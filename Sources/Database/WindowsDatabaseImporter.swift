import Foundation
import GRDB
import Models

public struct ResultadoPreflightWindows: Sendable {
    public let transacciones: Int
    public let prestamos: Int
    public let suscripciones: Int
    public let inventario: Int
    public let saldoInicialEfectivo: Decimal?
    public let saldoInicialTarjeta: Decimal?
    public let fechaMin: Date?
    public let fechaMax: Date?
    public let totalIngresos: Decimal
    public let totalGastos: Decimal
    public let muestraTransacciones: [MuestraTransaccion]
    public let muestraPrestamos: [MuestraPrestamo]
    public let muestraSuscripciones: [MuestraSuscripcion]
    public let suscripcionesConTipoDesconocido: [SuscripcionTipoDesconocido]
}

public struct MuestraTransaccion: Sendable, Identifiable, Hashable {
    public let id: Int64
    public let fecha: Date
    public let concepto: String
    public let monto: Decimal
    public let tipo: String
    public let categoria: String
    public let metodo: String
}

public struct MuestraPrestamo: Sendable, Identifiable, Hashable {
    public let id: Int64
    public let persona: String
    public let concepto: String
    public let monto: Decimal
    public let tipo: String
}

public struct MuestraSuscripcion: Sendable, Identifiable, Hashable {
    public let id: Int64
    public let concepto: String
    public let monto: Decimal
    public let tipo: String
    public let frecuencia: String
}

public struct SuscripcionTipoDesconocido: Sendable, Identifiable, Hashable {
    public let id: Int64
    public var concepto: String { "\(id): \(conceptoOriginal)" }
    public let conceptoOriginal: String
    public let tipoOriginal: String
    public let monto: Decimal
    public let frecuencia: String
}

public enum MapeoSuscripcion: Sendable, Hashable {
    case ingreso
    case gasto
    case omitir
}

public enum ModoSaldoInicial: String, Sendable, Hashable, CaseIterable {
    case archivo
    case actual
    case ajustarAReal
}

public struct ResultadoImportacionWindows: Sendable {
    public let transaccionesImportadas: Int
    public let prestamosImportados: Int
    public let suscripcionesImportadas: Int
    public let suscripcionesOmitidas: Int
    public let inventarioImportado: Int
    public let saldoInicialImportado: Bool
}

public enum WindowsDatabaseImporter {

    private static let tablasRequeridas = [
        "Transacciones",
        "Prestamos",
        "Suscripciones",
        "InventarioEfectivo",
        "SaldoInicial"
    ]

