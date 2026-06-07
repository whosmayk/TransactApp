import Foundation
import AppKit
import Testing
@testable import TransactApp

@Suite("MonitorTecladoBusqueda")
struct MonitorTecladoBusquedaTests {

    @Test("keyCode 126 (↑) postea busquedaMoverArriba")
    @MainActor
    func flechaArribaPosteaMoverArriba() {
        let monitor = MonitorTecladoBusqueda()
        var recibido: Notification.Name?
        let token = NotificationCenter.default.addObserver(
            forName: .busquedaMoverArriba,
            object: nil,
            queue: .main
        ) { notif in
            recibido = notif.name
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let consumido = monitor.despachar(keyCode: 126)
        #expect(consumido == true)
        #expect(recibido == .busquedaMoverArriba)
    }

    @Test("keyCode 125 (↓) postea busquedaMoverAbajo")
    @MainActor
    func flechaAbajoPosteaMoverAbajo() {
        let monitor = MonitorTecladoBusqueda()
        var recibido: Notification.Name?
        let token = NotificationCenter.default.addObserver(
            forName: .busquedaMoverAbajo,
            object: nil,
            queue: .main
        ) { notif in
            recibido = notif.name
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let consumido = monitor.despachar(keyCode: 125)
        #expect(consumido == true)
        #expect(recibido == .busquedaMoverAbajo)
    }

    @Test("keyCode 36 (Return) postea busquedaSeleccionar")
    @MainActor
    func enterPosteaSeleccionar() {
        let monitor = MonitorTecladoBusqueda()
        var recibido: Notification.Name?
        let token = NotificationCenter.default.addObserver(
            forName: .busquedaSeleccionar,
            object: nil,
            queue: .main
        ) { notif in
            recibido = notif.name
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let consumido = monitor.despachar(keyCode: 36)
        #expect(consumido == true)
        #expect(recibido == .busquedaSeleccionar)
    }

    @Test("keyCode 76 (numpad Enter) postea busquedaSeleccionar")
    @MainActor
    func numpadEnterPosteaSeleccionar() {
        let monitor = MonitorTecladoBusqueda()
        var recibido: Notification.Name?
        let token = NotificationCenter.default.addObserver(
            forName: .busquedaSeleccionar,
            object: nil,
            queue: .main
        ) { notif in
            recibido = notif.name
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let consumido = monitor.despachar(keyCode: 76)
        #expect(consumido == true)
        #expect(recibido == .busquedaSeleccionar)
    }

    @Test("keyCode 53 (Escape) postea busquedaCerrar")
    @MainActor
    func escapePosteaCerrar() {
        let monitor = MonitorTecladoBusqueda()
        var recibido: Notification.Name?
        let token = NotificationCenter.default.addObserver(
            forName: .busquedaCerrar,
            object: nil,
            queue: .main
        ) { notif in
            recibido = notif.name
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let consumido = monitor.despachar(keyCode: 53)
        #expect(consumido == true)
        #expect(recibido == .busquedaCerrar)
    }

    @Test("keyCode 65 (letra 'a') NO se consume")
    @MainActor
    func letraNormalNoSeConsume() {
        let monitor = MonitorTecladoBusqueda()
        let consumido = monitor.despachar(keyCode: 65)
        #expect(consumido == false)
    }
}
