# Inventario de Componentes Frontend (Custom)

Este documento detalla los componentes personalizados creados para la aplicación financiera, con el objetivo de identificar duplicidades y oportunidades de reutilización.

## 1. Componentes Compartidos (Shared)
Componentes de propósito general utilizados en múltiples módulos.

| Componente | Archivo | Características | Contenido | Uso principal |
| :--- | :--- | :--- | :--- | :--- |
| **ConfirmDialog** | `shared/ConfirmDialog.tsx` | Diálogo centralizado, variante destructiva (rojo) para el botón de acción. | Título, descripción y botones de Cancelar/Confirmar. Consume `useUiStore`. | Eliminación de bancos, cuentas, transacciones, etc. |
| **MultiCurrencyAmount** | `shared/MultiCurrencyAmount.tsx` | Formateador de moneda dinámico. | Lista de montos con su respectiva moneda (USD, ARS, etc.). | Dashboard, balances de cuentas, resúmenes. |
| **ErrorMessage** | `shared/ErrorMessage.tsx` | Alerta de error simple. | Texto de error con icono de advertencia. | Estados de error en peticiones API. |
| **LoadingSpinner** | `shared/LoadingSpinner.tsx` | Spinner centrado. | Animación de carga. | Pantallas de carga (loading states). |

## 2. Componentes de Layout
Definen la estructura de la aplicación.

| Componente | Archivo | Características | Contenido |
| :--- | :--- | :--- | :--- |
| **Sidebar** | `layout/Sidebar.tsx` | Barra lateral fija (Desktop). | Logo y lista de navegación (`NAV_ITEMS`). |
| **MobileSidebar** | `layout/Sidebar.tsx` | Barra lateral colapsable (Mobile). | Menú hamburguesa que abre el Sidebar. |
| **Header** | `layout/Header.tsx` | Barra superior. | Título de página, toggle de tema, notificaciones y perfil/logout. |
| **NotificationBell** | `layout/NotificationBell.tsx` | Icono de campana con badge. | Contador de notificaciones no leídas. |

## 3. Componentes de Negocio (Pages)
Componentes específicos de cada dominio de la aplicación.

### Módulo: Bancos (Banks)
| Componente | Archivo | Características | Contenido | Diferencias/Configuración |
| :--- | :--- | :--- | :--- | :--- |
| **BankCard** | `banks/BankCard.tsx` | Card con iconos dinámicos. | Info del banco, balance, badges de notificaciones. | Muestra alertas si hay notificaciones pendientes. |
| **BankFormDialog** | `banks/BankFormDialog.tsx` | Diálogo con formulario. | Campos: Nombre, Logo URL. | Maneja tanto creación como edición. |
| **AccountFormDialog** | `banks/AccountFormDialog.tsx` | Diálogo con formulario. | Campos: Nombre, Tipo de Cuenta, Balance Inicial, Moneda. | Configurable por `bankId`. |
| **CardList** | `banks/CardList.tsx` | Grid de tarjetas. | Mapeo de `BankCard`. | Renderiza la lista de bancos del usuario. |

### Módulo: Inversiones (Investments)
| Componente | Archivo | Características | Contenido | Diferencias/Configuración |
| :--- | :--- | :--- | :--- | :--- |
| **HoldingTable** | `investments/HoldingTable.tsx` | Tabla detallada. | Ticker, Qty, Precio Compra, Actual, P&L. | Usa colores (verde/rojo) para P&L. |
| **HoldingForm** | `investments/HoldingForm.tsx` | Formulario en diálogo. | Ticker, Cantidad, Precio, Fecha, Tipo. | Similar en estructura a `BankFormDialog`. |
| **PortfolioSummaryCard** | `investments/PortfolioSummaryCard.tsx` | Card de resumen. | Total invertido, P&L total por moneda. | Usa `MultiCurrencyAmount`. |

### Módulo: Transacciones y Préstamos
| Componente | Archivo | Características | Contenido |
| :--- | :--- | :--- | :--- |
| **TransactionForm** | `transactions/TransactionForm.tsx` | Formulario complejo. | Monto, Categoría, Cuenta, Fecha, Descripción. |
| **LoanForm** | `loans/LoanForm.tsx` | Formulario de préstamos. | Monto, Tasa, Cuotas, Entidad. |

## 4. Oportunidades de Mejora (Reutilización)

1.  **Formularios Base (Form Factory):** Los componentes `BankFormDialog`, `AccountFormDialog` y `HoldingForm` comparten el 80% de su estructura (Dialog + Form + Footer). Se podría crear un componente `GenericFormDialog` que reciba los campos como configuración.
2.  **Tablas Dinámicas:** `HoldingTable` y la tabla de transacciones podrían unificarse en un componente `DataTable` compartido con soporte para celdas personalizadas.
3.  **Tarjetas (Cards):** `BankCard` y `PortfolioSummaryCard` tienen estructuras similares. Un componente `SummaryCard` genérico con soporte para iconos y badges reduciría código duplicado.
4.  **Confirmaciones:** El `ConfirmDialog` ya está centralizado, lo cual es una buena práctica. Se podría extender para aceptar tipos de confirmación (Info, Warning, Danger).
