import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class FormularioPrestamoViewModel: ObservableObject {
    enum Modo: Equatable {
        case nuevo
        case editar(original: Prestamo)
    }

    @Published var persona: String
    @Published var concepto: String
    @Published var monto: CampoMonto
    @Published var tipo: TipoPrestamo
    @Published var fecha: Date
    @Published var afectaBalance: Bool
    @Published var montoPagado: CampoMonto
    @Published var notas: String
    @Published var error: String?
    @Published var guardando: Bool = false
    @Published var guardado: Bool = false

    let modo: Modo
    private let service: LoanService

    init(service: LoanService, prestamoInicial: Prestamo? = nil) {
        self.service = service
        if let inicial = prestamoInicial {
            self.modo = .editar(original: inicial)
            self.persona = inicial.persona
            self.concepto = inicial.concepto
            self.monto = CampoMonto(
                texto: FormatoMontoHelper.formatear(inicial.monto),
                valor: inicial.monto
            )
            self.tipo = inicial.tipo
            self.fecha = inicial.fecha
            self.afectaBalance = inicial.afectaBalance
            self.montoPagado = CampoMonto(
                texto: FormatoMontoHelper.formatear(inicial.montoPagado),
                valor: inicial.montoPagado
            )
            self.notas = inicial.notas ?? ""
        } else {
            self.modo = .nuevo
            self.persona = ""
            self.concepto = ""
            self.monto = CampoMonto()
            self.tipo = .meDeben
            self.fecha = Date()
            self.afectaBalance = true
            self.montoPagado = CampoMonto()
            self.notas = ""
        }
    }

    var personaValida: Bool { !persona.trimmingCharacters(in: .whitespaces).isEmpty }
    var montoValido: Bool { monto.valor > 0 }
    var pagosValidos: Bool { montoPagado.valor >= 0 && montoPagado.valor <= monto.valor }
    var afectarBalanceDisponible: Bool { tipo == .debo }

    var esValido: Bool {
        personaValida && montoValido && pagosValidos
    }

    var mensajeError: String? {
        if !personaValida { return LocalizableKey.prestamoErrorPersona.localized() }
        if !montoValido { return LocalizableKey.prestamoErrorMonto.localized() }
        if !pagosValidos { return LocalizableKey.prestamoErrorPagado.localized() }
        return nil
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
            let afectaFinal = tipo == .debo ? afectaBalance : false
            switch modo {
            case .nuevo:
                let nuevo = Prestamo(
                    id: nil,
                    persona: persona.trimmingCharacters(in: .whitespaces),
                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                    monto: monto.valor,
                    tipo: tipo,
                    fecha: fecha,
                    afectaBalance: afectaFinal,
                    montoPagado: montoPagado.valor,
                    notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas
                )
                _ = try await service.crear(nuevo)
            case .editar(let original):
                let actualizado = Prestamo(
                    id: original.id,
                    persona: persona.trimmingCharacters(in: .whitespaces),
                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                    monto: monto.valor,
                    tipo: tipo,
                    fecha: fecha,
                    afectaBalance: afectaFinal,
                    montoPagado: montoPagado.valor,
                    notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas
                )
                _ = try await service.actualizar(actualizado)
            }
            guardado = true
        } catch {
            self.error = error.localizedDescription
        }
    }

    func eliminar() async {
        guard case .editar(let original) = modo, let id = original.id else { return }
        guard !guardando else { return }
        guardando = true
        error = nil
        defer { guardando = false }
        do {
            try await service.eliminar(id: id)
            guardado = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}
