import Foundation

public struct ParametrosReporte: Sendable, Equatable {
    public var mes: Date
    public var incluirResumen: Bool
    public var incluirDetalleTransacciones: Bool
    public var incluirPrestamos: Bool
    public var incluirSuscripciones: Bool
    public var incluirInventario: Bool
    public var incluirProyeccionMes: Bool

    public init(
        mes: Date = Date(),
        incluirResumen: Bool = true,
        incluirDetalleTransacciones: Bool = true,
        incluirPrestamos: Bool = true,
        incluirSuscripciones: Bool = true,
        incluirInventario: Bool = true,
        incluirProyeccionMes: Bool = true
    ) {
        self.mes = mes
        self.incluirResumen = incluirResumen
        self.incluirDetalleTransacciones = incluirDetalleTransacciones
        self.incluirPrestamos = incluirPrestamos
        self.incluirSuscripciones = incluirSuscripciones
        self.incluirInventario = incluirInventario
        self.incluirProyeccionMes = incluirProyeccionMes
    }

    public var anio: Int {
        Calendar.current.component(.year, from: mes)
    }

    public var mesNumero: Int {
        Calendar.current.component(.month, from: mes)
    }
}

public struct ReporteMensual: Sendable {
    public let parametros: ParametrosReporte
    public let datos: DatosReporte
    public let transaccionesDelMes: [Transaccion]
    public let proyeccion: ProyeccionMensual?
    public let generadoEn: Date

    public init(
        parametros: ParametrosReporte,
        datos: DatosReporte,
        transaccionesDelMes: [Transaccion],
        proyeccion: ProyeccionMensual?,
        generadoEn: Date = Date()
    ) {
        self.parametros = parametros
        self.datos = datos
        self.transaccionesDelMes = transaccionesDelMes
        self.proyeccion = proyeccion
        self.generadoEn = generadoEn
    }
}

public enum FormatoReporte: String, Sendable, CaseIterable {
    case pdf = "PDF"
    case csv = "CSV"
}
