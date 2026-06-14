import Foundation
import GRDB
import Models

public protocol InventoryRepository: Sendable {
    func listar() async throws -> [Inventario]
    func obtener(denominacion: Int) async throws -> Inventario?
    func upsert(_ inventario: Inventario) async throws
    func ajustar(denominacion: Int, delta: Int) async throws
    func recontar(_ inventario: [Inventario]) async throws
    func reiniciarAlInicial(_ inicial: [Inventario]) async throws
    func ajustarEn(db: GRDB.Database, denominacion: Int, delta: Int) throws
    func cantidadEn(db: GRDB.Database, denominacion: Int) throws -> Int
}

public final class SQLiteInventoryRepository: InventoryRepository, @unchecked Sendable {
    private let manager: DatabaseManager

    public init(manager: DatabaseManager) {
        self.manager = manager
    }

    public func listar() async throws -> [Inventario] {
        try await manager.leer { db in
            let records = try InventarioRecord
                .order(Column("denominacion").desc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func obtener(denominacion: Int) async throws -> Inventario? {
        try await manager.leer { db in
            try InventarioRecord.fetchOne(db, key: denominacion)?.aModelo()
        }
    }

    public func upsert(_ inventario: Inventario) async throws {
        try await manager.escribir { db in
            var record = InventarioRecord(inventario)
            try record.save(db)
        }
    }

    public func ajustar(denominacion: Int, delta: Int) async throws {
        try await manager.escribir { db in
            try self.ajustarEn(db: db, denominacion: denominacion, delta: delta)
        }
    }

    public func recontar(_ inventario: [Inventario]) async throws {
        try await manager.escribir { db in
            let ahora = FormatoFecha.formatearFechaHora(Date())
            for item in inventario {
                try db.execute(
                    sql: "UPDATE InventarioEfectivo SET cantidad = ?, actualizadoEn = ? WHERE denominacion = ?",
                    arguments: [item.cantidad, ahora, item.denominacion]
                )
            }
        }
    }

    public func reiniciarAlInicial(_ inicial: [Inventario]) async throws {
        try await recontar(inicial)
    }

    public func ajustarEn(db: GRDB.Database, denominacion: Int, delta: Int) throws {
        let registro = try InventarioRecord.fetchOne(db, key: denominacion)
        let cantidadActual = registro?.cantidad ?? 0
        let nuevaCantidad = max(0, cantidadActual + delta)
        try db.execute(
            sql: """
                INSERT INTO InventarioEfectivo (denominacion, cantidad, actualizadoEn)
                VALUES (?, ?, ?)
                ON CONFLICT(denominacion) DO UPDATE
                SET cantidad = excluded.cantidad,
                    actualizadoEn = excluded.actualizadoEn
                """,
            arguments: [denominacion, nuevaCantidad, FormatoFecha.formatearFechaHora(Date())]
        )
    }

    public func cantidadEn(db: GRDB.Database, denominacion: Int) throws -> Int {
        try InventarioRecord.fetchOne(db, key: denominacion)?.cantidad ?? 0
    }
}
