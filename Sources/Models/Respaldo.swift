import Foundation

public struct Respaldo: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let url: URL
    public let fecha: Date
    public let tamano: Int64
    public let versionApp: String
    public let versionEsquema: Int
    public let automatico: Bool
    public let nota: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        fecha: Date,
        tamano: Int64,
        versionApp: String,
        versionEsquema: Int,
        automatico: Bool,
        nota: String? = nil
    ) {
        self.id = id
        self.url = url
        self.fecha = fecha
        self.tamano = tamano
        self.versionApp = versionApp
        self.versionEsquema = versionEsquema
        self.automatico = automatico
        self.nota = nota
    }

    public var nombreArchivo: String {
        url.lastPathComponent
    }
}

public enum BackupError: LocalizedError, Equatable {
    case formatoInvalido
    case versionNoSoportada(UInt32)
    case archivoVacio
    case esquemaIncompatible(archivo: Int, actual: Int)
    case escritura(String)
    case lectura(String)
    case archivoNoExiste

    public var errorDescription: String? {
        switch self {
        case .formatoInvalido:
            return "El archivo no es un respaldo válido de TransactApp."
        case .versionNoSoportada(let v):
            return "Versión de formato de respaldo \(v) no soportada."
        case .archivoVacio:
            return "El archivo de respaldo está vacío o corrupto."
        case .esquemaIncompatible(let archivo, let actual):
            return "El respaldo fue creado con esquema v\(archivo) pero la app usa v\(actual). Restaura una versión de TransactApp que coincida."
        case .escritura(let msg):
            return "No se pudo escribir el respaldo: \(msg)"
        case .lectura(let msg):
            return "No se pudo leer el respaldo: \(msg)"
        case .archivoNoExiste:
            return "El archivo de respaldo no existe."
        }
    }
}
