# Informe Detallado de Inventario de Componentes Frontend (Custom)

Este informe proporciona un análisis exhaustivo de los componentes personalizados desarrollados para la aplicación financiera. Se enfoca en la anatomía visual (forma y color), el contenido funcional y su distribución en la base de código.

---

## 🎨 ADN Visual Común (Design System)
La aplicación utiliza un tema oscuro consistente basado en la paleta de **Zinc**.
- **Colores Principales**: `bg-zinc-950` (fondo), `bg-zinc-900` (cards/diálogos), `border-zinc-800`.
- **Tipografía y Contraste**: `text-white` para títulos, `text-zinc-400/500` para descripciones y `text-primary` (azul) para acentos.
- **Formas**: Uso extensivo de bordes redondeados: `rounded-xl` (12px) para inputs/botones y `rounded-2xl` o `rounded-3xl` para cards principales y contenedores de detalle.
- **Interactividad**: Efectos de `hover:bg-zinc-800` y transiciones suaves en botones y tarjetas.

---

## 1. Componentes Compartidos (Shared)
Ubicación: `front/financial-app/components/shared/`

| Componente | Archivo | Contenido / Explicación | Color y Forma | Dónde se usa |
| :--- | :--- | :--- | :--- | :--- |
| **ConfirmDialog** | `ConfirmDialog.tsx` | Diálogo de confirmación para acciones irreversibles. Usa un store centralizado. | `bg-zinc-900`, `border-zinc-800`. Botón de acción: `variant="destructive"` (rojo). | `TransactionsContent`, `CategoriesContent`, `LoansContent`, `HoldingsContent`. |
| **MultiCurrencyAmount** | `MultiCurrencyAmount.tsx` | Formatea y concatena múltiples montos con sus monedas separándolos por un punto medio (`·`). | Texto con `text-muted-foreground` para los separadores. | `DashboardContent`, `MonthSummary`, `UpcomingPayments`, `YearOverview`, `PortfolioSummaryCard`. |
| **ErrorMessage** | `ErrorMessage.tsx` | Muestra un mensaje de error con un icono de advertencia (`AlertCircle`). | `text-red-500`, centrado en pantalla. | Casi todas las páginas de contenido (Dashboard, Banks, etc.). |
| **LoadingSpinner** | `LoadingSpinner.tsx` | Animación de carga circular centrada. | Icono `Loader2` con `animate-spin` y `text-zinc-500`. | Casi todas las páginas de contenido durante el `isLoading`. |

---

## 2. Componentes de Layout
Ubicación: `front/financial-app/components/layout/`

| Componente | Archivo | Contenido / Explicación | Color y Forma | Configuración / Diferencias |
| :--- | :--- | :--- | :--- | :--- |
| **Sidebar** | `Sidebar.tsx` | Navegación lateral estática. Contiene `NAV_ITEMS`. | `bg-sidebar` (zinc-950), `border-r`. Links activos: `bg-sidebar-primary`. | Desktop only (hidden on mobile). |
| **MobileSidebar** | `Sidebar.tsx` | Versión móvil colapsable del Sidebar. | Overlay oscuro (`bg-black/50`) y menú lateral animado. | Se activa vía `useUiStore`. |
| **Header** | `Header.tsx` | Barra superior con título dinámico y acciones globales. | `border-b`, altura fija `h-14`. | Recibe `title` como prop opcional. |
| **NotificationBell** | `NotificationBell.tsx` | Icono de campana con contador. | Badge rojo sobre icono de campana. | Detecta estados no leídos automáticamente. |
| **ThemeToggle** | `ThemeToggle.tsx` | Switch para cambiar entre Light y Dark mode. | Iconos `Sun`/`Moon` con transiciones de escala. | Persiste preferencia en `next-themes`. |

---

## 3. Componentes de Negocio (Pages)
Ubicación: `front/financial-app/components/pages/`

