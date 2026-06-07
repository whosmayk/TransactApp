import SwiftUI

public struct GhostButton: View {
    let titulo: String
    let accion: () -> Void
    var icono: String?
    var habilitado: Bool = true

    public init(_ titulo: String, icono: String? = nil, habilitado: Bool = true, accion: @escaping () -> Void) {
        self.titulo = titulo
        self.accion = accion
        self.icono = icono
        self.habilitado = habilitado
    }

    public var body: some View {
        Button(action: accion) {
            HStack(spacing: TemaEspaciado.s) {
                if let icono {
                    Image(systemName: icono)
                }
                Text(titulo)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TemaEspaciado.m)
            .padding(.horizontal, TemaEspaciado.l)
            .background(
                RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                    .fill(AppColor.surface1)
            )
            .foregroundStyle(habilitado ? AppColor.text : AppColor.subtext0)
            .overlay(
                RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                    .strokeBorder(AppColor.overlay0, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!habilitado)
    }
}
