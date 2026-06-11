import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class GestionPrestamosViewModel: ObservableObject {
    @Published var prestamos: [Prestamo] = []
    @Published var cargando: Bool = false
    @Published var error: String?

    let service: LoanService
    let transactionService: TransactionService
    let transactionRepo: any TransactionRepository
    let inventoryRepo: any InventoryRepository
    private let loanRepo: any LoanRepository

    init(
        service: LoanService,
        transactionService: TransactionService,
        transactionRepo: any TransactionRepository,
        inventoryRepo: any InventoryRepository,
        loanRepo: any LoanRepository
    ) {
        self.service = service
        self.transactionService = transactionService
        self.transactionRepo = transactionRepo
        self.inventoryRepo = inventoryRepo
        self.loanRepo = loanRepo
    }

    var prestamosMeDeben: [Prestamo] {
        prestamos.filter { $0.tipo == .meDeben }
    }

    var prestamosDebo: [Prestamo] {
        prestamos.filter { $0.tipo == .debo }
    }

    var pendienteMeDeben: Decimal {
        prestamosMeDeben.reduce(into: Decimal(0)) { $0 += $1.saldoPendiente }
    }

    var pendienteDebo: Decimal {
        prestamosDebo.reduce(into: Decimal(0)) { $0 += $1.saldoPendiente }
    }

    func cargar() async {
        guard !cargando else { return }
        cargando = true
        error = nil
        defer { cargando = false }
        do {
            prestamos = try await loanRepo.listar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func eliminar(_ prestamo: Prestamo) async {
        guard let id = prestamo.id else { return }
        do {
            try await service.eliminar(id: id)
            await cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
