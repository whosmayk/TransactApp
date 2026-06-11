import SwiftUI
import DesignSystem
import Models
import Services

struct DepositoTarjetaView: View {
    @ObservedObject var viewModel: DepositoTarjetaViewModel
    let onCerrar: () -> Void

    var body: some View {
        VStack(spacing: TemaEspaciado.l) {
            HStack {
                VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                    Text("Depósito a tarjeta")
                        .font(Tipografia.titulo())
                        .foregroundColor(AppColor.text)
                    Text("Retira efectivo y abona a tu tarjeta en un solo paso")
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                }
                Spacer()
                Button {
                    onCerrar()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColor.subtext0)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }

            if let error = viewModel.error {
                Text(error)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.red)
                    .padding(TemaEspaciado.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: TemaRadio.s)
                            .fill(AppColor.red.opacity(0.15))
                    )
            }

            ScrollView {
                VStack(spacing: TemaEspaciado.m) {
                    VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                        Text(LocalizableKey.commonCategoria.localized())
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.subtext1)
                        TextField("", text: $viewModel.concepto)
                            .textFieldStyle(.plain)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.text)
                            .padding(TemaEspaciado.m)
                            .background(
                                RoundedRectangle(cornerRadius: TemaRadio.s)
                                    .fill(AppColor.surface0)
                            )
                    }

                    CampoMontoField(
                        titulo: "Monto a depositar",
                        placeholder: "0",
                        texto: $viewModel.monto.texto
                    )

                    HStack(spacing: TemaEspaciado.m) {
                        Label("Se descuenta de:", systemImage: "arrow.down.circle")
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.subtext1)
                        HStack(spacing: TemaEspaciado.xs) {
                            Image(systemName: "banknote.fill")
                                .foregroundColor(AppColor.green)
                            Text("Efectivo")
                                .font(Tipografia.subtitulo())
                                .foregroundColor(AppColor.text)
                        }
                        Image(systemName: "arrow.right")
                            .foregroundColor(AppColor.subtext0)
                        HStack(spacing: TemaEspaciado.xs) {
                            Image(systemName: "creditcard.fill")
                                .foregroundColor(AppColor.sapphire)
                            Text("Tarjeta")
                                .font(Tipografia.subtitulo())
                                .foregroundColor(AppColor.text)
                        }
                        Spacer()
                    }
                    .padding(TemaEspaciado.m)
                    .background(
                        RoundedRectangle(cornerRadius: TemaRadio.m)
                            .fill(AppColor.surface0)
                    )

                    if viewModel.montoValido {
                        DesgloseBilletesEditorView(
                            desglose: $viewModel.desglose,
                            montoObjetivo: viewModel.monto.valor,
                            onAutoDesglose: { viewModel.autocompletarDesglose() }
                        )
                    }
                }
            }

            HStack(spacing: TemaEspaciado.m) {
                GhostButton("Cancelar", icono: "xmark") { onCerrar() }
                PrimaryButton(
                    "Depositar",
                    icono: "arrow.right.circle",
                    habilitado: viewModel.esValido && !viewModel.guardando
                ) {
                    Task { await viewModel.depositar() }
                }
            }
        }
        .padding(TemaEspaciado.l)
        .background(AppColor.base)
        .frame(width: 520, height: 580)
    }
}

struct DepositoTarjetaHost: View {
    @StateObject private var viewModel: DepositoTarjetaViewModel
    let onCerrar: () -> Void

    init(
        transactionService: TransactionService,
        onCerrar: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: DepositoTarjetaViewModel(
                transactionService: transactionService
            )
        )
        self.onCerrar = onCerrar
    }

    var body: some View {
        DepositoTarjetaView(viewModel: viewModel, onCerrar: onCerrar)
    }
}
