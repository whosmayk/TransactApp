import Foundation

public enum FormateadorComun {
    public static func fechaCompleta(_ fecha: Date) -> String {
        Localizador.fechaCompleta(fecha)
    }

    public static func fechaCorta(_ fecha: Date) -> String {
        Localizador.fechaCorta(fecha)
    }

    public static func relativo(_ fecha: Date) -> String {
        Localizador.relativo(fecha)
    }
}
