import Foundation
import Testing
import Models
import Database
import Services
@testable import TransactApp

@Suite("InventoryService")
struct InventoryServiceTests {

    private func preparar() async throws -> (DatabaseManager, any InventoryRepository, InventoryService) {
        let tmpDir = try directorioTemporal()
        let dbPath = tmpDir.appendingPathComponent("inv.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let repo = SQLiteInventoryRepository(manager: manager)
        let svc = InventoryService(manager: manager, repo: repo)
        return (manager, repo, svc)
    }

    @Test("Ingreso en efectivo suma al inventario")
    func ingresoSuma() async throws {
        let (_, repo, svc) = try await preparar()
        try await repo.upsert(Inventario(denominacion: 100, cantidad: 5))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Cobro", monto: 250,
            tipo: .ingreso, categoria: "Trabajo", metodo: .efectivo,
            desglose: DesgloseBilletes(n100: 2, n50: 1)
        )
        try await svc.aplicar(transaccion: tx)

        let item = try await repo.obtener(denominacion: 100)
        #expect(item?.cantidad == 7)
        let item50 = try await repo.obtener(denominacion: 50)
        #expect(item50?.cantidad == 1)
    }

    @Test("Gasto en efectivo resta del inventario")
    func gastoResta() async throws {
        let (_, repo, svc) = try await preparar()
        try await repo.upsert(Inventario(denominacion: 200, cantidad: 5))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Compra", monto: 400,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 2)
        )
        try await svc.aplicar(transaccion: tx)

        let item = try await repo.obtener(denominacion: 200)
        #expect(item?.cantidad == 3)
    }

    @Test("Gasto no baja de cero (clamp)")
    func gastoClamp() async throws {
        let (_, repo, svc) = try await preparar()
        try await repo.upsert(Inventario(denominacion: 1000, cantidad: 1))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 5000,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n1000: 5)
        )
        try await svc.aplicar(transaccion: tx)

        let item = try await repo.obtener(denominacion: 1000)
        #expect(item?.cantidad == 0)
    }

    @Test("Transacción con tarjeta no toca inventario")
    func tarjetaNoToca() async throws {
        let (_, repo, svc) = try await preparar()
        try await repo.upsert(Inventario(denominacion: 100, cantidad: 5))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Amazon", monto: 500,
            tipo: .gasto, categoria: "Compras", metodo: .tarjeta,
            desglose: nil
        )
        try await svc.aplicar(transaccion: tx)

        let item = try await repo.obtener(denominacion: 100)
        #expect(item?.cantidad == 5)
    }

    @Test("Revertir gasto devuelve los billetes")
    func revertirGasto() async throws {
        let (_, repo, svc) = try await preparar()
        try await repo.upsert(Inventario(denominacion: 100, cantidad: 5))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 200,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n100: 2)
        )
        try await svc.aplicar(transaccion: tx)
        try await svc.revertir(transaccion: tx)

        let item = try await repo.obtener(denominacion: 100)
        #expect(item?.cantidad == 5)
    }

    @Test("Revertir ingreso resta los billetes")
    func revertirIngreso() async throws {
        let (_, repo, svc) = try await preparar()
        try await repo.upsert(Inventario(denominacion: 50, cantidad: 0))

        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 100,
            tipo: .ingreso, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n50: 2)
        )
        try await svc.aplicar(transaccion: tx)
        try await svc.revertir(transaccion: tx)

        let item = try await repo.obtener(denominacion: 50)
        #expect(item?.cantidad == 0)
    }
}
