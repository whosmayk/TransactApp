import SwiftUI
import DesignSystem
import Models
import Services

struct GestionPrestamosView: View {
    @ObservedObject var viewModel: GestionPrestamosViewModel
    @State private var prestamoEnEdicion: Prestamo?
    @State private var prestamoEnPago: Prestamo?
    @State private var mostrarNuevo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            resumen

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
                    .padding(.horizontal, TemaEspaciado.xl)
            }

            lista
        }
        .background(AppColor.base)
        .navigationTitle(LocalizableKey.prestamoTitulo.localized())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    mostrarNuevo = true
                } label: {
                    Label(LocalizableKey.prestamoNuevo.localized(), systemImage: "plus")
                }
            }
        }
        .task { await viewModel.cargar() }
        .refreshable { await viewModel.cargar() }
        .sheet(isPresented: $mostrarNuevo) {
            NavigationStack {
                FormularioPrestamoHost(
                    service: viewModel.service,
                    onCerrar: {
                        mostrarNuevo = false
                        Task { await viewModel.cargar() }
                    }
                )
            }
            .frame(minWidth: 560, minHeight: 600)
        }
        .sheet(item: $prestamoEnEdicion) { prestamo in
            NavigationStack {
                FormularioPrestamoHost(
                    service: viewModel.service,
                    prestamoInicial: prestamo,
                    onCerrar: {
                        prestamoEnEdicion = nil
                        Task { await viewModel.cargar() }
                    }
                )
            }
            .frame(minWidth: 560, minHeight: 600)
        }
        .sheet(item: $prestamoEnPago) { prestamo in
            RegistrarPagoPrestamoHost(
                prestamo: prestamo,
                transactionService: viewModel.transactionService,
                transactionRepo: viewModel.transactionRepo,
                inventoryRepo: viewModel.inventoryRepo,
                loanService: viewModel.service,
                onCerrar: {
                    prestamoEnPago = nil
                    Task { await viewModel.cargar() }
                }
            )
        }
    }

    private var resumen: some View {
        HStack(spacing: TemaEspaciado.m) {
            CardView {
                VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(AppColor.green)
                        Text(TipoPrestamo.meDeben.titulo)
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.subtext1)
                    }
                    MontoLabel(
                        monto: viewModel.pendienteMeDeben,
                        tamanio: .mediano,
                        colorearSegunSigno: false
                    )
                    Text(LocalizableKey.prestamoCantidad.localized(viewModel.prestamosMeDeben.count))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            }
            CardView {
                VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(AppColor.red)
                        Text(TipoPrestamo.debo.titulo)
                            .font(Tipografia.subtitulo())
                            .foregroundColor(AppColor.subtext1)
                    }
                    MontoLabel(
                        monto: viewModel.pendienteDebo,
                        tamanio: .mediano,
                        colorearSegunSigno: false
                    )
                    Text(LocalizableKey.prestamoCantidad.localized(viewModel.prestamosDebo.count))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            }
        }
        .padding(TemaEspaciado.l)
    }

    private var lista: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: TemaEspaciado.l) {
                seccion(
                    titulo: TipoPrestamo.meDeben.titulo,
                    icono: "arrow.down.circle.fill",
                    colorIcono: AppColor.green,
                    prestamos: viewModel.prestamosMeDeben
                )
                seccion(
                    titulo: TipoPrestamo.debo.titulo,
                    icono: "arrow.up.circle.fill",
                    colorIcono: AppColor.red,
                    prestamos: viewModel.prestamosDebo
                )
            }
            .padding(.horizontal, TemaEspaciado.xl)
            .padding(.bottom, TemaEspaciado.xxl)
        }
    }

    @ViewBuilder
    private func seccion(
        titulo: String,
        icono: String,
        colorIcono: Color,
        prestamos: [Prestamo]
    ) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack(spacing: TemaEspaciado.s) {
                Image(systemName: icono)
                    .foregroundColor(colorIcono)
                Text(titulo)
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
            }

            if prestamos.isEmpty {
                Text(LocalizableKey.prestamoSinPrestamos.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
                    .padding(TemaEspaciado.m)
            } else {
                ForEach(prestamos) { p in
                    FilaPrestamoView(prestamo: p)
                        .onTapGesture { prestamoEnEdicion = p }
                        .contextMenu {
                            Button(LocalizableKey.commonEditar.localized()) { prestamoEnEdicion = p }
                            Button("Registrar pago", systemImage: "dollarsign.circle") { prestamoEnPago = p }
                            Divider()
                            Button(LocalizableKey.commonEliminar.localized(), role: .destructive) {
                                Task { await viewModel.eliminar(p) }
                            }
                        }
                }
            }
        }
    }
}

private struct FilaPrestamoView: View {
    let prestamo: Prestamo

    var body: some View {
        HStack(alignment: .top, spacing: TemaEspaciado.m) {
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text(prestamo.persona)
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                if !prestamo.concepto.isEmpty {
                    Text(prestamo.concepto)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                        .lineLimit(1)
                }
                HStack(spacing: TemaEspaciado.s) {
                    Text(fecha)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    if prestamo.afectaBalance {
                        Text("·")
                            .foregroundColor(AppColor.subtext0)
                        Text(LocalizableKey.prestamoAfecta.localized())
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.peach)
                    }
                }
                if prestamo.montoPagado > 0 {
                    ProgressView(value: prestamo.porcentajePagado)
                        .tint(AppColor.green)
                        .frame(maxWidth: 200)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                MontoLabel(monto: prestamo.monto, tamanio: .mediano, colorearSegunSigno: false)
                if prestamo.montoPagado > 0 && prestamo.montoPagado < prestamo.monto {
                    HStack(spacing: TemaEspaciado.xs) {
                        Text(LocalizableKey.prestamoPendiente.localized() + ":")
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                        MontoLabel(
                            monto: prestamo.saldoPendiente,
                            tamanio: .chico,
                            colorearSegunSigno: false
                        )
                    }
                } else if prestamo.estaPagado {
                    Text(LocalizableKey.prestamoPagado.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.green)
                }
            }
        }
        .padding(TemaEspaciado.m)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.m)
                .fill(AppColor.surface0)
        )
    }

    private var fecha: String {
        Localizador.fechaCorta(prestamo.fecha, formato: "d MMM yyyy")
    }
}
