import Foundation
import GRDB
import Models
import Database

public struct LoanService: Sendable {
    private let manager: DatabaseManager
    private let loanRepo: any LoanRepository

    public init(manager: DatabaseManager, loanRepo: any LoanRepository) {
        self.manager = manager
        self.loanRepo = loanRepo
    }

    @discardableResult
    public func crear(_ prestamo: Prestamo) async throws -> Prestamo {
        try Self.validar(prestamo)
        return try await loanRepo.insertar(prestamo)
    }

    @discardableResult
    public func actualizar(_ prestamo: Prestamo) async throws -> Prestamo {
        guard prestamo.id != nil else { throw AppDatabaseError.filaNoEncontrada }
        try Self.validar(prestamo)
        return try await loanRepo.actualizar(prestamo)
    }

    public func eliminar(id: Int64) async throws {
        try await loanRepo.eliminar(id: id)
    }

    public func registrarPago(id: Int64, monto: Decimal) async throws -> Prestamo {
        guard monto > 0 else {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El pago debe ser mayor a 0")
        }
        return try await manager.escribir { db in
            guard let actual = try loanRepo.obtenerEn(db: db, id: id) else {
                throw AppDatabaseError.filaNoEncontrada
            }
            var nuevoMontoPagado = actual.montoPagado + monto
            if nuevoMontoPagado > actual.monto {
                nuevoMontoPagado = actual.monto
            }
            var actualizado = actual
            actualizado.montoPagado = nuevoMontoPagado
            return try loanRepo.actualizarEn(db: db, actualizado)
        }
    }

    public func registrarPagoConTransaccion(
        prestamoId: Int64,
        montoPago: Decimal,
        transaccion: Transaccion,
        transactionRepo: any TransactionRepository,
        inventoryRepo: any InventoryRepository
    ) async throws {
        guard montoPago > 0 else {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El pago debe ser mayor a 0")
        }
        try await manager.escribir { db in
            guard var prestamo = try loanRepo.obtenerEn(db: db, id: prestamoId) else {
                throw AppDatabaseError.filaNoEncontrada
            }
            let nuevoPagado = min(prestamo.monto, prestamo.montoPagado + montoPago)
            prestamo.montoPagado = nuevoPagado
            try loanRepo.actualizarEn(db: db, prestamo)

            let guardada = try transactionRepo.insertarEn(db: db, transaccion)
            try TransactionService.aplicar(db, transaccion: guardada, inventoryRepo: inventoryRepo)
        }
    }

    static func validar(_ prestamo: Prestamo) throws {
        if prestamo.persona.trimmingCharacters(in: .whitespaces).isEmpty {
            throw AppDatabaseError.esquemaInvalido(mensaje: "La persona no puede estar vacía")
        }
        if prestamo.monto <= 0 {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El monto debe ser mayor a 0")
        }
        if prestamo.montoPagado < 0 {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El monto pagado no puede ser negativo")
        }
        if prestamo.montoPagado > prestamo.monto {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El monto pagado no puede superar el total")
        }
    }
}
