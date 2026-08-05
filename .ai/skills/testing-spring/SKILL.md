---
name: testing-spring
description: Use when writing or reviewing unit, slice, or integration tests in any Spring Boot backend service.
---

# Spring Boot Testing Standards Skill

## Core Rules

1. **Test Isolation & Speed**:
   - Prefer pure unit tests for domain logic (`domain/model`, `domain/service`, use cases) without launching Spring context (`MockitoExtension` / plain JUnit 5).
   - Use web slice tests (`@WebMvcTest` / `@WebFluxTest`) for REST controllers and HTTP serialization verification.

2. **Integration Tests**:
   - Integration tests MUST run cleanly on bare CI runners without external Docker requirements.
   - Use `H2` for in-memory database tests or Testcontainers when explicit PostgreSQL dialect features are tested.
   - Use `EmbeddedKafka` for event publishing/listening verification.

3. **No Muted Test Assertions**:
   - Never use `@Disabled` without an linked issue/ticket rationale.
   - Never swallow exceptions in tests or replace failing assertions with empty fallbacks.
