import Foundation
import Models
import Database
import Services

@main
struct SeederMain {
    static func main() async throws {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("TransactApp", isDirectory: true)
        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        let ruta = appSupport.appendingPathComponent("transactapp.sqlite")

        if FileManager.default.fileExists(atPath: ruta.path) {
            try FileManager.default.removeItem(at: ruta)
        }

        let manager = try DatabaseManager(ruta: ruta)
        try Migrator.aplicar(manager.dbQueue)

        let invRepo = SQLiteInventoryRepository(manager: manager)
        let transRepo = SQLiteTransactionRepository(manager: manager)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let inicialRepo = SQLiteInitialBalanceRepository(manager: manager)

        let invSvc = InventoryService(manager: manager, repo: invRepo)
        let transSvc = TransactionService(
            manager: manager,
            transactionRepo: transRepo,
            inventoryRepo: invRepo
        )
        let loanSvc = LoanService(manager: manager, loanRepo: loanRepo)
        let subSvc = SubscriptionService(manager: manager, subRepo: subRepo, transactionRepo: transRepo)

        _ = invSvc
        let inventarioInicial: [Inventario] = [
            Inventario(denominacion: 1000, cantidad: 2),
            Inventario(denominacion: 500, cantidad: 0),
            Inventario(denominacion: 200, cantidad: 1),
            Inventario(denominacion: 100, cantidad: 1),
            Inventario(denominacion: 50, cantidad: 0),
            Inventario(denominacion: 20, cantidad: 0),
            Inventario(denominacion: 10, cantidad: 0),
            Inventario(denominacion: 5, cantidad: 0)
        ]
        for item in inventarioInicial {
            try await invRepo.upsert(item)
        }
        let saldoInicial = SaldoInicial(
            efectivo: 2200,
            tarjeta: 300,
            inventarioInicial: inventarioInicial
        )
        try await inicialRepo.guardar(saldoInicial, inventario: inventarioInicial)

        let cal = Calendar.current
        let hoy = Date()
        func fechaStr(dias: Int) -> String {
            let d = cal.date(byAdding: .day, value: dias, to: hoy)!
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: d)
        }
        func fecha(dias: Int) -> Date {
            cal.date(byAdding: .day, value: dias, to: hoy)!
        }
        func hora(min: Int) -> Date {
            cal.date(byAdding: .minute, value: min, to: hoy)!
        }

        _ = try await transSvc.crear(Transaccion(
            fecha: fecha(dias: -3),
            hora: hora(min: -120),
            concepto: "Supermercado",
            monto: 250,
            tipo: .gasto,
            categoria: "Comida",
            metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 1, n50: 1)
        ))
        _ = try await transSvc.crear(Transaccion(
            fecha: fecha(dias: -2),
            hora: hora(min: -200),
            concepto: "Pago quincenal",
            monto: 3000,
            tipo: .ingreso,
            categoria: "Salario",
            metodo: .tarjeta,
            desglose: nil
        ))
        _ = try await transSvc.crear(Transaccion(
            fecha: fecha(dias: -1),
            hora: hora(min: -300),
            concepto: "Gasolina",
            monto: 80,
            tipo: .gasto,
            categoria: "Transporte",
            metodo: .efectivo,
            desglose: DesgloseBilletes(n50: 1, n20: 1, n10: 1)
        ))
        _ = try await transSvc.crear(Transaccion(
            fecha: fecha(dias: 0),
            hora: hora(min: -60),
            concepto: "Café + libro",
            monto: 120,
            tipo: .gasto,
            categoria: "Ocio",
            metodo: .tarjeta,
            desglose: nil
        ))

        _ = try await loanSvc.crear(Prestamo(
            persona: "Carlos",
            concepto: "Anticipo para evento",
            monto: 500,
            tipo: .meDeben,
            fecha: fecha(dias: -10),
            afectaBalance: false,
            montoPagado: 200,
            notas: "Pagar antes del 15"
        ))
        _ = try await loanSvc.crear(Prestamo(
            persona: "Mamá",
            concepto: "Compra del súper",
            monto: 350,
            tipo: .debo,
            fecha: fecha(dias: -5),
            afectaBalance: true,
            montoPagado: 0,
            notas: nil
        ))

        let manana = cal.date(byAdding: .day, value: 1, to: hoy)!
        let en3 = cal.date(byAdding: .day, value: 3, to: hoy)!
        let en15 = cal.date(byAdding: .day, value: 15, to: hoy)!

        _ = try await subSvc.crear(Suscripcion(
            concepto: "Netflix",
            monto: 299,
            categoria: "Entretenimiento",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -30),
            proximoCobro: manana,
            notas: "Plan familiar",
            duracionMeses: nil,
            activa: true
        ))
        _ = try await subSvc.crear(Suscripcion(
            concepto: "Spotify",
            monto: 199,
            categoria: "Entretenimiento",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -60),
            proximoCobro: en3,
            notas: nil,
            duracionMeses: nil,
            activa: true
        ))
        _ = try await subSvc.crear(Suscripcion(
            concepto: "Gimnasio",
            monto: 600,
            categoria: "Salud",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -90),
            proximoCobro: en15,
            notas: "Pago anual en 12 cuotas",
            duracionMeses: 12,
            activa: true
        ))

        print("OK Datos demo cargados en \(ruta.path)")
    }
}
