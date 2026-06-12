import SwiftUI
import AppKit
import Services
import Models
import DesignSystem
import Database

public struct RespaldoView: View {
    @ObservedObject var viewModel: RespaldoViewModel
    @State private var respaldoParaRestaurar: Respaldo?
    @State private var respaldoParaEliminar: Respaldo?
    @State private var respaldoConOpciones: Respaldo?
    @State private var respaldoConBalance: Respaldo?
    @State private var balanceRealEfectivo: Double = 0
    @State private var balanceRealTarjeta: Double = 0
    @State private var windowsImportSheet: WindowsImportPresentation?

    public init(viewModel: RespaldoViewModel) {
        self.viewModel = viewModel
    }

    private struct WindowsImportPresentation: Identifiable {
        let id = UUID()
        let vm: WindowsImportViewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.l) {
            header
            actionsBar
            if viewModel.respaldos.isEmpty {
                emptyState
            } else {
                listaRespaldos
            }
            if case .error(let msg) = viewModel.estado {
                bannerError(msg)
            }
            if case .exito(let msg) = viewModel.estado {
                bannerExito(msg)
            }
        }
        .padding(TemaEspaciado.l)
        .frame(minWidth: 520, minHeight: 480)
        .onAppear { viewModel.cargar() }
        .alert(LocalizableKey.respaldoAlertRestaurarTitulo.localized(), isPresented: Binding(
            get: { respaldoParaRestaurar != nil },
            set: { if !$0 { respaldoParaRestaurar = nil } }
        )) {
            Button(LocalizableKey.commonCancelar.localized(), role: .cancel) { respaldoParaRestaurar = nil }
            Button(LocalizableKey.respaldoOpcionesSaldo.localized(), role: .none) {
                respaldoConOpciones = respaldoParaRestaurar
                respaldoParaRestaurar = nil
            }
            Button(LocalizableKey.respaldoRestaurarCompleto.localized(), role: .destructive) {
                if let r = respaldoParaRestaurar {
                    viewModel.restaurar(r, modoSaldo: .archivo)
                }
                respaldoParaRestaurar = nil
            }
        } message: {
            if let r = respaldoParaRestaurar {
                Text(LocalizableKey.respaldoAlertRestaurarMsg.localized(r.nombreArchivo))
            }
        }
        .confirmationDialog(
            respaldoConOpciones.map { LocalizableKey.respaldoDialogElegirModo.localized($0.nombreArchivo) } ?? "",
            isPresented: Binding(
                get: { respaldoConOpciones != nil },
                set: { if !$0 { respaldoConOpciones = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(LocalizableKey.respaldoOpcionCompleto.localized()) {
                if let r = respaldoConOpciones {
                    viewModel.restaurar(r, modoSaldo: .archivo)
                }
                respaldoConOpciones = nil
            }
            Button(LocalizableKey.respaldoOpcionConservar.localized()) {
                if let r = respaldoConOpciones {
                    viewModel.restaurar(r, modoSaldo: .actual)
                }
                respaldoConOpciones = nil
            }
            Button(LocalizableKey.respaldoOpcionAjustar.localized()) {
                respaldoConBalance = respaldoConOpciones
                respaldoConOpciones = nil
            }
            Button(LocalizableKey.respaldoOpcionCancelar.localized(), role: .cancel) {
                respaldoConOpciones = nil
            }
        } message: {
            Text(LocalizableKey.respaldoDialogMsg.localized())
        }
        .sheet(item: Binding(
            get: { respaldoConBalance },
            set: { if $0 == nil { respaldoConBalance = nil } }
        ), onDismiss: {
            balanceRealEfectivo = 0
            balanceRealTarjeta = 0
        }) { respaldo in
            balanceRealSheet(respaldo: respaldo)
        }
        .alert(LocalizableKey.respaldoAlertEliminarTitulo.localized(), isPresented: Binding(
            get: { respaldoParaEliminar != nil },
            set: { if !$0 { respaldoParaEliminar = nil } }
        )) {
            Button(LocalizableKey.commonCancelar.localized(), role: .cancel) { respaldoParaEliminar = nil }
            Button(LocalizableKey.commonEliminar.localized(), role: .destructive) {
                if let r = respaldoParaEliminar {
                    viewModel.eliminar(r)
                }
                respaldoParaEliminar = nil
            }
        } message: {
            if let r = respaldoParaEliminar {
                Text(LocalizableKey.respaldoAlertEliminarMsg.localized(r.nombreArchivo))
            }
        }
        .sheet(item: $windowsImportSheet, onDismiss: { viewModel.cargar() }) { sheet in
            WindowsImportView(viewModel: sheet.vm)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text(LocalizableKey.respaldoTitulo.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.respaldoVersion.localized(Migrator.versionActual))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
            Spacer()
        }
    }

    private var actionsBar: some View {
        HStack(spacing: TemaEspaciado.m) {
            PrimaryButton(LocalizableKey.respaldoCrear.localized(), icono: "square.and.arrow.down") {
                Task { await viewModel.crearRespaldo() }
            }
            GhostButton(LocalizableKey.respaldoImportar.localized(), icono: "square.and.arrow.up") {
                _ = viewModel.importar()
            }
            GhostButton(LocalizableKey.respaldoImportarWindows.localized(), icono: "externaldrive.badge.plus") {
                windowsImportSheet = WindowsImportPresentation(
                    vm: viewModel.crearWindowsImportViewModel()
                )
            }
            GhostButton(LocalizableKey.respaldoRefrescar.localized(), icono: "arrow.clockwise") {
                viewModel.cargar()
            }
            Spacer()
            if case .trabajando = viewModel.estado {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppColor.accent)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: TemaEspaciado.m) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppColor.subtext0)
            Text(LocalizableKey.respaldoVacioTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.subtext0)
            Text(LocalizableKey.respaldoVacioDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(TemaEspaciado.xl)
    }

    private var listaRespaldos: some View {
        VStack(spacing: TemaEspaciado.s) {
            ForEach(viewModel.respaldos) { respaldo in
                respaldoRow(respaldo)
            }
        }
    }

    private func respaldoRow(_ respaldo: Respaldo) -> some View {
        HStack(spacing: TemaEspaciado.m) {
            Image(systemName: respaldo.automatico ? "clock.arrow.circlepath" : "doc.zipper")
                .font(.system(size: 20))
                .foregroundColor(respaldo.automatico ? AppColor.sapphire : AppColor.peach)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(respaldo.nombreArchivo)
                    .font(Tipografia.cuerpo().monospaced())
                    .foregroundColor(AppColor.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: TemaEspaciado.s) {
                    Text(Localizador.fechaCompleta(respaldo.fecha))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    Text("·")
                        .foregroundColor(AppColor.subtext1)
                    Text(Localizador.bytes(Int64(respaldo.tamano)))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    Text("·")
                        .foregroundColor(AppColor.subtext1)
                    Text("v\(respaldo.versionEsquema)")
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    if let nota = respaldo.nota {
                        Text("·")
                            .foregroundColor(AppColor.subtext1)
                        Text(nota)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            HStack(spacing: TemaEspaciado.s) {
                Button {
                    viewModel.mostrarEnFinder(respaldo)
                } label: {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(LocalizableKey.respaldoMostrarFinder.localized())

                Button {
                    respaldoParaRestaurar = respaldo
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(LocalizableKey.respaldoRestaurar.localized())

                Button {
                    respaldoParaEliminar = respaldo
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .foregroundColor(AppColor.red)
                .help(LocalizableKey.respaldoEliminar.localized())
            }
        }
        .padding(TemaEspaciado.m)
        .background(AppColor.surface0)
        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.m))
    }

    private func bannerError(_ msg: String) -> some View {
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

    private func bannerExito(_ msg: String) -> some View {
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

    private func balanceRealSheet(respaldo: Respaldo) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.l) {
            HStack {
                Image(systemName: "scalemass")
                    .foregroundColor(AppColor.peach)
                Text(LocalizableKey.respaldoAjustarSheetTitulo.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Spacer()
            }
            Text(LocalizableKey.respaldoAjustarSheetDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: TemaEspaciado.m) {
                VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                    Text(LocalizableKey.respaldoEfectivo.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    TextField(LocalizableKey.montoPlaceholder.localized(), value: $balanceRealEfectivo,
                              format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.plain)
                        .font(Tipografia.montoMediano().monospaced())
                        .foregroundColor(AppColor.text)
                        .padding(.horizontal, TemaEspaciado.m)
                        .padding(.vertical, TemaEspaciado.s)
                        .background(AppColor.surface0)
                        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                }
                VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                    Text(LocalizableKey.respaldoTarjeta.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    TextField(LocalizableKey.montoPlaceholder.localized(), value: $balanceRealTarjeta,
                              format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.plain)
                        .font(Tipografia.montoMediano().monospaced())
                        .foregroundColor(AppColor.text)
                        .padding(.horizontal, TemaEspaciado.m)
                        .padding(.vertical, TemaEspaciado.s)
                        .background(AppColor.surface0)
                        .clipShape(RoundedRectangle(cornerRadius: TemaRadio.s))
                }
            }
            Spacer()
            HStack {
                GhostButton(LocalizableKey.commonCancelar.localized(), icono: nil) {
                    respaldoConBalance = nil
                }
                Spacer()
                PrimaryButton(LocalizableKey.respaldoAjustarYRestaurar.localized(), icono: "arrow.uturn.backward.circle") {
                    let r = respaldo
                    viewModel.restaurar(
                        r,
                        modoSaldo: .ajustarAReal,
                        balanceReal: (balanceRealEfectivo, balanceRealTarjeta)
                    )
                    respaldoConBalance = nil
                }
            }
        }
        .padding(TemaEspaciado.xl)
        .frame(minWidth: 480, minHeight: 320)
        .background(AppColor.mantle)
    }
}
