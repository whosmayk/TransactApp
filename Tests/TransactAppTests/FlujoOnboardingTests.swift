import Foundation
import Testing
import Models
import Database

@Suite("Flujo Onboarding + Dashboard")
struct FlujoOnboardingTests {

    @Test("DB vacía → no hay saldo inicial → guardar lo crea → ya existe")
    func flujoCompleto() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("flujo.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let initialRepo = SQLiteInitialBalanceRepository(manager: manager)
        let inventoryRepo = SQLiteInventoryRepository(manager: manager)

        let inicial = try await initialRepo.obtener()
        #expect(inicial == nil)

        try await initialRepo.guardar(
            SaldoInicial(efectivo: 1500, tarjeta: 800, inventarioInicial: []),
            inventario: [
                Inventario(denominacion: 1000, cantidad: 1),
                Inventario(denominacion: 200, cantidad: 2)
            ]
        )

        let recargado = try await initialRepo.obtener()
        #expect(recargado?.efectivo == 1500)
        #expect(recargado?.tarjeta == 800)

        let inventario = try await inventoryRepo.listar()
        #expect(inventario.count == 2)
        let total = inventario.reduce(into: Decimal(0)) { $0 += $1.subtotal }
        #expect(total == 1400)
    }

    @Test("Resumen con saldo + transacción + préstamo refleja el cálculo")
    func resumenConSaldoYMovimientos() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("resumen.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let initialRepo = SQLiteInitialBalanceRepository(manager: manager)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let inventoryRepo = SQLiteInventoryRepository(manager: manager)

        try await initialRepo.guardar(
            SaldoInicial(efectivo: 1000, tarjeta: 500, inventarioInicial: []),
            inventario: []
        )
        let now = Date()
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: now, hora: now,
            concepto: "Sueldo", monto: 3000,
            tipo: .ingreso, categoria: "Trabajo", metodo: .tarjeta
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: now, hora: now,
            concepto: "Comida", monto: 200,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo
        ))
        _ = try await loanRepo.insertar(Prestamo(
            id: nil, persona: "Banco", concepto: "TC",
            monto: 1500, tipo: .debo, fecha: now, afectaBalance: true
        ))

        let saldo = try await initialRepo.obtener()
        let txs = try await txRepo.listar()
        let prestamos = try await loanRepo.listar()
        let inventario = try await inventoryRepo.listar()

        let resumen = CalculosFinancieros.resumen(
            saldoInicial: saldo,
            transacciones: txs,
            prestamos: prestamos
        )

        #expect(resumen.saldoEfectivo == 800)
        #expect(resumen.saldoTarjeta == 3500)
        #expect(resumen.balanceTotal == 4300)
        #expect(resumen.totalDeudas == 1500)
        #expect(resumen.balanceReal == 2800)
        #expect(resumen.totalIngresos == 3000)
        #expect(resumen.totalGastos == 200)
        #expect(inventario.isEmpty)
    }
}
