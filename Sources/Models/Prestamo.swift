import Foundation

public struct Prestamo: Identifiable, Codable, Equatable, Sendable {
    public var id: Int64?
    public var persona: String
    public var concepto: String
    public var monto: Decimal
    public var tipo: TipoPrestamo
    public var fecha: Date
    public var afectaBalance: Bool
    public var montoPagado: Decimal
    public var notas: String?

    public init(
        id: Int64? = nil,
        persona: String,
        concepto: String,
        monto: Decimal,
        tipo: TipoPrestamo,
        fecha: Date,
        afectaBalance: Bool = false,
        montoPagado: Decimal = 0,
        notas: String? = nil
    ) {
        self.id = id
        self.persona = persona
        self.concepto = concepto
        self.monto = monto
        self.tipo = tipo
        self.fecha = fecha
        self.afectaBalance = afectaBalance
        self.montoPagado = montoPagado
        self.notas = notas
    }

    public var saldoPendiente: Decimal {
        var saldo = monto - montoPagado
        if saldo < 0 { saldo = 0 }
        return saldo
    }

    public var estaPagado: Bool {
        saldoPendiente <= 0
    }

    public var porcentajePagado: Double {
        guard monto > 0 else { return 0 }
        let crudo = NSDecimalNumber(decimal: montoPagado / monto).doubleValue
        return max(0, min(1, crudo))
    }
}
