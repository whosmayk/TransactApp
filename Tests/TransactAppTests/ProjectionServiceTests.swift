import Foundation
import Testing
import Models
import Database
import Services

@Suite("ProjectionService")
struct ProjectionServiceTests {

    @Test("Sin histórico y mitad de mes extrapola linealmente")
    func extrapolarSinHistorico() {
        let calendar = Calendar(identifier: .gregorian)
        let fechaReferencia = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let svc = ProjectionService()

        let ingresos: [Transaccion] = [
            trans(fecha: fechaReferencia, tipo: .ingreso, monto: 2000)
        ]
        let gastos: [Transaccion] = [
            trans(fecha: fechaReferencia, tipo: .gasto, monto: 500)
        ]

        let resultado = svc.proyectar(
            transaccionesMesActual: ingresos + gastos,
            suscripcionesActivas: [],
            historicoMeses: [],
            metaAhorroMensual: 0,
            referencia: fechaReferencia
        )

        #expect(resultado.diasTranscurridos == 15)
        #expect(resultado.diasDelMes == 30)
        #expect(resultado.ingresosEsperados == Decimal(string: "4000")!)
        #expect(resultado.gastosEsperados == Decimal(string: "1000")!)
    }

    @Test("Con histórico usa el promedio, no extrapola")
    func promedioConHistorico() {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))!
        let svc = ProjectionService()

        let ahora: [Transaccion] = []
        let hist: [ResumenMensual] = [
            ResumenMensual(mes: ref, ingresos: 5000, gastos: 2000),
            ResumenMensual(mes: ref, ingresos: 6000, gastos: 2500),
            ResumenMensual(mes: ref, ingresos: 4000, gastos: 1500)
        ]

        let resultado = svc.proyectar(
            transaccionesMesActual: ahora,
            suscripcionesActivas: [],
            historicoMeses: hist,
            metaAhorroMensual: 0,
            referencia: ref
        )

        #expect(resultado.ingresosEsperados == Decimal(string: "5000")!)
        #expect(resultado.gastosEsperados == Decimal(string: "2000")!)
    }

    @Test("Suscripciones futuras se suman a gastos del mes")
    func suscripcionesRestantes() {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        let proximo = calendar.date(from: DateComponents(year: 2026, month: 6, day: 20))!
        let svc = ProjectionService()

        let suscripciones: [Suscripcion] = [
            Suscripcion(
                concepto: "Netflix", monto: 300, categoria: "Ocio",
                frecuencia: .mensual, tipo: .gasto,
                fechaInicio: ref, proximoCobro: proximo,
                notas: nil, duracionMeses: nil, activa: true
            )
        ]

        let resultado = svc.proyectar(
            transaccionesMesActual: [],
            suscripcionesActivas: suscripciones,
            historicoMeses: [],
            metaAhorroMensual: 0,
            referencia: ref
        )

        #expect(resultado.suscripcionesRestantes == 300)
    }

    @Test("Suscripciones inactivas o que ya cobraron no se cuentan")
    func suscripcionesExcluidas() {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 25))!
        let pasada = calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))!
        let svc = ProjectionService()

        let suscripciones: [Suscripcion] = [
            Suscripcion(
                concepto: "Pasada", monto: 200, categoria: "X",
                frecuencia: .mensual, tipo: .gasto,
                fechaInicio: ref, proximoCobro: pasada,
                notas: nil, duracionMeses: nil, activa: true
            )
        ]

        let resultado = svc.proyectar(
            transaccionesMesActual: [],
            suscripcionesActivas: suscripciones,
            historicoMeses: [],
            metaAhorroMensual: 0,
            referencia: ref
        )

        #expect(resultado.suscripcionesRestantes == 0)
    }

    @Test("Estado en meta cuando balance proyectado supera la meta")
    func estadoEnMeta() {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let svc = ProjectionService()

        let ingresos = [trans(fecha: ref, tipo: .ingreso, monto: 3000)]
        let gastos = [trans(fecha: ref, tipo: .gasto, monto: 500)]

        let resultado = svc.proyectar(
            transaccionesMesActual: ingresos + gastos,
            suscripcionesActivas: [],
            historicoMeses: [],
            metaAhorroMensual: 100,
            referencia: ref
        )

        #expect(resultado.estado == .enMeta)
        #expect(resultado.diferenciaVsMeta > 0)
    }

    @Test("Estado en riesgo cuando faltan más del 10% de la meta")
    func estadoEnRiesgo() {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let svc = ProjectionService()

        let gastos = [trans(fecha: ref, tipo: .gasto, monto: 4000)]

        let resultado = svc.proyectar(
            transaccionesMesActual: gastos,
            suscripcionesActivas: [],
            historicoMeses: [],
            metaAhorroMensual: 1000,
            referencia: ref
        )

        #expect(resultado.estado == .enRiesgo)
    }

    @Test("Estado cerca cuando faltan menos del 10% de la meta")
    func estadoCerca() {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let svc = ProjectionService()

        let ingresos = [trans(fecha: ref, tipo: .ingreso, monto: 100)]
        let gastos = [trans(fecha: ref, tipo: .gasto, monto: 5)]
        let hist: [ResumenMensual] = [
            ResumenMensual(mes: ref, ingresos: 100, gastos: 5)
        ]

        let resultado = svc.proyectar(
            transaccionesMesActual: ingresos + gastos,
            suscripcionesActivas: [],
            historicoMeses: hist,
            metaAhorroMensual: 100,
            referencia: ref
        )

        #expect(resultado.balanceProyectado == 95)
        #expect(resultado.estado == .cerca)
    }

    @Test("resumirHistorico agrupa por mes")
    func agruparHistorico() throws {
        let calendar = Calendar(identifier: .gregorian)
        let ref = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let haceUnMes = calendar.date(from: DateComponents(year: 2026, month: 5, day: 10))!
        let haceDosMeses = calendar.date(from: DateComponents(year: 2026, month: 4, day: 5))!

        let txs: [Transaccion] = [
            trans(fecha: haceUnMes, tipo: .ingreso, monto: 1000),
            trans(fecha: haceUnMes, tipo: .gasto, monto: 200),
            trans(fecha: haceDosMeses, tipo: .ingreso, monto: 1500),
            trans(fecha: haceDosMeses, tipo: .gasto, monto: 300),
            trans(fecha: ref, tipo: .gasto, monto: 100)
        ]

        let resumenes = ProjectionService.resumirHistorico(
            transacciones: txs,
            mesesAtras: 3,
            referencia: ref
        )

        #expect(resumenes.count == 2)
        #expect(resumenes[0].ingresos == 1500)
        #expect(resumenes[0].gastos == 300)
        #expect(resumenes[1].ingresos == 1000)
        #expect(resumenes[1].gastos == 200)
    }
}

