import Foundation
import SwiftUI
import Models
import Services
import Database

@MainActor
public final class SimuladorGastosViewModel: ObservableObject {
    public enum TipoEscenario: String, CaseIterable, Identifiable {
        case gastoUnico = "Gasto único"
        case cancelarSuscripcion = "Cancelar suscripción"
        case nuevaSuscripcion = "Nueva suscripción"
        case reducirCategoria = "Reducir categoría"

        public var id: String { rawValue }

        public var icono: String {
            switch self {
            case .gastoUnico: return "minus.circle"
            case .cancelarSuscripcion: return "repeat.circle.badge.xmark"
            case .nuevaSuscripcion: return "repeat.circle.badge.plus"
            case .reducirCategoria: return "chart.bar.fill"
            }
        }
    }

    @Published public var tipoSeleccionado: TipoEscenario = .gastoUnico
    @Published public var montoTexto: String = ""
    @Published public var metodo: MetodoPago = .efectivo
    @Published public var suscripcionSeleccionadaId: Int64?
    @Published public var conceptoNueva: String = ""
    @Published public var frecuenciaNueva: FrecuenciaSuscripcion = .mensual
    @Published public var categoriaSeleccionada: String = ""
    @Published public var porcentajeTexto: String = "20"

    @Published public private(set) var resultado: ResultadoSimulacion?
    @Published public private(set) var cargandoContexto: Bool = false
    @Published public var errorValidacion: String?
    @Published public var errorCalculo: String?

    private let service: SimuladorGastosService
    private let transactionRepo: any TransactionRepository
    private let loanRepo: any LoanRepository
    private let subscriptionRepo: any SubscriptionRepository
    private let initialBalanceRepo: any InitialBalanceRepository
    private let projectionService: ProjectionService
    private let mesesHistorico: Int

    public init(
        service: SimuladorGastosService = SimuladorGastosService(),
        transactionRepo: any TransactionRepository,
        loanRepo: any LoanRepository,
        subscriptionRepo: any SubscriptionRepository,
        initialBalanceRepo: any InitialBalanceRepository,
        projectionService: ProjectionService,
        mesesHistorico: Int = 3
    ) {
        self.service = service
        self.transactionRepo = transactionRepo
        self.loanRepo = loanRepo
        self.subscriptionRepo = subscriptionRepo
        self.initialBalanceRepo = initialBalanceRepo
        self.projectionService = projectionService
        self.mesesHistorico = mesesHistorico
    }

    public func cargarContexto() async {
        cargandoContexto = true
        defer { cargandoContexto = false }
        do {
            let suscripciones = try await subscriptionRepo.listar()
            self.suscripciones = suscripciones.filter { $0.activa }
            if suscripcionSeleccionadaId == nil {
                self.suscripcionSeleccionadaId = self.suscripciones.first?.id
            }
            let transacciones = try await transactionRepo.listar()
            let prestamos = try await loanRepo.listar()
            let saldoInicial = try await initialBalanceRepo.obtener()
            let resumen = CalculosFinancieros.resumen(
                saldoInicial: saldoInicial,
                transacciones: transacciones,
                prestamos: prestamos
            )
            self.contextoActual = ContextoSimulacion(
                resumen: resumen,
                suscripciones: suscripciones,
                transacciones: transacciones,
                mesesHistorico: mesesHistorico
            )
            if categoriaSeleccionada.isEmpty {
                self.categoriaSeleccionada = self.contextoActual?.categorias.first ?? ""
            }
        } catch {
            self.errorCalculo = "No pude cargar el contexto: \(error.localizedDescription)"
        }
    }

    @Published public private(set) var contextoActual: ContextoSimulacion?
    @Published public private(set) var suscripciones: [Suscripcion] = []

    public var escenarioVigente: EscenarioSimulacion? {
        construirEscenario()
    }

    public func simular() {
        errorValidacion = nil
        errorCalculo = nil
        guard let contexto = contextoActual else {
            errorCalculo = "Cargando datos… espera un momento."
            return
        }
        guard let escenario = construirEscenario() else {
            return
        }
        let res = service.simular(escenario: escenario, contexto: contexto)
        switch res {
        case .success(let r):
            self.resultado = r
        case .failure(let err):
            self.resultado = nil
            self.errorValidacion = err.errorDescription
        }
    }

    public func restablecer() {
        resultado = nil
        errorValidacion = nil
        errorCalculo = nil
    }

    private func construirEscenario() -> EscenarioSimulacion? {
        switch tipoSeleccionado {
        case .gastoUnico:
            guard let monto = parsearDecimal(montoTexto), monto > 0 else {
                errorValidacion = "Captura un monto mayor a 0."
                return nil
            }
            return .gastoUnico(monto: monto, metodo: metodo)
        case .cancelarSuscripcion:
            guard let id = suscripcionSeleccionadaId else {
                errorValidacion = "Elige una suscripción para cancelar."
                return nil
            }
            return .cancelarSuscripcion(suscripcionId: id)
        case .nuevaSuscripcion:
            let concepto = conceptoNueva.trimmingCharacters(in: .whitespaces)
            guard !concepto.isEmpty else {
                errorValidacion = "Escribe un concepto para la suscripción."
                return nil
            }
            guard let monto = parsearDecimal(montoTexto), monto > 0 else {
                errorValidacion = "Captura un monto mayor a 0."
                return nil
            }
            return .nuevaSuscripcion(concepto: concepto, monto: monto, frecuencia: frecuenciaNueva)
        case .reducirCategoria:
            guard !categoriaSeleccionada.isEmpty else {
                errorValidacion = "Elige una categoría."
                return nil
            }
            guard let porcentaje = parsearDecimal(porcentajeTexto), porcentaje > 0, porcentaje <= 100 else {
                errorValidacion = "El porcentaje debe estar entre 1 y 100."
                return nil
            }
            return .reducirCategoria(categoria: categoriaSeleccionada, porcentaje: porcentaje)
        }
    }

    private func parsearDecimal(_ texto: String) -> Decimal? {
        let limpio = texto
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard !limpio.isEmpty else { return nil }
        return Decimal(string: limpio)
    }
}
