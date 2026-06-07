import Foundation
import Models
import Database

public struct ConfiguracionUsuario: Codable, Equatable, Sendable {
    public var metaAhorroMensual: Decimal
    public var ventanaHistoricoMeses: Int
    public var notificacionesHabilitadas: Bool

    public init(
        metaAhorroMensual: Decimal = 0,
        ventanaHistoricoMeses: Int = 3,
        notificacionesHabilitadas: Bool = true
    ) {
        self.metaAhorroMensual = metaAhorroMensual
        self.ventanaHistoricoMeses = max(1, min(12, ventanaHistoricoMeses))
        self.notificacionesHabilitadas = notificacionesHabilitadas
    }

    public static let defecto = ConfiguracionUsuario()

    public static let clavePersistencia = "configuracion_usuario"
}

public struct ConfigurationService: Sendable {
    private let repo: any ConfigurationRepository

    public init(repo: any ConfigurationRepository) {
        self.repo = repo
    }

    public func obtener() async throws -> ConfiguracionUsuario {
        guard let json = try await repo.obtener(clave: ConfiguracionUsuario.clavePersistencia) else {
            return .defecto
        }
        guard let data = json.data(using: .utf8) else {
            return .defecto
        }
        return (try? JSONDecoder().decode(ConfiguracionUsuario.self, from: data)) ?? .defecto
    }

    public func guardar(_ configuracion: ConfiguracionUsuario) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(configuracion)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        try await repo.guardar(clave: ConfiguracionUsuario.clavePersistencia, valor: json)
    }

    public func restablecer() async throws {
        try await repo.eliminar(clave: ConfiguracionUsuario.clavePersistencia)
    }
}
