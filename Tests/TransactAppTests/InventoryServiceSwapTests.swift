import Foundation
import Testing
import Models
import Database
import Services
@testable import TransactApp

@Suite("InventoryService.swap")
struct InventoryServiceSwapTests {

    private func prepararInventarioInicial() async throws -> (DatabaseManager, any InventoryRepository, InventoryService) {
        let tmpDir = try directorioTemporal()
        let dbPath = tmpDir.appendingPathComponent("swap.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let repo = SQLiteInventoryRepository(manager: manager)
        for d in Inventario.denominaciones {
            try await repo.upsert(Inventario(denominacion: d, cantidad: 10))
        }
        let svc = InventoryService(manager: manager, repo: repo)
        return (manager, repo, svc)
    }

    @Test("Swap balanceado aplica cambios y mantiene inventario")
    func swapBalanceado() async throws {
        let (_, repo, svc) = try await prepararInventarioInicial()

        try await svc.swap(
            origen: [1000: 2],
            destino: [500: 4]
        )

        let inv1000 = try await repo.obtener(denominacion: 1000)
        let inv500 = try await repo.obtener(denominacion: 500)
        #expect(inv1000?.cantidad == 8)
        #expect(inv500?.cantidad == 14)
    }

    @Test("Swap no balanceado lanza error y no modifica inventario")
    func swapNoBalanceado() async throws {
        let (_, repo, svc) = try await prepararInventarioInicial()

        await #expect(throws: CambioBilleteError.self) {
            try await svc.swap(
                origen: [1000: 1],
                destino: [500: 1]
            )
        }

        let inv1000 = try await repo.obtener(denominacion: 1000)
        let inv500 = try await repo.obtener(denominacion: 500)
        #expect(inv1000?.cantidad == 10)
        #expect(inv500?.cantidad == 10)
    }

    @Test("Swap con inventario insuficiente lanza error y no modifica inventario")
    func swapInventarioInsuficiente() async throws {
        let (_, repo, svc) = try await prepararInventarioInicial()

        await #expect(throws: CambioBilleteError.self) {
            try await svc.swap(
                origen: [1000: 50],
                destino: [500: 100]
            )
        }

        let inv1000 = try await repo.obtener(denominacion: 1000)
        let inv500 = try await repo.obtener(denominacion: 500)
        #expect(inv1000?.cantidad == 10)
        #expect(inv500?.cantidad == 10)
    }
}
