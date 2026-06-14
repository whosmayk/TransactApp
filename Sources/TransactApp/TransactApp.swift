import SwiftUI
import Models
import Services
import Database
import DesignSystem

@main
struct TransactApp: App {
    @StateObject private var busquedaGlobal = BusquedaGlobalCoordinator()
    @StateObject private var navegacion: NavegacionCoordinator
    @StateObject private var root: RootCoordinator
    @StateObject private var updater = UpdateCoordinator()

    init() {
        let busqueda = BusquedaGlobalCoordinator()
        let nav = NavegacionCoordinator()
        _busquedaGlobal = StateObject(wrappedValue: busqueda)
        _navegacion = StateObject(wrappedValue: nav)
        _root = StateObject(wrappedValue: RootCoordinator(busquedaGlobal: busqueda))
        nav.configurar(busquedaGlobal: busqueda)
    }

    var body: some Scene {
        WindowGroup(LocalizableKey.appName.localized()) {
            RootView(
                root: root,
                navegacion: navegacion,
                busquedaGlobal: busquedaGlobal
            )
            .environmentObject(navegacion)
            .onOpenURL { url in
                Task { await root.handleURL(url) }
            }
            .task { await updater.checkSilencioso() }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button(LocalizableKey.updatesCheck.localized()) {
                    Task { await updater.check() }
                }
            }

            CommandGroup(after: .textEditing) {
                Button(
                    busquedaGlobal.buscarHabilitado
                        ? LocalizableKey.menuBuscar.localized()
                        : LocalizableKey.menuBuscarLoading.localized()
                ) {
                    busquedaGlobal.mostrar()
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button(LocalizableKey.menuArchivoNuevaTransaccion.localized()) {
                    navegacion.abrirHoja(.nuevaTransaccion)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button(LocalizableKey.menuArchivoHistorial.localized()) {
                    navegacion.navegar(.historial)
                }
                .keyboardShortcut("h", modifiers: [.command, .option])

                Button(LocalizableKey.menuArchivoSuscripciones.localized()) {
                    navegacion.navegar(.suscripciones)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button(LocalizableKey.menuArchivoPrestamos.localized()) {
                    navegacion.navegar(.prestamos)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button(LocalizableKey.menuArchivoReportes.localized()) {
                    navegacion.navegar(.reportes)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])

                Divider()

                Button(LocalizableKey.menuArchivoConfiguracion.localized()) {
                    navegacion.abrirHoja(.configuracion(tab: nil))
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu(LocalizableKey.menuIr.localized()) {
                Button(LocalizableKey.menuIrDashboard.localized()) {
                    navegacion.navegar(.dashboard)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button(LocalizableKey.menuIrHistorial.localized()) {
                    navegacion.navegar(.historial)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button(LocalizableKey.menuIrSuscripciones.localized()) {
                    navegacion.navegar(.suscripciones)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button(LocalizableKey.menuIrPrestamos.localized()) {
                    navegacion.navegar(.prestamos)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button(LocalizableKey.menuIrReportes.localized()) {
                    navegacion.navegar(.reportes)
                }
                .keyboardShortcut("5", modifiers: .command)
            }

            CommandMenu(LocalizableKey.menuHerramientas.localized()) {
                Button(LocalizableKey.menuHerramientasCambiarDenominaciones.localized()) {
                    navegacion.abrirHoja(.cambioBillete)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button(LocalizableKey.menuHerramientasImportarWindows.localized()) {
                    navegacion.abrirHoja(.configuracion(tab: .respaldos))
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button(LocalizableKey.menuHerramientasDiagnostico.localized()) {
                    navegacion.abrirHoja(.configuracion(tab: .diagnostico))
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button(LocalizableKey.commonRecargar.localized()) {
                    Task { await root.recargarTodo() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!root.tieneDashboard)
            }
        }
    }
}
