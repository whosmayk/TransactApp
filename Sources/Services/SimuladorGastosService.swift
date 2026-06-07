import Foundation
import Models

public struct SimuladorGastosService: Sendable {
    public init() {}

    public func simular(
        escenario: EscenarioSimulacion,
        contexto: ContextoSimulacion,
        referencia: Date = Date()
    ) -> Result<ResultadoSimulacion, ErrorSimulacion> {
        switch escenario.validar() {
        case .failure(let err): return .failure(err)
        case .success: break
        }

        switch escenario {
        case .gastoUnico(let monto, let metodo):
            return .success(simularGastoUnico(monto: monto, metodo: metodo, contexto: contexto))
        case .cancelarSuscripcion(let id):
            return simularCancelarSuscripcion(id: id, contexto: contexto)
        case .nuevaSuscripcion(let concepto, let monto, let frecuencia):
            return .success(simularNuevaSuscripcion(
                concepto: concepto, monto: monto, frecuencia: frecuencia, contexto: contexto
            ))
        case .reducirCategoria(let categoria, let porcentaje):
            return simularReducirCategoria(
                categoria: categoria, porcentaje: porcentaje, contexto: contexto, referencia: referencia
            )
        }
    }

    private func simularGastoUnico(
        monto: Decimal,
        metodo: MetodoPago,
        contexto: ContextoSimulacion
    ) -> ResultadoSimulacion {
        let resumen = contexto.resumen
        let nuevoSaldoEf: Decimal
        let nuevoSaldoTj: Decimal
        switch metodo {
        case .efectivo:
            nuevoSaldoEf = resumen.saldoEfectivo - monto
            nuevoSaldoTj = resumen.saldoTarjeta
        case .tarjeta:
            nuevoSaldoEf = resumen.saldoEfectivo
            nuevoSaldoTj = resumen.saldoTarjeta - monto
        }
        let nuevoBalance = nuevoSaldoEf + nuevoSaldoTj
        let nuevoBalanceReal = nuevoBalance - resumen.totalDeudas

        let simulado = ResumenFinanciero(
            saldoInicialEfectivo: resumen.saldoInicialEfectivo,
            saldoInicialTarjeta: resumen.saldoInicialTarjeta,
            saldoEfectivo: nuevoSaldoEf,
            saldoTarjeta: nuevoSaldoTj,
            balanceTotal: nuevoBalance,
            totalDeudas: resumen.totalDeudas,
            balanceReal: nuevoBalanceReal,
            totalIngresos: resumen.totalIngresos,
            totalGastos: resumen.totalGastos + monto
        )

        return ResultadoSimulacion(
            escenario: .gastoUnico(monto: monto, metodo: metodo),
            resumenActual: resumen,
            resumenSimulado: simulado,
            impactoInmediato: -monto,
            impactoMensualRecurrente: 0,
            impacto12Meses: -monto,
            mensaje: "Gasto único de \(textoMoneda(monto)) vía \(metodo == .efectivo ? "efectivo" : "tarjeta")."
        )
    }

    private func simularCancelarSuscripcion(
        id: Int64,
        contexto: ContextoSimulacion
    ) -> Result<ResultadoSimulacion, ErrorSimulacion> {
        guard let susc = contexto.suscripciones.first(where: { $0.id == id }) else {
            return .failure(.contextoInsuficiente("La suscripción ya no existe o fue modificada."))
        }
        guard susc.activa else {
            return .failure(.contextoInsuficiente("La suscripción ya estaba inactiva."))
        }
        let resumen = contexto.resumen
        let impactoMensual = susc.montoMensual()
        let impactoAnual = impactoMensual * 12

        let simulado = ResumenFinanciero(
            saldoInicialEfectivo: resumen.saldoInicialEfectivo,
            saldoInicialTarjeta: resumen.saldoInicialTarjeta,
            saldoEfectivo: resumen.saldoEfectivo,
            saldoTarjeta: resumen.saldoTarjeta,
            balanceTotal: resumen.balanceTotal,
            totalDeudas: resumen.totalDeudas,
            balanceReal: resumen.balanceReal,
            totalIngresos: resumen.totalIngresos,
            totalGastos: resumen.totalGastos
        )

        let mensaje = "Cancelar '\(susc.concepto)' te ahorraría \(textoMoneda(impactoMensual)) al mes, \(textoMoneda(impactoAnual)) al año."

        return .success(ResultadoSimulacion(
            escenario: .cancelarSuscripcion(suscripcionId: id),
            resumenActual: resumen,
            resumenSimulado: simulado,
            impactoInmediato: 0,
            impactoMensualRecurrente: -impactoMensual,
            impacto12Meses: -impactoAnual,
            mensaje: mensaje
        ))
    }

