import Foundation
import Testing
import Database
import Services
import Models
@testable import TransactApp

@Suite("Dashboard auto-refresh via AppEnvironment")
struct DashboardAutoRefreshTests {

    @Test("El handler registrado se invoca cuando la DB cambia")
    @MainActor
    func handlerSeInvocaTrasCambioEnDB() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("refresh.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let env = AppEnvironment(database: manager)

        let contador = ContadorActor()
        env.registrarObservadorHandler {
            await contador.incrementar()
        }
        // Dejamos pasar el initial value del observer
        try? await Task.sleep(for: .milliseconds(250))

        // Insertamos en una tabla trackeada
        try await env.database.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["2026-06-07", "12:00", "test", 50.0, "Ingreso", "X", "Efectivo"])
        }
        try? await Task.sleep(for: .milliseconds(300))

        let total = await contador.valor
        #expect(total >= 1, "El handler debe haberse invocado al menos 1 vez tras el INSERT (total: \(total))")

        env.cancelarObservador()
    }

    @Test("reiniciarObservador() re-suscribe tras reemplazarArchivo")
    @MainActor
    func reiniciarObservadorRenuevaSuscripcion() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("reiniciar.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let env = AppEnvironment(database: manager)

        let contador = ContadorActor()
        env.registrarObservadorHandler {
            await contador.incrementar()
        }
        try? await Task.sleep(for: .milliseconds(250))

        // Simulamos un reemplazo de archivo cerrando+reabriendo
        // (el reinicio real vía BackupService hace lo mismo internamente)
        try manager.reabrir()
        env.reiniciarObservador()
        try? await Task.sleep(for: .milliseconds(250))

        // Insertamos y verificamos que el nuevo observer emite
        let antes = await contador.valor
        try await env.database.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["2026-06-07", "12:30", "post-restart", 25.0, "Gasto", "X", "Efectivo"])
        }
        try? await Task.sleep(for: .milliseconds(300))
        let despues = await contador.valor

        #expect(despues > antes,
                "Tras reiniciar el observer y escribir, el handler debe invocarse (antes=\(antes), despues=\(despues))")

        env.cancelarObservador()
    }
}

private actor ContadorActor {
    var valor: Int = 0
    func incrementar() { valor += 1 }
}
