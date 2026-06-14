<script lang="ts">
	import { supabase } from '$lib/supabase'
	import { onMount } from 'svelte'

	let transacciones = $state<any[]>([])
	let prestamos = $state<any[]>([])
	let suscripciones = $state<any[]>([])
	let inventario = $state<any[]>([])
	let saldoInicial = $state<any>(null)
	let loading = $state(true)

	function loadData() {
		Promise.all([
			supabase.from('Transacciones').select('*').eq('is_deleted', 0).order('fecha', { ascending: false }),
			supabase.from('Prestamos').select('*').eq('is_deleted', 0).order('fecha', { ascending: false }),
			supabase.from('Suscripciones').select('*').eq('is_deleted', 0).order('proximoCobro', { ascending: true }),
			supabase.from('InventarioEfectivo').select('*').eq('is_deleted', 0).order('denominacion', { ascending: false }),
			supabase.from('SaldoInicial').select('*').eq('is_deleted', 0).limit(1)
		]).then(([t, p, s, i, si]) => {
			transacciones = t.data ?? []
			prestamos = p.data ?? []
			suscripciones = s.data ?? []
			inventario = i.data ?? []
			saldoInicial = si.data?.[0] ?? null
			loading = false
		})
	}

	onMount(() => {
		loadData()
		const channel = supabase.channel('dashboard-changes')
		channel.on('postgres_changes', { event: '*', schema: 'public' }, () => loadData())
		channel.subscribe()
		return () => { supabase.removeChannel(channel) }
	})

	function formatMoney(cents: number): string {
		const abs = Math.abs(cents)
		const sign = cents < 0 ? '-' : ''
		return sign + '$' + (abs / 100).toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
	}

	function calcTotal() {
		let efectivo = saldoInicial?.efectivo ?? 0
		let tarjeta = saldoInicial?.tarjeta ?? 0
		for (const t of transacciones) {
			if (t.metodo === 'Efectivo') {
				efectivo += t.tipo === 'Ingreso' ? t.monto : -t.monto
			} else {
				tarjeta += t.tipo === 'Ingreso' ? t.monto : -t.monto
			}
		}
		let deudas = 0
		for (const p of prestamos) {
			if (p.tipo === 'Debo' && p.afectaBalance) {
				deudas += (p.monto - p.montoPagado)
			}
		}
		return { efectivo, tarjeta, total: efectivo + tarjeta, real: efectivo + tarjeta - deudas }
	}

	const totales = $derived(calcTotal())
</script>

