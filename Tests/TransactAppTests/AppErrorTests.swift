import Foundation
import AppKit
import Testing
@testable import Models
@testable import Services
import Database

@Suite("AppError")
struct AppErrorTests {

    @Test("factory critical construye AppError con categoría .critical")
    func factoryCritical() {
        let typed = ErrorSimulacion.montoInvalido("100")
        let appError = AppError.critical(typed, source: .simulador)
        #expect(appError.category == .critical)
        #expect(appError.source == .simulador)
        #expect(appError.message == "100")
        #expect(appError.title == LocalizableKey.errorAceptarTitulo.localized())
    }

    @Test("factory warning construye AppError con categoría .warning")
    func factoryWarning() {
        let typed = BackupError.archivoNoExiste
        let appError = AppError.warning(typed, source: .backup)
        #expect(appError.category == .warning)
        #expect(appError.source == .backup)
        #expect(appError.title == LocalizableKey.errorWarningTitulo.localized())
    }

    @Test("factory info construye AppError con categoría .info")
    func factoryInfo() {
        let typed = ErrorSimulacion.campoVacio("concepto")
        let appError = AppError.info(typed, source: .simulador)
        #expect(appError.category == .info)
        #expect(appError.source == .simulador)
        #expect(appError.title == LocalizableKey.errorInfoTitulo.localized())
    }

    @Test("factory from con sugerencia preserva la sugerencia")
    func factoryFromConSugerencia() {
        let typed = AppDatabaseError.filaNoEncontrada
        let appError = AppError.from(
            typed,
            category: .critical,
            source: .database,
            suggestion: "Recarga el formulario."
        )
        #expect(appError.suggestion == "Recarga el formulario.")
    }

    @Test("errorDescription incluye título, mensaje y sugerencia si existe")
    func errorDescriptionCompleto() {
        let appError = AppError.personalizada(
            category: .critical,
            title: "Hola",
            message: "Mundo",
            suggestion: "Sugerencia X",
            source: .personalizada
        )
        let desc = appError.errorDescription
        #expect(desc?.contains("Hola") == true)
        #expect(desc?.contains("Mundo") == true)
        #expect(desc?.contains("Sugerencia X") == true)
    }

    @Test("errorDescription omite la sección de sugerencia si es nil")
    func errorDescriptionSinSugerencia() {
        let appError = AppError.personalizada(
            category: .info,
            title: "T",
            message: "M",
            suggestion: nil,
            source: .sistema
        )
        let desc = appError.errorDescription
        #expect(desc?.contains("Sugerencia") == false)
        #expect(desc?.contains("T") == true)
        #expect(desc?.contains("M") == true)
    }

