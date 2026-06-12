import SwiftUI
import DesignSystem
import Models
import Database
import Services

struct RegistrarPagoPrestamoView: View {
    @ObservedObject var viewModel: RegistrarPagoPrestamoViewModel
    let onCerrar: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(LocalizableKey.prestamoSeccionPersona.localized())
                            .foregroundColor(AppColor.subtext1)
                        Spacer()
                        Text(viewModel.prestamo.persona)
                            .foregroundColor(AppColor.text)
                    }
                    HStack {
                        Text(LocalizableKey.prestamoSaldoPendiente.localized())
                            .foregroundColor(AppColor.subtext1)
                        Spacer()
                        MontoLabel(monto: viewModel.saldoRestante, tamanio: .mediano, colorearSegunSigno: false)
                    }
                } header: {
                    Label(LocalizableKey.prestamoTitulo.localized(), systemImage: "arrow.left.arrow.right")
                }

                Section {
                    CampoMontoField(
                        titulo: LocalizableKey.prestamoPagoMonto.localized(),
                        placeholder: "0",
                        texto: $viewModel.montoPago.texto
                    )
                    DatePicker(LocalizableKey.commonFecha.localized(), selection: $viewModel.fecha, displayedComponents: .date)
                } header: {
                    Text(LocalizableKey.prestamoPagoDatos.localized())
                }

                Section {
                    Picker(LocalizableKey.formTxMetodo.localized(), selection: $viewModel.metodo) {
                        ForEach(MetodoPago.allCases, id: \.self) { m in
                            Text(m.titulo).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text(LocalizableKey.formTxSeccionMetodo.localized())
                }

                if viewModel.metodo == .efectivo && viewModel.montoPago.valor > 0 {
                    Section {
                        DesgloseBilletesEditorView(
                            desglose: $viewModel.desglose,
                            montoObjetivo: viewModel.montoPago.valor,
                            onAutoDesglose: { viewModel.autocompletarDesglose() }
                        )
                    } header: {
                        Text(LocalizableKey.commonDenominaciones.localized())
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
            .navigationTitle("\(accionTitulo) — \(viewModel.prestamo.persona)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizableKey.commonCancelar.localized(), action: onCerrar)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizableKey.prestamoPagoRegistrar.localized()) {
                        Task { await viewModel.registrar() }
                    }
                    .disabled(!viewModel.esValido || viewModel.guardando)
                }
            }
            .onChange(of: viewModel.guardado) { _, nuevo in
                if nuevo { onCerrar() }
            }
        }
        .frame(minWidth: 500, minHeight: 520)
    }

    private var accionTitulo: String {
        viewModel.prestamo.tipo == .meDeben
            ? LocalizableKey.prestamoPagoRecibir.localized()
            : LocalizableKey.prestamoPagoRealizar.localized()
    }
}

struct RegistrarPagoPrestamoHost: View {
    @StateObject private var viewModel: RegistrarPagoPrestamoViewModel
    let onCerrar: () -> Void

    init(
        prestamo: Prestamo,
        transactionService: TransactionService,
        transactionRepo: any TransactionRepository,
        inventoryRepo: any InventoryRepository,
        loanService: LoanService,
        onCerrar: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: RegistrarPagoPrestamoViewModel(
                prestamo: prestamo,
                transactionService: transactionService,
                transactionRepo: transactionRepo,
                inventoryRepo: inventoryRepo,
                loanService: loanService
            )
        )
        self.onCerrar = onCerrar
    }

    var body: some View {
        RegistrarPagoPrestamoView(viewModel: viewModel, onCerrar: onCerrar)
    }
}
