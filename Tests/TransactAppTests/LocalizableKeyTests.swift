import XCTest
@testable import Models
import Foundation

final class LocalizableKeyTests: XCTestCase {
    func test_es_localiza_todos_los_keys() throws {
        let bundle = Bundle.module
        let keys = LocalizableKey.allCases
        XCTAssertGreaterThan(keys.count, 0, "LocalizableKey debe tener al menos un caso")
        for key in keys {
            let raw = key.rawValue
            let localized = bundle.localizedString(forKey: raw, value: nil, table: nil)
            XCTAssertNotEqual(localized, raw, "Key \(raw) no localizada en bundle")
        }
    }

    func test_es_titulo_TipoTransaccion() {
        XCTAssertEqual(TipoTransaccion.ingreso.titulo, "Ingreso")
        XCTAssertEqual(TipoTransaccion.gasto.titulo, "Gasto")
    }

    func test_es_titulo_MetodoPago() {
        XCTAssertEqual(MetodoPago.efectivo.titulo, "Efectivo")
        XCTAssertEqual(MetodoPago.tarjeta.titulo, "Tarjeta")
    }

    func test_es_titulo_TipoPrestamo() {
        XCTAssertEqual(TipoPrestamo.meDeben.titulo, "Me deben")
        XCTAssertEqual(TipoPrestamo.debo.titulo, "Debo")
    }

    func test_es_titulo_FrecuenciaSuscripcion() {
        XCTAssertEqual(FrecuenciaSuscripcion.mensual.titulo, "Mensual")
        XCTAssertEqual(FrecuenciaSuscripcion.trimestral.titulo, "Trimestral")
        XCTAssertEqual(FrecuenciaSuscripcion.anual.titulo, "Anual")
    }

    func test_es_titulo_EstadoProyeccion() {
        XCTAssertEqual(EstadoProyeccion.enMeta.titulo, "En meta")
        XCTAssertEqual(EstadoProyeccion.cerca.titulo, "Cerca")
        XCTAssertEqual(EstadoProyeccion.enRiesgo.titulo, "En riesgo")
    }

    func test_es_Frecuencia_mesesPorCiclo_preservado() {
        XCTAssertEqual(FrecuenciaSuscripcion.mensual.mesesPorCiclo, 1)
        XCTAssertEqual(FrecuenciaSuscripcion.trimestral.mesesPorCiclo, 3)
        XCTAssertEqual(FrecuenciaSuscripcion.anual.mesesPorCiclo, 12)
    }

    func test_es_localized_con_argumentos() {
        let resultado = LocalizableKey.dashboardPrestamosPendientes.localized(5)
        XCTAssertEqual(resultado, "5 pendientes")
    }

    func test_es_localized_sin_argumentos() {
        let resultado = LocalizableKey.appName.localized()
        XCTAssertEqual(resultado, "TransactApp")
    }
}
