import Foundation
import Testing
import Models
import Database
import Services
@testable import TransactApp

@Suite("ReportesService")
struct ReportesServiceTests {

    private func preparar() async throws -> (
        DatabaseManager,
        ReportesService,
        SQLiteTransactionRepository,
        SQLiteLoanRepository,
        SQLiteSubscriptionRepository
    ) {
        let tmpDir = try directorioTemporal()
        let dbPath = tmpDir.appendingPathComponent("reportes.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let invRepo = SQLiteInventoryRepository(manager: manager)
        let loanRepo = SQLiteLoanRepository(manager: manager)
        let subRepo = SQLiteSubscriptionRepository(manager: manager)
        let initialRepo = SQLiteInitialBalanceRepository(manager: manager)
        let configRepo = SQLiteConfigurationRepository(manager: manager)
        let configService = ConfigurationService(repo: configRepo)
        let projectionService = ProjectionService()
        let service = ReportesService(
            database: manager,
            initialBalanceRepo: initialRepo,
            inventoryRepo: invRepo,
            transactionRepo: txRepo,
            loanRepo: loanRepo,
            subscriptionRepo: subRepo,
            configurationService: configService,
            projectionService: projectionService
        )
        return (manager, service, txRepo, loanRepo, subRepo)
    }

    private func fecha(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        return Calendar(identifier: .gregorian).date(from: comps)!
    }

    @Test("Compilar reporte filtra transacciones por mes")
    func filtrarTransaccionesPorMes() async throws {
        let (_, service, txRepo, _, _) = try await preparar()
        let calendar = Calendar(identifier: .gregorian)
        let ref = fecha(2026, 6, 5)
        let inicioJunio = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let inicioMayo = calendar.date(from: DateComponents(year: 2026, month: 5, day: 15))!
        let hora = FormatoFecha.parsearHora("12:00")!

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: inicioJunio, hora: hora,
            concepto: "Salario", monto: 5000,
            tipo: .ingreso, categoria: "Trabajo", metodo: .efectivo
        ))
        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: inicioMayo, hora: hora,
            concepto: "Antiguo", monto: 100,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo
        ))

        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(mes: ref),
            referencia: ref
        )
        #expect(reporte.transaccionesDelMes.count == 1)
        #expect(reporte.transaccionesDelMes[0].concepto == "Salario")
        #expect(reporte.datos.totalIngresos == 5000)
        #expect(reporte.datos.totalGastos == 0)
    }

    @Test("CSV con secciones básicas contiene encabezado y datos")
    func csvContenido() async throws {
        let (_, service, txRepo, loanRepo, subRepo) = try await preparar()
        let ref = fecha(2026, 6, 10)
        let hora = FormatoFecha.parsearHora("09:00")!
        let inicioJunio = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 1))!

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: inicioJunio, hora: hora,
            concepto: "Café, con \"comillas\"", monto: 50,
            tipo: .gasto, categoria: "Ocio", metodo: .efectivo
        ))
        _ = try await loanRepo.insertar(Prestamo(
            id: nil, persona: "Carlos", concepto: "Préstamo",
            monto: 500, tipo: .meDeben, fecha: inicioJunio
        ))
        _ = try await subRepo.insertar(Suscripcion(
            id: nil, concepto: "Netflix", monto: 199,
            categoria: "Ocio", frecuencia: .mensual, tipo: .gasto,
            fechaInicio: inicioJunio, proximoCobro: inicioJunio
        ))

        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(mes: ref),
            referencia: ref
        )
        let csv = service.generarCSV(reporte: reporte)
        let texto = String(data: csv, encoding: .utf8) ?? ""

        #expect(texto.contains("## Reporte mensual"))
        #expect(texto.contains("## Resumen"))
        #expect(texto.contains("## Transacciones"))
        #expect(texto.contains("## Préstamos"))
        #expect(texto.contains("## Suscripciones"))
        #expect(texto.contains("\"Café, con \"\"comillas\"\"\""))
        #expect(texto.contains("Netflix"))
        #expect(texto.contains("Carlos"))
    }

    @Test("CSV sin transacciones sólo incluye resumen")
    func csvVacio() async throws {
        let (_, service, _, _, _) = try await preparar()
        let ref = fecha(2026, 6, 10)
        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(
                mes: ref,
                incluirDetalleTransacciones: false,
                incluirPrestamos: false,
                incluirSuscripciones: false,
                incluirInventario: false
            ),
            referencia: ref
        )
        let csv = service.generarCSV(reporte: reporte)
        let texto = String(data: csv, encoding: .utf8) ?? ""
        #expect(texto.contains("## Resumen"))
        #expect(!texto.contains("## Transacciones"))
        #expect(!texto.contains("## Préstamos"))
        #expect(!texto.contains("## Suscripciones"))
    }

    @Test("CSV escapa comillas dobles en conceptos")
    func csvEscapaComillas() async throws {
        let (_, service, txRepo, _, _) = try await preparar()
        let ref = fecha(2026, 6, 10)
        let inicioJunio = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let hora = FormatoFecha.parsearHora("08:00")!

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: inicioJunio, hora: hora,
            concepto: "Café \"premium\"", monto: 80,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo
        ))

        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(
                mes: ref,
                incluirResumen: false,
                incluirPrestamos: false,
                incluirSuscripciones: false,
                incluirInventario: false,
                incluirProyeccionMes: false
            ),
            referencia: ref
        )
        let csv = service.generarCSV(reporte: reporte)
        let texto = String(data: csv, encoding: .utf8) ?? ""
        #expect(texto.contains("\"Café \"\"premium\"\"\""))
    }

    @Test("PDF genera bytes válidos con header %PDF")
    func pdfGeneraBytes() async throws {
        let (_, service, txRepo, _, _) = try await preparar()
        let ref = fecha(2026, 6, 10)
        let inicioJunio = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let hora = FormatoFecha.parsearHora("10:00")!

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: inicioJunio, hora: hora,
            concepto: "Compra", monto: 250,
            tipo: .gasto, categoria: "Supermercado", metodo: .tarjeta
        ))

        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(mes: ref),
            referencia: ref
        )
        let pdf = try service.generarPDF(reporte: reporte)
        #expect(pdf.count > 100)
        let prefijo = pdf.prefix(4)
        #expect(prefijo == Data([0x25, 0x50, 0x44, 0x46]))
    }

    @Test("PDF incluye secciones solicitadas")
    func pdfSecciones() async throws {
        let (_, service, _, _, _) = try await preparar()
        let ref = fecha(2026, 6, 10)
        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(mes: ref),
            referencia: ref
        )
        let pdf = try service.generarPDF(reporte: reporte)
        #expect(pdf.count > 0)
    }

    @Test("Nombre de archivo incluye año y mes")
    func nombreArchivo() async throws {
        let service = try await preparar().1
        let ref = fecha(2026, 6, 10)
        let p = ParametrosReporte(mes: ref)
        #expect(service.nombreArchivo(formato: .pdf, parametros: p) == "TransactApp-Reporte-2026-06.pdf")
        #expect(service.nombreArchivo(formato: .csv, parametros: p) == "TransactApp-Reporte-2026-06.csv")
    }

    @Test("Proyección se incluye cuando se solicita")
    func proyeccionIncluida() async throws {
        let (_, service, txRepo, _, _) = try await preparar()
        let ref = fecha(2026, 6, 15)
        let inicioJunio = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let hora = FormatoFecha.parsearHora("12:00")!

        _ = try await txRepo.insertar(Transaccion(
            id: nil, fecha: inicioJunio, hora: hora,
            concepto: "Salario", monto: 1000,
            tipo: .ingreso, categoria: "Trabajo", metodo: .efectivo
        ))

        let reporte = try await service.compilarReporte(
            parametros: ParametrosReporte(mes: ref, incluirProyeccionMes: true),
            referencia: ref
        )
        #expect(reporte.proyeccion != nil)
    }
}
