---
name: Estrategia de integracion recomendada
description: Arquitectura sugerida para market data service con IOL primario, BYMA secundario, Yahoo fallback, BCRA complemento
type: project
---

## Estrategia combinada de fuentes de datos

```
Primaria:     IOL API      --> acciones + bonos + CEDEARs + historicos
Secundaria:   BYMA Data    --> validacion + datos oficiales de cierre
Complemento:  BCRA API     --> tipo de cambio oficial, tasas de referencia
Fallback:     Yahoo Finance --> acciones si IOL no responde
```

**Why:** Ningun proveedor individual cubre todo. IOL es el mas completo pero depende de un broker. La combinacion da resiliencia.

**How to apply:**
- Strategy Pattern: interface `MarketDataProvider` con implementaciones por fuente
- Failover automatico: IOL -> BYMA -> Yahoo (solo acciones)
- Scheduler que cachee datos en PostgreSQL periodicamente
- Las consultas de la app leen de la DB local, no de APIs directamente
- BCRA API para tipo de cambio y tasas, integrado por separado
