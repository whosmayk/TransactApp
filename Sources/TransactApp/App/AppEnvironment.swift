import Foundation
import Database
import Services
import Models

@MainActor
public final class AppEnvironment: ObservableObject {
    public let database: DatabaseManager
    public let initialBalance: any InitialBalanceRepository
    public let inventory: any InventoryRepository
    public let transactions: any TransactionRepository
    public let loans: any LoanRepository
    public let subscriptions: any SubscriptionRepository
    public let configuration: any ConfigurationRepository

    public let inventoryService: InventoryService
    public let transactionService: TransactionService
    public let loanService: LoanService
    public let subscriptionService: SubscriptionService
    public let configurationService: ConfigurationService
    public let projectionService: ProjectionService
    public let reportesService: ReportesService
    public let backupService: BackupService
    public let busquedaGlobalService: BusquedaGlobalService
    public let simuladorGastosService: SimuladorGastosService
    public let errorPresenter: ErrorPresenter

    public let supabaseManager: SupabaseManager
    public let syncService: SyncService

    public private(set) var observador: DatabaseObserver
    private var observadorTask: Task<Void, Never>?
    private var observadorHandler: (@MainActor () async -> Void)?

    public init(database: DatabaseManager) {
        self.database = database
        self.observador = database.crearObservador()
        self.initialBalance = SQLiteInitialBalanceRepository(manager: database)
        self.inventory = SQLiteInventoryRepository(manager: database)
        self.transactions = SQLiteTransactionRepository(manager: database)
        self.loans = SQLiteLoanRepository(manager: database)
        self.subscriptions = SQLiteSubscriptionRepository(manager: database)
        self.configuration = SQLiteConfigurationRepository(manager: database)

        self.inventoryService = InventoryService(manager: database, repo: self.inventory)
        self.transactionService = TransactionService(
            manager: database,
            transactionRepo: self.transactions,
            inventoryRepo: self.inventory
        )
        self.loanService = LoanService(manager: database, loanRepo: self.loans)
        self.subscriptionService = SubscriptionService(
            manager: database,
            subRepo: self.subscriptions,
            transactionRepo: self.transactions
        )
        self.configurationService = ConfigurationService(repo: self.configuration)
        self.projectionService = ProjectionService()
        self.reportesService = ReportesService(
            database: database,
            initialBalanceRepo: self.initialBalance,
            inventoryRepo: self.inventory,
            transactionRepo: self.transactions,
            loanRepo: self.loans,
            subscriptionRepo: self.subscriptions,
            configurationService: self.configurationService,
            projectionService: self.projectionService
        )
        let versionApp = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        self.backupService = BackupService(
            database: database,
            versionApp: versionApp
        )
        self.busquedaGlobalService = BusquedaGlobalService(
            transactions: self.transactions,
            loans: self.loans,
            subscriptions: self.subscriptions
        )
        self.simuladorGastosService = SimuladorGastosService()
        self.errorPresenter = ErrorPresenter.shared

        let supabase = SupabaseManager()
        self.supabaseManager = supabase
        self.syncService = SyncService(manager: database, supabase: supabase)
        // Escucha la notificación global para re-suscribir la observación
        // después de operaciones que cierran/reabren la dbQueue (p.ej.
        // `BackupService.restaurar`).
        NotificationCenter.default.addObserver(
            forName: .transactAppObservadorReiniciar,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reiniciarObservador()
            }
        }
    }

    /// Registra el handler que se ejecutará cada vez que cambien las tablas observadas.
    /// El observer emite únicamente cuando hay un cambio real en la DB (sin polling,
    /// sin timer, sin scene-phase). Internamente tiene un debounce de 150 ms para
    /// coalescer escrituras en ráfaga.
    public func registrarObservadorHandler(_ handler: @escaping @MainActor () async -> Void) {
        self.observadorHandler = handler
        iniciarSuscripcionObservador()
    }

    /// Cancela la suscripción actual sin eliminar el handler.
    /// Útil cuando se reemplaza el environment (p.ej. `RootCoordinator.reiniciar`).
    public func cancelarObservador() {
        observadorTask?.cancel()
        observadorTask = nil
    }

    /// Llamar después de `database.reemplazarArchivo(desde:)` para re-suscribir
    /// la observación a la nueva cola. Conserva el handler registrado.
    public func reiniciarObservador() {
        observadorTask?.cancel()
        observadorTask = nil
        self.observador = database.crearObservador()
        iniciarSuscripcionObservador()
    }

    private func iniciarSuscripcionObservador() {
        guard let handler = observadorHandler else { return }
        let stream = observador.observe()
        observadorTask = Task { @MainActor [weak self] in
            for await _ in stream {
                guard self != nil else { return }
                if Task.isCancelled { return }
                await handler()
            }
        }
    }

    public static func bootstrap() throws -> AppEnvironment {
        let db = try DatabaseManager.crearEnRutaPorDefecto()
        return AppEnvironment(database: db)
    }

    public static func bootstrapInMemory() throws -> AppEnvironment {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactApp-\(UUID().uuidString).sqlite")
        let db = try DatabaseManager(ruta: tmp)
        return AppEnvironment(database: db)
    }
}
