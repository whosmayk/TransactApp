import Foundation
import SwiftUI
import DesignSystem
import Models
import Services

@MainActor
final class DepositoTarjetaViewModel: ObservableObject {
    @Published var concepto: String = "Depósito a tarjeta"
    @Published var monto: CampoMonto = CampoMonto()
    @Published var desglose: DesgloseBilletes = DesgloseBilletes()
    @Published var error: String?
    @Published var guardando: Bool = false
    @Published var guardado: Bool = false

    private let transactionService: TransactionService

    init(transactionService: TransactionService) {
        self.transactionService = transactionService
    }

    var montoValido: Bool { monto.valor > 0 }

    var conceptoValido: Bool { !concepto.trimmingCharacters(in: .whitespaces).isEmpty }

    var desgloseValido: Bool {
        let diff = abs((monto.valor - desglose.subtotal) as Decimal)
        return diff < Decimal(0.01)
    }

    var esValido: Bool {
        montoValido && conceptoValido && desgloseValido
    }

    var mensajeError: String? {
        if !montoValido { return "El monto debe ser mayor a 0." }
        if !conceptoValido { return "El concepto no puede estar vacío." }
        if !desgloseValido { return "La suma del desglose debe coincidir con el monto." }
        return nil
    }

    func autocompletarDesglose() {
        guard monto.valor > 0 else { return }
        desglose = DesgloseBilletes.autoDesglose(monto: monto.valor)
    }

    func depositar() async {
        guard !guardando else { return }
        guard esValido else {
            error = mensajeError
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }

        do {
            try await transactionService.crearDeposito(
                monto: monto.valor,
                concepto: concepto.trimmingCharacters(in: .whitespaces),
                desglose: desglose
            )
            guardado = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
