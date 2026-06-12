import Foundation
import Models
import Database
import PDFKit
import AppKit

public struct ReportesService: Sendable {
    private let database: DatabaseManager
    private let initialBalanceRepo: any InitialBalanceRepository
    private let inventoryRepo: any InventoryRepository
    private let transactionRepo: any TransactionRepository
    private let loanRepo: any LoanRepository
    private let subscriptionRepo: any SubscriptionRepository
    private let configurationService: ConfigurationService
    private let projectionService: ProjectionService

    public init(
        database: DatabaseManager,
        initialBalanceRepo: any InitialBalanceRepository,
        inventoryRepo: any InventoryRepository,
        transactionRepo: any TransactionRepository,
        loanRepo: any LoanRepository,
        subscriptionRepo: any SubscriptionRepository,
        configurationService: ConfigurationService,
        projectionService: ProjectionService
    ) {
        self.database = database
        self.initialBalanceRepo = initialBalanceRepo
        self.inventoryRepo = inventoryRepo
        self.transactionRepo = transactionRepo
        self.loanRepo = loanRepo
        self.subscriptionRepo = subscriptionRepo
        self.configurationService = configurationService
        self.projectionService = projectionService
    }

    public func compilarReporte(
        parametros: ParametrosReporte,
        referencia: Date = Date()
    ) async throws -> ReporteMensual {
        let todas = try await transactionRepo.listar()
        let transaccionesDelMes = Self.filtrarTransacciones(todas, en: parametros.mes)
        let prestamos = try await loanRepo.listar()
        let suscripciones = try await subscriptionRepo.listar()
        let inventario = try await inventoryRepo.listar()
        let saldoInicial = try await initialBalanceRepo.obtener()

        let totalIngresos = transaccionesDelMes
            .filter { $0.tipo == .ingreso }
            .reduce(into: Decimal(0)) { $0 += $1.monto }
        let totalGastos = transaccionesDelMes
            .filter { $0.tipo == .gasto }
            .reduce(into: Decimal(0)) { $0 += $1.monto }

        let resumenFinanciero = CalculosFinancieros.resumen(
            saldoInicial: saldoInicial,
            transacciones: todas,
            prestamos: prestamos
        )

        let datos = DatosReporte(
            saldoInicialEfectivo: saldoInicial?.efectivo ?? 0,
            saldoInicialTarjeta: saldoInicial?.tarjeta ?? 0,
            saldoEfectivo: resumenFinanciero.saldoEfectivo,
            saldoTarjeta: resumenFinanciero.saldoTarjeta,
            balanceTotal: resumenFinanciero.balanceTotal,
            totalDeudas: resumenFinanciero.totalDeudas,
            balanceReal: resumenFinanciero.balanceReal,
            totalIngresos: totalIngresos,
            totalGastos: totalGastos,
            transacciones: transaccionesDelMes,
            inventario: inventario,
            prestamos: prestamos,
            suscripciones: suscripciones
        )

        let config = try await configurationService.obtener()
        let proyeccion: ProyeccionMensual? = parametros.incluirProyeccionMes
            ? projectionService.proyectar(
                transaccionesMesActual: transaccionesDelMes,
                suscripcionesActivas: suscripciones.filter { $0.activa },
                historicoMeses: [],
                metaAhorroMensual: config.metaAhorroMensual,
                referencia: referencia
            )
            : nil

        return ReporteMensual(
            parametros: parametros,
            datos: datos,
            transaccionesDelMes: transaccionesDelMes,
            proyeccion: proyeccion,
            generadoEn: referencia
        )
    }

    public func generarPDF(reporte: ReporteMensual) throws -> Data {
        let generador = GeneradorPDFReporte(reporte: reporte)
        return try generador.renderizar()
    }

    public func generarCSV(reporte: ReporteMensual) -> Data {
        GeneradorCSVReporte(reporte: reporte).renderizar()
    }

    public func nombreArchivo(
        formato: FormatoReporte,
        parametros: ParametrosReporte
    ) -> String {
        let mes = String(format: "%02d", parametros.mesNumero)
        let extensionArchivo = formato == .pdf ? "pdf" : "csv"
        return "TransactApp-Reporte-\(parametros.anio)-\(mes).\(extensionArchivo)"
    }

