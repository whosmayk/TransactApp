# TransactApp (macOS, Swift)

Réplica nativa para macOS de la app original TransactApp (Windows Forms / .NET 10),
con énfasis en **inventario físico de efectivo por denominación** y
**proyección financiera a 18 meses**.

## Estado

**Fase 6f — Dashboard auto-refresh completada**. Cimientos,
modelo, dashboard, importador Windows, modo "ajustar a balance real", búsqueda
global (⌘F), simulador de escenarios, errores runtime como `NSAlert`, AppIcon
sapphire con `wallet.bifold`, **toda la UI localizada** (Common,
Transactions, Subscriptions, Loans, Reportes, Ajustes + Diagnóstico + Limpiar,
Respaldos + WindowsImport, Projection + Configuración, Onboarding,
BusquedaGlobal) con `LocalizableKey` (436 casos) + paridad es↔en verificada +
`Localizador` central para formatters (moneda, fechas, mes-año, día-mes,
relativo, bytes, decimal, plurales). Locale override vía
`UserDefaults["TransactApp.Locale"]`.

**Fase 6f — Dashboard auto-refresh ✅**: GRDB `ValueObservation` con regiones
por tabla y debounce 150 ms (`Sources/Database/DatabaseObserver.swift`). El
`AppEnvironment` registra un handler único que recarga los tres VMs
(dashboard + proyección + simulador) cuando cualquier tabla trackeada cambia
(Transacciones, Préstamos, Suscripciones, InventarioEfectivo, SaldoInicial,
Configuración). El botón "Recargar" se demota a icono-only (`arrow.clockwise`)
y se añade label "Actualizado HH:mm" en el header (hora absoluta, no
relativa, para evitar trabajo cosmético). Re-suscripción automática tras
`RespaldoViewModel.restaurarAsync` vía
`Notification.Name.transactAppObservadorReiniciar`. **Limitación conocida**:
las escrituras vía `sqlite3` CLI externo no son observadas (limitación de
`DatabaseQueue` para cross-process; los writes in-app sí disparan el refresh).
6 tests nuevos (DatabaseObserverTests + DashboardAutoRefreshTests), 177/177
verde, 29 suites.

**Fase 6f+ — Bug fix: form-reset ✅**: el ticker de 30s del header (removido)
re-corria el `DashboardView.body` cada 30s. Como 4 sheets (nueva transacción,
ajustes, editor historial, editor ⌘F) instanciaban sus VMs **dentro del body**,
cada tick creaba un VM nuevo y reseteaba el input. Solución: nuevo módulo
`Sources/TransactApp/Features/Common/FormularioHosts.swift` con 4 wrappers
trivial (`FormularioTransaccionHost`, `FormularioPrestamoHost`,
`FormularioSuscripcionHost`, `AjustesHost`) que envuelven el VM en
`@StateObject(wrappedValue:)` para preservar la identidad a través de
re-renders. `.id(tx.id)` en los sheets de edición para forzar re-init al
editar otra transacción distinta. 1 test nuevo (`test_horaCorta_esMX_formatoCorrecto`).
Verificado: header muestra "Actualizado 1:56a.m. ↻" (hora absoluta, sin
ticker); 177/177 tests verde.

**Próxima fase — Accesibilidad (Fase 6e)**: `.accessibilityLabel`,
`.accessibilityHint`, VoiceOver, Dynamic Type. (Pista: el botón Recargar ya
cuenta con `.accessibilityLabel` + `.accessibilityHint` + `.help` como
referencia de patrón.)

**Fase 6g — Cambio de denominaciones (operación de inventario) ✅**:
nueva operación independiente que reorganiza los billetes/monedas del
inventario sin afectar el saldo ni generar transacción. Trigger: botón
circular `arrow.left.arrow.right` en la esquina superior derecha de la
card "Efectivo" del dashboard. Sheet modal con dos secciones (Quitar
origen / Agregar destino) y resumen reactivo de balanceo en vivo. Si el
total origen ≠ total destino, el botón "Aplicar" queda deshabilitado con
un aviso en color `peach` ("Los totales no coinciden"); si está
balanceado, check verde con `green.opacity(0.15)`. Atomicidad garantizada
vía `InventoryService.swap(origen:destino:)` (validación de inventario
dentro de la transacción, no antes). No toca `Transacciones`, no
contamina proyección ni reportes, sin log de auditoría (YAGNI —
diferible). 3 tests nuevos (`InventoryServiceSwapTests`):
`swapBalanceado`, `swapNoBalanceado`, `swapInventarioInsuficiente`. 1
nuevo enum `CambioBilleteError` con 3 casos localizados
(`errorDescription`). 12 strings i18n (2 dashboard, 11 sheet). 180/180
tests verde, 30 suites.

