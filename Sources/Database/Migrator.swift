import Foundation
import GRDB

public enum Migrator {
    public static let claveVersion = "db_version"
    public static let versionActual: Int = 6

    public static func aplicar(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_esquema_inicial") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS SaldoInicial (
                    id INTEGER PRIMARY KEY CHECK (id = 1),
                    efectivo REAL NOT NULL DEFAULT 0,
                    tarjeta REAL NOT NULL DEFAULT 0,
                    fechaCreacion TEXT NOT NULL,
                    inventarioJson TEXT NOT NULL DEFAULT '[]'
                );

                CREATE TABLE IF NOT EXISTS Transacciones (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    fecha TEXT NOT NULL,
                    hora TEXT NOT NULL,
                    concepto TEXT NOT NULL,
                    monto REAL NOT NULL,
                    tipo TEXT NOT NULL CHECK (tipo IN ('Ingreso','Gasto')),
                    categoria TEXT NOT NULL,
                    metodo TEXT NOT NULL CHECK (metodo IN ('Efectivo','Tarjeta')),
                    desglose TEXT
                );
                CREATE INDEX IF NOT EXISTS idx_trans_fecha ON Transacciones(fecha);
                CREATE INDEX IF NOT EXISTS idx_trans_tipo  ON Transacciones(tipo);

                CREATE TABLE IF NOT EXISTS InventarioEfectivo (
                    denominacion INTEGER PRIMARY KEY,
                    cantidad INTEGER NOT NULL DEFAULT 0,
                    actualizadoEn TEXT NOT NULL
                );

                CREATE TABLE IF NOT EXISTS Prestamos (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    persona TEXT NOT NULL,
                    concepto TEXT NOT NULL,
                    monto REAL NOT NULL,
                    tipo TEXT NOT NULL CHECK (tipo IN ('Me deben','Debo')),
                    fecha TEXT NOT NULL,
                    afectaBalance INTEGER NOT NULL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS Suscripciones (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    concepto TEXT NOT NULL,
                    monto REAL NOT NULL,
                    categoria TEXT NOT NULL,
                    frecuencia TEXT NOT NULL
                        CHECK (frecuencia IN ('Mensual','Trimestral','Anual')),
                    tipo TEXT NOT NULL CHECK (tipo IN ('Ingreso','Gasto')),
                    fechaInicio TEXT NOT NULL,
                    proximoCobro TEXT NOT NULL,
                    notas TEXT,
                    duracionMeses INTEGER,
                    activa INTEGER NOT NULL DEFAULT 1,
                    notificado INTEGER NOT NULL DEFAULT 0
                );

                CREATE TABLE IF NOT EXISTS Metadata (
                    clave TEXT PRIMARY KEY,
                    valor TEXT NOT NULL
                );
            """)
        }

        migrator.registerMigration("v2_prestamos_pagos_notas") { db in
            try db.execute(sql: """
                ALTER TABLE Prestamos ADD COLUMN montoPagado REAL NOT NULL DEFAULT 0;
                ALTER TABLE Prestamos ADD COLUMN notas TEXT;
            """)
        }

        migrator.registerMigration("v3_configuracion") { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS Configuracion (
                    clave TEXT PRIMARY KEY,
                    valor TEXT NOT NULL,
                    actualizadoEn TEXT NOT NULL
                );
            """)
        }

        migrator.registerMigration("v4_normalizar_montos_transacciones") { db in
            try db.execute(sql: """
                UPDATE Transacciones SET monto = ABS(monto) WHERE monto < 0;
                """)
        }

        migrator.registerMigration("v5_montos_a_centavos") { db in
            let tablasMontos = [
                ("Transacciones", "monto"),
                ("Prestamos", "monto"),
                ("Prestamos", "montoPagado"),
                ("Suscripciones", "monto"),
                ("SaldoInicial", "efectivo"),
                ("SaldoInicial", "tarjeta"),
            ]
            for (tabla, columna) in tablasMontos {
                let tempCol = "\(columna)_temp"
                try db.execute(sql: """
                    ALTER TABLE \(tabla) ADD COLUMN \(tempCol) INTEGER NOT NULL DEFAULT 0;
                    """)
                try db.execute(sql: """
                    UPDATE \(tabla) SET \(tempCol) = CAST(ROUND(\(columna) * 100) AS INTEGER);
                    """)
                try db.execute(sql: """
                    ALTER TABLE \(tabla) DROP COLUMN \(columna);
                    """)
                try db.execute(sql: """
                    ALTER TABLE \(tabla) RENAME COLUMN \(tempCol) TO \(columna);
                    """)
            }
        }

        migrator.registerMigration("v6_metodo_pago_suscripciones") { db in
            try db.execute(sql: """
                ALTER TABLE Suscripciones ADD COLUMN metodoPago TEXT NOT NULL DEFAULT 'Tarjeta';
                """)
        }

        try migrator.migrate(dbQueue)
    }

    public static func revertirV5(_ dbQueue: DatabaseQueue) throws {
        try dbQueue.writeWithoutTransaction { db in
            let tablasMontos = [
                ("Transacciones", "monto"),
                ("Prestamos", "monto"),
                ("Prestamos", "montoPagado"),
                ("Suscripciones", "monto"),
                ("SaldoInicial", "efectivo"),
                ("SaldoInicial", "tarjeta"),
            ]
            for (tabla, columna) in tablasMontos {
                let tempCol = "\(columna)_temp"
                try db.execute(sql: """
                    ALTER TABLE \(tabla) ADD COLUMN \(tempCol) REAL NOT NULL DEFAULT 0;
                    """)
                try db.execute(sql: """
                    UPDATE \(tabla) SET \(tempCol) = CAST(\(columna) AS REAL) / 100.0;
                    """)
                try db.execute(sql: """
                    ALTER TABLE \(tabla) DROP COLUMN \(columna);
                    """)
                try db.execute(sql: """
                    ALTER TABLE \(tabla) RENAME COLUMN \(tempCol) TO \(columna);
                    """)
            }
        }
    }
}
