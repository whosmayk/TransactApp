import Foundation
import Testing
import GRDB
import Models
import Database
import Services
@testable import TransactApp

@Suite("LoanService: ciclo completo")
struct LoanServiceTests {

    @Test("Crear → listar → editar → eliminar")
    func cicloCompleto() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("prestamos.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let svc = LoanService(manager: manager, loanRepo: loanRepo)

        let nuevo = try await svc.crear(Prestamo(
            persona: "Ana", concepto: "Cena", monto: 1000,
            tipo: .meDeben, fecha: Date(), afectaBalance: false
        ))
        #expect(nuevo.id != nil)

        let lista = try await loanRepo.listar()
        #expect(lista.count == 1)

        let actualizado = try await svc.actualizar(Prestamo(
            id: nuevo.id, persona: "Ana María", concepto: "Cena", monto: 1200,
            tipo: .meDeben, fecha: Date(), afectaBalance: false
        ))
        #expect(actualizado.persona == "Ana María")
        #expect(actualizado.monto == 1200)

        try await svc.eliminar(id: actualizado.id!)
        let vacia = try await loanRepo.listar()
        #expect(vacia.isEmpty)
    }

    @Test("registrarPago suma al monto pagado sin pasar el total")
    func registrarPago() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("pago.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let svc = LoanService(manager: manager, loanRepo: loanRepo)

        let p = try await svc.crear(Prestamo(
            persona: "Beto", concepto: "Préstamo", monto: 1000,
            tipo: .debo, fecha: Date(), afectaBalance: true
        ))

        let despues1 = try await svc.registrarPago(id: p.id!, monto: 300)
        #expect(despues1.montoPagado == 300)
        #expect(despues1.saldoPendiente == 700)

        let despues2 = try await svc.registrarPago(id: p.id!, monto: 800)
        #expect(despues2.montoPagado == 1000)
        #expect(despues2.estaPagado)
    }

    @Test("Validación: persona vacía lanza error")
    func personaVacia() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("v.sqlite"))
        let svc = LoanService(manager: manager, loanRepo: SQLiteLoanRepository(manager: manager))

        do {
            _ = try await svc.crear(Prestamo(
                persona: "   ", concepto: "X", monto: 100,
                tipo: .meDeben, fecha: Date()
            ))
            Issue.record("Debió lanzar error")
        } catch {
            // esperado
        }
    }

    @Test("Validación: monto 0 lanza error")
    func montoCero() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("v.sqlite"))
        let svc = LoanService(manager: manager, loanRepo: SQLiteLoanRepository(manager: manager))

        do {
            _ = try await svc.crear(Prestamo(
                persona: "Ana", concepto: "X", monto: 0,
                tipo: .meDeben, fecha: Date()
            ))
            Issue.record("Debió lanzar error")
        } catch {
            // esperado
        }
    }

    @Test("sumarAfectaBalance solo cuenta préstamos Debo afecta balance")
    func sumaAfectaBalance() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("s.sqlite"))
        let loanRepo = SQLiteLoanRepository(manager: manager)

        _ = try await loanRepo.insertar(Prestamo(
            persona: "A", concepto: "x", monto: 500, tipo: .debo,
            fecha: Date(), afectaBalance: true
        ))
        _ = try await loanRepo.insertar(Prestamo(
            persona: "B", concepto: "x", monto: 300, tipo: .debo,
            fecha: Date(), afectaBalance: false
        ))
        _ = try await loanRepo.insertar(Prestamo(
            persona: "C", concepto: "x", monto: 200, tipo: .meDeben,
            fecha: Date(), afectaBalance: true
        ))

        let total = try await loanRepo.sumarAfectaBalance()
        #expect(total == 500)
    }

    @Test("Migración v2: DB con v1 funciona con campos nuevos en nil")
    func migracionV2() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("v1.sqlite")

        let queue = try DatabaseQueue(path: dbPath.path)
        try await queue.write { db in
            try db.execute(sql: """
                CREATE TABLE SaldoInicial (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    efectivo REAL NOT NULL DEFAULT 0,
                    tarjeta REAL NOT NULL DEFAULT 0,
                    fechaCreacion TEXT NOT NULL,
                    inventarioJson TEXT NOT NULL DEFAULT '[]'
                );
                CREATE TABLE Prestamos (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    persona TEXT NOT NULL,
                    concepto TEXT NOT NULL,
                    monto REAL NOT NULL,
                    tipo TEXT NOT NULL CHECK (tipo IN ('Me deben','Debo')),
                    fecha TEXT NOT NULL,
                    afectaBalance INTEGER NOT NULL DEFAULT 0
                );
                """)
            try db.execute(
                sql: "INSERT INTO Prestamos (persona, concepto, monto, tipo, fecha, afectaBalance) VALUES (?,?,?,?,?,?)",
                arguments: ["Ana", "x", 100, "Me deben", "2026-05-01", 0]
            )
        }

        let manager = try DatabaseManager(ruta: dbPath)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let lista = try await loanRepo.listar()
        #expect(lista.count == 1)
        #expect(lista[0].montoPagado == 0)
        #expect(lista[0].notas == nil)
    }
}

