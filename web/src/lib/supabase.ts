import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://hiloeceyeyrzbiecnuvc.supabase.co'
const supabaseAnonKey = 'sb_publishable_pM6JK32bWLKcnUoO57Yrqg_lCPt7f2U'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
