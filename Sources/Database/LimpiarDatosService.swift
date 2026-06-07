import Foundation
import GRDB

public struct ConteosUsuario: Sendable, Equatable {
    public let transacciones: Int
    public let prestamos: Int
    public let suscripciones: Int
    public let inventario: Int
    public let saldoInicial: Bool

    public init(
        transacciones: Int,
        prestamos: Int,
        suscripciones: Int,
        inventario: Int,
        saldoInicial: Bool
    ) {
        self.transacciones = transacciones
        self.prestamos = prestamos
        self.suscripciones = suscripciones
        self.inventario = inventario
        self.saldoInicial = saldoInicial
    }

    public var totalFilas: Int {
        transacciones + prestamos + suscripciones + inventario + (saldoInicial ? 1 : 0)
    }

    public var hayDatos: Bool { totalFilas > 0 }
}

public enum LimpiarDatosService {

    public static func conteos(en manager: DatabaseManager) async throws -> ConteosUsuario {
        try await manager.leer { db in
            let t = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones") ?? 0
            let p = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Prestamos") ?? 0
            let s = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Suscripciones") ?? 0
            let i = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM InventarioEfectivo") ?? 0
            let si = (try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM SaldoInicial") ?? 0) > 0
            return ConteosUsuario(
                transacciones: t, prestamos: p, suscripciones: s,
                inventario: i, saldoInicial: si
            )
        }
    }

    public static func limpiar(en manager: DatabaseManager) async throws -> ConteosUsuario {
        try await manager.escribir { db in
            try db.execute(sql: "DELETE FROM Transacciones")
            try db.execute(sql: "DELETE FROM Prestamos")
            try db.execute(sql: "DELETE FROM Suscripciones")
            try db.execute(sql: "DELETE FROM InventarioEfectivo")
            try db.execute(sql: "DELETE FROM SaldoInicial")
            try db.execute(sql: """
                DELETE FROM sqlite_sequence
                WHERE name IN ('Transacciones','Prestamos','Suscripciones')
                """)
        }
        return try await conteos(en: manager)
    }
}
