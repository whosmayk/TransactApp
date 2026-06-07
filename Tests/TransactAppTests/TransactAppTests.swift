import Foundation
import Testing
import GRDB
@testable import Models
@testable import DesignSystem
@testable import Database

@Suite("DesgloseBilletes")
struct DesgloseBilletesTests {

    @Test("Suma correcta por denominaciones")
    func subtotal() {
        let d = DesgloseBilletes(n1000: 1, n500: 2, n100: 3, n5: 4)
        let esperado: Decimal = 1000 + 1000 + 300 + 20
        #expect(d.subtotal == esperado)
        #expect(d.totalBilletes == 10)
    }

    @Test("Detección de desglose vacío")
    func vacio() {
        let d = DesgloseBilletes()
        #expect(d.subtotal == 0)
        #expect(d.estaVacio)
    }

    @Test("Auto-desglose reparte empezando por denominaciones grandes")
    func autoDesglose() {
        let d = DesgloseBilletes.autoDesglose(monto: 1750)
        #expect(d.n1000 == 1)
        #expect(d.n500 == 1)
        #expect(d.n200 == 1)
        #expect(d.n50 == 1)
        #expect(d.subtotal == 1750)
    }

    @Test("Auto-desglose con monto no representable deja restante")
    func autoDesgloseNoRepresentable() {
        let d = DesgloseBilletes.autoDesglose(monto: 13)
        #expect(d.n10 == 1)
        #expect(d.n5 == 0)
        #expect(d.subtotal == 10)
    }

    @Test("Auto-desglose con cero devuelve desglose vacío")
    func autoDesgloseCero() {
        let d = DesgloseBilletes.autoDesglose(monto: 0)
        #expect(d.estaVacio)
    }
}

@Suite("Suscripcion")
struct SuscripcionTests {

    @Test("Monto mensual para frecuencia Mensual")
    func mensual() {
        let s = Suscripcion(
            concepto: "Netflix", monto: 199, categoria: "Entretenimiento",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        )
        #expect(s.montoMensual() == 199)
    }

    @Test("Monto mensual para frecuencia Trimestral")
    func trimestral() {
        let s = Suscripcion(
            concepto: "Antivirus", monto: 300, categoria: "Software",
            frecuencia: .trimestral, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        )
        #expect(s.montoMensual() == Decimal(string: "100.00"))
    }

    @Test("Monto mensual para frecuencia Anual")
    func anual() {
        let s = Suscripcion(
            concepto: "Dominio", monto: 1200, categoria: "Servicios",
            frecuencia: .anual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        )
        #expect(s.montoMensual() == 100)
    }
}

@Suite("Base de datos")
struct DatabaseTests {

    @Test("Crea esquema en blanco")
    func esquemaInicial() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("test.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)

        let count = try await manager.leer { db in
            try TransaccionRecord.fetchCount(db)
        }
        #expect(count == 0)
    }

    @Test("Round-trip Transacción con desglose")
    func roundTripTransaccion() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("test.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let repo = SQLiteTransactionRepository(manager: manager)

        let original = Transaccion(
            id: nil,
            fecha: FormatoFecha.parsearFecha("2026-06-03")!,
            hora: FormatoFecha.parsearHora("14:30")!,
            concepto: "Almuerzo",
            monto: 150.50,
            tipo: .gasto,
            categoria: "Comida",
            metodo: .efectivo,
            desglose: DesgloseBilletes(n100: 1, n50: 1)
        )

        let guardada = try await repo.insertar(original)
        #expect(guardada.id != nil)

        let todas = try await repo.listar()
        #expect(todas.count == 1)
        let recuperada = todas[0]
        #expect(recuperada.concepto == "Almuerzo")
        #expect(recuperada.monto == original.monto)
        #expect(recuperada.tipo == .gasto)
        #expect(recuperada.desglose?.subtotal == 150)
    }

    @Test("Round-trip Inventario con ajuste")
    func roundTripInventario() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("test.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let repo = SQLiteInventoryRepository(manager: manager)

        try await repo.upsert(Inventario(denominacion: 100, cantidad: 5))
        try await repo.upsert(Inventario(denominacion: 50, cantidad: 3))

        let items = try await repo.listar()
        #expect(items.count == 2)

        try await repo.ajustar(denominacion: 100, delta: 2)
        let actualizado = try await repo.obtener(denominacion: 100)
        #expect(actualizado?.cantidad == 7)
    }

    @Test("Importa DB estilo Windows con esquema compatible")
    func importarDBWindows() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let winPath = tmpDir.appendingPathComponent("windows.sqlite")
        let macPath = tmpDir.appendingPathComponent("mac.sqlite")

        let winManager = try DatabaseManager(ruta: winPath)
        let winRepo = SQLiteTransactionRepository(manager: winManager)
        let winInv = SQLiteInventoryRepository(manager: winManager)
        let winSusc = SQLiteSubscriptionRepository(manager: winManager)

        _ = try await winRepo.insertar(Transaccion(
            id: nil,
            fecha: FormatoFecha.parsearFecha("2026-05-15")!,
            hora: FormatoFecha.parsearHora("09:00")!,
            concepto: "Cobro tito",
            monto: 250,
            tipo: .ingreso,
            categoria: "Trabajo",
            metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 1, n50: 1)
        ))
        try await winInv.upsert(Inventario(denominacion: 1000, cantidad: 1))
        _ = try await winSusc.insertar(Suscripcion(
            id: nil,
            concepto: "Spotify",
            monto: 115,
            categoria: "Música",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: Date(),
            proximoCobro: Date()
        ))

        let macManager = try DatabaseManager(ruta: macPath)
        let resultado = try await DatabaseImporter.importar(
            desdeOrigen: winPath,
            alDestino: macManager
        )

        #expect(resultado.transaccionesImportadas == 1)
        #expect(resultado.inventarioImportado == 1)
        #expect(resultado.suscripcionesImportadas == 1)
        #expect(resultado.saldoInicialImportado == false)
    }

    @Test("Rechaza DB que no es de TransactApp")
    func rechazarDBInvalida() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let fakePath = tmpDir.appendingPathComponent("fake.sqlite")
        let queue = try DatabaseQueue(path: fakePath.path)
        try await queue.write { db in
            try db.execute(sql: "CREATE TABLE Otra (id INTEGER PRIMARY KEY)")
        }
        let macPath = tmpDir.appendingPathComponent("mac.sqlite")
        let macManager = try DatabaseManager(ruta: macPath)

        do {
            _ = try await DatabaseImporter.importar(
                desdeOrigen: fakePath,
                alDestino: macManager
            )
            Issue.record("Debió lanzar AppDatabaseError.esquemaInvalido")
        } catch is AppDatabaseError {
            // esperado
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }
}

func directorioTemporal() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("TransactAppTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}
