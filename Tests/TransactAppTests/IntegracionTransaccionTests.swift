import Foundation
import Testing
import Models
import Database
import Services
@testable import TransactApp

@Suite("Integración: TransactionService ciclo completo")
struct IntegracionTransaccionTests {

    @Test("Crear → listar → editar → eliminar")
    func cicloCompleto() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("integracion.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let invRepo = SQLiteInventoryRepository(manager: manager)
        let svc = TransactionService(
            manager: manager, transactionRepo: txRepo, inventoryRepo: invRepo
        )

        try await invRepo.upsert(Inventario(denominacion: 200, cantidad: 10))

        let ahora = Date()

        let guardada = try await svc.crear(Transaccion(
            id: nil, fecha: ahora, hora: ahora,
            concepto: "Comida", monto: 400,
            tipo: .gasto, categoria: "Comida", metodo: .efectivo,
            desglose: DesgloseBilletes(n200: 2)
        ))
        #expect(guardada.id != nil)

        let despuesCrear = try await invRepo.obtener(denominacion: 200)
        #expect(despuesCrear?.cantidad == 8)

        let todas = try await txRepo.listar()
        #expect(todas.count == 1)
        #expect(todas[0].concepto == "Comida")

        let categorias = try await txRepo.categoriasDistintas()
        #expect(categorias == ["Comida"])

        let actualizada = try await svc.actualizar(
            Transaccion(
                id: guardada.id, fecha: guardada.fecha, hora: guardada.hora,
                concepto: "Cena", monto: 600,
                tipo: .gasto, categoria: "Restaurante", metodo: .efectivo,
                desglose: DesgloseBilletes(n200: 3)
            ),
            original: guardada
        )
        #expect(actualizada.id == guardada.id)

        let despuesEditar = try await invRepo.obtener(denominacion: 200)
        #expect(despuesEditar?.cantidad == 7)

        let listaFiltrada = try await txRepo.listarFiltrado(
            mes: nil, tipo: .gasto, categoria: "Restaurante", texto: nil,
            limite: nil, orden: .fechaDesc
        )
        #expect(listaFiltrada.count == 1)
        #expect(listaFiltrada[0].concepto == "Cena")

        let listaBusqueda = try await txRepo.buscar(texto: "Cen")
        #expect(listaBusqueda.count == 1)

        try await svc.eliminar(actualizada)

        let vacia = try await txRepo.listar()
        #expect(vacia.isEmpty)

        let final = try await invRepo.obtener(denominacion: 200)
        #expect(final?.cantidad == 10)
    }

    @Test("Cambiar método de efectivo a tarjeta libera inventario")
    func cambioMetodo() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("cambio.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let invRepo = SQLiteInventoryRepository(manager: manager)
        let svc = TransactionService(
            manager: manager, transactionRepo: txRepo, inventoryRepo: invRepo
        )

        try await invRepo.upsert(Inventario(denominacion: 100, cantidad: 5))

        let original = try await svc.crear(Transaccion(
            id: nil, fecha: Date(), hora: Date(),
            concepto: "X", monto: 200,
            tipo: .gasto, categoria: "Y", metodo: .efectivo,
            desglose: DesgloseBilletes(n100: 2)
        ))

        let intermedia = try await invRepo.obtener(denominacion: 100)
        #expect(intermedia?.cantidad == 3)

        let nueva = try await svc.actualizar(
            Transaccion(
                id: original.id, fecha: original.fecha, hora: original.hora,
                concepto: "X", monto: 200,
                tipo: .gasto, categoria: "Y", metodo: .tarjeta
            ),
            original: original
        )

        let final = try await invRepo.obtener(denominacion: 100)
        #expect(final?.cantidad == 5)
    }

    @Test("Filtros del historial respetan los parámetros")
    func filtrosHistorial() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("filtros.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let txRepo = SQLiteTransactionRepository(manager: manager)
        let invRepo = SQLiteInventoryRepository(manager: manager)
        let svc = TransactionService(
            manager: manager, transactionRepo: txRepo, inventoryRepo: invRepo
        )

        let ahora = Date()
        let ayer = ahora.addingTimeInterval(-86400)
        let mesPasado = ahora.addingTimeInterval(-86400 * 35)

        _ = try await svc.crear(Transaccion(
            id: nil, fecha: ahora, hora: ahora,
            concepto: "Cena hoy", monto: 100, tipo: .gasto,
            categoria: "Comida", metodo: .efectivo
        ))
        _ = try await svc.crear(Transaccion(
            id: nil, fecha: ayer, hora: ayer,
            concepto: "Cena ayer", monto: 200, tipo: .gasto,
            categoria: "Comida", metodo: .efectivo
        ))
        _ = try await svc.crear(Transaccion(
            id: nil, fecha: mesPasado, hora: mesPasado,
            concepto: "Sueldo", monto: 5000, tipo: .ingreso,
            categoria: "Trabajo", metodo: .tarjeta
        ))

        let soloGastos = try await txRepo.listarFiltrado(
            mes: nil, tipo: .gasto, categoria: nil, texto: nil,
            limite: nil, orden: .fechaDesc
        )
        #expect(soloGastos.count == 2)
        #expect(soloGastos.allSatisfy { $0.tipo == .gasto })

        let soloComida = try await txRepo.listarFiltrado(
            mes: nil, tipo: nil, categoria: "Comida", texto: nil,
            limite: nil, orden: .fechaDesc
        )
        #expect(soloComida.count == 2)

        let busquedaCena = try await txRepo.listarFiltrado(
            mes: nil, tipo: nil, categoria: nil, texto: "Cena",
            limite: nil, orden: .fechaDesc
        )
        #expect(busquedaCena.count == 2)

        let mesActual = try await txRepo.listarFiltrado(
            mes: ahora, tipo: nil, categoria: nil, texto: nil,
            limite: nil, orden: .fechaDesc
        )
        #expect(mesActual.count == 2)
        #expect(mesActual[0].concepto == "Cena hoy")
        #expect(mesActual[1].concepto == "Cena ayer")

        let mesPasadoConsulta = try await txRepo.listarFiltrado(
            mes: mesPasado, tipo: nil, categoria: nil, texto: nil,
            limite: nil, orden: .fechaDesc
        )
        #expect(mesPasadoConsulta.count == 1)
        #expect(mesPasadoConsulta[0].concepto == "Sueldo")

        let ultimas10 = try await txRepo.listarFiltrado(
            mes: nil, tipo: nil, categoria: nil, texto: nil,
            limite: 10, orden: .fechaDesc
        )
        #expect(ultimas10.count == 3)
    }
}
