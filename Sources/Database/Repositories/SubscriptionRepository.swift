import Foundation
import GRDB
import Models

public protocol SubscriptionRepository: Sendable {
    func listar() async throws -> [Suscripcion]
    func listarActivas() async throws -> [Suscripcion]
    func listarProximasAVencer(dentroDe dias: Int, referencia: Date) async throws -> [Suscripcion]
    func obtener(id: Int64) async throws -> Suscripcion?
    func insertar(_ suscripcion: Suscripcion) async throws -> Suscripcion
    func actualizar(_ suscripcion: Suscripcion) async throws -> Suscripcion
    func eliminar(id: Int64) async throws
    func marcarNotificada(id: Int64) async throws
    func marcarNoNotificada(id: Int64) async throws
    func actualizarProximoCobro(id: Int64, nuevoProximo: Date) async throws

    func insertarEn(db: GRDB.Database, _ suscripcion: Suscripcion) throws -> Suscripcion
    func actualizarEn(db: GRDB.Database, _ suscripcion: Suscripcion) throws -> Suscripcion
    func eliminarEn(db: GRDB.Database, id: Int64) throws
    func obtenerEn(db: GRDB.Database, id: Int64) throws -> Suscripcion?
}

public final class SQLiteSubscriptionRepository: SubscriptionRepository, @unchecked Sendable {
    private let manager: DatabaseManager

    public init(manager: DatabaseManager) {
        self.manager = manager
    }

    public func listar() async throws -> [Suscripcion] {
        try await manager.leer { db in
            let records = try SuscripcionRecord
                .order(Column("proximoCobro").asc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func listarActivas() async throws -> [Suscripcion] {
        try await manager.leer { db in
            let records = try SuscripcionRecord
                .filter(Column("activa") == 1)
                .order(Column("proximoCobro").asc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func listarProximasAVencer(dentroDe dias: Int, referencia: Date) async throws -> [Suscripcion] {
        let calendar = Calendar.current
        let inicioHoy = calendar.startOfDay(for: referencia)
        let limiteFuturo = calendar.date(byAdding: .day, value: dias, to: inicioHoy) ?? referencia
        let margenPasado = calendar.date(byAdding: .day, value: -7, to: inicioHoy) ?? referencia
        let limiteStr = FormatoFecha.formatearFecha(limiteFuturo)
        let margenStr = FormatoFecha.formatearFecha(margenPasado)
        return try await manager.leer { db in
            let records = try SuscripcionRecord
                .filter(Column("activa") == 1)
                .filter(Column("notificado") == 0)
                .filter(Column("proximoCobro") >= margenStr && Column("proximoCobro") <= limiteStr)
                .order(Column("proximoCobro").asc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func obtener(id: Int64) async throws -> Suscripcion? {
        try await manager.leer { db in
            try SuscripcionRecord.fetchOne(db, key: id)?.aModelo()
        }
    }

    public func insertar(_ suscripcion: Suscripcion) async throws -> Suscripcion {
        try await manager.escribir { db in
            try self.insertarEn(db: db, suscripcion)
        }
    }

    public func actualizar(_ suscripcion: Suscripcion) async throws -> Suscripcion {
        guard suscripcion.id != nil else { throw AppDatabaseError.filaNoEncontrada }
        return try await manager.escribir { db in
            try self.actualizarEn(db: db, suscripcion)
        }
    }

    public func eliminar(id: Int64) async throws {
        _ = try await manager.escribir { db in
            try self.eliminarEn(db: db, id: id)
        }
    }

    public func marcarNotificada(id: Int64) async throws {
        _ = try await manager.escribir { db in
            try db.execute(
                sql: "UPDATE Suscripciones SET notificado = 1 WHERE id = ?",
                arguments: [id]
            )
        }
    }

    public func marcarNoNotificada(id: Int64) async throws {
        _ = try await manager.escribir { db in
            try db.execute(
                sql: "UPDATE Suscripciones SET notificado = 0 WHERE id = ?",
                arguments: [id]
            )
        }
    }

    public func actualizarProximoCobro(id: Int64, nuevoProximo: Date) async throws {
        let nuevo = FormatoFecha.formatearFecha(nuevoProximo)
        _ = try await manager.escribir { db in
            try db.execute(
                sql: "UPDATE Suscripciones SET proximoCobro = ?, notificado = 0 WHERE id = ?",
                arguments: [nuevo, id]
            )
        }
    }

    public func insertarEn(db: GRDB.Database, _ suscripcion: Suscripcion) throws -> Suscripcion {
        var record = SuscripcionRecord(suscripcion)
        record.id = nil
        try record.insert(db)
        guard let id = record.id else { throw AppDatabaseError.filaNoEncontrada }
        var copia = suscripcion
        copia.id = id
        return copia
    }

    public func actualizarEn(db: GRDB.Database, _ suscripcion: Suscripcion) throws -> Suscripcion {
        guard let id = suscripcion.id else { throw AppDatabaseError.filaNoEncontrada }
        var record = SuscripcionRecord(suscripcion)
        record.id = id
        try record.update(db)
        return suscripcion
    }

    public func eliminarEn(db: GRDB.Database, id: Int64) throws {
        try SuscripcionRecord.deleteOne(db, key: id)
    }

    public func obtenerEn(db: GRDB.Database, id: Int64) throws -> Suscripcion? {
        try SuscripcionRecord.fetchOne(db, key: id)?.aModelo()
    }
}
