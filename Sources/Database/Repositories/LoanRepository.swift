import Foundation
import GRDB
import Models

public protocol LoanRepository: Sendable {
    func listar() async throws -> [Prestamo]
    func listarPor(tipo: TipoPrestamo) async throws -> [Prestamo]
    func obtener(id: Int64) async throws -> Prestamo?
    func insertar(_ prestamo: Prestamo) async throws -> Prestamo
    func actualizar(_ prestamo: Prestamo) async throws -> Prestamo
    func eliminar(id: Int64) async throws
    func sumarPendientes(tipo: TipoPrestamo) async throws -> Decimal
    func sumarAfectaBalance() async throws -> Decimal

    func insertarEn(db: GRDB.Database, _ prestamo: Prestamo) throws -> Prestamo
    func actualizarEn(db: GRDB.Database, _ prestamo: Prestamo) throws -> Prestamo
    func eliminarEn(db: GRDB.Database, id: Int64) throws
    func obtenerEn(db: GRDB.Database, id: Int64) throws -> Prestamo?
}

public final class SQLiteLoanRepository: LoanRepository, @unchecked Sendable {
    private let manager: DatabaseManager

    public init(manager: DatabaseManager) {
        self.manager = manager
    }

    public func listar() async throws -> [Prestamo] {
        try await manager.leer { db in
            let records = try PrestamoRecord
                .order(Column("fecha").desc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func listarPor(tipo: TipoPrestamo) async throws -> [Prestamo] {
        try await manager.leer { db in
            let records = try PrestamoRecord
                .filter(Column("tipo") == tipo.rawValue)
                .order(Column("fecha").desc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func obtener(id: Int64) async throws -> Prestamo? {
        try await manager.leer { db in
            try PrestamoRecord.fetchOne(db, key: id)?.aModelo()
        }
    }

    public func insertar(_ prestamo: Prestamo) async throws -> Prestamo {
        try await manager.escribir { db in
            try self.insertarEn(db: db, prestamo)
        }
    }

    public func actualizar(_ prestamo: Prestamo) async throws -> Prestamo {
        guard prestamo.id != nil else { throw AppDatabaseError.filaNoEncontrada }
        return try await manager.escribir { db in
            try self.actualizarEn(db: db, prestamo)
        }
    }

    public func eliminar(id: Int64) async throws {
        _ = try await manager.escribir { db in
            try self.eliminarEn(db: db, id: id)
        }
    }

    public func sumarPendientes(tipo: TipoPrestamo) async throws -> Decimal {
        try await manager.leer { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT monto, montoPagado
                FROM Prestamos
                WHERE tipo = ?
                """, arguments: [tipo.rawValue])
            var total: Decimal = 0
            for row in rows {
                let monto = row["monto"] as Double? ?? 0
                let pagado = row["montoPagado"] as Double? ?? 0
                let pendiente = max(0, monto - pagado)
                total += Decimal(pendiente)
            }
            return total
        }
    }

    public func sumarAfectaBalance() async throws -> Decimal {
        try await manager.leer { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT monto, montoPagado
                FROM Prestamos
                WHERE tipo = 'Debo' AND afectaBalance = 1
                """)
            var total: Decimal = 0
            for row in rows {
                let monto = row["monto"] as Double? ?? 0
                let pagado = row["montoPagado"] as Double? ?? 0
                let pendiente = max(0, monto - pagado)
                total += Decimal(pendiente)
            }
            return total
        }
    }

    public func insertarEn(db: GRDB.Database, _ prestamo: Prestamo) throws -> Prestamo {
        var record = PrestamoRecord(prestamo)
        record.id = nil
        try record.insert(db)
        guard let id = record.id else { throw AppDatabaseError.filaNoEncontrada }
        var copia = prestamo
        copia.id = id
        return copia
    }

    public func actualizarEn(db: GRDB.Database, _ prestamo: Prestamo) throws -> Prestamo {
        guard let id = prestamo.id else { throw AppDatabaseError.filaNoEncontrada }
        var record = PrestamoRecord(prestamo)
        record.id = id
        try record.update(db)
        return prestamo
    }

    public func eliminarEn(db: GRDB.Database, id: Int64) throws {
        try PrestamoRecord.deleteOne(db, key: id)
    }

    public func obtenerEn(db: GRDB.Database, id: Int64) throws -> Prestamo? {
        try PrestamoRecord.fetchOne(db, key: id)?.aModelo()
    }
}
