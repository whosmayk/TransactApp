import Foundation
import GRDB
import os

/// Emits a `Void` value every time the observed SQLite tables change.
///
/// The observation is driven by GRDB's `ValueObservation` and fires once per
/// committed transaction that touches any of the tracked tables. A debounce
/// window coalesces bursts (e.g. a Windows-DB import that writes 130 rows in
/// a single transaction) into a single downstream event.
///
/// Lifetime:
/// - Hold one `DatabaseObserver` for the lifetime of the `DatabaseManager`.
/// - If the underlying `dbQueue` is swapped (e.g. by
///   `DatabaseManager.reemplazarArchivo`), create a new `DatabaseObserver`
///   bound to the new queue and discard the old one.
public final class DatabaseObserver: @unchecked Sendable {
    /// The set of tables the observer reacts to. These cover every user-
    /// mutable table in the schema (see `Sources/Database/Migrator.swift`).
    public static let tablasPorDefecto: [String] = [
        "Transacciones",
        "Prestamos",
        "Suscripciones",
        "InventarioEfectivo",
        "SaldoInicial",
        "Configuracion"
    ]

    public let dbQueue: DatabaseQueue
    public let tablas: [String]
    public let debounceMs: Int

    public init(
        dbQueue: DatabaseQueue,
        tablas: [String] = DatabaseObserver.tablasPorDefecto,
        debounceMs: Int = 150
    ) {
        self.dbQueue = dbQueue
        self.tablas = tablas
        self.debounceMs = debounceMs
    }

    /// Returns an `AsyncStream<Void>` that yields once per detected change.
    ///
    /// The first event GRDB produces (the "initial value" emitted when the
    /// observation starts) is consumed and discarded. Subsequent events are
    /// the actual change notifications. They pass through a `debounceMs`
    /// window so back-to-back transactions collapse into a single yield.
    ///
    /// Cancelling the consuming `Task` cancels the underlying GRDB
    /// observation and finishes the stream.
    public func observe() -> AsyncStream<Void> {
        let queue = dbQueue
        let tables = tablas
        let debounce = debounceMs

        return AsyncStream { continuation in
            let observation = ValueObservation.tracking(
                regions: tables.map { Table($0) },
                fetch: { _ in () }
            )

            let task = Task {
                var iterator = observation.values(in: queue).makeAsyncIterator()
                do {
                    // Descarta la primera emisión (valor inicial al suscribirse).
                    _ = try await iterator.next()
                    while !Task.isCancelled {
                        guard try await iterator.next() != nil else { break }
                        if debounce > 0 {
                            try? await Task.sleep(for: .milliseconds(debounce))
                            if Task.isCancelled { break }
                        }
                        continuation.yield(())
                    }
                } catch is CancellationError {
                    // Salida silenciosa
                } catch {
                    let logger = Logger(subsystem: "com.transactapp.macos", category: "DatabaseObserver")
                    logger.error("DatabaseObserver terminó con error: \(error.localizedDescription, privacy: .public)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
