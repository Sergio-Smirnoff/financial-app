---
name: solid
description: Use when reviewing class design, splitting a growing class, or deciding where a new responsibility belongs in any backend service in this repo.
---

Mandatory on every class, in every layer, in every service. `ddd` (see `.ai/skills/ddd`) governs
WHAT the model expresses; SOLID governs HOW every class is shaped. A change that satisfies `ddd`
but violates a principle below is still rejected.

## S — Single Responsibility

A class has exactly one reason to change. Controllers translate HTTP only; use cases orchestrate
exactly one business operation; VOs enforce their own invariants; adapters touch exactly one
external system.

Violation: a controller that maps DTOs, validates business rules, and calls repositories directly
instead of delegating to a use case.

## O — Open/Closed

Extend behavior by adding new classes or enum constants, never by editing stable ones. Service
exception handlers extend the shared base and add handlers; new error kinds are new `DomainError`
constants — the category→HTTP mapper never changes per code.

Violation: adding an `if (type == X)` branch to an existing class every time a new case appears.

## L — Liskov Substitution

Every subtype is usable wherever its base type is expected, with no surprises. Any
`DomainException` subclass flows through the same `GlobalExceptionHandler`; any port
implementation honors the port's full contract.

Violation: a repository implementation that throws `UnsupportedOperationException` on one
inherited method instead of implementing it.

## I — Interface Segregation

Ports expose only what their consumer needs — `SupportedCurrencies` has exactly `isSupported` and
`all`, not a grab-bag of currency operations no caller uses. Split a `<Noun>Gateway` per consumer
rather than growing one fat gateway interface that each adapter partially implements.

Violation: a single `AccountPort` with 15 methods where each adapter implements 3 and stubs the
other 12.

## D — Dependency Inversion

High-level policy depends on abstractions, never on concretions. The domain defines
`domain/gateway/` and `domain/repository/` ports; `infrastructure` implements them. Shared code
depends on the `ErrorCode` interface, never on a concrete service's `DomainError` enum. Domain has
zero framework imports (ArchUnit-enforced where present).

Violation: a use case importing a JPA repository or a Feign client directly instead of the domain
port.

## OOP baseline

Behavior lives with the data it operates on (encapsulation — this is also the anemic-model rule in
`ddd` §5). Inheritance only for true is-a relationships; composition otherwise. No
`instanceof`/type-switch chains where polymorphism does the job.
