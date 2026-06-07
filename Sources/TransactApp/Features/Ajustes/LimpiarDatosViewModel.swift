import Foundation
import Services
import Database
import Models

@MainActor
public final class LimpiarDatosViewModel: ObservableObject {

    public enum Estado: Equatable {
        case inactivo
        case trabajando
        case exito(String)
        case error(String)
    }

    @Published public private(set) var conteos: ConteosUsuario = ConteosUsuario(
        transacciones: 0, prestamos: 0, suscripciones: 0,
        inventario: 0, saldoInicial: false
    )
    @Published public private(set) var estado: Estado = .inactivo

    public let database: DatabaseManager
    public let backupService: BackupService

    public init(database: DatabaseManager, backupService: BackupService) {
        self.database = database
        self.backupService = backupService
    }

    public func cargar() {
        Task { await cargarAsync() }
    }

    public func cargarAsync() async {
        do {
            conteos = try await LimpiarDatosService.conteos(en: database)
        } catch {
            estado = .error(LocalizableKey.limpiarErrorConteos.localized() + ": " + error.localizedDescription)
        }
    }

    public func limpiar() {
        Task { await limpiarAsync() }
    }

    public func limpiarAsync() async {
        estado = .trabajando
        do {
            let respaldo = try backupService.crearRespaldo(
                nota: LocalizableKey.limpiarNota.localized(),
                automatico: true
            )
            let result = try await LimpiarDatosService.limpiar(en: database)
            conteos = result
            estado = .exito(
                LocalizableKey.limpiarExito.localized() + " " + respaldo.nombreArchivo + "."
            )
        } catch {
            estado = .error(LocalizableKey.limpiarError.localized() + ": " + error.localizedDescription)
        }
    }

    public func limpiarEstado() {
        estado = .inactivo
    }
}
