import Foundation
import Testing
import GRDB
import Database
import Models

@Suite("DatabaseObserver")
struct DatabaseObserverTests {

    @Test("Observa UPDATE en una tabla trackeada y emite el evento")
    func observerEmitsOnTrackedTableUpdate() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("obs.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let observer = manager.crearObservador(debounceMs: 50)
        let counter = AsyncStreamCounter()

        let consumer = Task {
            for await _ in observer.observe() {
                await counter.increment()
            }
        }
        // Damos tiempo a que se consuma el "initial value" sin contar.
        try await Task.sleep(for: .milliseconds(200))
        let baseline = await counter.value

        // Escritura en tabla trackeada
        try await manager.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["2026-06-07", "12:00", "test", 100.0, "Ingreso", "Trabajo", "Efectivo"])
        }
        // Debounce (50 ms) + yield + slack
        try await Task.sleep(for: .milliseconds(250))
        consumer.cancel()
        let total = await counter.value
        #expect(total > baseline, "Tras UPDATE en tabla trackeada debe aumentar el contador (baseline=\(baseline), total=\(total))")
    }

    @Test("100 inserciones seguidas coalescen por el debounce")
    func debounceCoalesceBursts() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("burst.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let observer = manager.crearObservador(debounceMs: 200)
        let stream = observer.observe()
        let counter = AsyncStreamCounter()

        let consumer = Task {
            for await _ in stream {
                await counter.increment()
            }
        }

        // Dejamos pasar el initial value
        try await Task.sleep(for: .milliseconds(50))

        // Ráfaga de 50 inserciones
        for i in 0..<50 {
            try await manager.escribir { db in
                try db.execute(sql: """
                    INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: ["2026-06-07", "12:00", "k\(i)", 1.0, "Ingreso", "X", "Efectivo"])
            }
        }
        // Esperamos un poco más que el debounce + yield
        try await Task.sleep(for: .milliseconds(500))

        consumer.cancel()
        let fires = await counter.value
        #expect(fires >= 1, "Debe emitir al menos 1 evento tras ráfaga")
        #expect(fires <= 5, "El debounce de 200 ms debe coalescer 50 inserciones en ≤ 5 eventos (recibidos: \(fires))")
    }

    @Test("No emite si no hay cambios")
    func noFiresWithoutChanges() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("quiet.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let observer = manager.crearObservador(debounceMs: 50)
        let stream = observer.observe()
        let counter = AsyncStreamCounter()

        let consumer = Task {
            for await _ in stream {
                await counter.increment()
            }
        }
        try await Task.sleep(for: .milliseconds(500))
        consumer.cancel()

        let fires = await counter.value
        #expect(fires == 0, "Sin cambios no debe haber emisiones (recibidos: \(fires))")
    }

    @Test("Cancelar el consumer detiene la observación sin fugas")
    func cancellingConsumerStopsObservation() async throws {
        let tmpDir = try directorioTemporal()
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let dbPath = tmpDir.appendingPathComponent("cancel.sqlite")
        let manager = try DatabaseManager(ruta: dbPath)
        let observer = manager.crearObservador(debounceMs: 50)
        let stream = observer.observe()
        let counter = AsyncStreamCounter()

        let consumer = Task {
            for await _ in stream {
                await counter.increment()
            }
        }
        try await Task.sleep(for: .milliseconds(100))
        consumer.cancel()
        try await Task.sleep(for: .milliseconds(100))

        // Tras cancelar, escribimos y NO debería aumentar el counter
        let baselineFires = await counter.value
        try await manager.escribir { db in
            try db.execute(sql: """
                INSERT INTO Transacciones (fecha, hora, concepto, monto, tipo, categoria, metodo)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["2026-06-07", "12:00", "post_cancel", 1.0, "Ingreso", "X", "Efectivo"])
        }
        try await Task.sleep(for: .milliseconds(250))
        let afterFires = await counter.value
        #expect(afterFires == baselineFires,
                "Tras cancelar no deberían registrarse nuevos eventos (baseline=\(baselineFires), final=\(afterFires))")
    }
}

// MARK: - Helpers de test

private actor AsyncStreamCounter {
    private(set) var value: Int = 0
    func increment() { value += 1 }
}

private final class AsyncStreamCollector<T>: @unchecked Sendable {
    private var buffer: [T] = []
    private let lock = NSLock()
    func append(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(item)
    }
    func snapshot() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
}
