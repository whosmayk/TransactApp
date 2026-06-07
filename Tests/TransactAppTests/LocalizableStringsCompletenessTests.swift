import XCTest
@testable import Models
import Foundation

final class LocalizableStringsCompletenessTests: XCTestCase {
    func test_es_y_en_tienen_mismos_keys() throws {
        let esBundle = Bundle.module
        let enBundle = try bundle(for: "en")
        let esKeys = keys(in: esBundle, table: "Localizable")
        let enKeys = keys(in: enBundle, table: "Localizable")
        let soloEnEs = esKeys.subtracting(enKeys)
        let soloEnEn = enKeys.subtracting(esKeys)
        XCTAssertTrue(soloEnEs.isEmpty, "Keys solo en es: \(soloEnEs.sorted())")
        XCTAssertTrue(soloEnEn.isEmpty, "Keys solo en en: \(soloEnEn.sorted())")
    }

    func test_es_localiza_LocalizableKey_todos() {
        for key in LocalizableKey.allCases {
            let raw = key.rawValue
            let localized = Bundle.module.localizedString(forKey: raw, value: nil, table: "Localizable")
            XCTAssertNotEqual(localized, raw, "Key \(raw) no localizada en es")
        }
    }

    private func keys(in bundle: Bundle, table: String) -> Set<String> {
        guard let url = bundle.url(forResource: table, withExtension: "strings") else {
            return []
        }
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        var result = Set<String>()
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("/*"), !trimmed.hasPrefix("//") else { return }
            guard let equalIndex = trimmed.firstIndex(of: "=") else { return }
            let keyPart = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            let cleaned = keyPart.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if !cleaned.isEmpty {
                result.insert(cleaned)
            }
        }
        return result
    }

    private func bundle(for language: String) throws -> Bundle {
        guard let url = Bundle.module.url(forResource: language, withExtension: "lproj"),
              let bundle = Bundle(url: url) else {
            XCTFail("No se encontró \(language).lproj")
            throw NSError(domain: "test", code: 1)
        }
        return bundle
    }
}
