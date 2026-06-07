import Foundation
import Testing
@testable import TransactApp
import Models
import Database

@Suite("DashboardViewModel cálculos")
struct DashboardViewModelTests {

    @Test("Cargar() con ingresos y gastos publica gastosMesFirmado negativo y neto = ingresos + gastos")
    @MainActor
    func cargarCalculaGastosFirmadoYNeto() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("dash.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)

        let initialRepo = SQLiteInitialBalanceRepository(manager: manager)
        let inventoryRepo = SQLiteInventoryRepository(manager: manager)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let subRepo = SQLiteSubscriptionRepository(manager: manager)

        try await initialRepo.guardar(
            SaldoInicial(efectivo: 100, tarjeta: 0, inventarioInicial: []),
            inventario: []
        )

        let now = Date()
        let cal = Calendar.current
        let inicioMes = cal.dateInterval(of: .month, for: now)?.start ?? now
        let finMes = cal.dateInterval(of: .month, for: now)?.end
            ?? now.addingTimeInterval(86400)
        let esteMes = inicioMes.addingTimeInterval(3600)
        let mesPasado = cal.date(byAdding: .month, value: -1, to: inicioMes)!
            .addingTimeInterval(3600)

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: esteMes, hora: esteMes,
            concepto: "Sueldo", monto: 5000,
            tipo: .ingreso, categoria: "Trabajo", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: esteMes, hora: esteMes,
            concepto: "Comida", monto: 800,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: mesPasado, hora: mesPasado,
            concepto: "Antiguo", monto: 2000,
            tipo: .gasto, categoria: "X", metodo: .efectivo
        ))

        let vm = await DashboardViewModel(
            initialBalanceRepo: initialRepo,
            inventoryRepo: inventoryRepo,
            transactionRepo: txRepo,
            loanRepo: loanRepo,
            subscriptionRepo: subRepo
        )

        await vm.cargar()

        #expect(vm.ingresosMes == Decimal(5000), "Ingresos del mes actual")
        #expect(vm.gastosMesFirmado == Decimal(-800), "Gastos del mes con signo negativo")
        #expect(vm.netoMes == Decimal(4200), "Neto = ingresos + gastosFirmado")
        #expect(vm.gastosMesFirmado < 0, "gastosMesFirmado debe ser negativo")
        #expect(vm.ingresosHistorico == Decimal(5000), "Ingresado histórico")
        #expect(vm.gastosHistoricoFirmado == Decimal(-2800), "Gastado histórico = -2800")
        #expect(vm.gastosHistoricoFirmado < 0, "gastosHistoricoFirmado debe ser negativo")
    }
}
