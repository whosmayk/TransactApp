import Foundation

public struct DesgloseBilletes: Codable, Equatable, Sendable {
    public var n1000: Int
    public var n500: Int
    public var n200: Int
    public var n100: Int
    public var n50: Int
    public var n20: Int
    public var n10: Int
    public var n5: Int

    public init(
        n1000: Int = 0,
        n500: Int = 0,
        n200: Int = 0,
        n100: Int = 0,
        n50: Int = 0,
        n20: Int = 0,
        n10: Int = 0,
        n5: Int = 0
    ) {
        self.n1000 = n1000
        self.n500 = n500
        self.n200 = n200
        self.n100 = n100
        self.n50 = n50
        self.n20 = n20
        self.n10 = n10
        self.n5 = n5
    }

    public static let denominaciones: [Int] = [1000, 500, 200, 100, 50, 20, 10, 5]

    public func cantidad(de denominacion: Int) -> Int {
        switch denominacion {
        case 1000: return n1000
        case 500:  return n500
        case 200:  return n200
        case 100:  return n100
        case 50:   return n50
        case 20:   return n20
        case 10:   return n10
        case 5:    return n5
        default:   return 0
        }
    }

    public mutating func setCantidad(_ cantidad: Int, de denominacion: Int) {
        switch denominacion {
        case 1000: n1000 = cantidad
        case 500:  n500 = cantidad
        case 200:  n200 = cantidad
        case 100:  n100 = cantidad
        case 50:   n50 = cantidad
        case 20:   n20 = cantidad
        case 10:   n10 = cantidad
        case 5:    n5 = cantidad
        default:   break
        }
    }

    public var totalBilletes: Int {
        n1000 + n500 + n200 + n100 + n50 + n20 + n10 + n5
    }

    public var subtotal: Decimal {
        var total: Decimal = 0
        for denom in Self.denominaciones {
            total += Decimal(denom) * Decimal(cantidad(de: denom))
        }
        return total
    }

    public var estaVacio: Bool { totalBilletes == 0 }

    public static func autoDesglose(monto: Decimal) -> DesgloseBilletes {
        var restante = monto
        var d = DesgloseBilletes()
        for denom in denominaciones {
            if restante <= 0 { break }
            let denomDecimal = Decimal(denom)
            let division = restante / denomDecimal
            var quotient = Decimal()
            var entrada = division
            NSDecimalRound(&quotient, &entrada, 0, .down)
            let cantInt = NSDecimalNumber(decimal: quotient).intValue
            if cantInt > 0 {
                d.setCantidad(cantInt, de: denom)
                restante -= denomDecimal * Decimal(cantInt)
            }
        }
        return d
    }
}
