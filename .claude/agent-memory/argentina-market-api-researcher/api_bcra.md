---
name: BCRA API Publica
description: API del Banco Central — tipos de cambio oficial, tasas BADLAR/TNA, variables macro. NO cubre bonos ni acciones.
type: reference
---

## BCRA API Publica — Complemento macro

- **URL base:** `https://api.bcra.gob.ar`
- **Cobertura:** Variables monetarias, tipo de cambio oficial, tasas de referencia (BADLAR, TNA, Leliq), reservas internacionales, base monetaria.
- **NO cubre:** Cotizaciones de bonos, acciones, CEDEARs.
- **Historicos:** Si, series temporales completas.
- **Auth:** Ninguna (totalmente publica).
- **Rate limits:** No documentados, ~1 req/seg recomendado.
- **Formato:** REST / JSON
- **Endpoints clave:**
  - `GET /estadisticas/v2.0/PrincipalesVariables` — listado de variables
  - `GET /estadisticas/v2.0/DatosVariable/{idVariable}/{desde}/{hasta}` — serie temporal
- **Complejidad Spring Boot:** Facil. Sin auth, JSON directo.

**Why:** Fuente oficial para tipo de cambio y tasas. Complementa datos de mercado.
**How to apply:** Integrar para obtener dolar oficial, tasas de referencia para calculos de rendimiento.
