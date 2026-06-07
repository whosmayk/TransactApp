import AppKit

enum UpdateInstaller {
    static func descargarYExtraer(zip url: URL) async throws -> URL {
        let fm = FileManager.default
        let dirTemp = fm.temporaryDirectory.appendingPathComponent("TransactApp-Update", isDirectory: true)
        try? fm.removeItem(at: dirTemp)
        try fm.createDirectory(at: dirTemp, withIntermediateDirectories: true)

        let zipLocal = dirTemp.appendingPathComponent("update.zip")

        let session = URLSession(configuration: .ephemeral)
        let (data, _) = try await session.data(from: url)

        try data.write(to: zipLocal, options: .atomic)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        proc.arguments = ["-x", "-k", zipLocal.path, dirTemp.path]
        try proc.run()
        proc.waitUntilExit()

        guard proc.terminationStatus == 0 else {
            throw UpdateError.extraccionFallida
        }

        try fm.removeItem(at: zipLocal)

        let contents = try fm.contentsOfDirectory(at: dirTemp, includingPropertiesForKeys: nil)
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.appNoEncontrada
        }

        let destino = dirTemp.appendingPathComponent("TransactApp-Updated.app")
        if fm.fileExists(atPath: destino.path) {
            try fm.removeItem(at: destino)
        }
        try fm.moveItem(at: app, to: destino)

        return destino
    }

    static func reemplazarYRelanzar(nuevaApp: URL) throws {
        let fm = FileManager.default
        let appActual = Bundle.main.bundleURL
        let scriptURL = fm.temporaryDirectory.appendingPathComponent("transactapp-instalar.sh")

        let script = """
        #!/bin/bash
        sleep 2
        rm -rf "\(appActual.path)"
        cp -R "\(nuevaApp.path)" "\(appActual.path)"
        open "\(appActual.path)"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [scriptURL.path]
        try proc.run()

        NSApplication.shared.terminate(nil)
    }
}

enum UpdateError: LocalizedError {
    case extraccionFallida
    case appNoEncontrada

    var errorDescription: String? {
        switch self {
        case .extraccionFallida: "No se pudo extraer el archivo de actualización"
        case .appNoEncontrada: "No se encontró la app dentro del archivo de actualización"
        }
    }
}
