import Foundation

public struct Suscripcion: Identifiable, Codable, Equatable, Sendable {
    public var id: Int64?
    public var concepto: String
    public var monto: Decimal
    public var categoria: String
    public var frecuencia: FrecuenciaSuscripcion
    public var tipo: TipoTransaccion
    public var fechaInicio: Date
    public var proximoCobro: Date
    public var notas: String?
    public var duracionMeses: Int?
    public var activa: Bool
    public var notificado: Bool

    public init(
        id: Int64? = nil,
        concepto: String,
        monto: Decimal,
        categoria: String,
        frecuencia: FrecuenciaSuscripcion,
        tipo: TipoTransaccion,
        fechaInicio: Date,
        proximoCobro: Date,
        notas: String? = nil,
        duracionMeses: Int? = nil,
        activa: Bool = true,
        notificado: Bool = false
    ) {
        self.id = id
        self.concepto = concepto
        self.monto = monto
        self.categoria = categoria
        self.frecuencia = frecuencia
        self.tipo = tipo
        self.fechaInicio = fechaInicio
        self.proximoCobro = proximoCobro
        self.notas = notas
        self.duracionMeses = duracionMeses
        self.activa = activa
        self.notificado = notificado
    }

    public func montoMensual() -> Decimal {
        let meses = max(frecuencia.mesesPorCiclo, 1)
        var valor = monto / Decimal(meses)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &valor, 2, .bankers)
        return rounded
    }

    public func activaEnMes(offset: Int, referencia: Date) -> Bool {
        guard activa else { return false }
        guard let duracion = duracionMeses, duracion > 0 else { return true }
        let calendar = Calendar.current
        guard let inicioMes = calendar.dateInterval(of: .month, for: fechaInicio)?.start,
              let referenciaMes = calendar.dateInterval(of: .month, for: referencia)?.start else {
            return true
        }
        let mesesTranscurridos = calendar.dateComponents([.month], from: inicioMes, to: referenciaMes).month ?? 0
        let mesesAbsolutos = max(0, mesesTranscurridos) + offset
        return mesesAbsolutos < duracion
    }

    public func diasHastaProximoCobro(referencia: Date = Date()) -> Int {
        let calendar = Calendar.current
        let inicioDia = calendar.startOfDay(for: referencia)
        let cobroDia = calendar.startOfDay(for: proximoCobro)
        let components = calendar.dateComponents([.day], from: inicioDia, to: cobroDia)
        return components.day ?? 0
    }

    public func estaProximaAVencer(dentroDe dias: Int = 3, referencia: Date = Date()) -> Bool {
        guard activa else { return false }
        let restantes = diasHastaProximoCobro(referencia: referencia)
        return restantes >= 0 && restantes <= dias
    }

    public static func calcularProximoCobro(
        desde fechaBase: Date,
        frecuencia: FrecuenciaSuscripcion
    ) -> Date {
        let calendar = Calendar.current
        return calendar.date(
            byAdding: .month,
            value: frecuencia.mesesPorCiclo,
            to: fechaBase
        ) ?? fechaBase
    }
}
