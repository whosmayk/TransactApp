import Foundation

public struct SaldoInicial: Codable, Equatable, Sendable {
    public var efectivo: Decimal
    public var tarjeta: Decimal
    public var fechaCreacion: Date
    public var inventarioInicial: [Inventario]

    public init(
        efectivo: Decimal,
        tarjeta: Decimal,
        fechaCreacion: Date = Date(),
        inventarioInicial: [Inventario] = []
    ) {
        self.efectivo = efectivo
        self.tarjeta = tarjeta
        self.fechaCreacion = fechaCreacion
        self.inventarioInicial = inventarioInicial
    }
}
