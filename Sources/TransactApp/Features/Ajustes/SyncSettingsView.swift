import SwiftUI
import DesignSystem
import Services
import Models

struct SyncSettingsView: View {
    @EnvironmentObject var environment: AppEnvironment
    @State private var email: String = ""
    @State private var codigoOTP: String = ""
    @State private var estado: EstadoSync = .desconectado
    @State private var mensaje: String = ""
    @State private var sincronizando: Bool = false
    @State private var mostrandoInputCodigo: Bool = false
    @State private var autenticado: Bool = false

    enum EstadoSync: String {
        case desconectado = "Desconectado"
        case conectado = "Conectado"
        case enviando = "Enviando código…"
        case verificando = "Verificando código…"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TemaEspaciado.l) {
                headerView
                estadoView
                if !autenticado {
                    authView
                } else {
                    syncActionsView
                }
            }
            .padding(TemaEspaciado.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.base)
        .onAppear {
            autenticado = environment.syncService.autenticado
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.xs) {
            Text("Sincronización en la Nube")
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Text("Mantén tus datos sincronizados entre esta Mac y la versión web.")
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
        }
    }

    private var estadoView: some View {
        HStack {
            Circle()
                .fill(autenticado ? AppColor.green : AppColor.red)
                .frame(width: 10, height: 10)
            Text(autenticado ? "Conectado a la nube" : "Desconectado")
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
            if sincronizando {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, TemaEspaciado.s)
            }
        }
    }

    @ViewBuilder
    private var authView: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.m) {
            Text("Iniciar sesión")
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)

            Text("Ingresa tu correo. Recibirás un email con un link y un código de 8 dígitos. Puedes dar clic al link para abrir la web, o escribir el código aquí en la app.")
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)

            TextField("correo@ejemplo.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
                .disabled(estado == .enviando)

            if mostrandoInputCodigo {
                TextField("Código de 8 dígitos", text: $codigoOTP)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .disabled(estado == .verificando)

                HStack(spacing: TemaEspaciado.s) {
                    PrimaryButton("Verificar código") {
                        Task { await verificarCodigo() }
                    }
                    .disabled(codigoOTP.isEmpty || estado == .verificando)

                    Button("Cancelar") {
                        mostrandoInputCodigo = false
                        codigoOTP = ""
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                PrimaryButton("Enviar código de acceso") {
                    Task { await enviarMagicLink() }
                }
                .disabled(email.isEmpty || estado == .enviando)
            }

            if !mensaje.isEmpty {
                Text(mensaje)
                    .font(Tipografia.cuerpo())
                    .foregroundColor(mensaje.hasPrefix("Error") ? AppColor.red : AppColor.green)
            }
        }
    }

    @ViewBuilder
    private var syncActionsView: some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.m) {
            Text("Acciones")
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)

            HStack(spacing: TemaEspaciado.s) {
                PrimaryButton("Sincronizar ahora") {
                    Task { await sincronizar() }
                }
                .disabled(sincronizando)

                Button("Cerrar sesión") {
                    cerrarSesion()
                }
                .buttonStyle(.bordered)
                .tint(AppColor.red)
            }

            Text("La sincronización también ocurre automáticamente al abrir la app.")
                .font(.caption)
                .foregroundColor(AppColor.subtext0)
        }
    }

    private func enviarMagicLink() async {
        estado = .enviando
        mensaje = ""
        do {
            try await environment.syncService.enviarMagicLink(email: email)
            mostrandoInputCodigo = true
            estado = .desconectado
            mensaje = "Revisa tu correo. Puedes dar clic al link o escribir el código de 8 dígitos aquí."
        } catch {
            estado = .desconectado
            mensaje = "Error: \(error.localizedDescription)"
        }
    }

    private func verificarCodigo() async {
        estado = .verificando
        mensaje = ""
        do {
            try await environment.syncService.verificarYAutenticar(email: email, token: codigoOTP)
            autenticado = true
            estado = .conectado
            mensaje = "Sesión iniciada correctamente."
            mostrandoInputCodigo = false
            codigoOTP = ""
            await sincronizar()
        } catch {
            estado = .desconectado
            mensaje = "Error: \(error.localizedDescription)"
        }
    }

    private func sincronizar() async {
        sincronizando = true
        mensaje = ""
        await environment.syncService.pullChanges()
        let erroresAntes = environment.syncService.erroresSync.count
        await environment.syncService.pushChanges()
        let erroresDespues = environment.syncService.erroresSync.count
        if erroresDespues > erroresAntes {
            mensaje = "Sincronización completada con \(erroresDespues - erroresAntes) error(es)."
        } else {
            mensaje = "Sincronización completada."
        }
        sincronizando = false
    }

    private func cerrarSesion() {
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        environment.syncService.autenticado = false
        environment.supabaseManager.token = nil
        autenticado = false
        email = ""
        codigoOTP = ""
        mostrandoInputCodigo = false
        estado = .desconectado
        mensaje = "Sesión cerrada."
    }
}
