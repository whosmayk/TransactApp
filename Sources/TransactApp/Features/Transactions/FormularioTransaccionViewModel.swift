import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class FormularioTransaccionViewModel: ObservableObject {
    enum Modo: Equatable {
        case nuevo
        case editar(original: Transaccion)
    }

    @Published var tipo: TipoTransaccion = .gasto
    @Published var fecha: Date
    @Published var hora: Date
    @Published var concepto: String = ""
    @Published var monto: CampoMonto = CampoMonto()
    @Published var categoria: String = ""
    @Published var metodo: MetodoPago = .efectivo
    @Published var desglose: DesgloseBilletes = DesgloseBilletes()
    @Published var categoriasConocidas: [String] = []
    @Published var error: String?
    @Published var guardando: Bool = false
    @Published var guardado: Bool = false

    let modo: Modo
    private let service: TransactionService
    private let transactionRepo: any TransactionRepository

    init(
        service: TransactionService,
        transactionRepo: any TransactionRepository,
        transaccionInicial: Transaccion? = nil
    ) {
        self.service = service
        self.transactionRepo = transactionRepo
        let ahora = Date()
        if let inicial = transaccionInicial {
            self.modo = .editar(original: inicial)
            self.tipo = inicial.tipo
            self.fecha = inicial.fecha
            self.hora = inicial.hora
            self.concepto = inicial.concepto
            self.monto = CampoMonto(
                texto: FormatoMontoHelper.formatear(inicial.monto),
                valor: inicial.monto
            )
            self.categoria = inicial.categoria
            self.metodo = inicial.metodo
            self.desglose = inicial.desglose ?? DesgloseBilletes()
        } else {
            self.modo = .nuevo
            self.fecha = ahora
            self.hora = ahora
        }
    }

    var esEfectivo: Bool { metodo == .efectivo }

    var montoValido: Bool { monto.valor > 0 }

    var conceptoValido: Bool { !concepto.trimmingCharacters(in: .whitespaces).isEmpty }

    var desgloseValido: Bool {
        if !esEfectivo { return true }
        let diff = abs((monto.valor - desglose.subtotal) as Decimal)
        return diff < Decimal(0.01)
    }

    var esValido: Bool {
        montoValido && conceptoValido && desgloseValido
    }

    var mensajeError: String? {
        if !montoValido { return "El monto debe ser mayor a 0." }
        if !conceptoValido { return "El concepto no puede estar vacío." }
        if esEfectivo && !desgloseValido { return "La suma del desglose debe coincidir con el monto." }
        return nil
    }

    func cargarCategorias() async {
        do {
            categoriasConocidas = try await transactionRepo.categoriasDistintas()
        } catch {
            categoriasConocidas = []
        }
    }

    func autocompletarDesglose() {
        guard monto.valor > 0 else { return }
        desglose = DesgloseBilletes.autoDesglose(monto: monto.valor)
    }

    func guardar() async {
        guard !guardando else { return }
        guard esValido else {
            error = mensajeError
            return
        }
        guardando = true
        error = nil
        defer { guardando = false }

        do {
            let desgloseFinal: DesgloseBilletes? = esEfectivo ? desglose : nil
            switch modo {
            case .nuevo:
                let nueva = Transaccion(
                    id: nil,
                    fecha: fecha,
                    hora: hora,
                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                    monto: monto.valor,
                    tipo: tipo,
                    categoria: categoria.trimmingCharacters(in: .whitespaces),
                    metodo: metodo,
                    desglose: desgloseFinal
                )
                _ = try await service.crear(nueva)
            case .editar(let original):
                let actualizada = Transaccion(
                    id: original.id,
                    fecha: fecha,
                    hora: hora,
                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                    monto: monto.valor,
                    tipo: tipo,
                    categoria: categoria.trimmingCharacters(in: .whitespaces),
                    metodo: metodo,
                    desglose: desgloseFinal
                )
                _ = try await service.actualizar(actualizada, original: original)
            }
            guardado = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func eliminar() async {
        guard case .editar(let original) = modo else { return }
        guard !guardando else { return }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await service.eliminar(original)
            guardado = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

enum FormatoMontoHelper {
    static func formatear(_ valor: Decimal) -> String {
        if valor == 0 { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "es_MX")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: valor)) ?? "\(valor)"
    }
}
