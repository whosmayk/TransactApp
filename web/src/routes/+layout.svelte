<script lang="ts">
	import { onMount } from 'svelte'
	import { page } from '$app/stores'
	import { supabase } from '$lib/supabase'

	let { children } = $props()
	let session = $state<any>(null)
	let loading = $state(true)
	let email = $state('')
	let sent = $state(false)
	let otp = $state('')
	let errorMsg = $state('')
	let menuOpen = $state(false)

	let currentPage = $derived($page.url.pathname)

	onMount(async () => {
		const { data } = await supabase.auth.getSession()
		session = data.session
		loading = false
		supabase.auth.onAuthStateChange((_event, s) => { session = s })

		const hash = window.location.hash
		if (hash && hash.includes('access_token')) {
			loading = true
			const { data, error } = await supabase.auth.getSession()
			if (data.session) session = data.session
			if (error) errorMsg = 'Error al iniciar sesión con el magic link'
			loading = false
			window.history.replaceState({}, '', window.location.pathname)
		}
	})

	async function sendMagicLink() {
		errorMsg = ''
		const redirectTo = typeof window !== 'undefined' ? window.location.origin : undefined
		const { error } = await supabase.auth.signInWithOtp({
			email,
			options: { emailRedirectTo: redirectTo }
		})
		if (error) errorMsg = error.message
		else sent = true
	}

	async function verifyOTP() {
		errorMsg = ''
		const { error } = await supabase.auth.verifyOtp({ email, token: otp, type: 'magiclink' })
		if (error) errorMsg = error.message
		else { sent = false; email = ''; otp = '' }
	}

	const navItems = [
		{ path: '/dashboard', label: 'Dashboard', icon: '◈' },
		{ path: '/historial', label: 'Historial', icon: '◉' },
		{ path: '/suscripciones', label: 'Suscripciones', icon: '◎' },
		{ path: '/prestamos', label: 'Préstamos', icon: '◇' },
	]
</script>

