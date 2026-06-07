import SwiftUI
import DesignSystem
import Models

struct FormularioPrestamoView: View {
    @ObservedObject var viewModel: FormularioPrestamoViewModel
    let onCerrar: () -> Void

    var body: some View {
        Form {
            seccionTipo
            seccionPersona
            seccionMonto
            if viewModel.tipo == .debo {
                Section {
                    Toggle(LocalizableKey.prestamoAfectaBalance.localized(), isOn: $viewModel.afectaBalance)
                    Text(LocalizableKey.prestamoAfectaBalanceDesc.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext0)
                }
                .listRowBackground(AppColor.surface0)
            }
            seccionPagos
            seccionNotas
            seccionFecha

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
        .onChange(of: viewModel.guardado) { nuevo in
            if nuevo { onCerrar() }
        }
    }

    private var titulo: String {
        switch viewModel.modo {
        case .nuevo: return LocalizableKey.prestamoNuevoTitulo.localized()
        case .editar: return LocalizableKey.prestamoEditarTitulo.localized()
        }
    }

    private var seccionTipo: some View {
        Section {
            Picker(LocalizableKey.commonTipo.localized(), selection: $viewModel.tipo) {
                ForEach(TipoPrestamo.allCases, id: \.self) { tipo in
                    Text(tipo.titulo).tag(tipo)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionPersona: some View {
        Section(LocalizableKey.prestamoSeccionPersona.localized()) {
            TextField(LocalizableKey.prestamoPersonaPlaceholder.localized(), text: $viewModel.persona)
            TextField(LocalizableKey.prestamoConceptoPlaceholder.localized(), text: $viewModel.concepto)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionMonto: some View {
        Section(LocalizableKey.prestamoSeccionMonto.localized()) {
            CampoMontoField(
                placeholder: LocalizableKey.montoPlaceholder.localized(),
                texto: $viewModel.monto.texto
            )
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionPagos: some View {
        Section {
            CampoMontoField(
                placeholder: LocalizableKey.montoPlaceholder.localized(),
                texto: $viewModel.montoPagado.texto
            )
            if !viewModel.montoPagado.texto.isEmpty {
                HStack {
                    Text(LocalizableKey.prestamoSaldoPendiente.localized())
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.subtext1)
                    Spacer()
                    MontoLabel(
                        monto: viewModel.monto.valor - viewModel.montoPagado.valor,
                        tamanio: .chico,
                        colorearSegunSigno: false
                    )
                }
            }
        } header: {
            Text(LocalizableKey.prestamoSeccionPagado.localized())
        } footer: {
            Text(LocalizableKey.prestamoSeccionPagadoFooter.localized())
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionNotas: some View {
        Section(LocalizableKey.prestamoSeccionNotas.localized()) {
            TextEditor(text: $viewModel.notas)
                .frame(minHeight: 60)
                .scrollContentBackground(.hidden)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.text)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionFecha: some View {
        Section(LocalizableKey.prestamoSeccionFecha.localized()) {
            DatePicker(LocalizableKey.commonFecha.localized(), selection: $viewModel.fecha, displayedComponents: .date)
        }
        .listRowBackground(AppColor.surface0)
    }
}