### 🏦 Módulo de Bancos (Banks)
| Componente | Archivo | Contenido / Explicación | Color y Forma | Configuración / Diferencias |
| :--- | :--- | :--- | :--- | :--- |
| **BankCard** | `BankCard.tsx` | Card principal de banco. Muestra balance total y conteo de cuentas/tarjetas. | `rounded-2xl`, `bg-zinc-900`. Icono del banco en `rounded-xl bg-zinc-900`. | Cambia el color del icono de campana a `red-500` si hay alertas. |
| **BankDetailContent** | `BankDetailContent.tsx` | Contenedor principal del detalle de un banco. Filtros, búsqueda y lista de cuentas. | `p-8`, diseño responsivo. Secciones separadas por `space-y-8`. | Maneja estados de filtrado (`hide-empty`, `currency`). |
| **AccountFormDialog** | `AccountFormDialog.tsx` | Formulario para añadir/editar cuentas bancarias. | Diálogo estándar con `grid grid-cols-2`. | Configurado por `bankId` y `account` (si es edición). |
| **BankFormDialog** | `BankFormDialog.tsx` | Formulario para añadir/editar bancos. | Campos simples en `space-y-4`. | Cambia título y texto de botón según si recibe un `bank` prop. |
| **CardList** | `CardList.tsx` | Renderizador de la lista de `BankCard`. | Layout de grid responsivo. | Recibe array de `BankResponse`. |
| **QuickTransactionDialog**| `QuickTransactionDialog.tsx`| Acceso rápido para Depósitos/Retiros desde la cuenta. | Diálogo con input de monto y selector de tipo. | Se usa directamente desde la lista de cuentas. |

### 📈 Módulo de Inversiones (Investments)
| Componente | Archivo | Contenido / Explicación | Color y Forma | Configuración / Diferencias |
| :--- | :--- | :--- | :--- | :--- |
| **HoldingTable** | `HoldingTable.tsx` | Tabla técnica de activos. | `text-right` para números. Colores dinámicos en P&L. | P&L positivo: `text-green-600`, Negativo: `text-red-600`. |
| **HoldingForm** | `HoldingForm.tsx` | Formulario de transacciones de inversión (Compra/Venta). | `DialogContent` con selectores de Ticker y Tipo de Activo. | Maneja validaciones de moneda según el activo. |
| **PortfolioSummaryCard**| `PortfolioSummaryCard.tsx`| Resumen visual del portafolio. | `rounded-3xl`, degradados sutiles o `bg-zinc-900`. | Usa `MultiCurrencyAmount` para el total. |
| **AllocationChart** | `AllocationChart.tsx` | Gráfico de torta de distribución. | Colores de serie personalizados para cada activo. | Usa `Recharts` (PieChart). |

### 📊 Módulo de Dashboard
| Componente | Archivo | Contenido / Explicación | Color y Forma | Configuración / Diferencias |
| :--- | :--- | :--- | :--- | :--- |
| **IncomeExpenseChart** | `IncomeExpenseChart.tsx` | Gráfico de barras comparativo. | Barras en `primary` (Ingresos) y `red-500` (Gastos). | Selector de moneda integrado en el Header de la Card. |
| **MonthSummary** | `MonthSummary.tsx` | Widgets de resumen del mes actual. | Cards simples con iconos de tendencia. | Muestra variaciones porcentuales. |
| **UpcomingPayments** | `UpcomingPayments.tsx` | Lista de pagos próximos. | `Badge` de estado (Vencido, Próximo). | Ordenado por fecha de vencimiento. |

---

## 4. Análisis de Reutilización y Configuración

### Componentes con "Misma función, Distinta Configuración"
1.  **Formularios de Diálogo**: 
    - `BankFormDialog`, `AccountFormDialog`, `HoldingForm`, `TransactionForm`.
    - **Diferencia**: Solo cambia el esquema de validación (Zod) y los campos del `form`.
    - **Propuesta**: Crear un `FormDialogLayout` que maneje el estado de `open`, `isSubmitting` y el `DialogWrapper`.

2.  **Tablas de Datos**:
    - `HoldingTable`, `TransactionHistoryDialog` (lista).
    - **Diferencia**: `HoldingTable` tiene lógica de color de P&L, la de transacciones es más simple.
    - **Propuesta**: Unificar en un `AppTable` que acepte una definición de columnas (`columns definition`) similar a TanStack Table.

3.  **Tarjetas de Resumen (Stat Cards)**:
    - `MonthSummary` (varias cards), `PortfolioSummaryCard`.
    - **Diferencia**: Una es un grupo de mini-cards y la otra es una card grande con desglose.
    - **Propuesta**: Componente `StatCard` con props para `icon`, `label`, `value` (soporte MultiCurrency) y `trend`.

### Inventario de Contenido y Lógica Duplicada
- **Formateo de Moneda**: Muchos componentes importan `formatCurrency` manualmente.
- **Gestión de Diálogos**: La lógica de `useState(false)` para abrir/cerrar formularios se repite en `BanksContent`, `HoldingsContent` y `TransactionsContent`.
- **Estados de Carga**: El patrón `if (isLoading) return <LoadingSpinner />` es idéntico en el 90% de los componentes de página.

---
*Este documento sirve como base para la siguiente fase de refactorización y creación de un Core de Componentes más robusto.*
