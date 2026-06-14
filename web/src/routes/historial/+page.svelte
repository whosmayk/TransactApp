<script lang="ts">
	import { supabase } from '$lib/supabase'
	import { onMount } from 'svelte'

	let transacciones = $state<any[]>([])
	let loading = $state(true)
	let filterTipo = $state('')

	onMount(async () => {
		const { data } = await supabase.from('Transacciones').select('*').eq('is_deleted', 0).order('fecha', { ascending: false }).limit(100)
		transacciones = data ?? []
		loading = false
	})

	let filtered = $derived(
		!filterTipo ? transacciones : transacciones.filter(t => t.tipo === filterTipo)
	)

	function formatMoney(cents: number): string {
		const abs = Math.abs(cents)
		const sign = cents < 0 ? '-' : ''
		return sign + '$' + (abs / 100).toLocaleString('es-MX', { minimumFractionDigits: 2 })
	}
</script>

<div class="page">
	<div class="page-header">
		<h2>Historial</h2>
		<span class="page-sub">{transacciones.length} transacciones</span>
	</div>

	<div class="filters">
		<button class="filter-btn" class:active={!filterTipo} onclick={() => filterTipo = ''}>Todas</button>
		<button class="filter-btn" class:active={filterTipo === 'Ingreso'} onclick={() => filterTipo = 'Ingreso'}>
			<span class="dot green"></span> Ingresos
		</button>
		<button class="filter-btn" class:active={filterTipo === 'Gasto'} onclick={() => filterTipo = 'Gasto'}>
			<span class="dot red"></span> Gastos
		</button>
	</div>

	{#if loading}
		<div class="empty">Cargando…</div>
	{:else if filtered.length === 0}
		<div class="empty">No hay transacciones.</div>
	{:else}
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						<th><span data-label>Fecha</span></th>
						<th><span data-label>Concepto</span></th>
						<th><span data-label>Categoría</span></th>
						<th><span data-label>Método</span></th>
						<th class="amount"><span data-label>Monto</span></th>
					</tr>
				</thead>
				<tbody>
					{#each filtered as t}
						<tr>
							<td data-label="Fecha">{t.fecha}</td>
							<td data-label="Concepto">{t.concepto}</td>
							<td data-label="Categoría"><span class="cat-tag">{t.categoria}</span></td>
							<td data-label="Método">{t.metodo}</td>
							<td data-label="Monto" class="cell-amount" class:income={t.tipo === 'Ingreso'} class:expense={t.tipo === 'Gasto'}>
								{formatMoney(t.monto)}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<style>
	.page-header { margin-bottom: 1rem; display: flex; align-items: baseline; gap: 0.75rem; flex-wrap: wrap; }
	.page-header h2 { font-size: clamp(1.25rem, 4vw, 1.75rem); color: #fab387; }
	.page-sub { font-size: 0.85rem; color: #6c7086; }

	.filters { display: flex; gap: 0.5rem; margin-bottom: 1.25rem; flex-wrap: wrap; }
	.filter-btn {
		display: flex; align-items: center; gap: 0.4rem;
		padding: 0.5rem 1rem; background: #313244;
		color: #a6adc8; border: 1px solid #45475a;
		border-radius: 100px; font-size: 0.85rem; font-weight: 500;
		cursor: pointer; transition: all 0.15s; font-family: inherit;
		-webkit-tap-highlight-color: transparent;
	}
	.filter-btn.active { background: rgba(250, 179, 135, 0.12); color: #fab387; border-color: #fab387; }
	.dot { width: 8px; height: 8px; border-radius: 50%; display: inline-block; }
	.dot.green { background: #a6e3a1; }
	.dot.red { background: #f38ba8; }

	.table-wrap {
		background: #181825; border-radius: 14px;
		border: 1px solid #313244; overflow: hidden;
	}

	/* ===== Desktop: tabla normal ===== */
	@media (min-width: 640px) {
		table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
		thead th {
			padding: 0.8rem 1rem; text-align: left; font-size: 0.75rem;
			font-weight: 600; color: #6c7086; text-transform: uppercase;
			letter-spacing: 0.06em; background: #1e1e2e; border-bottom: 1px solid #313244;
			white-space: nowrap; position: sticky; top: 0;
		}
		th.amount { text-align: right; }
		tbody tr { border-bottom: 1px solid #313244; transition: background 0.1s; }
		tbody tr:last-child { border-bottom: none; }
		tbody tr:hover { background: rgba(255,255,255,0.02); }
		tbody td { padding: 0.7rem 1rem; white-space: nowrap; }
		.cell-date { color: #6c7086; font-size: 0.85rem; }
		.cell-conc { color: #cdd6f4; max-width: 250px; overflow: hidden; text-overflow: ellipsis; }
		.cat-tag {
			font-size: 0.75rem; background: #313244; color: #a6adc8;
			padding: 0.15rem 0.5rem; border-radius: 100px;
		}
		.cell-method { color: #a6adc8; font-size: 0.85rem; }
		.cell-amount { text-align: right; font-weight: 600; font-family: 'DM Mono', monospace; }
		.income { color: #a6e3a1; }
		.expense { color: #f38ba8; }
	}

	/* ===== Mobile: tarjetas apiladas ===== */
	@media (max-width: 639px) {
		thead { display: none; }
		table, tbody, tr, td { display: block; }
		table { width: 100%; }
		tr {
			padding: 0.85rem 1rem; border-bottom: 1px solid #313244;
			display: grid; grid-template-columns: 1fr 1fr; gap: 0.35rem 0.75rem;
		}
		tr:last-child { border-bottom: none; }
		td {
			padding: 0; border: none; white-space: normal;
			font-size: 0.85rem; color: #cdd6f4;
		}
		td::before {
			content: attr(data-label);
			display: block; font-size: 0.65rem; font-weight: 600;
			color: #6c7086; text-transform: uppercase;
			letter-spacing: 0.05em; margin-bottom: 0.1rem;
		}
		td:last-child {
			grid-column: 1 / -1; margin-top: 0.25rem;
			border-top: 1px solid #313244; padding-top: 0.5rem;
		}
		.cell-amount { font-family: 'DM Mono', monospace; font-weight: 600; }
		.income { color: #a6e3a1; }
		.expense { color: #f38ba8; }
		.cat-tag {
			font-size: 0.75rem; background: #313244; color: #a6adc8;
			padding: 0.15rem 0.5rem; border-radius: 100px; display: inline-block;
		}
		[data-label="Monto"] { font-weight: 600; }
	}

	.empty { color: #6c7086; padding: 3rem 0; text-align: center; }
</style>
