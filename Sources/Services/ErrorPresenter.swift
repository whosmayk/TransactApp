import AppKit
import Foundation
import Models

@MainActor
public final class ErrorPresenter: ObservableObject {
    public static let shared = ErrorPresenter()

    @Published public private(set) var lastPresented: AppError?
    @Published public private(set) var historial: [AppError] = []

    public let maxHistorial: Int

    public var presentadorAlerta: ((NSAlert, NSWindow?) -> Void)?

    public init(maxHistorial: Int = 50) {
        self.maxHistorial = maxHistorial
    }

    public func present(_ error: AppError, en ventana: NSWindow? = nil) {
        lastPresented = error
        agregarAlHistorial(error)

        let alerta = construirAlerta(error)
        presentarAlerta(alerta, en: ventana)
    }

    public func present(
        _ error: any LocalizedError,
        category: AppError.Category = .critical,
        source: AppError.ErrorSource = .personalizada,
        suggestion: String? = nil,
        en ventana: NSWindow? = nil
    ) {
        let appError = AppError.from(
            error,
            category: category,
            source: source,
            suggestion: suggestion
        )
        present(appError, en: ventana)
    }

    public func present(
        category: AppError.Category,
        title: String,
        message: String,
        suggestion: String? = nil,
        source: AppError.ErrorSource = .personalizada,
        en ventana: NSWindow? = nil
    ) {
        let error = AppError.personalizada(
            category: category,
            title: title,
            message: message,
            suggestion: suggestion,
            source: source
        )
        present(error, en: ventana)
    }

    public func limpiarUltimo() {
        lastPresented = nil
    }

    public func limpiarHistorial() {
        historial.removeAll()
    }

    private func construirAlerta(_ error: AppError) -> NSAlert {
        let alerta = NSAlert()
        alerta.messageText = error.title
        alerta.informativeText = construirCuerpoInformativo(error)
        alerta.alertStyle = estiloParaCategoria(error.category)

        switch error.category {
        case .critical:
            alerta.addButton(withTitle: "Aceptar")
        case .warning:
            alerta.addButton(withTitle: "Aceptar")
            alerta.addButton(withTitle: "Ignorar")
        case .info:
            alerta.addButton(withTitle: "Entendido")
        }

        return alerta
    }

    private func construirCuerpoInformativo(_ error: AppError) -> String {
        if let sugerencia = error.suggestion, !sugerencia.isEmpty {
            return "\(error.message)\n\nSugerencia: \(sugerencia)"
        }
        return error.message
    }

    private func estiloParaCategoria(_ categoria: AppError.Category) -> NSAlert.Style {
        switch categoria {
        case .info:
            return .informational
        case .warning:
            return .warning
        case .critical:
            return .critical
        }
    }

    private func presentarAlerta(_ alerta: NSAlert, en ventana: NSWindow?) {
        if let hook = presentadorAlerta {
            hook(alerta, ventana)
            return
        }
        let ventanaDestino = ventana ?? ventanaPreferida()

        if let ventana = ventanaDestino, ventana.isVisible {
            alerta.beginSheetModal(for: ventana, completionHandler: nil)
        } else {
            alerta.runModal()
        }
    }

    private func ventanaPreferida() -> NSWindow? {
        if let key = NSApp.keyWindow, key.isVisible {
            return key
        }
        if let main = NSApp.mainWindow, main.isVisible {
            return main
        }
        return NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain })
    }

    private func agregarAlHistorial(_ error: AppError) {
        historial.append(error)
        if historial.count > maxHistorial {
            historial.removeFirst(historial.count - maxHistorial)
        }
    }
}