    @Test("AppError es Equatable")
    func equatable() {
        let id = UUID()
        let a = AppError(
            id: id,
            category: .critical,
            title: "x",
            message: "y",
            suggestion: "z",
            source: .database
        )
        let b = AppError(
            id: id,
            category: .critical,
            title: "x",
            message: "y",
            suggestion: "z",
            source: .database
        )
        let c = AppError(
            id: UUID(),
            category: .critical,
            title: "x",
            message: "y",
            suggestion: "z",
            source: .database
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test("AppError es Identifiable con id estable")
    func identifiable() {
        let appError = AppError.personalizada(
            category: .info,
            title: "x",
            message: "y",
            source: .sistema
        )
        let id1 = appError.id
        #expect(appError.id == id1)
    }

    @Test("ErrorSimulacion.montoInvalido se convierte con mensaje correcto")
    func errorSimulacionMontoInvalido() {
        let err = AppError.from(
            ErrorSimulacion.montoInvalido("0.00"),
            category: .critical,
            source: .simulador
        )
        #expect(err.message == "0.00")
        #expect(err.source == .simulador)
    }

    @Test("BackupError.archivoVacio se convierte a AppError")
    func backupErrorArchivoVacio() {
        let err = AppError.critical(
            BackupError.archivoVacio,
            source: .backup
        )
        #expect(err.category == .critical)
        #expect(err.source == .backup)
        #expect(err.message.isEmpty == false)
    }

    @Test("AppDatabaseError.filaNoEncontrada se convierte a AppError")
    func databaseErrorFilaNoEncontrada() {
        let err = AppError.from(
            AppDatabaseError.filaNoEncontrada,
            category: .warning,
            source: .database
        )
        #expect(err.category == .warning)
        #expect(err.source == .database)
    }

    @Test("Categoria default es critical")
    func categoriaDefault() {
        let typed = ErrorSimulacion.contextoInsuficiente("test")
        let err = AppError.from(typed, source: .simulador)
        #expect(err.category == .critical)
    }

    @Test("ErrorSource default es .personalizada")
    func errorSourceDefault() {
        let typed = BackupError.archivoNoExiste
        let err = AppError.from(typed, category: .info)
        #expect(err.source == .personalizada)
    }
}

@Suite("ErrorPresenter")
struct ErrorPresenterTests {

    @Test("present(_:) agrega a historial y actualiza lastPresented")
    @MainActor
    func presentAgregaAHistorial() {
        let presenter = ErrorPresenter()
        presenter.presentadorAlerta = { _, _ in }
        let err = AppError.personalizada(
            category: .critical,
            title: "Test",
            message: "Mensaje",
            source: .sistema
        )
        presenter.present(err)
        #expect(presenter.lastPresented?.id == err.id)
        #expect(presenter.historial.count == 1)
        #expect(presenter.historial.first?.id == err.id)
    }

    @Test("present(_:) múltiples veces mantiene orden FIFO en historial")
    @MainActor
    func presentMultipleOrdenaFIFO() {
        let presenter = ErrorPresenter()
        presenter.presentadorAlerta = { _, _ in }
        let e1 = AppError.personalizada(category: .info, title: "1", message: "1", source: .sistema)
        let e2 = AppError.personalizada(category: .warning, title: "2", message: "2", source: .sistema)
        let e3 = AppError.personalizada(category: .critical, title: "3", message: "3", source: .sistema)
        presenter.present(e1)
        presenter.present(e2)
        presenter.present(e3)
        #expect(presenter.historial.map(\.title) == ["1", "2", "3"])
        #expect(presenter.lastPresented?.title == "3")
    }

    @Test("present(_:) respeta maxHistorial")
    @MainActor
    func presentRespetaMaxHistorial() {
        let presenter = ErrorPresenter(maxHistorial: 3)
        presenter.presentadorAlerta = { _, _ in }
        for i in 1...5 {
            let err = AppError.personalizada(
                category: .info,
                title: "\(i)",
                message: "\(i)",
                source: .sistema
            )
            presenter.present(err)
        }
        #expect(presenter.historial.count == 3)
        #expect(presenter.historial.map(\.title) == ["3", "4", "5"])
    }

    @Test("present(error:category:source:) convierte LocalizedError a AppError")
    @MainActor
    func presentConvierteLocalizedError() {
        let presenter = ErrorPresenter()
        presenter.presentadorAlerta = { _, _ in }
        let typed = ErrorSimulacion.montoInvalido("x")
        presenter.present(typed, category: .warning, source: .simulador)
        #expect(presenter.lastPresented?.category == .warning)
        #expect(presenter.lastPresented?.source == .simulador)
        #expect(presenter.lastPresented?.message == "x")
    }

    @Test("limpiarUltimo() pone lastPresented a nil")
    @MainActor
    func limpiarUltimo() {
        let presenter = ErrorPresenter()
        presenter.presentadorAlerta = { _, _ in }
        let err = AppError.personalizada(category: .info, title: "x", message: "y", source: .sistema)
        presenter.present(err)
        #expect(presenter.lastPresented != nil)
        presenter.limpiarUltimo()
        #expect(presenter.lastPresented == nil)
        #expect(presenter.historial.count == 1)
    }

    @Test("limpiarHistorial() vacía el historial pero conserva lastPresented")
    @MainActor
    func limpiarHistorial() {
        let presenter = ErrorPresenter()
        presenter.presentadorAlerta = { _, _ in }
        presenter.present(AppError.personalizada(category: .info, title: "a", message: "a", source: .sistema))
        presenter.present(AppError.personalizada(category: .info, title: "b", message: "b", source: .sistema))
        #expect(presenter.historial.count == 2)
        presenter.limpiarHistorial()
        #expect(presenter.historial.isEmpty)
        #expect(presenter.lastPresented != nil)
    }

    @Test("ErrorPresenter.shared es singleton")
    @MainActor
    func sharedEsSingleton() {
        let a = ErrorPresenter.shared
        let b = ErrorPresenter.shared
        #expect(a === b)
    }

    @Test("presentadorAlerta hook se llama en lugar de runModal")
    @MainActor
    func hookSeLlamaEnLugarDeRunModal() {
        let presenter = ErrorPresenter()
        var capturado: NSAlert?
        presenter.presentadorAlerta = { alerta, _ in capturado = alerta }
        let err = AppError.personalizada(category: .critical, title: "Hook", message: "test", source: .sistema)
        presenter.present(err)
        #expect(capturado?.messageText == "Hook")
    }
}
