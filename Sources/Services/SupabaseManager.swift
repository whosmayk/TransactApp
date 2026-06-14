import Foundation
import Database

public struct SupabaseSession: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }

    public init(accessToken: String, refreshToken: String, expiresAt: Int64) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }
}

public enum SupabaseError: LocalizedError, Sendable {
    case noAutenticado
    case red(Int, String)
    case decodificador(String)
    case otro(String)

    public var errorDescription: String? {
        switch self {
        case .noAutenticado: "No autenticado. Inicia sesión primero."
        case .red(let code, let msg): "Error del servidor (\(code)): \(msg)"
        case .decodificador(let msg): "Error de datos: \(msg)"
        case .otro(let msg): msg
        }
    }
}

public final class SupabaseManager: @unchecked Sendable {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public var token: String?

    public init() {}

    // MARK: - Auth

    public func enviarMagicLink(email: String, redirectTo: String = "https://web-six-bay-57.vercel.app") async throws {
        let url = URL(string: "\(SupabaseConfig.authURL)/otp")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: SupabaseConfig.apiKeyHeader)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "email": email,
            "create_user": true,
            "redirect_to": redirectTo
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyStr = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.red(code, "Error enviando magic link: \(bodyStr)")
        }
    }

    @discardableResult
    public func verificarOTP(email: String, token: String) async throws -> SupabaseSession {
        let url = URL(string: "\(SupabaseConfig.authURL)/verify")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: SupabaseConfig.apiKeyHeader)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "email": email,
            "token": token,
            "type": "magiclink"
        ]
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SupabaseError.red((response as? HTTPURLResponse)?.statusCode ?? 0, "Token inválido o expirado")
        }
        let sesion = try decoder.decode(SupabaseSession.self, from: data)
        self.token = sesion.accessToken
        return sesion
    }

    @discardableResult
    public func refrescarToken(_ refreshToken: String) async throws -> SupabaseSession {
        let url = URL(string: "\(SupabaseConfig.authURL)/token?grant_type=refresh_token")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: SupabaseConfig.apiKeyHeader)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["refresh_token": refreshToken]
        req.httpBody = try encoder.encode(body)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SupabaseError.red((response as? HTTPURLResponse)?.statusCode ?? 0, "Error refrescando sesión")
        }
        let sesion = try decoder.decode(SupabaseSession.self, from: data)
        self.token = sesion.accessToken
        return sesion
    }

    // MARK: - Data API

    public func select(
        tabla: String,
        since: Int64? = nil,
        columnas: String = "*"
    ) async throws -> [[String: Any]] {
        var urlComp = URLComponents(string: "\(SupabaseConfig.restURL)/\(tabla)")!
        var queryItems = [URLQueryItem(name: "select", value: columnas)]
        if let since {
            queryItems.append(URLQueryItem(name: "updated_at", value: "gte.\(since)"))
        }
        queryItems.append(URLQueryItem(name: "order", value: "updated_at.asc"))
        urlComp.queryItems = queryItems
        var req = URLRequest(url: urlComp.url!)
        req.httpMethod = "GET"
        aplicarCabeceras(&req)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SupabaseError.red((response as? HTTPURLResponse)?.statusCode ?? 0, "Error consultando datos")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw SupabaseError.decodificador("Formato de respuesta inesperado")
        }
        return json
    }

    public func insertar(tabla: String, body: [String: Any]) async throws {
        let url = URL(string: "\(SupabaseConfig.restURL)/\(tabla)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        aplicarCabeceras(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SupabaseError.red(code, "Error insertando en \(tabla)")
        }
    }

    public func actualizar(tabla: String, uuid: String, body: [String: Any]) async throws {
        let url = URL(string: "\(SupabaseConfig.restURL)/\(tabla)?uuid=eq.\(uuid)")!
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        aplicarCabeceras(&req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SupabaseError.red(code, "Error actualizando \(tabla)/\(uuid)")
        }
    }

    public func eliminar(tabla: String, uuid: String) async throws {
        let url = URL(string: "\(SupabaseConfig.restURL)/\(tabla)?uuid=eq.\(uuid)")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        aplicarCabeceras(&req)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...204).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw SupabaseError.red(code, "Error eliminando \(tabla)/\(uuid)")
        }
    }

    // MARK: - Helpers

    private func aplicarCabeceras(_ req: inout URLRequest) {
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: SupabaseConfig.apiKeyHeader)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: SupabaseConfig.bearerHeader)
        }
    }
}
