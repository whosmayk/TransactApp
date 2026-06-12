import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class GestionSuscripcionesViewModel: ObservableObject {
    @Published var suscripciones: [Suscripcion] = []
    @Published var cargando: Bool = false
    @Published var error: String?
    private var necesitaRecarga = false
    @Published var filtro: FiltroSuscripcion = .todas

    enum FiltroSuscripcion: String, CaseIterable, Identifiable {
        case todas
        case activas
        case inactivas
        case proximas

        var id: String { rawValue }

        var etiqueta: String {
            switch self {
            case .todas: return "Todas"
            case .activas: return "Activas"
            case .inactivas: return "Inactivas"
            case .proximas: return "Por vencer"
            }
        }
    }

    let service: SubscriptionService
    private let subRepo: any SubscriptionRepository

    init(service: SubscriptionService, subRepo: any SubscriptionRepository) {
        self.service = service
        self.subRepo = subRepo
    }

    var suscripcionesVisibles: [Suscripcion] {
        switch filtro {
        case .todas: return suscripciones
        case .activas: return suscripciones.filter { $0.activa }
        case .inactivas: return suscripciones.filter { !$0.activa }
        case .proximas: return suscripciones.filter { $0.estaProximaAVencer() }
        }
    }

    var totalMensual: Decimal {
        suscripciones
            .filter { $0.activa }
            .reduce(into: Decimal(0)) { $0 += $1.montoMensual() }
    }

    var activas: Int {
        suscripciones.filter { $0.activa }.count
    }

    var proximas: Int {
        suscripciones.filter { $0.estaProximaAVencer() }.count
    }

    func cargar() async {
        guard !cargando else {
            necesitaRecarga = true
            return
        }
        cargando = true
        error = nil
        defer {
            cargando = false
            if necesitaRecarga {
                necesitaRecarga = false
                Task { await cargar() }
            }
        }
        do {
            suscripciones = try await subRepo.listar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func alternarActiva(_ suscripcion: Suscripcion) async {
        guard let id = suscripcion.id else { return }
        do {
            _ = try await service.alternarActiva(id: id)
            await cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func registrarCobro(_ suscripcion: Suscripcion) async {
        guard let id = suscripcion.id else { return }
        do {
            _ = try await service.registrarCobro(id: id)
            await cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func eliminar(_ suscripcion: Suscripcion) async {
        guard let id = suscripcion.id else { return }
        do {
            try await service.eliminar(id: id)
            await cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