**Fase 6h — Menu bar macOS nativo ✅**: atajos de teclado globales sin
colisiones con defaults macOS, integrados en el menú File estándar (no
se duplica el menú). Nuevo `NavegacionCoordinator` (`@MainActor`) con
`enum Hoja` (5 cases: nuevaTransaccion, configuracion(tab:),
cambioBillete, importarWindows, diagnostico) + `enum Destino` (5 cases:
dashboard, historial, suscripciones, prestamos, reportes) para
sincronizar sheets + NavigationStack. `RootCoordinator` movido a App
scope (`@StateObject` en `TransactApp`) para que el menú Recargar
acceda a `dashboardViewModel`. `DashboardView` refactorizado: 6
`@State` eliminados (mostrarNuevaTransaccion, navegarAHistorial,
navegarAProximasSuscripciones, navegarAReportes, mostrarConfiguracion,
mostrarCambioBillete), reemplazados por `NavigationStack(path:
$navegacion.rutaNavegacion)` + `.navigationDestination(for:)` +
`.sheet(item:)` con binding bidireccional. `AjustesView` reusado con
`tabInicial: Tab?` opcional (Importar Windows y Diagnóstico abren el
sheet de Ajustes en la pestaña correspondiente). 4 grupos en
`.commands`:
- `CommandGroup(after: .textEditing)`: Buscar ⌘F (existente).
- `CommandGroup(after: .newItem)`: Nueva transacción ⌘N, Historial
  ⌘⇧H, Suscripciones ⌘⇧U, Préstamos ⌘⇧P, Reportes ⌘⌥R, Configuración
  ⌘, (en menú File estándar).
- `CommandMenu("Ir")`: Dashboard ⌘1, Historial ⌘2, Suscripciones ⌘3,
  Préstamos ⌘4, Reportes ⌘5.
- `CommandMenu("Herramientas")`: Cambiar denominaciones ⌘B, Importar
  Windows ⌘⇧I, Diagnóstico ⌘⌥D.
- `CommandGroup(after: .sidebar)`: Recargar ⌘R (`.disabled(!root.tieneDashboard)`).
  Mnemónicos: B=Billetes, R=Recargar (⌘), R=Reportes (⌘⌥). 16 i18n
  keys (16 items en es+en). Plan en
  `docs/PLAN_MENU_BAR_MACOS.md`. 180/180 tests verde, 30 suites.

**Fase 6h-fix — Menú "Archivo" duplicado (resuelto)**: el primer
intento usaba `CommandMenu("Archivo")` que duplicaba el menú File
default de macOS. Reemplazado por `CommandGroup(after: .newItem)` que
añade los items al menú File existente, respetando la convención
macOS. Verificado: menu bar = `Apple, TransactApp, Archivo, Edición,
Visualización, Ir, Herramientas, Ventana, Ayuda` (sin duplicado); los
6 items aparecen en el menú Archivo junto con "Nueva ventana de
TransactApp", "Cerrar", "Cerrar todo" defaults.

