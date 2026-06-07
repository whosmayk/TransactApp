import Foundation
import Models
import Database

public final class BusquedaGlobalService: Sendable {
    private let transactions: any TransactionRepository
    private let loans: any LoanRepository
    private let subscriptions: any SubscriptionRepository

    public init(
        transactions: any TransactionRepository,
        loans: any LoanRepository,
        subscriptions: any SubscriptionRepository
    ) {
        self.transactions = transactions
        self.loans = loans
        self.subscriptions = subscriptions
    }

    public func buscar(query: String, limite: Int = 20) async -> [ResultadoBusqueda] {
        let aguja = Self.normalizar(query)
        guard !aguja.isEmpty else { return [] }

        async let txResults = buscarTransacciones(aguja: aguja)
        async let prestamoResults = buscarPrestamos(aguja: aguja)
        async let suscResults = buscarSuscripciones(aguja: aguja)

        let (tx, pr, su) = await (txResults, prestamoResults, suscResults)
        return Array((tx + pr + su).sorted(by: { $0.score > $1.score }).prefix(limite).map(\.resultado))
    }

    public func emparejar(needle: String, haystack: String) -> Int? {
        Self.emparejarScore(needle: needle, haystack: haystack)
    }

    private func buscarTransacciones(aguja: String) async -> [(resultado: ResultadoBusqueda, score: Int)] {
        do {
            let lista = try await transactions.listar()
            return lista.compactMap { tx -> (ResultadoBusqueda, Int)? in
                let s1 = Self.emparejarScore(needle: aguja, haystack: tx.concepto) ?? 0
                let s2 = Self.emparejarScore(needle: aguja, haystack: tx.categoria) ?? 0
                let score = max(s1, s2)
                guard score > 0, tx.id != nil else { return nil }
                return (.transaccion(tx), score)
            }
        } catch {
            return []
        }
    }

    private func buscarPrestamos(aguja: String) async -> [(resultado: ResultadoBusqueda, score: Int)] {
        do {
            let lista = try await loans.listar()
            return lista.compactMap { pr -> (ResultadoBusqueda, Int)? in
                let s1 = Self.emparejarScore(needle: aguja, haystack: pr.persona) ?? 0
                let s2 = Self.emparejarScore(needle: aguja, haystack: pr.concepto) ?? 0
                let s3 = pr.notas.map { Self.emparejarScore(needle: aguja, haystack: $0) ?? 0 } ?? 0
                let score = max(s1, s2, s3)
                guard score > 0, pr.id != nil else { return nil }
                return (.prestamo(pr), score)
            }
        } catch {
            return []
        }
    }

    private func buscarSuscripciones(aguja: String) async -> [(resultado: ResultadoBusqueda, score: Int)] {
        do {
            let lista = try await subscriptions.listar()
            return lista.compactMap { su -> (ResultadoBusqueda, Int)? in
                let s1 = Self.emparejarScore(needle: aguja, haystack: su.concepto) ?? 0
                let s2 = Self.emparejarScore(needle: aguja, haystack: su.categoria) ?? 0
                let s3 = su.notas.map { Self.emparejarScore(needle: aguja, haystack: $0) ?? 0 } ?? 0
                let score = max(s1, s2, s3)
                guard score > 0, su.id != nil else { return nil }
                return (.suscripcion(su), score)
            }
        } catch {
            return []
        }
    }

    static func emparejarScore(needle: String, haystack: String) -> Int? {
        let n = normalizar(needle)
        let h = normalizar(haystack)
        if n.isEmpty { return 1 }
        if h.isEmpty { return nil }
        if h == n { return 1000 }
        if h.hasPrefix(n) { return 500 }
        if h.contains(n) { return 200 }
        if contieneSubsequence(needle: n, haystack: h) { return 50 }
        return nil
    }

    static func normalizar(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func contieneSubsequence(needle: String, haystack: String) -> Bool {
        let n = Array(needle)
        let h = Array(haystack)
        var i = 0
        for ch in h {
            if i < n.count && ch == n[i] { i += 1 }
            if i == n.count { return true }
        }
        return i == n.count
    }
}
