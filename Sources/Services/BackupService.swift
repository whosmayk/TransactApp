import Foundation
import Database
import Models

public struct EncabezadoRespaldo: Sendable, Equatable {
    public let formatoVersion: UInt32
    public let versionApp: String
    public let versionEsquema: Int
    public let fecha: Date
    public let tamanoSQLite: Int64

    public static let tamanoBytes = 4 + 4 + 4 + 8 + 8
}

public final class BackupService: @unchecked Sendable {
    public static let magic: [UInt8] = [0x54, 0x52, 0x42, 0x4B]
    public static let formatoVersion: UInt32 = 1
    public static let extensionArchivo = "transactapp"

    public let directorioRespaldos: URL
    private let database: DatabaseManager
    private let esquemaActual: Int
    private let versionApp: String
    private let retencionAutomatica: Int

    public init(
        database: DatabaseManager,
        directorioRespaldos: URL? = nil,
        versionApp: String = "0.6.0",
        esquemaActual: Int = Migrator.versionActual,
        retencionAutomatica: Int = 10
    ) {
        self.database = database
        self.directorioRespaldos = directorioRespaldos ?? Self.directorioPorDefecto()
        self.versionApp = versionApp
        self.esquemaActual = esquemaActual
        self.retencionAutomatica = retencionAutomatica
        try? FileManager.default.createDirectory(at: self.directorioRespaldos, withIntermediateDirectories: true)
    }

