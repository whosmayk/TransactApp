import SwiftUI

public struct CardView<Content: View>: View {
    let contenido: () -> Content

    public init(@ViewBuilder contenido: @escaping () -> Content) {
        self.contenido = contenido
    }

    public var body: some View {
        contenido()
            .padding(TemaEspaciado.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                    .fill(AppGradiente.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                    .strokeBorder(AppColor.surface1, lineWidth: 1)
            )
    }
}
