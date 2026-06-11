import Foundation
import GRDB
import Models
import Database

public struct TransactionService: Sendable {
    private let manager: DatabaseManager
    private let transactionRepo: any TransactionRepository
    private let inventoryRepo: any InventoryRepository

    public init(
        manager: DatabaseManager,
        transactionRepo: any TransactionRepository,
        inventoryRepo: any InventoryRepository
    ) {
        self.manager = manager
        self.transactionRepo = transactionRepo
        self.inventoryRepo = inventoryRepo
    }

    @discardableResult
    public func crear(_ transaccion: Transaccion) async throws -> Transaccion {
        try await manager.escribir { db in
            let guardada = try transactionRepo.insertarEn(db: db, transaccion)
            try Self.aplicar(db, transaccion: guardada, inventoryRepo: inventoryRepo)
            return guardada
        }
    }

    public func actualizar(_ nueva: Transaccion, original: Transaccion) async throws -> Transaccion {
        try await manager.escribir { db in
            try Self.revertir(db, transaccion: original, inventoryRepo: inventoryRepo)
            let guardada = try transactionRepo.actualizarEn(db: db, nueva)
            try Self.aplicar(db, transaccion: guardada, inventoryRepo: inventoryRepo)
            return guardada
        }
    }

    public func crearDeposito(
        monto: Decimal,
        concepto: String,
        desglose: DesgloseBilletes?
    ) async throws {
        try await manager.escribir { db in
            let ahora = Date()
            let gasto = Transaccion(
                fecha: ahora,
                hora: ahora,
                concepto: concepto,
                monto: monto,
                tipo: .gasto,
                categoria: "Depósitos",
                metodo: .efectivo,
                desglose: desglose
            )
            let gastoGuardada = try transactionRepo.insertarEn(db: db, gasto)
            try Self.aplicar(db, transaccion: gastoGuardada, inventoryRepo: inventoryRepo)

            let ingreso = Transaccion(
                fecha: ahora,
                hora: ahora,
                concepto: concepto,
                monto: monto,
                tipo: .ingreso,
                categoria: "Depósitos",
                metodo: .tarjeta
            )
            try transactionRepo.insertarEn(db: db, ingreso)
        }
    }

    public func eliminar(_ transaccion: Transaccion) async throws {
        guard let id = transaccion.id else { throw AppDatabaseError.filaNoEncontrada }
        try await manager.escribir { db in
            try Self.revertir(db, transaccion: transaccion, inventoryRepo: inventoryRepo)
            try transactionRepo.eliminarEn(db: db, id: id)
        }
    }

    static func aplicar(
        _ db: Database,
        transaccion: Transaccion,
        inventoryRepo: any InventoryRepository
    ) throws {
        guard transaccion.metodo == .efectivo,
              let desglose = transaccion.desglose else { return }
        try ajustar(db, desglose: desglose, tipo: transaccion.tipo, inventoryRepo: inventoryRepo)
    }

    static func revertir(
        _ db: Database,
        transaccion: Transaccion,
        inventoryRepo: any InventoryRepository
    ) throws {
        guard transaccion.metodo == .efectivo,
              let desglose = transaccion.desglose else { return }
        let tipoInverso: TipoTransaccion = transaccion.tipo == .ingreso ? .gasto : .ingreso
        try ajustar(db, desglose: desglose, tipo: tipoInverso, inventoryRepo: inventoryRepo)
    }

    static func ajustar(
        _ db: Database,
        desglose: DesgloseBilletes,
        tipo: TipoTransaccion,
        inventoryRepo: any InventoryRepository
    ) throws {
        for denom in DesgloseBilletes.denominaciones {
            let cant = desglose.cantidad(de: denom)
            guard cant != 0 else { continue }
            let delta = tipo == .ingreso ? cant : -cant
            try inventoryRepo.ajustarEn(db: db, denominacion: denom, delta: delta)
        }
    }
}