    public static func directorioPorDefecto() -> URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport
            .appendingPathComponent("TransactApp", isDirectory: true)
            .appendingPathComponent("Respaldos", isDirectory: true)
        return dir
    }

    public func crearRespaldo(
        nota: String? = nil,
        automatico: Bool = false
    ) throws -> Respaldo {
        let bytesSQLite = try serializarSQLite()

        let fecha = Date()
        let id = UUID()
        let nombreArchivo = nombreArchivoPara(fecha: fecha, id: id, automatico: automatico)
        let destino = directorioRespaldos.appendingPathComponent(nombreArchivo)

        let encabezado = EncabezadoRespaldo(
            formatoVersion: Self.formatoVersion,
            versionApp: versionApp,
            versionEsquema: esquemaActual,
            fecha: fecha,
            tamanoSQLite: Int64(bytesSQLite.count)
        )

        do {
            try escribirRespaldo(a: destino, encabezado: encabezado, sqlite: bytesSQLite)
        } catch {
            throw BackupError.escritura(error.localizedDescription)
        }

        let atributos = try FileManager.default.attributesOfItem(atPath: destino.path)
        let tamano = (atributos[.size] as? Int64) ?? Int64(bytesSQLite.count + EncabezadoRespaldo.tamanoBytes)

        let respaldo = Respaldo(
            id: id,
            url: destino,
            fecha: fecha,
            tamano: tamano,
            versionApp: versionApp,
            versionEsquema: esquemaActual,
            automatico: automatico,
            nota: nota
        )

        escribirMetadatosLado(respaldo)

        if automatico {
            try? limpiarRespaldosAutomaticos(mantener: retencionAutomatica)
        }

        return respaldo
    }

    public func importarDesdeArchivo(_ origen: URL) throws -> Respaldo {
        guard FileManager.default.fileExists(atPath: origen.path) else {
            throw BackupError.archivoNoExiste
        }

        let (encabezado, _) = try leerEncabezado(desde: origen)

        let fecha = Date()
        let id = UUID()
        let timestamp = formatoTimestamp(fecha)
        let corto = String(id.uuidString.prefix(8))
        let nombreDestino = "TransactApp-\(timestamp)-importado-\(corto).\(Self.extensionArchivo)"
        let destino = directorioRespaldos.appendingPathComponent(nombreDestino)

        do {
            try FileManager.default.copyItem(at: origen, to: destino)
        } catch {
            throw BackupError.escritura(error.localizedDescription)
        }

        let atributos = try FileManager.default.attributesOfItem(atPath: destino.path)
        let tamano = (atributos[FileAttributeKey.size] as? Int64) ?? 0

        let respaldo = Respaldo(
            id: id,
            url: destino,
            fecha: fecha,
            tamano: tamano,
            versionApp: encabezado.versionApp,
            versionEsquema: encabezado.versionEsquema,
            automatico: false,
            nota: "Importado de \(origen.lastPathComponent)"
        )

        escribirMetadatosLado(respaldo)
        return respaldo
    }

    public func restaurar(_ respaldo: Respaldo) throws {
        try restaurar(desde: respaldo.url)
    }

    public func restaurar(desde url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw BackupError.archivoNoExiste
        }

        let (encabezado, bytesSQLite) = try leerEncabezado(desde: url)

        if encabezado.versionEsquema > esquemaActual {
            throw BackupError.esquemaIncompatible(
                archivo: encabezado.versionEsquema,
                actual: esquemaActual
            )
        }

        let temp = directorioRespaldos.appendingPathComponent("restaurar-\(UUID().uuidString).sqlite")
        do {
            try bytesSQLite.write(to: temp, options: .atomic)
            try database.reemplazarArchivo(desde: temp)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw BackupError.lectura(error.localizedDescription)
        }
        try? FileManager.default.removeItem(at: temp)
    }

    public func listar() throws -> [Respaldo] {
        let fm = FileManager.default
        guard let archivos = try? fm.contentsOfDirectory(
            at: directorioRespaldos,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let metadatos = leerMetadatosLado()

        return archivos
            .filter { $0.pathExtension == Self.extensionArchivo }
            .compactMap { url -> Respaldo? in
                if let meta = metadatos[url.lastPathComponent] {
                    return Respaldo(
                        id: meta.id,
                        url: url,
                        fecha: meta.fecha,
                        tamano: meta.tamano,
                        versionApp: meta.versionApp,
                        versionEsquema: meta.versionEsquema,
                        automatico: meta.automatico,
                        nota: meta.nota
                    )
                }
                return leerRespaldoDesdeArchivo(url)
            }
            .sorted { $0.fecha > $1.fecha }
    }

    public func eliminar(_ respaldo: Respaldo) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: respaldo.url.path) {
            try fm.removeItem(at: respaldo.url)
        }
        eliminarMetadatosLado(nombre: respaldo.nombreArchivo)
    }

    public func limpiarRespaldosAutomaticos(mantener n: Int) throws {
        let todos = try listar()
        let automaticos = todos.filter { $0.automatico }
        guard automaticos.count > n else { return }
        let aEliminar = automaticos.dropFirst(n)
        for r in aEliminar {
            try? eliminar(r)
        }
    }

    public func leerEncabezado(desde url: URL) throws -> (EncabezadoRespaldo, Data) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw BackupError.archivoNoExiste
        }
        defer { try? handle.close() }

        guard let datos = try? handle.readToEnd() else {
            throw BackupError.archivoVacio
        }

        guard datos.count >= 4 + EncabezadoRespaldo.tamanoBytes else {
            throw BackupError.formatoInvalido
        }

        let magicDatos = Array(datos.prefix(4))
        guard magicDatos == Self.magic else {
            throw BackupError.formatoInvalido
        }

        var offset = 4
        let formato = datos.leerUInt32(en: &offset)
        guard formato == Self.formatoVersion else {
            throw BackupError.versionNoSoportada(formato)
        }

        let longitudVersion = Int(datos.leerUInt32(en: &offset))
        guard datos.count >= offset + longitudVersion + 4 + 8 + 8 else {
            throw BackupError.formatoInvalido
        }
        let versionBytes = datos.subdata(in: offset..<(offset + longitudVersion))
        guard let version = String(data: versionBytes, encoding: .utf8) else {
            throw BackupError.formatoInvalido
        }
        offset += longitudVersion

        let esquema = Int(datos.leerUInt32(en: &offset))
        let fechaUnix = datos.leerInt64(en: &offset)
        let tamano = datos.leerInt64(en: &offset)
        let fecha = Date(timeIntervalSince1970: TimeInterval(fechaUnix))

        let headerSize = 4 + EncabezadoRespaldo.tamanoBytes + longitudVersion
        let totalEsperado = headerSize + Int(tamano)
        guard datos.count >= totalEsperado else {
            throw BackupError.archivoVacio
        }
        let sqlite = datos.subdata(in: headerSize..<totalEsperado)

        let encabezado = EncabezadoRespaldo(
            formatoVersion: formato,
            versionApp: version,
            versionEsquema: esquema,
            fecha: fecha,
            tamanoSQLite: tamano
        )

        return (encabezado, sqlite)
    }

    private func leerRespaldoDesdeArchivo(_ url: URL) -> Respaldo? {
        do {
            let (encabezado, _) = try leerEncabezado(desde: url)
            let atributos = try FileManager.default.attributesOfItem(atPath: url.path)
            let tamano = (atributos[FileAttributeKey.size] as? Int64) ?? 0
            return Respaldo(
                id: UUID(),
                url: url,
                fecha: encabezado.fecha,
                tamano: tamano,
                versionApp: encabezado.versionApp,
                versionEsquema: encabezado.versionEsquema,
                automatico: false,
                nota: String?.none
            )
        } catch {
            return nil
        }
    }

    private func serializarSQLite() throws -> Data {
        let urlTemp = FileManager.default.temporaryDirectory
            .appendingPathComponent("transactapp-serializar-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: urlTemp) }

        let cola = database.dbQueue
        try cola.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM INTO ?", arguments: [urlTemp.path])
        }

        let handle = try FileHandle(forReadingFrom: urlTemp)
        defer { try? handle.close() }
        return try handle.readToEnd() ?? Data()
    }

    private func escribirRespaldo(a url: URL, encabezado: EncabezadoRespaldo, sqlite: Data) throws {
        var datos = Data()
        datos.append(contentsOf: Self.magic)

        datos.appendUInt32(encabezado.formatoVersion)

        let versionBytes = Array(encabezado.versionApp.utf8)
        datos.appendUInt32(UInt32(versionBytes.count))
        datos.append(contentsOf: versionBytes)

        datos.appendUInt32(UInt32(encabezado.versionEsquema))
        datos.appendInt64(Int64(encabezado.fecha.timeIntervalSince1970))
        datos.appendInt64(encabezado.tamanoSQLite)

        datos.append(sqlite)

        try datos.write(to: url, options: .atomic)
    }

    private func nombreArchivoPara(fecha: Date, id: UUID, automatico: Bool) -> String {
        let sufijo = automatico ? "auto" : "manual"
        let corto = String(id.uuidString.prefix(8))
        return "TransactApp-\(formatoTimestamp(fecha))-\(sufijo)-\(corto).\(Self.extensionArchivo)"
    }

    private func formatoTimestamp(_ fecha: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: fecha)
    }

    private var rutaMetadatos: URL {
        directorioRespaldos.appendingPathComponent(".index.json")
    }

    private func leerMetadatosLado() -> [String: RespaldoJSON] {
        let url = rutaMetadatos
        guard let datos = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: RespaldoJSON].self, from: datos)
        else {
            return [:]
        }
        return dict
    }

    private func escribirMetadatosLado(_ respaldo: Respaldo) {
        var dict = leerMetadatosLado()
        let json = RespaldoJSON(
            id: respaldo.id,
            fecha: respaldo.fecha,
            tamano: respaldo.tamano,
            versionApp: respaldo.versionApp,
            versionEsquema: respaldo.versionEsquema,
            automatico: respaldo.automatico,
            nota: respaldo.nota
        )
        dict[respaldo.nombreArchivo] = json
        if let datos = try? JSONEncoder().encode(dict) {
            try? datos.write(to: rutaMetadatos, options: Data.WritingOptions.atomic)
        }
    }

    private func eliminarMetadatosLado(nombre: String) {
        var dict = leerMetadatosLado()
        dict[nombre] = nil
        if let datos = try? JSONEncoder().encode(dict) {
            try? datos.write(to: rutaMetadatos, options: Data.WritingOptions.atomic)
        }
    }
}

