import Foundation
import GRDB
import Models

public protocol ConfigurationRepository: Sendable {
    func obtener(clave: String) async throws -> String?
    func guardar(clave: String, valor: String) async throws
    func eliminar(clave: String) async throws
}

public final class SQLiteConfigurationRepository: ConfigurationRepository, @unchecked Sendable {
    private let manager: DatabaseManager

    public init(manager: DatabaseManager) {
        self.manager = manager
    }

    public func obtener(clave: String) async throws -> String? {
        try await manager.leer { db in
            try String.fetchOne(
                db,
                sql: "SELECT valor FROM Configuracion WHERE clave = ?",
                arguments: [clave]
            )
        }
    }

    public func guardar(clave: String, valor: String) async throws {
        try await manager.escribir { db in
            try db.execute(
                sql: """
                    INSERT INTO Configuracion (clave, valor, actualizadoEn)
                    VALUES (?, ?, ?)
                    ON CONFLICT(clave) DO UPDATE
                    SET valor = excluded.valor,
                        actualizadoEn = excluded.actualizadoEn
                    """,
                arguments: [clave, valor, FormatoFecha.formatearFechaHora(Date())]
            )
        }
    }

    public func eliminar(clave: String) async throws {
        try await manager.escribir { db in
            try db.execute(
                sql: "DELETE FROM Configuracion WHERE clave = ?",
                arguments: [clave]
            )
        }
    }
}