    public static func preflight(ruta: URL) async throws -> ResultadoPreflightWindows {
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El archivo no existe.")
        }
        let queue = try colaReadOnly(ruta: ruta)
        return try await queue.read { db in
            try validarTablas(en: db)
            return ResultadoPreflightWindows(
                transacciones: try Self.contarTransacciones(en: db),
                prestamos: try Self.contarPrestamos(en: db),
                suscripciones: try Self.contarSuscripciones(en: db),
                inventario: try Self.contarInventario(en: db),
                saldoInicialEfectivo: try Self.saldoInicialValor(en: db, tipo: "Efectivo"),
                saldoInicialTarjeta: try Self.saldoInicialValor(en: db, tipo: "Tarjeta"),
                fechaMin: try Self.fechaMinTransacciones(en: db),
                fechaMax: try Self.fechaMaxTransacciones(en: db),
                totalIngresos: try Self.totalPorTipo(en: db, tipo: "Ingreso"),
                totalGastos: try Self.totalPorTipo(en: db, tipo: "Gasto"),
                muestraTransacciones: try Self.muestraTransacciones(en: db),
                muestraPrestamos: try Self.muestraPrestamos(en: db),
                muestraSuscripciones: try Self.muestraSuscripciones(en: db),
                suscripcionesConTipoDesconocido: try Self.suscripcionesConTipoDesconocido(en: db)
            )
        }
    }

    public static func importar(
        ruta: URL,
        alDestino manager: DatabaseManager,
        mapeoSuscripciones: [Int64: MapeoSuscripcion],
        modoSaldo: ModoSaldoInicial = .archivo,
        balanceReal: (efectivo: Double, tarjeta: Double)? = nil
    ) async throws -> ResultadoImportacionWindows {
        guard FileManager.default.fileExists(atPath: ruta.path) else {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El archivo no existe.")
        }
        if modoSaldo == .ajustarAReal && balanceReal == nil {
            throw AppDatabaseError.esquemaInvalido(
                mensaje: "Falta el balance real para ajustar el saldo inicial."
            )
        }
        let queue = try colaReadOnly(ruta: ruta)
        let necesitaPrevio = (modoSaldo != .archivo)
        let saldoPrevio: SaldoInicialOrigen? =
            necesitaPrevio
            ? (try await manager.leer { db -> SaldoInicialOrigen? in
                guard let fila = try Row.fetchOne(db, sql: """
                    SELECT efectivo, tarjeta, fechaCreacion, inventarioJson FROM SaldoInicial
                    """) else { return nil }
                return SaldoInicialOrigen(
                    efectivo: fila["efectivo"] ?? 0,
                    tarjeta: fila["tarjeta"] ?? 0,
                    fechaCreacion: fila["fechaCreacion"] ?? "",
                    inventarioJson: fila["inventarioJson"] ?? "[]"
                )
            })
            : nil
        return try await manager.escribir { dest in
            try queue.read { origen in
                try validarTablas(en: origen)
                let t = try importarTransacciones(origen: origen, dest: dest)
                let inv = try importarInventario(origen: origen, dest: dest)
                let p = try importarPrestamos(origen: origen, dest: dest)
                let (sImport, sOmit) = try importarSuscripciones(
                    origen: origen,
                    dest: dest,
                    mapeo: mapeoSuscripciones
                )
                var sInicial = false
                switch modoSaldo {
                case .archivo:
                    sInicial = try importarSaldoInicial(origen: origen, dest: dest)
                case .actual:
                    if let previo = saldoPrevio {
                        try dest.execute(sql: """
                            INSERT OR REPLACE INTO SaldoInicial
                              (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                            VALUES (1,?,?,?,?)
                            """, arguments: [
                                previo.efectivo, previo.tarjeta,
                                previo.fechaCreacion, previo.inventarioJson
                            ])
                        sInicial = true
                    }
                case .ajustarAReal:
                    guard let real = balanceReal else { break }
                    let deltaEf = try Double.fetchOne(dest, sql: """
                        SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                        FROM Transacciones WHERE metodo='Efectivo'
                        """) ?? 0
                    let deltaTj = try Double.fetchOne(dest, sql: """
                        SELECT COALESCE(SUM(CASE WHEN tipo='Ingreso' THEN monto ELSE -monto END), 0)
                        FROM Transacciones WHERE metodo='Tarjeta'
                        """) ?? 0
                    let nuevoEf = real.efectivo - deltaEf
                    let nuevoTj = real.tarjeta - deltaTj
                    let inventarioJson = saldoPrevio?.inventarioJson ?? "[]"
                    let fechaCreacion = saldoPrevio?.fechaCreacion
                        ?? FormatoFecha.formatearFechaHora(Date())
                    try dest.execute(sql: """
                        INSERT OR REPLACE INTO SaldoInicial
                          (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
                        VALUES (1,?,?,?,?)
                        """, arguments: [nuevoEf, nuevoTj, fechaCreacion, inventarioJson])
                    sInicial = true
                }
                return ResultadoImportacionWindows(
                    transaccionesImportadas: t,
                    prestamosImportados: p,
                    suscripcionesImportadas: sImport,
                    suscripcionesOmitidas: sOmit,
                    inventarioImportado: inv,
                    saldoInicialImportado: sInicial
                )
            }
        }
    }

    private struct SaldoInicialOrigen: Sendable {
        let efectivo: Double
        let tarjeta: Double
        let fechaCreacion: String
        let inventarioJson: String
    }

    private static func colaReadOnly(ruta: URL) throws -> DatabaseQueue {
        var config = Configuration()
        config.readonly = true
        config.busyMode = .timeout(5)
        return try DatabaseQueue(path: ruta.path, configuration: config)
    }

    private static func validarTablas(en db: Database) throws {
        for tabla in tablasRequeridas {
            let existe = try Bool.fetchOne(
                db,
                sql: "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name=?)",
                arguments: [tabla]
            ) ?? false
            if !existe {
                throw AppDatabaseError.esquemaInvalido(
                    mensaje: "Falta la tabla '\(tabla)'. El archivo no parece ser una DB de TransactApp."
                )
            }
        }
    }

    private static func truncarHora(_ texto: String) -> String {
        guard texto.count >= 5 else { return texto }
        return String(texto.prefix(5))
    }

    private static func desgloseJSON(
        n5: Int, n10: Int, n20: Int, n50: Int, n100: Int, n200: Int, n500: Int, n1000: Int
    ) -> String? {
        let d = DesgloseBilletes(n1000: n1000, n500: n500, n200: n200, n100: n100, n50: n50, n20: n20, n10: n10, n5: n5)
        guard !d.estaVacio else { return nil }
        guard let data = try? JSONEncoder().encode(d) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func importarTransacciones(origen: Database, dest: Database) throws -> Int {
        let filas = try Row.fetchAll(origen, sql: """
            SELECT Id, Fecha, Hora, Concepto, Monto, Tipo, Categoria, Metodo,
                   Desglose5, Desglose10, Desglose20, Desglose50,
                   Desglose100, Desglose200, Desglose500, Desglose1000
            FROM Transacciones
            """)
        try dest.execute(sql: "DELETE FROM Transacciones")
        var insertadas = 0
        for fila in filas {
            let fechaStr: String = fila["Fecha"] ?? ""
            let horaStr: String = fila["Hora"] ?? ""
            _ = FormatoFecha.parsearFecha(fechaStr) ?? Date()
            let horaTruncada = truncarHora(horaStr)
            let desglose = desgloseJSON(
                n5: fila["Desglose5"] ?? 0,
                n10: fila["Desglose10"] ?? 0,
                n20: fila["Desglose20"] ?? 0,
                n50: fila["Desglose50"] ?? 0,
                n100: fila["Desglose100"] ?? 0,
                n200: fila["Desglose200"] ?? 0,
                n500: fila["Desglose500"] ?? 0,
                n1000: fila["Desglose1000"] ?? 0
            )
            try dest.execute(sql: """
                INSERT INTO Transacciones
                  (fecha, hora, concepto, monto, tipo, categoria, metodo, desglose)
                VALUES (?,?,?,?,?,?,?,?)
                """, arguments: [
                    fechaStr, horaTruncada, fila["Concepto"] ?? "",
                    abs(fila["Monto"] ?? 0.0), fila["Tipo"] ?? "Gasto",
                    fila["Categoria"] ?? "", fila["Metodo"] ?? "Efectivo",
                    desglose
                ])
            insertadas += 1
        }
        return insertadas
    }

    private static func importarInventario(origen: Database, dest: Database) throws -> Int {
        let filas = try Row.fetchAll(origen, sql: """
            SELECT Denominacion, Cantidad FROM InventarioEfectivo
            """)
        let ahora = FormatoFecha.formatearFechaHora(Date())
        var insertadas = 0
        for fila in filas {
            let denomStr: String = fila["Denominacion"] ?? "0"
            let denom = Int(denomStr.trimmingCharacters(in: .whitespaces)) ?? 0
            let cant: Int = fila["Cantidad"] ?? 0
            try dest.execute(sql: """
                INSERT OR REPLACE INTO InventarioEfectivo (denominacion, cantidad, actualizadoEn)
                VALUES (?,?,?)
                """, arguments: [denom, cant, ahora])
            insertadas += 1
        }
        return insertadas
    }

    private static func importarPrestamos(origen: Database, dest: Database) throws -> Int {
        let filas = try Row.fetchAll(origen, sql: """
            SELECT Id, Persona, Concepto, Monto, Tipo, Fecha
            FROM Prestamos
            """)
        var insertadas = 0
        for fila in filas {
            let tipoOriginal: String = fila["Tipo"] ?? ""
            let tipoNormalizado = tipoOriginal.lowercased()
            let afectaBalance = (tipoNormalizado == "debo") ? 1 : 0
            let tipo: String
            switch tipoNormalizado {
            case "debo": tipo = "Debo"
            case "me deben": tipo = "Me deben"
            default: tipo = "Me deben"
            }
            try dest.execute(sql: """
                INSERT INTO Prestamos
                  (persona, concepto, monto, tipo, fecha, afectaBalance, montoPagado, notas)
                VALUES (?,?,?,?,?,?,?,?)
                """, arguments: [
                    fila["Persona"] ?? "", fila["Concepto"] ?? "",
                    fila["Monto"] ?? 0.0, tipo,
                    fila["Fecha"] ?? "", afectaBalance, 0.0, nil
                ])
            insertadas += 1
        }
        return insertadas
    }

    private static func importarSuscripciones(
        origen: Database, dest: Database, mapeo: [Int64: MapeoSuscripcion]
    ) throws -> (insertadas: Int, omitidas: Int) {
        let filas = try Row.fetchAll(origen, sql: """
            SELECT Id, Concepto, Monto, Categoria, Frecuencia,
                   FechaInicio, ProximaFechaCobro, Activa, Notificado,
                   Notas, Tipo, DuracionMeses
            FROM Suscripciones
            """)
        var insertadas = 0
        var omitidas = 0
        for fila in filas {
            let idOrigen: Int64 = fila["Id"] ?? 0
            let tipoOriginal: String = fila["Tipo"] ?? ""
            let tipoFinal: String
            let decision: MapeoSuscripcion
            if TipoTransaccion(rawValue: tipoOriginal) != nil {
                tipoFinal = tipoOriginal
                decision = .gasto
            } else if let m = mapeo[idOrigen] {
                switch m {
                case .ingreso: tipoFinal = "Ingreso"; decision = .ingreso
                case .gasto:   tipoFinal = "Gasto";   decision = .gasto
                case .omitir:  omitidas += 1; continue
                }
            } else {
                omitidas += 1
                continue
            }
            _ = decision
            try dest.execute(sql: """
                INSERT INTO Suscripciones
                  (concepto, monto, categoria, frecuencia, tipo, fechaInicio,
                   proximoCobro, notas, duracionMeses, activa, notificado)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)
                """, arguments: [
                    fila["Concepto"] ?? "", fila["Monto"] ?? 0.0,
                    fila["Categoria"] ?? "", fila["Frecuencia"] ?? "Mensual",
                    tipoFinal,
                    fila["FechaInicio"] ?? "", fila["ProximaFechaCobro"] ?? "",
                    fila["Notas"], fila["DuracionMeses"] ?? 0,
                    fila["Activa"] ?? 1, fila["Notificado"] ?? 0
                ])
            insertadas += 1
        }
        return (insertadas, omitidas)
    }

    private static func importarSaldoInicial(origen: Database, dest: Database) throws -> Bool {
        let filas = try Row.fetchAll(origen, sql: """
            SELECT Tipo, Monto FROM SaldoInicial
            """)
        guard !filas.isEmpty else { return false }
        var efectivo: Double = 0
        var tarjeta: Double = 0
        for fila in filas {
            let tipo: String = fila["Tipo"] ?? ""
            let monto: Double = fila["Monto"] ?? 0
            if tipo == "Efectivo" { efectivo = monto }
            else if tipo == "Tarjeta" { tarjeta = monto }
        }
        let ahora = FormatoFecha.formatearFechaHora(Date())
        try dest.execute(sql: """
            INSERT OR REPLACE INTO SaldoInicial
              (id, efectivo, tarjeta, fechaCreacion, inventarioJson)
            VALUES (1,?,?,?,?)
            """, arguments: [efectivo, tarjeta, ahora, "[]"])
        return true
    }

    private static func contarTransacciones(en db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Transacciones") ?? 0
    }
    private static func contarPrestamos(en db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Prestamos") ?? 0
    }
    private static func contarSuscripciones(en db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM Suscripciones") ?? 0
    }
    private static func contarInventario(en db: Database) throws -> Int {
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM InventarioEfectivo") ?? 0
    }
    private static func saldoInicialValor(en db: Database, tipo: String) throws -> Decimal? {
        guard let v = try Double.fetchOne(
            db, sql: "SELECT Monto FROM SaldoInicial WHERE Tipo=?", arguments: [tipo]
        ) else { return nil }
        return Decimal(v)
    }
    private static func fechaMinTransacciones(en db: Database) throws -> Date? {
        guard let s = try String.fetchOne(
            db, sql: "SELECT MIN(Fecha) FROM Transacciones"
        ) else { return nil }
        return FormatoFecha.parsearFecha(s)
    }
    private static func fechaMaxTransacciones(en db: Database) throws -> Date? {
        guard let s = try String.fetchOne(
            db, sql: "SELECT MAX(Fecha) FROM Transacciones"
        ) else { return nil }
        return FormatoFecha.parsearFecha(s)
    }
    private static func totalPorTipo(en db: Database, tipo: String) throws -> Decimal {
        let v = try Double.fetchOne(
            db, sql: "SELECT COALESCE(SUM(Monto),0) FROM Transacciones WHERE Tipo=?",
            arguments: [tipo]
        ) ?? 0
        return Decimal(v)
    }

    private static func muestraTransacciones(en db: Database) throws -> [MuestraTransaccion] {
        let filas = try Row.fetchAll(db, sql: """
            SELECT Id, Fecha, Concepto, Monto, Tipo, Categoria, Metodo
            FROM Transacciones ORDER BY Fecha ASC, Id ASC LIMIT 5
            """)
        return filas.compactMap { fila in
            let fechaStr: String = fila["Fecha"] ?? ""
            let fecha = FormatoFecha.parsearFecha(fechaStr) ?? Date()
            return MuestraTransaccion(
                id: fila["Id"] ?? 0, fecha: fecha,
                concepto: fila["Concepto"] ?? "",
                monto: Decimal(fila["Monto"] ?? 0.0),
                tipo: fila["Tipo"] ?? "",
                categoria: fila["Categoria"] ?? "",
                metodo: fila["Metodo"] ?? ""
            )
        }
    }

    private static func muestraPrestamos(en db: Database) throws -> [MuestraPrestamo] {
        let filas = try Row.fetchAll(db, sql: """
            SELECT Id, Persona, Concepto, Monto, Tipo
            FROM Prestamos ORDER BY Fecha ASC, Id ASC LIMIT 5
            """)
        return filas.compactMap { fila in
            MuestraPrestamo(
                id: fila["Id"] ?? 0, persona: fila["Persona"] ?? "",
                concepto: fila["Concepto"] ?? "",
                monto: Decimal(fila["Monto"] ?? 0.0),
                tipo: fila["Tipo"] ?? ""
            )
        }
    }

    private static func muestraSuscripciones(en db: Database) throws -> [MuestraSuscripcion] {
        let filas = try Row.fetchAll(db, sql: """
            SELECT Id, Concepto, Monto, Tipo, Frecuencia
            FROM Suscripciones ORDER BY FechaInicio ASC, Id ASC LIMIT 5
            """)
        return filas.compactMap { fila in
            MuestraSuscripcion(
                id: fila["Id"] ?? 0, concepto: fila["Concepto"] ?? "",
                monto: Decimal(fila["Monto"] ?? 0.0),
                tipo: fila["Tipo"] ?? "", frecuencia: fila["Frecuencia"] ?? ""
            )
        }
    }

    private static func suscripcionesConTipoDesconocido(en db: Database) throws -> [SuscripcionTipoDesconocido] {
        let filas = try Row.fetchAll(db, sql: """
            SELECT Id, Concepto, Tipo, Monto, Frecuencia
            FROM Suscripciones
            WHERE Tipo NOT IN ('Ingreso','Gasto')
            ORDER BY Id ASC
            """)
        return filas.compactMap { fila in
            SuscripcionTipoDesconocido(
                id: fila["Id"] ?? 0,
                conceptoOriginal: fila["Concepto"] ?? "",
                tipoOriginal: fila["Tipo"] ?? "",
                monto: Decimal(fila["Monto"] ?? 0.0),
                frecuencia: fila["Frecuencia"] ?? ""
            )
        }
    }
}
