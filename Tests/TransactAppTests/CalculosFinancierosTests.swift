import Foundation
import Testing
import Models
import Database

@Suite("Cálculos financieros")
struct CalculosFinancierosTests {

    private let fecha = FormatoFecha.parsearFecha("2026-06-03")!
    private let hora = FormatoFecha.parsearHora("12:00")!

    @Test("Resumen vacío sin saldo inicial ni movimientos")
    func resumenVacio() {
        let r = CalculosFinancieros.resumen(
            saldoInicial: nil,
            transacciones: [],
            prestamos: []
        )
        #expect(r == .vacio)
    }

    @Test("Saldo inicial sin movimientos preserva ambos montos")
    func saldoInicialSolo() {
        let inicial = SaldoInicial(
            efectivo: 1000,
            tarjeta: 500,
            inventarioInicial: []
        )
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: []
        )
        #expect(r.saldoEfectivo == 1000)
        #expect(r.saldoTarjeta == 500)
        #expect(r.balanceTotal == 1500)
        #expect(r.balanceReal == 1500)
        #expect(r.totalDeudas == 0)
    }

    @Test("Ingreso en efectivo aumenta saldo efectivo")
    func ingresoEfectivo() {
        let inicial = SaldoInicial(efectivo: 100, tarjeta: 0, inventarioInicial: [])
        let tx = Transaccion(
            id: nil, fecha: fecha, hora: hora,
            concepto: "Cobro", monto: 250,
            tipo: .ingreso, categoria: "Trabajo", metodo: .efectivo
        )
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [tx],
            prestamos: []
        )
        #expect(r.saldoEfectivo == 350)
        #expect(r.saldoTarjeta == 0)
        #expect(r.balanceTotal == 350)
        #expect(r.totalIngresos == 250)
        #expect(r.totalGastos == 0)
    }

    @Test("Gasto con tarjeta no toca el efectivo")
    func gastoTarjeta() {
        let inicial = SaldoInicial(efectivo: 1000, tarjeta: 200, inventarioInicial: [])
        let tx = Transaccion(
            id: nil, fecha: fecha, hora: hora,
            concepto: "Amazon", monto: 80,
            tipo: .gasto, categoria: "Compras", metodo: .tarjeta
        )
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [tx],
            prestamos: []
        )
        #expect(r.saldoEfectivo == 1000)
        #expect(r.saldoTarjeta == 120)
        #expect(r.balanceTotal == 1120)
        #expect(r.totalGastos == 80)
    }

    @Test("Mezcla de ingresos, gastos en ambos métodos")
    func mezcla() {
        let inicial = SaldoInicial(efectivo: 500, tarjeta: 300, inventarioInicial: [])
        let txs: [Transaccion] = [
            Transaccion(id: nil, fecha: fecha, hora: hora,
                concepto: "Nómina", monto: 2000, tipo: .ingreso,
                categoria: "Trabajo", metodo: .tarjeta),
            Transaccion(id: nil, fecha: fecha, hora: hora,
                concepto: "Comida", monto: 150, tipo: .gasto,
                categoria: "Comida", metodo: .efectivo),
            Transaccion(id: nil, fecha: fecha, hora: hora,
                concepto: "Gasolina", monto: 500, tipo: .gasto,
                categoria: "Transporte", metodo: .tarjeta),
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: txs,
            prestamos: []
        )
        #expect(r.saldoEfectivo == 350)
        #expect(r.saldoTarjeta == 1800)
        #expect(r.balanceTotal == 2150)
        #expect(r.totalIngresos == 2000)
        #expect(r.totalGastos == 650)
    }

    @Test("Préstamo 'Debo' con afectaBalance reduce balance real")
    func prestamoDeboAfecta() {
        let inicial = SaldoInicial(efectivo: 0, tarjeta: 1000, inventarioInicial: [])
        let prestamos = [
            Prestamo(id: nil, persona: "Juan", concepto: "Préstamo",
                monto: 200, tipo: .debo, fecha: fecha, afectaBalance: true)
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: prestamos
        )
        #expect(r.totalDeudas == 200)
        #expect(r.balanceReal == 800)
    }

    @Test("Préstamo 'Debo' sin afectaBalance se ignora en balance real")
    func prestamoDeboNoAfecta() {
        let inicial = SaldoInicial(efectivo: 0, tarjeta: 1000, inventarioInicial: [])
        let prestamos = [
            Prestamo(id: nil, persona: "Juan", concepto: "Personal",
                monto: 200, tipo: .debo, fecha: fecha, afectaBalance: false)
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: prestamos
        )
        #expect(r.totalDeudas == 0)
        #expect(r.balanceReal == 1000)
    }

    @Test("Préstamo 'Me deben' con afectaBalance incrementa balance real")
    func prestamoMeDebenAfecta() {
        let inicial = SaldoInicial(efectivo: 0, tarjeta: 500, inventarioInicial: [])
        let prestamos = [
            Prestamo(id: nil, persona: "Pedro", concepto: "Me pagó",
                monto: 300, tipo: .meDeben, fecha: fecha, afectaBalance: true)
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: prestamos
        )
        #expect(r.totalDeudas == 0)
        #expect(r.totalMeDeben == 300)
        #expect(r.balanceReal == 800)
    }

    @Test("Préstamo 'Me deben' sin afectaBalance se ignora")
    func prestamoMeDebenNoAfecta() {
        let inicial = SaldoInicial(efectivo: 0, tarjeta: 500, inventarioInicial: [])
        let prestamos = [
            Prestamo(id: nil, persona: "Pedro", concepto: "Me pagó",
                monto: 300, tipo: .meDeben, fecha: fecha, afectaBalance: false)
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: prestamos
        )
        #expect(r.totalDeudas == 0)
        #expect(r.totalMeDeben == 0)
        #expect(r.balanceReal == 500)
    }

    @Test("Préstamo con pagos parciales usa saldo pendiente")
    func prestamoConPagosParciales() {
        let inicial = SaldoInicial(efectivo: 0, tarjeta: 2000, inventarioInicial: [])
        let prestamos = [
            Prestamo(id: nil, persona: "Banco", concepto: "Crédito",
                monto: 1000, tipo: .debo, fecha: fecha,
                afectaBalance: true, montoPagado: 600)
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: prestamos
        )
        #expect(r.totalDeudas == 400)
        #expect(r.balanceReal == 1600)
    }

    @Test("Suma múltiples deudas que afectan")
    func multiplesDeudas() {
        let inicial = SaldoInicial(efectivo: 0, tarjeta: 1000, inventarioInicial: [])
        let prestamos = [
            Prestamo(id: nil, persona: "A", concepto: "x", monto: 100,
                tipo: .debo, fecha: fecha, afectaBalance: true),
            Prestamo(id: nil, persona: "B", concepto: "y", monto: 250,
                tipo: .debo, fecha: fecha, afectaBalance: true),
            Prestamo(id: nil, persona: "C", concepto: "z", monto: 999,
                tipo: .debo, fecha: fecha, afectaBalance: false),
        ]
        let r = CalculosFinancieros.resumen(
            saldoInicial: inicial,
            transacciones: [],
            prestamos: prestamos
        )
        #expect(r.totalDeudas == 350)
        #expect(r.balanceReal == 650)
    }
}
