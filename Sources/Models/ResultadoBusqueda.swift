import Foundation

public enum ResultadoBusquedaCategoria: String, Sendable, CaseIterable {
    case transaccion
    case prestamo
    case suscripcion

    public var titulo: String {
        switch self {
        case .transaccion: return "Transacciones"
        case .prestamo: return "Préstamos"
        case .suscripcion: return "Suscripciones"
        }
    }

    public var icono: String {
        switch self {
        case .transaccion: return "list.bullet.rectangle"
        case .prestamo: return "arrow.left.arrow.right.circle"
        case .suscripcion: return "repeat.circle"
        }
    }
}

public enum ResultadoBusqueda: Identifiable, Equatable, Sendable {
    case transaccion(Transaccion)
    case prestamo(Prestamo)
    case suscripcion(Suscripcion)

    public var id: String {
        switch self {
        case .transaccion(let tx):
            return "tx:\(tx.id ?? -1)"
        case .prestamo(let pr):
            return "pr:\(pr.id ?? -1)"
        case .suscripcion(let su):
            return "su:\(su.id ?? -1)"
        }
    }

    public var categoria: ResultadoBusquedaCategoria {
        switch self {
        case .transaccion: return .transaccion
        case .prestamo: return .prestamo
        case .suscripcion: return .suscripcion
        }
    }

    public var titulo: String {
        switch self {
        case .transaccion(let tx):
            return tx.concepto.isEmpty ? "Sin concepto" : tx.concepto
        case .prestamo(let pr):
            return pr.persona.isEmpty ? "Sin nombre" : pr.persona
        case .suscripcion(let su):
            return su.concepto.isEmpty ? "Sin nombre" : su.concepto
        }
    }

    public var subtitulo: String {
        switch self {
        case .transaccion(let tx):
            var partes: [String] = []
            if !tx.categoria.isEmpty { partes.append(tx.categoria) }
            partes.append(FormatoFechaResultado.formatear(tx.fecha))
            return partes.joined(separator: " · ")
        case .prestamo(let pr):
            var partes: [String] = []
            if !pr.concepto.isEmpty { partes.append(pr.concepto) }
            partes.append(pr.tipo.rawValue)
            if pr.afectaBalance { partes.append("afecta balance") }
            partes.append(FormatoFechaResultado.formatear(pr.fecha))
            return partes.joined(separator: " · ")
        case .suscripcion(let su):
            return su.categoria.isEmpty ? "Sin categoría" : su.categoria
        }
    }

    public var monto: Decimal {
        switch self {
        case .transaccion(let tx): return tx.monto
        case .prestamo(let pr): return pr.monto
        case .suscripcion(let su): return su.monto
        }
    }

    public var tipoParaColor: TipoTransaccion {
        switch self {
        case .transaccion(let tx): return tx.tipo
        case .prestamo(let pr):
            return pr.tipo == .meDeben ? .ingreso : .gasto
        case .suscripcion(let su): return su.tipo
        }
    }

    public var transaccion: Transaccion? {
        if case .transaccion(let t) = self { return t }
        return nil
    }

    public var prestamo: Prestamo? {
        if case .prestamo(let p) = self { return p }
        return nil
    }

    public var suscripcion: Suscripcion? {
        if case .suscripcion(let s) = self { return s }
        return nil
    }
}

private enum FormatoFechaResultado {
    static let fecha: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func formatear(_ date: Date) -> String { fecha.string(from: date) }
}
