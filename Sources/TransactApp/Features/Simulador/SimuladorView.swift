import SwiftUI
import DesignSystem
import Models
import Services
import Database

struct SimuladorView: View {
    @ObservedObject var viewModel: SimuladorGastosViewModel

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.m) {
                header
                if viewModel.cargandoContexto {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, TemaEspaciado.s)
                } else {
                    selectorTipo
                    panelInputs
                    botones
                    if let error = viewModel.errorValidacion ?? viewModel.errorCalculo {
                        mensajeError(error)
                    }
                    if let resultado = viewModel.resultado {
                        Divider().padding(.vertical, 2)
                        panelResultado(resultado)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: TemaEspaciado.s) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.peach)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: TemaRadio.s)
                        .fill(AppColor.peach.opacity(0.15))
                )
            VStack(alignment: .leading, spacing: 0) {
                Text("Simulador de gastos")
                    .font(Tipografia.subtitulo())
                    .foregroundColor(AppColor.text)
                Text("¿Qué pasaría si…?")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
            }
            Spacer()
        }
    }

    private var selectorTipo: some View {
        Picker("Escenario", selection: $viewModel.tipoSeleccionado) {
            ForEach(SimuladorGastosViewModel.TipoEscenario.allCases) { tipo in
                Label(tipo.rawValue, systemImage: tipo.icono).tag(tipo)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: viewModel.tipoSeleccionado) { _ in
            viewModel.restablecer()
        }
    }

    @ViewBuilder
    private var panelInputs: some View {
        switch viewModel.tipoSeleccionado {
        case .gastoUnico:
            inputsGastoUnico
        case .cancelarSuscripcion:
            inputsCancelarSuscripcion
        case .nuevaSuscripcion:
            inputsNuevaSuscripcion
        case .reducirCategoria:
            inputsReducirCategoria
        }
    }

    private var inputsGastoUnico: some View {
        HStack(spacing: TemaEspaciado.m) {
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text("Monto")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                HStack(spacing: 4) {
                    Text("$").foregroundColor(AppColor.subtext1)
                    TextField("0", text: $viewModel.montoTexto)
                        .textFieldStyle(.roundedBorder)
                }
            }
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text("Método")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                Picker("", selection: $viewModel.metodo) {
                    ForEach(MetodoPago.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var inputsCancelarSuscripcion: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
            Text("Suscripción a cancelar")
                .font(.caption)
                .foregroundColor(AppColor.subtext0)
            if viewModel.suscripciones.isEmpty {
                Text("No tienes suscripciones activas.")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
            } else {
                Picker("", selection: $viewModel.suscripcionSeleccionadaId) {
                    ForEach(viewModel.suscripciones) { s in
                        Text("\(s.concepto) — \(textoMoneda(s.montoMensual()))/mes")
                            .tag(Optional(s.id))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var inputsNuevaSuscripcion: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack(spacing: TemaEspaciado.m) {
                VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                    Text("Concepto")
                        .font(.caption)
                        .foregroundColor(AppColor.subtext0)
                    TextField("Ej: Spotify", text: $viewModel.conceptoNueva)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                    Text("Monto")
                        .font(.caption)
                        .foregroundColor(AppColor.subtext0)
                    HStack(spacing: 4) {
                        Text("$").foregroundColor(AppColor.subtext1)
                        TextField("0", text: $viewModel.montoTexto)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text("Frecuencia")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                Picker("", selection: $viewModel.frecuenciaNueva) {
                    ForEach(FrecuenciaSuscripcion.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var inputsReducirCategoria: some View {
        HStack(spacing: TemaEspaciado.m) {
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text("Categoría")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                if let categorias = viewModel.contextoActual?.categorias, !categorias.isEmpty {
                    Picker("", selection: $viewModel.categoriaSeleccionada) {
                        ForEach(categorias, id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                } else {
                    Text("Sin categorías con histórico.")
                        .font(.caption)
                        .foregroundColor(AppColor.subtext0)
                }
            }
            VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
                Text("Reducir %")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
                HStack(spacing: 4) {
                    TextField("20", text: $viewModel.porcentajeTexto)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("%").foregroundColor(AppColor.subtext1)
                }
            }
        }
    }

    private var botones: some View {
        HStack(spacing: TemaEspaciado.s) {
            Spacer()
            if viewModel.resultado != nil {
                Button {
                    viewModel.restablecer()
                } label: {
                    Label("Restablecer", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .foregroundColor(AppColor.subtext0)
            }
            PrimaryButton("Simular", icono: "wand.and.stars") {
                viewModel.simular()
            }
            .frame(maxWidth: 160)
        }
    }

    private func mensajeError(_ mensaje: String) -> some View {
        HStack(alignment: .top, spacing: TemaEspaciado.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColor.peach)
            Text(mensaje)
                .font(.caption)
                .foregroundColor(AppColor.peach)
        }
    }

    private func panelResultado(_ r: ResultadoSimulacion) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack(alignment: .firstTextBaseline, spacing: TemaEspaciado.l) {
                columna(
                    titulo: "Saldo actual",
                    valor: r.resumenActual.balanceTotal,
                    color: AppColor.text
                )
                Image(systemName: "arrow.right")
                    .foregroundColor(AppColor.subtext0)
                columna(
                    titulo: "Quedaría",
                    valor: r.resumenSimulado.balanceTotal,
                    color: colorPara(resultado: r)
                )
            }

            HStack(spacing: TemaEspaciado.l) {
                miniStat(
                    titulo: "Impacto inmediato",
                    valor: r.impactoInmediato,
                    prefijo: true
                )
                if r.impactoMensualRecurrente != 0 {
                    miniStat(
                        titulo: "Impacto mensual",
                        valor: r.impactoMensualRecurrente,
                        prefijo: true
                    )
                }
                if r.impacto12Meses != 0 {
                    miniStat(
                        titulo: "En 12 meses",
                        valor: r.impacto12Meses,
                        prefijo: true
                    )
                }
            }

            if let promedio = r.desgloseCategoria {
                Text("Promedio actual en la categoría: \(textoMoneda(promedio)) al mes")
                    .font(.caption)
                    .foregroundColor(AppColor.subtext0)
            }

            Text(r.mensaje)
                .font(.caption)
                .foregroundColor(AppColor.subtext1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func columna(titulo: String, valor: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.caption)
                .foregroundColor(AppColor.subtext0)
            MontoLabel(monto: valor, tamanio: .mediano, colorearSegunSigno: false)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func miniStat(titulo: String, valor: Decimal, prefijo: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.caption)
                .foregroundColor(AppColor.subtext0)
            MontoLabel(monto: valor, tamanio: .chico, colorearSegunSigno: true)
                .foregroundColor(valor < 0 ? AppColor.red : AppColor.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(prefijo ? 1 : 1)
    }

    private func colorPara(resultado r: ResultadoSimulacion) -> Color {
        let delta = r.balanceTotalCambio
        if delta == 0 { return AppColor.text }
        return delta < 0 ? AppColor.red : AppColor.green
    }

    private func textoMoneda(_ valor: Decimal) -> String {
        Localizador.monedaCorta(valor)
    }
}
