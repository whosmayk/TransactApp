import SwiftUI
import AppKit
import Foundation

enum IconError: Error {
    case argumentosInvalidos
    case renderFallido
    case escrituraFallida(String)
}

@main
struct IconRenderer {
    static func main() async throws {
        let args = CommandLine.arguments
        guard args.count == 2 else {
            FileHandle.standardError.write(Data("Uso: render-icon.swift <ruta-png-salida>\n".utf8))
            throw IconError.argumentosInvalidos
        }
        let destino = URL(fileURLWithPath: args[1])

        let view = AppIconView()
            .frame(width: 1024, height: 1024)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = true
        renderer.colorMode = ColorRenderingMode.nonLinear

        guard let nsImage: NSImage = renderer.nsImage,
              let tiff: Data = nsImage.tiffRepresentation,
              let bitmap: NSBitmapImageRep = NSBitmapImageRep(data: tiff),
              let png: Data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            FileHandle.standardError.write(Data("Falló el render del icono.\n".utf8))
            throw IconError.renderFallido
        }

        do {
            try png.write(to: destino)
        } catch {
            FileHandle.standardError.write(Data("No pude escribir \(destino.path): \(error.localizedDescription)\n".utf8))
            throw IconError.escrituraFallida(destino.path)
        }

        print("OK Icono renderizado: \(destino.path) (\(png.count) bytes)")
    }
}
