import Foundation
import Database
import Models
import GRDB

public struct SyncConflicto: Identifiable, Sendable {
    public let id = UUID()
    public let tabla: String
    public let uuid: String
    public let localJSON: String
    public let remotoJSON: String
    public let localUpdatedAt: Int64
    public let remotoUpdatedAt: Int64
}

public enum SyncResolucion: Sendable {
    case usarLocal
    case usarRemoto
}

public final class SyncService: @unchecked Sendable {
    private let manager: DatabaseManager
    private let supabase: SupabaseManager
    public var autenticado: Bool = false

    private var conflictoHandler: (@MainActor @Sendable ([SyncConflicto]) async -> Void)?
    public private(set) var erroresSync: [String] = []

    public init(manager: DatabaseManager, supabase: SupabaseManager) {
        self.manager = manager
        self.supabase = supabase
    }

    public func configurarHandler(
        _ handler: @escaping @MainActor @Sendable ([SyncConflicto]) async -> Void
    ) {
        self.conflictoHandler = handler
    }

    // MARK: - Auth

    public func enviarMagicLink(email: String) async throws {
        try await supabase.enviarMagicLink(email: email)
    }

    public func verificarYAutenticar(email: String, token: String) async throws {
        let sesion = try await supabase.verificarOTP(email: email, token: token)
        autenticado = true
        if let data = try? JSONEncoder().encode(sesion) {
            UserDefaults.standard.set(data, forKey: "supabase_session")
        }
    }

    public func restaurarSesion() {
        guard let data = UserDefaults.standard.data(forKey: "supabase_session"),
              let sesion = try? JSONDecoder().decode(SupabaseSession.self, from: data) else { return }
        supabase.token = sesion.accessToken
        autenticado = true
        if sesion.expiresAt * 1000 < Date().epochMillis {
            autenticado = false
        }
    }

    // MARK: - Push

    public func pushChanges() async {
        for tabla in Self.tablasConUUID {
            guard autenticado else { return }
            let uuids: [String] = ((try? await manager.leer { db in
                try String.fetchAll(db, sql: """
                    SELECT uuid FROM \(tabla)
                    WHERE sync_status = 0 AND is_deleted = 0 AND uuid IS NOT NULL AND uuid != ''
                    """)
            }) ?? []).filter { !$0.isEmpty }
            for uuid in uuids {
                guard let body = try? await leerBody(tabla: tabla, uuid: uuid) else { continue }
                do {
                    try await supabase.insertar(tabla: tabla, body: body)
                    await marcarSynced(tabla: tabla, uuid: uuid)
                } catch let SupabaseError.red(code, msg) where code == 409 {
                    try? await supabase.actualizar(tabla: tabla, uuid: uuid, body: body)
                    await marcarSynced(tabla: tabla, uuid: uuid)
                } catch {
                    let msg = "[Sync] Error pushing \(tabla)/\(uuid): \(error)"
                    print(msg)
                    erroresSync.append(msg)
                }
            }
        }
    }

