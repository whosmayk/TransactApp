import Foundation

public enum EscenarioSimulacion: Equatable, Sendable {
    case gastoUnico(monto: Decimal, metodo: MetodoPago)
    case cancelarSuscripcion(suscripcionId: Int64)
    case nuevaSuscripcion(concepto: String, monto: Decimal, frecuencia: FrecuenciaSuscripcion)
    case reducirCategoria(categoria: String, porcentaje: Decimal)

    public var titulo: String {
        switch self {
        case .gastoUnico: return "Gasto único"
        case .cancelarSuscripcion: return "Cancelar suscripción"
        case .nuevaSuscripcion: return "Nueva suscripción"
        case .reducirCategoria: return "Reducir categoría"
        }
    }

    public var icono: String {
        switch self {
        case .gastoUnico: return "minus.circle"
        case .cancelarSuscripcion: return "repeat.circle.badge.xmark"
        case .nuevaSuscripcion: return "repeat.circle.badge.plus"
        case .reducirCategoria: return "chart.bar.fill"
        }
    }

    public func validar() -> Result<Void, ErrorSimulacion> {
        switch self {
        case .gastoUnico(let monto, _):
            guard monto > 0 else {
                return .failure(.montoInvalido("Captura un monto mayor a 0."))
            }
            return .success(())
        case .nuevaSuscripcion(let concepto, let monto, _):
            guard !concepto.trimmingCharacters(in: .whitespaces).isEmpty else {
                return .failure(.campoVacio("Escribe un concepto para la suscripción."))
            }
            guard monto > 0 else {
                return .failure(.montoInvalido("Captura un monto mayor a 0."))
            }
            return .success(())
        case .reducirCategoria(let categoria, let porcentaje):
            guard !categoria.isEmpty else {
                return .failure(.campoVacio("Elige una categoría."))
            }
            guard porcentaje > 0 && porcentaje <= 100 else {
                return .failure(.montoInvalido("El porcentaje debe estar entre 1 y 100."))
            }
            return .success(())
        case .cancelarSuscripcion:
            return .success(())
        }
    }
}

public enum ErrorSimulacion: LocalizedError, Equatable {
    case montoInvalido(String)
    case campoVacio(String)
    case contextoInsuficiente(String)

    public var errorDescription: String? {
        switch self {
        case .montoInvalido(let m): return m
        case .campoVacio(let m): return m
        case .contextoInsuficiente(let m): return m
        }
    }
}

public struct ContextoSimulacion: Equatable, Sendable {
    public let resumen: ResumenFinanciero
    public let suscripciones: [Suscripcion]
    public let transacciones: [Transaccion]
    public let categorias: [String]
    public let mesesHistorico: Int

    public init(
        resumen: ResumenFinanciero,
        suscripciones: [Suscripcion],
        transacciones: [Transaccion],
        mesesHistorico: Int = 3
    ) {
        self.resumen = resumen
        self.suscripciones = suscripciones
        self.transacciones = transacciones
        var cats = Set(transacciones.map(\.categoria))
        cats.formUnion(suscripciones.map(\.categoria))
        self.categorias = cats.sorted()
        self.mesesHistorico = mesesHistorico
    }

    public var suscripcionesActivas: [Suscripcion] {
        suscripciones.filter { $0.activa }
    }
}

public struct ResultadoSimulacion: Equatable, Sendable {
    public let escenario: EscenarioSimulacion
    public let resumenActual: ResumenFinanciero
    public let resumenSimulado: ResumenFinanciero
    public let impactoInmediato: Decimal
    public let impactoMensualRecurrente: Decimal
    public let impacto12Meses: Decimal
    public let mensaje: String
    public let desgloseCategoria: Decimal?

    public init(
        escenario: EscenarioSimulacion,
        resumenActual: ResumenFinanciero,
        resumenSimulado: ResumenFinanciero,
        impactoInmediato: Decimal,
        impactoMensualRecurrente: Decimal,
        impacto12Meses: Decimal,
        mensaje: String,
        desgloseCategoria: Decimal? = nil
    ) {
        self.escenario = escenario
        self.resumenActual = resumenActual
        self.resumenSimulado = resumenSimulado
        self.impactoInmediato = impactoInmediato
        self.impactoMensualRecurrente = impactoMensualRecurrente
        self.impacto12Meses = impacto12Meses
        self.mensaje = mensaje
        self.desgloseCategoria = desgloseCategoria
    }
}

public extension ResultadoSimulacion {
    var balanceTotalCambio: Decimal {
        resumenSimulado.balanceTotal - resumenActual.balanceTotal
    }

    var balanceRealCambio: Decimal {
        resumenSimulado.balanceReal - resumenActual.balanceReal
    }
}
