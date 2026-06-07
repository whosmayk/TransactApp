import Foundation
import Models
import Database

public struct InventoryService: Sendable {
    private let manager: DatabaseManager
    private let repo: any InventoryRepository

    public init(manager: DatabaseManager, repo: any InventoryRepository) {
        self.manager = manager
        self.repo = repo
    }

    public func aplicar(transaccion: Transaccion) async throws {
        guard transaccion.metodo == .efectivo,
              let desglose = transaccion.desglose else { return }
        try await ajustar(desglose: desglose, segun: transaccion.tipo)
    }

    public func revertir(transaccion: Transaccion) async throws {
        guard transaccion.metodo == .efectivo,
              let desglose = transaccion.desglose else { return }
        let tipoInverso: TipoTransaccion = transaccion.tipo == .ingreso ? .gasto : .ingreso
        try await ajustar(desglose: desglose, segun: tipoInverso)
    }

    /// Aplica un swap atómico de denominaciones de efectivo.
    /// - origen: denominaciones a restar del inventario.
    /// - destino: denominaciones a sumar al inventario.
    /// - Throws: `CambioBilleteError.sinMovimientos` si ambos están vacíos.
    /// - Throws: `CambioBilleteError.cambioNoBalanceado` si el total en pesos difiere.
    /// - Throws: `CambioBilleteError.inventarioInsuficiente` si algún origen excede el inventario.
    /// - Garantiza atomicidad: si cualquier paso falla, no se aplica ningún cambio.
    public func swap(origen: [Int: Int], destino: [Int: Int]) async throws {
        let origenLimpio = origen.filter { $0.value > 0 }
        let destinoLimpio = destino.filter { $0.value > 0 }
        guard !origenLimpio.isEmpty || !destinoLimpio.isEmpty else {
            throw CambioBilleteError.sinMovimientos
        }
        let totalOrigen = origenLimpio.reduce(Decimal(0)) { $0 + Decimal($1.key) * Decimal($1.value) }
        let totalDestino = destinoLimpio.reduce(Decimal(0)) { $0 + Decimal($1.key) * Decimal($1.value) }
        guard totalOrigen == totalDestino else {
            throw CambioBilleteError.cambioNoBalanceado(
                totalOrigen: totalOrigen,
                totalDestino: totalDestino
            )
        }

        try await manager.escribir { db in
            for (denom, cant) in origenLimpio {
                let disponible = try repo.cantidadEn(db: db, denominacion: denom)
                guard disponible >= cant else {
                    throw CambioBilleteError.inventarioInsuficiente(
                        denominacion: denom,
                        disponible: disponible,
                        solicitado: cant
                    )
                }
            }
            for (denom, cant) in origenLimpio {
                try repo.ajustarEn(db: db, denominacion: denom, delta: -cant)
            }
            for (denom, cant) in destinoLimpio {
                try repo.ajustarEn(db: db, denominacion: denom, delta: +cant)
            }
        }
    }

    private func ajustar(desglose: DesgloseBilletes, segun tipo: TipoTransaccion) async throws {
        for denom in DesgloseBilletes.denominaciones {
            let cant = desglose.cantidad(de: denom)
            guard cant != 0 else { continue }
            let delta = tipo == .ingreso ? cant : -cant
            try await repo.ajustar(denominacion: denom, delta: delta)
        }
    }
}
