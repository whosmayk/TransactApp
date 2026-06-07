import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
public final class ProyeccionViewModel: ObservableObject {
    @Published public private(set) var proyeccion: ProyeccionMensual?
    @Published public private(set) var cargando: Bool = false
    @Published public var error: String?

    private let projectionService: ProjectionService
    private let transactionRepo: any TransactionRepository
    private let subscriptionRepo: any SubscriptionRepository
    private let configurationService: ConfigurationService

    public init(
        projectionService: ProjectionService,
        transactionRepo: any TransactionRepository,
        subscriptionRepo: any SubscriptionRepository,
        configurationService: ConfigurationService
    ) {
        self.projectionService = projectionService
        self.transactionRepo = transactionRepo
        self.subscriptionRepo = subscriptionRepo
        self.configurationService = configurationService
    }

    public func cargar() async {
        cargando = true
        defer { cargando = false }
        do {
            let calendar = Calendar.current
            let referencia = Date()
            let inicioMes = calendar.startOfMonth(referencia) ?? referencia

            let transacciones = try await transactionRepo.listarFiltrado(
                mes: inicioMes,
                tipo: nil,
                categoria: nil,
                texto: nil,
                limite: 1000,
                orden: .fechaDesc
            )

            let suscripciones = try await subscriptionRepo.listar()
            let activas = suscripciones.filter { $0.activa }

            let config = try await configurationService.obtener()
            let mesesAtras = config.ventanaHistoricoMeses
            let haceMeses = calendar.date(byAdding: .month, value: -mesesAtras, to: referencia) ?? referencia
            let todasTx = try await transactionRepo.listarFiltrado(
                mes: nil,
                tipo: nil,
                categoria: nil,
                texto: nil,
                limite: 5000,
                orden: .fechaDesc
            )

            let todasFiltradas = todasTx.filter { tx in
                tx.fecha >= haceMeses && tx.fecha < inicioMes
            }

            let historico = ProjectionService.resumirHistorico(
                transacciones: todasFiltradas,
                mesesAtras: mesesAtras,
                referencia: referencia
            )

            self.proyeccion = projectionService.proyectar(
                transaccionesMesActual: transacciones,
                suscripcionesActivas: activas,
                historicoMeses: historico,
                metaAhorroMensual: config.metaAhorroMensual,
                referencia: referencia
            )
            self.error = nil
        } catch {
            self.error = LocalizableKey.proyeccionError.localized(error.localizedDescription)
        }
    }
}
