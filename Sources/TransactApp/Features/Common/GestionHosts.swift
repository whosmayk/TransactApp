import SwiftUI
import Models
import Database
import Services

struct GestionPrestamosHost: View {
    @StateObject private var viewModel: GestionPrestamosViewModel

    init(
        service: LoanService,
        transactionService: TransactionService,
        transactionRepo: any TransactionRepository,
        inventoryRepo: any InventoryRepository,
        loanRepo: any LoanRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: GestionPrestamosViewModel(
                service: service,
                transactionService: transactionService,
                transactionRepo: transactionRepo,
                inventoryRepo: inventoryRepo,
                loanRepo: loanRepo
            )
        )
    }

    var body: some View {
        GestionPrestamosView(viewModel: viewModel)
    }
}

struct GestionSuscripcionesHost: View {
    @StateObject private var viewModel: GestionSuscripcionesViewModel

    init(
        service: SubscriptionService,
        subRepo: any SubscriptionRepository
    ) {
        _viewModel = StateObject(
            wrappedValue: GestionSuscripcionesViewModel(
                service: service,
                subRepo: subRepo
            )
        )
    }

    var body: some View {
        GestionSuscripcionesView(viewModel: viewModel)
    }
}
