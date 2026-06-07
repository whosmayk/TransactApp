import SwiftUI
import AppKit
import Services
import Database
import Models
import DesignSystem

public struct WindowsImportView: View {
    @ObservedObject var viewModel: WindowsImportViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: WindowsImportViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColor.surface0)
            contenido
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().background(AppColor.surface0)
            footer
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(AppColor.mantle)
    }

    private var header: some View {
        HStack(spacing: TemaEspaciado.m) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 20))
                .foregroundColor(AppColor.peach)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizableKey.wiTitulo.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Text(textoSubtitulo)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
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
            .help(LocalizableKey.commonCerrar.localized())
        }
        .padding(TemaEspaciado.l)
    }

    private var textoSubtitulo: String {
        switch viewModel.paso {
        case .seleccion: return LocalizableKey.wiPaso1.localized()
        case .preflight: return LocalizableKey.wiLeyendo.localized()
        case .resolverTipos: return LocalizableKey.wiPaso2.localized()
        case .preview: return LocalizableKey.wiPaso3.localized()
        case .importando: return LocalizableKey.wiPaso4.localized()
        case .finalizado: return LocalizableKey.wiCompletado.localized()
        }
    }

    @ViewBuilder
    private var contenido: some View {
        switch viewModel.paso {
        case .seleccion:
            pasoSeleccion
        case .preflight:
            pasoCargando
        case .resolverTipos:
            pasoResolverTipos
        case .preview:
            pasoPreview
        case .importando:
            pasoImportando
        case .finalizado(let resultado, let respaldo):
            pasoFinalizado(resultado, respaldo: respaldo)
        }
    }

    private var pasoSeleccion: some View {
        VStack(spacing: TemaEspaciado.l) {
            Spacer()
            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(AppColor.accent)
            Text(LocalizableKey.wiSeleccionaTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.wiSeleccionaDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if let error = viewModel.error {
                Text(error)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.red)
                    .padding(TemaEspaciado.s)
                    .background(AppColor.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                    .frame(maxWidth: 520)
            }
            PrimaryButton(LocalizableKey.wiElegirArchivo.localized(), icono: "folder") {
                viewModel.seleccionarArchivo()
            }
            Spacer()
        }
        .padding(TemaEspaciado.l)
    }

    private var pasoCargando: some View {
        VStack(spacing: TemaEspaciado.m) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(AppColor.accent)
            Text(LocalizableKey.wiAnalizando.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(viewModel.rutaOrigen?.lastPathComponent ?? "")
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            Spacer()
        }
    }

    private var pasoResolverTipos: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.m) {
                Text(LocalizableKey.wiResolverTitulo.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
                Text(LocalizableKey.wiResolverDesc.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)

                HStack(spacing: TemaEspaciado.s) {
                    GhostButton(LocalizableKey.wiMarcarTodasGasto.localized(), icono: "checkmark.circle") {
                        viewModel.aplicarTodosGasto()
                    }
                    GhostButton(LocalizableKey.wiOmitirTodas.localized(), icono: "minus.circle") {
                        viewModel.aplicarTodosOmitir()
                    }
                    Spacer()
                }

                if let pre = viewModel.preflightResultado {
                    VStack(spacing: TemaEspaciado.s) {
                        ForEach(pre.suscripcionesConTipoDesconocido) { s in
                            suscripcionRow(s)
                        }
                    }
                }
            }
            .padding(TemaEspaciado.l)
        }
    }

    private func suscripcionRow(_ s: SuscripcionTipoDesconocido) -> some View {
        HStack(spacing: TemaEspaciado.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(s.id) · \(s.conceptoOriginal)")
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.wiTipoOriginal.localized() + ": \"" + s.tipoOriginal + "\" · " + s.frecuencia + " · " + Localizador.moneda(s.monto))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.mapeo[s.id] ?? .gasto },
                set: { viewModel.establecerMapeo(id: s.id, mapeo: $0) }
            )) {
                Text(LocalizableKey.wiMapeoGasto.localized()).tag(MapeoSuscripcion.gasto)
                Text(LocalizableKey.wiMapeoIngreso.localized()).tag(MapeoSuscripcion.ingreso)
                Text(LocalizableKey.wiMapeoOmitir.localized()).tag(MapeoSuscripcion.omitir)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
    }

    private var pasoPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.l) {
                if let pre = viewModel.preflightResultado {
                    resumenCard(pre: pre)
                    muestraTransacciones(pre: pre)
                    muestraPrestamos(pre: pre)
                    muestraSuscripciones(pre: pre)
                    advertenciaAutoBackup
                }
            }
            .padding(TemaEspaciado.l)
        }
    }

    private func resumenCard(pre: ResultadoPreflightWindows) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(AppColor.sapphire)
                Text(LocalizableKey.wiResumenArchivo.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                Spacer()
            }
            resumenFila(LocalizableKey.wiResumenTransacciones.localized(), "\(pre.transacciones)",
                        pre.fechaMin != nil && pre.fechaMax != nil
                            ? "\(Localizador.fechaCorta(pre.fechaMin!)) → \(Localizador.fechaCorta(pre.fechaMax!))"
                            : nil)
            resumenFila(LocalizableKey.wiResumenIngresos.localized(), Localizador.moneda(pre.totalIngresos))
            resumenFila(LocalizableKey.wiResumenGastos.localized(), Localizador.moneda(pre.totalGastos))
            resumenFila(LocalizableKey.wiResumenPrestamos.localized(), "\(pre.prestamos)")
            resumenFila(LocalizableKey.wiResumenSuscripciones.localized(), "\(pre.suscripciones)")
            resumenFila(LocalizableKey.wiResumenInventario.localized(), "\(pre.inventario) " + LocalizableKey.commonDenominaciones.localized())
            resumenFila(LocalizableKey.wiResumenSaldo.localized(),
                        Localizador.moneda(pre.saldoInicialEfectivo ?? 0) + " " + LocalizableKey.wiEfectivoReal.localized() + " + " +
                        Localizador.moneda(pre.saldoInicialTarjeta ?? 0) + " " + LocalizableKey.wiTarjetaReal.localized())
            Divider().background(AppColor.surface1)
            selectorModoSaldo
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
    }

    private var selectorModoSaldo: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(AppColor.peach)
                Text(LocalizableKey.wiSaldoTitulo.localized())
                    .font(Tipografia.cuerpo().weight(.medium))
                    .foregroundColor(AppColor.text)
                Spacer()
            }
            Picker("", selection: Binding(
                get: { viewModel.modoSaldo },
                set: { viewModel.modoSaldo = $0 }
            )) {
                Text(LocalizableKey.wiSaldoArchivo.localized()).tag(ModoSaldoInicial.archivo)
                Text(LocalizableKey.wiSaldoActual.localized()).tag(ModoSaldoInicial.actual)
                Text(LocalizableKey.wiSaldoAjustar.localized()).tag(ModoSaldoInicial.ajustarAReal)
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Text(viewModel.saldoInicialTextoExplicativo)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.modoSaldo == .ajustarAReal {
                balanceRealEditor
            }
        }
    }

    private var balanceRealEditor: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack(spacing: TemaEspaciado.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizableKey.wiEfectivoReal.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    TextField(LocalizableKey.montoPlaceholder.localized(), value: $viewModel.balanceRealEfectivo,
                              format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.plain)
                        .font(Tipografia.cuerpo().monospaced())
                        .foregroundColor(AppColor.text)
                        .padding(.horizontal, TemaEspaciado.s)
                        .padding(.vertical, TemaEspaciado.xs)
                        .background(AppColor.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizableKey.wiTarjetaReal.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    TextField(LocalizableKey.montoPlaceholder.localized(), value: $viewModel.balanceRealTarjeta,
                              format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.plain)
                        .font(Tipografia.cuerpo().monospaced())
                        .foregroundColor(AppColor.text)
                        .padding(.horizontal, TemaEspaciado.s)
                        .padding(.vertical, TemaEspaciado.xs)
                        .background(AppColor.surface1)
                        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                }
            }
            Text(LocalizableKey.wiCalcular.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
        }
    }

    private func resumenFila(_ titulo: String, _ valor: String, _ extra: String? = nil) -> some View {
        HStack {
            Text(titulo)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            Spacer()
            Text(valor)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.text)
            if let extra = extra {
                Text("· \(extra)")
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
        }
    }

    private func muestraTransacciones(pre: ResultadoPreflightWindows) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.wiPrimerasTransacciones.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            ForEach(pre.muestraTransacciones) { t in
                HStack {
                    Text(Localizador.fechaCorta(t.fecha))
                        .font(Tipografia.cuerpo().monospaced())
                        .foregroundColor(AppColor.subtext0)
                        .frame(width: 90, alignment: .leading)
                    Text(t.concepto)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.text)
                    Spacer()
                    Text(Localizador.moneda(t.monto))
                        .font(Tipografia.cuerpo().monospaced())
                        .foregroundColor(t.tipo == "Ingreso" ? AppColor.green : AppColor.red)
                }
                .padding(.horizontal, TemaEspaciado.s)
                .padding(.vertical, TemaEspaciado.xs)
            }
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
    }

    private func muestraPrestamos(pre: ResultadoPreflightWindows) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.wiPrestamosPrimeros.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            if pre.muestraPrestamos.isEmpty {
                Text(LocalizableKey.wiSinPrestamos.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            } else {
                ForEach(pre.muestraPrestamos) { p in
                    HStack {
                        Text(p.persona)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.text)
                        Text("·")
                            .foregroundColor(AppColor.subtext0)
                        Text(p.concepto)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                        Spacer()
                        Text(p.tipo)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(p.tipo == "Debo" ? AppColor.red : AppColor.green)
                    }
                    .padding(.horizontal, TemaEspaciado.s)
                    .padding(.vertical, TemaEspaciado.xs)
                }
            }
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
    }

    private func muestraSuscripciones(pre: ResultadoPreflightWindows) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack {
                Text(LocalizableKey.wiSuscripcionesPrimeras.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                if !pre.suscripcionesConTipoDesconocido.isEmpty {
                    Text("⚠ " + LocalizableKey.wiSuscripcionesNoReconocidas.localized(pre.suscripcionesConTipoDesconocido.count))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.peach)
                }
                Spacer()
            }
            ForEach(pre.muestraSuscripciones) { s in
                HStack {
                    Text("#\(s.id) · \(s.concepto)")
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.text)
                    Spacer()
                    Text(s.tipo)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
                .padding(.horizontal, TemaEspaciado.s)
                .padding(.vertical, TemaEspaciado.xs)
            }
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
    }

    private var advertenciaAutoBackup: some View {
        HStack(alignment: .top, spacing: TemaEspaciado.s) {
            Image(systemName: "info.circle")
                .foregroundColor(AppColor.sapphire)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizableKey.wiAutoBackupTitulo.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.wiAutoBackupDesc.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.sapphire.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
    }

    private var pasoImportando: some View {
        VStack(spacing: TemaEspaciado.m) {
            Spacer()
            ProgressView()
                .controlSize(.large)
                .tint(AppColor.accent)
            Text(LocalizableKey.wiImportandoTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.wiImportandoSubtitulo.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            Spacer()
        }
    }

    private func pasoFinalizado(
        _ resultado: ResultadoImportacionWindows,
        respaldo: Respaldo?
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.m) {
                HStack(spacing: TemaEspaciado.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColor.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizableKey.wiImportandoTitulo.localized())
                            .font(Tipografia.titulo())
                            .foregroundColor(AppColor.text)
                        Text(LocalizableKey.wiImportandoDesc.localized())
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                    }
                }
                .padding(TemaEspaciado.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))

                VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                    filaResultado(LocalizableKey.wiResultadoTx.localized(), "\(resultado.transaccionesImportadas)")
                    filaResultado(LocalizableKey.wiResultadoPrestamos.localized(), "\(resultado.prestamosImportados)")
                    filaResultado(LocalizableKey.wiResultadoSuscripciones.localized(), "\(resultado.suscripcionesImportadas)")
                    if resultado.suscripcionesOmitidas > 0 {
                        filaResultado(LocalizableKey.wiResultadoOmitidas.localized(), "\(resultado.suscripcionesOmitidas)")
                    }
                    filaResultado(LocalizableKey.wiResultadoInventario.localized(), "\(resultado.inventarioImportado) " + LocalizableKey.commonDenominaciones.localized())
                    filaResultado(LocalizableKey.wiResultadoSaldo.localized(), resultado.saldoInicialImportado ? LocalizableKey.wiResultadoSi.localized() : LocalizableKey.wiResultadoNo.localized())
                }
                .padding(TemaEspaciado.m)
                .background(AppColor.surface0)
                .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))

                if let respaldo = respaldo {
                    VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                        Text(LocalizableKey.wiRespaldoPrevio.localized())
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.text)
                        Text(respaldo.nombreArchivo)
                            .font(Tipografia.cuerpo().monospaced())
                            .foregroundColor(AppColor.subtext0)
                        Text(LocalizableKey.wiRespaldoCreado.localized(Localizador.fechaCompleta(respaldo.fecha)))
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                    }
                    .padding(TemaEspaciado.m)
                    .background(AppColor.surface0)
                    .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
                }
            }
            .padding(TemaEspaciado.l)
        }
    }

    private func filaResultado(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            Spacer()
            Text(valor)
                .font(Tipografia.cuerpo().monospaced())
                .foregroundColor(AppColor.text)
        }
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: TemaEspaciado.m) {
            if let error = viewModel.error {
                Text(error)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.red)
                Spacer()
                GhostButton(LocalizableKey.commonCerrar.localized(), icono: nil) {
                    viewModel.limpiarError()
                }
            }
            Spacer()
            contenidoFooterBotones
        }
        .padding(TemaEspaciado.l)
    }

    @ViewBuilder
    private var contenidoFooterBotones: some View {
        switch viewModel.paso {
        case .seleccion, .preflight, .importando:
            EmptyView()
        case .resolverTipos:
            GhostButton(LocalizableKey.commonAtras.localized(), icono: nil) {
                viewModel.reiniciar()
            }
            PrimaryButton(LocalizableKey.commonContinuar.localized(), icono: "arrow.right") {
                viewModel.continuarAPreview()
            }
        case .preview:
            let omitidas = viewModel.conteoSuscripcionesOmitidas()
            let total = viewModel.preflightResultado?.suscripcionesConTipoDesconocido.count ?? 0
            if total > 0 && omitidas == total {
                GhostButton(LocalizableKey.commonAtras.localized(), icono: nil) {
                    viewModel.volverAResolverTipos()
                }
                Text(LocalizableKey.wiTodasOmitidas.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.peach)
            } else {
                GhostButton(LocalizableKey.commonAtras.localized(), icono: nil) {
                    viewModel.volverAResolverTipos()
                }
                PrimaryButton(LocalizableKey.wiImportar.localized(), icono: "tray.and.arrow.down") {
                    Task { await viewModel.importar() }
                }
            }
        case .finalizado:
            PrimaryButton(LocalizableKey.commonListo.localized(), icono: "checkmark") {
                dismiss()
            }
        }
    }
}
