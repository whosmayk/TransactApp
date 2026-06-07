import Foundation
import GRDB

public struct ResultadoImportacion: Sendable {
    public let transaccionesImportadas: Int
    public let inventarioImportado: Int
    public let prestamosImportados: Int
    public let suscripcionesImportadas: Int
    public let saldoInicialImportado: Bool
}

public enum DatabaseImporter {
    public static func importar(
        desdeOrigen rutaOrigen: URL,
        alDestino manager: DatabaseManager,
        modoSaldo: ModoSaldoInicial = .archivo,
        balanceReal: (efectivo: Double, tarjeta: Double)? = nil
    ) async throws -> ResultadoImportacion {
        guard FileManager.default.fileExists(atPath: rutaOrigen.path) else {
            throw AppDatabaseError.esquemaInvalido(mensaje: "El archivo origen no existe.")
        }
        if modoSaldo == .ajustarAReal && balanceReal == nil {
            throw AppDatabaseError.esquemaInvalido(
                mensaje: "Falta el balance real para ajustar el saldo inicial."
            )
        }

        let origenQueue = try DatabaseQueue(path: rutaOrigen.path)
        try validarEsquema(origenQueue)

        let saldoPrevio: SaldoInicialRecord? = (modoSaldo != .archivo)
            ? (try await manager.leer { db in try SaldoInicialRecord.fetchOne(db) })
            : nil

        _ = try await manager.escribir { dest in
            try origenQueue.read { origen in
                try importarTransacciones(origen: origen, dest: dest)
                try importarInventario(origen: origen, dest: dest)
                try importarPrestamos(origen: origen, dest: dest)
                try importarSuscripciones(origen: origen, dest: dest)
                switch modoSaldo {
                case .archivo:
                    try importarSaldoInicial(origen: origen, dest: dest)
                case .actual:
                    if let previo = saldoPrevio {
                        var nueva = previo
                        nueva.id = 1
                        try nueva.insert(dest, onConflict: .replace)
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
                    let nueva = SaldoInicialRecord(
                        id: 1,
                        efectivo: real.efectivo - deltaEf,
                        tarjeta: real.tarjeta - deltaTj,
                        fechaCreacion: saldoPrevio?.fechaCreacion ?? "",
                        inventarioJson: saldoPrevio?.inventarioJson ?? "[]"
                    )
                    try nueva.insert(dest, onConflict: .replace)
                }
            }
        }

        return try await manager.leer { db in
            let t = try TransaccionRecord.fetchCount(db)
            let i = try InventarioRecord.fetchCount(db)
            let p = try PrestamoRecord.fetchCount(db)
            let s = try SuscripcionRecord.fetchCount(db)
            let si = try SaldoInicialRecord.fetchCount(db) > 0
            return ResultadoImportacion(
                transaccionesImportadas: t,
                inventarioImportado: i,
                prestamosImportados: p,
                suscripcionesImportadas: s,
                saldoInicialImportado: (modoSaldo == .archivo) && si
            )
        }
    }

    private static func validarEsquema(_ queue: DatabaseQueue) throws {
        let tablasRequeridas = [
            EsquemaColumnas.Transaccion.tabla,
            EsquemaColumnas.Inventario.tabla,
            EsquemaColumnas.Prestamo.tabla,
            EsquemaColumnas.Suscripcion.tabla,
            EsquemaColumnas.SaldoInicial.tabla
        ]
        try queue.read { db in
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
    }

    private static func importarTransacciones(origen: Database, dest: Database) throws {
        let filas = try TransaccionRecord.fetchAll(origen)
        for fila in filas {
            var nueva = fila
            nueva.id = nil
            nueva.monto = abs(fila.monto)
            try nueva.insert(dest, onConflict: .replace)
        }
    }

    private static func importarInventario(origen: Database, dest: Database) throws {
        let filas = try InventarioRecord.fetchAll(origen)
        for fila in filas {
            try fila.insert(dest, onConflict: .replace)
        }
    }

    private static func importarPrestamos(origen: Database, dest: Database) throws {
        let filas = try PrestamoRecord.fetchAll(origen)
        for fila in filas {
            var nueva = fila
            nueva.id = nil
            try nueva.insert(dest, onConflict: .replace)
        }
    }

    private static func importarSuscripciones(origen: Database, dest: Database) throws {
        let filas = try SuscripcionRecord.fetchAll(origen)
        for fila in filas {
            var nueva = fila
            nueva.id = nil
            try nueva.insert(dest, onConflict: .replace)
        }
    }

    private static func importarSaldoInicial(origen: Database, dest: Database) throws {
        let filas = try SaldoInicialRecord.fetchAll(origen)
        for fila in filas {
            var nueva = fila
            nueva.id = 1
            try nueva.insert(dest, onConflict: .replace)
        }
    }
}