private func trans(fecha: Date, tipo: TipoTransaccion, monto: Decimal) -> Transaccion {
    Transaccion(
        fecha: fecha,
        hora: fecha,
        concepto: "Test",
        monto: monto,
        tipo: tipo,
        categoria: "Test",
        metodo: .efectivo,
        desglose: nil
    )
}

@Suite("ConfigurationService")
struct ConfigurationServiceTests {

    @Test("Round-trip guardar y recuperar configuración")
    func roundTrip() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let manager = try DatabaseManager(ruta: tmp.appendingPathComponent("cfg.sqlite"))
        let repo = SQLiteConfigurationRepository(manager: manager)
        let svc = ConfigurationService(repo: repo)

        let original = ConfiguracionUsuario(
            metaAhorroMensual: 1500,
            ventanaHistoricoMeses: 6,
            notificacionesHabilitadas: false
        )
        try await svc.guardar(original)

        let recuperado = try await svc.obtener()
        #expect(recuperado.metaAhorroMensual == 1500)
        #expect(recuperado.ventanaHistoricoMeses == 6)
        #expect(recuperado.notificacionesHabilitadas == false)
    }

    @Test("Sin datos devuelve configuración por defecto")
    func porDefecto() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let manager = try DatabaseManager(ruta: tmp.appendingPathComponent("cfg2.sqlite"))
        let repo = SQLiteConfigurationRepository(manager: manager)
        let svc = ConfigurationService(repo: repo)

        let config = try await svc.obtener()
        #expect(config.metaAhorroMensual == 0)
        #expect(config.ventanaHistoricoMeses == 3)
        #expect(config.notificacionesHabilitadas == true)
    }

    @Test("Migración v3 añade tabla Configuracion")
    func migracionV3() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let manager = try DatabaseManager(ruta: tmp.appendingPathComponent("v3.sqlite"))
        try Migrator.aplicar(manager.dbQueue)
        let repo = SQLiteConfigurationRepository(manager: manager)
        try await repo.guardar(clave: "test", valor: "hola")
        let v = try await repo.obtener(clave: "test")
        #expect(v == "hola")
    }
}
