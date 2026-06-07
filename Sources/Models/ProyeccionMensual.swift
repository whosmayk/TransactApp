import Foundation

public enum EstadoProyeccion: String, Codable, Sendable, CaseIterable {
    case enMeta = "En meta"
    case cerca = "Cerca"
    case enRiesgo = "En riesgo"

    public var titulo: String {
        switch self {
        case .enMeta: return LocalizableKey.enumEstadoEnMeta.localized()
        case .cerca: return LocalizableKey.enumEstadoCerca.localized()
        case .enRiesgo: return LocalizableKey.enumEstadoEnRiesgo.localized()
        }
    }
}

public struct ProyeccionMensual: Equatable, Sendable {
    public var ingresosEsperados: Decimal
    public var gastosEsperados: Decimal
    public var suscripcionesRestantes: Decimal
    public var balanceProyectado: Decimal
    public var metaAhorro: Decimal
    public var diferenciaVsMeta: Decimal
    public var diasTranscurridos: Int
    public var diasDelMes: Int
    public var estado: EstadoProyeccion
    public var mensaje: String

    public init(
        ingresosEsperados: Decimal,
        gastosEsperados: Decimal,
        suscripcionesRestantes: Decimal,
        metaAhorro: Decimal,
        diasTranscurridos: Int,
        diasDelMes: Int
    ) {
        self.ingresosEsperados = ingresosEsperados
        self.gastosEsperados = gastosEsperados
        self.suscripcionesRestantes = suscripcionesRestantes
        self.metaAhorro = metaAhorro
        self.diasTranscurridos = diasTranscurridos
        self.diasDelMes = diasDelMes
        self.balanceProyectado = ingresosEsperados - gastosEsperados - suscripcionesRestantes
        self.diferenciaVsMeta = self.balanceProyectado - metaAhorro
        self.estado = Self.calcularEstado(diferencia: self.diferenciaVsMeta, meta: metaAhorro)
        self.mensaje = Self.construirMensaje(
            estado: self.estado,
            diferencia: self.diferenciaVsMeta,
            balance: self.balanceProyectado,
            dias: diasTranscurridos,
            totalDias: diasDelMes
        )
    }

    public var porcentajeCompletado: Double {
        guard diasDelMes > 0 else { return 0 }
        return min(1.0, Double(diasTranscurridos) / Double(diasDelMes))
    }

    private static func calcularEstado(diferencia: Decimal, meta: Decimal) -> EstadoProyeccion {
        if diferencia >= 0 {
            return .enMeta
        }
        let tolerancia: Decimal = meta > 0 ? meta * 0.1 : 50
        if diferencia >= -tolerancia {
            return .cerca
        }
        return .enRiesgo
    }

    private static func construirMensaje(
        estado: EstadoProyeccion,
        diferencia: Decimal,
        balance: Decimal,
        dias: Int,
        totalDias: Int
    ) -> String {
        switch estado {
        case .enMeta:
            if dias >= totalDias {
                return LocalizableKey.proyeccionMsgCerrasteMes.localized(Localizador.monedaCorta(balance))
            }
            let faltan = totalDias - dias
            return LocalizableKey.proyeccionMsgPorEncima.localized(Localizador.monedaCorta(diferencia), faltan)
        case .cerca:
            return LocalizableKey.proyeccionMsgPorDebajo.localized(Localizador.monedaCorta(-diferencia))
        case .enRiesgo:
            return LocalizableKey.proyeccionMsgRiesgo.localized(Localizador.monedaCorta(-diferencia))
        }
    }
}
