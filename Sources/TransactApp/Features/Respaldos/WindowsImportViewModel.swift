import Foundation
import AppKit
import SwiftUI
import Services
import Database
import Models

@MainActor
public final class WindowsImportViewModel: ObservableObject {

    public enum Paso {
        case seleccion
        case preflight
        case resolverTipos
        case preview
        case importando
        case finalizado(ResultadoImportacionWindows, Respaldo?)
    }

    @Published public private(set) var paso: Paso = .seleccion
    @Published public private(set) var rutaOrigen: URL?
    @Published public private(set) var preflightResultado: ResultadoPreflightWindows?
    @Published public private(set) var resultadoImportacion: ResultadoImportacionWindows?
    @Published public private(set) var respaldoPrevio: Respaldo?
    @Published public var mapeo: [Int64: MapeoSuscripcion] = [:]
    @Published public var modoSaldo: ModoSaldoInicial = .archivo
    @Published public var balanceRealEfectivo: Double = 0
    @Published public var balanceRealTarjeta: Double = 0
    @Published public private(set) var error: String?

    public let database: DatabaseManager
    public let backupService: BackupService
    public let errorPresenter: ErrorPresenter

    public init(
        database: DatabaseManager,
        backupService: BackupService,
        errorPresenter: ErrorPresenter = ErrorPresenter.shared
    ) {
        self.database = database
        self.backupService = backupService
        self.errorPresenter = errorPresenter
    }

    public func seleccionarArchivo() {
        let panel = NSOpenPanel()
        panel.title = "Seleccionar backup de TransactApp (Windows)"
        panel.message = "Elige el archivo .db del backup de Windows que quieres importar."
        panel.prompt = "Seleccionar"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        rutaOrigen = url
        error = nil
        Task { await ejecutarPreflight() }
    }

    public func ejecutarPreflight() async {
        guard let ruta = rutaOrigen else { return }
        paso = .preflight
        do {
            let pre = try await WindowsDatabaseImporter.preflight(ruta: ruta)
            preflightResultado = pre
            mapeo = Dictionary(
                uniqueKeysWithValues: pre.suscripcionesConTipoDesconocido.map { ($0.id, .gasto) }
            )
            if pre.suscripcionesConTipoDesconocido.isEmpty {
                paso = .preview
            } else {
                paso = .resolverTipos
            }
        } catch {
            self.error = "No se pudo leer el archivo: \(error.localizedDescription)"
            errorPresenter.present(
                category: .critical,
                title: "No pude leer el archivo de Windows",
                message: "Verifica que sea un backup válido de TransactApp (Windows).",
                suggestion: "Elige otro archivo .db y vuelve a intentarlo.",
                source: .importacion
            )
            paso = .seleccion
        }
    }

    public func establecerMapeo(id: Int64, mapeo valor: MapeoSuscripcion) {
        mapeo[id] = valor
    }

    public func aplicarTodosGasto() {
        guard let pre = preflightResultado else { return }
        for s in pre.suscripcionesConTipoDesconocido {
            mapeo[s.id] = .gasto
        }
    }

    public func aplicarTodosOmitir() {
        guard let pre = preflightResultado else { return }
        for s in pre.suscripcionesConTipoDesconocido {
            mapeo[s.id] = .omitir
        }
    }

    public func continuarAPreview() {
        paso = .preview
    }

    public func volverAResolverTipos() {
        paso = .resolverTipos
    }

    public func importar() async {
        guard let ruta = rutaOrigen else { return }
        paso = .importando
        var respaldo: Respaldo?
        do {
            respaldo = try backupService.crearRespaldo(
                nota: "Backup automático antes de importar desde Windows",
                automatico: true
            )
        } catch {
            self.error = "No se pudo crear el backup previo: \(error.localizedDescription)"
            errorPresenter.present(
                category: .critical,
                title: "No pude crear el respaldo previo",
                message: "La importación se canceló para no perder datos.",
                suggestion: "Verifica espacio en disco y que ~/Library/Application Support/TransactApp/backups/ tenga permisos de escritura.",
                source: .backup
            )
            paso = .preview
            return
        }
        do {
            let balanceReal: (efectivo: Double, tarjeta: Double)?
            switch modoSaldo {
            case .ajustarAReal:
                balanceReal = (balanceRealEfectivo, balanceRealTarjeta)
            case .archivo, .actual:
                balanceReal = nil
            }
            let resultado = try await WindowsDatabaseImporter.importar(
                ruta: ruta,
                alDestino: database,
                mapeoSuscripciones: mapeo,
                modoSaldo: modoSaldo,
                balanceReal: balanceReal
            )
            resultadoImportacion = resultado
            respaldoPrevio = respaldo
            paso = .finalizado(resultado, respaldo)
        } catch {
            self.error = "Falló la importación: \(error.localizedDescription)"
            let descripcion = error.localizedDescription
            let appError = AppError.personalizada(
                category: .critical,
                title: "Falló la importación",
                message: descripcion,
                suggestion: "Tu base de datos actual NO fue modificada (se creó un respaldo previo automático).",
                source: .importacion
            )
            errorPresenter.present(appError)
            paso = .preview
        }
    }

    public var saldoInicialTextoExplicativo: String {
        switch modoSaldo {
        case .archivo:
            return "Reemplazará tu saldo inicial actual con el del archivo ($\(formatMonto(preflightResultado?.saldoInicialEfectivo ?? 0)) efectivo + $\(formatMonto(preflightResultado?.saldoInicialTarjeta ?? 0)) tarjeta)."
        case .actual:
            return "Se conservará tu saldo inicial actual; el del archivo se ignora."
        case .ajustarAReal:
            return "Ingresa tu balance real y se calculará el saldo inicial para que la suma de transacciones coincida exactamente con él."
        }
    }

    private func formatMonto(_ d: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: NSDecimalNumber(decimal: d)) ?? "0.00"
    }

    public func reiniciar() {
        paso = .seleccion
        rutaOrigen = nil
        preflightResultado = nil
        resultadoImportacion = nil
        respaldoPrevio = nil
        mapeo = [:]
        modoSaldo = .archivo
        balanceRealEfectivo = 0
        balanceRealTarjeta = 0
        error = nil
    }

    public func limpiarError() {
        error = nil
    }

    public func conteoSuscripcionesOmitidas() -> Int {
        guard let pre = preflightResultado else { return 0 }
        return pre.suscripcionesConTipoDesconocido.filter { mapeo[$0.id] == .omitir }.count
    }
}
