---
name: Gaps de cobertura en APIs argentinas
description: Resumen critico de que APIs cubren bonos vs acciones — la mayoria internacional solo cubre acciones, no bonos soberanos
type: reference
---

## Hallazgo critico: Brecha bonos vs acciones

La mayoria de APIs internacionales (Yahoo Finance, Alpha Vantage, Twelve Data, FMP) **solo cubren acciones argentinas** y NO cubren bonos soberanos (Bonares, Globales, Letras, LECAPs).

Para bonos soberanos argentinos, las unicas fuentes viables son:
1. **IOL API** (requiere cuenta de broker)
2. **BYMA Data** (tier gratuito limitado)
3. **PPI API** (acceso cerrado, no auto-servicio)
4. **Scraping de Rava** (fragil, no recomendado)

**Implicacion para el proyecto:** Si se necesitan cotizaciones de bonos, IOL es practicamente la unica opcion viable para un proyecto independiente/personal.

## Brokers sin API publica
- Cocos Capital: sin API publica
- Bull Market Brokers: sin API publica
- Balanz: sin API publica
- Solo IOL y (parcialmente) PPI ofrecen APIs para terceros.

## pyRofex (Matba Rofex)
- Solo cubre futuros y opciones (derivados), NO acciones ni bonos BYMA.
- Requiere cuenta ALYC habilitada en Matba Rofex.
- Python only, no Java.
