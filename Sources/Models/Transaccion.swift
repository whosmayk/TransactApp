import Foundation

public struct Transaccion: Identifiable, Codable, Equatable, Sendable {
    public var id: Int64?
    public var fecha: Date
    public var hora: Date
    public var concepto: String
    public var monto: Decimal
    public var tipo: TipoTransaccion
    public var categoria: String
    public var metodo: MetodoPago
    public var desglose: DesgloseBilletes?

    public init(
        id: Int64? = nil,
        fecha: Date,
        hora: Date,
        concepto: String,
        monto: Decimal,
        tipo: TipoTransaccion,
        categoria: String,
        metodo: MetodoPago,
        desglose: DesgloseBilletes? = nil
    ) {
        self.id = id
        self.fecha = fecha
        self.hora = hora
        self.concepto = concepto
        self.monto = monto
        self.tipo = tipo
        self.categoria = categoria
        self.metodo = metodo
        self.desglose = desglose
    }

    public var afectaEfectivo: Bool { metodo == .efectivo }

    public var montoFirmado: Decimal {
        switch tipo {
        case .ingreso: return monto
        case .gasto: return -monto
        }
    }
}
