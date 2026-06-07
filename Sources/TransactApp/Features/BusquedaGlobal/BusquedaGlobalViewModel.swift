import Foundation
import SwiftUI
import Combine
import Models
import Services

@MainActor
public final class BusquedaGlobalViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var resultados: [ResultadoBusqueda] = []
    @Published public var indiceSeleccionado: Int = 0
    @Published public var cargando: Bool = false

    private let service: BusquedaGlobalService
    private var tarea: Task<Void, Never>?
    private let debounceNanos: UInt64

    public init(
        service: BusquedaGlobalService,
        debounceMs: Int = 100
    ) {
        self.service = service
        self.debounceNanos = UInt64(debounceMs) * 1_000_000
    }

    public func actualizar(query nuevo: String) {
        self.query = nuevo
        tarea?.cancel()
        guard !nuevo.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.resultados = []
            self.indiceSeleccionado = 0
            self.cargando = false
            return
        }
        self.cargando = true
        let servicio = self.service
        let delay = self.debounceNanos
        tarea = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            if Task.isCancelled { return }
            let res = await servicio.buscar(query: nuevo)
            if Task.isCancelled { return }
            await MainActor.run {
                guard let self else { return }
                self.resultados = res
                self.indiceSeleccionado = 0
                self.cargando = false
            }
        }
    }

    public func moverSeleccion(delta: Int) {
        guard !resultados.isEmpty else { return }
        let n = resultados.count
        var nuevo = indiceSeleccionado + delta
        if nuevo < 0 { nuevo = n - 1 }
        if nuevo >= n { nuevo = 0 }
        indiceSeleccionado = nuevo
    }

    public func seleccionarActual() -> ResultadoBusqueda? {
        guard !resultados.isEmpty,
              indiceSeleccionado >= 0,
              indiceSeleccionado < resultados.count else { return nil }
        return resultados[indiceSeleccionado]
    }

    public func resetear() {
        tarea?.cancel()
        query = ""
        resultados = []
        indiceSeleccionado = 0
        cargando = false
    }
}
