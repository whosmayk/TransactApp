import Foundation
import SwiftUI
import DesignSystem
import Database
import Services
import Models
import PDFKit
import AppKit

@MainActor
final class ReportesViewModel: ObservableObject {
    @Published var mesSeleccionado: Date = Date()
    @Published var cargando: Bool = false
    @Published var error: String?
    @Published var reporte: ReporteMensual?
    @Published var datosPDF: Data?
    @Published var datosCSV: Data?
    @Published var mostrarCompartir: Bool = false
    @Published var urlCompartir: URL?

    @Published var incluirResumen: Bool = true
    @Published var incluirDetalleTransacciones: Bool = true
    @Published var incluirPrestamos: Bool = true
    @Published var incluirSuscripciones: Bool = true
    @Published var incluirInventario: Bool = true
    @Published var incluirProyeccionMes: Bool = true

    private let service: ReportesService
    private let errorPresenter: ErrorPresenter

    init(service: ReportesService, errorPresenter: ErrorPresenter = ErrorPresenter.shared) {
        self.service = service
        self.errorPresenter = errorPresenter
    }

    var nombreArchivoPDF: String {
        let parametros = parametrosActuales()
        return service.nombreArchivo(formato: .pdf, parametros: parametros)
    }

    var nombreArchivoCSV: String {
        let parametros = parametrosActuales()
        return service.nombreArchivo(formato: .csv, parametros: parametros)
    }

    var hayContenido: Bool {
        guard let reporte else { return false }
        return !reporte.transaccionesDelMes.isEmpty
            || !reporte.datos.prestamos.isEmpty
            || !reporte.datos.suscripciones.isEmpty
            || !reporte.datos.inventario.isEmpty
    }

    func cargar() async {
        guard !cargando else { return }
        cargando = true
        error = nil
        defer { cargando = false }
        do {
            let parametros = parametrosActuales()
            let reporteCompilado = try await service.compilarReporte(
                parametros: parametros,
                referencia: Date()
            )
            self.reporte = reporteCompilado
            self.datosPDF = try service.generarPDF(reporte: reporteCompilado)
            self.datosCSV = service.generarCSV(reporte: reporteCompilado)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func exportarPDF() {
        guard let datos = datosPDF else { return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(nombreArchivoPDF)
        do {
            try datos.write(to: url)
            urlCompartir = url
            mostrarCompartir = true
        } catch {
            self.error = LocalizableKey.reportesErrorPdf.localized() + ": " + error.localizedDescription
            errorPresenter.present(
                category: .critical,
                title: LocalizableKey.reportesErrorPdf.localized(),
                message: LocalizableKey.reportesErrorPdfMsg.localized(),
                suggestion: LocalizableKey.reportesErrorPdfSug.localized(),
                source: .exportacion
            )
        }
    }

    func exportarCSV() {
        guard let datos = datosCSV else { return }
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(nombreArchivoCSV)
        do {
            try datos.write(to: url)
            urlCompartir = url
            mostrarCompartir = true
        } catch {
            self.error = LocalizableKey.reportesErrorCsv.localized() + ": " + error.localizedDescription
            errorPresenter.present(
                category: .critical,
                title: LocalizableKey.reportesErrorCsv.localized(),
                message: LocalizableKey.reportesErrorCsvMsg.localized(),
                suggestion: LocalizableKey.reportesErrorCsvSug.localized(),
                source: .exportacion
            )
        }
    }

    func guardarPDFEnDescargas() {
        guardarArchivo(datos: datosPDF, nombre: nombreArchivoPDF, panelTitle: LocalizableKey.reportesGuardarPdf.localized())
    }

    func guardarCSVEnDescargas() {
        guardarArchivo(datos: datosCSV, nombre: nombreArchivoCSV, panelTitle: LocalizableKey.reportesGuardarCsv.localized())
    }

    func seleccionarMesAnterior() {
        let calendar = Calendar.current
        if let nuevo = calendar.date(byAdding: .month, value: -1, to: mesSeleccionado) {
            mesSeleccionado = nuevo
            Task { await cargar() }
        }
    }

    func seleccionarMesSiguiente() {
        let calendar = Calendar.current
        if let nuevo = calendar.date(byAdding: .month, value: 1, to: mesSeleccionado) {
            mesSeleccionado = nuevo
            Task { await cargar() }
        }
    }

    func recargarConOpciones() {
        Task { await cargar() }
    }

    func parametrosActuales() -> ParametrosReporte {
        ParametrosReporte(
            mes: mesSeleccionado,
            incluirResumen: incluirResumen,
            incluirDetalleTransacciones: incluirDetalleTransacciones,
            incluirPrestamos: incluirPrestamos,
            incluirSuscripciones: incluirSuscripciones,
            incluirInventario: incluirInventario,
            incluirProyeccionMes: incluirProyeccionMes
        )
    }

    private func guardarArchivo(
        datos: Data?,
        nombre: String,
        panelTitle: String
    ) {
        guard let datos else { return }
        let panel = NSSavePanel()
        panel.title = panelTitle
        panel.nameFieldStringValue = nombre
        panel.canCreateDirectories = true
        panel.allowedContentTypes = []
        panel.begin { respuesta in
            guard respuesta == .OK, let url = panel.url else { return }
            do {
                try datos.write(to: url)
            } catch {
                Task { @MainActor in
                    self.error = LocalizableKey.reportesErrorGuardar.localized() + ": " + error.localizedDescription
                    self.errorPresenter.present(
                        category: .critical,
                        title: LocalizableKey.reportesErrorGuardar.localized(),
                        message: LocalizableKey.reportesErrorGuardarMsg.localized(),
                        suggestion: LocalizableKey.reportesErrorGuardarSug.localized(),
                        source: .exportacion
                    )
                }
            }
        }
    }
}