    public static func filtrarTransacciones(
        _ transacciones: [Transaccion],
        en mes: Date
    ) -> [Transaccion] {
        let calendar = Calendar.current
        guard let inicio = calendar.dateInterval(of: .month, for: mes)?.start,
              let fin = calendar.dateInterval(of: .month, for: mes)?.end else {
            return []
        }
        return transacciones
            .filter { $0.fecha >= inicio && $0.fecha < fin }
            .sorted { lhs, rhs in
                if lhs.fecha != rhs.fecha { return lhs.fecha < rhs.fecha }
                return lhs.hora < rhs.hora
            }
    }
}

struct GeneradorCSVReporte {
    let reporte: ReporteMensual

    func renderizar() -> Data {
        var lineas: [String] = []
        let p = reporte.parametros

        lineas.append("## Reporte mensual")
        lineas.append("Mes,\(p.anio)-\(String(format: "%02d", p.mesNumero))")
        lineas.append("Generado,\(FormatoFechaCSV.fechaHora(reporte.generadoEn))")
        lineas.append("")

        if p.incluirResumen {
            lineas.append("## Resumen")
            lineas.append("Concepto,Valor")
            lineas.append("Total ingresos,\(FormateadorCSV.plano(reporte.datos.totalIngresos))")
            lineas.append("Total gastos,\(FormateadorCSV.plano(reporte.datos.totalGastos))")
            lineas.append("Balance del mes,\(FormateadorCSV.plano(reporte.datos.totalIngresos - reporte.datos.totalGastos))")
            lineas.append("")
        }

        if p.incluirDetalleTransacciones {
            lineas.append("## Transacciones")
            lineas.append("Fecha,Hora,Concepto,Tipo,Categoría,Método,Monto,Desglose")
            for tx in reporte.transaccionesDelMes {
                lineas.append(lineaTransaccion(tx))
            }
            lineas.append("")
        }

        if p.incluirPrestamos {
            lineas.append("## Préstamos")
            lineas.append("Persona,Concepto,Tipo,Monto,Pagado,Saldo,Afecta balance,Fecha")
            for prestamo in reporte.datos.prestamos {
                lineas.append(lineaPrestamo(prestamo))
            }
            lineas.append("")
        }

        if p.incluirSuscripciones {
            lineas.append("## Suscripciones")
            lineas.append("Concepto,Categoría,Tipo,Monto,Frecuencia,Próximo cobro,Activa")
            for sub in reporte.datos.suscripciones {
                lineas.append(lineaSuscripcion(sub))
            }
            lineas.append("")
        }

        if p.incluirInventario {
            lineas.append("## Inventario de efectivo")
            lineas.append("Denominación,Cantidad,Subtotal")
            for inv in reporte.datos.inventario {
                lineas.append("\(inv.denominacion),\(inv.cantidad),\(FormateadorCSV.plano(inv.subtotal))")
            }
            lineas.append("")
        }

        let contenido = lineas.joined(separator: "\n")
        return Data(contenido.utf8)
    }

    private func lineaTransaccion(_ tx: Transaccion) -> String {
        let campos: [String] = [
            FormatoFechaCSV.fecha(tx.fecha),
            FormatoFechaCSV.hora(tx.hora),
            escape(tx.concepto),
            tx.tipo.rawValue,
            escape(tx.categoria),
            tx.metodo.rawValue,
            FormateadorCSV.plano(tx.monto),
            escape(desgloseTexto(tx.desglose))
        ]
        return campos.joined(separator: ",")
    }

    private func lineaPrestamo(_ p: Prestamo) -> String {
        let campos: [String] = [
            escape(p.persona),
            escape(p.concepto),
            p.tipo.rawValue,
            FormateadorCSV.plano(p.monto),
            FormateadorCSV.plano(p.montoPagado),
            FormateadorCSV.plano(p.saldoPendiente),
            p.afectaBalance ? "Sí" : "No",
            FormatoFechaCSV.fecha(p.fecha)
        ]
        return campos.joined(separator: ",")
    }

    private func lineaSuscripcion(_ s: Suscripcion) -> String {
        let campos: [String] = [
            escape(s.concepto),
            escape(s.categoria),
            s.tipo.rawValue,
            FormateadorCSV.plano(s.monto),
            s.frecuencia.rawValue,
            FormatoFechaCSV.fecha(s.proximoCobro),
            s.activa ? "Sí" : "No"
        ]
        return campos.joined(separator: ",")
    }

