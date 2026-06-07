import Foundation
import GRDB
import Models

public protocol InitialBalanceRepository: Sendable {
    func obtener() async throws -> SaldoInicial?
    func guardar(_ saldo: SaldoInicial, inventario: [Inventario]) async throws
}

public final class SQLiteInitialBalanceRepository: InitialBalanceRepository, @unchecked Sendable {
    private let manager: DatabaseManager

    public init(manager: DatabaseManager) {
        self.manager = manager
    }

    public func obtener() async throws -> SaldoInicial? {
        try await manager.leer { db in
            try SaldoInicialRecord.fetchOne(db, key: 1)?.aModelo()
        }
    }

    public func guardar(_ saldo: SaldoInicial, inventario: [Inventario]) async throws {
        try await manager.escribir { db in
            let record = SaldoInicialRecord(saldo, inventario: inventario)
            try record.save(db)

            let ahora = FormatoFecha.formatearFechaHora(Date())
            for item in inventario {
                try db.execute(
                    sql: """
                        INSERT INTO InventarioEfectivo (denominacion, cantidad, actualizadoEn)
                        VALUES (?, ?, ?)
                        ON CONFLICT(denominacion) DO UPDATE
                        SET cantidad = excluded.cantidad,
                            actualizadoEn = excluded.actualizadoEn
                        """,
                    arguments: [item.denominacion, item.cantidad, ahora]
                )
            }
        }
    }
}
