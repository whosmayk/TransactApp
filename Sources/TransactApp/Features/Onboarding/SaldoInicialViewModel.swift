import Foundation
import SwiftUI
import DesignSystem
import Database
import Models

@MainActor
final class SaldoInicialViewModel: ObservableObject {
    @Published var efectivo: CampoMonto = CampoMonto()
    @Published var tarjeta: CampoMonto = CampoMonto()
    @Published var cantidades: [Int: Int] = [:]
    @Published var error: String?
    @Published var guardando: Bool = false
    @Published var completado: Bool = false

    private let repo: any InitialBalanceRepository
    private let inventarioRepo: any InventoryRepository

    init(repo: any InitialBalanceRepository, inventarioRepo: any InventoryRepository) {
        self.repo = repo
        self.inventarioRepo = inventarioRepo
        for d in Inventario.denominaciones {
            cantidades[d] = 0
        }
    }

    var subtotalInventario: Decimal {
        cantidades.reduce(into: Decimal(0)) { acc, par in
            acc += Decimal(par.key) * Decimal(par.value)
        }
    }

    var esValido: Bool {
        efectivo.valor >= 0 && tarjeta.valor >= 0
    }

    func actualizarCantidad(_ cantidad: Int, de denominacion: Int) {
        let clamped = max(0, cantidad)
        cantidades[denominacion] = clamped
    }

    func aceptar() async {
        guard !guardando else { return }
        error = nil
        guardando = true
        defer { guardando = false }

        let inventarioItems: [Inventario] = Inventario.denominaciones.compactMap { denom in
            let cant = cantidades[denom] ?? 0
            guard cant > 0 else { return nil }
            return Inventario(denominacion: denom, cantidad: cant)
        }

        let saldo = SaldoInicial(
            efectivo: efectivo.valor,
            tarjeta: tarjeta.valor,
            inventarioInicial: inventarioItems
        )

        do {
            try await repo.guardar(saldo, inventario: inventarioItems)
            completado = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
