import Foundation

public struct ResumenFinanciero: Equatable, Sendable {
    public let saldoInicialEfectivo: Decimal
    public let saldoInicialTarjeta: Decimal
    public let saldoEfectivo: Decimal
    public let saldoTarjeta: Decimal
    public let balanceTotal: Decimal
    public let totalDeudas: Decimal
    public let totalMeDeben: Decimal
    public let balanceReal: Decimal
    public let totalIngresos: Decimal
    public let totalGastos: Decimal

    public init(
        saldoInicialEfectivo: Decimal,
        saldoInicialTarjeta: Decimal,
        saldoEfectivo: Decimal,
        saldoTarjeta: Decimal,
        balanceTotal: Decimal,
        totalDeudas: Decimal,
        totalMeDeben: Decimal,
        balanceReal: Decimal,
        totalIngresos: Decimal,
        totalGastos: Decimal
    ) {
        self.saldoInicialEfectivo = saldoInicialEfectivo
        self.saldoInicialTarjeta = saldoInicialTarjeta
        self.saldoEfectivo = saldoEfectivo
        self.saldoTarjeta = saldoTarjeta
        self.balanceTotal = balanceTotal
        self.totalDeudas = totalDeudas
        self.totalMeDeben = totalMeDeben
        self.balanceReal = balanceReal
        self.totalIngresos = totalIngresos
        self.totalGastos = totalGastos
    }

    public static let vacio = ResumenFinanciero(
        saldoInicialEfectivo: 0,
        saldoInicialTarjeta: 0,
        saldoEfectivo: 0,
        saldoTarjeta: 0,
        balanceTotal: 0,
        totalDeudas: 0,
        totalMeDeben: 0,
        balanceReal: 0,
        totalIngresos: 0,
        totalGastos: 0
    )
}

public enum CalculosFinancieros {
    public static func resumen(
        saldoInicial: SaldoInicial?,
        transacciones: [Transaccion],
        prestamos: [Prestamo]
    ) -> ResumenFinanciero {
        let saldoInicialEfectivo = saldoInicial?.efectivo ?? 0
        let saldoInicialTarjeta = saldoInicial?.tarjeta ?? 0

        let deltaEfectivo = transacciones
            .filter { $0.metodo == .efectivo }
            .reduce(into: Decimal(0)) { $0 += $1.montoFirmado }
        let deltaTarjeta = transacciones
            .filter { $0.metodo == .tarjeta }
            .reduce(into: Decimal(0)) { $0 += $1.montoFirmado }

        let saldoEfectivo = saldoInicialEfectivo + deltaEfectivo
        let saldoTarjeta = saldoInicialTarjeta + deltaTarjeta
        let balanceTotal = saldoEfectivo + saldoTarjeta

        let totalDeudas = prestamos
            .filter { $0.tipo == .debo && $0.afectaBalance }
            .reduce(into: Decimal(0)) { $0 += $1.saldoPendiente }
        let totalMeDeben = prestamos
            .filter { $0.tipo == .meDeben && $0.afectaBalance }
            .reduce(into: Decimal(0)) { $0 += $1.saldoPendiente }
        let balanceReal = balanceTotal - totalDeudas + totalMeDeben

        let totalIngresos = transacciones
            .filter { $0.tipo == .ingreso }
            .reduce(into: Decimal(0)) { $0 += $1.monto }
        let totalGastos = transacciones
            .filter { $0.tipo == .gasto }
            .reduce(into: Decimal(0)) { $0 += $1.monto }

        return ResumenFinanciero(
            saldoInicialEfectivo: saldoInicialEfectivo,
            saldoInicialTarjeta: saldoInicialTarjeta,
            saldoEfectivo: saldoEfectivo,
            saldoTarjeta: saldoTarjeta,
            balanceTotal: balanceTotal,
            totalDeudas: totalDeudas,
            totalMeDeben: totalMeDeben,
            balanceReal: balanceReal,
            totalIngresos: totalIngresos,
            totalGastos: totalGastos
        )
    }
}
