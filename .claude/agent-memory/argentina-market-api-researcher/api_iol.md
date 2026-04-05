---
name: IOL (InvertirOnline) API
description: API REST mas completa para acciones, bonos, CEDEARs y letras argentinas — requiere cuenta de broker gratuita, OAuth2
type: reference
---

## IOL API — Fuente primaria recomendada

- **URL base:** `https://api.invertironline.com`
- **Cobertura:** Acciones (Merval lider + general), CEDEARs, bonos soberanos (Bonares, Globales), Letras del Tesoro, LECAPs, ONs, cauciones, FCI. Tanto ARS como USD.
- **Historicos:** Si, endpoint de serie historica con rango de fechas. Varios anos disponibles.
- **Frescura:** Delay ~15 min en tier gratuito.
- **Auth:** OAuth2 con username/password de cuenta IOL. Refresh tokens. Cuenta gratis sin monto minimo.
- **Rate limits:** ~100 req/min estimado.
- **Formato:** REST / JSON
- **Endpoints clave:**
  - `POST /token` — autenticacion
  - `GET /api/v2/{mercado}/Titulos/{simbolo}/Cotizacion` — cotizacion actual
  - `GET /api/v2/{mercado}/Titulos/{simbolo}/Cotizacion/seriehistorica/{desde}/{hasta}` — historicos
  - `GET /api/v2/Cotizaciones/{instrumento}/{pais}` — listado por tipo de instrumento
- **Complejidad Spring Boot:** Media. Necesita manejo de OAuth2 refresh tokens.

**Why:** Es la unica API accesible que cubre bonos + acciones + historicos de forma completa.
**How to apply:** Usarla como fuente primaria en cualquier microservicio de market data.
