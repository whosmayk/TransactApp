import SwiftUI

public struct DangerButton: View {
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
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TemaEspaciado.m)
            .padding(.horizontal, TemaEspaciado.l)
            .background(
                RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                    .fill(habilitado ? AppColor.red : AppColor.overlay0)
            )
            .foregroundStyle(habilitado ? AppColor.base : AppColor.subtext0)
        }
        .buttonStyle(.plain)
        .disabled(!habilitado)
    }
}