@Suite("SubscriptionService: ciclo completo")
struct SubscriptionServiceTests {

    @Test("Crear → listar → editar → eliminar")
    func cicloCompleto() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("s.sqlite"))
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let svc = SubscriptionService(manager: manager, subRepo: subRepo, transactionRepo: SQLiteTransactionRepository(manager: manager))

        let nuevo = try await svc.crear(Suscripcion(
            concepto: "Netflix", monto: 199, categoria: "Entretenimiento",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        ))
        #expect(nuevo.id != nil)

        let lista = try await subRepo.listar()
        #expect(lista.count == 1)

        let actualizado = try await svc.actualizar(Suscripcion(
            id: nuevo.id, concepto: "Netflix Premium", monto: 269,
            categoria: "Entretenimiento", frecuencia: .mensual,
            tipo: .gasto, fechaInicio: Date(), proximoCobro: Date()
        ))
        #expect(actualizado.monto == 269)

        try await svc.eliminar(id: actualizado.id!)
        let vacia = try await subRepo.listar()
        #expect(vacia.isEmpty)
    }

    @Test("registrarCobro avanza próximo cobro por la frecuencia")
    func registrarCobro() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("c.sqlite"))
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let svc = SubscriptionService(manager: manager, subRepo: subRepo, transactionRepo: SQLiteTransactionRepository(manager: manager))

        let inicio = FormatoFecha.parsearFecha("2026-01-15")!
        let cobro = FormatoFecha.parsearFecha("2026-02-15")!
        let s = try await svc.crear(Suscripcion(
            concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: inicio, proximoCobro: cobro
        ))

        let despues = try await svc.registrarCobro(id: s.id!)
        let comp = Calendar.current.dateComponents(
            [.year, .month], from: cobro, to: despues.proximoCobro
        )
        #expect(comp.month == 1)
        #expect(despues.notificado == false)
    }

    @Test("alternarActiva cambia el flag")
    func alternar() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("a.sqlite"))
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let svc = SubscriptionService(manager: manager, subRepo: subRepo, transactionRepo: SQLiteTransactionRepository(manager: manager))

        let s = try await svc.crear(Suscripcion(
            concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        ))
        #expect(s.activa)

        let desactivada = try await svc.alternarActiva(id: s.id!)
        #expect(!desactivada.activa)
    }

    @Test("listarProximasAVencer respeta ventana y filtra notificadas")
    func proximasAVencer() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("p.sqlite"))
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let svc = SubscriptionService(manager: manager, subRepo: subRepo, transactionRepo: SQLiteTransactionRepository(manager: manager))

        let ahora = Date()
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: ahora)!
        let en5Dias = Calendar.current.date(byAdding: .day, value: 5, to: ahora)!

        let s1 = try await svc.crear(Suscripcion(
            concepto: "Mañana", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: manana
        ))
        _ = try await svc.crear(Suscripcion(
            concepto: "En 5", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: en5Dias
        ))

        let proximas = try await svc.listarProximasAVencer(dentroDe: 3)
        #expect(proximas.count == 1)
        #expect(proximas[0].id == s1.id)

        try await svc.marcarNotificada(id: s1.id!)
        let despues = try await svc.listarProximasAVencer(dentroDe: 3)
        #expect(despues.isEmpty)
    }

    @Test("Validación: concepto vacío lanza error")
    func conceptoVacio() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("v.sqlite"))
        let svc = SubscriptionService(
            manager: manager,
            subRepo: SQLiteSubscriptionRepository(manager: manager),
            transactionRepo: SQLiteTransactionRepository(manager: manager)
        )

        do {
            _ = try await svc.crear(Suscripcion(
                concepto: "  ", monto: 100, categoria: "X",
                frecuencia: .mensual, tipo: .gasto,
                fechaInicio: Date(), proximoCobro: Date()
            ))
            Issue.record("Debió lanzar error")
        } catch {
            // esperado
        }
    }
}