    private func leerBody(tabla: String, uuid: String) async throws -> [String: Any]? {
        let data: Data = try await manager.leer { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM \(tabla) WHERE uuid = ?", arguments: [uuid]) else {
                throw AppDatabaseError.filaNoEncontrada
            }
            return try JSONSerialization.data(withJSONObject: SyncService.rowDict(row))
        }
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        // Supabase usa GENERATED ALWAYS AS IDENTITY para estas tablas
        if tabla != "SaldoInicial" {
            dict.removeValue(forKey: "id")
        }
        return dict
    }

    public func pushCambio(tabla: String, uuid: String, datos: [String: Any]) async {
        guard autenticado else { return }
        do {
            try await supabase.insertar(tabla: tabla, body: datos)
            await marcarSynced(tabla: tabla, uuid: uuid)
        } catch let SupabaseError.red(code, _) where code == 409 {
            try? await supabase.actualizar(tabla: tabla, uuid: uuid, body: datos)
            await marcarSynced(tabla: tabla, uuid: uuid)
        } catch {}
    }

    public func pushEliminacion(tabla: String, uuid: String) async {
        guard autenticado else { return }
        do {
            try await supabase.eliminar(tabla: tabla, uuid: uuid)
        } catch {}
    }

    public func pushNuevo(tabla: String, uuid: String, datos: [String: Any]) async {
        guard autenticado else { return }
        do {
            try await supabase.insertar(tabla: tabla, body: datos)
            await marcarSynced(tabla: tabla, uuid: uuid)
        } catch {}
    }

    // MARK: - Pull

    public func pullChanges() async {
        guard autenticado else { return }
        let ultimoSync = await obtenerUltimoSync()
        var conflictos: [SyncConflicto] = []

        for tabla in SyncService.tablasConUUID {
            do {
                let remotos = try await supabase.select(tabla: tabla, since: ultimoSync > 0 ? min(ultimoSync, Date().epochMillis) : nil)
                for remoto in remotos {
                    let uuid = remoto["uuid"] as? String ?? ""
                    guard !uuid.isEmpty else { continue }
                    if let conflicto = try await aplicarCambio(tabla: tabla, uuid: uuid, remoto: remoto) {
                        conflictos.append(conflicto)
                    }
                }
            } catch {}
        }

        if !conflictos.isEmpty, let handler = conflictoHandler {
            await handler(conflictos)
        }

        await actualizarUltimoSync()
    }

    private func aplicarCambio(
        tabla: String, uuid: String, remoto: [String: Any]
    ) async throws -> SyncConflicto? {
        let remotoUpdated = remoto["updated_at"] as? Int64 ?? 0
        guard remotoUpdated > 0 else { return nil }
        let isDeleted = (remoto["is_deleted"] as? Int) == 1
        let remotoData = try JSONSerialization.data(withJSONObject: remoto)

        return try await manager.escribir { db in
            let remoto = (try? JSONSerialization.jsonObject(with: remotoData) as? [String: Any]) ?? [:]

            if isDeleted {
                try db.execute(sql: "UPDATE \(tabla) SET is_deleted = 1, sync_status = 1, updated_at = ? WHERE uuid = ?",
                              arguments: [remotoUpdated, uuid])
                return nil
            }

            let localRow = try Row.fetchOne(db, sql: "SELECT updated_at FROM \(tabla) WHERE uuid = ?", arguments: [uuid])
            guard let localRow, let localUpdated = localRow["updated_at"] as? Int64 else {
                try SyncService.insertarRemoto(db: db, tabla: tabla, remoto: remoto)
                return nil
            }

            if remotoUpdated <= localUpdated { return nil }

            if remotoUpdated > localUpdated + 2000 {
                try SyncService.actualizarConRemoto(db: db, tabla: tabla, uuid: uuid, remoto: remoto)
                return nil
            }

            let localJSON = try SyncService.obtenerJSONLocal(db: db, tabla: tabla, uuid: uuid)
            let remotoJSON = SyncService.remotoAJSON(remoto)
            return SyncConflicto(
                tabla: tabla,
                uuid: uuid,
                localJSON: localJSON,
                remotoJSON: remotoJSON,
                localUpdatedAt: localUpdated,
                remotoUpdatedAt: remotoUpdated
            )
        }
    }

    public func resolverConflicto(_ conflicto: SyncConflicto, eleccion: SyncResolucion) async {
        switch eleccion {
        case .usarLocal:
            try? await manager.escribir { db in
                try db.execute(sql: "UPDATE \(conflicto.tabla) SET sync_status = 0 WHERE uuid = ?",
                              arguments: [conflicto.uuid])
            }
        case .usarRemoto:
            let remotos = try? await supabase.select(tabla: conflicto.tabla, since: nil, columnas: "*")
            let remoto = remotos?.first(where: { ($0["uuid"] as? String) == conflicto.uuid })
            guard let remoto else { return }
            let uuid = conflicto.uuid
            let tabla = conflicto.tabla
            let remotoData = try? JSONSerialization.data(withJSONObject: remoto)
            let finalData = remotoData ?? Data()
            try? await manager.escribir { db in
                try db.execute(sql: "UPDATE \(tabla) SET sync_status = 1, is_deleted = 1 WHERE uuid = ?",
                              arguments: [uuid])
                if let remoto = try? JSONSerialization.jsonObject(with: finalData) as? [String: Any] {
                    try SyncService.insertarRemoto(db: db, tabla: tabla, remoto: remoto)
                }
            }
        }
    }

    private static let claveUltimoSync = "last_synced_at_millis"

    // MARK: - Sync metadata

    private func obtenerUltimoSync() async -> Int64 {
        (try? await manager.leer { db in
            try String.fetchOne(db, sql: "SELECT valor FROM Metadata WHERE clave = ?", arguments: [Self.claveUltimoSync])
                .flatMap { Int64($0) } ?? 0
        }) ?? 0
    }

    private func actualizarUltimoSync() async {
        let ahora = Date().epochMillis
        try? await manager.escribir { db in
            try db.execute(sql: """
                INSERT INTO Metadata (clave, valor) VALUES (?, ?)
                ON CONFLICT(clave) DO UPDATE SET valor = excluded.valor
                """, arguments: [Self.claveUltimoSync, "\(ahora)"])
        }
    }

    private func marcarSynced(tabla: String, uuid: String) async {
        try? await manager.escribir { db in
            try db.execute(sql: "UPDATE \(tabla) SET sync_status = 1 WHERE uuid = ?", arguments: [uuid])
        }
    }

    // MARK: - Helpers

    public static let tablasConUUID = ["Transacciones", "Prestamos", "Suscripciones", "SaldoInicial", "InventarioEfectivo"]

    static func insertarRemoto(db: Database, tabla: String, remoto: [String: Any]) throws {
        let pares = remoto.filter { $0.key != "sync_status" }
        let cols = pares.keys.joined(separator: ", ")
        let placeholders = pares.keys.map { _ in "?" }.joined(separator: ", ")
        let statement = try db.makeStatement(sql: "INSERT OR IGNORE INTO \(tabla) (\(cols)) VALUES (\(placeholders))")
        let dvs = Self.toDatabaseValues(Array(pares.values))
        try statement.setArguments(StatementArguments(dvs))
        try statement.execute()
    }

    static func actualizarConRemoto(db: Database, tabla: String, uuid: String, remoto: [String: Any]) throws {
        let pares = remoto.filter { $0.key != "uuid" && $0.key != "sync_status" }
        let sets = pares.keys.map { "\($0) = ?" }.joined(separator: ", ")
        let statement = try db.makeStatement(sql: "UPDATE \(tabla) SET \(sets) WHERE uuid = ?")
        let dvs = Self.toDatabaseValues(Array(pares.values))
        let allDvs = dvs + [uuid.databaseValue]
        try statement.setArguments(StatementArguments(allDvs))
        try statement.execute()
    }

    private static func toDatabaseValues(_ values: [Any]) -> [DatabaseValue] {
        values.map { v in
            switch v {
            case let s as String: return s.databaseValue
            case let i as Int64: return i.databaseValue
            case let i as Int: return Int64(i).databaseValue
            case let d as Double: return d.databaseValue
            case let b as Bool: return (b ? 1 : 0).databaseValue
            default: return "".databaseValue
            }
        }
    }

    static func obtenerJSONLocal(db: Database, tabla: String, uuid: String) throws -> String {
        if let row = try Row.fetchOne(db, sql: "SELECT * FROM \(tabla) WHERE uuid = ?", arguments: [uuid]) {
            return SyncService.rowAJSON(row)
        }
        return "{}"
    }

    static func remotoAJSON(_ remoto: [String: Any]) -> String {
        remoto.map { k, v in "\"\(k)\": \(v)" }.joined(separator: ", ")
    }

    static func rowDict(_ row: Row) -> [String: Any] {
        var dict: [String: Any] = [:]
        for (col, dbv) in row {
            switch dbv.storage {
            case .null: break
            case .int64(let v): dict[col] = v
            case .double(let v): dict[col] = v
            case .string(let v): dict[col] = v
            case .blob(let v): dict[col] = v
            }
        }
        return dict
    }

    static func rowAJSON(_ row: Row) -> String {
        var parts: [String] = []
        for (col, dbv) in row {
            switch dbv.storage {
            case .null: parts.append("\"\(col)\": null")
            case .int64(let v): parts.append("\"\(col)\": \(v)")
            case .double(let v): parts.append("\"\(col)\": \(v)")
            case .string(let v): parts.append("\"\(col)\": \"\(v)\"")
            case .blob: parts.append("\"\(col)\": \"<blob>\"")
            }
        }
        return parts.joined(separator: ", ")
    }
}


