import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class FormularioSuscripcionViewModel: ObservableObject {
    enum Modo: Equatable {
        case nuevo
        case editar(original: Suscripcion)
    }

    @Published var concepto: String
    @Published var monto: CampoMonto
    @Published var categoria: String
    @Published var frecuencia: FrecuenciaSuscripcion
    @Published var tipo: TipoTransaccion
    @Published var fechaInicio: Date
    @Published var duracionMesesTexto: String
    @Published var metodoPago: MetodoPago
    @Published var activa: Bool
    @Published var notas: String
    @Published var error: String?
    @Published var guardando: Bool = false
    @Published var guardado: Bool = false

    let modo: Modo
    private let service: SubscriptionService

    init(service: SubscriptionService, suscripcionInicial: Suscripcion? = nil) {
        self.service = service
        if let inicial = suscripcionInicial {
            self.modo = .editar(original: inicial)
            self.concepto = inicial.concepto
            self.monto = CampoMonto(
                texto: FormatoMontoHelper.formatear(inicial.monto),
                valor: inicial.monto
            )
            self.categoria = inicial.categoria
            self.frecuencia = inicial.frecuencia
            self.tipo = inicial.tipo
            self.fechaInicio = inicial.fechaInicio
            self.duracionMesesTexto = inicial.duracionMeses.flatMap { $0 > 0 ? String($0) : nil } ?? ""
            self.metodoPago = inicial.metodoPago
            self.activa = inicial.activa
            self.notas = inicial.notas ?? ""
        } else {
            self.modo = .nuevo
            self.concepto = ""
            self.monto = CampoMonto()
            self.categoria = ""
            self.frecuencia = .mensual
            self.tipo = .gasto
            let ahora = Date()
            self.fechaInicio = ahora
            self.duracionMesesTexto = ""
            self.metodoPago = .tarjeta
            self.activa = true
            self.notas = ""
        }
    }

    var proximoCobro: Date {
        Suscripcion.calcularProximoCobro(
            desde: fechaInicio,
            frecuencia: frecuencia
        )
    }

    var conceptoValido: Bool {
        !concepto.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var montoValido: Bool { monto.valor > 0 }

    var duracionValida: Bool {
        if duracionMesesTexto.isEmpty { return true }
        if let n = Int(duracionMesesTexto), n > 0 { return true }
        return false
    }

    var esValido: Bool {
        conceptoValido && montoValido && duracionValida
    }

    var mensajeError: String? {
        if !conceptoValido { return "Indica el concepto de la suscripción." }
        if !montoValido { return "El monto debe ser mayor a 0." }
        if !duracionValida { return "La duración debe estar vacía o ser un entero positivo." }
        return nil
    }

    func duracionEntero() -> Int? {
        if duracionMesesTexto.isEmpty { return nil }
        if let n = Int(duracionMesesTexto), n > 0 { return n }
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
            let proximo = proximoCobro
            switch modo {
            case .nuevo:
                let nueva = Suscripcion(
                    id: nil,
                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                    monto: monto.valor,
                    categoria: categoria.trimmingCharacters(in: .whitespaces),
                    frecuencia: frecuencia,
                    tipo: tipo,
                    fechaInicio: fechaInicio,
                    proximoCobro: proximo,
                    notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas,
                    duracionMeses: duracionEntero(),
                    metodoPago: metodoPago,
                    activa: activa,
                    notificado: false
                )
                _ = try await service.crear(nueva)
            case .editar(let original):
                let actualizada = Suscripcion(
                    id: original.id,
                    concepto: concepto.trimmingCharacters(in: .whitespaces),
                    monto: monto.valor,
                    categoria: categoria.trimmingCharacters(in: .whitespaces),
                    frecuencia: frecuencia,
                    tipo: tipo,
                    fechaInicio: fechaInicio,
                    proximoCobro: original.activa ? proximo : original.proximoCobro,
                    notas: notas.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notas,
                    duracionMeses: duracionEntero(),
                    metodoPago: metodoPago,
                    activa: activa,
                    notificado: original.notificado
                )
                _ = try await service.actualizar(actualizada)
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
