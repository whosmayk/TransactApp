import Foundation
import Models
import Database
import Services

@main
struct ScreenshotSeeder {
    static func main() async throws {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dir = cwd.appendingPathComponent("screenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ruta = dir.appendingPathComponent("transactapp-demo.db")

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

        let transSvc = TransactionService(
            manager: manager,
            transactionRepo: transRepo,
            inventoryRepo: invRepo
        )
        let loanSvc = LoanService(manager: manager, loanRepo: loanRepo)
        let subSvc = SubscriptionService(manager: manager, subRepo: subRepo)

        let inventarioInicial: [Inventario] = [
            Inventario(denominacion: 1000, cantidad: 5),
            Inventario(denominacion: 500, cantidad: 3),
            Inventario(denominacion: 200, cantidad: 4),
            Inventario(denominacion: 100, cantidad: 6),
            Inventario(denominacion: 50, cantidad: 10),
            Inventario(denominacion: 20, cantidad: 8),
            Inventario(denominacion: 10, cantidad: 5),
            Inventario(denominacion: 5, cantidad: 3)
        ]
        for item in inventarioInicial {
            try await invRepo.upsert(item)
        }

        let saldoInicial = SaldoInicial(
            efectivo: 10000,
            tarjeta: 15000,
            inventarioInicial: inventarioInicial
        )
        try await inicialRepo.guardar(saldoInicial, inventario: inventarioInicial)

        let cal = Calendar.current
        let hoy = Date()

        func fecha(dias: Int) -> Date {
            cal.date(byAdding: .day, value: dias, to: hoy)!
        }

        func hora(h: Int, m: Int = 0) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: hoy)!
        }

        func transaccion(
            dias: Int,
            horaH: Int,
            horaM: Int,
            concepto: String,
            monto: Decimal,
            tipo: TipoTransaccion,
            categoria: String,
            metodo: MetodoPago,
            n1000: Int = 0, n500: Int = 0, n200: Int = 0,
            n100: Int = 0, n50: Int = 0, n20: Int = 0, n10: Int = 0, n5: Int = 0
        ) async throws {
            let d = DesgloseBilletes(
                n1000: n1000, n500: n500, n200: n200,
                n100: n100, n50: n50, n20: n20, n10: n10, n5: n5
            )
            let desglose: DesgloseBilletes? = metodo == .efectivo ? d : nil
            _ = try await transSvc.crear(Transaccion(
                fecha: fecha(dias: dias),
                hora: hora(h: horaH, m: horaM),
                concepto: concepto,
                monto: monto,
                tipo: tipo,
                categoria: categoria,
                metodo: metodo,
                desglose: desglose
            ))
        }

        // All dates are relative to today (dias: -X means X days ago)

        // Ingresos del mes
        try await transaccion(dias: -28, horaH: 10, horaM: 0, concepto: "Salario quincenal", monto: 8500,
            tipo: .ingreso, categoria: "Salario", metodo: .tarjeta)
        try await transaccion(dias: -14, horaH: 10, horaM: 0, concepto: "Salario quincenal", monto: 8500,
            tipo: .ingreso, categoria: "Salario", metodo: .tarjeta)
        try await transaccion(dias: -21, horaH: 14, horaM: 30, concepto: "Venta de bicicleta", monto: 1500,
            tipo: .ingreso, categoria: "Otros", metodo: .efectivo,
            n1000: 1, n500: 1)
        try await transaccion(dias: -10, horaH: 9, horaM: 15, concepto: "Reembolso gastos médicos", monto: 3200,
            tipo: .ingreso, categoria: "Salud", metodo: .tarjeta)

