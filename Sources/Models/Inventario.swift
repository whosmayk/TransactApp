import Foundation

public struct Inventario: Identifiable, Codable, Equatable, Sendable {
    public var denominacion: Int
    public var cantidad: Int
    public var actualizadoEn: Date

    public var id: Int { denominacion }

    public init(denominacion: Int, cantidad: Int, actualizadoEn: Date = Date()) {
        self.denominacion = denominacion
        self.cantidad = cantidad
        self.actualizadoEn = actualizadoEn
    }

    public var subtotal: Decimal {
        Decimal(denominacion) * Decimal(cantidad)
    }

    public static let denominaciones: [Int] = [1000, 500, 200, 100, 50, 20, 10, 5]
}
