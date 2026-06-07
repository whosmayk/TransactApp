import SwiftUI
import Models

public struct MontoLabel: View {
    let monto: Decimal
    let tamanio: Tamanio
    let colorearSegunSigno: Bool

    public enum Tamanio {
        case chico, mediano, grande
    }

    public init(monto: Decimal, tamanio: Tamanio = .mediano, colorearSegunSigno: Bool = true) {
        self.monto = monto
        self.tamanio = tamanio
        self.colorearSegunSigno = colorearSegunSigno
    }

    public var body: some View {
        Text(formatear())
            .font(fuente)
            .foregroundStyle(color)
            .monospacedDigit()
    }

    private var fuente: Font {
        switch tamanio {
        case .chico: return .system(size: 13, weight: .medium, design: .monospaced)
        case .mediano: return Tipografia.montoMediano()
        case .grande: return Tipografia.montoGrande()
        }
    }

    private var color: Color {
        guard colorearSegunSigno else { return AppColor.text }
        return monto < 0 ? AppColor.red : AppColor.green
    }

    private func formatear() -> String {
        Localizador.moneda(monto)
    }
}
