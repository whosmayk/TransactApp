import SwiftUI
import DesignSystem
import Database
import Services
import Models

struct RootView: View {
    @ObservedObject var root: RootCoordinator
    @ObservedObject var navegacion: NavegacionCoordinator
    let busquedaGlobal: BusquedaGlobalCoordinator

    var body: some View {
        ZStack {
            AppColor.base.ignoresSafeArea()

            switch root.estado {
            case .iniciando:
                ProgresoVista(mensaje: "Cargando base de datos…")
            case .requiereOnboarding:
                if let env = root.environment,
                   let vm = root.saldoInicialViewModel {
                    SaldoInicialView(viewModel: vm) {
                        root.avanzarADashboard(env: env)
                    }
                    .id(ObjectIdentifier(vm))
                } else {
                    ProgresoVista(mensaje: "Preparando onboarding…")
                }
            case .dashboard:
                if let env = root.environment,
                   let vm = root.dashboardViewModel,
                   let proyeccion = root.proyeccionViewModel,
                   let simulador = root.simuladorViewModel {
                    DashboardView(
                        viewModel: vm,
                        proyeccionViewModel: proyeccion,
                        simuladorViewModel: simulador,
                        configurationService: env.configurationService
                    )
                    .environmentObject(env)
                    .id(ObjectIdentifier(vm))
                } else {
                    ProgresoVista(mensaje: "Cargando dashboard…")
                }
            case .error(let mensaje):
                ErrorVista(mensaje: mensaje, reintentar: {
                    Task { await root.reiniciar() }
                })
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .preferredColorScheme(.dark)
        .task { await root.iniciar() }
        .overlay(BusquedaGlobalOverlay(
            coordinator: busquedaGlobal,
            environment: root.environment
        ))
    }
}

@MainActor
final class RootCoordinator: ObservableObject {
    enum Estado: Equatable {
        case iniciando
        case requiereOnboarding
        case dashboard
        case error(String)
    }

    @Published var estado: Estado = .iniciando
    @Published var environment: AppEnvironment?
    @Published var saldoInicialViewModel: SaldoInicialViewModel?
    @Published var dashboardViewModel: DashboardViewModel?
    @Published var proyeccionViewModel: ProyeccionViewModel?
    @Published var simuladorViewModel: SimuladorGastosViewModel?
    private var simuladorContextoTask: Task<Void, Never>?
    let busquedaGlobal: BusquedaGlobalCoordinator

    init(busquedaGlobal: BusquedaGlobalCoordinator) {
        self.busquedaGlobal = busquedaGlobal
    }

    func iniciar() async {
        do {
            let env = try AppEnvironment.bootstrap()
            self.environment = env
            busquedaGlobal.configurar(service: env.busquedaGlobalService)

            // Intentar restaurar sesión de Supabase
            env.syncService.restaurarSesion()

            let existe = try await env.initialBalance.obtener() != nil
            if existe {
                configurarDashboard(env: env)
                self.estado = .dashboard
                // Sincronización inicial en segundo plano
                Task {
                    await env.syncService.pullChanges()
                    await env.syncService.pushChanges()
                }
            } else {
                let vm = SaldoInicialViewModel(
                    repo: env.initialBalance,
                    inventarioRepo: env.inventory
                )
                self.saldoInicialViewModel = vm
                self.estado = .requiereOnboarding
            }
        } catch {
            self.estado = .error(error.localizedDescription)
        }
    }

    func avanzarADashboard(env: AppEnvironment) {
        configurarDashboard(env: env)
        self.saldoInicialViewModel = nil
        self.estado = .dashboard
    }

    private func configurarDashboard(env: AppEnvironment) {
        let vm = DashboardViewModel(
            initialBalanceRepo: env.initialBalance,
            inventoryRepo: env.inventory,
            transactionRepo: env.transactions,
            loanRepo: env.loans,
            subscriptionRepo: env.subscriptions,
            notifier: SubscriptionNotifier(service: env.subscriptionService)
        )
        let proyeccion = ProyeccionViewModel(
            projectionService: env.projectionService,
            transactionRepo: env.transactions,
            subscriptionRepo: env.subscriptions,
            configurationService: env.configurationService
        )
        let simulador = SimuladorGastosViewModel(
            service: env.simuladorGastosService,
            transactionRepo: env.transactions,
            loanRepo: env.loans,
            subscriptionRepo: env.subscriptions,
            initialBalanceRepo: env.initialBalance,
            projectionService: env.projectionService
        )
        simuladorContextoTask?.cancel()
        simuladorContextoTask = Task { await simulador.cargarContexto() }
        self.dashboardViewModel = vm
        self.proyeccionViewModel = proyeccion
        self.simuladorViewModel = simulador

        // Auto-refresco: la dashboard, la proyección y el simulador se recargan
        // automáticamente cada vez que la DB sufre una escritura real.
        // La suscripción vive mientras el environment exista.
        env.registrarObservadorHandler { [weak vm, weak proyeccion, weak simulador] in
            await vm?.cargar()
            await proyeccion?.cargar()
            await simulador?.cargarContexto()
        }
    }

    func reiniciar() async {
        simuladorContextoTask?.cancel()
        simuladorContextoTask = nil
        environment?.cancelarObservador()
        environment = nil
        saldoInicialViewModel = nil
        dashboardViewModel = nil
        proyeccionViewModel = nil
        simuladorViewModel = nil
        estado = .iniciando
        await iniciar()
    }

    var tieneDashboard: Bool {
        dashboardViewModel != nil
    }

    func recargarTodo() async {
        guard let vm = dashboardViewModel else { return }
        await vm.cargar()
        await proyeccionViewModel?.cargar()
        await simuladorViewModel?.cargarContexto()
    }

    func handleURL(_ url: URL) async {
        guard let env = environment,
              url.scheme == "transactapp",
              let fragment = url.fragment(percentEncoded: false),
              let params = parseFragment(fragment),
              let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else { return }

        env.supabaseManager.token = accessToken
        env.syncService.autenticado = true
        let sesion = SupabaseSession(accessToken: accessToken, refreshToken: refreshToken, expiresAt: 0)
        if let data = try? JSONEncoder().encode(sesion) {
            UserDefaults.standard.set(data, forKey: "supabase_session")
        }
        await env.syncService.pullChanges()
        await env.syncService.pushChanges()
    }

    private func parseFragment(_ fragment: String) -> [String: String]? {
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            params[String(kv[0])] = String(kv[1])
        }
        return params.isEmpty ? nil : params
    }
}

private struct ProgresoVista: View {
    let mensaje: String
    var body: some View {
        VStack(spacing: TemaEspaciado.l) {
            ProgressView()
                .controlSize(.large)
                .tint(AppColor.accent)
            Text(mensaje)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext1)
        }
    }
}

private struct ErrorVista: View {
    let mensaje: String
    let reintentar: () -> Void
    var body: some View {
        VStack(spacing: TemaEspaciado.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColor.red)
            Text("Algo salió mal")
                .font(Tipografia.titulo())
                .foregroundColor(AppColor.text)
            Text(mensaje)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
            PrimaryButton("Reintentar", icono: "arrow.clockwise", accion: reintentar)
                .frame(maxWidth: 240)
        }
        .padding(TemaEspaciado.xxl)
    }
}
