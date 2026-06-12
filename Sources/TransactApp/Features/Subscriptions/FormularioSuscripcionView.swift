import SwiftUI
import DesignSystem
import Models

struct FormularioSuscripcionView: View {
    @ObservedObject var viewModel: FormularioSuscripcionViewModel
    let onCerrar: () -> Void

    var body: some View {
        Form {
            seccionBasicos
            seccionMonto
            seccionPeriodicidad
            seccionFechas
            seccionOpciones

            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundColor(AppColor.red)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(AppColor.base)
        .navigationTitle(titulo)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizableKey.commonCancelar.localized(), action: onCerrar)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(viewModel.guardando ? LocalizableKey.commonGuardando.localized() : LocalizableKey.commonGuardar.localized()) {
                    Task { await viewModel.guardar() }
                }
                .disabled(!viewModel.esValido || viewModel.guardando)
            }
            if case .editar = viewModel.modo {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        Task { await viewModel.eliminar() }
                    } label: {
                        Label(LocalizableKey.commonEliminar.localized(), systemImage: "trash")
                    }
                    .disabled(viewModel.guardando)
                }
            }
        }
        .onChange(of: viewModel.guardado) { _, nuevo in
            if nuevo { onCerrar() }
        }
    }

    private var titulo: String {
        switch viewModel.modo {
        case .nuevo: return LocalizableKey.formSubNueva.localized()
        case .editar: return LocalizableKey.formSubEditar.localized()
        }
    }

    private var seccionBasicos: some View {
        Section {
            TextField(LocalizableKey.formSubConcepto.localized(), text: $viewModel.concepto)
            TextField(LocalizableKey.formSubCategoria.localized(), text: $viewModel.categoria)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionMonto: some View {
        Section(LocalizableKey.formSubSeccionMonto.localized()) {
            CampoMontoField(
                placeholder: LocalizableKey.montoPlaceholder.localized(),
                texto: $viewModel.monto.texto
            )
            HStack {
                Text(LocalizableKey.formSubEquivale.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
                Spacer()
                MontoLabel(
                    monto: viewModel.monto.valor / Decimal(viewModel.frecuencia.mesesPorCiclo),
                    tamanio: .chico,
                    colorearSegunSigno: false
                )
                Text(LocalizableKey.formSubPorMes.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext0)
            }
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionPeriodicidad: some View {
        Section {
            Picker(LocalizableKey.formSubFrecuencia.localized(), selection: $viewModel.frecuencia) {
                ForEach(FrecuenciaSuscripcion.allCases, id: \.self) { f in
                    Text(f.titulo).tag(f)
                }
            }
            .pickerStyle(.segmented)
            Picker(LocalizableKey.formSubTipo.localized(), selection: $viewModel.tipo) {
                ForEach(TipoTransaccion.allCases, id: \.self) { t in
                    Text(t.titulo).tag(t)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionFechas: some View {
        Section {
            DatePicker(LocalizableKey.formSubInicio.localized(), selection: $viewModel.fechaInicio, displayedComponents: .date)
            HStack {
                Text(LocalizableKey.formSubProximoCobro.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext1)
                Spacer()
                Text(Localizador.fechaCorta(viewModel.proximoCobro, formato: "d MMM yyyy"))
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.accent)
            }
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionOpciones: some View {
        Section {
            HStack {
                Text(LocalizableKey.formSubDuracion.localized())
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.subtext1)
                Spacer()
                TextField("", text: $viewModel.duracionMesesTexto)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(AppColor.text)
                if viewModel.duracionMesesTexto.isEmpty {
                    Text(LocalizableKey.formSubDuracionIndefinida.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                        .fixedSize()
                }
            }
            Picker(LocalizableKey.formTxMetodo.localized(), selection: $viewModel.metodoPago) {
                ForEach(MetodoPago.allCases, id: \.self) { m in
                    Text(m.titulo).tag(m)
                }
            }
            .pickerStyle(.segmented)
            Toggle(LocalizableKey.formSubActiva.localized(), isOn: $viewModel.activa)
        } footer: {
            Text(LocalizableKey.formSubFooterDuracion.localized())
        }
        .listRowBackground(AppColor.surface0)
    }
}
