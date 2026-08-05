---
name: event-driven
description: Use when working with Kafka events, transactional outbox publishing, CloudEvents 1.0 binary mode, idempotent consumer processing, or DLQ retry logic.
---

# Event-Driven Architecture Skill

## Core Rules

1. **Transactional Outbox**:
   - Outbound domain events MUST be written to the `outbox_event` table in the SAME database transaction as aggregate persistence.
   - Do NOT invoke Kafka producers directly inside HTTP request threads or `@Transactional` use cases.
   - `OutboxRelay` (`@Scheduled` in `commons-messaging`) polls `outbox_event` and dispatches to Kafka asynchronously.

2. **CloudEvents 1.0 Binary Binding**:
   - Headers: `ce_id`, `ce_type`, `ce_source`, `ce_specversion=1.0`, `ce_time`.
   - Topic name MUST equal `ce_type` (e.g. `finances.transaction.created`, `banks.payment.recorded`).
   - Binary mode: event payload is JSON in the record body; metadata attributes travel in Kafka record headers (`CeHeaders`).

3. **Idempotent Consumption**:
   - Consumer listeners MUST record processed events using `ProcessedEventGateway` / `IdempotentEventProcessor`.
   - Deduplicate on `ce_id`. Duplicate events must be silently acknowledged without re-executing domain side-effects.

4. **Error Handling & DLQ**:
   - Listener failures trigger retry via standard container error handlers.
   - After exhausted retries, messages land on `<topic>.DLT`.