<div class="page">
	<div class="page-header">
		<h2>Dashboard</h2>
		<span class="page-sub">Resumen financiero</span>
	</div>

	{#if loading}
		<div class="empty">Cargando datos…</div>
	{:else}
		<div class="summary-grid">
			<div class="summary-card">
				<div class="summary-label">Total</div>
				<div class="summary-value">{formatMoney(totales.total)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Efectivo</div>
				<div class="summary-value accent">{formatMoney(totales.efectivo)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Tarjeta</div>
				<div class="summary-value accent">{formatMoney(totales.tarjeta)}</div>
			</div>
			<div class="summary-card">
				<div class="summary-label">Balance Real</div>
				<div class="summary-value" class:negative={totales.real < 0}>{formatMoney(totales.real)}</div>
			</div>
		</div>

		{#if inventario.length > 0}
			<section class="section">
				<h3>Inventario</h3>
				<div class="inv-grid">
					{#each inventario as item}
						<div class="inv-chip">
							<span class="inv-denom">${item.denominacion}</span>
							<span class="inv-count">×{item.cantidad}</span>
							<span class="inv-sub">{formatMoney(item.denominacion * item.cantidad * 100)}</span>
						</div>
					{/each}
				</div>
			</section>
		{/if}

		<div class="grid-2col">
			<section class="section">
				<h3>Últimas transacciones</h3>
				{#if transacciones.length === 0}
					<p class="empty-sm">Sin transacciones</p>
				{:else}
					{#each transacciones.slice(0, 10) as t}
						<div class="row">
							<span class="row-date">{t.fecha}</span>
							<span class="row-conc">{t.concepto}</span>
							<span class="row-amount" class:income={t.tipo === 'Ingreso'} class:expense={t.tipo === 'Gasto'}>
								{formatMoney(t.monto)}
							</span>
						</div>
					{/each}
				{/if}
			</section>

			<div class="grid-stack">
				<section class="section">
					<h3>Préstamos</h3>
					{#if prestamos.length === 0}
						<p class="empty-sm">Sin préstamos</p>
					{:else}
						{#each prestamos.slice(0, 5) as p}
							<div class="row">
								<span class="row-conc">{p.persona}: {p.concepto}</span>
								<span class="row-amount">{formatMoney(p.monto)}</span>
							</div>
						{/each}
					{/if}
				</section>

				<section class="section">
					<h3>Suscripciones próximas</h3>
					{#if suscripciones.filter(s => s.activa).length === 0}
						<p class="empty-sm">Sin suscripciones activas</p>
					{:else}
						{#each suscripciones.filter(s => s.activa).slice(0, 5) as s}
							<div class="row">
								<span class="row-conc">{s.concepto}</span>
								<span class="row-amount">{formatMoney(s.monto)}</span>
							</div>
						{/each}
					{/if}
				</section>
			</div>
		</div>
	{/if}
</div>

<style>
	.page-header { margin-bottom: 1.5rem; }
	.page-header h2 { font-size: clamp(1.25rem, 4vw, 1.75rem); color: #fab387; }
	.page-sub { font-size: 0.85rem; color: #6c7086; margin-top: 0.15rem; display: block; }

	/* summary cards */
	.summary-grid {
		display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;
		margin-bottom: 1.5rem;
	}
	@media (min-width: 640px) { .summary-grid { grid-template-columns: repeat(4, 1fr); } }
	.summary-card {
		background: #181825; padding: 1.25rem; border-radius: 14px;
		border: 1px solid #313244;
	}
	.summary-label { font-size: 0.75rem; color: #6c7086; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 0.35rem; font-weight: 500; }
	.summary-value { font-size: clamp(1.2rem, 4vw, 1.65rem); font-weight: 700; color: #cdd6f4; font-family: 'DM Mono', monospace; }
	.summary-value.accent { color: #fab387; }
	.summary-value.negative { color: #f38ba8; }

	/* sections */
	.section {
		background: #181825; padding: 1.25rem; border-radius: 14px;
		border: 1px solid #313244; margin-bottom: 1rem;
	}
	.section h3 { font-size: 0.95rem; color: #cdd6f4; margin-bottom: 0.75rem; }

	/* inventory */
	.inv-grid { display: flex; flex-wrap: wrap; gap: 0.5rem; }
	.inv-chip {
		background: #1e1e2e; padding: 0.4rem 0.65rem; border-radius: 8px;
		display: flex; gap: 0.35rem; align-items: center; font-size: 0.85rem;
		border: 1px solid #313244;
	}
	.inv-denom { font-weight: 700; color: #fab387; }
	.inv-count { color: #a6adc8; }
	.inv-sub { color: #585b70; font-size: 0.75rem; }

	/* rows */
	.row {
		display: flex; gap: 0.5rem; padding: 0.5rem 0;
		border-bottom: 1px solid #313244; align-items: flex-start;
		font-size: 0.9rem;
	}
	.row:last-child { border-bottom: none; }
	.row-date { color: #6c7086; font-size: 0.8rem; width: 75px; flex-shrink: 0; padding-top: 0.1rem; }
	.row-conc { flex: 1; color: #cdd6f4; min-width: 0; word-break: break-word; }
	.row-amount { font-weight: 600; font-family: 'DM Mono', monospace; white-space: nowrap; margin-left: auto; }
	.income { color: #a6e3a1; }
	.expense { color: #f38ba8; }

	@media (max-width: 400px) {
		.row { flex-wrap: wrap; gap: 0.15rem 0.5rem; padding: 0.6rem 0; }
		.row-date { width: auto; font-size: 0.75rem; }
		.row-conc { order: 1; width: 100%; font-size: 0.85rem; }
		.row-amount { order: 2; margin-left: 0; font-size: 0.85rem; }
	}

	/* grid */
	.grid-2col {
		display: grid; grid-template-columns: 1fr; gap: 1rem;
	}
	@media (min-width: 768px) { .grid-2col { grid-template-columns: 1fr 1fr; } }
	.grid-stack { display: flex; flex-direction: column; gap: 1rem; }

	/* empty */
	.empty { color: #6c7086; padding: 3rem 0; text-align: center; }
	.empty-sm { color: #585b70; font-size: 0.85rem; padding: 0.5rem 0; }
</style>