private struct RespaldoJSON: Codable {
    let id: UUID
    let fecha: Date
    let tamano: Int64
    let versionApp: String
    let versionEsquema: Int
    let automatico: Bool
    let nota: String?

    init(
        id: UUID,
        fecha: Date,
        tamano: Int64,
        versionApp: String,
        versionEsquema: Int,
        automatico: Bool,
        nota: String?
    ) {
        self.id = id
        self.fecha = fecha
        self.tamano = tamano
        self.versionApp = versionApp
        self.versionEsquema = versionEsquema
        self.automatico = automatico
        self.nota = nota
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.fecha = try c.decode(Date.self, forKey: .fecha)
        self.tamano = try c.decode(Int64.self, forKey: .tamano)
        self.versionApp = try c.decode(String.self, forKey: .versionApp)
        self.versionEsquema = try c.decode(Int.self, forKey: .versionEsquema)
        self.automatico = try c.decode(Bool.self, forKey: .automatico)
        self.nota = try c.decodeIfPresent(String.self, forKey: .nota)
    }
}

extension Data {
    mutating func appendUInt32(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }

    mutating func appendInt64(_ value: Int64) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { self.append(contentsOf: $0) }
    }

    func leerUInt32(en offset: inout Int) -> UInt32 {
        let valor: UInt32 = self.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return 0 }
            var v: UInt32 = 0
            memcpy(&v, base.advanced(by: offset), 4)
            return UInt32(littleEndian: v)
        }
        offset += 4
        return valor
    }

    func leerInt64(en offset: inout Int) -> Int64 {
        let valor: Int64 = self.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return 0 }
            var v: Int64 = 0
            memcpy(&v, base.advanced(by: offset), 8)
            return Int64(littleEndian: v)
        }
        offset += 8
        return valor
    }
}
