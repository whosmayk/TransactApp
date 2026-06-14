<script lang="ts">
	import { supabase } from '$lib/supabase'
	import { onMount } from 'svelte'

	let suscripciones = $state<any[]>([])
	let loading = $state(true)

	onMount(async () => {
		const { data } = await supabase.from('Suscripciones').select('*').order('proximoCobro', { ascending: true })
		suscripciones = data ?? []
		loading = false
	})

	function formatMoney(cents: number): string {
		return '$' + (cents / 100).toLocaleString('es-MX', { minimumFractionDigits: 2 })
	}
</script>

<div class="page">
	<div class="page-header">
		<h2>Suscripciones</h2>
		<span class="page-sub">{suscripciones.length} registros</span>
	</div>

	{#if loading}
		<div class="empty">Cargando…</div>
	{:else if suscripciones.length === 0}
		<div class="empty">No hay suscripciones.</div>
	{:else}
		<div class="table-wrap">
			<table>
				<thead>
					<tr>
						<th><span data-label>Concepto</span></th>
						<th><span data-label>Monto</span></th>
						<th><span data-label>Frecuencia</span></th>
						<th><span data-label>Próximo cobro</span></th>
						<th><span data-label>Estado</span></th>
					</tr>
				</thead>
				<tbody>
					{#each suscripciones as s}
						<tr>
							<td data-label="Concepto">{s.concepto}</td>
							<td data-label="Monto">{formatMoney(s.monto)}</td>
							<td data-label="Frecuencia">{s.frecuencia}</td>
							<td data-label="Próximo cobro">{s.proximoCobro}</td>
							<td data-label="Estado">
								<span class="badge" class:active={s.activa} class:inactive={!s.activa}>
									{s.activa ? 'Activa' : 'Inactiva'}
								</span>
							</td>
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
		tbody tr { border-bottom: 1px solid #313244; transition: background 0.1s; }
		tbody tr:last-child { border-bottom: none; }
		tbody tr:hover { background: rgba(255,255,255,0.02); }
		tbody td { padding: 0.7rem 1rem; white-space: nowrap; color: #cdd6f4; }
		.badge {
			font-size: 0.75rem; font-weight: 600; padding: 0.2rem 0.6rem;
			border-radius: 100px;
		}
		.badge.active { background: rgba(166, 227, 161, 0.12); color: #a6e3a1; }
		.badge.inactive { background: rgba(108, 112, 134, 0.2); color: #6c7086; }
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
		.badge {
			font-size: 0.75rem; font-weight: 600; padding: 0.2rem 0.6rem;
			border-radius: 100px; display: inline-block;
		}
		.badge.active { background: rgba(166, 227, 161, 0.12); color: #a6e3a1; }
		.badge.inactive { background: rgba(108, 112, 134, 0.2); color: #6c7086; }
	}

	.empty { color: #6c7086; padding: 3rem 0; text-align: center; }
</style>
