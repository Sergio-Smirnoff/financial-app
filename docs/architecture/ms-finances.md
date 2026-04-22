# ms-finances — Microservicio de Finanzas

Puerto: **8082** | Schema PostgreSQL: **finances**

---

## Índice

1. [Estructura de paquetes](#1-estructura-de-paquetes)
2. [Entidades](#2-entidades)
3. [Enums](#3-enums)
4. [Repositorios](#4-repositorios)
5. [Servicios](#5-servicios)
6. [Controladores y endpoints](#6-controladores-y-endpoints)
7. [DTOs](#7-dtos)
8. [Mappers](#8-mappers)
9. [Manejo de excepciones](#9-manejo-de-excepciones)
10. [Kafka](#10-kafka)
11. [Scheduler](#11-scheduler)
12. [Configuración](#12-configuración)

---

## 1. Estructura de paquetes

```
com.financialapp.finances
├── controller/
│   ├── CategoryController
│   ├── TransactionController
│   ├── CardExpenseController
│   └── LoanController
├── service/
│   ├── CategoryService
│   ├── TransactionService
│   ├── CardExpenseService
│   ├── LoanService
│   └── LoanInstallmentService
├── repository/
│   ├── CategoryRepository
│   ├── TransactionRepository
│   ├── CardExpenseRepository
│   ├── LoanRepository
│   └── LoanInstallmentRepository
├── mapper/
│   ├── CategoryMapper
│   ├── TransactionMapper
│   ├── CardExpenseMapper
│   └── LoanMapper
├── model/
│   ├── entity/
│   │   ├── Category
│   │   ├── Transaction
│   │   ├── CardExpense
│   │   ├── Loan
│   │   └── LoanInstallment
│   ├── dto/
│   │   ├── request/
│   │   └── response/
│   └── enums/
│       ├── CategoryType
│       └── TransactionType
├── exception/
│   ├── BusinessException
│   ├── ResourceNotFoundException
│   └── GlobalExceptionHandler
├── config/
│   ├── AlertProperties
│   ├── KafkaConfig
│   └── SwaggerConfig
├── kafka/
│   ├── event/
│   │   ├── PaymentDueEvent
│   │   ├── LoanReminderEvent
│   │   └── InstallmentReminderEvent
│   └── producer/
│       └── FinancesEventProducer
├── scheduler/
│   └── FinancesAlertScheduler
└── FinancesApplication
```

---

## 2. Entidades

### Category — `finances.categories`

Categorías de dos niveles: parent → subcategoría. Las del sistema (`isSystem=true`) son compartidas por todos los usuarios; las de usuario (`isSystem=false`) son privadas.

| Campo | Tipo | Restricciones |
|---|---|---|
| `id` | Long | PK, IDENTITY |
| `parent` | Category | @ManyToOne LAZY, @JoinColumn(parent_id), nullable |
| `subcategories` | List\<Category\> | @OneToMany(mappedBy=parent, cascade=ALL) LAZY |
| `userId` | Long | nullable (null = sistema) |
| `name` | String | max 100, not null |
| `type` | CategoryType | @Enumerated(STRING), not null |
| `color` | String | max 7 (hex, ej: #FF6B6B) |
| `icon` | String | max 50 |
| `isSystem` | boolean | not null |
| `active` | boolean | not null, default true |
| `createdAt` | LocalDateTime | @PrePersist, no actualizable |
| `updatedAt` | LocalDateTime | @PreUpdate |

---

### Transaction — `finances.transactions`

Movimiento de dinero (ingreso o gasto). Borrado físico.

| Campo | Tipo | Restricciones |
|---|---|---|
| `id` | Long | PK, IDENTITY |
| `userId` | Long | not null |
| `type` | TransactionType | @Enumerated(STRING), not null |
| `amount` | BigDecimal | precision=15, scale=2, not null |
| `currency` | String | max 3 (ISO 4217), not null |
| `category` | Category | @ManyToOne LAZY, not null |
| `description` | String | max 500 |
| `date` | LocalDate | not null |
| `createdAt` | LocalDateTime | @PrePersist |
| `updatedAt` | LocalDateTime | @PreUpdate |

---

### CardExpense — `finances.card_expenses`

Gasto en cuotas con tarjeta. Borrado físico. Se marca inactivo cuando `remainingInstallments` llega a 0.

| Campo | Tipo | Restricciones |
|---|---|---|
| `id` | Long | PK, IDENTITY |
| `userId` | Long | not null |
| `cardId` | Long | referencia a ms-cards, not null |
| `description` | String | max 255, not null |
| `totalAmount` | BigDecimal | precision=15, scale=2, not null |
| `currency` | String | max 3, not null |
| `totalInstallments` | int | not null |
| `remainingInstallments` | int | not null |
| `installmentAmount` | BigDecimal | precision=15, scale=2, not null |
| `nextDueDate` | LocalDate | not null |
| `active` | boolean | default true |
| `createdAt` | LocalDateTime | @PrePersist |
| `updatedAt` | LocalDateTime | @PreUpdate |

---

### Loan — `finances.loans`

Préstamo con cuotas generadas automáticamente al crearlo.

| Campo | Tipo | Restricciones |
|---|---|---|
| `id` | Long | PK, IDENTITY |
| `userId` | Long | not null |
| `description` | String | max 255, not null |
| `entity` | String | max 100 (entidad prestamista) |
| `totalAmount` | BigDecimal | precision=15, scale=2, not null |
| `currency` | String | max 3, not null |
| `totalInstallments` | int | not null |
| `paidInstallments` | int | default 0 |
| `nextPaymentDate` | LocalDate | nullable (null cuando está cancelado) |
| `installmentAmount` | BigDecimal | precision=15, scale=2, not null |
| `active` | boolean | default true |
| `createdAt` | LocalDateTime | @PrePersist |
| `updatedAt` | LocalDateTime | @PreUpdate |

---

### LoanInstallment — `finances.loan_installments`

Cuota individual de un préstamo. Se generan todas al crear el Loan.

| Campo | Tipo | Restricciones |
|---|---|---|
| `id` | Long | PK, IDENTITY |
| `loan` | Loan | @ManyToOne LAZY, not null |
| `installmentNumber` | int | not null |
| `amount` | BigDecimal | precision=15, scale=2, not null |
| `dueDate` | LocalDate | not null |
| `paid` | boolean | default false |
| `paidDate` | LocalDate | nullable |
| `createdAt` | LocalDateTime | @PrePersist |
| `updatedAt` | LocalDateTime | @PreUpdate |

---

## 3. Enums

```java
enum CategoryType { INCOME, EXPENSE, BOTH }
enum TransactionType { INCOME, EXPENSE }
```

---

## 4. Repositorios

### CategoryRepository

| Método | Descripción |
|---|---|
| `findVisibleParentCategories(userId, type, isSystem)` | Categorías padre (parent IS NULL) visibles al usuario. Orden: sistema DESC, nombre ASC |
| `findVisibleSubcategories(parentId, userId)` | Subcategorías activas bajo un padre, visibles al usuario |
| `findAllVisibleFlat(userId, type, isSystem)` | Todas las categorías activas en lista plana. Orden: padres primero, nombre ASC |
| `existsByIdAndSystemFalseAndUserId(id, userId)` | Verifica que el usuario sea dueño de una categoría no-sistema |
| `existsByIdAndParentIsNotNull(id)` | Verifica que una categoría es subcategoría |

### TransactionRepository

| Método | Descripción |
|---|---|
| `findFiltered(userId, type, categoryId, currency, dateFrom, dateTo, pageable)` | Búsqueda paginada con todos los filtros opcionales |
| `sumByTypeAndCurrency(userId, type, currency, dateFrom, dateTo)` | `COALESCE(SUM(amount), 0)` por tipo y moneda en rango de fechas |

### CardExpenseRepository

| Método | Descripción |
|---|---|
| `findFiltered(userId, active, cardId, currency)` | Lista filtrada, orden: createdAt DESC |
| `findActiveWithUpcomingDueDate(from, to)` | Activos con nextDueDate entre `from` y `to` (para scheduler) |
| `countActiveByUserIdAndCurrency(userId, currency)` | Conteo de gastos activos |
| `sumRemainingDebtByUserIdAndCurrency(userId, currency)` | `SUM(installmentAmount * remainingInstallments)` activos |

### LoanRepository

| Método | Descripción |
|---|---|
| `findFiltered(userId, active, currency)` | Lista filtrada, orden: createdAt DESC |
| `countActiveByUserIdAndCurrency(userId, currency)` | Conteo de préstamos activos |
| `sumRemainingDebtByUserIdAndCurrency(userId, currency)` | `SUM(installmentAmount * (totalInstallments - paidInstallments))` activos |

### LoanInstallmentRepository

| Método | Descripción |
|---|---|
| `findByLoanIdOrderByInstallmentNumberAsc(loanId)` | Todas las cuotas de un préstamo en orden |
| `findByLoanIdAndInstallmentNumber(loanId, number)` | Optional de cuota específica |
| `findUpcomingUnpaid(from, to)` | Cuotas no pagadas con dueDate entre `from` y `to` (para scheduler) |
| `findUnpaidByLoanId(loanId)` | Cuotas sin pagar de un préstamo, orden por número |

---

## 5. Servicios

### CategoryService

- **`getCategoryTree`** — Árbol con subcategorías anidadas
- **`getCategoriesFlat`** — Lista plana con parentId
- **`getById`** — Categoría por ID con validación de visibilidad
- **`getSubcategories`** — Subcategorías de un padre (valida que el padre no sea ya una subcategoría)
- **`createParentCategory`** — Crea categoría de usuario (isSystem=false)
- **`createSubcategory`** — Crea subcategoría bajo un padre (valida que el padre exista y no sea subcategoría)
- **`updateParentCategory`** — Rechaza categorías de sistema y acceso de no-propietario
- **`updateSubcategory`** — Permite actualizar nombre (sistema o propietario)
- **`deleteParentCategory`** / **`deleteSubcategory`** — Soft delete (active=false), rechaza categorías de sistema
- **`validateSubcategoryForTransaction`** — Valida que el categoryId sea una subcategoría activa y visible (las transacciones solo pueden tener subcategorías, no padres)

### TransactionService

Monedas soportadas: `["ARS", "USD"]`

- **`getTransactions`** — Paginado con todos los filtros opcionales
- **`create`** — Valida que la categoría sea subcategoría, crea, refetch para popular categoryName
- **`getById`** / **`update`** / **`delete`** — Con validación de propiedad. Delete es físico
- **`getSummary`** — Resumen por moneda: income, expense, balance + deuda de préstamos y gastos de tarjeta

### CardExpenseService

- **`create`** — `remainingInstallments = totalInstallments`
- **`update`** — Solo actualiza `cardId` y `description`
- **`payInstallment`** — Decrementa `remainingInstallments`, avanza `nextDueDate` un mes, marca inactivo cuando llega a 0

### LoanService

- **`create`** — Crea el Loan y genera **todas** las LoanInstallment con fechas mensuales desde `firstPaymentDate`
- **`update`** — Solo actualiza `description` y `entity`
- **`delete`** — Físico, cascada a installments
- **`markLoanClosedIfFullyPaid`** — Cuando `paidInstallments >= totalInstallments`: `active=false`, `nextPaymentDate=null`
- **`updateNextPaymentDate`** — Actualiza al `dueDate` de la próxima cuota sin pagar (o null si todas pagadas)

### LoanInstallmentService

- **`getInstallments`** — Valida propiedad del Loan, devuelve todas las cuotas ordenadas
- **`payInstallment`** — Lógica secuencial: el préstamo debe estar activo, la cuota no debe estar pagada, todas las anteriores deben estar pagadas. Al pagar: `paid=true`, `paidDate=hoy`, incrementa `paidInstallments` en Loan, actualiza `nextPaymentDate`, cierra el Loan si está completo

---

## 6. Controladores y endpoints

Header requerido en todos los endpoints: `X-User-Id: {userId}` (Long)

### CategoryController — `/api/v1/finances`

| Método | Path | Body / Params | Respuesta |
|---|---|---|---|
| GET | `/categories` | `?type=`, `?isSystem=` | `ApiResponse<List<CategoryTreeResponse>>` |
| GET | `/categories/flat` | `?type=`, `?isSystem=` | `ApiResponse<List<CategoryFlatResponse>>` |
| GET | `/categories/{id}` | — | `ApiResponse<CategoryFlatResponse>` |
| GET | `/categories/{id}/subcategories` | — | `ApiResponse<List<SubcategoryResponse>>` |
| POST | `/categories` | `CreateParentCategoryRequest` | `201 ApiResponse<CategoryFlatResponse>` |
| POST | `/categories/{id}/subcategories` | `CreateSubcategoryRequest` | `201 ApiResponse<SubcategoryResponse>` |
| PUT | `/categories/{id}` | `UpdateCategoryRequest` | `ApiResponse<CategoryFlatResponse>` |
| PUT | `/subcategories/{id}` | `UpdateSubcategoryRequest` | `ApiResponse<SubcategoryResponse>` |
| DELETE | `/categories/{id}` | — | `ApiResponse<Void>` (soft delete) |
| DELETE | `/subcategories/{id}` | — | `ApiResponse<Void>` (soft delete) |

### TransactionController — `/api/v1/finances/transactions`

| Método | Path | Body / Params | Respuesta |
|---|---|---|---|
| GET | `/` | `?type=`, `?categoryId=`, `?currency=`, `?dateFrom=`, `?dateTo=`, pageable (default: size=20, sort=date DESC) | `ApiResponse<Page<TransactionResponse>>` |
| POST | `/` | `TransactionRequest` | `201 ApiResponse<TransactionResponse>` |
| GET | `/{id}` | — | `ApiResponse<TransactionResponse>` |
| PUT | `/{id}` | `TransactionRequest` | `ApiResponse<TransactionResponse>` |
| DELETE | `/{id}` | — | `ApiResponse<Void>` (físico) |
| GET | `/summary` | `?currency=`, `?dateFrom=`, `?dateTo=` | `ApiResponse<List<SummaryResponse>>` |

### CardExpenseController — `/api/v1/finances/card-expenses`

| Método | Path | Body / Params | Respuesta |
|---|---|---|---|
| GET | `/` | `?active=`, `?cardId=`, `?currency=` | `ApiResponse<List<CardExpenseResponse>>` |
| POST | `/` | `CardExpenseRequest` | `201 ApiResponse<CardExpenseResponse>` |
| GET | `/{id}` | — | `ApiResponse<CardExpenseResponse>` |
| PUT | `/{id}` | `CardExpenseUpdateRequest` | `ApiResponse<CardExpenseResponse>` |
| DELETE | `/{id}` | — | `ApiResponse<Void>` (físico) |
| POST | `/{id}/pay-installment` | — | `ApiResponse<CardExpenseResponse>` |

### LoanController — `/api/v1/finances/loans`

| Método | Path | Body / Params | Respuesta |
|---|---|---|---|
| GET | `/` | `?active=`, `?currency=` | `ApiResponse<List<LoanResponse>>` |
| POST | `/` | `LoanRequest` | `201 ApiResponse<LoanResponse>` |
| GET | `/{id}` | — | `ApiResponse<LoanResponse>` |
| PUT | `/{id}` | `LoanUpdateRequest` | `ApiResponse<LoanResponse>` |
| DELETE | `/{id}` | — | `ApiResponse<Void>` (físico) |
| GET | `/{id}/installments` | — | `ApiResponse<List<LoanInstallmentResponse>>` |
| PUT | `/{id}/installments/{installmentId}/pay` | — | `ApiResponse<LoanInstallmentResponse>` |

---

## 7. DTOs

### Requests

**TransactionRequest**
```
type*         TransactionType
amount*       BigDecimal @Positive
currency*     String @Pattern("ARS|USD")
categoryId*   Long
description   String @Size(max=500)
date*         LocalDate
```

**CardExpenseRequest**
```
cardId*              Long
description*         String @NotBlank @Size(max=255)
totalAmount*         BigDecimal @Positive
currency*            String @Pattern("ARS|USD")
totalInstallments*   Integer @Min(1)
installmentAmount*   BigDecimal @Positive
nextDueDate*         LocalDate
```

**CardExpenseUpdateRequest**
```
cardId*       Long
description*  String @NotBlank @Size(max=255)
```

**LoanRequest**
```
description*         String @NotBlank @Size(max=255)
entity               String @Size(max=100)
totalAmount*         BigDecimal @Positive
currency*            String @Pattern("ARS|USD")
totalInstallments*   Integer @Min(1)
installmentAmount*   BigDecimal @Positive
firstPaymentDate*    LocalDate
```

**LoanUpdateRequest**
```
description*  String @NotBlank @Size(max=255)
entity        String @Size(max=100)
```

**CreateParentCategoryRequest**
```
name*   String @NotBlank @Size(max=100)
type*   CategoryType
color   String @Size(max=7)
icon    String @Size(max=50)
```

**CreateSubcategoryRequest**
```
name*  String @NotBlank @Size(max=100)
type*  CategoryType
```

**UpdateCategoryRequest**
```
name*   String @NotBlank @Size(max=100)
type*   CategoryType
color   String @Size(max=7)
icon    String @Size(max=50)
```

**UpdateSubcategoryRequest**
```
name*  String @NotBlank @Size(max=100)
```

### Responses

**ApiResponse\<T\>** — Wrapper universal
```json
{
  "success": true,
  "message": "OK",
  "data": { ... },
  "errors": [],
  "timestamp": "2026-02-23T17:00:00Z"
}
```
Métodos estáticos: `ok(data)`, `ok(message, data)`, `error(message)`, `error(message, errors)`

**TransactionResponse**
```
id, userId, type, amount, currency,
categoryId, categoryName, description, date,
createdAt, updatedAt
```

**CardExpenseResponse**
```
id, userId, cardId, description, totalAmount, currency,
totalInstallments, remainingInstallments, installmentAmount,
nextDueDate, active, createdAt, updatedAt
```

**LoanResponse**
```
id, userId, description, entity, totalAmount, currency,
totalInstallments, paidInstallments, nextPaymentDate,
installmentAmount, active, createdAt, updatedAt
```

**LoanInstallmentResponse**
```
id, loanId, installmentNumber, amount, dueDate,
paid, paidDate, createdAt, updatedAt
```

**CategoryFlatResponse**
```
id, parentId, userId, name, type, color, icon, isSystem, active
```

**CategoryTreeResponse**
```
id, name, type, color, icon, isSystem,
subcategories: List<SubcategoryResponse>
```

**SubcategoryResponse**
```
id, name, type, isSystem, userId
```

**SummaryResponse**
```
currency, totalIncome, totalExpense, balance,
activeLoans, totalLoanDebt,
activeCardExpenses, totalCardExpenseDebt
```

---

## 8. Mappers

Todos usan **MapStruct**.

| Mapper | Mappings notables |
|---|---|
| `TransactionMapper` | `category.id → categoryId`, `category.name → categoryName` |
| `CategoryMapper` | `parent.id → parentId` en flat; árbol ignora subcategories (se llenan manualmente) |
| `LoanMapper` | `loan.id → loanId` en installmentResponse |
| `CardExpenseMapper` | Mapeo directo |

---

## 9. Manejo de excepciones

**GlobalExceptionHandler** (`@RestControllerAdvice`)

| Excepción | HTTP | Respuesta |
|---|---|---|
| `ResourceNotFoundException` | 404 | `ApiResponse.error(message)` |
| `BusinessException` | 400 | `ApiResponse.error(message)` |
| `MethodArgumentNotValidException` | 400 | `ApiResponse.error("Validation failed", [field errors])` |
| `Exception` (genérico) | 500 | `ApiResponse.error("An unexpected error occurred")` |

---

## 10. Kafka

### Tópicos (declarados en KafkaConfig)

| Tópico | Particiones | Réplicas |
|---|---|---|
| `payment.due` | 1 | 1 |
| `loan.reminder` | 1 | 1 |
| `installment.reminder` | 1 | 1 |

### Eventos publicados (solo producer, sin consumers)

**PaymentDueEvent** → `payment.due`
```json
{
  "eventType": "PAYMENT_DUE",
  "userId": 1,
  "timestamp": "...",
  "payload": {
    "cardExpenseId": 1,
    "description": "...",
    "nextDueDate": "2026-03-01",
    "installmentAmount": 5000.00,
    "currency": "ARS",
    "remainingInstallments": 3
  }
}
```

**LoanReminderEvent** → `loan.reminder`
```json
{
  "eventType": "LOAN_REMINDER",
  "userId": 1,
  "timestamp": "...",
  "payload": {
    "loanId": 1,
    "loanDescription": "...",
    "nextPaymentDate": "2026-03-01",
    "installmentAmount": 10000.00,
    "currency": "ARS",
    "remainingInstallments": 8
  }
}
```

**InstallmentReminderEvent** → `installment.reminder`
```json
{
  "eventType": "INSTALLMENT_REMINDER",
  "userId": 1,
  "timestamp": "...",
  "payload": {
    "loanId": 1,
    "installmentId": 5,
    "loanDescription": "...",
    "installmentNumber": 3,
    "dueDate": "2026-03-01",
    "amount": 10000.00,
    "currency": "ARS"
  }
}
```

La clave del mensaje Kafka es el `userId` (String). Estos eventos son consumidos por **ms-notifications**.

---

## 11. Scheduler

**FinancesAlertScheduler** — Requiere `@EnableScheduling` en la aplicación.

| Método | Cron | Descripción |
|---|---|---|
| `checkCardExpensesDue()` | `0 0 8 * * *` (08:00 diario) | Gastos de tarjeta con `nextDueDate` entre hoy y hoy + `daysBeforePayment`. Publica `PaymentDueEvent` por cada uno |
| `checkLoansReminder()` | `0 5 8 * * *` (08:05 diario) | Préstamos activos con `nextPaymentDate` entre hoy y hoy + `daysBeforeLoan`. Publica `LoanReminderEvent` |
| `checkInstallmentsReminder()` | `0 10 8 * * *` (08:10 diario) | Cuotas no pagadas con `dueDate` entre hoy y hoy + `daysBeforeInstallment`. Publica `InstallmentReminderEvent` |

Ventanas configurables vía variables de entorno:
- `DAYS_BEFORE_PAYMENT_ALERT` (default: 3)
- `DAYS_BEFORE_LOAN_ALERT` (default: 3)
- `DAYS_BEFORE_INSTALLMENT_ALERT` (default: 3)

---

## 12. Configuración

### application.yml

```yaml
server:
  port: 8082

spring:
  application:
    name: finances-service
  datasource:
    url: ${DB_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}
    driver-class-name: org.postgresql.Driver
  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        default_schema: finances
  flyway:
    schemas: finances
    default-schema: finances
    locations: classpath:db/migration
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
    producer:
      key-serializer: StringSerializer
      value-serializer: JsonSerializer

alerts:
  days-before-payment: ${DAYS_BEFORE_PAYMENT_ALERT:3}
  days-before-loan: ${DAYS_BEFORE_LOAN_ALERT:3}
  days-before-installment: ${DAYS_BEFORE_INSTALLMENT_ALERT:3}
```

### Variables de entorno

| Variable | Descripción |
|---|---|
| `DB_URL` | JDBC URL con schema: `jdbc:postgresql://postgres:5432/db?currentSchema=finances` |
| `DB_USERNAME` | Usuario PostgreSQL |
| `DB_PASSWORD` | Contraseña PostgreSQL |
| `KAFKA_BOOTSTRAP_SERVERS` | Ej: `kafka:9092` |
| `DAYS_BEFORE_PAYMENT_ALERT` | Días de anticipación para alertas de tarjeta (default: 3) |
| `DAYS_BEFORE_LOAN_ALERT` | Días de anticipación para alertas de préstamo (default: 3) |
| `DAYS_BEFORE_INSTALLMENT_ALERT` | Días de anticipación para alertas de cuota (default: 3) |

---

## Patrones arquitectónicos clave

- **Aislamiento por usuario** — Todos los datos filtrados por `userId` vía header `X-User-Id`. No hay acceso cross-user.
- **Soft delete en categorías** — Las categorías se desactivan (`active=false`). Las transacciones, préstamos y gastos de tarjeta se borran físicamente.
- **Jerarquía de 2 niveles** — Las categorías solo pueden ser padre o subcategoría. No se permiten más niveles. Las transacciones solo pueden asociarse a subcategorías.
- **Cuotas secuenciales en préstamos** — Las cuotas deben pagarse en orden; no se puede pagar una cuota si hay anteriores sin pagar.
- **Generación automática de cuotas** — Al crear un Loan se generan todas las LoanInstallment con fechas mensuales desde `firstPaymentDate`.
- **Multi-moneda** — ARS y USD. El summary agrega totales por cada moneda.
- **Solo producer Kafka** — El servicio publica eventos de alerta pero no consume ningún tópico.
- **Swagger disponible** — `/swagger-ui.html` y `/v3/api-docs` (solo en dev, puerto 8082 expuesto vía override).
