import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
public final class CambioBilleteViewModel: ObservableObject {
    @Published public var origen: [Int: Int] = [:]
    @Published public var destino: [Int: Int] = [:]
    @Published public var concepto: String = ""
    @Published public var inventario: [Inventario] = []
    @Published public var aplicando: Bool = false
    @Published public var error: String?

    private let inventoryService: InventoryService
    private let inventoryRepo: any InventoryRepository
    private let onCerrar: () -> Void

    public init(
        inventoryService: InventoryService,
        inventoryRepo: any InventoryRepository,
        onCerrar: @escaping () -> Void
    ) {
        self.inventoryService = inventoryService
        self.inventoryRepo = inventoryRepo
        self.onCerrar = onCerrar
    }

    public func cargar() async {
        do {
            inventario = try await inventoryRepo.listar()
        } catch {
            inventario = []
        }
    }

    public var totalOrigen: Decimal {
        origen.reduce(Decimal(0)) { $0 + Decimal($1.key) * Decimal($1.value) }
    }

    public var totalDestino: Decimal {
        destino.reduce(Decimal(0)) { $0 + Decimal($1.key) * Decimal($1.value) }
    }

    public var balanceValido: Bool {
        totalOrigen > 0 && totalOrigen == totalDestino
    }

    public var hayMovimientos: Bool {
        origen.contains { $0.value > 0 } || destino.contains { $0.value > 0 }
    }

    public func inventarioDe(_ denom: Int) -> Int {
        inventario.first(where: { $0.denominacion == denom })?.cantidad ?? 0
    }

    public func setOrigen(_ cantidad: Int, denom: Int) {
        let maxDisponible = inventarioDe(denom) + (destino[denom] ?? 0)
        let clamped = max(0, min(cantidad, maxDisponible))
        if clamped == 0 {
            origen.removeValue(forKey: denom)
        } else {
            origen[denom] = clamped
        }
        if destino[denom] != nil {
            destino[denom] = 0
        }
        autoGenerarConceptoSiVacio()
    }

    public func setDestino(_ cantidad: Int, denom: Int) {
        let clamped = max(0, cantidad)
        if clamped == 0 {
            destino.removeValue(forKey: denom)
        } else {
            destino[denom] = clamped
        }
        if origen[denom] != nil {
            origen[denom] = 0
        }
        autoGenerarConceptoSiVacio()
    }

    private func autoGenerarConceptoSiVacio() {
        guard concepto.isEmpty else { return }
        concepto = Self.formatearConcepto(
            origen: origen.filter { $0.value > 0 },
            destino: destino.filter { $0.value > 0 }
        )
    }

    public func aplicar() async {
        guard !aplicando else { return }
        await cargar()
        guard hayMovimientos else {
            error = "No has seleccionado ningún cambio."
            return
        }
        guard balanceValido else {
            error = "El total que quitas debe ser igual al que agregas."
            return
        }
        aplicando = true
        error = nil
        defer { aplicando = false }
        do {
            try await inventoryService.swap(
                origen: origen.filter { $0.value > 0 },
                destino: destino.filter { $0.value > 0 }
            )
            onCerrar()
        } catch let cambioError as CambioBilleteError {
            error = cambioError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    public static func formatearConcepto(origen: [Int: Int], destino: [Int: Int]) -> String {
        let origenStr = origen
            .sorted { $0.key > $1.key }
            .map { "\($0.value)×$\($0.key)" }
            .joined(separator: " + ")
        let destinoStr = destino
            .sorted { $0.key > $1.key }
            .map { "\($0.value)×$\($0.key)" }
            .joined(separator: " + ")
        guard !origenStr.isEmpty || !destinoStr.isEmpty else { return "" }
        return "Cambio: \(origenStr) → \(destinoStr)"
    }
}
