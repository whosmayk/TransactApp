import Foundation
import Testing
import Models
import Services
import Database

@Suite("SimuladorGastosService")
struct SimuladorGastosServiceTests {

    @Test("Gasto único en efectivo resta del saldo en efectivo")
    func gastoUnicoEfectivo() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .gastoUnico(monto: 500, metodo: .efectivo),
            contexto: contexto
        )
        guard case .success(let r) = resultado else {
            Issue.record("Debió ser success")
            return
        }

        #expect(r.impactoInmediato == -500)
        #expect(r.impactoMensualRecurrente == 0)
        #expect(r.impacto12Meses == -500)
        #expect(r.resumenSimulado.saldoEfectivo == 500)
        #expect(r.resumenSimulado.saldoTarjeta == 1000)
        #expect(r.resumenSimulado.balanceTotal == 1500)
        #expect(r.resumenSimulado.balanceReal == 1500 - contexto.resumen.totalDeudas)
    }

    @Test("Gasto único en tarjeta no toca el efectivo")
    func gastoUnicoTarjeta() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .gastoUnico(monto: 300, metodo: .tarjeta),
            contexto: contexto
        )
        guard case .success(let r) = resultado else {
            Issue.record("Debió ser success")
            return
        }
        #expect(r.resumenSimulado.saldoEfectivo == 1000)
        #expect(r.resumenSimulado.saldoTarjeta == 700)
    }

    @Test("Gasto único con monto 0 falla con validación")
    func gastoUnicoMontoCero() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .gastoUnico(monto: 0, metodo: .efectivo),
            contexto: contexto
        )
        guard case .failure(let err) = resultado else {
            Issue.record("Debió ser failure")
            return
        }
        #expect(err == .montoInvalido("Captura un monto mayor a 0."))
    }

    @Test("Gasto único negativo falla con validación")
    func gastoUnicoMontoNegativo() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .gastoUnico(monto: -100, metodo: .efectivo),
            contexto: contexto
        )
        guard case .failure = resultado else {
            Issue.record("Debió ser failure")
            return
        }
    }

    @Test("Cancelar suscripción existente calcula impacto mensual y anual")
    func cancelarSuscripcionExistente() throws {
        let contexto = contextoBase()
        let suscripcionMensual = Suscripcion(
            id: 1, concepto: "Netflix", monto: 200, categoria: "Ocio",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date(),
            notas: nil, duracionMeses: nil, activa: true
        )
        let contextoConSub = ContextoSimulacion(
            resumen: contexto.resumen,
            suscripciones: [suscripcionMensual],
            transacciones: contexto.transacciones
        )
        let resultado = SimuladorGastosService().simular(
            escenario: .cancelarSuscripcion(suscripcionId: 1),
            contexto: contextoConSub
        )
        guard case .success(let r) = resultado else {
            Issue.record("Debió ser success")
            return
        }
        #expect(r.impactoInmediato == 0)
        #expect(r.impactoMensualRecurrente == -200)
        #expect(r.impacto12Meses == -2400)
        #expect(r.mensaje.contains("Netflix"))
    }

    @Test("Cancelar suscripción que no existe devuelve error de contexto")
    func cancelarSuscripcionInexistente() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .cancelarSuscripcion(suscripcionId: 999),
            contexto: contexto
        )
        guard case .failure(let err) = resultado else {
            Issue.record("Debió ser failure")
            return
        }
        #expect(err == .contextoInsuficiente("La suscripción ya no existe o fue modificada."))
    }

    @Test("Cancelar suscripción ya inactiva falla")
    func cancelarSuscripcionInactiva() {
        let contexto = contextoBase()
        let inactiva = Suscripcion(
            id: 5, concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date(),
            notas: nil, duracionMeses: nil, activa: false
        )
        let resultado = SimuladorGastosService().simular(
            escenario: .cancelarSuscripcion(suscripcionId: 5),
            contexto: ContextoSimulacion(
                resumen: contexto.resumen,
                suscripciones: [inactiva],
                transacciones: contexto.transacciones
            )
        )
        guard case .failure = resultado else {
            Issue.record("Debió ser failure")
            return
        }
    }

    @Test("Nueva suscripción mensual impacta directo en flujo mensual")
    func nuevaSuscripcionMensual() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .nuevaSuscripcion(concepto: "Spotify", monto: 99, frecuencia: .mensual),
            contexto: contexto
        )
        guard case .success(let r) = resultado else {
            Issue.record("Debió ser success")
            return
        }
        #expect(r.impactoMensualRecurrente == -99)
        #expect(r.impacto12Meses == -1188)
        #expect(r.mensaje.contains("Spotify"))
    }

    @Test("Nueva suscripción anual reparte correctamente a mensual")
    func nuevaSuscripcionAnual() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .nuevaSuscripcion(concepto: "Dominio", monto: 1200, frecuencia: .anual),
            contexto: contexto
        )
        guard case .success(let r) = resultado else {
            Issue.record("Debió ser success")
            return
        }
        #expect(r.impactoMensualRecurrente == Decimal(string: "-100")!)
        #expect(r.impacto12Meses == -1200)
    }

    @Test("Nueva suscripción sin concepto falla")
    func nuevaSuscripcionSinConcepto() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .nuevaSuscripcion(concepto: "  ", monto: 100, frecuencia: .mensual),
            contexto: contexto
        )
        guard case .failure(let err) = resultado else {
            Issue.record("Debió ser failure")
            return
        }
        #expect(err == .campoVacio("Escribe un concepto para la suscripción."))
    }

    @Test("Reducir categoría existente usa histórico de meses configurados")
    func reducirCategoriaExistente() throws {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let transacciones: [Transaccion] = (0..<3).flatMap { mes in
            let fecha = calendar.date(from: DateComponents(year: 2026, month: 6 - mes, day: 10))!
            return [
                trans(fecha: fecha, tipo: .gasto, categoria: "Comida", monto: 1000)
            ]
        }
        let contexto = ContextoSimulacion(
            resumen: resumenBase(),
            suscripciones: [],
            transacciones: transacciones,
            mesesHistorico: 3
        )
        let resultado = SimuladorGastosService().simular(
            escenario: .reducirCategoria(categoria: "Comida", porcentaje: 20),
            contexto: contexto,
            referencia: ref
        )
        guard case .success(let r) = resultado else {
            Issue.record("Debió ser success, obtuvo \(resultado)")
            return
        }
        #expect(r.impactoMensualRecurrente == Decimal(string: "-200.00")!)
        #expect(r.impacto12Meses == Decimal(string: "-2400.00")!)
        #expect(r.desgloseCategoria == Decimal(1000))
    }

    @Test("Reducir categoría sin histórico falla con contexto insuficiente")
    func reducirCategoriaSinHistorico() throws {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let contexto = ContextoSimulacion(
            resumen: resumenBase(),
            suscripciones: [],
            transacciones: [],
            mesesHistorico: 3
        )
        let resultado = SimuladorGastosService().simular(
            escenario: .reducirCategoria(categoria: "Ocio", porcentaje: 50),
            contexto: contexto,
            referencia: ref
        )
        guard case .failure(let err) = resultado else {
            Issue.record("Debió ser failure")
            return
        }
        #expect(err == .contextoInsuficiente("No hay histórico de gastos en 'Ocio'."))
    }

    @Test("Reducir categoría con porcentaje 0 falla")
    func reducirCategoriaPorcentajeCero() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .reducirCategoria(categoria: "X", porcentaje: 0),
            contexto: contexto
        )
        guard case .failure = resultado else {
            Issue.record("Debió ser failure")
            return
        }
    }

    @Test("Reducir categoría con porcentaje > 100 falla")
    func reducirCategoriaPorcentajeInvalido() {
        let contexto = contextoBase()
        let resultado = SimuladorGastosService().simular(
            escenario: .reducirCategoria(categoria: "X", porcentaje: 150),
            contexto: contexto
        )
        guard case .failure = resultado else {
            Issue.record("Debió ser failure")
            return
        }
    }

    @Test("Categorías del contexto incluyen transacciones y suscripciones únicas")
    func categoriasDeduplicadas() {
        let transacciones = [
            trans(fecha: Date(), tipo: .gasto, categoria: "Comida", monto: 100),
            trans(fecha: Date(), tipo: .gasto, categoria: "Comida", monto: 50),
            trans(fecha: Date(), tipo: .gasto, categoria: "Transporte", monto: 80)
        ]
        let suscripciones = [
            Suscripcion(
                id: 1, concepto: "Netflix", monto: 200, categoria: "Ocio",
                frecuencia: .mensual, tipo: .gasto,
                fechaInicio: Date(), proximoCobro: Date(), activa: true
            )
        ]
        let contexto = ContextoSimulacion(
            resumen: resumenBase(),
            suscripciones: suscripciones,
            transacciones: transacciones
        )
        #expect(contexto.categorias == ["Comida", "Ocio", "Transporte"])
    }

    @Test("Contexto filtra suscripciones activas correctamente")
    func contextoSuscripcionesActivas() {
        let activas = [
            Suscripcion(id: 1, concepto: "A", monto: 100, categoria: "X",
                        frecuencia: .mensual, tipo: .gasto,
                        fechaInicio: Date(), proximoCobro: Date(), activa: true),
            Suscripcion(id: 2, concepto: "B", monto: 200, categoria: "X",
                        frecuencia: .mensual, tipo: .gasto,
                        fechaInicio: Date(), proximoCobro: Date(), activa: true)
        ]
        let inactivas = [
            Suscripcion(id: 3, concepto: "C", monto: 300, categoria: "X",
                        frecuencia: .mensual, tipo: .gasto,
                        fechaInicio: Date(), proximoCobro: Date(), activa: false)
        ]
        let contexto = ContextoSimulacion(
            resumen: resumenBase(),
            suscripciones: activas + inactivas,
            transacciones: []
        )
        #expect(contexto.suscripcionesActivas.count == 2)
        #expect(contexto.suscripcionesActivas.allSatisfy { $0.activa })
    }
}

private func resumenBase() -> ResumenFinanciero {
    ResumenFinanciero(
        saldoInicialEfectivo: 0,
        saldoInicialTarjeta: 0,
        saldoEfectivo: 1000,
        saldoTarjeta: 1000,
        balanceTotal: 2000,
        totalDeudas: 0,
        balanceReal: 2000,
        totalIngresos: 0,
        totalGastos: 0
    )
}

private func contextoBase() -> ContextoSimulacion {
    ContextoSimulacion(
        resumen: resumenBase(),
        suscripciones: [],
        transacciones: []
    )
}

private func trans(
    fecha: Date,
    tipo: TipoTransaccion,
    categoria: String = "Test",
    monto: Decimal
) -> Transaccion {
    Transaccion(
        fecha: fecha,
        hora: fecha,
        concepto: "Test",
        monto: monto,
        tipo: tipo,
        categoria: categoria,
        metodo: .efectivo,
        desglose: nil
    )
}
