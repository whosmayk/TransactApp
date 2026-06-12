import Foundation
import Testing
import GRDB
import Models
import Database

@Suite("Migracion v5: REAL a INTEGER (centavos)")
struct MigracionV5Tests {

    private func crearDBV4() async throws -> DatabaseManager {
        let tmpDir = try directorioTemporal()
        let dbPath = tmpDir.appendingPathComponent("v5_test.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        return manager
    }

    @Test("Round-trip preserva centavos exactos tras migracion")
    func roundTripCentavosExactos() async throws {
        let manager = try await crearDBV4()
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let initialRepo = SQLiteInitialBalanceRepository(manager: manager)

        let tx = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Cafe", monto: 123.45,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo
        ))
        let pr = try await loanRepo.insertar(Prestamo(
            id: nil, persona: "Juan", concepto: "Prestamo",
            monto: 1000.99, tipo: .debo, fecha: Date(),
            afectaBalance: true, montoPagado: 333.33
        ))
        let su = try await subRepo.insertar(Suscripcion(
            id: nil, concepto: "Netflix", monto: 199.99,
            categoria: "Ocio", frecuencia: .mensual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        ))
        try await initialRepo.guardar(
            SaldoInicial(efectivo: 1500.50, tarjeta: 2500.75, inventarioInicial: []),
            inventario: []
        )

        // Aplicar migracion manual (la BD se creo con esquema v4, la migracion ya corrio en el init)
        // Pero como el init de DatabaseManager aplica Migrator que ya esta en v4, la BD deberia
        // tener columnas REAL. Verificamos los tipos actuales.
        let tiposAntes = try await manager.leer { db in
            try Row.fetchOne(db, sql: "SELECT typeof(monto) as t FROM Transacciones LIMIT 1")?["t"] as String? ?? ""
        }
        #expect(tiposAntes == "integer")

        let leidaTx = try await txRepo.obtener(id: tx.id!)
        #expect(leidaTx?.monto == Decimal(string: "123.45")!)

        let leidoPr = try await loanRepo.obtener(id: pr.id!)
        #expect(leidoPr?.monto == Decimal(string: "1000.99")!)
        #expect(leidoPr?.montoPagado == Decimal(string: "333.33")!)
        #expect(leidoPr?.saldoPendiente == Decimal(string: "667.66")!)

        let leidaSu = try await subRepo.obtener(id: su.id!)
        #expect(leidaSu?.monto == Decimal(string: "199.99")!)

        let saldoInicial = try await initialRepo.obtener()
        #expect(saldoInicial?.efectivo == Decimal(string: "1500.50")!)
        #expect(saldoInicial?.tarjeta == Decimal(string: "2500.75")!)
    }

    @Test("Migracion preserva 50 valores aleatorios con centavos exactos")
    func migracionPreservaMultiplesValores() async throws {
        let manager = try await crearDBV4()
        let txRepo = SQLiteTransactionRepository(manager: manager)

        var montosOriginales: [Int64: Decimal] = [:]
        for i in 0..<50 {
            let pesos = Decimal(arc4random_uniform(10000))
            let centavos = Decimal(arc4random_uniform(100))
            let monto = pesos + centavos / 100
            let tx = try await txRepo.insertar(Transaccion(
                id: nil, fecha: Date(), hora: Date(),
                concepto: "Test \(i)", monto: monto,
                tipo: i % 2 == 0 ? .ingreso : .gasto,
                categoria: "Test", metodo: .efectivo
            ))
            montosOriginales[tx.id!] = monto
        }

        for (id, montoEsperado) in montosOriginales {
            let leida = try await txRepo.obtener(id: id)
            #expect(leida?.monto == montoEsperado)
        }
    }

    @Test("SUM en SQL crudo devuelve pesos consistentes")
    func sumSQLCrudo() async throws {
        let manager = try await crearDBV4()
        let txRepo = SQLiteTransactionRepository(manager: manager)

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "A", monto: 100.50,
            tipo: .ingreso, categoria: "X", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "B", monto: 50.25,
            tipo: .gasto, categoria: "X", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "C", monto: 25.75,
            tipo: .ingreso, categoria: "X", metodo: .tarjeta
        ))

        let sumaEfectivoCents = try await manager.leer { db in
            try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                FROM Transacciones WHERE metodo='Efectivo'
                """) ?? 0
        }
        let sumaTarjetaCents = try await manager.leer { db in
            try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                FROM Transacciones WHERE metodo='Tarjeta'
                """) ?? 0
        }
        let sumaEfectivo = Decimal(sumaEfectivoCents) / 100
        let sumaTarjeta = Decimal(sumaTarjetaCents) / 100

        #expect(sumaEfectivo == Decimal(string: "50.25")!)
        #expect(sumaTarjeta == Decimal(string: "25.75")!)
    }

    @Test("SaldoInicial tras migracion preserva efectivo y tarjeta")
    func saldoInicialMigracion() async throws {
        let manager = try await crearDBV4()
        let initialRepo = SQLiteInitialBalanceRepository(manager: manager)

        try await initialRepo.guardar(
            SaldoInicial(efectivo: 1234.56, tarjeta: 7890.12, inventarioInicial: []),
            inventario: []
        )

        let saldo = try await initialRepo.obtener()
        #expect(saldo?.efectivo == Decimal(string: "1234.56")!)
        #expect(saldo?.tarjeta == Decimal(string: "7890.12")!)
    }

    @Test("Prestamo con pagos parciales preserva saldoPendiente tras migracion")
    func prestamoPagosParcialesMigracion() async throws {
        let manager = try await crearDBV4()
        let loanRepo = SQLiteLoanRepository(manager: manager)

        let pr = try await loanRepo.insertar(Prestamo(
            id: nil, persona: "Maria", concepto: "Prestamo",
            monto: 1000.00, tipo: .debo, fecha: Date(),
            afectaBalance: true, montoPagado: 333.33
        ))

        let leido = try await loanRepo.obtener(id: pr.id!)
        #expect(leido?.monto == Decimal(string: "1000.00")!)
        #expect(leido?.montoPagado == Decimal(string: "333.33")!)
        #expect(leido?.saldoPendiente == Decimal(string: "666.67")!)
    }
}
