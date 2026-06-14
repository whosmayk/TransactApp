-- Migración: agregar uuid a InventarioEfectivo
-- Ejecutar en Supabase Dashboard → SQL Editor
-- Requisito: InventarioEfectivo debe tener columna uuid para sincronización

ALTER TABLE IF EXISTS public."InventarioEfectivo" ADD COLUMN IF NOT EXISTS uuid TEXT NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_inventarioefectivo_uuid ON public."InventarioEfectivo"(uuid);

-- Asignar UUIDs a filas existentes que no tengan uno
UPDATE public."InventarioEfectivo" SET uuid = gen_random_uuid()::text WHERE uuid = '';
