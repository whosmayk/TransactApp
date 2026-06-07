import Foundation

public struct DatosReporte: Sendable {
    public let saldoInicialEfectivo: Decimal
    public let saldoInicialTarjeta: Decimal
    public let saldoEfectivo: Decimal
    public let saldoTarjeta: Decimal
    public let balanceTotal: Decimal
    public let totalDeudas: Decimal
    public let balanceReal: Decimal
    public let totalIngresos: Decimal
    public let totalGastos: Decimal
    public let transacciones: [Transaccion]
    public let inventario: [Inventario]
    public let prestamos: [Prestamo]
    public let suscripciones: [Suscripcion]

    public init(
        saldoInicialEfectivo: Decimal,
        saldoInicialTarjeta: Decimal,
        saldoEfectivo: Decimal,
        saldoTarjeta: Decimal,
        balanceTotal: Decimal,
        totalDeudas: Decimal,
        balanceReal: Decimal,
        totalIngresos: Decimal,
        totalGastos: Decimal,
        transacciones: [Transaccion],
        inventario: [Inventario],
        prestamos: [Prestamo],
        suscripciones: [Suscripcion]
    ) {
        self.saldoInicialEfectivo = saldoInicialEfectivo
        self.saldoInicialTarjeta = saldoInicialTarjeta
        self.saldoEfectivo = saldoEfectivo
        self.saldoTarjeta = saldoTarjeta
        self.balanceTotal = balanceTotal
        self.totalDeudas = totalDeudas
        self.balanceReal = balanceReal
        self.totalIngresos = totalIngresos
        self.totalGastos = totalGastos
        self.transacciones = transacciones
        self.inventario = inventario
        self.prestamos = prestamos
        self.suscripciones = suscripciones
    }

    public static let vacio = DatosReporte(
        saldoInicialEfectivo: 0,
        saldoInicialTarjeta: 0,
        saldoEfectivo: 0,
        saldoTarjeta: 0,
        balanceTotal: 0,
        totalDeudas: 0,
        balanceReal: 0,
        totalIngresos: 0,
        totalGastos: 0,
        transacciones: [],
        inventario: [],
        prestamos: [],
        suscripciones: []
    )
}

public struct ProyeccionMes: Identifiable, Sendable {
    public let offset: Int
    public let fecha: Date
    public let ingreso: Decimal
    public let pagosRecurrentes: Decimal
    public let saldo: Decimal
    public let acumulado: Decimal
    public let totalGeneral: Decimal

    public var id: Int { offset }
}

public struct ConfiguracionProyeccion: Sendable, Equatable {
    public var ingresoMensualBase: Decimal
    public var factorDiario: Decimal
    public var claveTito: String
    public var horizonteMeses: Int

    public init(
        ingresoMensualBase: Decimal = 900,
        factorDiario: Decimal = 30,
        claveTito: String = "tito",
        horizonteMeses: Int = 18
    ) {
        self.ingresoMensualBase = ingresoMensualBase
        self.factorDiario = factorDiario
        self.claveTito = claveTito
        self.horizonteMeses = horizonteMeses
    }
}
