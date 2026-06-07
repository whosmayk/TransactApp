import SwiftUI
import DesignSystem
import Models

struct DesgloseBilletesEditorView: View {
    @Binding var desglose: DesgloseBilletes
    let montoObjetivo: Decimal
    let onAutoDesglose: () -> Void

    private let columnas = [
        GridItem(.flexible(), spacing: TemaEspaciado.s),
        GridItem(.flexible(), spacing: TemaEspaciado.s)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.m) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Desglose de billetes")
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.text)
                    Text("Suma igual al monto del gasto")
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(LocalizableKey.desgloseSubtotal.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                    MontoLabel(monto: desglose.subtotal, tamanio: .mediano, colorearSegunSigno: false)
                    if !estaCuadrado {
                        Text(LocalizableKey.desgloseFaltan.localized(Localizador.moneda(montoObjetivo - desglose.subtotal)))
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.red)
                    }
                }
            }

            LazyVGrid(columns: columnas, spacing: TemaEspaciado.s) {
                ForEach(DesgloseBilletes.denominaciones, id: \.self) { denom in
                    DenominacionFila(
                        denominacion: denom,
                        cantidad: Binding(
                            get: { desglose.cantidad(de: denom) },
                            set: { desglose.setCantidad($0, de: denom) }
                        )
                    )
                }
            }

            GhostButton(LocalizableKey.desgloseAuto.localized(), icono: "wand.and.stars", habilitado: montoObjetivo > 0) {
                onAutoDesglose()
            }
        }
    }

    private var estaCuadrado: Bool {
        montoObjetivo == desglose.subtotal
    }
}

private struct DenominacionFila: View {
    let denominacion: Int
    @Binding var cantidad: Int
    @FocusState private var enfocado: Bool

    var body: some View {
        HStack(spacing: TemaEspaciado.s) {
            Text("\(LocalizableKey.montoPrefijo.localized())\(denominacion)")
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
                .frame(width: 60, alignment: .leading)

            HStack(spacing: TemaEspaciado.xs) {
                Button {
                    cantidad = max(0, cantidad - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.surface2)
                        )
                        .foregroundColor(AppColor.text)
                }
                .buttonStyle(.plain)

                TextField("0", value: $cantidad, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(Tipografia.montoMediano())
                    .foregroundColor(AppColor.text)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .background(
                        RoundedRectangle(cornerRadius: TemaRadio.s)
                            .fill(AppColor.surface1)
                    )
                    .focused($enfocado)

                Button {
                    cantidad += 1
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.surface2)
                        )
                        .foregroundColor(AppColor.text)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(TemaEspaciado.s)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.s)
                .fill(AppColor.surface0)
        )
    }
}
