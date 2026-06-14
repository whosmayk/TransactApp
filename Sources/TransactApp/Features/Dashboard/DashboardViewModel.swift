import Foundation
import SwiftUI
import DesignSystem
import Database
import Services
import Models

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var resumen: ResumenFinanciero = .vacio
    @Published var ingresosMes: Decimal = 0
    @Published var gastosMesFirmado: Decimal = 0
    @Published var ingresosHistorico: Decimal = 0
    @Published var gastosHistoricoFirmado: Decimal = 0
    @Published var inventario: [Inventario] = []
    @Published var prestamos: [Prestamo] = []
    @Published var suscripciones: [Suscripcion] = []
    @Published var notificaciones: [NotificacionSuscripcion] = []
    @Published var cargando: Bool = false
    @Published var error: String?
    private var necesitaRecarga = false

    private let initialBalanceRepo: any InitialBalanceRepository
    private let inventoryRepo: any InventoryRepository
    private let transactionRepo: any TransactionRepository
    private let loanRepo: any LoanRepository
    private let subscriptionRepo: any SubscriptionRepository
    private let notifier: SubscriptionNotifier?

    init(
        initialBalanceRepo: any InitialBalanceRepository,
        inventoryRepo: any InventoryRepository,
        transactionRepo: any TransactionRepository,
        loanRepo: any LoanRepository,
        subscriptionRepo: any SubscriptionRepository,
        notifier: SubscriptionNotifier? = nil
    ) {
        self.initialBalanceRepo = initialBalanceRepo
        self.inventoryRepo = inventoryRepo
        self.transactionRepo = transactionRepo
        self.loanRepo = loanRepo
        self.subscriptionRepo = subscriptionRepo
        self.notifier = notifier
    }

    var totalInventario: Decimal {
        inventario.reduce(into: Decimal(0)) { $0 += $1.subtotal }
    }

    var netoMes: Decimal {
        ingresosMes + gastosMesFirmado
    }

    var prestamosPendientes: Int {
        prestamos.filter { !$0.estaPagado }.count
    }

    var totalPendienteMeDeben: Decimal {
        prestamos.filter { $0.tipo == .meDeben && !$0.estaPagado }
            .reduce(into: Decimal(0)) { $0 += $1.saldoPendiente }
    }

    var totalPendienteDebo: Decimal {
        prestamos.filter { $0.tipo == .debo && !$0.estaPagado }
            .reduce(into: Decimal(0)) { $0 += $1.saldoPendiente }
    }

    var suscripcionesActivas: Int {
        suscripciones.filter { $0.activa }.count
    }

    var suscripcionesPorVencer: Int {
        notificaciones.count
    }

    var totalMensualSuscripciones: Decimal {
        suscripciones
            .filter { $0.activa }
            .reduce(into: Decimal(0)) { $0 += $1.montoMensual() }
    }

    func cargar() async {
        guard !cargando else {
            necesitaRecarga = true
            return
        }
        cargando = true
        error = nil
        defer {
            cargando = false
            if necesitaRecarga {
                necesitaRecarga = false
                Task { await cargar() }
            }
        }

        do {
            async let saldoInicialTask = initialBalanceRepo.obtener()
            async let inventarioTask = inventoryRepo.listar()
            async let transaccionesTask = transactionRepo.listar()
            async let prestamosTask = loanRepo.listar()
            async let suscripcionesTask = subscriptionRepo.listar()
            async let notifTask: [NotificacionSuscripcion] = {
                guard let notifier else { return [] }
                return await notifier.revisar()
            }()

            let (saldoInicial, inventario, transacciones, prestamos, suscripciones, notifs) =
                try await (
                    saldoInicialTask,
                    inventarioTask,
                    transaccionesTask,
                    prestamosTask,
                    suscripcionesTask,
                    notifTask
                )

            let resumen = CalculosFinancieros.resumen(
                saldoInicial: saldoInicial,
                transacciones: transacciones,
                prestamos: prestamos
            )
            let transaccionesMes = transaccionesDelMesActual(transacciones)
            let ingresosMes = transaccionesMes
                .filter { $0.tipo == .ingreso }
                .reduce(into: Decimal(0)) { $0 += $1.monto }
            let gastosMesAbs = transaccionesMes
                .filter { $0.tipo == .gasto }
                .reduce(into: Decimal(0)) { $0 += $1.monto }
            let ingresosHistorico = transacciones
                .filter { $0.tipo == .ingreso }
                .reduce(into: Decimal(0)) { $0 += $1.monto }
            let gastosHistAbs = transacciones
                .filter { $0.tipo == .gasto }
                .reduce(into: Decimal(0)) { $0 += $1.monto }

            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                self.inventario = inventario
                self.prestamos = prestamos
                self.suscripciones = suscripciones
                self.notificaciones = notifs
                self.resumen = resumen
                self.ingresosMes = ingresosMes
                self.gastosMesFirmado = -gastosMesAbs
                self.ingresosHistorico = ingresosHistorico
                self.gastosHistoricoFirmado = -gastosHistAbs
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func descartarNotificaciones() async {
        if let notifier {
            await notifier.marcarNotificadas(notificaciones.map(\.id))
        }
        notificaciones = []
    }

    private func transaccionesDelMesActual(_ todas: [Transaccion]) -> [Transaccion] {
        let calendario = Calendar.current
        let ahora = Date()
        guard let inicioMes = calendario.dateInterval(of: .month, for: ahora)?.start,
              let finMes = calendario.dateInterval(of: .month, for: ahora)?.end else {
            return todas
        }
        return todas.filter { tx in
            tx.fecha >= inicioMes && tx.fecha < finMes
        }
    }
}
