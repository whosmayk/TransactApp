import SwiftUI
import Models
import Services

@MainActor
public final class NavegacionCoordinator: ObservableObject {
    public enum Hoja: Identifiable {
        case nuevaTransaccion
        case configuracion(tab: AjustesView.Tab?)
        case cambioBillete
        case depositoTarjeta
        case importarWindows
        case diagnostico

        public var id: String {
            switch self {
            case .nuevaTransaccion: return "nuevaTransaccion"
            case .configuracion(let tab): return "configuracion:\(tab?.rawValue ?? "default")"
            case .cambioBillete: return "cambioBillete"
            case .depositoTarjeta: return "depositoTarjeta"
            case .importarWindows: return "importarWindows"
            case .diagnostico: return "diagnostico"
            }
        }
    }

    public enum Destino: String, Hashable {
        case dashboard
        case historial
        case suscripciones
        case prestamos
        case reportes
    }

    @Published public var hojaActiva: Hoja?
    @Published public var rutaNavegacion: [Destino] = []

    private weak var busquedaGlobal: BusquedaGlobalCoordinator?

    public init(busquedaGlobal: BusquedaGlobalCoordinator? = nil) {
        self.busquedaGlobal = busquedaGlobal
    }

    public func configurar(busquedaGlobal: BusquedaGlobalCoordinator) {
        self.busquedaGlobal = busquedaGlobal
    }

    public func abrirHoja(_ hoja: Hoja) {
        busquedaGlobal?.cerrarSeleccion()
        busquedaGlobal?.ocultar()
        hojaActiva = hoja
    }

    public func cerrarHoja() {
        hojaActiva = nil
    }

    public func navegar(_ destino: Destino) {
        if destino == .dashboard {
            rutaNavegacion = []
        } else if !rutaNavegacion.contains(destino) {
            rutaNavegacion.append(destino)
        } else {
            rutaNavegacion.removeAll(where: { $0 == destino })
            rutaNavegacion.append(destino)
        }
    }

    public func irAtras() {
        if !rutaNavegacion.isEmpty {
            rutaNavegacion.removeLast()
        }
    }
}
