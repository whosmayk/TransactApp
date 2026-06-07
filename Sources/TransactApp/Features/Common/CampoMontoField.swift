import SwiftUI
import DesignSystem
import Models

public struct CampoMontoField: View {
    let titulo: String?
    let placeholder: String
    @Binding var texto: String
    @FocusState private var enfocado: Bool

    public init(
        titulo: String? = nil,
        placeholder: String = LocalizableKey.montoPlaceholder.localized(),
        texto: Binding<String>
    ) {
        self.titulo = titulo
        self.placeholder = placeholder
        self._texto = texto
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
            if let titulo {
                Text(titulo)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext1)
            }
            HStack(spacing: TemaEspaciado.s) {
                Text(LocalizableKey.montoPrefijo.localized())
                    .font(Tipografia.montoMediano())
                    .foregroundColor(AppColor.subtext0)
                TextField(placeholder, text: $texto)
                    .textFieldStyle(.plain)
                    .font(Tipografia.montoMediano())
                    .foregroundColor(AppColor.text)
                    .tint(AppColor.accent)
            }
            .padding(.horizontal, TemaEspaciado.m)
            .padding(.vertical, TemaEspaciado.s)
            .background(
                RoundedRectangle(cornerRadius: TemaRadio.s)
                    .fill(AppColor.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TemaRadio.s)
                    .strokeBorder(enfocado ? AppColor.accent : .clear, lineWidth: 1)
            )
            .focused($enfocado)
        }
    }
}
