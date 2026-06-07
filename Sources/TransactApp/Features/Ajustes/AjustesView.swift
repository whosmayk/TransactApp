import SwiftUI
import Services
import Models
import DesignSystem
import Database

public struct AjustesView: View {
    @ObservedObject var configuracionViewModel: ConfiguracionViewModel
    @ObservedObject var respaldoViewModel: RespaldoViewModel
    @ObservedObject var limpiarDatosViewModel: LimpiarDatosViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .configuracion
    let tabInicial: Tab?

    public enum Tab: String, CaseIterable, Identifiable {
        case configuracion
        case respaldos
        case limpiar
        case diagnostico
        public var id: String { rawValue }

        public var titulo: String {
            switch self {
            case .configuracion: return LocalizableKey.tabConfiguracion.localized()
            case .respaldos: return LocalizableKey.tabRespaldos.localized()
            case .limpiar: return LocalizableKey.tabLimpiar.localized()
            case .diagnostico: return LocalizableKey.tabDiagnostico.localized()
            }
        }
    }

    public init(
        configuracionViewModel: ConfiguracionViewModel,
        respaldoViewModel: RespaldoViewModel,
        limpiarDatosViewModel: LimpiarDatosViewModel,
        tabInicial: Tab? = nil
    ) {
        self.configuracionViewModel = configuracionViewModel
        self.respaldoViewModel = respaldoViewModel
        self.limpiarDatosViewModel = limpiarDatosViewModel
        self.tabInicial = tabInicial
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().background(AppColor.surface0)
            contenidoTab
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(AppColor.mantle)
        .onAppear {
            if let t = tabInicial {
                tab = t
            }
        }
    }

