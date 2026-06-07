import SwiftUI
import DesignSystem
import Models

struct SaldoInicialView: View {
    @ObservedObject var viewModel: SaldoInicialViewModel
    let onCompletado: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.xl) {
                encabezado

                seccionSaldos

                seccionInventario

                if let error = viewModel.error {
                    Text(error)
                        .font(Tipografia.cuerpo())
                        .foregroundStyle(AppColor.red)
                        .padding(TemaEspaciado.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.red.opacity(0.15))
                        )
                }

                PrimaryButton(
                    viewModel.guardando ? LocalizableKey.commonGuardando.localized() : LocalizableKey.commonAceptar.localized(),
                    icono: "checkmark",
                    habilitado: viewModel.esValido && !viewModel.guardando
                ) {
                    Task { await aceptar() }
                }
            }
            .padding(TemaEspaciado.xxl)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.base)
        .onChange(of: viewModel.completado) { nuevo in
            if nuevo { onCompletado() }
        }
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(LocalizableKey.onboardingTitulo.localized())
                .font(Tipografia.titulo())
                .foregroundStyle(AppColor.text)
            Text(LocalizableKey.onboardingSubtitulo.localized())
                .font(Tipografia.cuerpo())
                .foregroundStyle(AppColor.subtext1)
        }
    }

    private var seccionSaldos: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.l) {
                Text(LocalizableKey.onboardingSaldos.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundStyle(AppColor.text)

                CampoMontoField(
                    titulo: LocalizableKey.onboardingEfectivo.localized(),
                    placeholder: LocalizableKey.montoPlaceholder.localized(),
                    texto: $viewModel.efectivo.texto
                )

                CampoMontoField(
                    titulo: LocalizableKey.onboardingTarjeta.localized(),
                    placeholder: LocalizableKey.montoPlaceholder.localized(),
                    texto: $viewModel.tarjeta.texto
                )
            }
        }
    }

    private var seccionInventario: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.m) {
                HStack {
                    Text(LocalizableKey.onboardingInventario.localized())
                        .font(Tipografia.subtitulo())
                        .foregroundStyle(AppColor.text)
                    Spacer()
                    MontoLabel(monto: viewModel.subtotalInventario, tamanio: .mediano, colorearSegunSigno: false)
                }
                Text(LocalizableKey.onboardingInventarioDesc.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundStyle(AppColor.subtext1)

                let columnas = [GridItem(.flexible(), spacing: TemaEspaciado.s),
                                GridItem(.flexible(), spacing: TemaEspaciado.s),
                                GridItem(.flexible(), spacing: TemaEspaciado.s),
                                GridItem(.flexible(), spacing: TemaEspaciado.s)]
                LazyVGrid(columns: columnas, spacing: TemaEspaciado.s) {
                    ForEach(Inventario.denominaciones, id: \.self) { denom in
                        DenominacionCelda(
                            denominacion: denom,
                            cantidad: Binding(
                                get: { viewModel.cantidades[denom] ?? 0 },
                                set: { viewModel.actualizarCantidad($0, de: denom) }
                            )
                        )
                    }
                }
            }
        }
    }

    private func aceptar() async {
        await viewModel.aceptar()
    }
}

private struct DenominacionCelda: View {
    let denominacion: Int
    @Binding var cantidad: Int
    @FocusState private var enfocado: Bool

    var body: some View {
        VStack(spacing: TemaEspaciado.xs) {
            Text("\(LocalizableKey.montoPrefijo.localized())\(denominacion)")
                .font(Tipografia.subtitulo())
                .foregroundStyle(AppColor.text)

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
                        .foregroundStyle(AppColor.text)
                }
                .buttonStyle(.plain)

                TextField("0", value: $cantidad, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(Tipografia.montoMediano())
                    .foregroundStyle(AppColor.text)
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
                        .foregroundStyle(AppColor.text)
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
