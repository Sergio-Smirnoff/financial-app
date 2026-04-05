---
name: Yahoo Finance (.BA suffix)
description: Acciones argentinas via Yahoo Finance — historicos extensos, sin auth, pero NO cubre bonos y API no oficial
type: reference
---

## Yahoo Finance — Fallback para acciones

- **URL:** `https://query1.finance.yahoo.com/v8/finance/chart/{symbol}` (no oficial)
- **Tickers:** Sufijo `.BA` (ej: GGAL.BA, PAMP.BA, YPF.BA, TXAR.BA)
- **Cobertura:** Acciones del Merval, algunos CEDEARs. **NO cubre bonos soberanos.**
- **Historicos:** Si, anos de datos. Excelente para acciones.
- **Auth:** Sin API key, pero riesgo de bloqueo por rate limiting.
- **Maven:** `yahoofinance-api` library disponible.
- **Complejidad:** Facil, pero fragil (API no oficial).

**Why:** No requiere cuenta de broker. Buenos historicos para acciones.
**How to apply:** Usar como fallback si IOL no responde. Solo para acciones, nunca para bonos.
