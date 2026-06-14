<script lang="ts">
	import { supabase } from '$lib/supabase'
	import { onMount } from 'svelte'

	let prestamos = $state<any[]>([])
	let loading = $state(true)

	onMount(async () => {
		const { data } = await supabase.from('Prestamos').select('*').order('fecha', { ascending: false })
		prestamos = data ?? []
		loading = false
	})

	function formatMoney(cents: number): string {
		return '$' + (cents / 100).toLocaleString('es-MX', { minimumFractionDigits: 2 })
	}
</script>

<div class="page">
	<div class="page-header">
		<h2>Préstamos</h2>
		<span class="page-sub">{prestamos.length} registros</span>
	</div>

	{#if loading}
		<div class="empty">Cargando…</div>
	{:else if prestamos.length === 0}
		<div class="empty">No hay préstamos.</div>
	{:else}
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						<th><span data-label>Persona</span></th>
						<th><span data-label>Concepto</span></th>
						<th><span data-label>Monto</span></th>
						<th><span data-label>Tipo</span></th>
						<th><span data-label>Pagado</span></th>
						<th class="amount"><span data-label>Pendiente</span></th>
					</tr>
				</thead>
				<tbody>
					{#each prestamos as p}
						<tr>
							<td data-label="Persona" class="cell-person">{p.persona}</td>
							<td data-label="Concepto">{p.concepto}</td>
							<td data-label="Monto">{formatMoney(p.monto)}</td>
							<td data-label="Tipo">
								<span class="badge" class:debt={p.tipo === 'Debo'} class:owe={p.tipo === 'Me deben'}>
									{p.tipo}
								</span>
							</td>
							<td data-label="Pagado">{formatMoney(p.montoPagado)}</td>
							<td data-label="Pendiente" class="cell-amount">{formatMoney(Math.max(0, p.monto - p.montoPagado))}</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<style>
	.page-header { margin-bottom: 1.5rem; display: flex; align-items: baseline; gap: 0.75rem; flex-wrap: wrap; }
	.page-header h2 { font-size: clamp(1.25rem, 4vw, 1.75rem); color: #fab387; }
	.page-sub { font-size: 0.85rem; color: #6c7086; }

	.table-wrap {
		background: #181825; border-radius: 14px;
		border: 1px solid #313244; overflow: hidden;
	}

	@media (min-width: 640px) {
		table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
		thead th {
			padding: 0.8rem 1rem; text-align: left; font-size: 0.75rem;
			font-weight: 600; color: #6c7086; text-transform: uppercase;
			letter-spacing: 0.06em; background: #1e1e2e; border-bottom: 1px solid #313244;
			white-space: nowrap;
		}
		th.amount { text-align: right; }
		tbody tr { border-bottom: 1px solid #313244; transition: background 0.1s; }
		tbody tr:last-child { border-bottom: none; }
		tbody tr:hover { background: rgba(255,255,255,0.02); }
		tbody td { padding: 0.7rem 1rem; white-space: nowrap; color: #cdd6f4; }
		.cell-person { font-weight: 500; }
		.cell-amount { text-align: right; font-weight: 600; font-family: 'DM Mono', monospace; }
		.badge {
			font-size: 0.75rem; font-weight: 600; padding: 0.2rem 0.6rem;
			border-radius: 100px;
		}
		.badge.debt { background: rgba(243, 139, 168, 0.12); color: #f38ba8; }
		.badge.owe { background: rgba(166, 227, 161, 0.12); color: #a6e3a1; }
	}

	@media (max-width: 639px) {
		thead { display: none; }
		table, tbody, tr, td { display: block; }
		table { width: 100%; }
		tr {
			padding: 0.85rem 1rem; border-bottom: 1px solid #313244;
			display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem 0.75rem;
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
		td:first-child { grid-column: 1 / -1; }
		.cell-person { font-weight: 600; }
		.cell-amount { font-family: 'DM Mono', monospace; font-weight: 600; }
		.badge {
			font-size: 0.75rem; font-weight: 600; padding: 0.2rem 0.6rem;
			border-radius: 100px; display: inline-block;
		}
		.badge.debt { background: rgba(243, 139, 168, 0.12); color: #f38ba8; }
		.badge.owe { background: rgba(166, 227, 161, 0.12); color: #a6e3a1; }
	}

	.empty { color: #6c7086; padding: 3rem 0; text-align: center; }
</style>
