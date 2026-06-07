import SwiftUI
import Services
import Database
import Models
import DesignSystem

public struct LimpiarDatosView: View {
    @ObservedObject var viewModel: LimpiarDatosViewModel
    @State private var mostrarConfirmacion: Bool = false
    @State private var textoConfirmacion: String = ""

    public init(viewModel: LimpiarDatosViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.l) {
            header
            advertencia
            conteosCard
            accionCard
            banners
            Spacer()
        }
        .padding(TemaEspaciado.l)
        .onAppear { viewModel.cargar() }
        .alert(LocalizableKey.limpiarAlertTitulo.localized(), isPresented: $mostrarConfirmacion) {
            Button(LocalizableKey.commonCancelar.localized(), role: .cancel) {
                textoConfirmacion = ""
            }
            Button(LocalizableKey.limpiarAlertBorrar.localized(), role: .destructive) {
                viewModel.limpiar()
                textoConfirmacion = ""
            }
        } message: {
            Text(textoAlerta)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "trash.slash.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColor.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizableKey.limpiarTitulo.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.limpiarSubtitulo.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
            Spacer()
        }
    }

    private var advertencia: some View {
        HStack(alignment: .top, spacing: TemaEspaciado.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColor.peach)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizableKey.limpiarAdvertencia.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.limpiarAdvertenciaDesc.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.peach.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
    }

    private var conteosCard: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.limpiarConteoTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            conteoFila(LocalizableKey.limpiarConteoTransacciones.localized(), "\(viewModel.conteos.transacciones)")
            conteoFila(LocalizableKey.limpiarConteoPrestamos.localized(), "\(viewModel.conteos.prestamos)")
            conteoFila(LocalizableKey.limpiarConteoSuscripciones.localized(), "\(viewModel.conteos.suscripciones)")
            conteoFila(LocalizableKey.limpiarConteoInventario.localized(), "\(viewModel.conteos.inventario)")
            conteoFila(LocalizableKey.limpiarConteoSaldo.localized(), viewModel.conteos.saldoInicial ? LocalizableKey.limpiarConteoConfigurado.localized() : LocalizableKey.limpiarConteoNoConfigurado.localized())
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
    }

    private func conteoFila(_ titulo: String, _ valor: String) -> some View {
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

    private var accionCard: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            if viewModel.conteos.hayDatos {
                Button {
                    mostrarConfirmacion = true
                } label: {
                    HStack(spacing: TemaEspaciado.s) {
                        Image(systemName: "trash")
                        Text(LocalizableKey.limpiarBorrarTodo.localized())
                    }
                    .font(Tipografia.subtitulo())
                    .foregroundColor(.white)
                    .padding(.horizontal, TemaEspaciado.l)
                    .padding(.vertical, TemaEspaciado.m)
                    .background(AppColor.red)
                    .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                }
                .buttonStyle(.plain)
                .disabled(trabajando)
            } else {
                HStack(spacing: TemaEspaciado.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColor.green)
                    Text(LocalizableKey.limpiarVacio.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
                .padding(TemaEspaciado.m)
                .background(AppColor.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
            }
        }
    }

    private var trabajando: Bool {
        if case .trabajando = viewModel.estado { return true }
        return false
    }

    @ViewBuilder
    private var banners: some View {
        if trabajando {
            HStack(spacing: TemaEspaciado.s) {
                ProgressView().controlSize(.small).tint(AppColor.accent)
                Text(LocalizableKey.limpiarTrabajando.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
            .padding(TemaEspaciado.s)
            .background(AppColor.surface0)
            .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
        }
        if case .exito(let msg) = viewModel.estado {
            HStack(spacing: TemaEspaciado.s) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColor.green)
                Text(msg)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.green)
                Spacer()
                Button(LocalizableKey.commonCerrar.localized()) { viewModel.limpiarEstado() }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppColor.text)
            }
            .padding(TemaEspaciado.s)
            .background(AppColor.green.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
        }
        if case .error(let msg) = viewModel.estado {
            HStack(spacing: TemaEspaciado.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(AppColor.red)
                Text(msg)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.red)
                Spacer()
                Button(LocalizableKey.commonCerrar.localized()) { viewModel.limpiarEstado() }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppColor.text)
            }
            .padding(TemaEspaciado.s)
            .background(AppColor.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
        }
    }

    private var textoAlerta: String {
        let c = viewModel.conteos
        var partes: [String] = []
        if c.transacciones > 0 { partes.append(LocalizableKey.limpiarDetalleTransacciones.localized(c.transacciones)) }
        if c.prestamos > 0 { partes.append(LocalizableKey.limpiarDetallePrestamos.localized(c.prestamos)) }
        if c.suscripciones > 0 { partes.append(LocalizableKey.limpiarDetalleSuscripciones.localized(c.suscripciones)) }
        if c.inventario > 0 { partes.append(LocalizableKey.limpiarDetalleInventario.localized(c.inventario)) }
        if c.saldoInicial { partes.append(LocalizableKey.limpiarDetalleSaldo.localized()) }
        let detalle = partes.isEmpty ? LocalizableKey.limpiarDetalleTodos.localized() : partes.joined(separator: ", ")
        return LocalizableKey.limpiarAlertDetalle.localized(detalle)
    }
}
