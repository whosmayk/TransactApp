import SwiftUI
import Testing
@testable import DesignSystem
import Models

@MainActor
@Suite("MontoLabel render")
struct MontoLabelRenderTests {

    @Test("MontoLabel con monto negativo renderizado tiene color rojo dominante")
    func montoNegativoRenderEsRojo() throws {
        let label = MontoLabel(monto: -800, tamanio: .mediano)
            .frame(width: 200, height: 50)
        let renderer = ImageRenderer(content: label)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else {
            Issue.record("No se pudo renderizar el MontoLabel")
            return
        }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rojo = 0
        var verde = 0
        var textPixels = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            let a = pixels[i + 3]
            if a < 128 { continue }
            if r > 100 && g < r && b < r { rojo += 1; textPixels += 1 }
            else if g > 100 && r < g && b < g { verde += 1; textPixels += 1 }
        }
        print("Pixels text rojo: \(rojo), verde: \(verde), total: \(textPixels)")
        #expect(rojo > 0, "Debe haber píxeles rojos en el render de un monto negativo")
        #expect(rojo > verde, "El rojo debe dominar sobre el verde en un monto negativo")
    }

    @Test("MontoLabel con monto positivo renderizado tiene color verde dominante")
    func montoPositivoRenderEsVerde() throws {
        let label = MontoLabel(monto: 500, tamanio: .mediano)
            .frame(width: 200, height: 50)
        let renderer = ImageRenderer(content: label)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else {
            Issue.record("No se pudo renderizar el MontoLabel")
            return
        }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rojo = 0
        var verde = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = pixels[i]
            let g = pixels[i + 1]
            let b = pixels[i + 2]
            let a = pixels[i + 3]
            if a < 128 { continue }
            if r > 100 && g < r && b < r { rojo += 1 }
            else if g > 100 && r < g && b < g { verde += 1 }
        }
        print("Pixels text rojo: \(rojo), verde: \(verde)")
        #expect(verde > 0, "Debe haber píxeles verdes en el render de un monto positivo")
        #expect(verde > rojo, "El verde debe dominar sobre el rojo en un monto positivo")
    }
}
