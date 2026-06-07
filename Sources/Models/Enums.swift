import Foundation

public enum TipoTransaccion: String, Codable, CaseIterable, Sendable, Hashable {
    case ingreso = "Ingreso"
    case gasto = "Gasto"

    public var titulo: String {
        switch self {
        case .ingreso: return LocalizableKey.enumTipoIngreso.localized()
        case .gasto: return LocalizableKey.enumTipoGasto.localized()
        }
    }
}

public enum MetodoPago: String, Codable, CaseIterable, Sendable, Hashable {
    case efectivo = "Efectivo"
    case tarjeta = "Tarjeta"

    public var titulo: String {
        switch self {
        case .efectivo: return LocalizableKey.enumMetodoEfectivo.localized()
        case .tarjeta: return LocalizableKey.enumMetodoTarjeta.localized()
        }
    }
}

public enum TipoPrestamo: String, Codable, CaseIterable, Sendable, Hashable {
    case meDeben = "Me deben"
    case debo = "Debo"

    public var titulo: String {
        switch self {
        case .meDeben: return LocalizableKey.enumPrestamoMeDeben.localized()
        case .debo: return LocalizableKey.enumPrestamoDebo.localized()
        }
    }
}

public enum FrecuenciaSuscripcion: String, Codable, CaseIterable, Sendable, Hashable {
    case mensual = "Mensual"
    case trimestral = "Trimestral"
    case anual = "Anual"

    public var mesesPorCiclo: Int {
        switch self {
        case .mensual: return 1
        case .trimestral: return 3
        case .anual: return 12
        }
    }

    public var titulo: String {
        switch self {
        case .mensual: return LocalizableKey.enumFrecuenciaMensual.localized()
        case .trimestral: return LocalizableKey.enumFrecuenciaTrimestral.localized()
        case .anual: return LocalizableKey.enumFrecuenciaAnual.localized()
        }
    }
}
