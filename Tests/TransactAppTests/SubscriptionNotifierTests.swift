import Foundation
import Testing
import Models
import Database
import Services
@testable import TransactApp

@Suite("SubscriptionNotifier")
struct SubscriptionNotifierTests {

    @Test("Devuelve solo suscripciones activas en ventana y no notificadas")
    func notificar() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("notif.sqlite"))
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let svc = SubscriptionService(manager: manager, subRepo: subRepo)
        let notifier = SubscriptionNotifier(service: svc, ventana: 3)

        let ahora = Date()
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: ahora)!
        let en5 = Calendar.current.date(byAdding: .day, value: 5, to: ahora)!
        let ayer = Calendar.current.date(byAdding: .day, value: -1, to: ahora)!

        _ = try await svc.crear(Suscripcion(
            concepto: "Mañana", monto: 100, categoria: "X",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: manana
        ))
        _ = try await svc.crear(Suscripcion(
            concepto: "En 5", monto: 100, categoria: "X",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: en5
        ))
        _ = try await svc.crear(Suscripcion(
            concepto: "Ayer", monto: 100, categoria: "X",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: ayer
        ))

        let notifs = await notifier.revisar()
        #expect(notifs.count == 2)
        let conceptos = Set(notifs.map { $0.concepto })
        #expect(conceptos.contains("Mañana"))
        #expect(conceptos.contains("Ayer"))
    }

    @Test("marcarNotificadas impide que vuelvan a aparecer")
    func marcarYRevisar() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let manager = try DatabaseManager(ruta: tmpDir.appendingPathComponent("notif2.sqlite"))
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let svc = SubscriptionService(manager: manager, subRepo: subRepo)
        let notifier = SubscriptionNotifier(service: svc, ventana: 3)

        let ahora = Date()
        let manana = Calendar.current.date(byAdding: .day, value: 1, to: ahora)!
        _ = try await svc.crear(Suscripcion(
            concepto: "Mañana", monto: 100, categoria: "X",
            frecuencia: .mensual, tipo: .gasto,
            fechaInicio: ahora, proximoCobro: manana
        ))

        let primera = await notifier.revisar()
        #expect(primera.count == 1)
        await notifier.marcarNotificadas(primera.map(\.id))

        let segunda = await notifier.revisar()
        #expect(segunda.isEmpty)
    }
}