<div class="app">
	{#if loading}
		<div class="loading-screen">
			<span class="loader"></span>
		</div>
	{:else if !session}
		<div class="auth-screen">
			<div class="auth-card">
				<div class="auth-header">
					<span class="auth-logo">◆</span>
					<h1>TransactApp</h1>
					<p class="auth-sub">Finanzas personales · Nube</p>
				</div>
				{#if !sent}
					<form onsubmit={(e) => { e.preventDefault(); sendMagicLink() }}>
						<div class="field">
							<label for="email">Correo electrónico</label>
							<input id="email" type="email" bind:value={email} placeholder="tu@correo.com" required autocomplete="email" />
						</div>
						<button type="submit" class="btn-primary" disabled={!email}>Enviar código de acceso</button>
						{#if errorMsg}<p class="err">{errorMsg}</p>{/if}
					</form>
				{:else}
					<form onsubmit={(e) => { e.preventDefault(); verifyOTP() }}>
						<p class="otp-desc">Revisa tu email. Puedes dar clic al link que llegó, o escribir el código de 8 dígitos:</p>
						<div class="field">
							<label for="otp">Código de verificación</label>
							<input id="otp" type="text" bind:value={otp} placeholder="12345678" maxlength={8} required inputmode="numeric" pattern="[0-9]*" autocomplete="one-time-code" />
						</div>
						<button type="submit" class="btn-primary" disabled={otp.length < 8}>Verificar código</button>
						<button type="button" class="btn-link" onclick={() => { sent = false; errorMsg = '' }}>← Usar otro correo</button>
						{#if errorMsg}<p class="err">{errorMsg}</p>{/if}
					</form>
				{/if}
			</div>
		</div>
	{:else}
		<!-- Desktop sidebar -->
		<aside class="sidebar">
			<div class="sidebar-brand">
				<span class="sidebar-logo">◆</span>
				<span class="sidebar-name">TransactApp</span>
			</div>
			<nav class="sidebar-nav">
				{#each navItems as item}
					<a href={item.path} class="nav-link" class:active={currentPage === item.path}>
						<span class="nav-icon">{item.icon}</span>
						<span>{item.label}</span>
					</a>
				{/each}
			</nav>
			<div class="sidebar-footer">
				<button class="btn-logout" onclick={() => supabase.auth.signOut()}>Cerrar sesión</button>
			</div>
		</aside>

		<!-- Mobile header -->
		<header class="mobile-header">
			<span class="mobile-logo">◆</span>
			<span class="mobile-title">TransactApp</span>
			<button class="hamburger" onclick={() => menuOpen = !menuOpen} aria-label="Menú">
				<span class="hamburger-line" class:open={menuOpen}></span>
			</button>
		</header>

		<!-- Mobile drawer -->
		<div class="drawer-overlay" class:open={menuOpen} onclick={() => menuOpen = false}></div>
		<nav class="drawer" class:open={menuOpen}>
			<div class="drawer-header">
				<span class="sidebar-logo">◆</span>
				<span class="sidebar-name">TransactApp</span>
			</div>
			{#each navItems as item}
				<a href={item.path} class="nav-link" class:active={currentPage === item.path} onclick={() => menuOpen = false}>
					<span class="nav-icon">{item.icon}</span>
					<span>{item.label}</span>
				</a>
			{/each}
			<div class="drawer-footer">
				<button class="btn-logout" onclick={() => supabase.auth.signOut()}>Cerrar sesión</button>
			</div>
		</nav>

		<!-- Main content -->
		<main class="main-content" onclick={() => menuOpen = false}>
			{@render children()}
		</main>

		<!-- Mobile bottom nav -->
		<nav class="bottom-nav">
			{#each navItems as item}
				<a href={item.path} class="bottom-link" class:active={currentPage === item.path}>
					<span class="bottom-icon">{item.icon}</span>
					<span class="bottom-label">{item.label}</span>
				</a>
			{/each}
		</nav>
	{/if}
</div>

<noscript>
	<div class="noscript">
		<p>JavaScript es necesario para esta aplicación. Actívalo en tu navegador.</p>
	</div>
</noscript>

<style>
	:global(*) { margin: 0; padding: 0; box-sizing: border-box; }
	:global(body) {
		font-family: 'DM Sans', -apple-system, BlinkMacSystemFont, sans-serif;
		background: #1e1e2e; color: #cdd6f4; min-height: 100vh;
		-webkit-font-smoothing: antialiased;
		-moz-osx-font-smoothing: grayscale;
		overflow-x: hidden;
	}
	:global(body.auth) { background: #181825; }
	:global(h1, h2, h3, h4) { font-weight: 600; letter-spacing: -0.02em; }
	:global(a) { color: #fab387; text-decoration: none; }

	/* ---------- layout ---------- */
	.app { min-height: 100vh; display: flex; flex-direction: column; }

	/* ---------- loading ---------- */
	.loading-screen {
		display: flex; align-items: center; justify-content: center;
		height: 100vh; background: #1e1e2e;
	}
	.loader {
		width: 32px; height: 32px; border: 3px solid #313244;
		border-top-color: #fab387; border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* ---------- auth screen ---------- */
	.auth-screen {
		display: flex; align-items: center; justify-content: center;
		min-height: 100vh; padding: 1.5rem;
		background: radial-gradient(ellipse at top left, #1e1e2e 0%, #181825 100%);
	}
	.auth-card {
		background: #181825; padding: 2.5rem 2rem; border-radius: 20px;
		width: 100%; max-width: 400px;
		border: 1px solid #313244;
		box-shadow: 0 20px 60px rgba(0,0,0,0.4);
	}
	.auth-header { text-align: center; margin-bottom: 2rem; }
	.auth-logo { font-size: 2.5rem; color: #fab387; display: block; margin-bottom: 0.5rem; }
	.auth-card h1 { font-size: 1.75rem; color: #cdd6f4; margin-bottom: 0.25rem; }
	.auth-sub { color: #6c7086; font-size: 0.9rem; }
	.field { margin-bottom: 1.25rem; }
	.field label {
		display: block; font-size: 0.8rem; font-weight: 500;
		color: #a6adc8; margin-bottom: 0.4rem; text-transform: uppercase;
		letter-spacing: 0.05em;
	}
	.field input {
		width: 100%; padding: 0.75rem 1rem;
		background: #313244; border: 1.5px solid #45475a;
		border-radius: 10px; color: #cdd6f4; font-size: 1rem;
		font-family: 'DM Mono', monospace;
		transition: border-color 0.2s;
	}
	.field input:focus { outline: none; border-color: #fab387; }
	.field input::placeholder { color: #585b70; }
	.btn-primary {
		width: 100%; padding: 0.8rem;	margin-top: 0.5rem;
		background: #fab387; color: #1e1e2e; border: none;
		border-radius: 10px; font-size: 1rem; font-weight: 600;
		cursor: pointer; transition: opacity 0.2s, transform 0.1s;
		font-family: inherit;
	}
	.btn-primary:hover { opacity: 0.9; }
	.btn-primary:active { transform: scale(0.98); }
	.btn-primary:disabled { opacity: 0.4; cursor: not-allowed; }
	.btn-link {
		background: none; border: none; color: #6c7086;
		font-size: 0.85rem; cursor: pointer; margin-top: 0.75rem;
		font-family: inherit; width: 100%; text-align: center;
	}
	.btn-link:hover { color: #a6adc8; }
	.otp-desc { color: #a6adc8; font-size: 0.9rem; margin-bottom: 1.25rem; line-height: 1.5; text-align: center; }
	.err { color: #f38ba8; font-size: 0.85rem; margin-top: 0.75rem; text-align: center; }

	/* ---------- sidebar (desktop) ---------- */
	.sidebar {
		display: none; position: fixed; top: 0; left: 0;
		width: 240px; height: 100vh; padding: 1.5rem 1rem;
		background: #181825; border-right: 1px solid #313244;
		flex-direction: column; z-index: 100;
	}
	.sidebar-brand {
		display: flex; align-items: center; gap: 0.65rem;
		margin-bottom: 2rem; padding: 0 0.75rem;
	}
	.sidebar-logo { font-size: 1.5rem; color: #fab387; }
	.sidebar-name { font-size: 1.15rem; font-weight: 700; color: #cdd6f4; letter-spacing: -0.02em; }
	.sidebar-nav { flex: 1; display: flex; flex-direction: column; gap: 0.25rem; }
	.nav-link {
		display: flex; align-items: center; gap: 0.75rem;
		padding: 0.7rem 0.75rem; border-radius: 10px;
		color: #a6adc8; font-size: 0.95rem; font-weight: 500;
		transition: background 0.15s, color 0.15s;
	}
	.nav-link:hover { background: #313244; color: #cdd6f4; }
	.nav-link.active { background: rgba(250, 179, 135, 0.12); color: #fab387; }
	.nav-icon { font-size: 1rem; width: 24px; text-align: center; }
	.sidebar-footer { padding-top: 1rem; border-top: 1px solid #313244; }
	.btn-logout {
		width: 100%; padding: 0.6rem; background: none;
		border: 1px solid #45475a; border-radius: 10px;
		color: #6c7086; font-size: 0.85rem; cursor: pointer;
		font-family: inherit; transition: color 0.2s, border-color 0.2s;
	}
	.btn-logout:hover { color: #f38ba8; border-color: #f38ba8; }

	/* ---------- mobile header + drawer ---------- */
	.mobile-header {
		display: flex; align-items: center; gap: 0.65rem;
		padding: 0.75rem 1.25rem;
		background: #181825; border-bottom: 1px solid #313244;
		position: sticky; top: 0; z-index: 90;
	}
	.mobile-logo { font-size: 1.3rem; color: #fab387; }
	.mobile-title { flex: 1; font-weight: 600; font-size: 1rem; color: #cdd6f4; }
	.hamburger {
		background: none; border: none; cursor: pointer;
		width: 32px; height: 32px; display: flex;
		align-items: center; justify-content: center;
		position: relative; z-index: 110;
	}
	.hamburger-line, .hamburger-line::before, .hamburger-line::after {
		content: ''; display: block; width: 20px; height: 2px;
		background: #a6adc8; border-radius: 2px;
		transition: transform 0.25s, background 0.25s;
		position: relative;
	}
	.hamburger-line::before { position: absolute; top: -6px; }
	.hamburger-line::after { position: absolute; top: 6px; }
	.hamburger-line.open { background: transparent; }
	.hamburger-line.open::before { transform: translateY(6px) rotate(45deg); }
	.hamburger-line.open::after { transform: translateY(-6px) rotate(-45deg); }

	.drawer-overlay {
		position: fixed; inset: 0; background: rgba(0,0,0,0.5);
		z-index: 95; opacity: 0; pointer-events: none;
		transition: opacity 0.3s;
	}
	.drawer-overlay.open { opacity: 1; pointer-events: auto; }

	.drawer {
		position: fixed; top: 0; left: 0; bottom: 0; width: 260px;
		background: #181825; z-index: 100; padding: 1.5rem 1rem;
		display: flex; flex-direction: column;
		transform: translateX(-100%); transition: transform 0.3s cubic-bezier(0.22, 1, 0.36, 1);
		border-right: 1px solid #313244;
	}
	.drawer.open { transform: translateX(0); }
	.drawer-header {
		display: flex; align-items: center; gap: 0.65rem;
		margin-bottom: 2rem; padding: 0 0.75rem;
	}
	.drawer .nav-link { font-size: 1rem; padding: 0.8rem 0.75rem; }
	.drawer-footer { padding-top: 1rem; border-top: 1px solid #313244; margin-top: auto; }

	/* ---------- main content ---------- */
	.main-content {
		flex: 1; padding: 1.25rem; padding-bottom: 5rem;
		max-width: 1200px; width: 100%; margin: 0 auto;
	}

	/* ---------- bottom nav (mobile) ---------- */
	.bottom-nav {
		display: flex; position: fixed; bottom: 0; left: 0; right: 0;
		background: #181825; border-top: 1px solid #313244;
		z-index: 80; padding: 0.35rem 0; padding-bottom: max(0.35rem, env(safe-area-inset-bottom));
	}
	.bottom-link {
		flex: 1; display: flex; flex-direction: column;
		align-items: center; gap: 0.15rem;
		padding: 0.4rem 0; color: #585b70;
		font-size: 0.6rem; font-weight: 500;
		text-decoration: none; transition: color 0.15s;
		-webkit-tap-highlight-color: transparent;
	}
	.bottom-link.active { color: #fab387; }
	.bottom-link.active .bottom-icon { transform: scale(1.1); }
	.bottom-icon { font-size: 1.25rem; transition: transform 0.15s; }
	.bottom-label { font-size: 0.6rem; text-transform: uppercase; letter-spacing: 0.04em; }

	/* ---------- responsive ---------- */
	@media (min-width: 768px) {
		.sidebar { display: flex; }
		.mobile-header { display: none; }
		.bottom-nav { display: none; }
		.main-content { margin-left: 240px; padding: 2rem; padding-bottom: 2rem; }
	}

	/* ---------- noscript ---------- */
	.noscript { padding: 2rem; color: #f38ba8; font-family: sans-serif; }
</style>