        // Gastos del mes
        try await transaccion(dias: -27, horaH: 18, horaM: 0, concepto: "Renta departamento", monto: 4500,
            tipo: .gasto, categoria: "Vivienda", metodo: .tarjeta)
        try await transaccion(dias: -25, horaH: 12, horaM: 30, concepto: "Supermercado semanal", monto: 1250,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n1000: 1, n200: 1, n50: 1)
        try await transaccion(dias: -22, horaH: 8, horaM: 0, concepto: "Electricidad CFE", monto: 380,
            tipo: .gasto, categoria: "Servicios", metodo: .tarjeta)
        try await transaccion(dias: -22, horaH: 8, horaM: 5, concepto: "Internet Totalplay", monto: 599,
            tipo: .gasto, categoria: "Servicios", metodo: .tarjeta)
        try await transaccion(dias: -20, horaH: 13, horaM: 0, concepto: "Comida para llevar", monto: 185,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n100: 1, n50: 1, n20: 1, n10: 1, n5: 1)
        try await transaccion(dias: -18, horaH: 10, horaM: 0, concepto: "Gasolina (llenado)", monto: 720,
            tipo: .gasto, categoria: "Transporte", metodo: .efectivo,
            n500: 1, n200: 1, n20: 1)
        try await transaccion(dias: -17, horaH: 20, horaM: 0, concepto: "Cena con amigos", monto: 640,
            tipo: .gasto, categoria: "Ocio", metodo: .tarjeta)
        try await transaccion(dias: -15, horaH: 11, horaM: 0, concepto: "Ropa (Zara)", monto: 1350,
            tipo: .gasto, categoria: "Ropa", metodo: .tarjeta)
        try await transaccion(dias: -12, horaH: 9, horaM: 0, concepto: "Farmacia", monto: 230,
            tipo: .gasto, categoria: "Salud", metodo: .efectivo,
            n200: 1, n20: 1, n10: 1)
        try await transaccion(dias: -11, horaH: 14, horaM: 0, concepto: "Uber aeropuerto", monto: 320,
            tipo: .gasto, categoria: "Transporte", metodo: .tarjeta)
        try await transaccion(dias: -8, horaH: 12, horaM: 0, concepto: "Supermercado semanal", monto: 980,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n500: 1, n200: 2, n50: 1, n20: 1, n10: 1)
        try await transaccion(dias: -7, horaH: 19, horaM: 0, concepto: "Cine + palomitas", monto: 280,
            tipo: .gasto, categoria: "Ocio", metodo: .efectivo,
            n200: 1, n50: 1, n20: 1, n10: 1)
        try await transaccion(dias: -5, horaH: 7, horaM: 0, concepto: "Agua potable", monto: 180,
            tipo: .gasto, categoria: "Servicios", metodo: .tarjeta)
        try await transaccion(dias: -4, horaH: 13, horaM: 0, concepto: "Comida (taquería)", monto: 150,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n100: 1, n50: 1)
        try await transaccion(dias: -3, horaH: 11, horaM: 0, concepto: "Gasolina (medio tanque)", monto: 400,
            tipo: .gasto, categoria: "Transporte", metodo: .efectivo,
            n200: 2)
        try await transaccion(dias: -2, horaH: 16, horaM: 0, concepto: "Libros (Gandhi)", monto: 520,
            tipo: .gasto, categoria: "Ocio", metodo: .tarjeta)
        try await transaccion(dias: -1, horaH: 10, horaM: 0, concepto: "Mercado de frutas", monto: 120,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n100: 1, n20: 1)

        // Mes pasado
        try await transaccion(dias: -35, horaH: 10, horaM: 0, concepto: "Salario quincenal", monto: 8500,
            tipo: .ingreso, categoria: "Salario", metodo: .tarjeta)
        try await transaccion(dias: -40, horaH: 18, horaM: 0, concepto: "Renta departamento", monto: 4500,
            tipo: .gasto, categoria: "Vivienda", metodo: .tarjeta)
        try await transaccion(dias: -38, horaH: 12, horaM: 0, concepto: "Supermercado", monto: 1100,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n1000: 1, n100: 1)
        try await transaccion(dias: -36, horaH: 9, horaM: 0, concepto: "Electricidad CFE", monto: 410,
            tipo: .gasto, categoria: "Servicios", metodo: .tarjeta)
        try await transaccion(dias: -33, horaH: 14, horaM: 0, concepto: "Cena aniversario", monto: 1200,
            tipo: .gasto, categoria: "Ocio", metodo: .tarjeta)
        try await transaccion(dias: -30, horaH: 11, horaM: 0, concepto: "Gasolina", monto: 680,
            tipo: .gasto, categoria: "Transporte", metodo: .efectivo,
            n500: 1, n100: 1, n50: 1, n20: 1, n10: 1)
        try await transaccion(dias: -28, horaH: 16, horaM: 0, concepto: "Consultoría freelance", monto: 2500,
            tipo: .ingreso, categoria: "Salario", metodo: .tarjeta)
        try await transaccion(dias: -26, horaH: 12, horaM: 0, concepto: "Comida (sushi)", monto: 350,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n200: 1, n100: 1, n50: 1)
        try await transaccion(dias: -24, horaH: 10, horaM: 0, concepto: "Ferretería (reparación)", monto: 280,
            tipo: .gasto, categoria: "Hogar", metodo: .efectivo,
            n200: 1, n50: 1, n20: 1, n10: 1)
        try await transaccion(dias: -22, horaH: 20, horaM: 0, concepto: "Streaming (estreno)", monto: 80,
            tipo: .gasto, categoria: "Ocio", metodo: .tarjeta)
        try await transaccion(dias: -20, horaH: 13, horaM: 0, concepto: "Ropa deportiva", monto: 890,
            tipo: .gasto, categoria: "Ropa", metodo: .tarjeta)

