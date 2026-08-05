---
name: rest-api
description: Use when designing, creating, reviewing, or refactoring REST controllers, OpenAPI error codes, pagination, and ApiResponse envelopes in any microservice.
---

# REST API Design & Review Skill

## Core Rules

1. **Response Envelope (`ApiResponse<T>`)**:
   - Every controller endpoint returns `ApiResponse<T>` from `commons-core`.
   - Never return raw DTOs, naked entities, or custom `ResponseEntity<X>` wrappers that omit `ApiResponse`.

2. **Error Handling & Declarations**:
   - Controller methods declare throwable domain errors using `@ApiErrorCodes(catalog = DomainError.class, ...)`.
   - Error responses travel in the exact same `ApiResponse<T>` envelope where `code` holds the `DomainError` enum slug and details travel in `data`.
   - Exceptions extend `DomainException` and are handled globally by `GlobalExceptionHandler`.

3. **HTTP Status Codes & Verbs**:
   - `GET`: `200 OK` for success. Query parameters for filtering/paging.
   - `POST`: `201 Created` for resource creation (include `Location` header if URI exists).
   - `PUT`: `200 OK` for full updates or upserts.
   - `PATCH`: `200 OK` for partial modifications.
   - `DELETE`: `200 OK` or `204 No Content`.
   - Domain validation errors: `422 Unprocessable Entity`.
   - Resource not found: `404 Not Found`.
   - Unauthorized: `401 Unauthorized`.
   - Forbidden: `403 Forbidden`.

4. **Pagination**:
   - Use cursor-based pagination (`PageResult<T>`) for large collections (e.g. transactions).
