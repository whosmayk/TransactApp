import Foundation
import Models
import Database

public struct NotificacionSuscripcion: Identifiable, Equatable, Sendable {
    public let id: Int64
    public let concepto: String
    public let monto: Decimal
    public let proximoCobro: Date
    public let diasRestantes: Int

    public init(id: Int64, concepto: String, monto: Decimal, proximoCobro: Date, diasRestantes: Int) {
        self.id = id
        self.concepto = concepto
        self.monto = monto
        self.proximoCobro = proximoCobro
        self.diasRestantes = diasRestantes
    }

    public var mensaje: String {
        if diasRestantes < 0 {
            return "Vencida hace \(-diasRestantes) día\(-diasRestantes == 1 ? "" : "s")"
        }
        if diasRestantes == 0 {
            return "Vence hoy"
        }
        if diasRestantes == 1 {
            return "Vence mañana"
        }
        return "Vence en \(diasRestantes) días"
    }
}

public actor SubscriptionNotifier {
    private let service: SubscriptionService
    private let ventana: Int

    public init(service: SubscriptionService, ventana: Int = 3) {
        self.service = service
        self.ventana = ventana
    }

    public func revisar() async -> [NotificacionSuscripcion] {
        let ahora = Date()
        let proximas: [Suscripcion]
        do {
            proximas = try await service.listarProximasAVencer(dentroDe: ventana)
        } catch {
            return []
        }
        return proximas.compactMap { s in
            guard let id = s.id else { return nil }
            return NotificacionSuscripcion(
                id: id,
                concepto: s.concepto,
                monto: s.monto,
                proximoCobro: s.proximoCobro,
                diasRestantes: s.diasHastaProximoCobro(referencia: ahora)
            )
        }
    }

    public func marcarNotificadas(_ ids: [Int64]) async {
        for id in ids {
            try? await service.marcarNotificada(id: id)
        }
    }
}
