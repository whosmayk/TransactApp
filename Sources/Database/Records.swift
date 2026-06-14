import Foundation
import GRDB
import Models

struct TransaccionRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = EsquemaColumnas.Transaccion.tabla

    var id: Int64?
    var fecha: String
    var hora: String
    var concepto: String
    var monto: Int64
    var tipo: String
    var categoria: String
    var metodo: String
    var desglose: String?
    var uuid: String
    var updatedAt: Int64
    var syncStatus: Int
    var isDeleted: Int

    enum CodingKeys: String, CodingKey {
        case id, fecha, hora, concepto, monto, tipo, categoria, metodo, desglose, uuid
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
        case isDeleted = "is_deleted"
    }

    init(
        id: Int64? = nil,
        fecha: String,
        hora: String,
        concepto: String,
        monto: Int64,
        tipo: String,
        categoria: String,
        metodo: String,
        desglose: String? = nil,
        uuid: String? = nil,
        updatedAt: Int64 = Date().epochMillis,
        syncStatus: Int = 0,
        isDeleted: Int = 0
    ) {
        self.id = id
        self.fecha = fecha
        self.hora = hora
        self.concepto = concepto
        self.monto = monto
        self.tipo = tipo
        self.categoria = categoria
        self.metodo = metodo
        self.desglose = desglose
        self.uuid = uuid ?? UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isDeleted = isDeleted
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(_ transaccion: Transaccion) {
        self.id = transaccion.id
        self.fecha = FormatoFecha.formatearFecha(transaccion.fecha)
        self.hora = FormatoFecha.formatearHora(transaccion.hora)
        self.concepto = transaccion.concepto
        self.monto = transaccion.monto.centavos
        self.tipo = transaccion.tipo.rawValue
        self.categoria = transaccion.categoria
        self.metodo = transaccion.metodo.rawValue
        if let d = transaccion.desglose,
           let data = try? JSONEncoder().encode(d),
           let json = String(data: data, encoding: .utf8) {
            self.desglose = json
        } else {
            self.desglose = nil
        }
        self.uuid = transaccion.uuid
        self.updatedAt = transaccion.updatedAt.epochMillis
        self.syncStatus = 0
        self.isDeleted = transaccion.isDeleted ? 1 : 0
    }

    func aModelo() -> Transaccion? {
        guard let tipoEnum = TipoTransaccion(rawValue: tipo),
              let metodoEnum = MetodoPago(rawValue: metodo),
              let fechaDate = FormatoFecha.parsearFecha(fecha),
              let horaDate = FormatoFecha.parsearHora(hora) else {
            return nil
        }
        let montoDecimal = monto.aDecimal
        var desgloseStruct: DesgloseBilletes?
        if let json = desglose, let data = json.data(using: .utf8) {
            desgloseStruct = try? JSONDecoder().decode(DesgloseBilletes.self, from: data)
        }
        return Transaccion(
            id: id,
            fecha: fechaDate,
            hora: horaDate,
            concepto: concepto,
            monto: montoDecimal,
            tipo: tipoEnum,
            categoria: categoria,
            metodo: metodoEnum,
            desglose: desgloseStruct,
            uuid: uuid,
            updatedAt: Date(epochMillis: updatedAt),
            isDeleted: isDeleted != 0
        )
    }
}

struct InventarioRecord: FetchableRecord, MutablePersistableRecord, Codable {
    static let databaseTableName = EsquemaColumnas.Inventario.tabla

    var denominacion: Int
    var cantidad: Int
    var actualizadoEn: String
    var updatedAt: Int64
    var syncStatus: Int
    var isDeleted: Int

    enum CodingKeys: String, CodingKey {
        case denominacion, cantidad, actualizadoEn
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
        case isDeleted = "is_deleted"
    }

    init(
        denominacion: Int,
        cantidad: Int,
        actualizadoEn: String,
        updatedAt: Int64 = Date().epochMillis,
        syncStatus: Int = 0,
        isDeleted: Int = 0
    ) {
        self.denominacion = denominacion
        self.cantidad = cantidad
        self.actualizadoEn = actualizadoEn
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isDeleted = isDeleted
    }

    init(_ inventario: Inventario) {
        self.denominacion = inventario.denominacion
        self.cantidad = inventario.cantidad
        self.actualizadoEn = FormatoFecha.formatearFechaHora(inventario.actualizadoEn)
        self.updatedAt = Date().epochMillis
        self.syncStatus = 0
        self.isDeleted = 0
    }

    func aModelo() -> Inventario? {
        guard let fecha = FormatoFecha.parsearFechaHora(actualizadoEn) else { return nil }
        return Inventario(denominacion: denominacion, cantidad: cantidad, actualizadoEn: fecha)
    }
}