    private var header: some View {
        HStack {
            Text(LocalizableKey.ajustesTitulo.localized())
                .font(Tipografia.titulo())
                .foregroundColor(AppColor.text)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColor.subtext0)
            }
            .buttonStyle(.borderless)
            .help(LocalizableKey.ajustesCerrar.localized())
        }
        .padding(TemaEspaciado.l)
    }

    private var tabBar: some View {
        HStack(spacing: TemaEspaciado.s) {
            ForEach(Tab.allCases) { t in
                Button {
                    tab = t
                } label: {
                    Text(t.titulo)
                        .font(Tipografia.subtitulo())
                        .foregroundColor(tab == t ? AppColor.accent : AppColor.subtext0)
                        .padding(.horizontal, TemaEspaciado.m)
                        .padding(.vertical, TemaEspaciado.s)
                        .background(
                            tab == t
                            ? AnyShapeStyle(AppGradiente.cardHeader)
                            : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, TemaEspaciado.l)
    }

    @ViewBuilder
    private var contenidoTab: some View {
        switch tab {
        case .configuracion:
            ConfiguracionView(viewModel: configuracionViewModel)
        case .respaldos:
            RespaldoView(viewModel: respaldoViewModel)
        case .limpiar:
            LimpiarDatosView(viewModel: limpiarDatosViewModel)
        case .diagnostico:
            DiagnosticoView()
        }
    }
}

struct DiagnosticoView: View {
    @EnvironmentObject var environment: AppEnvironment
    @ObservedObject private var presenter = ErrorPresenter.shared
    @State private var errorPersonalizadoTitulo: String = ""
    @State private var errorPersonalizadoMensaje: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.l) {
                seccionAlertasPredefinidas
                seccionAlertaPersonalizada
                seccionHistorial
            }
            .padding(TemaEspaciado.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColor.base)
        .onAppear {
            if errorPersonalizadoTitulo.isEmpty {
                errorPersonalizadoTitulo = LocalizableKey.diagCustomPlaceholderTitulo.localized()
            }
            if errorPersonalizadoMensaje.isEmpty {
                errorPersonalizadoMensaje = LocalizableKey.diagCustomPlaceholderMsg.localized()
            }
        }
    }

    private var seccionAlertasPredefinidas: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.diagTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.diagDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)

            HStack(spacing: TemaEspaciado.s) {
                Button(LocalizableKey.diagBotonInfo.localized()) {
                    environment.errorPresenter.present(
                        category: .info,
                        title: LocalizableKey.diagInfoTitulo.localized(),
                        message: LocalizableKey.diagInfoMsg.localized(),
                        source: .sistema
                    )
                }
                .buttonStyle(.bordered)

                Button(LocalizableKey.diagBotonWarning.localized()) {
                    environment.errorPresenter.present(
                        category: .warning,
                        title: LocalizableKey.diagWarningTitulo.localized(),
                        message: LocalizableKey.diagWarningMsg.localized(),
                        suggestion: LocalizableKey.diagWarningSug.localized(),
                        source: .sistema
                    )
                }
                .buttonStyle(.bordered)

                Button(LocalizableKey.diagBotonCritical.localized()) {
                    environment.errorPresenter.present(
                        category: .critical,
                        title: LocalizableKey.diagCriticalTitulo.localized(),
                        message: LocalizableKey.diagCriticalMsg.localized(),
                        suggestion: LocalizableKey.diagCriticalSug.localized(),
                        source: .sistema
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColor.red)
            }

            HStack(spacing: TemaEspaciado.s) {
                Button(LocalizableKey.diagBotonErrorSim.localized()) {
                    let err = ErrorSimulacion.montoInvalido("100")
                    environment.errorPresenter.present(
                        err,
                        category: .critical,
                        source: .simulador
                    )
                }
                .buttonStyle(.bordered)

                Button(LocalizableKey.diagBotonErrorDB.localized()) {
                    let err = AppDatabaseError.filaNoEncontrada
                    environment.errorPresenter.present(
                        err,
                        category: .critical,
                        source: .database
                    )
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var seccionAlertaPersonalizada: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.diagCustomTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.diagCustomDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)

            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text(LocalizableKey.diagCustomLabelTitulo.localized())
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                TextField(LocalizableKey.diagCustomLabelTitulo.localized(), text: $errorPersonalizadoTitulo)
                    .textFieldStyle(.roundedBorder)
                Text(LocalizableKey.diagCustomLabelMsg.localized())
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                TextEditor(text: $errorPersonalizadoMensaje)
                    .frame(minHeight: 80)
                    .font(Tipografia.cuerpo())
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: TemaRadio.s)
                            .fill(AppColor.surface0.opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: TemaRadio.s)
                            .stroke(AppColor.surface0, lineWidth: 1)
                    )
            }

            Button(LocalizableKey.diagCustomDisparar.localized()) {
                environment.errorPresenter.present(
                    category: .critical,
                    title: errorPersonalizadoTitulo,
                    message: errorPersonalizadoMensaje,
                    source: .personalizada
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColor.peach)
        }
    }

    private var seccionHistorial: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack {
                Text(LocalizableKey.diagHistorialTitulo.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                Spacer()
                if !presenter.historial.isEmpty {
                    Button(LocalizableKey.commonLimpiar.localized()) {
                        environment.errorPresenter.limpiarHistorial()
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text(LocalizableKey.diagHistorialDesc.localized(environment.errorPresenter.maxHistorial))
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)

            if presenter.historial.isEmpty {
                Text(LocalizableKey.diagHistorialVacio.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
                    .padding(.vertical, TemaEspaciado.s)
            } else {
                VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                    ForEach(presenter.historial.reversed()) { error in
                        HStack(alignment: .top, spacing: TemaEspaciado.s) {
                            Text(iconoParaCategoria(error.category))
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(error.title)
                                    .font(Tipografia.cuerpo())
                                    .foregroundColor(AppColor.text)
                                Text(error.message)
                                    .font(.caption)
                                    .foregroundColor(AppColor.subtext0)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(etiquetaCategoria(error.category))
                                .font(.caption)
                                .foregroundColor(AppColor.subtext0)
                        }
                        .padding(TemaEspaciado.s)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.surface0.opacity(0.2))
                        )
                    }
                }
            }
        }
    }

    private func iconoParaCategoria(_ cat: AppError.Category) -> String {
        switch cat {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .critical: return "xmark.octagon"
        }
    }

    private func etiquetaCategoria(_ cat: AppError.Category) -> String {
        switch cat {
        case .info: return LocalizableKey.diagBotonInfo.localized()
        case .warning: return LocalizableKey.diagBotonWarning.localized()
        case .critical: return LocalizableKey.diagBotonCritical.localized()
        }
    }
}
