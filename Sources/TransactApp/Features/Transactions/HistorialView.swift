import SwiftUI
import DesignSystem
import Models

struct HistorialView: View {
    @ObservedObject var viewModel: HistorialViewModel
    @State private var transaccionEditar: Transaccion?

    var body: some View {
        VStack(spacing: 0) {
            filtros

            resumenFiltros

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
        .navigationTitle(LocalizableKey.historialTitulo.localized())
        .searchable(text: $viewModel.texto, prompt: LocalizableKey.historialBuscar.localized())
        .onChange(of: viewModel.texto) { _ in scheduleReload() }
        .onChange(of: viewModel.tipoFiltro) { _ in scheduleReload() }
        .onChange(of: viewModel.categoriaFiltro) { _ in scheduleReload() }
        .onChange(of: viewModel.mesFiltro) { _ in scheduleReload() }
        .onChange(of: viewModel.usarFiltroMes) { _ in scheduleReload() }
        .onChange(of: viewModel.orden) { _ in scheduleReload() }
        .task { await viewModel.cargar() }
        .refreshable { await viewModel.cargar() }
        .sheet(item: $transaccionEditar) { tx in
            NavigationStack {
                EditorTransaccionWrapper(transaccion: tx) {
                    transaccionEditar = nil
                    Task { await viewModel.cargar() }
                }
                .id(tx.id)
            }
        }
    }

    private var filtros: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack(spacing: TemaEspaciado.m) {
                Picker(LocalizableKey.commonTipo.localized(), selection: $viewModel.tipoFiltro) {
                    Text(LocalizableKey.historialTodos.localized()).tag(TipoFiltro.todos)
                    Text(LocalizableKey.historialFiltroIngresos.localized()).tag(TipoFiltro.tipo(.ingreso))
                    Text(LocalizableKey.historialFiltroGastos.localized()).tag(TipoFiltro.tipo(.gasto))
                }
                .pickerStyle(.segmented)

                Menu {
                    Button(LocalizableKey.historialCategoriaTodas.localized()) { viewModel.categoriaFiltro = nil }
                    Divider()
                    ForEach(viewModel.categorias, id: \.self) { cat in
                        Button(cat) { viewModel.categoriaFiltro = cat }
                    }
                } label: {
                    HStack(spacing: TemaEspaciado.xs) {
                        Image(systemName: "tag")
                        Text(viewModel.categoriaFiltro ?? LocalizableKey.historialCategoria.localized())
                            .lineLimit(1)
                    }
                    .padding(.horizontal, TemaEspaciado.m)
                    .padding(.vertical, TemaEspaciado.s)
                    .background(
                        RoundedRectangle(cornerRadius: TemaRadio.s)
                            .fill(AppColor.surface1)
                    )
                    .foregroundColor(AppColor.text)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Button(LocalizableKey.historialOrdenRecientes.localized()) { viewModel.orden = .fechaDesc }
                    Button(LocalizableKey.historialOrdenAntiguas.localized()) { viewModel.orden = .fechaAsc }
                    Button(LocalizableKey.historialOrdenMayor.localized()) { viewModel.orden = .montoDesc }
                    Button(LocalizableKey.historialOrdenMenor.localized()) { viewModel.orden = .montoAsc }
                } label: {
                    HStack(spacing: TemaEspaciado.xs) {
                        Image(systemName: "arrow.up.arrow.down")
                        Text(ordenTexto)
                    }
                    .padding(.horizontal, TemaEspaciado.m)
                    .padding(.vertical, TemaEspaciado.s)
                    .background(
                        RoundedRectangle(cornerRadius: TemaRadio.s)
                            .fill(AppColor.surface1)
                    )
                    .foregroundColor(AppColor.text)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Toggle(LocalizableKey.historialFiltroMes.localized(), isOn: $viewModel.usarFiltroMes)
                    .toggleStyle(.switch)
                    .foregroundColor(AppColor.subtext1)
                if viewModel.usarFiltroMes {
                    DatePicker("", selection: $viewModel.mesFiltro, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Button {
                    viewModel.limpiarFiltros()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .foregroundColor(AppColor.subtext0)
            }
        }
        .padding(TemaEspaciado.l)
    }

    private var ordenTexto: String {
        switch viewModel.orden {
        case .fechaDesc: return LocalizableKey.historialOrdenRecientes.localized()
        case .fechaAsc: return LocalizableKey.historialOrdenAntiguas.localized()
        case .montoDesc: return LocalizableKey.historialOrdenMayor.localized()
        case .montoAsc: return LocalizableKey.historialOrdenMenor.localized()
        }
    }

    private var resumenFiltros: some View {
        HStack(spacing: TemaEspaciado.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizableKey.historialConteoTransacciones.localized(viewModel.transacciones.count))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
            Spacer()
            HStack(spacing: TemaEspaciado.l) {
                VStack(alignment: .trailing) {
                    Text(LocalizableKey.dashboardIngresos.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    MontoLabel(monto: viewModel.totalIngresos, tamanio: .chico, colorearSegunSigno: false)
                }
                VStack(alignment: .trailing) {
                    Text(LocalizableKey.dashboardGastos.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    MontoLabel(monto: viewModel.totalGastos, tamanio: .chico, colorearSegunSigno: false)
                }
                VStack(alignment: .trailing) {
                    Text(LocalizableKey.dashboardNeto.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    MontoLabel(monto: viewModel.neto, tamanio: .chico)
                }
            }
        }
        .padding(.horizontal, TemaEspaciado.xl)
        .padding(.bottom, TemaEspaciado.s)
    }

    private var lista: some View {
        ScrollView {
            LazyVStack(spacing: TemaEspaciado.s) {
                if viewModel.cargando && viewModel.transacciones.isEmpty {
                    ProgressView()
                        .tint(AppColor.accent)
                        .padding(TemaEspaciado.xxl)
                } else if viewModel.transacciones.isEmpty {
                    Text(LocalizableKey.historialVacio.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                        .padding(TemaEspaciado.xxl)
                } else {
                    ForEach(viewModel.transacciones) { tx in
                        FilaTransaccionView(transaccion: tx)
                            .onTapGesture { transaccionEditar = tx }
                            .contextMenu {
                                Button(LocalizableKey.commonEditar.localized()) { transaccionEditar = tx }
                                Button(LocalizableKey.commonEliminar.localized(), role: .destructive) {
                                    Task { await viewModel.eliminar(tx) }
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, TemaEspaciado.xl)
            .padding(.bottom, TemaEspaciado.xxl)
        }
    }

    private func scheduleReload() {
        Task { await viewModel.cargar() }
    }
}

private struct FilaTransaccionView: View {
    let transaccion: Transaccion

    var body: some View {
        HStack(spacing: TemaEspaciado.m) {
            Image(systemName: icono)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: TemaRadio.s)
                        .fill(colorFondo)
                )
                .foregroundColor(colorIcono)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaccion.concepto)
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                    .lineLimit(1)
                HStack(spacing: TemaEspaciado.s) {
                    Text(transaccion.categoria)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                    Text("·")
                        .foregroundColor(AppColor.subtext0)
                    Text(transaccion.metodo.titulo)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(diaMes)
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                Text(anio)
                    .font(.caption2.monospaced())
                    .foregroundColor(AppColor.subtext0)
            }
            .frame(minWidth: 60, alignment: .trailing)
            .help(LocalizableKey.historialFechaCompleta.localized(fechaCompleta))

            MontoLabel(monto: transaccion.montoFirmado, tamanio: .mediano)
        }
        .padding(TemaEspaciado.m)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.m)
                .fill(AppColor.surface0)
        )
    }

    private var diaMes: String {
        Localizador.fechaCorta(transaccion.fecha, formato: "d MMM")
    }

    private var anio: String {
        let f = DateFormatter()
        f.locale = Localizador.localeActual
        f.dateFormat = "yyyy"
        return f.string(from: transaccion.fecha)
    }

    private var fechaCompleta: String {
        Localizador.fechaCompleta(transaccion.fecha)
    }

    private var icono: String {
        switch transaccion.tipo {
        case .ingreso:
            return transaccion.metodo == .efectivo ? "arrow.down.circle.fill" : "creditcard.fill"
        case .gasto:
            return transaccion.metodo == .efectivo ? "arrow.up.circle.fill" : "creditcard"
        }
    }

    private var colorFondo: Color {
        switch transaccion.tipo {
        case .ingreso: return AppColor.green.opacity(0.15)
        case .gasto: return AppColor.red.opacity(0.15)
        }
    }

    private var colorIcono: Color {
        switch transaccion.tipo {
        case .ingreso: return AppColor.green
        case .gasto: return AppColor.red
        }
    }
}

struct EditorTransaccionWrapper: View {
    let transaccion: Transaccion
    let onCerrar: () -> Void
    @EnvironmentObject var environment: AppEnvironment

    var body: some View {
        FormularioTransaccionHost(
            service: environment.transactionService,
            transactionRepo: environment.transactions,
            transaccionInicial: transaccion,
            onCerrar: onCerrar
        )
    }
}