    private func desgloseTexto(_ desglose: DesgloseBilletes?) -> String {
        guard let d = desglose, !d.estaVacio else { return "" }
        let partes: [String] = DesgloseBilletes.denominaciones.compactMap { denom in
            let cant = d.cantidad(de: denom)
            guard cant > 0 else { return nil }
            return "\(cant)x$\(denom)"
        }
        return partes.joined(separator: " ")
    }

    private func escape(_ texto: String) -> String {
        let escapado = texto.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escapado)\""
    }
}

enum FormateadorCSV {
    static func plano(_ valor: Decimal) -> String {
        var valor = valor
        var rounded = Decimal()
        NSDecimalRound(&rounded, &valor, 2, .bankers)
        let nsValor = NSDecimalNumber(decimal: rounded)
        let formateador = NumberFormatter()
        formateador.locale = Locale(identifier: "en_US_POSIX")
        formateador.numberStyle = .decimal
        formateador.minimumFractionDigits = 2
        formateador.maximumFractionDigits = 2
        formateador.groupingSeparator = ""
        formateador.decimalSeparator = "."
        return formateador.string(from: nsValor) ?? "0.00"
    }
}

enum FormatoFechaCSV {
    static func fecha(_ date: Date) -> String { FormatoFecha.formatearFecha(date) }
    static func hora(_ date: Date) -> String { FormatoFecha.formatearHora(date) }
    static func fechaHora(_ date: Date) -> String { FormatoFecha.formatearFechaHora(date) }
}

enum PaletaPDF {
    static let base = NSColor(calibratedRed: 0.047, green: 0.055, blue: 0.063, alpha: 1)
    static let superficie = NSColor(calibratedRed: 0.094, green: 0.106, blue: 0.118, alpha: 1)
    static let superficieCero = NSColor(calibratedRed: 0.122, green: 0.133, blue: 0.149, alpha: 1)
    static let subtexto = NSColor(calibratedRed: 0.612, green: 0.627, blue: 0.651, alpha: 1)
    static let subtextoClaro = NSColor(calibratedRed: 0.424, green: 0.439, blue: 0.471, alpha: 1)
    static let texto = NSColor.white
    static let green = NSColor(calibratedRed: 0.420, green: 0.749, blue: 0.541, alpha: 1)
    static let red = NSColor(calibratedRed: 0.831, green: 0.478, blue: 0.478, alpha: 1)
    static let peach = NSColor(calibratedRed: 0.831, green: 0.659, blue: 0.478, alpha: 1)
    static let sapphire = NSColor(calibratedRed: 0.369, green: 0.541, blue: 0.749, alpha: 1)
}

final class GeneradorPDFReporte {
    let reporte: ReporteMensual

    private let tamanoPagina = CGSize(width: 612, height: 792)
    private let margenIzq: CGFloat = 48
    private let margenDer: CGFloat = 48
    private let margenSup: CGFloat = 48
    private let margenInf: CGFloat = 48
    private let anchoContenido: CGFloat = 516
    private var y: CGFloat = 0
    private var contexto: CGContext!

    init(reporte: ReporteMensual) {
        self.reporte = reporte
    }

