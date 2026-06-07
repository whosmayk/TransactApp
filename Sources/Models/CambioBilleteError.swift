import Foundation

public enum CambioBilleteError: LocalizedError, Equatable {
    case cambioNoBalanceado(totalOrigen: Decimal, totalDestino: Decimal)
    case inventarioInsuficiente(denominacion: Int, disponible: Int, solicitado: Int)
    case sinMovimientos

    public var errorDescription: String? {
        switch self {
        case .cambioNoBalanceado(let origen, let destino):
            let fmt: (Decimal) -> String = { valor in
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = Locale(identifier: "es_MX")
                formatter.currencyCode = "MXN"
                formatter.maximumFractionDigits = 2
                formatter.minimumFractionDigits = 2
                return formatter.string(from: NSDecimalNumber(decimal: valor)) ?? "\(valor)"
            }
            return "El total que quitas (\(fmt(origen))) debe ser igual al que agregas (\(fmt(destino)))."
        case .inventarioInsuficiente(let denom, let disponible, let solicitado):
            return "Inventario insuficiente: tienes \(disponible) billete\(disponible == 1 ? "" : "s") de $\(denom) y pediste \(solicitado)."
        case .sinMovimientos:
            return "No has seleccionado ningún cambio."
        }
    }
}
