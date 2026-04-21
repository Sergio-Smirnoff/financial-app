# 📋 Plan de Estabilización de Inversiones

Este plan detalla las acciones necesarias para corregir la desconexión de datos en el módulo de inversiones y asegurar la integridad del historial y los flujos de edición/venta.

## 1. Auditoría y Reparación de Datos (Backend/DB)
*   **Problema:** Registros de `holdings` con `bank_id` nulo o 0 impiden que el frontend cargue los selectores correctamente.
*   **Acción:** 
    *   Ejecutar un script de limpieza que asocie cada `holding` con el `bank_id` de su cuenta padre.
    *   Garantizar que todas las monedas estén en UPPERCASE (`USD`, `ARS`).
    *   Añadir una restricción `@PrePersist` y `@PreUpdate` en Java para normalizar los datos antes de guardarlos.

## 2. Implementación de Historial (History Fix)
*   **Problema:** El historial de la "Cuenta de Inversión" aparece vacío porque los eventos solo se registran contra la "Cuenta de Pago".
*   **Acción:** Refactorizar `HoldingService.java`:
    *   **Compra:** Publicar dos eventos de pago: uno negativo (Débito) en la cuenta de ahorros y uno positivo (Crédito/Inversión) en la cuenta de inversión.
    *   **Venta:** Publicar dos eventos: uno negativo (Liquidación) en la cuenta de inversión y uno positivo (Crédito) en la cuenta destino.
*   **Meta:** Que al hacer clic en "History" de una cuenta de inversión, se vean los movimientos de compra/venta.

## 3. Refactor de Formulario de Edición (Edit Logic)
*   **Problema:** Los selectores (Banco/Cuenta) se inicializan vacíos porque el formulario carga antes que la lista de bancos.
*   **Acción:**
    *   En `HoldingForm.tsx`, usar un estado de guardia o `skeleton` que bloquee el render hasta que `holding` y `banks` estén disponibles.
    *   Asegurar que `fundingAccountId` sea opcional en el esquema de Zod durante la edición.

## 4. Corrección del Selector de Venta (Sell Flow)
*   **Problema:** "No hay cuentas disponibles" debido a falta de `bankId` en el contexto del diálogo.
*   **Acción:**
    *   Asegurar que el objeto `HoldingWithPrice` incluya siempre el `bankId`.
    *   En `SellHoldingDialog.tsx`, forzar la recarga del banco si el `bankId` cambia para garantizar que las cuentas destino se filtren correctamente por moneda (ignore-case).

## 5. Verificación Final (E2E)
*   [ ] Comprar holding: Descuenta de ahorros + Aparece en historial de inversión.
*   [ ] Editar holding: No pierde la asociación de banco/cuenta.
*   [ ] Vender holding: Suma en cuenta destino + Desaparece de inversión + Aparece en historial de ambas.
