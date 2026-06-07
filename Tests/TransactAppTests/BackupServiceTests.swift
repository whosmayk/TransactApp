import XCTest
import Foundation
@testable import Database
@testable import Services
import Models

final class BackupServiceTests: XCTestCase {
    var tempDir: URL!
    var dbPath: URL!
    var database: DatabaseManager!
    var service: BackupService!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactAppTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("test.sqlite")
        database = try DatabaseManager(ruta: dbPath)
        let dirRespaldos = tempDir.appendingPathComponent("Respaldos")
        service = BackupService(
            database: database,
            directorioRespaldos: dirRespaldos,
            versionApp: "0.6.0",
            esquemaActual: 3
        )
    }

    override func tearDownWithError() throws {
        service = nil
        database = nil
        if let tempDir {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    func testCrearRespaldoGeneraArchivoValido() async throws {
        let respaldo = try service.crearRespaldo()

        XCTAssertTrue(FileManager.default.fileExists(atPath: respaldo.url.path))
        XCTAssertEqual(respaldo.url.pathExtension, "transactapp")
        XCTAssertGreaterThan(respaldo.tamano, 0)
        XCTAssertEqual(respaldo.versionEsquema, 3)
        XCTAssertEqual(respaldo.versionApp, "0.6.0")
        XCTAssertFalse(respaldo.automatico)

        let datos = try Data(contentsOf: respaldo.url)
        let magic = Array(datos.prefix(4))
        XCTAssertEqual(magic, BackupService.magic)
    }

    func testRoundTripRestaurarPreservaDatos() async throws {
        try await database.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES ('2026-06-01', '10:00', 'Comida', 250, 'Gasto', 'Alimentación', 'Efectivo')
            """)
        }

        let respaldo = try service.crearRespaldo()

        try await database.escribir { db in
            try db.execute(sql: "DELETE FROM Transacciones")
        }

        let conteoAntes = try await contarTransacciones()
        XCTAssertEqual(conteoAntes, 0)

        try service.restaurar(respaldo)

        let conteoDespues = try await contarTransacciones()
        XCTAssertEqual(conteoDespues, 1, "La transacción debería estar de vuelta")

        let concepto = try await database.leer { db in
            try String.fetchOne(db, sql: "SELECT concepto FROM Transacciones LIMIT 1")
        }
        XCTAssertEqual(concepto, "Comida")
    }

    func testListarRespaldosOrdenaPorFechaDescendente() throws {
        let r1 = try service.crearRespaldo()
        Thread.sleep(forTimeInterval: 0.05)
        let r2 = try service.crearRespaldo()
        Thread.sleep(forTimeInterval: 0.05)
        let r3 = try service.crearRespaldo()

        let listados = try service.listar()
        XCTAssertEqual(listados.count, 3)
        XCTAssertEqual(listados[0].id, r3.id)
        XCTAssertEqual(listados[1].id, r2.id)
        XCTAssertEqual(listados[2].id, r1.id)
    }

    func testEliminarRespaldoBorraArchivo() throws {
        let respaldo = try service.crearRespaldo()
        XCTAssertTrue(FileManager.default.fileExists(atPath: respaldo.url.path))

        try service.eliminar(respaldo)

        XCTAssertFalse(FileManager.default.fileExists(atPath: respaldo.url.path))
        let listados = try service.listar()
        XCTAssertEqual(listados.count, 0)
    }

    func testLimpiarRespaldosAutomaticosMantieneSoloNRecientes() throws {
        for _ in 0..<5 {
            _ = try service.crearRespaldo(automatico: true)
            Thread.sleep(forTimeInterval: 0.02)
        }
        _ = try service.crearRespaldo(automatico: false)

        let todos = try service.listar()
        let automaticos = todos.filter { $0.automatico }
        XCTAssertEqual(automaticos.count, 5)
        XCTAssertEqual(todos.count, 6)

        try service.limpiarRespaldosAutomaticos(mantener: 2)

        let despues = try service.listar()
        let automaticosDespues = despues.filter { $0.automatico }
        XCTAssertEqual(automaticosDespues.count, 2, "Solo debe mantener 2 automáticos")
        XCTAssertEqual(despues.count, 3, "Los manuales deben sobrevivir")
    }

    func testRestaurarRechazaArchivoInvalido() throws {
        let archivoInvalido = tempDir.appendingPathComponent("basura.transactapp")
        try Data("no es un respaldo".utf8).write(to: archivoInvalido)

        XCTAssertThrowsError(try service.restaurar(desde: archivoInvalido)) { error in
            guard let e = error as? BackupError else {
                XCTFail("Esperaba BackupError")
                return
            }
            XCTAssertEqual(e, .formatoInvalido)
        }
    }

    func testRestaurarRechazaEsquemaIncompatible() throws {
        let otroDB = try DatabaseManager(
            ruta: tempDir.appendingPathComponent("otro.sqlite")
        )
        let otroService = BackupService(
            database: otroDB,
            directorioRespaldos: tempDir.appendingPathComponent("OtrosRespaldos"),
            versionApp: "0.5.0",
            esquemaActual: 99
        )
        let respaldoFalso = try otroService.crearRespaldo()

        XCTAssertThrowsError(try service.restaurar(respaldoFalso)) { error in
            guard let e = error as? BackupError else {
                XCTFail("Esperaba BackupError")
                return
            }
            if case .esquemaIncompatible(let archivo, let actual) = e {
                XCTAssertEqual(archivo, 99)
                XCTAssertEqual(actual, 3)
            } else {
                XCTFail("Esperaba esquemaIncompatible, recibí \(e)")
            }
        }
    }

    func testImportarDesdeArchivoCreaCopiaInterna() throws {
        let origen = tempDir.appendingPathComponent("origen.transactapp")
        let respaldoOriginal = try service.crearRespaldo()
        try FileManager.default.copyItem(at: respaldoOriginal.url, to: origen)
        try service.eliminar(respaldoOriginal)

        let importados = try service.listar()
        XCTAssertEqual(importados.count, 0)

        let importado = try service.importarDesdeArchivo(origen)
        XCTAssertTrue(FileManager.default.fileExists(atPath: importado.url.path))
        XCTAssertNotEqual(importado.url, origen, "Debe copiarse al directorio de respaldos")

        let finales = try service.listar()
        XCTAssertEqual(finales.count, 1)
        XCTAssertEqual(finales[0].id, importado.id)
        XCTAssertEqual(finales[0].nota, "Importado de origen.transactapp")
    }

    func testNombreArchivoIncluyeTimestamp() throws {
        let respaldo = try service.crearRespaldo()
        let nombre = respaldo.nombreArchivo
        XCTAssertTrue(nombre.hasPrefix("TransactApp-"))
        XCTAssertTrue(nombre.hasSuffix(".transactapp"))
        XCTAssertTrue(nombre.contains("-manual-"))
    }

    func testBackupAutomaticoSeLimpiaSegunRetencion() throws {
        let serviceConRetencion3 = BackupService(
            database: database,
            directorioRespaldos: tempDir.appendingPathComponent("R3"),
            versionApp: "0.6.0",
            esquemaActual: 3,
            retencionAutomatica: 3
        )

        for _ in 0..<6 {
            _ = try serviceConRetencion3.crearRespaldo(automatico: true)
            Thread.sleep(forTimeInterval: 0.02)
        }

        let listados = try serviceConRetencion3.listar()
        let automaticos = listados.filter { $0.automatico }
        XCTAssertEqual(automaticos.count, 3, "Debe mantener solo 3 automáticos")
    }

    private func contarTransacciones() async throws -> Int {
        try await database.leer { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones") ?? 0
        }
    }
}
