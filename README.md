# TransactApp

> Control de finanzas personales con inventario físico de efectivo, proyección a 18 meses y soporte para múltiples monedas.

TransactApp te ayuda a llevar el control de tus ingresos, gastos, suscripciones, préstamos y — sobre todo — el **efectivo físico** que tienes en tu cartera, desglosado por denominación (billetes y monedas).

---

## Capturas

*Configuración de saldo inicial*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/64d26c53-2ac8-4e4c-b025-fabf5b61b0cd" />

*Dashboard*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/7bee9206-c552-402e-b21c-c137f68d6079" />

<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/39561b2a-1269-4c33-b023-971f5cddb006" />

*Nueva Transacción*
<img width="2408" height="1650" alt="image" src="https://github.com/user-attachments/assets/32cd6869-c80b-44fb-8885-6c7397e30eee" />

*Historial de transacciones*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/b015696e-5d75-41f7-9d3b-8070aba227ae" />

*Editar transacciones*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/370b4524-4884-4860-83e1-f0ad207a6789" />

*Generación de reportes mensuales en PDF y CSV*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/63702338-0ada-4c09-901e-f3e9b462006e" />

*Configuración de meta mensual*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/5e609c54-2cfd-4366-a7e2-2caf1a508c21" />

*Respaldos de la base de datos*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/50a2dc87-df35-4549-907b-a3298f4636f8" />

*Borrar la base de datos*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/e11ffc01-ee79-4b65-bd5f-4fd49e236bb7" />

*Simulación de gastos*
<img width="2142" height="706" alt="image" src="https://github.com/user-attachments/assets/f39da7e9-ec66-4920-808a-29b5b0e18abf" />

*Suscripciones y pagos recurrentes*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/28aaf9af-7dbc-405e-819e-6ec663fc51ba" />

*Control de préstamos*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/e4378e39-caab-4f99-93a0-f16a81bf8f99" />

*Cambio de billetes o monedas por otras denominaciones*
<img width="2408" height="1506" alt="image" src="https://github.com/user-attachments/assets/a7e3f309-9989-4fb4-8e1b-8d15791cb4cf" />


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
