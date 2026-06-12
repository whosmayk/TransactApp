import Foundation
import AppKit
import Services
import GRDB
import Database
import Models

@MainActor
public final class RespaldoViewModel: ObservableObject {
    public enum Estado: Equatable {
        case inactivo
        case trabajando
        case error(String)
        case exito(String)
    }

    @Published public private(set) var respaldos: [Respaldo] = []
    @Published public private(set) var estado: Estado = .inactivo
    @Published public var autoRespaldoHabilitado: Bool = false

    public let service: BackupService
    public let database: DatabaseManager

    public init(service: BackupService, database: DatabaseManager) {
        self.service = service
        self.database = database
    }

    public func crearWindowsImportViewModel() -> WindowsImportViewModel {
        WindowsImportViewModel(database: database, backupService: service)
    }

    public func cargar() {
        do {
            respaldos = try service.listar()
            estado = .inactivo
        } catch {
            estado = .error(LocalizableKey.respaldoErrorListar.localized() + ": " + error.localizedDescription)
        }
    }

    public func crearRespaldo() async {
        estado = .trabajando
        do {
            let respaldo = try await Task.detached(priority: .userInitiated) { [service] in
                try service.crearRespaldo()
            }.value
            cargar()
            estado = .exito(LocalizableKey.respaldoCreado.localized(respaldo.nombreArchivo))
        } catch {
            estado = .error(LocalizableKey.respaldoErrorCrear.localized() + ": " + error.localizedDescription)
        }
    }

    public func eliminar(_ respaldo: Respaldo) {
        do {
            try service.eliminar(respaldo)
            cargar()
            estado = .exito(LocalizableKey.respaldoEliminado.localized())
        } catch {
            estado = .error(LocalizableKey.respaldoErrorEliminar.localized() + ": " + error.localizedDescription)
        }
    }

    public func restaurar(
        _ respaldo: Respaldo,
        modoSaldo: ModoSaldoInicial = .archivo,
        balanceReal: (efectivo: Double, tarjeta: Double)? = nil
    ) {
        Task { await restaurarAsync(respaldo, modoSaldo: modoSaldo, balanceReal: balanceReal) }
    }

    private struct SnapshotSaldo: Sendable {
        let efectivo: Double
        let tarjeta: Double
        let fechaCreacion: String
        let inventarioJson: String
    }

    private func restaurarAsync(
        _ respaldo: Respaldo,
        modoSaldo: ModoSaldoInicial,
        balanceReal: (efectivo: Double, tarjeta: Double)?
    ) async {
        do {
            if modoSaldo == .ajustarAReal && balanceReal == nil {
                estado = .error(LocalizableKey.respaldoErrorSinBalance.localized())
                return
            }
            var saldoPrevio: SnapshotSaldo?
            if modoSaldo != .archivo {
                saldoPrevio = try await database.leer { db -> SnapshotSaldo? in
                    guard let fila = try Row.fetchOne(db, sql: """
                        SELECT efectivo, tarjeta, fechaCreacion, inventarioJson FROM SaldoInicial
                        """) else { return nil }
                    return SnapshotSaldo(
                        efectivo: Double(fila["efectivo"] as Int64? ?? 0) / 100,
                        tarjeta: Double(fila["tarjeta"] as Int64? ?? 0) / 100,
                        fechaCreacion: fila["fechaCreacion"] ?? "",
                        inventarioJson: fila["inventarioJson"] ?? "[]"
                    )
                }
            }
            try service.restaurar(respaldo)
            // `reemplazarArchivo` cierra y reabre la `dbQueue` interna, lo cual
            // invalida la suscripción vigente del `DatabaseObserver` (sigue
            // apuntando a la cola vieja). Notificamos al `AppEnvironment` para
            // que re-suscriba sobre la nueva cola.
            NotificationCenter.default.post(
                name: .transactAppObservadorReiniciar, object: nil)
            switch modoSaldo {
            case .archivo:
                break
            case .actual:
                if let previo = saldoPrevio {
                    try await database.escribir { db in
                        try db.execute(sql: """
                            INSERT OR REPLACE INTO SaldoInicial
                              (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                            VALUES (1, ?, ?, ?, ?)
                            """, arguments: [
                                Int64(round(previo.efectivo * 100)),
                                Int64(round(previo.tarjeta * 100)),
                                previo.fechaCreacion, previo.inventarioJson
                            ])
                    }
                }
            case .ajustarAReal:
                guard let real = balanceReal else { break }
                let deltaEfCents = try await database.leer { db in
                    try Int64.fetchOne(db, sql: """
                        SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                        FROM Transacciones WHERE metodo='Efectivo'
                        """) ?? 0
                }
                let deltaTjCents = try await database.leer { db in
                    try Int64.fetchOne(db, sql: """
                        SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                        FROM Transacciones WHERE metodo='Tarjeta'
                        """) ?? 0
                }
                let fechaSnap = saldoPrevio?.fechaCreacion ?? ""
                let inventarioSnap = saldoPrevio?.inventarioJson ?? "[]"
                let nuevoEfCents = Int64(round(real.efectivo * 100)) - deltaEfCents
                let nuevoTjCents = Int64(round(real.tarjeta * 100)) - deltaTjCents
                try await database.escribir { db in
                    try db.execute(sql: """
                        INSERT OR REPLACE INTO SaldoInicial
                          (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                        VALUES (1, ?, ?, ?, ?)
                        """, arguments: [nuevoEfCents, nuevoTjCents, fechaSnap, inventarioSnap])
                }
            }
            let msg: String
            switch modoSaldo {
            case .archivo:
                msg = LocalizableKey.respaldoExitoArchivo.localized(respaldo.nombreArchivo)
            case .actual:
                msg = LocalizableKey.respaldoExitoActual.localized(respaldo.nombreArchivo)
            case .ajustarAReal:
                let efText = Localizador.moneda(Decimal(balanceReal?.efectivo ?? 0))
                let tjText = Localizador.moneda(Decimal(balanceReal?.tarjeta ?? 0))
                msg = LocalizableKey.respaldoExitoAjustar.localized(respaldo.nombreArchivo, efText, tjText)
            }
            estado = .exito(msg)
        } catch {
            estado = .error(LocalizableKey.respaldoErrorRestaurar.localized() + ": " + error.localizedDescription)
        }
    }

    public func importar() -> URL? {
        let panel = NSOpenPanel()
        panel.title = LocalizableKey.respaldoImportarPanel.localized()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            let respaldo = try service.importarDesdeArchivo(url)
            cargar()
            estado = .exito(LocalizableKey.respaldoImportado.localized(respaldo.nombreArchivo))
            return url
        } catch {
            estado = .error(LocalizableKey.respaldoErrorImportar.localized() + ": " + error.localizedDescription)
            return nil
        }
    }

    public func mostrarEnFinder(_ respaldo: Respaldo) {
        NSWorkspace.shared.activateFileViewerSelecting([respaldo.url])
    }

    public func limpiarEstado() {
        estado = .inactivo
    }
}
