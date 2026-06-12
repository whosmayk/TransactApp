import Foundation
import SwiftUI
import DesignSystem
import Models
import Database
import Services

@MainActor
final class HistorialViewModel: ObservableObject {
    @Published var transacciones: [Transaccion] = []
    @Published var cargando: Bool = false
    @Published var error: String?
    private var necesitaRecarga = false
    @Published var texto: String = ""
    @Published var tipoFiltro: TipoFiltro = .todos
    @Published var categoriaFiltro: String? = nil
    @Published var mesFiltro: Date = Date()
    @Published var usarFiltroMes: Bool = false
    @Published var orden: OrdenTransaccion = .fechaDesc
    @Published var categorias: [String] = []

    let service: TransactionService
    private let transactionRepo: any TransactionRepository

    init(service: TransactionService, transactionRepo: any TransactionRepository) {
        self.service = service
        self.transactionRepo = transactionRepo
    }

    var totalIngresos: Decimal {
        transacciones.filter { $0.tipo == .ingreso }.reduce(into: Decimal(0)) { $0 += $1.monto }
    }

    var totalGastos: Decimal {
        transacciones.filter { $0.tipo == .gasto }.reduce(into: Decimal(0)) { $0 += $1.monto }
    }

    var neto: Decimal { totalIngresos - totalGastos }

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
            async let listaTask = transactionRepo.listarFiltrado(
                mes: usarFiltroMes ? mesFiltro : nil,
                tipo: tipoFiltro == .todos ? nil : tipoFiltro.tipo,
                categoria: categoriaFiltro,
                texto: texto.isEmpty ? nil : texto,
                limite: nil,
                orden: orden
            )
            async let categoriasTask = transactionRepo.categoriasDistintas()
            let (lista, cats) = try await (listaTask, categoriasTask)
            self.transacciones = lista
            self.categorias = cats
        } catch {
            self.error = error.localizedDescription
        }
    }

    func eliminar(_ transaccion: Transaccion) async {
        do {
            try await service.eliminar(transaccion)
            await cargar()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func limpiarFiltros() {
        texto = ""
        tipoFiltro = .todos
        categoriaFiltro = nil
        usarFiltroMes = false
        Task { await cargar() }
    }
}

enum TipoFiltro: Hashable {
    case todos
    case tipo(TipoTransaccion)

    var tipo: TipoTransaccion? {
        if case .tipo(let t) = self { return t }
        return nil
    }

    var etiqueta: String {
        switch self {
        case .todos: return "Todos"
        case .tipo(let t): return t.rawValue
        }
    }
}
