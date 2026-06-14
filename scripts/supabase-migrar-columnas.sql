-- Migración: renombrar columnas a camelCase y comillar identificadores
-- Ejecutar en Supabase Dashboard → SQL Editor
-- No pierde datos existentes

-- Prestamos
ALTER TABLE IF EXISTS public."Prestamos" RENAME COLUMN "afectabalance" TO "afectaBalance";
ALTER TABLE IF EXISTS public."Prestamos" RENAME COLUMN "montopagado" TO "montoPagado";

-- Suscripciones
ALTER TABLE IF EXISTS public."Suscripciones" RENAME COLUMN "fechainicio" TO "fechaInicio";
ALTER TABLE IF EXISTS public."Suscripciones" RENAME COLUMN "proximocobro" TO "proximoCobro";
ALTER TABLE IF EXISTS public."Suscripciones" RENAME COLUMN "duracionmeses" TO "duracionMeses";
ALTER TABLE IF EXISTS public."Suscripciones" RENAME COLUMN "metodopago" TO "metodoPago";

-- SaldoInicial
ALTER TABLE IF EXISTS public."SaldoInicial" RENAME COLUMN "fechacreacion" TO "fechaCreacion";
ALTER TABLE IF EXISTS public."SaldoInicial" RENAME COLUMN "inventariojson" TO "inventarioJson";

-- InventarioEfectivo
ALTER TABLE IF EXISTS public."InventarioEfectivo" RENAME COLUMN "actualizadoen" TO "actualizadoEn";

-- Configuracion
ALTER TABLE IF EXISTS public."Configuracion" RENAME COLUMN "actualizadoen" TO "actualizadoEn";

-- Limpiar datos de prueba (si existen)
DELETE FROM public."Suscripciones" WHERE uuid LIKE 'test-%';
DELETE FROM public."Prestamos" WHERE uuid LIKE 'test-%';

-- Eliminar datos parciales de sync anterior para que el próximo push sea limpio
-- Opcional: si quieres mantener las 159 transacciones, omite esta línea
-- DELETE FROM public."Transacciones";
