import AppKit
import Models

@MainActor
final class UpdateCoordinator: ObservableObject, @unchecked Sendable {
    @Published var estado: Estado = .inactivo
    @Published var progreso: Double = 0

    enum Estado: Equatable {
        case inactivo
        case verificando
        case actualizado
        case disponible(Version, String, String)
        case descargando
        case listo(URL)
        case error(String)

        static func == (lhs: Estado, rhs: Estado) -> Bool {
            switch (lhs, rhs) {
            case (.inactivo, .inactivo), (.verificando, .verificando),
                (.actualizado, .actualizado), (.descargando, .descargando): true
            case let (.disponible(a, _, _), .disponible(b, _, _)): a == b
            case let (.listo(a), .listo(b)): a == b
            case let (.error(a), .error(b)): a == b
            default: false
            }
        }
    }

    private let versionActual: Version
    private let feedURL: URL

    init() {
        let versionString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        self.versionActual = (try? Version(versionString)) ?? Version()

        let feedString = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
            ?? "https://whosmayk.github.io/TransactApp/appcast.json"
        guard let url = URL(string: feedString) else {
            fatalError("SUFeedURL contains an invalid URL: \(feedString)")
        }
        self.feedURL = url
    }

    func check() async {
        estado = .verificando
        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            let appcast = try JSONDecoder().decode(Appcast.self, from: data)
            guard let remota = try? Version(appcast.latestVersion) else {
                estado = .error("Formato de versión inválido en el feed")
                return
            }

            guard remota > versionActual else {
                estado = .actualizado
                return
            }

            estado = .disponible(remota, appcast.downloadUrl, appcast.releaseNotes)
            mostrarAlerta(remota: remota, urlDescarga: appcast.downloadUrl, notas: appcast.releaseNotes)
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    func checkSilencioso() async {
        guard estado == .inactivo else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: feedURL)
            let appcast = try JSONDecoder().decode(Appcast.self, from: data)
            guard let remota = try? Version(appcast.latestVersion) else { return }
            guard remota > versionActual else { return }
            estado = .disponible(remota, appcast.downloadUrl, appcast.releaseNotes)
            mostrarAlerta(remota: remota, urlDescarga: appcast.downloadUrl, notas: appcast.releaseNotes)
        } catch {
            estado = .error(error.localizedDescription)
        }
    }

    func instalar(archivoZip: URL) async {
        estado = .descargando
        progreso = 0

        do {
            let destino = try await UpdateInstaller.descargarYExtraer(zip: archivoZip)
            estado = .listo(destino)
            try UpdateInstaller.reemplazarYRelanzar(nuevaApp: destino)
        } catch {
            estado = .error(error.localizedDescription)
            let alert = NSAlert()
            alert.messageText = LocalizableKey.updatesErrorInstalar.localized()
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: LocalizableKey.commonAceptar.localized())
            alert.runModal()
        }
    }

    private func mostrarAlerta(remota: Version, urlDescarga: String, notas: String) {
        let alert = NSAlert()
        alert.messageText = LocalizableKey.updatesDisponible.localized(remota.mayor, remota.minor, remota.patch)
        alert.informativeText = notas.isEmpty
            ? LocalizableKey.updatesDisponibleDesc.localized()
            : notas
        alert.addButton(withTitle: LocalizableKey.updatesDescargar.localized())
        alert.addButton(withTitle: LocalizableKey.commonCancelar.localized())

        let respuesta = alert.runModal()
        if respuesta == .alertFirstButtonReturn {
            guard let url = URL(string: urlDescarga) else {
                estado = .error("URL inválida: \(urlDescarga)")
                return
            }
            Task { await instalar(archivoZip: url) }
        }
    }
}

struct Appcast: Codable {
    let latestVersion: String
    let downloadUrl: String
    let releaseNotes: String
    let minimumOSVersion: String

    var latestVersionParsed: Version? { try? Version(latestVersion) }
}
