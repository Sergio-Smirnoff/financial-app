---
name: BYMA Data API
description: API oficial de BYMA — fuente autoritativa para datos de mercado argentino, tier gratuito limitado, documentacion escasa
type: reference
---

## BYMA Data API — Fuente oficial secundaria

- **URL base:** `https://open.bymadata.com.ar`
- **Cobertura:** Acciones, CEDEARs, bonos soberanos, ONs, Letras, cauciones. Todo lo que opera en BYMA.
- **Historicos:** Limitados en tier gratuito. Historicos profundos requieren contrato comercial.
- **Frescura:** Delay 15-20 min sin contrato.
- **Auth:** Token Bearer, registro requerido.
- **Rate limits:** Restrictivos en tier gratuito.
- **Formato:** REST / JSON
- **Complejidad Spring Boot:** Alta. Documentacion publica escasa, requiere algo de ingenieria inversa.

**Why:** Fuente autoritativa del mercado. Datos de cierre oficiales.
**How to apply:** Usar como segunda fuente para validar precios de cierre y como complemento de IOL.
