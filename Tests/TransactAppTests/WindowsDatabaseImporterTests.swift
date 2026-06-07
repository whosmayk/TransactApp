import Foundation
import Testing
import GRDB
@testable import Models
@testable import DesignSystem
@testable import Database

@Suite("WindowsDatabaseImporter")
struct WindowsDatabaseImporterTests {

    private func crearDBWindowsStub(en ruta: URL) throws -> DatabaseQueue {
        let queue = try DatabaseQueue(path: ruta.path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE Transacciones (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Concepto TEXT, Monto REAL, Tipo TEXT, Fecha TEXT, Hora TEXT,
                    Categoria TEXT, Metodo TEXT,
                    Desglose5 INTEGER DEFAULT 0, Desglose10 INTEGER DEFAULT 0,
                    Desglose20 INTEGER DEFAULT 0, Desglose50 INTEGER DEFAULT 0,
                    Desglose100 INTEGER DEFAULT 0, Desglose200 INTEGER DEFAULT 0,
                    Desglose500 INTEGER DEFAULT 0, Desglose1000 INTEGER DEFAULT 0
                );
                CREATE TABLE Prestamos (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Persona TEXT, Monto REAL, Tipo TEXT, Fecha TEXT,
                    TransaccionId INTEGER, Concepto TEXT
                );
                CREATE TABLE Suscripciones (
                    Id INTEGER PRIMARY KEY AUTOINCREMENT,
                    Concepto TEXT, Monto REAL, Categoria TEXT, Frecuencia TEXT,
                    FechaInicio TEXT, ProximaFechaCobro TEXT,
                    Activa INTEGER DEFAULT 1, Notificado INTEGER DEFAULT 0,
                    Notas TEXT, Tipo TEXT DEFAULT 'Suscripcion',
                    DuracionMeses INTEGER DEFAULT 0
                );
                CREATE TABLE InventarioEfectivo (
                    Denominacion TEXT PRIMARY KEY, Cantidad INTEGER
                );
                CREATE TABLE SaldoInicial (
                    Tipo TEXT PRIMARY KEY, Monto REAL
                );
                CREATE TABLE Categorias (Nombre TEXT PRIMARY KEY);
                """)
        }
        return queue
    }

    private func directorioTemporal() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactAppWinImp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Preflight detecta tablas faltantes")
    func preflightTablasFaltantes() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let ruta = tmp.appendingPathComponent("invalida.sqlite")
        let q = try DatabaseQueue(path: ruta.path)
        try await q.write { db in try db.execute(sql: "CREATE TABLE Otra (id INTEGER)") }

        do {
            _ = try await WindowsDatabaseImporter.preflight(ruta: ruta)
            Issue.record("Debió lanzar AppDatabaseError")
        } catch is AppDatabaseError {
        } catch {
            Issue.record("Error inesperado: \(error)")
        }
    }

    @Test("Preflight devuelve conteos y totales correctos")
    func preflightConteos() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro','1000.0','Ingreso','2026-05-01','09:00:00','Trabajo','Efectivo'),
                       ('Comida','200.5','Gasto','2026-05-02','14:30:15','Comida','Efectivo'),
                       ('Gas','500.0','Gasto','2026-05-03','18:00:00','Transporte','Tarjeta');
                INSERT INTO Prestamos (Persona, Monto, Tipo, Fecha, Concepto)
                VALUES ('Mamá','300.0','Debo','2026-05-01','Cosas'),
                       ('Pedro','100.0','Me Deben','2026-05-02','Cena');
                INSERT INTO Suscripciones
                  (Concepto, Monto, Categoria, Frecuencia, FechaInicio, ProximaFechaCobro, Tipo)
                VALUES ('Netflix','269.0','Entretenimiento','Mensual','2026-05-01','2026-06-01','Gasto'),
                       ('Laptop MSI','1200.0','Tecnología','Mensual','2026-05-01','2026-06-01','MSI');
                INSERT INTO InventarioEfectivo (Denominacion, Cantidad) VALUES ('1000','3'),('500','2');
                INSERT INTO SaldoInicial (Tipo, Monto) VALUES ('Efectivo','500.0'),('Tarjeta','1234.56');
                """)
        }
        let pre = try await WindowsDatabaseImporter.preflight(ruta: winPath)
        #expect(pre.transacciones == 3)
        #expect(pre.prestamos == 2)
        #expect(pre.suscripciones == 2)
        #expect(pre.inventario == 2)
        #expect(pre.saldoInicialEfectivo == Decimal(string: "500"))
        let tarjetaAbs = (pre.saldoInicialTarjeta ?? 0) - Decimal(string: "1234.56")!
        #expect(abs(NSDecimalNumber(decimal: tarjetaAbs).doubleValue) < 0.0001)
        #expect(pre.totalIngresos == Decimal(1000))
        let gastosAbs = pre.totalGastos - Decimal(string: "700.5")!
        #expect(abs(NSDecimalNumber(decimal: gastosAbs).doubleValue) < 0.0001)
        #expect(pre.fechaMin == FormatoFecha.parsearFecha("2026-05-01"))
        #expect(pre.fechaMax == FormatoFecha.parsearFecha("2026-05-03"))
        #expect(pre.suscripcionesConTipoDesconocido.count == 1)
        #expect(pre.suscripcionesConTipoDesconocido.first?.tipoOriginal == "MSI")
    }

    @Test("Importar trunca hora HH:mm:ss → HH:mm y combina desglose en JSON")
    func importarTruncaHoraYDesglose() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo,
                   Desglose5, Desglose10, Desglose20, Desglose50,
                   Desglose100, Desglose200, Desglose500, Desglose1000)
                VALUES ('Cobro','1750.0','Ingreso','2026-05-01','21:55:49','Trabajo','Efectivo',
                        0,0,0,1,0,1,0,1),
                       ('Simple','100.0','Gasto','2026-05-02','10:00:00','Comida','Efectivo',
                        0,0,0,0,0,0,0,0);
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath, alDestino: mac, mapeoSuscripciones: [:]
        )
        #expect(res.transaccionesImportadas == 2)

        let filas = try await mac.leer { db -> [(hora: String, desglose: String?)] in
            try Row.fetchAll(db, sql: "SELECT hora, desglose FROM Transacciones ORDER BY id")
                .map { (hora: $0["hora"] ?? "", desglose: $0["desglose"]) }
        }
        #expect(filas.count == 2)
        #expect(filas[0].hora == "21:55")
        #expect(filas[0].desglose != nil)
        let json = try #require(filas[0].desglose)
        let parsed = try JSONDecoder().decode(DesgloseBilletes.self,
            from: json.data(using: .utf8) ?? Data())
        #expect(parsed.n1000 == 1)
        #expect(parsed.n200 == 1)
        #expect(parsed.n50 == 1)
        #expect(parsed.subtotal == 1250)
        #expect(filas[1].desglose == nil)
    }

    @Test("Importar normaliza 'Me Deben' → 'Me deben' y calcula afectaBalance")
    func importarPrestamosNormaliza() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Prestamos (Persona, Monto, Tipo, Fecha, Concepto)
                VALUES ('Mamá','500.0','Debo','2026-05-01','Cosas'),
                       ('Pedro','300.0','Me Deben','2026-05-02','Cena');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        _ = try await WindowsDatabaseImporter.importar(
            ruta: winPath, alDestino: mac, mapeoSuscripciones: [:]
        )

        let prestamos = try await mac.leer { db -> [(tipo: String, afecta: Int)] in
            try Row.fetchAll(db, sql: "SELECT tipo, afectaBalance FROM Prestamos ORDER BY id")
                .map { (tipo: $0["tipo"] ?? "", afecta: $0["afectaBalance"] ?? 0) }
        }
        #expect(prestamos.count == 2)
        #expect(prestamos[0].tipo == "Debo")
        #expect(prestamos[0].afecta == 1)
        #expect(prestamos[1].tipo == "Me deben")
        #expect(prestamos[1].afecta == 0)
    }

    @Test("Importar resuelve MSI según mapeo del usuario")
    func importarSuscripcionesResuelveMSI() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Suscripciones
                  (Concepto, Monto, Categoria, Frecuencia, FechaInicio, ProximaFechaCobro, Tipo)
                VALUES ('Netflix','269.0','Entretenimiento','Mensual','2026-05-01','2026-06-01','Gasto'),
                       ('Laptop MSI','1200.0','Tecnología','Mensual','2026-05-01','2026-06-01','MSI'),
                       ('Cómputo','800.0','Tecnología','Mensual','2026-05-01','2026-06-01','Con Intereses');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [
                2: .gasto,
                3: .omitir
            ]
        )
        #expect(res.suscripcionesImportadas == 2)
        #expect(res.suscripcionesOmitidas == 1)

        let tipos = try await mac.leer { db -> [String] in
            try String.fetchAll(db, sql: "SELECT tipo FROM Suscripciones ORDER BY id")
        }
        #expect(tipos == ["Gasto", "Gasto"])
    }

    @Test("Importar colapsa SaldoInicial 2 filas en 1")
    func importarSaldoInicial() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO SaldoInicial (Tipo, Monto) VALUES ('Efectivo','2260.0'),('Tarjeta','4097.86');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath, alDestino: mac, mapeoSuscripciones: [:]
        )
        #expect(res.saldoInicialImportado)

        let fila = try await mac.leer { db -> (id: Int, ef: Double, tj: Double)? in
            try Row.fetchOne(db, sql: "SELECT id, efectivo, tarjeta FROM SaldoInicial").map {
                (id: $0["id"] ?? 0, ef: $0["efectivo"] ?? 0, tj: $0["tarjeta"] ?? 0)
            }
        }
        #expect(fila?.id == 1)
        #expect(fila?.ef == 2260.0)
        #expect(fila?.tj == 4097.86)
    }

    @Test("Importar castea Denominacion TEXT → INT y añade actualizadoEn")
    func importarInventario() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO InventarioEfectivo (Denominacion, Cantidad)
                VALUES ('1000','3'),('500','2'),('20','5');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath, alDestino: mac, mapeoSuscripciones: [:]
        )
        #expect(res.inventarioImportado == 3)

        let filas = try await mac.leer { db -> [(denom: Int, cant: Int)] in
            try Row.fetchAll(db, sql: "SELECT denominacion, cantidad FROM InventarioEfectivo ORDER BY denominacion")
                .map { (denom: $0["denominacion"] ?? 0, cant: $0["cantidad"] ?? 0) }
        }
        #expect(filas.count == 3)
        #expect(filas.map(\.denom) == [20, 500, 1000])
        #expect(filas.map(\.cant) == [5, 2, 3])
    }

    @Test("Importar reemplaza: si el destino tiene filas previas y la fuente está vacía, el destino queda vacío")
    func importarReemplazaDestino() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        let mac = try DatabaseManager(ruta: macPath)
        try await mac.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES ('2026-01-01','10:00','Previa','1.0','Gasto','X','Efectivo')
                """)
        }
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath, alDestino: mac, mapeoSuscripciones: [:]
        )
        #expect(res.transaccionesImportadas == 0)
        let conteo = try await mac.leer { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones") ?? 0
        }
        #expect(conteo == 0, "El import es replace: limpia el destino antes de insertar")
    }

    @Test("Importar inventario: OR REPLACE cuando el destino ya tiene denominaciones")
    func importarInventarioConConflictos() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO InventarioEfectivo (Denominacion, Cantidad) VALUES ('1000','3'),('500','2');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        try await mac.escribir { db in
            try db.execute(sql: """
                INSERT INTO InventarioEfectivo (denominacion, cantidad, actualizadoEn)
                VALUES (1000, 10, '2026-01-01T00:00:00'),
                       (200,  5, '2026-01-01T00:00:00')
                """)
        }
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath, alDestino: mac, mapeoSuscripciones: [:]
        )
        #expect(res.inventarioImportado == 2)
        let filas = try await mac.leer { db -> [(denom: Int, cant: Int)] in
            try Row.fetchAll(db, sql: "SELECT denominacion, cantidad FROM InventarioEfectivo ORDER BY denominacion")
                .map { (denom: $0["denominacion"] ?? 0, cant: $0["cantidad"] ?? 0) }
        }
        let mapa = Dictionary(uniqueKeysWithValues: filas.map { ($0.denom, $0.cant) })
        #expect(mapa[1000] == 3)
        #expect(mapa[500] == 2)
        #expect(mapa[200] == 5)
    }

    @Test("Importar sin saldo inicial: conserva el saldo previo del destino")
    func importarSinSaldoInicial() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro','100.0','Ingreso','2026-05-01','10:00:00','Trabajo','Efectivo');
                INSERT INTO SaldoInicial (Tipo, Monto) VALUES ('Efectivo','5000.0'),('Tarjeta','3000.0');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        try await mac.escribir { db in
            try db.execute(sql: """
                INSERT INTO SaldoInicial (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                VALUES (1, 100.0, 50.0, '2026-01-01T00:00:00', '[]')
                """)
        }
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .actual
        )
        #expect(res.transaccionesImportadas == 1)
        #expect(res.saldoInicialImportado == true)
        let saldo = try await mac.leer { db -> (ef: Double, tj: Double) in
            let fila = try Row.fetchOne(db, sql: "SELECT efectivo, tarjeta FROM SaldoInicial")
            return (fila?["efectivo"] ?? 0, fila?["tarjeta"] ?? 0)
        }
        #expect(saldo.ef == 100.0)
        #expect(saldo.tj == 50.0)
    }

    @Test("Importar sin saldo inicial: conserva el inventarioJson del destino")
    func importarSinSaldoInicialConservaInventarioJson() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro','100.0','Ingreso','2026-05-01','10:00:00','Trabajo','Efectivo');
                """)
        }
        let inventarioDestino = #"[{"d":500,"c":7},{"d":100,"c":12}]"#
        let mac = try DatabaseManager(ruta: macPath)
        try await mac.escribir { db in
            try db.execute(sql: """
                INSERT INTO SaldoInicial (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                VALUES (1, 800.0, 200.0, '2026-02-15T10:30:00', ?)
                """, arguments: [inventarioDestino])
        }
        _ = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .actual
        )
        let inventarioTras = try await mac.leer { db -> String in
            let fila = try Row.fetchOne(db, sql: "SELECT inventarioJson FROM SaldoInicial")
            return fila?["inventarioJson"] ?? ""
        }
        #expect(inventarioTras == inventarioDestino)
    }

    @Test("Ajustar a balance real: calcula el saldo inicial para coincidir con el balance dado")
    func importarAjustarABalanceReal() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro trabajo','500.0','Ingreso','2026-05-01','10:00:00','Trabajo','Efectivo'),
                       ('Comida','200.0','Gasto','2026-05-02','13:00:00','Comida','Efectivo'),
                       ('Tarjeta sueldo','1000.0','Ingreso','2026-05-01','10:00:00','Trabajo','Tarjeta'),
                       ('Compra online','150.0','Gasto','2026-05-03','20:00:00','Compras','Tarjeta');
                INSERT INTO SaldoInicial (Tipo, Monto) VALUES ('Efectivo','1000.0'),('Tarjeta','500.0');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .ajustarAReal,
            balanceReal: (100.0, 5813.50)
        )
        #expect(res.transaccionesImportadas == 4)
        #expect(res.saldoInicialImportado == true)
        let saldoFinal = try await mac.leer { db -> (ef: Double, tj: Double) in
            let fila = try Row.fetchOne(db, sql: "SELECT efectivo, tarjeta FROM SaldoInicial")
            return (fila?["efectivo"] ?? 0, fila?["tarjeta"] ?? 0)
        }
        #expect(abs(saldoFinal.ef - (-200.0)) < 0.001)
        #expect(abs(saldoFinal.tj - 4963.50) < 0.001)
        let balance = try await mac.leer { db -> (ef: Double, tj: Double) in
            let deltaEf = try Double.fetchOne(db, sql: """
                SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                FROM Transacciones WHERE metodo='Efectivo'
                """) ?? 0
            let deltaTj = try Double.fetchOne(db, sql: """
                SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                FROM Transacciones WHERE metodo='Tarjeta'
                """) ?? 0
            let si = try Row.fetchOne(db, sql: "SELECT efectivo, tarjeta FROM SaldoInicial")
            let ef = (si?["efectivo"] ?? 0) + deltaEf
            let tj = (si?["tarjeta"] ?? 0) + deltaTj
            return (ef, tj)
        }
        #expect(abs(balance.ef - 100.0) < 0.01)
        #expect(abs(balance.tj - 5813.50) < 0.01)
    }

    @Test("Ajustar a balance real sin transacciones: el saldo inicial es el balance real")
    func importarAjustarABalanceRealSinTransacciones() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        _ = try crearDBWindowsStub(en: winPath)
        let mac = try DatabaseManager(ruta: macPath)
        _ = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .ajustarAReal,
            balanceReal: (250.0, 750.50)
        )
        let saldoFinal = try await mac.leer { db -> (ef: Double, tj: Double) in
            let fila = try Row.fetchOne(db, sql: "SELECT efectivo, tarjeta FROM SaldoInicial")
            return (fila?["efectivo"] ?? 0, fila?["tarjeta"] ?? 0)
        }
        #expect(abs(saldoFinal.ef - 250.0) < 0.001)
        #expect(abs(saldoFinal.tj - 750.50) < 0.001)
    }

    @Test("Ajustar a balance real con destino vacío: crea el saldo inicial desde cero")
    func importarAjustarABalanceRealDestinoVacio() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro','300.0','Ingreso','2026-05-01','10:00:00','Trabajo','Efectivo'),
                       ('Gasto','50.0','Gasto','2026-05-02','13:00:00','Comida','Efectivo');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        _ = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .ajustarAReal,
            balanceReal: (500.0, 1000.0)
        )
        let saldoFinal = try await mac.leer { db -> (ef: Double, tj: Double) in
            let fila = try Row.fetchOne(db, sql: "SELECT efectivo, tarjeta FROM SaldoInicial")
            return (fila?["efectivo"] ?? 0, fila?["tarjeta"] ?? 0)
        }
        #expect(abs(saldoFinal.ef - 250.0) < 0.001)
        #expect(abs(saldoFinal.tj - 1000.0) < 0.001)
    }

    @Test("Ajustar a balance real preserva inventarioJson del destino")
    func importarAjustarABalanceRealPreservaInventario() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro','100.0','Ingreso','2026-05-01','10:00:00','Trabajo','Efectivo');
                """)
        }
        let inventarioDestino = #"[{"d":1000,"c":3}]"#
        let mac = try DatabaseManager(ruta: macPath)
        try await mac.escribir { db in
            try db.execute(sql: """
                INSERT INTO SaldoInicial (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                VALUES (1, 0.0, 0.0, '2026-01-01T00:00:00', ?)
                """, arguments: [inventarioDestino])
        }
        _ = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .ajustarAReal,
            balanceReal: (50.0, 0.0)
        )
        let inventarioTras = try await mac.leer { db -> String in
            let fila = try Row.fetchOne(db, sql: "SELECT inventarioJson FROM SaldoInicial")
            return fila?["inventarioJson"] ?? ""
        }
        #expect(inventarioTras == inventarioDestino)
    }

    @Test("Importar sin saldo inicial y destino sin saldo: queda vacío")
    func importarSinSaldoInicialDestinoVacio() async throws {
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let winPath = tmp.appendingPathComponent("win.sqlite")
        let macPath = tmp.appendingPathComponent("mac.sqlite")
        let q = try crearDBWindowsStub(en: winPath)
        try await q.write { db in
            try db.execute(sql: """
                INSERT INTO Transacciones
                  (Concepto, Monto, Tipo, Fecha, Hora, Categoria, Metodo)
                VALUES ('Cobro','100.0','Ingreso','2026-05-01','10:00:00','Trabajo','Efectivo');
                """)
        }
        let mac = try DatabaseManager(ruta: macPath)
        let res = try await WindowsDatabaseImporter.importar(
            ruta: winPath,
            alDestino: mac,
            mapeoSuscripciones: [:],
            modoSaldo: .actual
        )
        #expect(res.saldoInicialImportado == false)
        let haySaldo = try await mac.leer { db in
            (try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM SaldoInicial") ?? 0) > 0
        }
        #expect(!haySaldo)
    }
}

@Suite("WindowsDatabaseImporter integración (fixture real)")
struct WindowsDatabaseImporterIntegracionTests {

    private static let rutaBackup: URL = {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return cwd.appendingPathComponent("TransactApp_Backup_2026-06-03.db")
    }()

    private func directorioTemporal() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TransactAppWinImpInt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func macVacio(en dir: URL) throws -> DatabaseManager {
        try DatabaseManager(ruta: dir.appendingPathComponent("mac.sqlite"))
    }

    @Test("Preflight del backup real devuelve conteos esperados")
    func preflightBackupReal() async throws {
        let ruta = Self.rutaBackup
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            withKnownIssue {
                Issue.record("Fixture no encontrada: \(ruta.path). Coloca el .db en la raíz del proyecto.")
            }
            return
        }
        let pre = try await WindowsDatabaseImporter.preflight(ruta: ruta)
        #expect(pre.transacciones == 130)
        #expect(pre.prestamos == 8)
        #expect(pre.suscripciones == 7)
        #expect(pre.inventario == 8)
        #expect(pre.saldoInicialEfectivo != nil)
        #expect(pre.saldoInicialTarjeta != nil)
        #expect(pre.fechaMin == FormatoFecha.parsearFecha("2026-04-25"))
        #expect(pre.fechaMax == FormatoFecha.parsearFecha("2026-06-03"))
        #expect(pre.suscripcionesConTipoDesconocido.count == 7)
        let tiposDesconocidos = Set(pre.suscripcionesConTipoDesconocido.map(\.tipoOriginal))
        #expect(tiposDesconocidos == ["Suscripcion", "MSI", "Con Intereses"])
        #expect(pre.muestraTransacciones.count == 5)
        #expect(pre.muestraPrestamos.count <= 5)
        #expect(pre.muestraSuscripciones.count == 5)
    }

    @Test("Importar backup real completo con MSI→Gasto, Con Intereses→Gasto")
    func importarBackupRealCompleto() async throws {
        let ruta = Self.rutaBackup
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            withKnownIssue {
                Issue.record("Fixture no encontrada: \(ruta.path)")
            }
            return
        }
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let mac = try macVacio(en: tmp)

        let pre = try await WindowsDatabaseImporter.preflight(ruta: ruta)
        var mapeo: [Int64: MapeoSuscripcion] = [:]
        for s in pre.suscripcionesConTipoDesconocido {
            mapeo[s.id] = .gasto
        }
        let res = try await WindowsDatabaseImporter.importar(
            ruta: ruta, alDestino: mac, mapeoSuscripciones: mapeo
        )
        #expect(res.transaccionesImportadas == 130)
        #expect(res.prestamosImportados == 8)
        #expect(res.suscripcionesImportadas == 7)
        #expect(res.suscripcionesOmitidas == 0)
        #expect(res.inventarioImportado == 8)
        #expect(res.saldoInicialImportado)

        let conteos = try await mac.leer { db -> (t: Int, p: Int, s: Int, i: Int) in
            let t = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones") ?? 0
            let p = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Prestamos") ?? 0
            let s = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Suscripciones") ?? 0
            let i = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM InventarioEfectivo") ?? 0
            return (t, p, s, i)
        }
        #expect(conteos.t == 130)
        #expect(conteos.p == 8)
        #expect(conteos.s == 7)
        #expect(conteos.i == 8)

        let sinDesglose = try await mac.leer { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones WHERE desglose IS NULL") ?? 0
        }
        #expect(sinDesglose == 68)

        let saldo = try await mac.leer { db -> (id: Int, ef: Double, tj: Double) in
            let fila = try Row.fetchOne(db, sql: "SELECT id, efectivo, tarjeta FROM SaldoInicial")
            return (fila?["id"] ?? 0, fila?["efectivo"] ?? 0, fila?["tarjeta"] ?? 0)
        }
        #expect(saldo.id == 1)
        let efAbs = abs(saldo.ef - 2260.0)
        let tjAbs = abs(saldo.tj - 4097.86)
        #expect(efAbs < 0.001)
        #expect(tjAbs < 0.001)

        let prestamosTipos = try await mac.leer { db -> [String] in
            try String.fetchAll(db, sql: "SELECT DISTINCT tipo FROM Prestamos ORDER BY tipo")
        }
        #expect(prestamosTipos == ["Debo", "Me deben"])

        let suscTipos = try await mac.leer { db -> [String] in
            try String.fetchAll(db, sql: "SELECT DISTINCT tipo FROM Suscripciones ORDER BY tipo")
        }
        #expect(suscTipos == ["Gasto"])

        let inventario = try await mac.leer { db -> [Int] in
            try Int.fetchAll(db, sql: "SELECT denominacion FROM InventarioEfectivo ORDER BY denominacion")
        }
        #expect(inventario == [5, 10, 20, 50, 100, 200, 500, 1000])
    }

    @Test("Importar omitiendo MSI/Con Intereses cuenta correctamente")
    func importarOmitirTodasMSIs() async throws {
        let ruta = Self.rutaBackup
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            withKnownIssue {
                Issue.record("Fixture no encontrada: \(ruta.path)")
            }
            return
        }
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let mac = try macVacio(en: tmp)

        let pre = try await WindowsDatabaseImporter.preflight(ruta: ruta)
        var mapeo: [Int64: MapeoSuscripcion] = [:]
        for s in pre.suscripcionesConTipoDesconocido {
            mapeo[s.id] = .omitir
        }
        let res = try await WindowsDatabaseImporter.importar(
            ruta: ruta, alDestino: mac, mapeoSuscripciones: mapeo
        )
        #expect(res.suscripcionesImportadas == 0)
        #expect(res.suscripcionesOmitidas == 7)
    }

    @Test("Importar normaliza montos: Windows.Gasto con monto negativo → Mac.monto positivo")
    func importarNormalizaMontosNegativos() async throws {
        let ruta = Self.rutaBackup
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            withKnownIssue {
                Issue.record("Fixture no encontrada: \(ruta.path)")
            }
            return
        }
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let mac = try macVacio(en: tmp)

        let pre = try await WindowsDatabaseImporter.preflight(ruta: ruta)
        var mapeo: [Int64: MapeoSuscripcion] = [:]
        for s in pre.suscripcionesConTipoDesconocido {
            mapeo[s.id] = .gasto
        }
        _ = try await WindowsDatabaseImporter.importar(
            ruta: ruta, alDestino: mac, mapeoSuscripciones: mapeo
        )

        let conteoNegativo = try await mac.leer { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones WHERE monto < 0") ?? 0
        }
        #expect(conteoNegativo == 0, "Ningún monto en Mac debe ser negativo: el signo lo aporta tipo")

        let conteoPorTipo = try await mac.leer { db -> (gasto: Int, ingreso: Int) in
            let g = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones WHERE tipo='Gasto'") ?? 0
            let i = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones WHERE tipo='Ingreso'") ?? 0
            return (g, i)
        }
        #expect(conteoPorTipo.gasto == 32)
        #expect(conteoPorTipo.ingreso == 98)
    }

    @Test("Ajustar a balance real: el balance final (con TODAS las transacciones) coincide con el balance real")
    func ajustarABalanceRealBalanceFinalCoincide() async throws {
        let ruta = Self.rutaBackup
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            withKnownIssue {
                Issue.record("Fixture no encontrada: \(ruta.path)")
            }
            return
        }
        let tmp = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let mac = try macVacio(en: tmp)

        let pre = try await WindowsDatabaseImporter.preflight(ruta: ruta)
        var mapeo: [Int64: MapeoSuscripcion] = [:]
        for s in pre.suscripcionesConTipoDesconocido {
            mapeo[s.id] = .gasto
        }

        let realEf: Double = 100.0
        let realTj: Double = 5813.50
        _ = try await WindowsDatabaseImporter.importar(
            ruta: ruta,
            alDestino: mac,
            mapeoSuscripciones: mapeo,
            modoSaldo: .ajustarAReal,
            balanceReal: (realEf, realTj)
        )

        let (saldoInicialEf, saldoInicialTj, deltaEf, deltaTj) = try await mac.leer { db -> (Double, Double, Double, Double) in
            let si = try Row.fetchOne(db, sql: "SELECT efectivo, tarjeta FROM SaldoInicial")
            let ef: Double = (si?["efectivo"] as? Double) ?? 0
            let tj: Double = (si?["tarjeta"] as? Double) ?? 0
            let dEf = try Double.fetchOne(db, sql: """
                SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                FROM Transacciones WHERE metodo='Efectivo'
                """) ?? 0
            let dTj = try Double.fetchOne(db, sql: """
                SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                FROM Transacciones WHERE metodo='Tarjeta'
                """) ?? 0
            return (ef, tj, dEf, dTj)
        }

        let balanceEf = saldoInicialEf + deltaEf
        let balanceTj = saldoInicialTj + deltaTj
        #expect(abs(balanceEf - realEf) < 0.01)
        #expect(abs(balanceTj - realTj) < 0.01)
    }
}
