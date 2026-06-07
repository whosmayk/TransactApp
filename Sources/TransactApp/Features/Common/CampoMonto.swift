import Foundation

public struct CampoMonto: Equatable, Sendable {
    public var texto: String {
        didSet {
            valor = CampoMonto.parsear(texto)
        }
    }
    public var valor: Decimal

    public init(texto: String = "", valor: Decimal = 0) {
        self.texto = texto
        self.valor = CampoMonto.parsear(texto)
    }

    public static func parsear(_ texto: String) -> Decimal {
        var limpio = texto
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
        if limpio.isEmpty { return 0 }

        let tieneComa = limpio.contains(",")
        let tienePunto = limpio.contains(".")

        if tieneComa && !tienePunto {
            limpio = limpio.replacingOccurrences(of: ",", with: "")
        } else if tienePunto && !tieneComa {
        } else if tieneComa && tienePunto {
            if let lastPunto = limpio.lastIndex(of: "."),
               let lastComa = limpio.lastIndex(of: ",") {
                if lastPunto > lastComa {
                    limpio = limpio.replacingOccurrences(of: ",", with: "")
                } else {
                    limpio = limpio
                        .replacingOccurrences(of: ".", with: "")
                        .replacingOccurrences(of: ",", with: ".")
                }
            }
        }

        if let dec = Decimal(string: limpio, locale: Locale(identifier: "en_US_POSIX")) {
            return dec
        }
        if let dec = Decimal(string: limpio, locale: Locale(identifier: "es_MX")) {
            return dec
        }
        return 0
    }

    public mutating func actualizar(texto nuevo: String) {
        texto = nuevo
        valor = CampoMonto.parsear(nuevo)
    }

    public func formatear() -> String {
        if valor == 0 { return texto.isEmpty ? "" : "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "es_MX")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let ns = NSDecimalNumber(decimal: valor)
        return formatter.string(from: ns) ?? "\(valor)"
    }
}

