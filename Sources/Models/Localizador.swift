import Foundation

public enum Localizador {
    public static let identificadorPorDefecto = "es_MX"
    public static let codigoMoneda = "MXN"

    public static var localeActual: Locale {
        Locale(identifier: UserDefaults.standard.string(forKey: "TransactApp.Locale")
                ?? identificadorPorDefecto)
    }

    public static func moneda(_ monto: Decimal, locale: Locale = localeActual) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        f.currencyCode = codigoMoneda
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        let ns = NSDecimalNumber(decimal: monto)
        return f.string(from: ns) ?? "\(monto)"
    }

    public static func monedaCorta(_ monto: Decimal, locale: Locale = localeActual) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = locale
        f.currencyCode = codigoMoneda
        f.maximumFractionDigits = 0
        f.minimumFractionDigits = 0
        let ns = NSDecimalNumber(decimal: monto)
        return f.string(from: ns) ?? "\(monto)"
    }

    public static func decimal(_ valor: Decimal, fracciones: Int = 2, locale: Locale = localeActual) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.minimumFractionDigits = fracciones
        f.maximumFractionDigits = fracciones
        let ns = NSDecimalNumber(decimal: valor)
        return f.string(from: ns) ?? "\(valor)"
    }

    public static func fechaCorta(_ fecha: Date, locale: Locale = localeActual, formato: String? = nil) -> String {
        let f = DateFormatter()
        if let formato {
            f.dateFormat = formato
        } else {
            f.dateStyle = .short
            f.timeStyle = .none
        }
        f.locale = locale
        f.calendar = Calendar(identifier: .gregorian)
        return f.string(from: fecha)
    }

    public static func fechaCompleta(_ fecha: Date, locale: Locale = localeActual) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = locale
        return f.string(from: fecha)
    }

    public static func fechaLarga(_ fecha: Date, locale: Locale = localeActual) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        f.locale = locale
        return f.string(from: fecha)
    }

    public static func mesAno(_ fecha: Date, locale: Locale = localeActual) -> String {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        f.locale = locale
        return f.string(from: fecha)
    }

    public static func diaMes(_ fecha: Date, locale: Locale = localeActual) -> String {
        let f = DateFormatter()
        f.dateFormat = "d 'de' LLLL"
        f.locale = locale
        return f.string(from: fecha)
    }

    public static func relativo(_ fecha: Date, locale: Locale = localeActual) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        f.locale = locale
        return f.localizedString(for: fecha, relativeTo: Date())
    }

    public static func horaCorta(_ fecha: Date, locale: Locale = localeActual) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = locale
        return f.string(from: fecha)
    }

    public static func bytes(_ cantidad: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: cantidad)
    }

    public static func plural(_ count: Int, singular: LocalizableKey, plural: LocalizableKey) -> String {
        if count == 1 {
            return "\(count) \(singular.localized())"
        } else {
            return "\(count) \(plural.localized())"
        }
    }
}