struct PrestamoRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = EsquemaColumnas.Prestamo.tabla

    var id: Int64?
    var persona: String
    var concepto: String
    var monto: Int64
    var tipo: String
    var fecha: String
    var afectaBalance: Int
    var montoPagado: Int64
    var notas: String?
    var uuid: String
    var updatedAt: Int64
    var syncStatus: Int
    var isDeleted: Int

    enum CodingKeys: String, CodingKey {
        case id, persona, concepto, monto, tipo, fecha, afectaBalance, montoPagado, notas, uuid
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
        case isDeleted = "is_deleted"
    }

    init(
        id: Int64? = nil,
        persona: String,
        concepto: String,
        monto: Int64,
        tipo: String,
        fecha: String,
        afectaBalance: Int,
        montoPagado: Int64 = 0,
        notas: String? = nil,
        uuid: String? = nil,
        updatedAt: Int64 = Date().epochMillis,
        syncStatus: Int = 0,
        isDeleted: Int = 0
    ) {
        self.id = id
        self.persona = persona
        self.concepto = concepto
        self.monto = monto
        self.tipo = tipo
        self.fecha = fecha
        self.afectaBalance = afectaBalance
        self.montoPagado = montoPagado
        self.notas = notas
        self.uuid = uuid ?? UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isDeleted = isDeleted
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(_ prestamo: Prestamo) {
        self.id = prestamo.id
        self.persona = prestamo.persona
        self.concepto = prestamo.concepto
        self.monto = prestamo.monto.centavos
        self.tipo = prestamo.tipo.rawValue
        self.fecha = FormatoFecha.formatearFecha(prestamo.fecha)
        self.afectaBalance = prestamo.afectaBalance ? 1 : 0
        self.montoPagado = prestamo.montoPagado.centavos
        self.notas = prestamo.notas
        self.uuid = prestamo.uuid
        self.updatedAt = prestamo.updatedAt.epochMillis
        self.syncStatus = 0
        self.isDeleted = prestamo.isDeleted ? 1 : 0
    }

    func aModelo() -> Prestamo? {
        guard let tipoEnum = TipoPrestamo(rawValue: tipo),
              let fechaDate = FormatoFecha.parsearFecha(fecha) else { return nil }
        return Prestamo(
            id: id,
            persona: persona,
            concepto: concepto,
            monto: monto.aDecimal,
            tipo: tipoEnum,
            fecha: fechaDate,
            afectaBalance: afectaBalance != 0,
            montoPagado: montoPagado.aDecimal,
            notas: notas,
            uuid: uuid,
            updatedAt: Date(epochMillis: updatedAt),
            isDeleted: isDeleted != 0
        )
    }
}

struct SuscripcionRecord: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = EsquemaColumnas.Suscripcion.tabla

    var id: Int64?
    var concepto: String
    var monto: Int64
    var categoria: String
    var frecuencia: String
    var tipo: String
    var fechaInicio: String
    var proximoCobro: String
    var notas: String?
    var duracionMeses: Int?
    var metodoPago: String
    var activa: Int
    var notificado: Int
    var uuid: String
    var updatedAt: Int64
    var syncStatus: Int
    var isDeleted: Int

    enum CodingKeys: String, CodingKey {
        case id, concepto, monto, categoria, frecuencia, tipo, fechaInicio, proximoCobro
        case notas, duracionMeses, metodoPago, activa, notificado, uuid
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
        case isDeleted = "is_deleted"
    }

    init(
        id: Int64? = nil,
        concepto: String,
        monto: Int64,
        categoria: String,
        frecuencia: String,
        tipo: String,
        fechaInicio: String,
        proximoCobro: String,
        notas: String? = nil,
        duracionMeses: Int? = nil,
        metodoPago: String = "Tarjeta",
        activa: Int = 1,
        notificado: Int = 0,
        uuid: String? = nil,
        updatedAt: Int64 = Date().epochMillis,
        syncStatus: Int = 0,
        isDeleted: Int = 0
    ) {
        self.id = id
        self.concepto = concepto
        self.monto = monto
        self.categoria = categoria
        self.frecuencia = frecuencia
        self.tipo = tipo
        self.fechaInicio = fechaInicio
        self.proximoCobro = proximoCobro
        self.notas = notas
        self.duracionMeses = duracionMeses
        self.metodoPago = metodoPago
        self.activa = activa
        self.notificado = notificado
        self.uuid = uuid ?? UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isDeleted = isDeleted
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    init(_ s: Suscripcion) {
        self.id = s.id
        self.concepto = s.concepto
        self.monto = s.monto.centavos
        self.categoria = s.categoria
        self.frecuencia = s.frecuencia.rawValue
        self.tipo = s.tipo.rawValue
        self.fechaInicio = FormatoFecha.formatearFecha(s.fechaInicio)
        self.proximoCobro = FormatoFecha.formatearFecha(s.proximoCobro)
        self.notas = s.notas
        self.duracionMeses = s.duracionMeses
        self.metodoPago = s.metodoPago.rawValue
        self.activa = s.activa ? 1 : 0
        self.notificado = s.notificado ? 1 : 0
        self.uuid = s.uuid
        self.updatedAt = s.updatedAt.epochMillis
        self.syncStatus = 0
        self.isDeleted = s.isDeleted ? 1 : 0
    }

    func aModelo() -> Suscripcion? {
        guard let frecuenciaEnum = FrecuenciaSuscripcion(rawValue: frecuencia),
              let tipoEnum = TipoTransaccion(rawValue: tipo),
              let fechaInicioDate = FormatoFecha.parsearFecha(fechaInicio),
              let proximoCobroDate = FormatoFecha.parsearFecha(proximoCobro) else {
            return nil
        }
        let metodoPagoEnum = MetodoPago(rawValue: metodoPago) ?? .tarjeta
        return Suscripcion(
            id: id,
            concepto: concepto,
            monto: monto.aDecimal,
            categoria: categoria,
            frecuencia: frecuenciaEnum,
            tipo: tipoEnum,
            fechaInicio: fechaInicioDate,
            proximoCobro: proximoCobroDate,
            notas: notas,
            duracionMeses: duracionMeses.flatMap { $0 > 0 ? $0 : nil },
            metodoPago: metodoPagoEnum,
            activa: activa != 0,
            notificado: notificado != 0,
            uuid: uuid,
            updatedAt: Date(epochMillis: updatedAt),
            isDeleted: isDeleted != 0
        )
    }
}