**Refactor de paleta — Deep Slate + Steel Blue ✅**: Catppuccin Mocha
reemplazado por una paleta seria, profesional con grises profundos
neutros (#0C0E10 base, #181B1E surface0, #1F2226 surface1, #262A2E
surface2) y acento Steel Blue (#6C8EBF). Nuevo `AppGradiente` con 4
gradientes (`surface`, `accent`, `cardHeader`, `progress`) aplicados a
CardView (fondo degradado sutil), PrimaryButton (degradado steel
blue), y Ajustes tab selección. Colores semánticos apagados: green
salvia (#6BBF8A), rojo apagado (#D47A7A), peach (#D4A87A). 11 colores
Catppuccin no usados eliminados. `CatppuccinMocha` renombrado a
`AppColor` (503 referencias actualizadas, 26 archivos). `PaletaPDF`
actualizado en ReportesService. 180/180 tests verde, 30 suites.

Ver `docs/PLAN_IMPLEMENTACION_SWIFT.md` para el plan completo y
`ANALISIS_REVERSE_ENGINEERING.md` para el análisis de la app original.

## Stack

- Swift 6 (modo estricto de concurrencia)
- SwiftUI + AppKit (bridge selectivo)
- GRDB.swift (SQLite con migraciones)
- Swift Charts (macOS 14+)
- PDFKit (reportes)
- macOS 14+ (Sonoma) — usa `wallet.bifold` (SF Symbols 5) para el AppIcon

## Estructura

```
Sources/
  TransactApp/      @main entry point (SwiftUI App)
  Models/           structs de dominio (Transaccion, Inventario, ...) + LocalizableKey/Localizador + Resources/{es,en}.lproj
  DesignSystem/     AppColor (Deep Slate + Steel Blue) + componentes reutilizables
  Database/         GRDB DatabaseManager + repositorios
Resources/
  Info.plist        bundle metadata (CFBundleIconName=AppIcon, CFBundleLocalizations=[es,en])
  IconSource/       SwiftUI AppIconView usado por render-icon.swift
scripts/
  build-app.sh      compila + genera .icns + copia TransactApp_Models.bundle + ensambla .app
  build-icon.sh     compila render-icon + iconutil → AppIcon.icns
  render-icon.swift SwiftUI ImageRenderer → PNG maestro 1024×1024
Tests/
  TransactAppTests/
```

## Internacionalización (Fase 6d-extendida)

- `defaultLocalization: "es"` en `Package.swift`.
- `LocalizableKey` enum (`Sources/Models/LocalizableKey.swift`) — 434 casos
  `: String, Sendable, CaseIterable` con `rawValue = "key.path"`. Llamar
  `.localized()` / `.localized(args)`. Sufijos por feature: `dashboard.*`,
  `historial.*`, `formTx.*`, `formSub.*`, `sus.*`, `prestamo.*`, `config.*`,
  `proyeccion.*`, `reportes.*`, `respaldo.*`, `wi.*`, `ajustes.*`, `tab.*`,
  `diag.*`, `limpiar.*`, `onboarding.*`, `busq.*`, `monto.*`, `common.*`,
  `error.*`, `enum.*`, `categoria.*`, `menu.*`.
- `Sources/Models/Resources/{es,en}.lproj/Localizable.strings` con claves
  simétricas (test de paridad `LocalizableStringsCompletenessTests`) y 100%
  cobertura verificada sobre `LocalizableKey.allCases`.
- `Localizador` enum (`Sources/Models/Localizador.swift`) centraliza formatters
  (moneda, fecha corta/larga con formato opcional, mes-año, día-mes,
  relativo, bytes, decimal, plural). Default `es_MX` + `MXN`. Locale override
  vía `UserDefaults["TransactApp.Locale"]`.
- Enums (`TipoTransaccion`, `MetodoPago`, `TipoPrestamo`,
  `FrecuenciaSuscripcion`, `EstadoProyeccion`) exponen `var titulo: String`.
  `mesesPorCiclo` preservado en `FrecuenciaSuscripcion`.
- `CategoriasComunes.llaves: [LocalizableKey]` + `nombresEspacioUsuario` (UI)
  + `nombres` (legacy, ya no se usa en código migrado).
- Patrón de migración: `Text("Cancelar")` → `Text(LocalizableKey.commonCancelar.localized())`,
  `Text(verbatim: "$\(x)")` → `Localizador.moneda(x)`,
  `Text("Editar") { … }` (Button) → `Button(LocalizableKey.commonEditar.localized()) { … }`,
  glyphs `"$"` aislados → `LocalizableKey.montoPrefijo.localized()`.
- `Bundle.module` requiere `resources: [.process("Resources")]` en el target
  `Models` y `import Models` en los consumidores.
- `build-app.sh` copia `TransactApp_Models.bundle` a
  `TransactApp.app/Contents/Resources/` para que la app encuentre el bundle
  en runtime (no solo en dev).
- Helpers para keys sin arg: `LocalizableKey.appName.localized() == "TransactApp"`.
- Tests i18n: `LocalizableKeyTests` (CaseIterable auto + titulos + plurales),
  `LocalizadorTests` (formato es-MX/MXN, `monedaCorta` sin decimales,
  `plural` singular/plural, `bytes` KB, `fechaCorta` con formato opcional),
  `LocalizableStringsCompletenessTests` (paridad es↔en + cobertura total).

## Comandos

```bash
swift build                   # compilar binario SPM
swift test                    # correr tests
./scripts/run-app.sh          # compilar + empaquetar + abrir como .app
./scripts/build-app.sh debug  # sólo compilar y empaquetar (no abre)
open build/TransactApp.app    # abrir el bundle ya construido
```

## Atajos de teclado

| Atajo | Acción |
|---|---|
| `⌘F` | Abrir/cerrar paleta de búsqueda global |
| `↑ ↓` | Navegar resultados (en la paleta) |
| `⏎` | Abrir el resultado seleccionado (en la paleta) |
| `esc` | Cerrar la paleta |

## Rutas clave

| Qué | Ruta |
|---|---|
| Proyecto | `~/Documents/TransactApp macOS/` (o donde lo clonaste) |
| Bundle de la app | `~/Documents/TransactApp macOS/build/TransactApp.app` |
| Base de datos SQLite | `~/Library/Application Support/TransactApp/transactapp.sqlite` |
| Respaldos automáticos | `~/Library/Application Support/TransactApp/Respaldos/` |
| WAL / SHM (temporales) | Misma carpeta que la DB, con extensiones `.wal` y `.shm` |

> ⚠️ **`~/Library` está oculta en Finder** (por convención de Apple). Ver
> [Acceso a carpetas ocultas](#acceso-a-carpetas-ocultas) más abajo.

## Inicio rápido (paso a paso)

```bash
# 1. Entrar a la carpeta del proyecto (ajusta la ruta si está en otro lugar)
cd ~/Documents/TransactApp\ macOS

# 2. Compilar y abrir la app en un solo paso
./scripts/build-app.sh debug && open build/TransactApp.app

# 3. (Opcional) Poblar la base de datos con datos demo
swift run Seeder

# 4. (Opcional) Borrar la DB para forzar el onboarding de nuevo
rm "$HOME/Library/Application Support/TransactApp/transactapp.sqlite"*
```

## Acceso a carpetas ocultas

La base de datos y los respaldos viven en `~/Library/`, una carpeta
que Finder oculta por defecto. Tres formas de llegar ahí:

### A. Desde Finder (GUI)

1. Abre Finder.
2. En el menú superior click **Ir → Ir a la carpeta…** (o atajo
   `⌘ + ⇧ + G`).
3. Escribe o pega la ruta y presiona Enter:

```
~/Library/Application Support/TransactApp
```

> Si la ruta con `~` no funciona, prueba con la ruta absoluta.
> Para obtenerla, corre en Terminal:
> ```bash
> echo "$HOME/Library/Application Support/TransactApp"
> ```

4. Finder abrirá directamente la carpeta `TransactApp` con `transactapp.sqlite`
   y la subcarpeta `Respaldos/`.

### B. Atajo de teclado para mostrar `~/Library`

Si necesitas ver `Library` de forma permanente en la barra lateral de Finder:

- En Finder, menús **Ir → Utilidades** o **Ir → Mantenimiento** (en algunas
  versiones, **Ir → Mantenimiento**). Eso te lleva a `~/Library`.
- Alternativa moderna: en Finder mantén presionada la tecla **`⌥` (Option/Alt)**
  mientras abres el menú **Ir** y verás que `Library` aparece en la lista.

### C. Desde Terminal (siempre funciona)

La Terminal **siempre** ve las carpetas ocultas. Algunos comandos útiles:

```bash
# Ver el contenido de la carpeta de la app
ls -la "$HOME/Library/Application Support/TransactApp"

# Ver los respaldos
ls -la "$HOME/Library/Application Support/TransactApp/Respaldos"

# Abrir la carpeta en Finder desde Terminal
open "$HOME/Library/Application Support/TransactApp"

# Abrir la carpeta de respaldos en Finder
open "$HOME/Library/Application Support/TransactApp/Respaldos"

# Borrar la DB (forzar onboarding de nuevo en el siguiente inicio)
rm "$HOME/Library/Application Support/TransactApp/transactapp.sqlite"*
```

> El `*` al final del `rm` también borra los archivos laterales
> `transactapp.sqlite-wal` y `transactapp.sqlite-shm` que GRDB usa
> internamente.

### D. Revelar un archivo en Finder desde su ruta

Si ya tienes la ruta de un archivo (por ejemplo desde un mensaje de error),
puedes resaltarlo en Finder con:

```bash
# Abrir Finder con el archivo ya seleccionado
open -R "$HOME/Library/Application Support/TransactApp/transactapp.sqlite"
```

## Atajos útiles durante desarrollo

```bash
# Limpiar caché de compilación si algo se comporta raro
swift package clean

# Limpiar todo el build y los artefactos
rm -rf .build build

# Ver el log en vivo mientras la app corre (útil para depurar)
# (Corre la app y luego en otra terminal:)
log stream --predicate 'process == "TransactApp"'

# Inspeccionar la DB con sqlite3 (consulta SQL directa)
sqlite3 "$HOME/Library/Application Support/TransactApp/transactapp.sqlite"
# Dentro de sqlite3:
#   .tables                -- lista de tablas
#   .schema Transacciones  -- esquema de una tabla
#   SELECT * FROM Transacciones LIMIT 10;
#   .quit                  -- salir
```

## Abrir en Xcode

```bash
open Package.swift
```

Xcode detectará el paquete SPM y mostrará todos los targets.

> **Requisito**: Se necesita **Xcode.app completo** (no sólo CommandLineTools)
> para correr tests (`XCTest` / `Testing` no están en el SDK público de CLT).
> Descarga Xcode desde el App Store (~12 GB). El `swift build` del código
> principal sí funciona con CLT.

## Distribución

DMG firmado y notarizado publicado en GitHub Pages (fase 7).
