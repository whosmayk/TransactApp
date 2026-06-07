import SwiftUI
import Models
import Database
import Services

struct FormularioTransaccionHost: View {
    @StateObject private var viewModel: FormularioTransaccionViewModel
    let onCerrar: () -> Void

    init(
        service: TransactionService,
        transactionRepo: any TransactionRepository,
        transaccionInicial: Transaccion? = nil,
        onCerrar: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: FormularioTransaccionViewModel(
                service: service,
                transactionRepo: transactionRepo,
                transaccionInicial: transaccionInicial
            )
        )
        self.onCerrar = onCerrar
    }

    var body: some View {
        FormularioTransaccionView(viewModel: viewModel, onCerrar: onCerrar)
    }
}

struct FormularioPrestamoHost: View {
    @StateObject private var viewModel: FormularioPrestamoViewModel
    let onCerrar: () -> Void

    init(
        service: LoanService,
        prestamoInicial: Prestamo? = nil,
        onCerrar: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: FormularioPrestamoViewModel(
                service: service,
                prestamoInicial: prestamoInicial
            )
        )
        self.onCerrar = onCerrar
    }

    var body: some View {
        FormularioPrestamoView(viewModel: viewModel, onCerrar: onCerrar)
    }
}

struct FormularioSuscripcionHost: View {
    @StateObject private var viewModel: FormularioSuscripcionViewModel
    let onCerrar: () -> Void

    init(
        service: SubscriptionService,
        suscripcionInicial: Suscripcion? = nil,
        onCerrar: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: FormularioSuscripcionViewModel(
                service: service,
                suscripcionInicial: suscripcionInicial
            )
        )
        self.onCerrar = onCerrar
    }

    var body: some View {
        FormularioSuscripcionView(viewModel: viewModel, onCerrar: onCerrar)
    }
}

struct AjustesHost: View {
    @StateObject private var configuracionViewModel: ConfiguracionViewModel
    @StateObject private var respaldoViewModel: RespaldoViewModel
    @StateObject private var limpiarDatosViewModel: LimpiarDatosViewModel
    let tabInicial: AjustesView.Tab?

    init(
        configurationService: ConfigurationService,
        backupService: BackupService,
        database: DatabaseManager,
        tabInicial: AjustesView.Tab? = nil
    ) {
        self.tabInicial = tabInicial
        _configuracionViewModel = StateObject(
            wrappedValue: ConfiguracionViewModel(
                configurationService: configurationService
            )
        )
        _respaldoViewModel = StateObject(
            wrappedValue: RespaldoViewModel(
                service: backupService,
                database: database
            )
        )
        _limpiarDatosViewModel = StateObject(
            wrappedValue: LimpiarDatosViewModel(
                database: database,
                backupService: backupService
            )
        )
    }

    var body: some View {
        AjustesView(
            configuracionViewModel: configuracionViewModel,
            respaldoViewModel: respaldoViewModel,
            limpiarDatosViewModel: limpiarDatosViewModel,
            tabInicial: tabInicial
        )
    }
}

struct CambioBilleteHost: View {
    @StateObject private var viewModel: CambioBilleteViewModel
    let onCerrar: () -> Void

    init(
        inventoryService: InventoryService,
        inventoryRepo: any InventoryRepository,
        onCerrar: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: CambioBilleteViewModel(
                inventoryService: inventoryService,
                inventoryRepo: inventoryRepo,
                onCerrar: onCerrar
            )
        )
        self.onCerrar = onCerrar
    }

    var body: some View {
        CambioBilleteView(viewModel: viewModel, onCerrar: onCerrar)
    }
}
