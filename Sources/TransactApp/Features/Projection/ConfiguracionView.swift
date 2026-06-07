import Foundation
import SwiftUI
import DesignSystem
import Models
import Services

@MainActor
public final class ConfiguracionViewModel: ObservableObject {
    @Published public var metaAhorroTexto: String = ""
    @Published public var ventanaHistorico: Int = 3
    @Published public var notificacionesHabilitadas: Bool = true
    @Published public var cargando: Bool = false
    @Published public var guardando: Bool = false
    @Published public var error: String?

    private let configurationService: ConfigurationService

    public init(configurationService: ConfigurationService) {
        self.configurationService = configurationService
    }

    public func cargar() async {
        cargando = true
        defer { cargando = false }
        do {
            let config = try await configurationService.obtener()
            self.metaAhorroTexto = config.metaAhorroMensual == 0
                ? ""
                : Localizador.decimal(config.metaAhorroMensual, fracciones: 0)
            self.ventanaHistorico = config.ventanaHistoricoMeses
            self.notificacionesHabilitadas = config.notificacionesHabilitadas
        } catch {
            self.error = LocalizableKey.configErrorCargar.localized()
        }
    }

    public func guardar() async -> Bool {
        guardando = true
        defer { guardando = false }
        do {
            let metaDecimal = try parsearMeta()
            let config = ConfiguracionUsuario(
                metaAhorroMensual: metaDecimal,
                ventanaHistoricoMeses: ventanaHistorico,
                notificacionesHabilitadas: notificacionesHabilitadas
            )
            try await configurationService.guardar(config)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func parsearMeta() throws -> Decimal {
        let limpio = metaAhorroTexto
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: " ", with: "")
        if limpio.isEmpty { return 0 }
        guard let valor = Decimal(string: limpio), valor >= 0 else {
            throw NSError(
                domain: "Configuracion",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: LocalizableKey.configErrorMeta.localized()]
            )
        }
        return valor
    }
}

struct ConfiguracionView: View {
    @ObservedObject var viewModel: ConfiguracionViewModel
    @Environment(\.dismiss) private var dismiss
    var onGuardado: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: TemaEspaciado.l) {
                    seccionMeta
                    seccionHistorico
                    seccionNotificaciones
                    if let error = viewModel.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColor.red)
                    }
                }
                .padding(TemaEspaciado.l)
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 520)
        .background(AppColor.base)
        .task { await viewModel.cargar() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizableKey.configTitulo.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.configSubtitulo.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext1)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppColor.subtext0)
            }
            .buttonStyle(.borderless)
        }
        .padding(TemaEspaciado.l)
    }

    private var seccionMeta: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.configSeccionMeta.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.configMetaDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            HStack {
                Text(LocalizableKey.montoPrefijo.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.subtext1)
                TextField(LocalizableKey.configMetaPlaceholder.localized(), text: $viewModel.metaAhorroTexto)
                    .textFieldStyle(.roundedBorder)
                    .font(Tipografia.subtitulo())
            }
        }
    }

    private var seccionHistorico: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.configSeccionHistorico.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.configHistoricoDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            Picker(LocalizableKey.configMeses.localized(), selection: $viewModel.ventanaHistorico) {
                ForEach([1, 2, 3, 6, 12], id: \.self) { meses in
                    Text(LocalizableKey.configMesesOpcion.localized(meses, meses == 1 ? LocalizableKey.commonMesSingular.localized() : LocalizableKey.commonMesPlural.localized()))
                        .tag(meses)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var seccionNotificaciones: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Toggle(isOn: $viewModel.notificacionesHabilitadas) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizableKey.configNotificaciones.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.text)
                    Text(LocalizableKey.configNotificacionesDesc.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            }
            .toggleStyle(.switch)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(LocalizableKey.commonCancelar.localized()) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button {
                Task {
                    if await viewModel.guardar() {
                        onGuardado?()
                        dismiss()
                    }
                }
            } label: {
                if viewModel.guardando {
                    ProgressView().controlSize(.small)
                } else {
                    Text(LocalizableKey.commonGuardar.localized())
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.guardando)
        }
        .padding(TemaEspaciado.l)
    }
}
