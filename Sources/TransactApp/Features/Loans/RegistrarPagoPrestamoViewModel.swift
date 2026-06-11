import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class RegistrarPagoPrestamoViewModel: ObservableObject {
    @Published var prestamo: Prestamo
    @Published var metodo: MetodoPago = .efectivo
    @Published var desglose: DesgloseBilletes = DesgloseBilletes()
    @Published var montoPago: CampoMonto = CampoMonto()
    @Published var fecha: Date
    @Published var error: String?
    @Published var guardando: Bool = false
    @Published var guardado: Bool = false

    private let transactionService: TransactionService
    private let loanService: LoanService
    private let transactionRepo: any TransactionRepository
    private let inventoryRepo: any InventoryRepository

    init(
        prestamo: Prestamo,
        transactionService: TransactionService,
        transactionRepo: any TransactionRepository,
        inventoryRepo: any InventoryRepository,
        loanService: LoanService
    ) {
        self.prestamo = prestamo
        self.transactionService = transactionService
        self.transactionRepo = transactionRepo
        self.inventoryRepo = inventoryRepo
        self.loanService = loanService
        self.fecha = Date()
    }

    var montoValido: Bool { montoPago.valor > 0 }

    var desgloseValido: Bool {
        if metodo != .efectivo { return true }
        let diff = abs((montoPago.valor - desglose.subtotal) as Decimal)
        return diff < Decimal(0.01)
    }

    var esValido: Bool { montoValido && desgloseValido }

    var saldoRestante: Decimal { prestamo.saldoPendiente }

    var mensajeError: String? {
        if !montoValido { return "El monto del pago debe ser mayor a 0." }
        if montoPago.valor > saldoRestante { return "El pago no puede exceder el saldo pendiente (\(Localizador.moneda(saldoRestante)))." }
        if metodo == .efectivo && !desgloseValido { return "La suma del desglose debe coincidir con el monto." }
        return nil
    }

    func autocompletarDesglose() {
        guard montoPago.valor > 0 else { return }
        desglose = DesgloseBilletes.autoDesglose(monto: montoPago.valor)
    }

    func registrar() async {
        guard !guardando else { return }
        guard esValido else {
            error = mensajeError
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }

        do {
            let tipo: TipoTransaccion = prestamo.tipo == .meDeben ? .ingreso : .gasto
            let conceptoTexto = "Pago de préstamo - \(prestamo.persona)"
            let desgloseFinal: DesgloseBilletes? = metodo == .efectivo ? desglose : nil

            let transaccion = Transaccion(
                fecha: fecha,
                hora: fecha,
                concepto: conceptoTexto,
                monto: montoPago.valor,
                tipo: tipo,
                categoria: "Préstamos",
                metodo: metodo,
                desglose: desgloseFinal
            )

            try await loanService.registrarPagoConTransaccion(
                prestamoId: prestamo.id!,
                montoPago: montoPago.valor,
                transaccion: transaccion,
                transactionRepo: transactionRepo,
                inventoryRepo: inventoryRepo
            )

            guardado = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
