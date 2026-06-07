import Foundation
import GRDB
import Models
import Database

public struct SubscriptionService: Sendable {
    private let manager: DatabaseManager
    private let subRepo: any SubscriptionRepository

    public init(manager: DatabaseManager, subRepo: any SubscriptionRepository) {
        self.manager = manager
        self.subRepo = subRepo
    }

    @discardableResult
    public func crear(_ suscripcion: Suscripcion) async throws -> Suscripcion {
        try Self.validar(suscripcion)
        return try await subRepo.insertar(suscripcion)
    }

    @discardableResult
    public func actualizar(_ suscripcion: Suscripcion) async throws -> Suscripcion {
        guard suscripcion.id != nil else { throw AppDatabaseError.filaNoEncontrada }
        try Self.validar(suscripcion)
        return try await subRepo.actualizar(suscripcion)
    }

    public func eliminar(id: Int64) async throws {
        try await subRepo.eliminar(id: id)
    }

    public func alternarActiva(id: Int64) async throws -> Suscripcion {
        try await manager.escribir { db in
            guard let actual = try subRepo.obtenerEn(db: db, id: id) else {
                throw AppDatabaseError.filaNoEncontrada
            }
            var nueva = actual
            nueva.activa.toggle()
            return try subRepo.actualizarEn(db: db, nueva)
        }
    }

    public func registrarCobro(id: Int64) async throws -> Suscripcion {
        try await manager.escribir { db in
            guard let actual = try subRepo.obtenerEn(db: db, id: id) else {
                throw AppDatabaseError.filaNoEncontrada
            }
            let nuevoProximo = Suscripcion.calcularProximoCobro(
                desde: actual.proximoCobro,
                frecuencia: actual.frecuencia
            )
            var nueva = actual
            nueva.proximoCobro = nuevoProximo
            nueva.notificado = false
            return try subRepo.actualizarEn(db: db, nueva)
        }
    }

    public func marcarNotificada(id: Int64) async throws {
        try await subRepo.marcarNotificada(id: id)
    }

    public func listarProximasAVencer(dentroDe dias: Int = 3) async throws -> [Suscripcion] {
        try await subRepo.listarProximasAVencer(dentroDe: dias, referencia: Date())
    }

    static func validar(_ suscripcion: Suscripcion) throws {
        if suscripcion.concepto.trimmingCharacters(in: .whitespaces).isEmpty {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El concepto no puede estar vacío")
        }
        if suscripcion.monto <= 0 {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El monto debe ser mayor a 0")
        }
        if let duracion = suscripcion.duracionMeses, duracion < 0 {
            throw AppDatabaseError.esquemaInvalido(mensaje: "La duración no puede ser negativa")
        }
    }
}
