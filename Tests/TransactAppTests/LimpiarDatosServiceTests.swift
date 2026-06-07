import Foundation
import Testing
import GRDB
@testable import Database

@Suite("LimpiarDatosService")
struct LimpiarDatosServiceTests {

    private func directorioTemporal() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactAppLimpiar-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func managerLimpio() async throws -> DatabaseManager {
        let dir = try directorioTemporal()
        let ruta = dir.appendingPathComponent("test.sqlite")
        return try DatabaseManager(ruta: ruta)
    }

    private func poblar(_ manager: DatabaseManager) async throws {
        try await manager.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES ('2026-05-01','10:00','T1','100.0','Gasto','X','Efectivo'),
                       ('2026-05-02','11:00','T2','200.0','Ingreso','Y','Tarjeta');
                INSERT INTO Prestamos (persona, concepto, monto, tipo, fecha, afectaBalance, montoPagado)
                VALUES ('Mamá','Cosa','50.0','Debo','2026-05-01',1,0);
                INSERT INTO Suscripciones
                  (concepto, monto, categoria, frecuencia, tipo, fechaInicio, proximoCobro, activa, notificado)
                VALUES ('Netflix','269.0','Entretenimiento','Mensual','Gasto','2026-05-01','2026-06-01',1,0);
                INSERT INTO InventarioEfectivo (denominacion, cantidad, actualizadoEn)
                VALUES (1000, 3, '2026-05-01T10:00:00'), (500, 2, '2026-05-01T10:00:00');
                INSERT INTO SaldoInicial (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                VALUES (1, 1000.0, 500.0, '2026-05-01T10:00:00', '[]');
                """)
        }
    }

    @Test("Conteos detecta todas las filas de usuario")
    func conteosEnDBPoblada() async throws {
        let m = try await managerLimpio()
        try await poblar(m)
        let c = try await LimpiarDatosService.conteos(en: m)
        #expect(c.transacciones == 2)
        #expect(c.prestamos == 1)
        #expect(c.suscripciones == 1)
        #expect(c.inventario == 2)
        #expect(c.saldoInicial)
        #expect(c.hayDatos)
    }

    @Test("Conteos en DB vacía devuelve ceros")
    func conteosEnDBVacia() async throws {
        let m = try await managerLimpio()
        let c = try await LimpiarDatosService.conteos(en: m)
        #expect(!c.hayDatos)
        #expect(c.totalFilas == 0)
    }

    @Test("Limpiar borra todas las filas de usuario")
    func limpiarBorraTodo() async throws {
        let m = try await managerLimpio()
        try await poblar(m)
        let result = try await LimpiarDatosService.limpiar(en: m)
        #expect(!result.hayDatos)
        let c = try await LimpiarDatosService.conteos(en: m)
        #expect(c.transacciones == 0)
        #expect(c.prestamos == 0)
        #expect(c.suscripciones == 0)
        #expect(c.inventario == 0)
        #expect(!c.saldoInicial)
    }

    @Test("Limpiar resetea el autoincrement de Transacciones")
    func limpiarReseteaSecuencia() async throws {
        let m = try await managerLimpio()
        try await poblar(m)
        try await m.escribir { db in
            try db.execute(sql: "DELETE FROM Transacciones")
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES ('2026-05-01','10:00','Post','1.0','Gasto','X','Efectivo')
                """)
        }
        let idAntes = try await m.leer { db in
            try Int64.fetchOne(db, sql: "SELECT id FROM Transacciones ORDER BY id DESC LIMIT 1") ?? 0
        }
        #expect(idAntes == 3)

        _ = try await LimpiarDatosService.limpiar(en: m)
        try await m.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES ('2026-05-01','10:00','Post','1.0','Gasto','X','Efectivo')
                """)
        }
        let idDespues = try await m.leer { db in
            try Int64.fetchOne(db, sql: "SELECT id FROM Transacciones ORDER BY id DESC LIMIT 1") ?? 0
        }
        #expect(idDespues == 1)
    }

    @Test("Limpiar no toca la tabla grdb_migrations")
    func limpiarNoTocaMigraciones() async throws {
        let m = try await managerLimpio()
        try await poblar(m)
        _ = try await LimpiarDatosService.limpiar(en: m)
        let migraciones = try await m.leer { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM grdb_migrations") ?? 0
        }
        #expect(migraciones >= 1)
    }
}
