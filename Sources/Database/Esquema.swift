import Foundation
import GRDB

public enum EsquemaColumnas {
    public struct SyncCol {
        public static let uuid = "uuid"
        public static let updatedAt = "updated_at"
        public static let syncStatus = "sync_status"
        public static let isDeleted = "is_deleted"
    }

    public enum Transaccion {
        public static let tabla = "Transacciones"
        public static let id = "id"
        public static let fecha = "fecha"
        public static let hora = "hora"
        public static let concepto = "concepto"
        public static let monto = "monto"
        public static let tipo = "tipo"
        public static let categoria = "categoria"
        public static let metodo = "metodo"
        public static let desglose = "desglose"
        public static let uuid = SyncCol.uuid
        public static let updatedAt = SyncCol.updatedAt
        public static let syncStatus = SyncCol.syncStatus
        public static let isDeleted = SyncCol.isDeleted
    }

    public enum Inventario {
        public static let tabla = "InventarioEfectivo"
        public static let denominacion = "denominacion"
        public static let cantidad = "cantidad"
        public static let actualizadoEn = "actualizadoEn"
        public static let uuid = SyncCol.uuid
        public static let updatedAt = SyncCol.updatedAt
        public static let syncStatus = SyncCol.syncStatus
        public static let isDeleted = SyncCol.isDeleted
    }

    public enum Prestamo {
        public static let tabla = "Prestamos"
        public static let id = "id"
        public static let persona = "persona"
        public static let concepto = "concepto"
        public static let monto = "monto"
        public static let tipo = "tipo"
        public static let fecha = "fecha"
        public static let afectaBalance = "afectaBalance"
        public static let montoPagado = "montoPagado"
        public static let notas = "notas"
        public static let uuid = SyncCol.uuid
        public static let updatedAt = SyncCol.updatedAt
        public static let syncStatus = SyncCol.syncStatus
        public static let isDeleted = SyncCol.isDeleted
    }

    public enum Suscripcion {
        public static let tabla = "Suscripciones"
        public static let id = "id"
        public static let concepto = "concepto"
        public static let monto = "monto"
        public static let categoria = "categoria"
        public static let frecuencia = "frecuencia"
        public static let tipo = "tipo"
        public static let fechaInicio = "fechaInicio"
        public static let proximoCobro = "proximoCobro"
        public static let notas = "notas"
        public static let duracionMeses = "duracionMeses"
        public static let activa = "activa"
        public static let notificado = "notificado"
        public static let uuid = SyncCol.uuid
        public static let updatedAt = SyncCol.updatedAt
        public static let syncStatus = SyncCol.syncStatus
        public static let isDeleted = SyncCol.isDeleted
    }

    public enum SaldoInicial {
        public static let tabla = "SaldoInicial"
        public static let id = "id"
        public static let efectivo = "efectivo"
        public static let tarjeta = "tarjeta"
        public static let fechaCreacion = "fechaCreacion"
        public static let inventarioJson = "inventarioJson"
        public static let uuid = SyncCol.uuid
        public static let updatedAt = SyncCol.updatedAt
        public static let syncStatus = SyncCol.syncStatus
        public static let isDeleted = SyncCol.isDeleted
    }

    public enum Metadata {
        public static let tabla = "Metadata"
        public static let clave = "clave"
        public static let valor = "valor"
    }
}

public enum FormatoFecha {
    public static let fecha: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static let hora: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "HH:mm"
        return f
    }()

    public static let fechaHoraCompleta: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    public static func formatearFecha(_ date: Date) -> String { fecha.string(from: date) }
    public static func formatearHora(_ date: Date) -> String { hora.string(from: date) }
    public static func formatearFechaHora(_ date: Date) -> String { fechaHoraCompleta.string(from: date) }
    public static func parsearFecha(_ texto: String) -> Date? { fecha.date(from: texto) }
    public static func parsearHora(_ texto: String) -> Date? { hora.date(from: texto) }
    public static func parsearFechaHora(_ texto: String) -> Date? { fechaHoraCompleta.date(from: texto) }
}
