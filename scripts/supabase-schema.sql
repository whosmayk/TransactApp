-- Schema para Supabase PostgreSQL
-- Ejecutar esto en el SQL Editor del dashboard de Supabase
-- Crea las tablas que coinciden con la app macOS

-- Transacciones
CREATE TABLE IF NOT EXISTS public."Transacciones" (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TEXT NOT NULL,
    hora TEXT NOT NULL,
    concepto TEXT NOT NULL,
    monto BIGINT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('Ingreso','Gasto')),
    categoria TEXT NOT NULL,
    metodo TEXT NOT NULL CHECK (metodo IN ('Efectivo','Tarjeta')),
    desglose TEXT,
    uuid TEXT NOT NULL DEFAULT '',
    updated_at BIGINT NOT NULL DEFAULT 0,
    sync_status INT NOT NULL DEFAULT 0,
    is_deleted INT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON public."Transacciones"(fecha);
CREATE UNIQUE INDEX IF NOT EXISTS idx_transacciones_uuid ON public."Transacciones"(uuid);

-- Prestamos
CREATE TABLE IF NOT EXISTS public."Prestamos" (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    persona TEXT NOT NULL,
    concepto TEXT NOT NULL,
    monto BIGINT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('Me deben','Debo')),
    fecha TEXT NOT NULL,
    "afectaBalance" INT NOT NULL DEFAULT 0,
    "montoPagado" BIGINT NOT NULL DEFAULT 0,
    notas TEXT,
    uuid TEXT NOT NULL DEFAULT '',
    updated_at BIGINT NOT NULL DEFAULT 0,
    sync_status INT NOT NULL DEFAULT 0,
    is_deleted INT NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_prestamos_uuid ON public."Prestamos"(uuid);

-- Suscripciones
CREATE TABLE IF NOT EXISTS public."Suscripciones" (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    concepto TEXT NOT NULL,
    monto BIGINT NOT NULL,
    categoria TEXT NOT NULL,
    frecuencia TEXT NOT NULL CHECK (frecuencia IN ('Mensual','Trimestral','Anual')),
    tipo TEXT NOT NULL CHECK (tipo IN ('Ingreso','Gasto')),
    "fechaInicio" TEXT NOT NULL,
    "proximoCobro" TEXT NOT NULL,
    notas TEXT,
    "duracionMeses" INT,
    "metodoPago" TEXT NOT NULL DEFAULT 'Tarjeta',
    activa INT NOT NULL DEFAULT 1,
    notificado INT NOT NULL DEFAULT 0,
    uuid TEXT NOT NULL DEFAULT '',
    updated_at BIGINT NOT NULL DEFAULT 0,
    sync_status INT NOT NULL DEFAULT 0,
    is_deleted INT NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_suscripciones_uuid ON public."Suscripciones"(uuid);

-- InventarioEfectivo
CREATE TABLE IF NOT EXISTS public."InventarioEfectivo" (
    denominacion INT PRIMARY KEY,
    cantidad INT NOT NULL DEFAULT 0,
    "actualizadoEn" TEXT NOT NULL DEFAULT '',
    uuid TEXT NOT NULL DEFAULT '',
    updated_at BIGINT NOT NULL DEFAULT 0,
    sync_status INT NOT NULL DEFAULT 0,
    is_deleted INT NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_inventarioefectivo_uuid ON public."InventarioEfectivo"(uuid);

-- SaldoInicial
CREATE TABLE IF NOT EXISTS public."SaldoInicial" (
    id INT PRIMARY KEY,
    efectivo BIGINT NOT NULL DEFAULT 0,
    tarjeta BIGINT NOT NULL DEFAULT 0,
    "fechaCreacion" TEXT NOT NULL,
    "inventarioJson" TEXT NOT NULL DEFAULT '[]',
    uuid TEXT NOT NULL DEFAULT '',
    updated_at BIGINT NOT NULL DEFAULT 0,
    sync_status INT NOT NULL DEFAULT 0,
    is_deleted INT NOT NULL DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_saldoinicial_uuid ON public."SaldoInicial"(uuid);

-- Configuracion
CREATE TABLE IF NOT EXISTS public."Configuracion" (
    clave TEXT PRIMARY KEY,
    valor TEXT NOT NULL,
    "actualizadoEn" TEXT NOT NULL DEFAULT '',
    updated_at BIGINT NOT NULL DEFAULT 0,
    sync_status INT NOT NULL DEFAULT 0,
    is_deleted INT NOT NULL DEFAULT 0
);

-- Row Level Security — deshabilitado para single-user local-first
-- Si quieres restringir por usuario, cambia a FOR ALL USING (auth.uid() = user_id)
ALTER TABLE IF EXISTS public."Transacciones" DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public."Prestamos" DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public."Suscripciones" DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public."InventarioEfectivo" DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public."SaldoInicial" DISABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public."Configuracion" DISABLE ROW LEVEL SECURITY;
