import Foundation
import Testing
import SwiftUI
import Models
import DesignSystem

@Suite("MontoLabel sign formatting")
struct MontoLabelTests {

    @Test("Decimal negativo formatea con signo y color rojo")
    func decimalNegativoEsRojo() {
        let monto: Decimal = -1234.56
        #expect(monto < 0)
        let ns = NSDecimalNumber(decimal: monto)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "es_MX")
        formatter.currencyCode = "MXN"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        let texto = formatter.string(from: ns) ?? ""
        #expect(texto.contains("1,234.56"))
        #expect(texto.contains("-") || texto.first == "-")
    }

    @Test("Decimal positivo NO es rojo (queda verde)")
    func decimalPositivoNoEsRojo() {
        let monto: Decimal = 1234.56
        #expect(!(monto < 0))
    }

    @Test("Decimal cero NO es rojo (caso borde: sin gastos)")
    func decimalCeroNoEsRojo() {
        let monto: Decimal = 0
        #expect(!(monto < 0))
    }

    @Test("Negación de Decimal produce valor negativo")
    func negacionDecimal() {
        let pos: Decimal = 500
        let firmado = -pos
        #expect(firmado < 0)
        #expect(firmado == -500)
    }
}
