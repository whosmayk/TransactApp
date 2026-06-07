import XCTest
@testable import Models
import Foundation

final class LocalizadorTests: XCTestCase {
    func test_moneda_esMX_formato_MXN() {
        let resultado = Localizador.moneda(Decimal(string: "1000")!, locale: Locale(identifier: "es_MX"))
        XCTAssertEqual(resultado, "$1,000.00")
    }

    func test_moneda_esMX_negativo() {
        let resultado = Localizador.moneda(Decimal(string: "-1500.50")!, locale: Locale(identifier: "es_MX"))
        XCTAssertTrue(resultado.contains("1,500.50"))
        XCTAssertTrue(resultado.contains("-") || resultado.contains("("))
    }

    func test_moneda_enUS() {
        let resultado = Localizador.moneda(Decimal(string: "1000")!, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(resultado, "MX$1,000.00")
    }

    func test_monedaCorta_sin_decimales() {
        let resultado = Localizador.monedaCorta(Decimal(string: "1234")!, locale: Locale(identifier: "es_MX"))
        XCTAssertEqual(resultado, "$1,234")
    }

    func test_decimal_2_fracciones() {
        let resultado = Localizador.decimal(Decimal(string: "1234.5")!, locale: Locale(identifier: "es_MX"))
        XCTAssertEqual(resultado, "1,234.50")
    }

    func test_decimal_0_fracciones() {
        let resultado = Localizador.decimal(Decimal(string: "1234")!, fracciones: 0, locale: Locale(identifier: "es_MX"))
        XCTAssertEqual(resultado, "1,234")
    }

    func test_fechaCorta_esMX() {
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 6
        componentes.day = 6
        let fecha = Calendar(identifier: .gregorian).date(from: componentes)!
        let resultado = Localizador.fechaCorta(fecha, locale: Locale(identifier: "es_MX"))
        XCTAssertTrue(resultado.contains("6"), "Debe contener día 6, fue: \(resultado)")
        XCTAssertTrue(resultado.contains("26"), "Debe contener año 26 (short), fue: \(resultado)")
    }

    func test_fechaCorta_conFormatoCustom_esMX() {
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 6
        componentes.day = 6
        let fecha = Calendar(identifier: .gregorian).date(from: componentes)!
        let resultado = Localizador.fechaCorta(fecha, locale: Locale(identifier: "es_MX"), formato: "d MMM")
        XCTAssertFalse(resultado.isEmpty, "fechaCorta con formato custom NO debe devolver string vacío en es_MX (regression: timeStyle + dateFormat chocan). Fue: '\(resultado)'")
        XCTAssertTrue(resultado.contains("6"), "Debe contener día 6, fue: \(resultado)")
        XCTAssertTrue(resultado.lowercased().contains("jun"), "Debe contener mes jun, fue: \(resultado)")
    }

    func test_horaCorta_esMX_formatoCorrecto() {
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 6
        componentes.day = 7
        componentes.hour = 14
        componentes.minute = 32
        let fecha = Calendar(identifier: .gregorian).date(from: componentes)!
        let resultado = Localizador.horaCorta(fecha, locale: Locale(identifier: "es_MX"))
        XCTAssertFalse(resultado.isEmpty, "horaCorta no debe devolver vacío. Fue: '\(resultado)'")
        XCTAssertTrue(resultado.contains("14") || resultado.contains("2"), "Debe contener hora (14 o 2 PM). Fue: '\(resultado)'")
        XCTAssertTrue(resultado.contains("32"), "Debe contener minutos 32. Fue: '\(resultado)'")
    }

    func test_mesAno_esMX_contiene_mes() {
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 6
        componentes.day = 15
        let fecha = Calendar(identifier: .gregorian).date(from: componentes)!
        let resultado = Localizador.mesAno(fecha, locale: Locale(identifier: "es_MX"))
        XCTAssertTrue(resultado.contains("2026"))
        XCTAssertFalse(resultado.isEmpty)
    }

    func test_diaMes_esMX() {
        var componentes = DateComponents()
        componentes.year = 2026
        componentes.month = 6
        componentes.day = 15
        let fecha = Calendar(identifier: .gregorian).date(from: componentes)!
        let resultado = Localizador.diaMes(fecha, locale: Locale(identifier: "es_MX"))
        XCTAssertTrue(resultado.contains("15"))
        XCTAssertTrue(resultado.contains("2026") == false, "diaMes solo debe traer día y mes, no año")
    }

    func test_bytes_formato_humano() {
        let kb = Localizador.bytes(2048)
        XCTAssertTrue(kb.contains("KB") || kb.contains("kB"))
    }

    func test_plural_singular() {
        let resultado = Localizador.plural(1, singular: .commonDiaSingular, plural: .commonDiaPlural)
        XCTAssertEqual(resultado, "1 día")
    }

    func test_plural_plural() {
        let resultado = Localizador.plural(3, singular: .commonDiaSingular, plural: .commonDiaPlural)
        XCTAssertEqual(resultado, "3 días")
    }
}
