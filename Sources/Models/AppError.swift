import Foundation

public struct AppError: LocalizedError, Identifiable, Equatable {
    public enum Category: Equatable {
        case info
        case warning
        case critical
    }

    public let id: UUID
    public let category: Category
    public let title: String
    public let message: String
    public let suggestion: String?
    public let source: ErrorSource

    public enum ErrorSource: Equatable {
        case database
        case backup
        case importacion
        case exportacion
        case simulador
        case sistema
        case personalizada
    }

    public init(
        id: UUID = UUID(),
        category: Category,
        title: String,
        message: String,
        suggestion: String? = nil,
        source: ErrorSource = .personalizada
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.suggestion = suggestion
        self.source = source
    }

    public var errorDescription: String? {
        if let suggestion, !suggestion.isEmpty {
            return "\(title) — \(message)\n\nSugerencia: \(suggestion)"
        }
        return "\(title) — \(message)"
    }

    public var mensajeCorto: String {
        message
    }

    public static func critical(
        _ error: any LocalizedError,
        source: ErrorSource,
        suggestion: String? = nil
    ) -> AppError {
        from(error, category: .critical, source: source, suggestion: suggestion)
    }

    public static func warning(
        _ error: any LocalizedError,
        source: ErrorSource,
        suggestion: String? = nil
    ) -> AppError {
        from(error, category: .warning, source: source, suggestion: suggestion)
    }

    public static func info(
        _ error: any LocalizedError,
        source: ErrorSource,
        suggestion: String? = nil
    ) -> AppError {
        from(error, category: .info, source: source, suggestion: suggestion)
    }

    public static func from(
        _ error: any LocalizedError,
        category: Category = .critical,
        source: ErrorSource = .personalizada,
        suggestion: String? = nil
    ) -> AppError {
        let tituloInferido = inferirTitulo(error: error, category: category)
        let mensaje = error.errorDescription ?? String(describing: error)
        return AppError(
            category: category,
            title: tituloInferido,
            message: mensaje,
            suggestion: suggestion,
            source: source
        )
    }

    public static func personalizada(
        category: Category,
        title: String,
        message: String,
        suggestion: String? = nil,
        source: ErrorSource = .personalizada
    ) -> AppError {
        AppError(
            category: category,
            title: title,
            message: message,
            suggestion: suggestion,
            source: source
        )
    }

    private static func inferirTitulo(
        error: any LocalizedError,
        category: Category
    ) -> String {
        switch category {
        case .critical:
            return "Algo salió mal"
        case .warning:
            return "Atención"
        case .info:
            return "Información"
        }
    }
}
