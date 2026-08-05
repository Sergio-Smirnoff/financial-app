# ms-upload — Statement Upload & Bulk Import Service

> Human-facing. Facts an implementer needs live in `back/ms-upload/.ai/` — this page holds the
> reasoning behind them and does not restate them. If the two disagree, the repo file wins.

`ms-upload` is the ingestion gateway for bulk financial data. A user uploads a bank statement (PDF) or a generic CSV export; the service stores the raw file in MinIO under a `temp/` prefix, parses it into a list of candidate transactions, and returns a preview. The user then reviews and optionally re-categorises each row before confirming. On confirmation the service creates an `ImportRun` aggregate, dedupes against active imports via `FileHash` (SHA-256), forwards each transaction to `ms-finances` (or card installments to `ms-banks`), computes a `ReconciliationResult`, moves the file from `temp/` to `imports/{userId}/{importRunId}/...`, and persists the import run and created transaction IDs.

---

## Upload → Preview → Confirm Flow

```mermaid
sequenceDiagram
    actor User
    participant Frontend
    participant Gateway
    participant ms-upload
    participant MinIO
    participant ms-finances

    User->>Frontend: Drop file + select FileType
    Frontend->>Gateway: POST /api/v1/upload/statement/preview (multipart)
    Gateway->>ms-upload: forward + inject X-User-Id header

    ms-upload->>MinIO: store raw file at temp/{uuid}/{filename}
    ms-upload->>ms-upload: save UploadSession (tempKey → userId)
    ms-upload->>ms-upload: StatementParserPort.parse(stream, FileType)
    ms-upload-->>Gateway: StatementPreviewResponse {tempKey, transactions[], totalAmount, count}
    Gateway-->>Frontend: 200 OK

    Frontend->>User: Show ImportPreviewDialog\n(account selector + row-by-row category mapping)
    User->>Frontend: Select account, adjust categories, click Confirm

    Frontend->>Gateway: POST /api/v1/upload/statement/confirm\n{tempKey, accountId, fileType, mappings[]}
    Gateway->>ms-upload: forward + inject X-User-Id header

    ms-upload->>ms-upload: ConfirmImportUseCase (FileHash SHA-256 dedup check)
    loop for each mapping / parsed tx
        ms-upload->>ms-finances: POST /api/v1/finances/transactions
        ms-finances-->>ms-upload: 201 Created {id} / error (skipped, counted)
    end
    ms-upload->>ms-upload: Compute ReconciliationResult (statement vs calculated)
    ms-upload->>MinIO: move file to imports/{userId}/{importRunId}/...
    ms-upload->>ms-upload: record ImportRun (COMPLETED | PARTIAL)
    ms-upload-->>Gateway: StatementConfirmResponse {importId, status, importedCount}
    Gateway-->>Frontend: 200 OK
    Frontend->>User: Show success toast
```
