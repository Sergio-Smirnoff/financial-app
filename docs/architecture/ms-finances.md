# ms-finances — Microservicio de Finanzas

Puerto: **8082** | Schema PostgreSQL: **finances**

---

## 1. Cambios Recientes (Audit 2026-05-08)

- **Integridad de Saldo (Event Sourcing):** La creación de transacciones ya no llama sincrónicamente a `ms-banks`. Ahora publica un evento `transaction.created` en Kafka.
- **Seguridad S2S:** Se requiere el header `X-Internal-Token` para todas las llamadas internas.
- **Notificaciones Transaccionales:** Los eventos de Kafka se envían solo *después* de que la transacción de DB ha hecho commit (vía `@TransactionalEventListener`).
- **Remoción de Footguns:** Se eliminó el parámetro `bypassBalance` por ser inseguro.

---

## 2. Estructura de paquetes

```
com.financialapp.finances
├── config/
│   ├── InternalAuthFilter (Validación S2S)
│   ├── FeignConfig (Inyección de token S2S)
│   ├── KafkaErrorHandlerConfig (DLT support)
│   └── ...
├── kafka/
│   ├── event/
│   │   ├── TransactionCreatedEvent (NUEVO: para actualización de saldos)
│   │   └── ...
│   └── producer/
│       ├── FinancesEventProducer (Usa ApplicationEventPublisher para transaccionalidad)
│       └── TransactionalKafkaListener (Envía a Kafka AFTER_COMMIT)
└── ...
```

---

## 3. Entidades Principales

### Transaction — `finances.transactions`

Movimiento de dinero. **Nota:** Al guardarse, dispara un evento asíncrono para actualizar el saldo en el banco correspondiente.

| Campo | Tipo | Restricciones |
|---|---|---|
| `id` | Long | PK, IDENTITY |
| `userId` | Long | not null |
| `accountId` | Long | ID de cuenta en `ms-banks` (nullable para CASH) |
| `amount` | BigDecimal | precision=15, scale=2, not null |
| `currency` | String | max 3 (ISO 4217), not null |

---

## 4. Kafka

### Tópicos Publicados

| Tópico | Propósito |
|---|---|
| `transaction.created` | Informa a `ms-banks` que debe ajustar un saldo. |
| `payment.due` | Alerta de vencimiento de tarjeta. |
| `loan.reminder` | Recordatorio general de préstamo. |

### Configuración de Resiliencia
- **Producer:** Retries configurados.
- **Consumer:** (Si aplica) usa `ErrorHandlingDeserializer` para evitar bloqueos por mensajes malformados.

---

## 5. Seguridad

### Filtro de Autenticación Interna
El `InternalAuthFilter` intercepta todas las peticiones (excepto actuator/swagger) y valida que el header `X-Internal-Token` coincida con la variable de entorno `INTERNAL_AUTH_TOKEN`.

### Feign Interceptor
El `FeignRequestInterceptor` inyecta automáticamente el token interno en todas las llamadas salientes a otros microservicios.
