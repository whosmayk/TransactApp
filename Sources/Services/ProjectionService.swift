import Foundation
import Models
import Database

public struct ResumenMensual: Sendable, Equatable {
    public var mes: Date
    public var ingresos: Decimal
    public var gastos: Decimal

    public init(mes: Date, ingresos: Decimal, gastos: Decimal) {
        self.mes = mes
        self.ingresos = ingresos
        self.gastos = gastos
    }

    public var balance: Decimal { ingresos - gastos }
}

public struct ProjectionService: Sendable {
    public init() {}

    public func proyectar(
        transaccionesMesActual: [Transaccion],
        suscripcionesActivas: [Suscripcion],
        historicoMeses: [ResumenMensual],
        metaAhorroMensual: Decimal,
        referencia: Date = Date()
    ) -> ProyeccionMensual {
        let calendar = Calendar.current
        let inicioMes = calendar.startOfMonth(referencia) ?? referencia
        let diasDelMes = calendar.range(of: .day, in: .month, for: inicioMes)?.count ?? 30
        let diasTranscurridos = max(1, calendar.dayOfMonth(for: referencia))

        let (ingresosReales, gastosReales) = Self.separarIngresosGastos(transaccionesMesActual)
        let suscripcionesRestantes = Self.sumarSuscripcionesRestantes(
            suscripciones: suscripcionesActivas,
            desde: referencia,
            finDeMes: calendar.endOfMonth(referencia) ?? referencia,
            calendar: calendar
        )

        let ingresosEsperados = Self.proyectarIngresos(
            real: ingresosReales,
            historico: historicoMeses.map(\.ingresos),
            diasTranscurridos: diasTranscurridos,
            diasDelMes: diasDelMes
        )

        let gastosEsperados = Self.proyectarGastos(
            real: gastosReales,
            historico: historicoMeses.map(\.gastos),
            diasTranscurridos: diasTranscurridos,
            diasDelMes: diasDelMes
        )

        return ProyeccionMensual(
            ingresosEsperados: ingresosEsperados,
            gastosEsperados: gastosEsperados,
            suscripcionesRestantes: suscripcionesRestantes,
            metaAhorro: metaAhorroMensual,
            diasTranscurridos: diasTranscurridos,
            diasDelMes: diasDelMes
        )
    }

    public static func resumirHistorico(
        transacciones: [Transaccion],
        mesesAtras: Int,
        referencia: Date = Date()
    ) -> [ResumenMensual] {
        let calendar = Calendar.current
        let inicio = calendar.date(byAdding: .month, value: -(mesesAtras), to: referencia) ?? referencia
        let agrupado = Dictionary(grouping: transacciones.filter { $0.fecha < referencia && $0.fecha >= inicio }) { tx in
            calendar.startOfMonth(tx.fecha) ?? tx.fecha
        }
        return agrupado.map { mes, txs in
            let (ing, gas) = separarIngresosGastos(txs)
            return ResumenMensual(mes: mes, ingresos: ing, gastos: gas)
        }.sorted { $0.mes < $1.mes }
    }

    private static func separarIngresosGastos(_ transacciones: [Transaccion]) -> (Decimal, Decimal) {
        var ingresos: Decimal = 0
        var gastos: Decimal = 0
        for tx in transacciones {
            switch tx.tipo {
            case .ingreso: ingresos += tx.monto
            case .gasto: gastos += tx.monto
            }
        }
        return (ingresos, gastos)
    }

    private static func proyectarIngresos(
        real: Decimal,
        historico: [Decimal],
        diasTranscurridos: Int,
        diasDelMes: Int
    ) -> Decimal {
        if !historico.isEmpty {
            let promedio = historico.reduce(0, +) / Decimal(historico.count)
            return promedio
        }
        guard diasTranscurridos > 0, diasDelMes > diasTranscurridos else { return real }
        let factor = Decimal(diasDelMes) / Decimal(diasTranscurridos)
        return real * factor
    }

    private static func proyectarGastos(
        real: Decimal,
        historico: [Decimal],
        diasTranscurridos: Int,
        diasDelMes: Int
    ) -> Decimal {
        if !historico.isEmpty {
            let promedio = historico.reduce(0, +) / Decimal(historico.count)
            return max(real, promedio)
        }
        guard diasTranscurridos > 0, diasDelMes > diasTranscurridos else { return real }
        let factor = Decimal(diasDelMes) / Decimal(diasTranscurridos)
        return real * factor
    }

    private static func sumarSuscripcionesRestantes(
        suscripciones: [Suscripcion],
        desde: Date,
        finDeMes: Date,
        calendar: Calendar
    ) -> Decimal {
        let inicioHoy = calendar.startOfDay(for: desde)
        var total: Decimal = 0
        for s in suscripciones where s.activa {
            let proximo = calendar.startOfDay(for: s.proximoCobro)
            if proximo >= inicioHoy && proximo <= finDeMes && s.tipo == .gasto {
                total += s.monto
            }
        }
        return total
    }
}

extension Calendar {
    public func startOfMonth(_ date: Date) -> Date? {
        var components = dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        return self.date(from: components)
    }

    public func endOfMonth(_ date: Date) -> Date? {
        guard let start = startOfMonth(date) else { return nil }
        return self.date(byAdding: DateComponents(month: 1, day: -1), to: start)
    }

    public func dayOfMonth(for date: Date) -> Int {
        self.component(.day, from: date)
    }
}
