import Foundation
import Testing
import GRDB
@testable import Database
@testable import Services
import Models

@Suite("BusquedaGlobalService")
struct BusquedaGlobalServiceTests {

    private func crearDB() throws -> (DatabaseManager, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactApp-Busqueda-\(UUID().uuidString).sqlite")
        let db = try DatabaseManager(ruta: url)
        return (db, url)
    }

    @Test("Coincidencia exacta gana sobre prefijo, substring y subsequence")
    func emparejamientoExacto() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "Netflix", haystack: "Netflix") == 1000)
        #expect(BusquedaGlobalService.emparejarScore(needle: "netflix", haystack: "NETFLIX") == 1000)
    }

    @Test("Prefijo sin match exacto obtiene 500")
    func emparejamientoPrefijo() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "Net", haystack: "Netflix") == 500)
        #expect(BusquedaGlobalService.emparejarScore(needle: "UBER", haystack: "uber eats") == 500)
    }

    @Test("Substring en medio obtiene 200")
    func emparejamientoSubstring() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "flix", haystack: "Netflix") == 200)
    }

    @Test("Subsequence (caracteres en orden) obtiene 50")
    func emparejamientoSubsequence() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "nflx", haystack: "Netflix") == 50)
        #expect(BusquedaGlobalService.emparejarScore(needle: "sptfy", haystack: "Spotify Premium") == 50)
    }

    @Test("Sin coincidencia devuelve nil")
    func emparejamientoSinMatch() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "xyz", haystack: "Netflix") == nil)
    }

    @Test("Aguja vacía devuelve score 1 (match trivial)")
    func emparejamientoVacio() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "", haystack: "Netflix") == 1)
        #expect(BusquedaGlobalService.emparejarScore(needle: "   ", haystack: "Netflix") == 1)
    }

    @Test("Acentos y mayúsculas se ignoran (normalización)")
    func emparejamientoAcentos() {
        #expect(BusquedaGlobalService.emparejarScore(needle: "nino", haystack: "Niño") == 1000)
        #expect(BusquedaGlobalService.emparejarScore(needle: "Transporte", haystack: "TRANSPORTE") == 1000)
        #expect(BusquedaGlobalService.emparejarScore(needle: "uber", haystack: "Uber Eats") == 500)
    }

    @Test("Buscar vacío devuelve lista vacía")
    func buscarVacio() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let svc = BusquedaGlobalService(
            transactions: SQLiteTransactionRepository(manager: db),
            loans: SQLiteLoanRepository(manager: db),
            subscriptions: SQLiteSubscriptionRepository(manager: db)
        )
        let res = await svc.buscar(query: "")
        #expect(res.isEmpty)
    }

    @Test("Buscar por substring en concepto de transacción devuelve el resultado")
    func buscarTransaccionConcepto() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let txRepo = SQLiteTransactionRepository(manager: db)
        let svc = BusquedaGlobalService(
            transactions: txRepo,
            loans: SQLiteLoanRepository(manager: db),
            subscriptions: SQLiteSubscriptionRepository(manager: db)
        )
        let tx = Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Café Starbucks", monto: 65,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo
        )
        _ = try await txRepo.insertar(tx)

        let res = await svc.buscar(query: "star")
        #expect(res.count == 1)
        guard case .transaccion(let guardada) = res[0] else {
            Issue.record("Se esperaba un resultado de tipo transacción")
            return
        }
        #expect(guardada.id ?? 0 > 0)
        #expect(guardada.concepto == "Café Starbucks")
        #expect(guardada.tipo == .gasto)
    }

    @Test("Buscar por persona de préstamo devuelve el resultado")
    func buscarPrestamoPersona() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let prRepo = SQLiteLoanRepository(manager: db)
        let svc = BusquedaGlobalService(
            transactions: SQLiteTransactionRepository(manager: db),
            loans: prRepo,
            subscriptions: SQLiteSubscriptionRepository(manager: db)
        )
        let pr = Prestamo(
            id: nil, persona: "Ana López", concepto: "Préstamo cena",
            monto: 500, tipo: .meDeben, fecha: Date(), afectaBalance: false
        )
        _ = try await prRepo.insertar(pr)

        let res = await svc.buscar(query: "ana")
        #expect(res.count == 1)
        guard case .prestamo(let guardado) = res[0] else {
            Issue.record("Se esperaba un resultado de tipo préstamo")
            return
        }
        #expect(guardado.persona == "Ana López")
        #expect(guardado.tipo == .meDeben)
    }

    @Test("Buscar por notas de suscripción (sin acento) matchea con acentos")
    func buscarSuscripcionNotas() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let suRepo = SQLiteSubscriptionRepository(manager: db)
        let svc = BusquedaGlobalService(
            transactions: SQLiteTransactionRepository(manager: db),
            loans: SQLiteLoanRepository(manager: db),
            subscriptions: suRepo
        )
        let cal = Calendar.current
        let inicio = cal.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()
        let su = Suscripcion(
            id: nil, concepto: "Música", monto: 199, categoria: "Entretenimiento",
            frecuencia: .mensual, tipo: .gasto, fechaInicio: inicio, proximoCobro: inicio,
            notas: "Plan familiar para niños"
        )
        _ = try await suRepo.insertar(su)

        let res = await svc.buscar(query: "nino")
        #expect(res.count == 1)
        guard case .suscripcion(let guardada) = res[0] else {
            Issue.record("Se esperaba un resultado de tipo suscripción")
            return
        }
        #expect(guardada.concepto == "Música")
    }

    @Test("Sin coincidencias devuelve lista vacía")
    func buscarSinCoincidencias() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let txRepo = SQLiteTransactionRepository(manager: db)
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Café", monto: 50, tipo: .gasto,
            categoria: "Comida", metodo: .efectivo
        ))
        let svc = BusquedaGlobalService(
            transactions: txRepo,
            loans: SQLiteLoanRepository(manager: db),
            subscriptions: SQLiteSubscriptionRepository(manager: db)
        )
        let res = await svc.buscar(query: "xyz123")
        #expect(res.isEmpty)
    }

    @Test("Resultados se ordenan por relevancia: exacto > prefijo > substring > subsequence")
    func ordenarPorRelevancia() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let txRepo = SQLiteTransactionRepository(manager: db)
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Comida rápida", monto: 100, tipo: .gasto,
            categoria: "Comida", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Café rápido", monto: 50, tipo: .gasto,
            categoria: "Comida", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "Restaurante", monto: 200, tipo: .gasto,
            categoria: "Comida", metodo: .efectivo
        ))
        let svc = BusquedaGlobalService(
            transactions: txRepo,
            loans: SQLiteLoanRepository(manager: db),
            subscriptions: SQLiteSubscriptionRepository(manager: db)
        )

        let res = await svc.buscar(query: "rap")
        #expect(res.count == 2)
        #expect(res[0].titulo == "Café rápido")
        #expect(res[1].titulo == "Comida rápida")
    }

    @Test("Límite de resultados se respeta")
    func limiteDeResultados() async throws {
        let (db, url) = try crearDB()
        defer { try? FileManager.default.removeItem(at: url) }
        let txRepo = SQLiteTransactionRepository(manager: db)
        for i in 1...30 {
            _ = try await txRepo.insertar(Transaccion(
                id: nil, fecha: Date(), hora: Date(),
                concepto: "Gasto \(i)", monto: Decimal(i), tipo: .gasto,
                categoria: "X", metodo: .efectivo
            ))
        }
        let svc = BusquedaGlobalService(
            transactions: txRepo,
            loans: SQLiteLoanRepository(manager: db),
            subscriptions: SQLiteSubscriptionRepository(manager: db)
        )
        let res = await svc.buscar(query: "gasto", limite: 5)
        #expect(res.count == 5)
    }
}
