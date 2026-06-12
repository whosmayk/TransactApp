import SwiftUI
import AppKit
import DesignSystem
import Models
import Services
import Database

@MainActor
public final class BusquedaGlobalCoordinator: ObservableObject {
    @Published public var visible: Bool = false
    @Published public var seleccion: ResultadoBusqueda?
    @Published public var buscarHabilitado: Bool = false

    private var service: BusquedaGlobalService?

    public init() {}

    public func configurar(service: BusquedaGlobalService) {
        self.service = service
        self.buscarHabilitado = true
    }

    public func mostrar() {
        guard buscarHabilitado else { return }
        visible = true
    }

    public func ocultar() {
        visible = false
        seleccion = nil
    }

    public func abrir(_ resultado: ResultadoBusqueda) {
        seleccion = resultado
        visible = false
    }

    public func cerrarSeleccion() {
        seleccion = nil
    }

    public func construirViewModel() -> BusquedaGlobalViewModel? {
        guard let service else { return nil }
        return BusquedaGlobalViewModel(service: service)
    }
}

struct BusquedaGlobalOverlay: View {
    @ObservedObject var coordinator: BusquedaGlobalCoordinator
    let environment: AppEnvironment?

    var body: some View {
        ZStack {
            if coordinator.visible, let env = environment {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { coordinator.ocultar() }
                    .transition(.opacity)

                BusquedaGlobalViewHolder(
                    service: env.busquedaGlobalService,
                    onSeleccionar: { resultado in
                        coordinator.abrir(resultado)
                    },
                    onCerrar: { coordinator.ocultar() }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: coordinator.visible)
        .sheet(
            item: Binding(
                get: { coordinator.seleccion },
                set: { nuevo in if nuevo == nil { return } }
            ),
            onDismiss: { coordinator.cerrarSeleccion() }
        ) { resultado in
            if let env = environment {
                NavigationStack {
                    BusquedaGlobalEditor(resultado: resultado, environment: env) {
                        coordinator.cerrarSeleccion()
                    }
                }
            }
        }
    }
}

private struct BusquedaGlobalViewHolder: View {
    let service: BusquedaGlobalService
    let onSeleccionar: (ResultadoBusqueda) -> Void
    let onCerrar: () -> Void
    @StateObject private var viewModel: BusquedaGlobalViewModel

    init(
        service: BusquedaGlobalService,
        onSeleccionar: @escaping (ResultadoBusqueda) -> Void,
        onCerrar: @escaping () -> Void
    ) {
        self.service = service
        self.onSeleccionar = onSeleccionar
        self.onCerrar = onCerrar
        self._viewModel = StateObject(wrappedValue: BusquedaGlobalViewModel(service: service))
    }

    var body: some View {
        BusquedaGlobalView(
            viewModel: viewModel,
            onSeleccionar: onSeleccionar,
            onCerrar: onCerrar
        )
    }
}

private struct BusquedaGlobalEditor: View {
    let resultado: ResultadoBusqueda
    let environment: AppEnvironment
    let onCerrar: () -> Void

    var body: some View {
        switch resultado {
        case .transaccion(let tx):
            FormularioTransaccionHost(
                service: environment.transactionService,
                transactionRepo: environment.transactions,
                transaccionInicial: tx,
                onCerrar: onCerrar
            )
            .frame(minWidth: 560, minHeight: 600)
            .id(tx.id)
        case .prestamo(let pr):
            FormularioPrestamoHost(
                service: environment.loanService,
                prestamoInicial: pr,
                onCerrar: onCerrar
            )
            .frame(minWidth: 560, minHeight: 600)
            .id(pr.id)
        case .suscripcion(let su):
            FormularioSuscripcionHost(
                service: environment.subscriptionService,
                suscripcionInicial: su,
                onCerrar: onCerrar
            )
            .frame(minWidth: 560, minHeight: 600)
            .id(su.id)
        }
    }
}