    func renderizar() throws -> Data {
        let datos = NSMutableData()
        guard let consumer = CGDataConsumer(data: datos) else {
            throw NSError(domain: "ReportePDF", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No se pudo crear el consumidor de datos PDF"
            ])
        }
        var mediaBox = CGRect(origin: .zero, size: tamanoPagina)
        let info: [String: Any] = [
            kCGPDFContextTitle as String: "Reporte TransactApp",
            kCGPDFContextAuthor as String: "TransactApp",
            kCGPDFContextCreator as String: "TransactApp"
        ]
        guard let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, info as CFDictionary) else {
            throw NSError(domain: "ReportePDF", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "No se pudo crear el contexto PDF"
            ])
        }
        self.contexto = ctx

        self.iniciarPagina()
        self.dibujarEncabezado()

        if reporte.parametros.incluirResumen {
            self.dibujarResumen()
        }
        if reporte.parametros.incluirDetalleTransacciones {
            self.dibujarTransacciones()
        }
        if reporte.parametros.incluirPrestamos {
            self.dibujarPrestamos()
        }
        if reporte.parametros.incluirSuscripciones {
            self.dibujarSuscripciones()
        }
        if reporte.parametros.incluirInventario {
            self.dibujarInventario()
        }
        if reporte.parametros.incluirProyeccionMes, let p = reporte.proyeccion {
            self.dibujarProyeccion(p)
        }
        self.dibujarPie()

        ctx.closePDF()
        return datos as Data
    }

    private func iniciarPagina() {
        contexto.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: contexto, flipped: false)
        y = tamanoPagina.height - margenSup
        pintarFondo()
    }

    private func cerrarPagina() {
        NSGraphicsContext.restoreGraphicsState()
        contexto.endPDFPage()
    }

    private func pintarFondo() {
        let rect = CGRect(origin: .zero, size: tamanoPagina)
        PaletaPDF.base.setFill()
        rect.fill()
    }

    private func asegurarEspacio(_ altura: CGFloat) {
        if y - altura < margenInf {
            cerrarPagina()
            iniciarPagina()
        }
    }

    private func dibujarEncabezado() {
        let combinado = NSMutableAttributedString()
        combinado.append(NSAttributedString(
            string: "Reporte mensual\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: PaletaPDF.texto
            ]
        ))
        combinado.append(NSAttributedString(
            string: "\(nombreMes(reporte.parametros.mesNumero)) \(reporte.parametros.anio)\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: PaletaPDF.subtexto
            ]
        ))
        combinado.append(NSAttributedString(
            string: "Generado: \(FormatoFechaCSV.fechaHora(reporte.generadoEn))\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: PaletaPDF.subtextoClaro
            ]
        ))
        dibujarAtribuido(combinado, colorFondo: nil)
    }

    private func dibujarResumen() {
        let ingresos = reporte.datos.totalIngresos
        let gastos = reporte.datos.totalGastos
        let neto = ingresos - gastos

        encabezadoSeccion("Resumen del mes")
        linea("Ingresos", valor: ingresos, color: PaletaPDF.green)
        linea("Gastos", valor: gastos, color: PaletaPDF.red)
        linea("Balance del mes", valor: neto,
              color: neto >= 0 ? PaletaPDF.green : PaletaPDF.red)

        if reporte.parametros.incluirProyeccionMes, let proy = reporte.proyeccion {
            linea("Proyección fin de mes", valor: proy.balanceProyectado,
                  color: proy.balanceProyectado >= 0 ? PaletaPDF.green : PaletaPDF.red)
        }
        espacio(8)
    }

    private func dibujarTransacciones() {
        encabezadoSeccion("Transacciones (\(reporte.transaccionesDelMes.count))")
        if reporte.transaccionesDelMes.isEmpty {
            dibujarVacio("Sin transacciones registradas.")
            return
        }
        let columnas: [(String, CGFloat)] = [
            ("Fecha", 70),
            ("Concepto", 200),
            ("Cat.", 80),
            ("Método", 60),
            ("Monto", 80)
        ]
        tablaEncabezado(columnas)
        for tx in reporte.transaccionesDelMes {
            let colorMonto: NSColor = tx.tipo == .ingreso ? PaletaPDF.green : PaletaPDF.red
            tablaFila(
                columnas: columnas,
                valores: [
                    FormatoFechaCSV.fecha(tx.fecha),
                    tx.concepto,
                    tx.categoria,
                    tx.metodo.rawValue,
                    (tx.tipo == .gasto ? "-" : "+") + FormateadorCSV.plano(tx.monto)
                ],
                colorMonto: colorMonto
            )
        }
        espacio(8)
    }

    private func dibujarPrestamos() {
        encabezadoSeccion("Préstamos (\(reporte.datos.prestamos.count))")
        if reporte.datos.prestamos.isEmpty {
            dibujarVacio("Sin préstamos registrados.")
            return
        }
        let columnas: [(String, CGFloat)] = [
            ("Persona", 100),
            ("Concepto", 160),
            ("Tipo", 70),
            ("Monto", 70),
            ("Saldo", 70)
        ]
        tablaEncabezado(columnas)
        for prestamo in reporte.datos.prestamos {
            let colorMonto: NSColor = prestamo.tipo == .meDeben ? PaletaPDF.green : PaletaPDF.red
            tablaFila(
                columnas: columnas,
                valores: [
                    prestamo.persona,
                    prestamo.concepto,
                    prestamo.tipo.rawValue,
                    FormateadorCSV.plano(prestamo.monto),
                    FormateadorCSV.plano(prestamo.saldoPendiente)
                ],
                colorMonto: colorMonto
            )
        }
        espacio(8)
    }

    private func dibujarSuscripciones() {
        encabezadoSeccion("Suscripciones (\(reporte.datos.suscripciones.count))")
        if reporte.datos.suscripciones.isEmpty {
            dibujarVacio("Sin suscripciones registradas.")
            return
        }
        let columnas: [(String, CGFloat)] = [
            ("Concepto", 160),
            ("Categoría", 100),
            ("Monto", 70),
            ("Frecuencia", 80),
            ("Próximo", 70)
        ]
        tablaEncabezado(columnas)
        for sub in reporte.datos.suscripciones {
            let colorMonto: NSColor = sub.tipo == .ingreso ? PaletaPDF.green : PaletaPDF.peach
            tablaFila(
                columnas: columnas,
                valores: [
                    sub.concepto,
                    sub.categoria,
                    FormateadorCSV.plano(sub.monto),
                    sub.frecuencia.rawValue,
                    FormatoFechaCSV.fecha(sub.proximoCobro)
                ],
                colorMonto: colorMonto
            )
        }
        espacio(8)
    }

    private func dibujarInventario() {
        encabezadoSeccion("Inventario de efectivo")
        if reporte.datos.inventario.isEmpty {
            dibujarVacio("Sin inventario registrado.")
            return
        }
        let columnas: [(String, CGFloat)] = [
            ("Denominación", 120),
            ("Cantidad", 100),
            ("Subtotal", 100)
        ]
        tablaEncabezado(columnas)
        for inv in reporte.datos.inventario {
            tablaFila(
                columnas: columnas,
                valores: [
                    "$\(inv.denominacion)",
                    "\(inv.cantidad)",
                    FormateadorCSV.plano(inv.subtotal)
                ],
                colorMonto: PaletaPDF.green
            )
        }
        espacio(8)
    }

    private func dibujarProyeccion(_ p: ProyeccionMensual) {
        encabezadoSeccion("Proyección del mes")
        linea("Ingresos esperados", valor: p.ingresosEsperados, color: PaletaPDF.green)
        linea("Gastos esperados", valor: p.gastosEsperados, color: PaletaPDF.red)
        linea("Suscripciones restantes", valor: p.suscripcionesRestantes, color: PaletaPDF.peach)
        linea("Balance proyectado", valor: p.balanceProyectado,
              color: p.balanceProyectado >= 0 ? PaletaPDF.green : PaletaPDF.red)
        linea("Meta de ahorro", valor: p.metaAhorro, color: PaletaPDF.sapphire)
        linea("Diferencia vs meta", valor: p.diferenciaVsMeta,
              color: p.diferenciaVsMeta >= 0 ? PaletaPDF.green : PaletaPDF.red)

        let colorEstado: NSColor
        let textoEstado: String
        switch p.estado {
        case .enMeta:
            colorEstado = PaletaPDF.green
            textoEstado = "En meta"
        case .cerca:
            colorEstado = PaletaPDF.peach
            textoEstado = "Cerca de la meta"
        case .enRiesgo:
            colorEstado = PaletaPDF.red
            textoEstado = "En riesgo"
        }
        espacio(6)
        let combinado = NSMutableAttributedString()
        combinado.append(NSAttributedString(
            string: "Estado: ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: PaletaPDF.texto
            ]
        ))
        combinado.append(NSAttributedString(
            string: textoEstado + "\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: colorEstado
            ]
        ))
        combinado.append(NSAttributedString(
            string: p.mensaje + "\n\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: PaletaPDF.texto
            ]
        ))
        dibujarAtribuido(combinado, colorFondo: nil)
    }

    private func dibujarPie() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .regular),
            .foregroundColor: PaletaPDF.subtextoClaro
        ]
        dibujarAtribuido(
            NSAttributedString(string: "TransactApp · Reporte generado automáticamente", attributes: attrs),
            colorFondo: nil
        )
        cerrarPagina()
    }

    private func encabezadoSeccion(_ titulo: String) {
        espacio(6)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: PaletaPDF.texto
        ]
        let s = NSAttributedString(string: titulo + "\n", attributes: attrs)
        dibujarAtribuido(s, colorFondo: PaletaPDF.superficieCero, padding: 6)
    }

    private func linea(
        _ etiqueta: String,
        valor: Decimal,
        color: NSColor
    ) {
        let combinado = NSMutableAttributedString()
        combinado.append(NSAttributedString(
            string: "\(etiqueta): ",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: PaletaPDF.texto
            ]
        ))
        combinado.append(NSAttributedString(
            string: "$" + FormateadorCSV.plano(valor) + "\n",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
                .foregroundColor: color
            ]
        ))
        dibujarAtribuido(combinado, colorFondo: nil)
    }

    private func dibujarVacio(_ texto: String) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .regular),
            .foregroundColor: PaletaPDF.subtextoClaro
        ]
        dibujarAtribuido(
            NSAttributedString(string: texto + "\n\n", attributes: attrs),
            colorFondo: nil
        )
    }

    private func tablaEncabezado(_ columnas: [(String, CGFloat)]) {
        let attrsBase: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: PaletaPDF.texto
        ]
        let attrsMonto: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: PaletaPDF.texto
        ]
        let altoFila: CGFloat = 14
        asegurarEspacio(altoFila)

        let rectFondo = CGRect(
            x: margenIzq - 4,
            y: y - altoFila,
            width: anchoContenido + 8,
            height: altoFila
        )
        PaletaPDF.superficie.setFill()
        NSBezierPath(roundedRect: rectFondo, xRadius: 4, yRadius: 4).fill()

        var x = margenIzq
        for col in columnas {
            let attrs = esColumnaMonto(col.0) ? attrsMonto : attrsBase
            let p = NSMutableParagraphStyle()
            p.alignment = esColumnaMonto(col.0) ? .right : .left
            p.lineBreakMode = .byTruncatingTail
            let a = attrs.merging([.paragraphStyle: p]) { _, b in b }
            let rect = CGRect(x: x, y: y - altoFila, width: col.1 - 4, height: altoFila)
            col.0.draw(in: rect, withAttributes: a)
            x += col.1
        }
        y -= altoFila
    }

    private func tablaFila(
        columnas: [(String, CGFloat)],
        valores: [String],
        colorMonto: NSColor
    ) {
        let attrsBase: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: PaletaPDF.texto
        ]
        let attrsMonto: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: colorMonto
        ]
        let altoFila: CGFloat = 14
        asegurarEspacio(altoFila)
        var x = margenIzq
        for (i, col) in columnas.enumerated() {
            let valor = i < valores.count ? valores[i] : ""
            let attrs = esColumnaMonto(col.0) ? attrsMonto : attrsBase
            let p = NSMutableParagraphStyle()
            p.alignment = esColumnaMonto(col.0) ? .right : .left
            p.lineBreakMode = .byTruncatingTail
            let a = attrs.merging([.paragraphStyle: p]) { _, b in b }
            let rect = CGRect(x: x, y: y - altoFila, width: col.1 - 4, height: altoFila)
            valor.draw(in: rect, withAttributes: a)
            x += col.1
        }
        y -= altoFila
    }

    private func esColumnaMonto(_ nombre: String) -> Bool {
        ["Monto", "Subtotal", "Saldo"].contains(nombre)
    }

    private func espacio(_ altura: CGFloat) {
        y -= altura
    }

    private func dibujarAtribuido(
        _ string: NSAttributedString,
        colorFondo: NSColor?,
        padding: CGFloat = 6
    ) {
        let attrs = string.length > 0
            ? string.attributes(at: 0, effectiveRange: nil)
            : [:]
        let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 11)
        let ancho = anchoContenido - padding * 2
        let bounding = string.boundingRect(
            with: CGSize(width: ancho, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let altura = ceil(bounding.height) + padding

        if let fondo = colorFondo {
            asegurarEspacio(altura + 4)
            let rect = CGRect(
                x: margenIzq - 4,
                y: y - altura - 2,
                width: anchoContenido + 8,
                height: altura + 4
            )
            fondo.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        } else {
            asegurarEspacio(altura)
        }

        let drawRect = CGRect(x: margenIzq, y: y - altura, width: ancho, height: altura)
        string.draw(in: drawRect)
        y -= altura + 4
        _ = font
    }

    private func nombreMes(_ numero: Int) -> String {
        let nombres = [
            "", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
            "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
        ]
        let idx = max(0, min(12, numero))
        return nombres[idx]
    }
}