        // Hace 2 meses
        try await transaccion(dias: -60, horaH: 10, horaM: 0, concepto: "Salario", monto: 17000,
            tipo: .ingreso, categoria: "Salario", metodo: .tarjeta)
        try await transaccion(dias: -62, horaH: 18, horaM: 0, concepto: "Renta", monto: 4500,
            tipo: .gasto, categoria: "Vivienda", metodo: .tarjeta)
        try await transaccion(dias: -58, horaH: 12, horaM: 0, concepto: "Súper quincenal", monto: 1350,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n1000: 1, n200: 1, n100: 1, n50: 1)
        try await transaccion(dias: -55, horaH: 9, horaM: 0, concepto: "CFE", monto: 370,
            tipo: .gasto, categoria: "Servicios", metodo: .tarjeta)
        try await transaccion(dias: -52, horaH: 11, horaM: 0, concepto: "Llantas nuevas", monto: 3200,
            tipo: .gasto, categoria: "Transporte", metodo: .tarjeta)
        try await transaccion(dias: -50, horaH: 20, horaM: 0, concepto: "Cena familiar", monto: 850,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n500: 1, n200: 1, n100: 1, n50: 1)
        try await transaccion(dias: -48, horaH: 15, horaM: 0, concepto: "Venta de mueble", monto: 2000,
            tipo: .ingreso, categoria: "Otros", metodo: .efectivo,
            n1000: 2)
        try await transaccion(dias: -45, horaH: 10, horaM: 0, concepto: "Dentista", monto: 600,
            tipo: .gasto, categoria: "Salud", metodo: .tarjeta)
        try await transaccion(dias: -42, horaH: 13, horaM: 0, concepto: "Comida rápida", monto: 175,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            n100: 1, n50: 1, n20: 1, n5: 1)

        // Préstamos
        _ = try await loanSvc.crear(Prestamo(
            persona: "Carlos",
            concepto: "Entrada concierto",
            monto: 1200,
            tipo: .meDeben,
            fecha: fecha(dias: -20),
            afectaBalance: false,
            montoPagado: 0,
            notas: "Me paga la próxima semana"
        ))
        _ = try await loanSvc.crear(Prestamo(
            persona: "Mamá",
            concepto: "Depósito para el súper",
            monto: 500,
            tipo: .debo,
            fecha: fecha(dias: -40),
            afectaBalance: true,
            montoPagado: 200,
            notas: nil
        ))
        _ = try await loanSvc.crear(Prestamo(
            persona: "Luis",
            concepto: "Cena cumpleaños",
            monto: 350,
            tipo: .debo,
            fecha: fecha(dias: -15),
            afectaBalance: false,
            montoPagado: 350,
            notas: "Pagado ✔"
        ))

        // Suscripciones
        let manana = cal.date(byAdding: .day, value: 1, to: hoy)!
        let en3 = cal.date(byAdding: .day, value: 3, to: hoy)!
        let en10 = cal.date(byAdding: .day, value: 10, to: hoy)!

        _ = try await subSvc.crear(Suscripcion(
            concepto: "Netflix Premium",
            monto: 299,
            categoria: "Entretenimiento",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -120),
            proximoCobro: manana,
            notas: "Plan 4K compartido",
            duracionMeses: nil,
            activa: true
        ))
        _ = try await subSvc.crear(Suscripcion(
            concepto: "Spotify Duo",
            monto: 179,
            categoria: "Entretenimiento",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -240),
            proximoCobro: manana,
            notas: nil,
            duracionMeses: nil,
            activa: true
        ))
        _ = try await subSvc.crear(Suscripcion(
            concepto: "Gimnasio SportsWorld",
            monto: 699,
            categoria: "Salud",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -90),
            proximoCobro: en3,
            notas: "Pase anual",
            duracionMeses: 12,
            activa: true
        ))
        _ = try await subSvc.crear(Suscripcion(
            concepto: "iCloud 2TB",
            monto: 219,
            categoria: "Servicios",
            frecuencia: .mensual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -180),
            proximoCobro: en10,
            notas: nil,
            duracionMeses: nil,
            activa: true
        ))
        _ = try await subSvc.crear(Suscripcion(
            concepto: "Amazon Prime",
            monto: 99,
            categoria: "Servicios",
            frecuencia: .anual,
            tipo: .gasto,
            fechaInicio: fecha(dias: -60),
            proximoCobro: fecha(dias: 305),
            notas: "Renovación anual",
            duracionMeses: nil,
            activa: true
        ))

        print("OK Base de datos demo generada: \(ruta.path)")
        print("  \(35) transacciones, 5 suscripciones, 3 préstamos, 8 denominaciones")
    }
}
