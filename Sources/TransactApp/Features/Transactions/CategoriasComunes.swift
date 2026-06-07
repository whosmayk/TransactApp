import Foundation
import Models

public enum CategoriasComunes {
    public static let llaves: [LocalizableKey] = [
        .categoriaComida,
        .categoriaTransporte,
        .categoriaVivienda,
        .categoriaServicios,
        .categoriaSalud,
        .categoriaEducacion,
        .categoriaEntretenimiento,
        .categoriaCompras,
        .categoriaRopa,
        .categoriaTrabajo,
        .categoriaFreelance,
        .categoriaInversiones,
        .categoriaRegalos,
        .categoriaMascotas,
        .categoriaOtros
    ]

    public static var nombresEspacioUsuario: [String] {
        llaves.map { $0.localized() }
    }

    public static let nombres: [String] = [
        "Comida",
        "Transporte",
        "Vivienda",
        "Servicios",
        "Salud",
        "Educación",
        "Entretenimiento",
        "Compras",
        "Ropa",
        "Trabajo",
        "Freelance",
        "Inversiones",
        "Regalos",
        "Mascotas",
        "Otros"
    ]
}
