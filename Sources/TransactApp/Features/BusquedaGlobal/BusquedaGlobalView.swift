import SwiftUI
import DesignSystem
import Models

struct BusquedaGlobalView: View {
    @ObservedObject var viewModel: BusquedaGlobalViewModel
    let onSeleccionar: (ResultadoBusqueda) -> Void
    let onCerrar: () -> Void

    @FocusState private var textFieldEnfocado: Bool
    @StateObject private var monitorTeclado = MonitorTecladoBusqueda()

    var body: some View {
        VStack(spacing: 0) {
            cabecera
            Divider().background(AppColor.surface1)
            contenido
            Divider().background(AppColor.surface1)
            pie
        }
        .frame(width: 640, height: 480)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.l)
                .fill(AppColor.mantle)
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TemaRadio.l)
                .stroke(AppColor.surface1, lineWidth: 1)
        )
        .onAppear {
            textFieldEnfocado = true
            monitorTeclado.iniciar()
        }
        .onDisappear {
            monitorTeclado.detener()
        }
        .onExitCommand(perform: onCerrar)
    }

    private var cabecera: some View {
        HStack(spacing: TemaEspaciado.m) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.accent)
            TextField("", text: Binding(
                get: { viewModel.query },
                set: { viewModel.actualizar(query: $0) }
            ), prompt: Text(LocalizableKey.busqPlaceholder.localized())
                .foregroundColor(AppColor.subtext0)
            )
            .textFieldStyle(.plain)
            .font(Tipografia.subtitulo())
            .foregroundColor(AppColor.text)
            .focused($textFieldEnfocado)
            .onSubmit {
                if let r = viewModel.seleccionarActual() {
                    onSeleccionar(r)
                }
            }
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.actualizar(query: "")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColor.subtext0)
                }
                .buttonStyle(.borderless)
                .help(LocalizableKey.commonLimpiar.localized())
            }
        }
        .padding(TemaEspaciado.l)
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            estadoVacioSugerencia
        } else if viewModel.cargando {
            ProgresoBusqueda()
        } else if viewModel.resultados.isEmpty {
            estadoSinResultados
        } else {
            listaResultados
        }
    }

    private var estadoVacioSugerencia: some View {
        VStack(spacing: TemaEspaciado.m) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundColor(AppColor.accent)
            Text(LocalizableKey.busqEstadoVacioTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.busqEstadoVacioDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(TemaEspaciado.xl)
    }

    private var estadoSinResultados: some View {
        VStack(spacing: TemaEspaciado.m) {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: 36))
                .foregroundColor(AppColor.subtext0)
            Text(LocalizableKey.busqEstadoSinResultadosTitulo.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text(LocalizableKey.busqEstadoSinResultadosDesc.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(TemaEspaciado.xl)
    }

    private var listaResultados: some View {
        let agrupados = Dictionary(grouping: viewModel.resultados, by: \.categoria)
        let ordenadasCategorias: [ResultadoBusquedaCategoria] = [.transaccion, .prestamo, .suscripcion]
            .filter { agrupados[$0] != nil }

        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: TemaEspaciado.m) {
                    ForEach(ordenadasCategorias, id: \.self) { cat in
                        let items = agrupados[cat] ?? []
                        VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                            HStack(spacing: TemaEspaciado.xs) {
                                Image(systemName: cat.icono)
                                    .font(.system(size: 11, weight: .medium))
                                Text(cat.titulo.uppercased())
                                    .font(Tipografia.cuerpo())
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(AppColor.subtext0)
                            .padding(.horizontal, TemaEspaciado.l)

                            ForEach(items) { resultado in
                                let indicePlano = indicePlano(para: resultado)
                                FilaResultado(
                                    resultado: resultado,
                                    seleccionado: indicePlano == viewModel.indiceSeleccionado
                                )
                                .id(resultado.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.indiceSeleccionado = indicePlano
                                    onSeleccionar(resultado)
                                }
                                .padding(.horizontal, TemaEspaciado.l)
                                .onChange(of: viewModel.indiceSeleccionado) { nuevo in
                                    if nuevo == indicePlano,
                                       let id = opcionalIndice(nuevo) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            proxy.scrollTo(id, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, TemaEspaciado.m)
            }
        }
    }

    private func indicePlano(para resultado: ResultadoBusqueda) -> Int {
        viewModel.resultados.firstIndex(of: resultado) ?? 0
    }

    private func opcionalIndice(_ i: Int) -> String? {
        guard i >= 0, i < viewModel.resultados.count else { return nil }
        return viewModel.resultados[i].id
    }

    private var pie: some View {
        HStack(spacing: TemaEspaciado.l) {
            HintTecla(texto: "↑↓", descripcion: LocalizableKey.busqHintNavegar.localized())
            HintTecla(texto: "⏎", descripcion: LocalizableKey.busqHintAbrir.localized())
            HintTecla(texto: "esc", descripcion: LocalizableKey.busqHintCerrar.localized())
            Spacer()
            if !viewModel.query.isEmpty {
                Text(LocalizableKey.busqConteoResultados.localized(viewModel.resultados.count, viewModel.resultados.count))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
        }
        .padding(.horizontal, TemaEspaciado.l)
        .padding(.vertical, TemaEspaciado.s)
        .background(AppColor.base.opacity(0.5))
        .onReceive(NotificationCenter.default.publisher(for: .busquedaMoverArriba)) { _ in
            viewModel.moverSeleccion(delta: -1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .busquedaMoverAbajo)) { _ in
            viewModel.moverSeleccion(delta: 1)
        }
        .onReceive(NotificationCenter.default.publisher(for: .busquedaSeleccionar)) { _ in
            if let r = viewModel.seleccionarActual() {
                onSeleccionar(r)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .busquedaCerrar)) { _ in
            onCerrar()
        }
    }
}

private struct FilaResultado: View {
    let resultado: ResultadoBusqueda
    let seleccionado: Bool

    var body: some View {
        HStack(alignment: .center, spacing: TemaEspaciado.m) {
            Image(systemName: iconoCategoria)
                .font(.system(size: 16))
                .frame(width: 28)
                .foregroundColor(colorIcono)
            VStack(alignment: .leading, spacing: 2) {
                Text(resultado.titulo)
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                    .lineLimit(1)
                Text(resultado.subtitulo)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
                    .lineLimit(1)
            }
            Spacer()
            MontoLabel(monto: resultado.monto, tamanio: .chico, colorearSegunSigno: false)
        }
        .padding(.vertical, TemaEspaciado.s)
        .padding(.horizontal, TemaEspaciado.s)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.s)
                .fill(seleccionado ? AppColor.surface1 : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TemaRadio.s)
                .stroke(seleccionado ? AppColor.accent : .clear, lineWidth: 1)
        )
    }

    private var iconoCategoria: String {
        switch resultado {
        case .transaccion: return "list.bullet.rectangle"
        case .prestamo: return "person.crop.circle"
        case .suscripcion: return "repeat.circle.fill"
        }
    }

    private var colorIcono: Color {
        switch resultado.tipoParaColor {
        case .ingreso: return AppColor.green
        case .gasto: return AppColor.red
        }
    }
}

private struct HintTecla: View {
    let texto: String
    let descripcion: String

    var body: some View {
        HStack(spacing: TemaEspaciado.xs) {
            Text(texto)
                .font(Tipografia.cuerpo())
                .fontWeight(.medium)
                .padding(.horizontal, TemaEspaciado.s)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColor.surface1)
                )
                .foregroundColor(AppColor.text)
            Text(descripcion)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
        }
    }
}

private struct ProgresoBusqueda: View {
    var body: some View {
        VStack(spacing: TemaEspaciado.m) {
            ProgressView()
                .controlSize(.small)
                .tint(AppColor.accent)
            Text(LocalizableKey.busqCargando.localized())
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public extension Notification.Name {
    static let busquedaMoverArriba = Notification.Name("com.transactapp.busqueda.moverArriba")
    static let busquedaMoverAbajo = Notification.Name("com.transactapp.busqueda.moverAbajo")
    static let busquedaSeleccionar = Notification.Name("com.transactapp.busqueda.seleccionar")
    static let busquedaCerrar = Notification.Name("com.transactapp.busqueda.cerrar")
    static let transactAppObservadorReiniciar = Notification.Name("com.transactapp.observador.reiniciar")
}
