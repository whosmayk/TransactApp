import Foundation
import GRDB
import Models

public protocol TransactionRepository: Sendable {
    func listar() async throws -> [Transaccion]
    func obtener(id: Int64) async throws -> Transaccion?
    func insertar(_ transaccion: Transaccion) async throws -> Transaccion
    func actualizar(_ transaccion: Transaccion) async throws -> Transaccion
    func eliminar(id: Int64) async throws
    func buscar(texto: String) async throws -> [Transaccion]
    func listarFiltrado(
        mes: Date?,
        tipo: TipoTransaccion?,
        categoria: String?,
        texto: String?,
        limite: Int?,
        orden: OrdenTransaccion
    ) async throws -> [Transaccion]
    func categoriasDistintas() async throws -> [String]

    func insertarEn(db: GRDB.Database, _ transaccion: Transaccion) throws -> Transaccion
    func actualizarEn(db: GRDB.Database, _ transaccion: Transaccion) throws -> Transaccion
    func eliminarEn(db: GRDB.Database, id: Int64) throws
}

public enum OrdenTransaccion: Sendable {
    case fechaDesc
    case fechaAsc
    case montoDesc
    case montoAsc
}

public final class SQLiteTransactionRepository: TransactionRepository, @unchecked Sendable {
    private let manager: DatabaseManager

    public init(manager: DatabaseManager) {
        self.manager = manager
    }

    public func listar() async throws -> [Transaccion] {
        try await manager.leer { db in
            let records = try TransaccionRecord
                .order(Column("fecha").desc, Column("hora").desc)
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func obtener(id: Int64) async throws -> Transaccion? {
        try await manager.leer { db in
            try TransaccionRecord.fetchOne(db, key: id)?.aModelo()
        }
    }

    public func insertar(_ transaccion: Transaccion) async throws -> Transaccion {
        try await manager.escribir { db in
            var record = TransaccionRecord(transaccion)
            record.id = nil
            try record.insert(db)
            guard let id = record.id else {
                throw AppDatabaseError.filaNoEncontrada
            }
            var copia = transaccion
            copia.id = id
            return copia
        }
    }

    public func actualizar(_ transaccion: Transaccion) async throws -> Transaccion {
        guard let id = transaccion.id else { throw AppDatabaseError.filaNoEncontrada }
        return try await manager.escribir { db in
            var record = TransaccionRecord(transaccion)
            record.id = id
            try record.update(db)
            return transaccion
        }
    }

    public func eliminar(id: Int64) async throws {
        _ = try await manager.escribir { db in
            try TransaccionRecord.deleteOne(db, key: id)
        }
    }

    public func buscar(texto: String) async throws -> [Transaccion] {
        let patron = "%\(texto)%"
        return try await manager.leer { db in
            let records = try TransaccionRecord
                .filter(Column("concepto").like(patron))
                .fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func listarFiltrado(
        mes: Date?,
        tipo: TipoTransaccion?,
        categoria: String?,
        texto: String?,
        limite: Int?,
        orden: OrdenTransaccion
    ) async throws -> [Transaccion] {
        try await manager.leer { db in
            var request = TransaccionRecord.all()

            if let mes {
                let calendario = Calendar.current
                if let inicio = calendario.dateInterval(of: .month, for: mes)?.start,
                   let fin = calendario.dateInterval(of: .month, for: mes)?.end {
                    let inicioStr = FormatoFecha.formatearFecha(inicio)
                    let finStr = FormatoFecha.formatearFecha(fin)
                    request = request.filter(Column("fecha") >= inicioStr && Column("fecha") < finStr)
                }
            }

            if let tipo {
                request = request.filter(Column("tipo") == tipo.rawValue)
            }

            if let categoria, !categoria.isEmpty {
                request = request.filter(Column("categoria") == categoria)
            }

            if let texto, !texto.isEmpty {
                let patron = "%\(texto)%"
                request = request.filter(Column("concepto").like(patron))
            }

            switch orden {
            case .fechaDesc:
                request = request.order(Column("fecha").desc, Column("hora").desc)
            case .fechaAsc:
                request = request.order(Column("fecha").asc, Column("hora").asc)
            case .montoDesc:
                request = request.order(Column("monto").desc)
            case .montoAsc:
                request = request.order(Column("monto").asc)
            }

            if let limite {
                request = request.limit(limite)
            }

            let records = try request.fetchAll(db)
            return records.compactMap { $0.aModelo() }
        }
    }

    public func categoriasDistintas() async throws -> [String] {
        try await manager.leer { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT DISTINCT categoria
                FROM Transacciones
                WHERE categoria <> ''
                ORDER BY categoria ASC
                """)
            return rows.compactMap { $0["categoria"] as String? }
        }
    }

    public func insertarEn(db: GRDB.Database, _ transaccion: Transaccion) throws -> Transaccion {
        var record = TransaccionRecord(transaccion)
        record.id = nil
        try record.insert(db)
        guard let id = record.id else { throw AppDatabaseError.filaNoEncontrada }
        var copia = transaccion
        copia.id = id
        return copia
    }

    public func actualizarEn(db: GRDB.Database, _ transaccion: Transaccion) throws -> Transaccion {
        var record = TransaccionRecord(transaccion)
        guard let id = transaccion.id else { throw AppDatabaseError.filaNoEncontrada }
        record.id = id
        try record.update(db)
        return transaccion
    }

    public func eliminarEn(db: GRDB.Database, id: Int64) throws {
        try TransaccionRecord.deleteOne(db, key: id)
    }
}
