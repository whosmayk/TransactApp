import Foundation
import Testing
import Models
@testable import Database

@Suite("Préstamo: cálculo")
struct PrestamoCalculoTests {

    @Test("Saldo pendiente = monto - montoPagado")
    func saldoPendiente() {
        let p = Prestamo(
            persona: "Ana", concepto: "Cena", monto: 1000, tipo: .meDeben,
            fecha: Date(), montoPagado: 350
        )
        #expect(p.saldoPendiente == 650)
        #expect(p.porcentajePagado > 0.34 && p.porcentajePagado < 0.36)
    }

    @Test("Pago total marca como pagado")
    func pagadoTotal() {
        let p = Prestamo(
            persona: "Ana", concepto: "Cena", monto: 500, tipo: .meDeben,
            fecha: Date(), montoPagado: 500
        )
        #expect(p.estaPagado)
        #expect(p.saldoPendiente == 0)
        #expect(p.porcentajePagado == 1)
    }

    @Test("Saldo pendiente no es negativo aunque se pague de más")
    func pagadoDeMas() {
        let p = Prestamo(
            persona: "Ana", concepto: "Cena", monto: 100, tipo: .meDeben,
            fecha: Date(), montoPagado: 150
        )
        #expect(p.saldoPendiente == 0)
    }

    @Test("Sin pagos → no pagado y 0%")
    func sinPagos() {
        let p = Prestamo(
            persona: "Ana", concepto: "Cena", monto: 100, tipo: .meDeben,
            fecha: Date()
        )
        #expect(!p.estaPagado)
        #expect(p.saldoPendiente == 100)
        #expect(p.porcentajePagado == 0)
    }
}

@Suite("Suscripción: cálculo")
struct SuscripcionCalculoTests {

    @Test("calcularProximoCobro suma meses según frecuencia")
    func proximoCobro() {
        let base = FormatoFecha.parsearFecha("2026-06-03")!
        let m1 = Suscripcion.calcularProximoCobro(
            desde: base, frecuencia: .mensual
        )
        let t1 = Suscripcion.calcularProximoCobro(
            desde: base, frecuencia: .trimestral
        )
        let a1 = Suscripcion.calcularProximoCobro(
            desde: base, frecuencia: .anual
        )
        #expect(Calendar.current.dateComponents([.month], from: base, to: m1).month == 1)
        #expect(Calendar.current.dateComponents([.month], from: base, to: t1).month == 3)
        #expect(Calendar.current.dateComponents([.month], from: base, to: a1).month == 12)
    }

    @Test("estaProximaAVencer detecta suscripciones dentro de 3 días")
    func proximaAVencer() {
        let ahora = Date()
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: ahora)!
        let dentro5 = Calendar.current.date(byAdding: .day, value: 5, to: ahora)!
        let s1 = Suscripcion(
            concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: manana
        )
        let s2 = Suscripcion(
            concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: dentro5
        )
        #expect(s1.estaProximaAVencer(referencia: ahora))
        #expect(!s2.estaProximaAVencer(referencia: ahora))
    }

    @Test("Inactiva no se considera próxima a vencer")
    func inactivaNoProxima() {
        let ahora = Date()
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: ahora)!
        let s = Suscripcion(
            concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: manana,
            activa: false
        )
        #expect(!s.estaProximaAVencer(referencia: ahora))
    }

    @Test("activaEnMes respeta duración")
    func duracionLimita() {
        let inicio = FormatoFecha.parsearFecha("2026-01-15")!
        let referencia = FormatoFecha.parsearFecha("2026-05-15")!
        let s = Suscripcion(
            concepto: "X", monto: 100, categoria: "Y",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: inicio, proximoCobro: inicio,
            duracionMeses: 3
        )
        #expect(!s.activaEnMes(offset: 0, referencia: referencia))
    }

    @Test("montoMensual anual prorratea entre 12")
    func montoMensualAnual() {
        let s = Suscripcion(
            concepto: "Dominio", monto: 1200, categoria: "Servicios",
            frecuencia: .anual, tipo: .gasto,
            fechaInicio: Date(), proximoCobro: Date()
        )
        #expect(s.montoMensual() == 100)
    }
}