struct SaldoInicialRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = EsquemaColumnas.SaldoInicial.tabla

    var id: Int
    var efectivo: Int64
    var tarjeta: Int64
    var fechaCreacion: String
    var inventarioJson: String
    var uuid: String
    var updatedAt: Int64
    var syncStatus: Int
    var isDeleted: Int

    enum CodingKeys: String, CodingKey {
        case id, efectivo, tarjeta, fechaCreacion, inventarioJson, uuid
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
        case isDeleted = "is_deleted"
    }

    init(
        id: Int = 1,
        efectivo: Int64,
        tarjeta: Int64,
        fechaCreacion: String,
        inventarioJson: String,
        uuid: String? = nil,
        updatedAt: Int64 = Date().epochMillis,
        syncStatus: Int = 0,
        isDeleted: Int = 0
    ) {
        self.id = id
        self.efectivo = efectivo
        self.tarjeta = tarjeta
        self.fechaCreacion = fechaCreacion
        self.inventarioJson = inventarioJson
        self.uuid = uuid ?? UUID().uuidString.lowercased()
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
        self.isDeleted = isDeleted
    }

    init(_ s: SaldoInicial, inventario: [Inventario]) {
        self.id = 1
        self.efectivo = s.efectivo.centavos
        self.tarjeta = s.tarjeta.centavos
        self.fechaCreacion = FormatoFecha.formatearFechaHora(s.fechaCreacion)
        let records = inventario.map { InventarioRecord($0) }
        if let data = try? JSONEncoder().encode(records),
           let json = String(data: data, encoding: .utf8) {
            self.inventarioJson = json
        } else {
            self.inventarioJson = "[]"
        }
        self.uuid = UUID().uuidString.lowercased()
        self.updatedAt = Date().epochMillis
        self.syncStatus = 0
        self.isDeleted = 0
    }

    func aModelo() -> SaldoInicial? {
        guard let fecha = FormatoFecha.parsearFechaHora(fechaCreacion) else { return nil }
        let inventario: [Inventario] = {
            guard let data = inventarioJson.data(using: .utf8) else { return [] }
            let records = (try? JSONDecoder().decode([InventarioRecord].self, from: data)) ?? []
            return records.compactMap { $0.aModelo() }
        }()
        return SaldoInicial(
            efectivo: efectivo.aDecimal,
            tarjeta: tarjeta.aDecimal,
            fechaCreacion: fecha,
            inventarioInicial: inventario
        )
    }
}

struct MetadataRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = EsquemaColumnas.Metadata.tabla

    var clave: String
    var valor: String
}

extension Decimal {
    var centavos: Int64 {
        var resultado = Decimal()
        var copia = self
        NSDecimalRound(&resultado, &copia, 2, .bankers)
        let cents = resultado * 100
        return NSDecimalNumber(decimal: cents).int64Value
    }
}

extension Int64 {
    var aDecimal: Decimal {
        Decimal(self) / 100
    }
}

// MARK: - Sync helpers

extension Date {
    public var epochMillis: Int64 {
        Int64(self.timeIntervalSince1970 * 1000)
    }

    public init(epochMillis: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(epochMillis) / 1000)
    }
}

let syncMetaKey = "last_synced_at_millis"
