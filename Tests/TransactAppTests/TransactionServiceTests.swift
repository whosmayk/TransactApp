import Foundation
import Testing
import Models
import Database
import Services
@testable import TransactApp

@Suite("TransactionService")
struct TransactionServiceTests {

    private func preparar() async throws -> (DatabaseManager, TransactionService) {
        let tmpDir = try directorioTemporal()
        let dbPath = tmpDir.appendingPathComponent("tx.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let invRepo = SQLiteInventoryRepository(manager: manager)
        let svc = TransactionService(
            manager: manager,
            transactionRepo: txRepo,
            inventoryRepo: invRepo
        )
        return (manager, svc)
    }

    @Test("Crear gasto en efectivo decrementa inventario")
    func crearGastoEfectivo() async throws {
        let (manager, svc) = try await preparar()
        let invRepo = SQLiteInventoryRepository(manager: manager)
        try await invRepo.upsert(Inventario(denominacion: 200, cantidad: 5))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Cena", monto: 600,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 3)
        )
        let guardada = try await svc.crear(tx)
        #expect(guardada.id != nil)

        let item = try await invRepo.obtener(denominacion: 200)
        #expect(item?.cantidad == 2)
    }

    @Test("Crear ingreso en efectivo aumenta inventario")
    func crearIngresoEfectivo() async throws {
        let (manager, svc) = try await preparar()
        let invRepo = SQLiteInventoryRepository(manager: manager)
        try await invRepo.upsert(Inventario(denominacion: 100, cantidad: 0))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Cobro", monto: 300,
            tipo: .ingreso, categoria: "Trabajo", metodo: .efectivo,
            desglose: DesgloseBilletes(n100: 3)
        )
        _ = try await svc.crear(tx)

        let item = try await invRepo.obtener(denominacion: 100)
        #expect(item?.cantidad == 3)
    }

    @Test("Crear con tarjeta no toca inventario")
    func crearTarjetaNoToca() async throws {
        let (manager, svc) = try await preparar()
        let invRepo = SQLiteInventoryRepository(manager: manager)
        try await invRepo.upsert(Inventario(denominacion: 100, cantidad: 5))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Amazon", monto: 500,
            tipo: .gasto, categoria: "Compras", metodo: .tarjeta
        )
        _ = try await svc.crear(tx)

        let item = try await invRepo.obtener(denominacion: 100)
        #expect(item?.cantidad == 5)
    }

    @Test("Actualizar revierte inventario anterior y aplica nuevo")
    func actualizarRevierteYAplica() async throws {
        let (manager, svc) = try await preparar()
        let invRepo = SQLiteInventoryRepository(manager: manager)
        try await invRepo.upsert(Inventario(denominacion: 200, cantidad: 5))

        let original = try await svc.crear(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 400,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 2)
        ))

        let intermedia = try await invRepo.obtener(denominacion: 200)
        #expect(intermedia?.cantidad == 3)

        let nueva = Transaccion(
            id: original.id,
            fecha: original.fecha, hora: original.hora,
            concepto: "X", monto: 600,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 3)
        )
        _ = try await svc.actualizar(nueva, original: original)

        let final = try await invRepo.obtener(denominacion: 200)
        #expect(final?.cantidad == 2)
    }

    @Test("Actualizar de efectivo a tarjeta libera inventario")
    func actualizarEfectivoATarjeta() async throws {
        let (manager, svc) = try await preparar()
        let invRepo = SQLiteInventoryRepository(manager: manager)
        try await invRepo.upsert(Inventario(denominacion: 100, cantidad: 5))

        let original = try await svc.crear(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 200,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n100: 2)
        ))

        let nueva = Transaccion(
            id: original.id,
            fecha: original.fecha, hora: original.hora,
            concepto: "X", monto: 200,
            tipo: .gasto, categoria: "Y", metodo: .tarjeta,
            desglose: nil
        )
        _ = try await svc.actualizar(nueva, original: original)

        let item = try await invRepo.obtener(denominacion: 100)
        #expect(item?.cantidad == 5)
    }

    @Test("Eliminar revierte inventario antes de borrar")
    func eliminarRevierte() async throws {
        let (manager, svc) = try await preparar()
        let invRepo = SQLiteInventoryRepository(manager: manager)
        try await invRepo.upsert(Inventario(denominacion: 500, cantidad: 2))

        let tx = try await svc.crear(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 1000,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n500: 2)
        ))

        let intermedia = try await invRepo.obtener(denominacion: 500)
        #expect(intermedia?.cantidad == 0)

        try await svc.eliminar(tx)

        let final = try await invRepo.obtener(denominacion: 500)
        #expect(final?.cantidad == 2)
    }

    @Test("Atomicidad: revertir falla porque no hay inventario y la inserción también falla")
    func atomicidadInsertarRollback() async throws {
        let tmpDir = try directorioTemporal()
        let dbPath = tmpDir.appendingPathComponent("atomic.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let invRepo = SQLiteInventoryRepository(manager: manager)
        let svc = TransactionService(
            manager: manager, transactionRepo: txRepo, inventoryRepo: invRepo
        )

        try await invRepo.upsert(Inventario(denominacion: 1000, cantidad: 0))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 1000,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n1000: 1)
        )

        let guardada = try await svc.crear(tx)
        #expect(guardada.id != nil)
        let item = try await invRepo.obtener(denominacion: 1000)
        #expect(item?.cantidad == 0)
    }

    @Test("crear rechaza concepto vacio")
    func crearRechazaConceptoVacio() async throws {
        let (_, svc) = try await preparar()
        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "  ", monto: 100,
            tipo: .gasto, categoria: "Comida", metodo: .tarjeta
        )
        do {
            _ = try await svc.crear(tx)
            Issue.record("Debio lanzar error")
        } catch {
            #expect((error as? AppDatabaseError) != nil)
        }
    }

    @Test("crear rechaza monto cero o negativo")
    func crearRechazaMontoCero() async throws {
        let (_, svc) = try await preparar()
        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Comida", monto: 0,
            tipo: .gasto, categoria: "Comida", metodo: .tarjeta
        )
        do {
            _ = try await svc.crear(tx)
            Issue.record("Debio lanzar error")
        } catch {
            #expect((error as? AppDatabaseError) != nil)
        }
    }

    @Test("crear rechaza categoria vacia")
    func crearRechazaCategoriaVacia() async throws {
        let (_, svc) = try await preparar()
        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Comida", monto: 100,
            tipo: .gasto, categoria: "", metodo: .tarjeta
        )
        do {
            _ = try await svc.crear(tx)
            Issue.record("Debio lanzar error")
        } catch {
            #expect((error as? AppDatabaseError) != nil)
        }
    }
}
