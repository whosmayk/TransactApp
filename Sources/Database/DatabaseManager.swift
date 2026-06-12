import Foundation
import GRDB

public enum AppDatabaseError: LocalizedError {
    case esquemaInvalido(mensaje: String)
    case filaNoEncontrada
    case errorSQL(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .esquemaInvalido(let mensaje):
            return "Esquema de base de datos invalido: \(mensaje)"
        case .filaNoEncontrada:
            return "No se encontro la fila solicitada."
        case .errorSQL(let underlying):
            return "Error de base de datos: \(underlying.localizedDescription)"
        }
    }
}

public final class DatabaseManager: @unchecked Sendable {
    public let ruta: URL
    private var _dbQueue: DatabaseQueue
    private let lock = NSLock()

    public var dbQueue: DatabaseQueue {
        lock.lock()
        defer { lock.unlock() }
        return _dbQueue
    }

    public init(ruta: URL) throws {
        self.ruta = ruta
        self._dbQueue = try Self.crearCola(ruta: ruta)
        try Migrator.aplicar(_dbQueue)
    }

    public static func rutaPorDefecto() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("TransactApp", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("transactapp.sqlite")
    }

    public static func crearEnRutaPorDefecto() throws -> DatabaseManager {
        let ruta = try rutaPorDefecto()
        return try DatabaseManager(ruta: ruta)
    }

    public func crearObservador(debounceMs: Int = 150) -> DatabaseObserver {
        DatabaseObserver(dbQueue: dbQueue, debounceMs: debounceMs)
    }

    public func escribir<T: Sendable>(_ bloque: @escaping @Sendable (Database) throws -> T) async throws -> T {
        let cola = dbQueue
        return try await cola.write { db in
            try bloque(db)
        }
    }

    public func leer<T: Sendable>(_ bloque: @escaping @Sendable (Database) throws -> T) async throws -> T {
        let cola = dbQueue
        return try await cola.read { db in
            try bloque(db)
        }
    }

    public func cerrar() throws {
        let actual = dbQueue
        lock.lock()
        _dbQueue = try Self.crearColaVacia()
        lock.unlock()
        _ = actual
    }

    public func reabrir() throws {
        lock.lock()
        _dbQueue = try Self.crearCola(ruta: ruta)
        lock.unlock()
    }

    public func reemplazarArchivo(desde origen: URL) throws {
        try cerrar()

        let fm = FileManager.default
        let destino = ruta
        let destinoWAL = ruta.appendingPathExtension("wal")
        let destinoSHM = ruta.appendingPathExtension("shm")

        for lateral in [destinoWAL, destinoSHM] {
            if fm.fileExists(atPath: lateral.path) {
                try? fm.removeItem(at: lateral)
            }
        }

        if fm.fileExists(atPath: destino.path) {
            try? fm.removeItem(at: destino)
        }
        try fm.copyItem(at: origen, to: destino)

        try reabrir()

        let cola = dbQueue
        do {
            _ = try cola.read { db in
                try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sqlite_master") ?? 0
            }
        } catch {
            throw AppDatabaseError.esquemaInvalido(
                mensaje: "La base de datos restaurada no es valida: \(error.localizedDescription)"
            )
        }
    }

    private static func crearCola(ruta: URL) throws -> DatabaseQueue {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.busyMode = .timeout(5)
        return try DatabaseQueue(path: ruta.path, configuration: config)
    }

    private static func crearColaVacia() throws -> DatabaseQueue {
        var config = Configuration()
        config.foreignKeysEnabled = true
        return try DatabaseQueue()
    }
}
