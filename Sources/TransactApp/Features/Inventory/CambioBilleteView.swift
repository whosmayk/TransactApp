import SwiftUI
import DesignSystem
import Models

public struct CambioBilleteView: View {
    @ObservedObject var viewModel: CambioBilleteViewModel
    let onCerrar: () -> Void

    public init(viewModel: CambioBilleteViewModel, onCerrar: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCerrar = onCerrar
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(AppColor.surface0)
            HStack(alignment: .top, spacing: TemaEspaciado.s) {
                seccionOrigen
                seccionDestino
            }
            .padding(.horizontal, TemaEspaciado.l)
            .padding(.top, TemaEspaciado.s)
            Divider().background(AppColor.surface0)
                .padding(.top, TemaEspaciado.s)
            VStack(spacing: TemaEspaciado.s) {
                resumen
                TextField(
                    LocalizableKey.cambioBilleteConcepto.localized(),
                    text: $viewModel.concepto
                )
                .textFieldStyle(.roundedBorder)
                if let error = viewModel.error {
                    Text(error)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.red)
                        .padding(TemaEspaciado.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: TemaRadio.s)
                                .fill(AppColor.red.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, TemaEspaciado.l)
            .padding(.top, TemaEspaciado.s)
            .padding(.bottom, TemaEspaciado.s)
            Divider().background(AppColor.surface0)
            footer
        }
        .background(AppColor.base)
        .task { await viewModel.cargar() }
    }

    private var header: some View {
        HStack(spacing: TemaEspaciado.s) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColor.sapphire)
            Text(LocalizableKey.dashboardCambiarBilletes.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Spacer()
        }
        .padding(.horizontal, TemaEspaciado.l)
        .padding(.vertical, TemaEspaciado.s)
    }

    private var seccionOrigen: some View {
        seccionBilletes(
            titulo: LocalizableKey.cambioBilleteQuitar.localized(),
            color: AppColor.red,
            cantidadPara: { viewModel.origen[$0] ?? 0 },
            setCantidad: { viewModel.setOrigen($0, denom: $1) },
            maxPara: { viewModel.inventarioDe($0) }
        )
    }

    private var seccionDestino: some View {
        seccionBilletes(
            titulo: LocalizableKey.cambioBilleteAgregar.localized(),
            color: AppColor.green,
            cantidadPara: { viewModel.destino[$0] ?? 0 },
            setCantidad: { viewModel.setDestino($0, denom: $1) },
            maxPara: { _ in 999 }
        )
    }

    @ViewBuilder
    private func seccionBilletes(
        titulo: String,
        color: Color,
        cantidadPara: @escaping (Int) -> Int,
        setCantidad: @escaping (Int, Int) -> Void,
        maxPara: @escaping (Int) -> Int?
    ) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(titulo)
                .font(Tipografia.subtitulo())
                .foregroundColor(color)
            VStack(spacing: 4) {
                ForEach(Inventario.denominaciones, id: \.self) { denom in
                    filaDenominacion(
                        denom: denom,
                        color: color,
                        cantidadPara: cantidadPara,
                        setCantidad: setCantidad,
                        maxPara: maxPara
                    )
                }
            }
        }
    }

    private func filaDenominacion(
        denom: Int,
        color: Color,
        cantidadPara: @escaping (Int) -> Int,
        setCantidad: @escaping (Int, Int) -> Void,
        maxPara: @escaping (Int) -> Int?
    ) -> some View {
        let maxCantidad: Int = maxPara(denom) ?? 999
        let cantidadActual: Int = cantidadPara(denom)
        let inventarioDisponible: Int? = maxPara(denom)
        let muestraDisponible = (inventarioDisponible ?? 999) < 999
        return HStack(spacing: TemaEspaciado.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text("$\(denom)")
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                if muestraDisponible, let inv = inventarioDisponible {
                    Text(LocalizableKey.cambioBilleteDisponible.localized(inv))
                        .font(.system(size: 9))
                        .foregroundColor(AppColor.subtext0)
                } else {
                    Color.clear.frame(height: 11)
                }
            }
            .frame(width: 70, alignment: .leading)
            Spacer()
            Button {
                setCantidad(cantidadActual - 1, denom)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .disabled(cantidadActual <= 0)
            .foregroundColor(AppColor.subtext0)
            Text("\(cantidadActual)")
                .font(Tipografia.montoMediano())
                .foregroundColor(color)
                .frame(minWidth: 24, alignment: .center)
            Button {
                setCantidad(cantidadActual + 1, denom)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .disabled(cantidadActual >= maxCantidad)
            .foregroundColor(AppColor.subtext0)
        }
        .padding(.horizontal, TemaEspaciado.s)
        .padding(.vertical, TemaEspaciado.xs)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.s)
                .fill(AppColor.surface0)
        )
    }

    private var resumen: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack {
                Text(LocalizableKey.cambioBilleteTotalQuitado.localized(Localizador.moneda(viewModel.totalOrigen)))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.red)
                Spacer()
                Text(LocalizableKey.cambioBilleteTotalAgregado.localized(Localizador.moneda(viewModel.totalDestino)))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.green)
            }
            HStack {
                Image(systemName: viewModel.balanceValido
                      ? "checkmark.circle.fill"
                      : "exclamationmark.triangle.fill")
                    .foregroundColor(viewModel.balanceValido
                                     ? AppColor.green
                                     : AppColor.peach)
                Text(viewModel.balanceValido
                     ? LocalizableKey.cambioBilleteBalanceOk.localized()
                     : LocalizableKey.cambioBilleteBalanceError.localized())
                    .font(Tipografia.subtitulo())
                    .foregroundColor(viewModel.balanceValido
                                     ? AppColor.green
                                     : AppColor.peach)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TemaEspaciado.s)
            .background(
                RoundedRectangle(cornerRadius: TemaRadio.s)
                    .fill(viewModel.balanceValido
                          ? AppColor.green.opacity(0.15)
                          : AppColor.peach.opacity(0.15))
            )
        }
    }

    private var footer: some View {
        HStack(spacing: TemaEspaciado.m) {
            GhostButton(LocalizableKey.commonCancelar.localized()) {
                onCerrar()
            }
            PrimaryButton(
                LocalizableKey.cambioBilleteAplicar.localized(),
                icono: "checkmark",
                habilitado: viewModel.balanceValido && viewModel.hayMovimientos && !viewModel.aplicando
            ) {
                Task { await viewModel.aplicar() }
            }
        }
        .padding(.horizontal, TemaEspaciado.l)
        .padding(.vertical, TemaEspaciado.s)
    }
}
