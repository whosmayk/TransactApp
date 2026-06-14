import Foundation

public struct Transaccion: Identifiable, Codable, Equatable, Sendable, Syncable {
    public var id: Int64?
    public var fecha: Date
    public var hora: Date
    public var concepto: String
    public var monto: Decimal
    public var tipo: TipoTransaccion
    public var categoria: String
    public var metodo: MetodoPago
    public var desglose: DesgloseBilletes?

    public var uuid: String
    public var updatedAt: Date
    public var isDeleted: Bool

    public init(
        id: Int64? = nil,
        fecha: Date,
        hora: Date,
        concepto: String,
        monto: Decimal,
        tipo: TipoTransaccion,
        categoria: String,
        metodo: MetodoPago,
        desglose: DesgloseBilletes? = nil,
        uuid: String? = nil,
        updatedAt: Date = Date(),
        isDeleted: Bool = false
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
        self.uuid = uuid ?? Self.generarUUID()
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    public var afectaEfectivo: Bool { metodo == .efectivo }

    public var montoFirmado: Decimal {
        switch tipo {
        case .ingreso: return monto
        case .gasto: return -monto
        }
    }
}
