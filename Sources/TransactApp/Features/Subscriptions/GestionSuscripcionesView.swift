import SwiftUI
import DesignSystem
import Models

struct GestionSuscripcionesView: View {
    @ObservedObject var viewModel: GestionSuscripcionesViewModel
    @State private var suscripcionEnEdicion: Suscripcion?
    @State private var mostrarNuevo: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            resumen

            filtros

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
        .navigationTitle(LocalizableKey.susTitulo.localized())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    mostrarNuevo = true
                } label: {
                    Label(LocalizableKey.susNueva.localized(), systemImage: "plus")
                }
            }
        }
        .task { await viewModel.cargar() }
        .refreshable { await viewModel.cargar() }
        .sheet(isPresented: $mostrarNuevo) {
            NavigationStack {
                FormularioSuscripcionHost(
                    service: viewModel.service,
                    onCerrar: {
                        mostrarNuevo = false
                        Task { await viewModel.cargar() }
                    }
                )
            }
            .frame(minWidth: 560, minHeight: 600)
        }
        .sheet(item: $suscripcionEnEdicion) { suscripcion in
            NavigationStack {
                FormularioSuscripcionHost(
                    service: viewModel.service,
                    suscripcionInicial: suscripcion,
                    onCerrar: {
                        suscripcionEnEdicion = nil
                        Task { await viewModel.cargar() }
                    }
                )
            }
            .frame(minWidth: 560, minHeight: 600)
        }
    }

    private var resumen: some View {
        HStack(spacing: TemaEspaciado.m) {
            cardResumen(
                contenido: LocalizableKey.susResumenMensual.localized(),
                monto: viewModel.totalMensual,
                pie: LocalizableKey.susResumenActivas.localized(viewModel.activas)
            )
            cardResumen(
                contenido: LocalizableKey.susResumenPorVencer.localized(),
                numeroGrande: viewModel.proximas,
                etiquetaNumero: LocalizableKey.susResumenProximasLabel.localized(),
                pie: LocalizableKey.susResumen3dias.localized()
            )
        }
        .padding(TemaEspaciado.l)
    }

    @ViewBuilder
    private func cardResumen(
        contenido: String,
        monto: Decimal? = nil,
        numeroGrande: Int? = nil,
        etiquetaNumero: String? = nil,
        pie: String
    ) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            Text(contenido)
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.subtext1)
            if let monto {
                MontoLabel(monto: monto, tamanio: .mediano, colorearSegunSigno: false)
            }
            if let n = numeroGrande, let etiqueta = etiquetaNumero {
                HStack(alignment: .firstTextBaseline, spacing: TemaEspaciado.xs) {
                    Text(LocalizableKey.susResumenProximas.localized(n))
                        .font(Tipografia.montoMediano())
                        .foregroundColor(n > 0 ? AppColor.peach : AppColor.text)
                    Text(etiqueta)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
            }
            Text(pie)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
        }
        .padding(TemaEspaciado.l)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                .fill(AppGradiente.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TemaRadio.m, style: .continuous)
                .strokeBorder(AppColor.surface1, lineWidth: 1)
        )
    }

    private var filtros: some View {
        Picker(LocalizableKey.susFiltro.localized(), selection: $viewModel.filtro) {
            ForEach(GestionSuscripcionesViewModel.FiltroSuscripcion.allCases) { f in
                Text(etiquetaFiltro(f)).tag(f)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, TemaEspaciado.l)
        .padding(.bottom, TemaEspaciado.s)
    }

    private func etiquetaFiltro(_ f: GestionSuscripcionesViewModel.FiltroSuscripcion) -> String {
        switch f {
        case .todas: return LocalizableKey.susFiltroTodas.localized()
        case .activas: return LocalizableKey.susFiltroActivas.localized()
        case .inactivas: return LocalizableKey.susFiltroInactivas.localized()
        case .proximas: return LocalizableKey.susFiltroPorVencer.localized()
        }
    }

    private var lista: some View {
        ScrollView {
            LazyVStack(spacing: TemaEspaciado.s) {
                if viewModel.cargando && viewModel.suscripciones.isEmpty {
                    ProgressView()
                        .tint(AppColor.accent)
                        .padding(TemaEspaciado.xxl)
                } else if viewModel.suscripcionesVisibles.isEmpty {
                    Text(LocalizableKey.susVacio.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                        .padding(TemaEspaciado.xxl)
                } else {
                    ForEach(viewModel.suscripcionesVisibles) { s in
                        FilaSuscripcionView(
                            suscripcion: s,
                            onAlternar: { Task { await viewModel.alternarActiva(s) } },
                            onCobrar: { Task { await viewModel.registrarCobro(s) } }
                        )
                        .onTapGesture { suscripcionEnEdicion = s }
                        .contextMenu {
                            Button(LocalizableKey.commonEditar.localized()) { suscripcionEnEdicion = s }
                            Button(
                                s.activa ? LocalizableKey.commonDesactivar.localized() : LocalizableKey.commonActivar.localized()
                            ) {
                                Task { await viewModel.alternarActiva(s) }
                            }
                            Button(LocalizableKey.susRegistrarCobro.localized()) {
                                Task { await viewModel.registrarCobro(s) }
                            }
                            Button(LocalizableKey.commonEliminar.localized(), role: .destructive) {
                                Task { await viewModel.eliminar(s) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, TemaEspaciado.xl)
            .padding(.bottom, TemaEspaciado.xxl)
        }
    }
}

private struct FilaSuscripcionView: View {
    let suscripcion: Suscripcion
    let onAlternar: () -> Void
    let onCobrar: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: TemaEspaciado.m) {
            Image(systemName: icono)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: TemaRadio.s)
                        .fill(colorFondo)
                )
                .foregroundColor(colorIcono)

            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                HStack(spacing: TemaEspaciado.s) {
                    Text(suscripcion.concepto)
                        .font(Tipografia.subtitulo())
                        .foregroundColor(AppColor.text)
                    if !suscripcion.activa {
                        Text(LocalizableKey.susInactiva.localized())
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext0)
                            .padding(.horizontal, TemaEspaciado.s)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(AppColor.surface2)
                            )
                    }
                }
                HStack(spacing: TemaEspaciado.s) {
                    Text(suscripcion.frecuencia.titulo)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                    if !suscripcion.categoria.isEmpty {
                        Text("·")
                            .foregroundColor(AppColor.subtext0)
                        Text(suscripcion.categoria)
                            .font(Tipografia.cuerpo())
                            .foregroundColor(AppColor.subtext1)
                    }
                }
                HStack(spacing: TemaEspaciado.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text(textoProximoCobro)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(colorUrgencia)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: TemaEspaciado.xs) {
                MontoLabel(
                    monto: suscripcion.monto,
                    tamanio: .mediano,
                    colorearSegunSigno: false
                )
                if suscripcion.frecuencia != .mensual {
                    Text(LocalizableKey.susPorMes.localized(Localizador.monedaCorta(suscripcion.montoMensual())))
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
                HStack(spacing: TemaEspaciado.xs) {
                    Button {
                        onAlternar()
                    } label: {
                        Image(systemName: suscripcion.activa ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppColor.accent)
                    .help(suscripcion.activa ? LocalizableKey.commonDesactivar.localized() : LocalizableKey.commonActivar.localized())

                    Button {
                        onCobrar()
                    } label: {
                        Image(systemName: "checkmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(AppColor.green)
                    .help(LocalizableKey.susRegistrarCobro.localized() + " (avanza próximo cobro)")
                }
                .padding(.top, 2)
            }
        }
        .padding(TemaEspaciado.m)
        .background(
            RoundedRectangle(cornerRadius: TemaRadio.m)
                .fill(AppColor.surface0)
        )
        .opacity(suscripcion.activa ? 1 : 0.55)
    }

    private var textoProximoCobro: String {
        let dias = suscripcion.diasHastaProximoCobro()
        if dias < 0 {
            let absDias = -dias
            if absDias == 1 {
                return LocalizableKey.susVencidaHaceSingular.localized()
            } else {
                return LocalizableKey.susVencidaHacePlural.localized(absDias)
            }
        }
        if dias == 0 {
            return LocalizableKey.susVenceHoy.localized()
        }
        if dias == 1 {
            return LocalizableKey.susVenceManana.localized()
        }
        return LocalizableKey.susEnDias.localized(dias)
    }

    private var colorUrgencia: Color {
        let dias = suscripcion.diasHastaProximoCobro()
        if dias <= 0 { return AppColor.red }
        if dias <= 3 { return AppColor.peach }
        return AppColor.subtext0
    }

    private var icono: String {
        suscripcion.frecuencia == .anual
            ? "calendar.badge.clock"
            : "repeat.circle.fill"
    }

    private var colorFondo: Color {
        suscripcion.activa
            ? AppColor.accent.opacity(0.15)
            : AppColor.surface1
    }

    private var colorIcono: Color {
        suscripcion.activa ? AppColor.accent : AppColor.subtext0
    }
}
