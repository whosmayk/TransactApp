import SwiftUI
import DesignSystem
import Models
import Database
import Services
import PDFKit

struct ReportesView: View {
    @ObservedObject var viewModel: ReportesViewModel

    var body: some View {
        VStack(spacing: 0) {
            encabezado
            Divider().background(AppColor.surface1)
            contenido
        }
        .background(AppColor.base)
        .frame(minWidth: 900, minHeight: 600)
        .task { await viewModel.cargar() }
    }

    private var encabezado: some View {
        HStack {
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text(LocalizableKey.reportesTitulo.localized())
                    .font(Tipografia.titulo())
                    .foregroundColor(AppColor.text)
                Text(LocalizableKey.reportesSubtitulo.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext1)
            }
            Spacer()
            selectorMes
        }
        .padding(TemaEspaciado.l)
        .background(AppColor.mantle)
    }

    private var selectorMes: some View {
        HStack(spacing: TemaEspaciado.s) {
            Button(action: { viewModel.seleccionarMesAnterior() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .foregroundColor(AppColor.subtext0)

            Text(mesLegible(viewModel.mesSeleccionado))
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
                .frame(minWidth: 160)

            Button(action: { viewModel.seleccionarMesSiguiente() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .foregroundColor(AppColor.subtext0)
        }
        .padding(.horizontal, TemaEspaciado.s)
        .padding(.vertical, TemaEspaciado.s)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                .fill(AppColor.surface0)
        )
    }

    private var contenido: some View {
        HStack(spacing: 0) {
            panelOpciones
                .frame(width: 280)
            Divider().background(AppColor.surface1)
            vistaPrevia
        }
    }

    private var panelOpciones: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.l) {
                seccionSecciones
                seccionAcciones
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
                if !viewModel.hayContenido {
                    Text(LocalizableKey.reportesSinDatosMes.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            }
            .padding(TemaEspaciado.l)
        }
        .background(AppColor.mantle)
    }

    private var seccionSecciones: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.reportesSecciones.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)

            Toggle(LocalizableKey.reportesSeccionResumen.localized(), isOn: $viewModel.incluirResumen)
                .onChange(of: viewModel.incluirResumen) { _, _ in viewModel.recargarConOpciones() }
            Toggle(LocalizableKey.reportesSeccionDetalle.localized(), isOn: $viewModel.incluirDetalleTransacciones)
                .onChange(of: viewModel.incluirDetalleTransacciones) { _, _ in viewModel.recargarConOpciones() }
            Toggle(LocalizableKey.reportesSeccionPrestamos.localized(), isOn: $viewModel.incluirPrestamos)
                .onChange(of: viewModel.incluirPrestamos) { _, _ in viewModel.recargarConOpciones() }
            Toggle(LocalizableKey.reportesSeccionSuscripciones.localized(), isOn: $viewModel.incluirSuscripciones)
                .onChange(of: viewModel.incluirSuscripciones) { _, _ in viewModel.recargarConOpciones() }
            Toggle(LocalizableKey.reportesSeccionInventario.localized(), isOn: $viewModel.incluirInventario)
                .onChange(of: viewModel.incluirInventario) { _, _ in viewModel.recargarConOpciones() }
            Toggle(LocalizableKey.reportesSeccionProyeccion.localized(), isOn: $viewModel.incluirProyeccionMes)
                .onChange(of: viewModel.incluirProyeccionMes) { _, _ in viewModel.recargarConOpciones() }
        }
        .toggleStyle(.switch)
        .foregroundColor(AppColor.subtext1)
    }

    private var seccionAcciones: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.reportesExportar.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)

            PrimaryButton(
                LocalizableKey.reportesCompartirPdf.localized(),
                icono: "square.and.arrow.up",
                habilitado: viewModel.datosPDF != nil && !viewModel.cargando
            ) {
                viewModel.exportarPDF()
            }
            GhostButton(
                LocalizableKey.reportesGuardarPdf.localized(),
                icono: "arrow.down.doc",
                habilitado: viewModel.datosPDF != nil && !viewModel.cargando
            ) {
                viewModel.guardarPDFEnDescargas()
            }
            GhostButton(
                LocalizableKey.reportesCompartirCsv.localized(),
                icono: "tablecells",
                habilitado: viewModel.datosCSV != nil && !viewModel.cargando
            ) {
                viewModel.exportarCSV()
            }
            GhostButton(
                LocalizableKey.reportesGuardarCsv.localized(),
                icono: "arrow.down.doc.fill",
                habilitado: viewModel.datosCSV != nil && !viewModel.cargando
            ) {
                viewModel.guardarCSVEnDescargas()
            }
        }
    }

    @ViewBuilder
    private var vistaPrevia: some View {
        ZStack {
            AppColor.base
            if viewModel.cargando {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppColor.accent)
            } else if let datos = viewModel.datosPDF,
                      let doc = PDFDocument(data: datos) {
                PDFKitView(document: doc)
            } else if let reporte = viewModel.reporte {
                VStack(alignment: .center, spacing: TemaEspaciado.m) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(AppColor.subtext0)
                    Text(LocalizableKey.reportesVaciaTitulo.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.subtext1)
                    Text(LocalizableKey.reportesTransaccionesConteo.localized(reporte.transaccionesDelMes.count))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            } else {
                Text(LocalizableKey.reportesSeleccionaMes.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
        }
        .sheet(isPresented: $viewModel.mostrarCompartir) {
            if let url = viewModel.urlCompartir {
                CompartirArchivoSheet(url: url)
            }
        }
    }

    private func mesLegible(_ fecha: Date) -> String {
        Localizador.mesAno(fecha).capitalized
    }
}

private struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = NSColor(calibratedRed: 0.047, green: 0.055, blue: 0.063, alpha: 1)
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document !== document {
            nsView.document = document
        }
    }
}

private struct CompartirArchivoSheet: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            let picker = NSSharingServicePicker(items: [url])
            let location = NSPoint(x: 100, y: 100)
            picker.show(relativeTo: NSRect(origin: location, size: .zero), of: view, preferredEdge: .minY)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
