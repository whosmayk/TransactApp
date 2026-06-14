import { supabase } from './supabase'
import type { PostgrestError } from '@supabase/supabase-js'

export interface TransaccionDB {
  uuid: string
  fecha: string
  hora: string
  concepto: string
  monto: number
  tipo: 'Ingreso' | 'Gasto'
  categoria: string
  metodo: 'Efectivo' | 'Tarjeta'
  desglose: string | null
  updated_at: number
  is_deleted: number
}

export interface PrestamoDB {
  uuid: string
  persona: string
  concepto: string
  monto: number
  tipo: 'Me deben' | 'Debo'
  fecha: string
  afecta_balance: number
  monto_pagado: number
  notas: string | null
  updated_at: number
  is_deleted: number
}

export interface SuscripcionDB {
  uuid: string
  concepto: string
  monto: number
  categoria: string
  frecuencia: 'Mensual' | 'Trimestral' | 'Anual'
  tipo: 'Ingreso' | 'Gasto'
  fecha_inicio: string
  proximo_cobro: string
  notas: string | null
  duracion_meses: number | null
  metodo_pago: string
  activa: number
  notificado: number
  updated_at: number
  is_deleted: number
}

export interface InventarioDB {
  denominacion: number
  cantidad: number
  actualizado_en: string
  updated_at: number
  is_deleted: number
}

export interface SaldoInicialDB {
  uuid: string
  id: number
  efectivo: number
  tarjeta: number
  fecha_creacion: string
  inventario_json: string
  updated_at: number
  is_deleted: number
}

export async function fetchTransacciones(since?: number): Promise<TransaccionDB[]> {
  let query = supabase.from('Transacciones').select('*').eq('is_deleted', 0).order('fecha', { ascending: false })
  if (since) query = query.gt('updated_at', since)
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function fetchPrestamos(since?: number): Promise<PrestamoDB[]> {
  let query = supabase.from('Prestamos').select('*').eq('is_deleted', 0).order('fecha', { ascending: false })
  if (since) query = query.gt('updated_at', since)
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function fetchSuscripciones(since?: number): Promise<SuscripcionDB[]> {
  let query = supabase.from('Suscripciones').select('*').eq('is_deleted', 0).order('proximo_cobro', { ascending: true })
  if (since) query = query.gt('updated_at', since)
  const { data, error } = await query
  if (error) throw error
  return data ?? []
}

export async function fetchInventario(): Promise<InventarioDB[]> {
  const { data, error } = await supabase.from('InventarioEfectivo').select('*').eq('is_deleted', 0).order('denominacion', { ascending: false })
  if (error) throw error
  return data ?? []
}

export async function fetchSaldoInicial(): Promise<SaldoInicialDB | null> {
  const { data, error } = await supabase.from('SaldoInicial').select('*').eq('is_deleted', 0).limit(1)
  if (error) throw error
  return data?.[0] ?? null
}

export async function createTransaccion(t: Omit<TransaccionDB, 'updated_at' | 'is_deleted'>): Promise<TransaccionDB> {
  const { data, error } = await supabase.from('Transacciones').insert({
    ...t,
    updated_at: Date.now(),
    is_deleted: 0
  }).select().single()
  if (error) throw error
  return data
}

export async function updateTransaccion(uuid: string, changes: Partial<TransaccionDB>): Promise<void> {
  const { error } = await supabase.from('Transacciones').update({ ...changes, updated_at: Date.now() }).eq('uuid', uuid)
  if (error) throw error
}