    private func simularNuevaSuscripcion(
        concepto: String,
        monto: Decimal,
        frecuencia: FrecuenciaSuscripcion,
        contexto: ContextoSimulacion
    ) -> ResultadoSimulacion {
        let resumen = contexto.resumen
        let meses = Decimal(frecuencia.mesesPorCiclo)
        let impactoPorCiclo = monto
        let impactoMensual = monto / meses
        let impacto12Meses = impactoMensual * 12

        let simulado = ResumenFinanciero(
            saldoInicialEfectivo: resumen.saldoInicialEfectivo,
            saldoInicialTarjeta: resumen.saldoInicialTarjeta,
            saldoEfectivo: resumen.saldoEfectivo,
            saldoTarjeta: resumen.saldoTarjeta,
            balanceTotal: resumen.balanceTotal,
            totalDeudas: resumen.totalDeudas,
            balanceReal: resumen.balanceReal,
            totalIngresos: resumen.totalIngresos,
            totalGastos: resumen.totalGastos
        )

        let mensaje: String
        if frecuencia == .mensual {
            mensaje = "Nueva suscripción '\(concepto)': \(textoMoneda(monto)) al mes, \(textoMoneda(impacto12Meses)) al año."
        } else {
            mensaje = "Nueva suscripción '\(concepto)': \(textoMoneda(monto)) cada \(frecuencia.rawValue.lowercased()), ≈\(textoMoneda(impactoMensual)) al mes, \(textoMoneda(impacto12Meses)) al año."
        }

        _ = impactoPorCiclo
        return ResultadoSimulacion(
            escenario: .nuevaSuscripcion(concepto: concepto, monto: monto, frecuencia: frecuencia),
            resumenActual: resumen,
            resumenSimulado: simulado,
            impactoInmediato: 0,
            impactoMensualRecurrente: -impactoMensual,
            impacto12Meses: -impacto12Meses,
            mensaje: mensaje
        )
    }

    private func simularReducirCategoria(
        categoria: String,
        porcentaje: Decimal,
        contexto: ContextoSimulacion,
        referencia: Date
    ) -> Result<ResultadoSimulacion, ErrorSimulacion> {
        let calendar = Calendar.current
        let haceMeses = calendar.date(
            byAdding: .month,
            value: -contexto.mesesHistorico,
            to: referencia
        ) ?? referencia
        let gastosCategoria = contexto.transacciones.filter {
            $0.tipo == .gasto
            && $0.categoria == categoria
            && $0.fecha >= haceMeses
        }
        guard !gastosCategoria.isEmpty else {
            return .failure(.contextoInsuficiente("No hay histórico de gastos en '\(categoria)'."))
        }
        let total = gastosCategoria.reduce(into: Decimal(0)) { $0 += $1.monto }
        let mesesDecimal = Decimal(contexto.mesesHistorico)
        let promedioMensual = total / mesesDecimal
        let factorReduccion = porcentaje / 100
        var ahorroMensual = promedioMensual * factorReduccion
        var ahorroRedondeado = Decimal()
        NSDecimalRound(&ahorroRedondeado, &ahorroMensual, 2, .bankers)
        let ahorroAnual = ahorroRedondeado * 12

        let resumen = contexto.resumen
        let simulado = ResumenFinanciero(
            saldoInicialEfectivo: resumen.saldoInicialEfectivo,
            saldoInicialTarjeta: resumen.saldoInicialTarjeta,
            saldoEfectivo: resumen.saldoEfectivo,
            saldoTarjeta: resumen.saldoTarjeta,
            balanceTotal: resumen.balanceTotal,
            totalDeudas: resumen.totalDeudas,
            balanceReal: resumen.balanceReal,
            totalIngresos: resumen.totalIngresos,
            totalGastos: resumen.totalGastos
        )

        let porcentajeTexto = Localizador.decimal(porcentaje, fracciones: 0)
        let mensaje = "Reducir '\(categoria)' un \(porcentajeTexto)% te ahorraría ≈\(textoMoneda(ahorroRedondeado)) al mes (basado en \(textoMoneda(promedioMensual)) promedio), ≈\(textoMoneda(ahorroAnual)) al año."

        return .success(ResultadoSimulacion(
            escenario: .reducirCategoria(categoria: categoria, porcentaje: porcentaje),
            resumenActual: resumen,
            resumenSimulado: simulado,
            impactoInmediato: 0,
            impactoMensualRecurrente: -ahorroRedondeado,
            impacto12Meses: -ahorroAnual,
            mensaje: mensaje,
            desgloseCategoria: promedioMensual
        ))
    }

    private func textoMoneda(_ valor: Decimal) -> String {
        Localizador.monedaCorta(valor)
    }
}
