import SwiftUI
import DesignSystem
import Models

struct FormularioTransaccionView: View {
    @ObservedObject var viewModel: FormularioTransaccionViewModel
    let onCerrar: () -> Void

    var body: some View {
        Form {
            seccionTipo
            seccionDatos
            seccionMonto
            seccionCategoria
            seccionMetodo

            if viewModel.esEfectivo {
                Section {
                    DesgloseBilletesEditorView(
                        desglose: $viewModel.desglose,
                        montoObjetivo: viewModel.monto.valor,
                        onAutoDesglose: { viewModel.autocompletarDesglose() }
                    )
                }
            }

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
        .task { await viewModel.cargarCategorias() }
        .onChange(of: viewModel.guardado) { nuevo in
            if nuevo { onCerrar() }
        }
    }

    private var titulo: String {
        switch viewModel.modo {
        case .nuevo: return LocalizableKey.formTxNueva.localized()
        case .editar: return LocalizableKey.formTxEditar.localized()
        }
    }

    private var seccionTipo: some View {
        Section {
            Picker(LocalizableKey.commonTipo.localized(), selection: $viewModel.tipo) {
                ForEach(TipoTransaccion.allCases, id: \.self) { tipo in
                    Text(tipo.titulo).tag(tipo)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionDatos: some View {
        Section(LocalizableKey.formTxSeccionFecha.localized()) {
            DatePicker(LocalizableKey.commonFecha.localized(), selection: $viewModel.fecha, displayedComponents: .date)
            DatePicker(LocalizableKey.formTxHora.localized(), selection: $viewModel.hora, displayedComponents: .hourAndMinute)
            TextField(LocalizableKey.formTxConcepto.localized(), text: $viewModel.concepto)
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionMonto: some View {
        Section(LocalizableKey.formTxSeccionMonto.localized()) {
            CampoMontoField(
                placeholder: LocalizableKey.montoPlaceholder.localized(),
                texto: $viewModel.monto.texto
            )
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionCategoria: some View {
        Section(LocalizableKey.commonCategoria.localized()) {
            TextField(LocalizableKey.formTxPlaceholderCategoria.localized(), text: $viewModel.categoria)
            if !viewModel.categoriasConocidas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TemaEspaciado.s) {
                        ForEach(viewModel.categoriasConocidas, id: \.self) { cat in
                            Button {
                                viewModel.categoria = cat
                            } label: {
                                Text(cat)
                                    .font(Tipografia.cuerpo())
                                    .padding(.horizontal, TemaEspaciado.m)
                                    .padding(.vertical, TemaEspaciado.s)
                                    .background(
                                        RoundedRectangle(cornerRadius: TemaRadio.s)
                                            .fill(viewModel.categoria == cat ? AppColor.accent.opacity(0.3) : AppColor.surface1)
                                    )
                                    .foregroundColor(AppColor.text)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listRowBackground(AppColor.surface0)
    }

    private var seccionMetodo: some View {
        Section(LocalizableKey.formTxSeccionMetodo.localized()) {
            Picker(LocalizableKey.formTxMetodo.localized(), selection: $viewModel.metodo) {
                ForEach(MetodoPago.allCases, id: \.self) { metodo in
                    Text(metodo.titulo).tag(metodo)
                }
            }
            .pickerStyle(.segmented)
        }
        .listRowBackground(AppColor.surface0)
    }
}
