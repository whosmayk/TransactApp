import SwiftUI
import AppKit

@MainActor
final class MonitorTecladoBusqueda: ObservableObject {
    private var monitor: Any?

    func iniciar() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.manejar(event: event) ? nil : event
        }
    }

    func detener() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func manejar(event: NSEvent) -> Bool {
        guard event.window?.isKeyWindow == true else { return false }
        return despachar(keyCode: event.keyCode)
    }

    func despachar(keyCode: UInt16) -> Bool {
        switch keyCode {
        case 126:
            NotificationCenter.default.post(name: .busquedaMoverArriba, object: nil)
            return true
        case 125:
            NotificationCenter.default.post(name: .busquedaMoverAbajo, object: nil)
            return true
        case 36, 76:
            NotificationCenter.default.post(name: .busquedaSeleccionar, object: nil)
            return true
        case 53:
            NotificationCenter.default.post(name: .busquedaCerrar, object: nil)
            return true
        default:
            return false
        }
    }
}
