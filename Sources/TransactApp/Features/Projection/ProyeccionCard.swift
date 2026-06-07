import Foundation
import SwiftUI
import DesignSystem
import Models

struct ProyeccionCard: View {
    @ObservedObject var viewModel: ProyeccionViewModel
    var onConfiguracion: () -> Void

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: TemaEspaciado.s) {
                header
                if let error = viewModel.error {
                    Text(error)
                        .font(Tipografia.cuerpo())
                        .foregroundColor(AppColor.red)
                } else if let proyeccion = viewModel.proyeccion {
                    contenido(proyeccion)
                } else {
                    HStack {
                        Spacer()
                        ProgressView().controlSize(.small)
                        Spacer()
                    }
                    .padding(.vertical, TemaEspaciado.s)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: TemaEspaciado.s) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.accent)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: TemaRadio.s)
                        .fill(AppColor.accent.opacity(0.15))
                )
            Text(LocalizableKey.dashboardProyeccionMes.localized())
                .font(Tipografia.subtitulo())
                .foregroundColor(AppColor.text)
            Spacer()
            Button(action: onConfiguracion) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(AppColor.subtext0)
            }
            .buttonStyle(.borderless)
            .help(LocalizableKey.configTitulo.localized())
        }
    }

    @ViewBuilder
    private func contenido(_ p: ProyeccionMensual) -> some View {
        VStack(alignment: .leading, spacing: TemaEspaciado.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(Localizador.moneda(p.balanceProyectado))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(colorBalance(p))
                Spacer()
                badgeEstado(p.estado)
            }

            Text(p.mensaje)
                .font(Tipografia.cuerpo())
                .foregroundColor(AppColor.subtext0)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColor.surface0)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorEstado(p.estado))
                            .frame(
                                width: max(0, min(geo.size.width, geo.size.width * p.porcentajeCompletado)),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(LocalizableKey.dashboardDia.localized(p.diasTranscurridos, p.diasDelMes))
                        .font(.caption)
                        .foregroundColor(AppColor.subtext0)
                    Spacer()
                    if p.metaAhorro > 0 {
                        Text(LocalizableKey.proyeccionMeta.localized(Localizador.moneda(p.metaAhorro)))
                            .font(.caption)
                            .foregroundColor(AppColor.subtext0)
                    }
                }
            }

            Divider().padding(.vertical, 2)

            HStack(spacing: TemaEspaciado.m) {
                miniStat(
                    titulo: LocalizableKey.dashboardIngresosEsperados.localized(),
                    valor: Localizador.moneda(p.ingresosEsperados),
                    color: AppColor.green
                )
                miniStat(
                    titulo: LocalizableKey.dashboardGastosEsperados.localized(),
                    valor: Localizador.moneda(p.gastosEsperados),
                    color: AppColor.red
                )
                if p.suscripcionesRestantes > 0 {
                    miniStat(
                        titulo: LocalizableKey.dashboardSuscripciones.localized(),
                        valor: Localizador.moneda(p.suscripcionesRestantes),
                        color: AppColor.sapphire
                    )
                }
            }
        }
    }

    private func miniStat(titulo: String, valor: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo)
                .font(.caption)
                .foregroundColor(AppColor.subtext0)
            Text(valor)
                .font(Tipografia.subtitulo())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func badgeEstado(_ estado: EstadoProyeccion) -> some View {
        let (texto, color) = infoEstado(estado)
        return Text(texto)
            .font(.caption)
            .foregroundColor(AppColor.text)
            .padding(.horizontal, TemaEspaciado.s)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.25)))
            .overlay(Capsule().stroke(color.opacity(0.5), lineWidth: 1))
    }

    private func infoEstado(_ estado: EstadoProyeccion) -> (String, Color) {
        switch estado {
        case .enMeta: return (LocalizableKey.proyeccionEnMeta.localized(), AppColor.green)
        case .cerca: return (LocalizableKey.proyeccionCerca.localized(), AppColor.peach)
        case .enRiesgo: return (LocalizableKey.proyeccionEnRiesgo.localized(), AppColor.red)
        }
    }

    private func colorEstado(_ estado: EstadoProyeccion) -> Color {
        infoEstado(estado).1
    }

    private func colorBalance(_ p: ProyeccionMensual) -> Color {
        colorEstado(p.estado)
    }
}
