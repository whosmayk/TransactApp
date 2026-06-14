import SwiftUI
import DesignSystem
import Models
import Database
import Services

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var proyeccionViewModel: ProyeccionViewModel
    @ObservedObject var simuladorViewModel: SimuladorGastosViewModel
    let configurationService: ConfigurationService
    @EnvironmentObject var environment: AppEnvironment
    @EnvironmentObject var navegacion: NavegacionCoordinator
    @State private var ultimaActualizacion: Date = .now

    var body: some View {
        NavigationStack(path: $navegacion.rutaNavegacion) {
            ScrollView {
                VStack(alignment: .leading, spacing: TemaEspaciado.xl) {
                    encabezado

                    if !viewModel.notificaciones.isEmpty {
                        seccionNotificaciones
                    }

                    if let error = viewModel.error {
                        Text(error)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.red)
                            .padding(TemaEspaciado.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: TemaRadio.s)
                                    .fill(AppColor.red.opacity(0.15))
                            )
                    }

                    seccionAcciones

                    gridTarjetasSaldo

                    ProyeccionCard(viewModel: proyeccionViewModel) {
                        navegacion.abrirHoja(.configuracion(tab: nil))
                    }

                    SimuladorView(viewModel: simuladorViewModel)

                    seccionMes

                    seccionResumenPrestamos
                    seccionResumenSuscripciones

                    seccionInventario
                }
                .padding(TemaEspaciado.xxl)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity)
            }
            .background(AppColor.base)
            .task {
                await viewModel.cargar()
                await proyeccionViewModel.cargar()
                ultimaActualizacion = .now
            }
            .onChange(of: viewModel.cargando) { _, nuevo in
                if !nuevo { ultimaActualizacion = .now }
            }
            .refreshable {
                await viewModel.cargar()
                await proyeccionViewModel.cargar()
            }
            .navigationDestination(for: NavegacionCoordinator.Destino.self) { destino in
                switch destino {
                case .dashboard:
                    EmptyView()
                case .historial:
                    HistorialHost(
                        service: environment.transactionService,
                        transactionRepo: environment.transactions
                    )
                case .suscripciones:
                    GestionSuscripcionesHost(
                        service: environment.subscriptionService,
                        subRepo: environment.subscriptions
                    )
                case .prestamos:
                    GestionPrestamosHost(
                        service: environment.loanService,
                        transactionService: environment.transactionService,
                        transactionRepo: environment.transactions,
                        inventoryRepo: environment.inventory,
                        loanRepo: environment.loans
                    )
                case .reportes:
                    ReportesHost(
                        service: environment.reportesService
                    )
                }
            }
            .sheet(item: Binding(
                get: { navegacion.hojaActiva },
                set: { nuevo in if nuevo == nil { navegacion.cerrarHoja() } }
            )) { hoja in
                contenidoHoja(hoja)
            }
        }
    }

    @ViewBuilder
    private func contenidoHoja(_ hoja: NavegacionCoordinator.Hoja) -> some View {
        switch hoja {
        case .nuevaTransaccion:
            NavigationStack {
                FormularioTransaccionHost(
                    service: environment.transactionService,
                    transactionRepo: environment.transactions,
                    onCerrar: { navegacion.cerrarHoja() }
                )
            }
            .frame(minWidth: 560, minHeight: 600)
        case .configuracion(let tab):
            AjustesHost(
                configurationService: configurationService,
                backupService: environment.backupService,
                database: environment.database,
                tabInicial: tab
            )
            .onDisappear {
                Task { await proyeccionViewModel.cargar() }
            }
        case .depositoTarjeta:
            NavigationStack {
                DepositoTarjetaHost(
                    transactionService: environment.transactionService,
                    onCerrar: { navegacion.cerrarHoja() }
                )
            }
            .frame(minWidth: 520, minHeight: 580)
        case .cambioBillete:
            CambioBilleteHost(
                inventoryService: environment.inventoryService,
                inventoryRepo: environment.inventory,
                onCerrar: { navegacion.cerrarHoja() }
            )
            .frame(minWidth: 620, minHeight: 560)
        case .importarWindows:
            AjustesHost(
                configurationService: configurationService,
                backupService: environment.backupService,
                database: environment.database,
                tabInicial: .respaldos
            )
        case .diagnostico:
            AjustesHost(
                configurationService: configurationService,
                backupService: environment.backupService,
                database: environment.database,
                tabInicial: .diagnostico
            )
        }
    }

    private var encabezado: some View {
        HStack {
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text(LocalizableKey.appName.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.appTagline.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext1)
            }
            Spacer()
            HStack(spacing: TemaEspaciado.s) {
                Text(LocalizableKey.commonActualizado.localized(Localizador.horaCorta(ultimaActualizacion)))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
                    .help(LocalizableKey.commonActualizadoHint.localized(Localizador.fechaCompleta(ultimaActualizacion)))
                Button {
                    Task { await viewModel.cargar() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundColor(AppColor.subtext0)
                .disabled(viewModel.cargando)
                .accessibilityLabel(LocalizableKey.commonRecargar.localized())
                .accessibilityHint(LocalizableKey.commonRecargarHint.localized())
                .help(LocalizableKey.commonRecargarHint.localized())
            }
        }
    }

    private var seccionNotificaciones: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(AppColor.peach)
                    Text(LocalizableKey.dashboardNotificacionesTitulo.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.text)
                    Spacer()
                    Button(LocalizableKey.dashboardNotificacionesDescartar.localized()) {
                        Task { await viewModel.descartarNotificaciones() }
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppColor.subtext0)
                }
                ForEach(viewModel.notificaciones) { n in
                    Button {
                        navegacion.navegar(.suscripciones)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(n.concepto)
                                    .font(Tipografia.cuerpo())
                                    .foregroundColor(AppColor.text)
                                Text(n.mensaje)
                                    .font(Tipografia.cuerpo())
                                    .foregroundColor(AppColor.subtext0)
                            }
                            Spacer()
                            MontoLabel(
                                monto: n.monto,
                                tamanio: .chico,
                                colorearSegunSigno: false
                            )
                        }
                        .padding(.vertical, TemaEspaciado.xs)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gridTarjetasSaldo: some View {
        HStack(spacing: TemaEspaciado.m) {
            TarjetaSaldo(
                titulo: LocalizableKey.dashboardSaldoTotal.localized(),
                monto: viewModel.resumen.balanceTotal,
                icono: "creditcard.fill",
                colorIcono: AppColor.accent
            )
            TarjetaSaldo(
                titulo: LocalizableKey.dashboardEfectivo.localized(),
                monto: viewModel.resumen.saldoEfectivo,
                icono: "banknote.fill",
                colorIcono: AppColor.green,
                accion: { navegacion.abrirHoja(.cambioBillete) }
            )
            TarjetaSaldo(
                titulo: LocalizableKey.dashboardTarjeta.localized(),
                monto: viewModel.resumen.saldoTarjeta,
                icono: "rectangle.fill",
                colorIcono: AppColor.sapphire
            )
            TarjetaSaldo(
                titulo: LocalizableKey.dashboardBalanceReal.localized(),
                monto: viewModel.resumen.balanceReal,
                icono: "person.fill",
                colorIcono: AppColor.peach,
                subtituloDeuda: viewModel.resumen.totalDeudas
            )
        }
    }

    private var seccionMes: some View {
        HStack(spacing: TemaEspaciado.m) {
            CardView {
                VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                    Text(LocalizableKey.dashboardMesActual.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.subtext1)
                    HStack(spacing: TemaEspaciado.l) {
                        VStack(alignment: .leading) {
                            Text(LocalizableKey.dashboardIngresos.localized())
                                .font(Tipografia.cuerpo())
                                .foregroundColor(AppColor.subtext0)
                            MontoLabel(monto: viewModel.ingresosMes, tamanio: .mediano, colorearSegunSigno: false)
                        }
                        VStack(alignment: .leading) {
                            Text(LocalizableKey.dashboardGastos.localized())
                                .font(Tipografia.cuerpo())
                                .foregroundColor(AppColor.subtext0)
                            MontoLabel(monto: viewModel.gastosMesFirmado, tamanio: .mediano)
                        }
                        VStack(alignment: .leading) {
                            Text(LocalizableKey.dashboardNeto.localized())
                                .font(Tipografia.cuerpo())
                                .foregroundColor(AppColor.subtext0)
                            MontoLabel(monto: viewModel.netoMes, tamanio: .mediano)
                        }
                    }
                }
            }
            CardView {
                VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                    Text(LocalizableKey.dashboardHistorico.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.subtext1)
                    HStack(spacing: TemaEspaciado.l) {
                        VStack(alignment: .leading) {
                            Text(LocalizableKey.dashboardIngresado.localized())
                                .font(Tipografia.cuerpo())
                                .foregroundColor(AppColor.subtext0)
                            MontoLabel(monto: viewModel.ingresosHistorico, tamanio: .mediano, colorearSegunSigno: false)
                        }
                        VStack(alignment: .leading) {
                            Text(LocalizableKey.dashboardGastado.localized())
                                .font(Tipografia.cuerpo())
                                .foregroundColor(AppColor.subtext0)
                            MontoLabel(monto: viewModel.gastosHistoricoFirmado, tamanio: .mediano)
                        }
                    }
                }
            }
        }
    }

    private var seccionResumenPrestamos: some View {
        NavigationLink(value: NavegacionCoordinator.Destino.prestamos) {
            CardView {
                HStack(spacing: TemaEspaciado.m) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 28))
                        .foregroundColor(AppColor.accent)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.accent.opacity(0.15))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizableKey.dashboardPrestamos.localized())
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.text)
                        Text(LocalizableKey.dashboardPrestamosPendientes.localized(viewModel.prestamosPendientes))
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: TemaEspaciado.xs) {
                            Image(systemName: "arrow.down")
                                .foregroundColor(AppColor.green)
                            MontoLabel(
                                monto: viewModel.totalPendienteMeDeben,
                                tamanio: .chico,
                                colorearSegunSigno: false
                            )
                        }
                        HStack(spacing: TemaEspaciado.xs) {
                            Image(systemName: "arrow.up")
                                .foregroundColor(AppColor.red)
                            MontoLabel(
                                monto: viewModel.totalPendienteDebo,
                                tamanio: .chico,
                                colorearSegunSigno: false
                            )
                        }
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColor.subtext0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var seccionResumenSuscripciones: some View {
        NavigationLink(value: NavegacionCoordinator.Destino.suscripciones) {
            CardView {
                HStack(spacing: TemaEspaciado.m) {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppColor.sapphire)
                        .frame(width: 48, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.sapphire.opacity(0.15))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizableKey.dashboardSuscripciones.localized())
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.text)
                        Text("\(LocalizableKey.dashboardSuscripcionesActivas.localized(viewModel.suscripcionesActivas)) · \(LocalizableKey.dashboardSuscripcionesPorVencer.localized(viewModel.suscripcionesPorVencer))")
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(LocalizableKey.dashboardSuscripcionesMensual.localized())
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                        MontoLabel(
                            monto: viewModel.totalMensualSuscripciones,
                            tamanio: .chico,
                            colorearSegunSigno: false
                        )
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppColor.subtext0)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var seccionInventario: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.m) {
                HStack {
                    Text(LocalizableKey.dashboardInventario.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.text)
                    Spacer()
                    Text(LocalizableKey.dashboardInventarioTotal.localized(Localizador.moneda(viewModel.totalInventario)))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                }
                if !viewModel.inventario.isEmpty {
                    let items = viewModel.inventario
                    let paso = 4
                    VStack(spacing: TemaEspaciado.s) {
                        ForEach(Array(stride(from: 0, to: items.count, by: paso).enumerated()), id: \.offset) { _, start in
                            let chunk = items[start..<min(start + paso, items.count)]
                            HStack(spacing: TemaEspaciado.s) {
                                ForEach(chunk) { item in
                                    HStack {
                                        Text("$\(item.denominacion)")
                                            .font(Tipografia.subtitulo())
                                            .foregroundColor(AppColor.text)
                                        Spacer()
                                        Text("× \(item.cantidad)")
                                            .font(Tipografia.montoMediano())
                                            .foregroundColor(AppColor.green)
                                    }
                                    .padding(TemaEspaciado.s)
                                    .background(
                                        RoundedRectangle(cornerRadius: TemaRadio.s)
                                            .fill(AppColor.surface0)
                                    )
                                }
                            }
                        }
                    }
                } else {
                    Text(LocalizableKey.dashboardInventarioVacio.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            }
        }
    }

    private var seccionAcciones: some View {
        HStack(spacing: TemaEspaciado.m) {
            PrimaryButton(LocalizableKey.dashboardNuevaTransaccion.localized(), icono: "plus") {
                navegacion.abrirHoja(.nuevaTransaccion)
            }
            GhostButton(LocalizableKey.dashboardHistorial.localized(), icono: "clock") {
                navegacion.navegar(.historial)
            }
            GhostButton(LocalizableKey.dashboardReporte.localized(), icono: "doc.text") {
                navegacion.navegar(.reportes)
            }
            GhostButton("Depositar a tarjeta", icono: "creditcard") {
                navegacion.abrirHoja(.depositoTarjeta)
            }
        }
    }
}

private struct TarjetaSaldo: View {
    let titulo: String
    let monto: Decimal
    let icono: String
    let colorIcono: Color
    var subtituloDeuda: Decimal? = nil
    var accion: (() -> Void)? = nil

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                HStack {
                    Image(systemName: icono)
                        .foregroundColor(colorIcono)
                    Text(titulo)
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.subtext1)
                }
                MontoLabel(monto: monto, tamanio: .grande)
                if let deuda = subtituloDeuda, deuda > 0 {
                    HStack(spacing: TemaEspaciado.xs) {
                        Text(LocalizableKey.dashboardDeuda.localized() + ":")
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                        Text(Localizador.moneda(deuda))
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.red)
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            if let accion {
                Button(action: accion) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColor.subtext0)
                        .padding(6)
                        .background(
                            Circle().fill(AppColor.surface1)
                        )
                }
                .buttonStyle(.plain)
                .help(LocalizableKey.dashboardCambiarBilletesHint.localized())
                .accessibilityLabel(LocalizableKey.dashboardCambiarBilletes.localized())
                .accessibilityHint(LocalizableKey.dashboardCambiarBilletesHint.localized())
                .padding(8)
            }
        }
    }
}
