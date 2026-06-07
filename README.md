# TransactApp

> Control de finanzas personales con inventario físico de efectivo, proyección a 18 meses y soporte para múltiples monedas.

TransactApp te ayuda a llevar el control de tus ingresos, gastos, suscripciones, préstamos y — sobre todo — el **efectivo físico** que tienes en tu cartera, desglosado por denominación (billetes y monedas).

---

## Capturas

*[Agrega aquí capturas de pantalla del dashboard, historial, y sheets modales]*


---

## Funcionalidades

### Dashboard
Resumen financiero completo en una sola vista: balance total, ingresos y gastos del mes, proyección a 18 meses, suscripciones próximas, préstamos activos, e inventario de efectivo desglosado por denominación.

### Transacciones
Registro de ingresos y gastos con desglose de billetes y monedas. Cada transacción puede detallar con qué denominaciones físicas se realizó, manteniendo sincronizado el inventario de efectivo.

### Suscripciones
Gestión de suscripciones recurrentes (mensuales, trimestrales, anuales). El dashboard muestra las próximas a vencer y el impacto mensual estimado.

### Préstamos
Control de préstamos activos: dinero que te deben y dinero que debes. Con saldos actualizados y seguimiento individual.

### Proyección Financiera
Proyección a 18 meses basada en tus ingresos, gastos, suscripciones y préstamos. Incluye configuración de meta de ahorro mensual y simulación de reducción de gastos por categoría.

### Inventario de Efectivo
Control físico del efectivo desglosado por denominación ($1000, $500, $200, $100, $50, $20, monedas). Incluye operación de **cambio de denominaciones** para reorganizar billetes sin alterar el saldo.

### Importación desde Windows
Migra tus datos desde la versión original de TransactApp (Windows Forms / .NET) importando directamente el archivo SQLite.

### Búsqueda Global
Busca transacciones, suscripciones y préstamos desde cualquier pantalla con `⌘F`.

### Reportes
Genera reportes mensuales en PDF con gráficos de ingresos vs gastos, desglose por categoría, evolución del balance y estado de suscripciones/préstamos.

---

## Atajos de teclado

| Atajo | Acción |
|---|---|
| `⌘N` | Nueva transacción |
| `⌘F` | Búsqueda global |
| `⌘R` | Recargar dashboard |
| `⌘B` | Cambiar denominaciones |
| `⌘⇧H` | Ir a Historial |
| `⌘⇧U` | Ir a Suscripciones |
| `⌘⇧P` | Ir a Préstamos |
| `⌘⌥R` | Ir a Reportes |
| `⌘,` | Configuración |
| `⌘⇧I` | Importar desde Windows |
| `⌘⌥D` | Diagnóstico |
| `⌘1`–`⌘5` | Ir a Dashboard / Historial / Suscripciones / Préstamos / Reportes |

---

## Instalación

### Requisitos mínimos
- macOS 14 (Sonoma) o superior
- Apple Silicon o Intel

### Descargar
Descarga el archivo `.zip` desde la [página de releases](https://github.com/whosmayk/TransactApp/releases), descomprime y arrastra `TransactApp.app` a tu carpeta de Aplicaciones.

> ⚠️ Al abrir por primera vez, haz clic derecho sobre `TransactApp.app` y selecciona **Abrir** para confirmar que confías en la app (al no estar firmada con Developer ID de Apple, Gatekeeper muestra una advertencia).

### Compilar desde fuente
```bash
git clone https://github.com/whosmayk/TransactApp.git
cd TransactApp
./scripts/build-app.sh release
open build/TransactApp.app
```

---

## Stack tecnológico

| Componente | Tecnología |
|---|---|
| Lenguaje | Swift 6 (concurrencia estricta) |
| UI | SwiftUI + AppKit |
| Base de datos | SQLite vía GRDB.swift 7 |
| Reportes PDF | Core Graphics + PDFKit |
| Gráficas | Swift Charts (macOS 14+) |
| Icono | SF Symbols 5 (`wallet.bifold`) |
| Versión mínima | macOS 14 Sonoma |

---

## Licencia

Uso personal. Este proyecto no está afiliado ni respaldado por Apple Inc.
