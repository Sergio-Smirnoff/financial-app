# Deployment

`dev.sh` command reference is in `.ai/references/SCRIPTS.md`. `.env.example` is the canonical
env-var reference — it wins over this file.

## Port map

| Service | Compose name | Host port |
|---|---|---|
| ms-gateway | `gateway` | 8080 — single external entry point for `/api/v1/...` |
| ms-users | `service-users` | 8081 |
| ms-finances | `service-finances` | 8082 |
| ms-banks | `service-banks` | 8083 |
| ms-notifications | `service-notifications` | 8084 |
| ms-upload | `service-upload` | 8085 |
| ms-investments | `service-investments` | 8086 |
| Frontend | `frontend` | 3000 |
| PostgreSQL | `postgres` | 5432 |
| Kafka | `kafka` | 9093 host / 9092 inter-container |
| MinIO | `minio` | 9000 API, 9001 console |

Swagger: aggregated at `http://localhost:8080/swagger-ui.html`; per-service at
`http://localhost:<port>/swagger-ui.html`, **dev mode only** (those ports exist only via
`docker-compose.override.yml`).

## Environment variables

Copy `.env.example` to `.env`. Never commit `.env`.

| Variable | Default / example | Purpose |
|---|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `financialapp` / `changeme` / `financialapp` | database credentials |
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka:9092` | `local-all` overrides to `localhost:9093` |
| `KAFKA_CLUSTER_ID` | base64 UUID | **required** for KRaft; without a fixed id the broker re-formats storage on every recreate. Generate: `docker run --rm confluentinc/cp-kafka:7.7.0 kafka-storage random-uuid` |
| `JWT_SECRET` | 64+ char random | HMAC-SHA signing key |
| `INTERNAL_AUTH_TOKEN` | random | shared `X-Internal-Token` for service-to-service calls; **required** — every backend hard-fails at startup without it |
| `JWT_EXPIRATION` / `JWT_REFRESH_EXPIRATION` | `86400000` / `604800000` | access 24 h, refresh 7 d, in ms |
| `JWT_ENABLED` | `true` | disables gateway JWT validation — local testing only |
| `RATE_LIMIT_RPM` | `600` | gateway per-IP limit |
| `COOKIE_SECURE` | `false` | must be `true` in production |
| `ALLOWED_ORIGINS` | `https://<domain>,http://localhost` | gateway CORS list |
| `NEXT_PUBLIC_GATEWAY_URL` | `https://<domain>/api` | baked into the Next.js image at build |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | `minioadmin` / `changeme` | object storage |
| `IOL_USERNAME` / `IOL_PASSWORD` | — | InvertirOnline price feed |
| `DOMAIN_NAME` / `ACME_EMAIL` | — | Traefik host routing + Let's Encrypt |
| `MAIL_HOST` / `MAIL_PORT` / `MAIL_USERNAME` / `MAIL_PASSWORD` | — | notification email |
| `DUCKDNS_DOMAIN` / `DUCKDNS_TOKEN` | — | optional dynamic DNS |
| `GRAFANA_ADMIN_PASSWORD` | — | Grafana at `/grafana` |
| `SWAGGER_AUTH` | `admin:$$apr1$$...` | htpasswd basic-auth. **Double every `$` to `$$` in `.env`** — compose interpolates values and a literal `$apr1$` hash gets corrupted. Generate `htpasswd -nb admin 'pass'`, then double |
| `<SERVICE>_VERSION` | `latest` | pins the GHCR tag per service |

## Startup flow

Infra (`postgres`, `kafka` KRaft, `minio`) and monitoring (`prometheus`, `grafana`, `loki`,
`promtail`) carry no profile and start first — monitoring is always up with the stack. App
services need `--profile app` and will not start without it. Compose waits for postgres to
report healthy, then starts the six backend services, then the gateway (which `depends_on`
all of them), then the frontend (which `depends_on` the gateway).

On first start only, `infra/postgres/init/01-create-schemas.sql` creates the six per-service
schemas. Later `up` runs do not re-execute it.

## Docker vs local

`docker-compose.override.yml` is **dev-only** and does exactly one thing: publish host ports —
infra (5432, 9093, 9000/9001), gateway 8080, frontend 3000, every microservice 8081–8086 so
per-service Swagger is reachable, monitoring (9090, 3001, 3100), and the Traefik dashboard on
8888. Compose auto-loads it whenever you run plain `docker compose` with no `-f`.

Production therefore **must** name the file explicitly, so the override is never picked up:

```bash
docker compose -f docker-compose.yml --profile app up -d
```

Nothing is exposed to the host but Traefik's 80 and 443. Traefik terminates TLS and routes by
host + path prefix to `gateway:8080`, `frontend:3000` or `grafana:3000`.

**Never run `docker-compose.override.yml` or `scripts/dev.sh` on a production server.**

Local hybrid mode — `scripts/dev.sh local-all` — runs infra in Docker and services as local
JVM processes, overriding `KAFKA_BOOTSTRAP_SERVERS=localhost:9093`, `DB_URL` to
`localhost:5432` with `currentSchema=<schema>`, and every `*_SERVICE_URL` to `localhost:<port>`.
Logs land in `./logs/<service>.log`.

## Images and releases

Published to `ghcr.io/sergio-smirnoff/<service>` by each repo's `docker-publish.yml`, which
delegates to the reusable workflows. Push to `master` tags `latest` + `sha-<shortsha>`; a
`v*` tag adds `X.Y.Z` and `X.Y`. Release mechanics: `.ai/references/PIPELINE.md`.

Pin a service on the server by setting its `<SERVICE>_VERSION` in `.env`; unset means
`latest`. Rollback is setting the previous version and re-running the `up -d` command.

## First-time deploy

Requirements: Linux host x86-64 or ARM64 (images are multi-arch), 2+ vCPU, 4 GB+ RAM, ~20 GB
disk; Docker Engine 24+ with Compose v2; ports 80 and 443 open; a domain pointing at the
public IP; a GHCR classic PAT with `read:packages` if the images are private.

The server needs the **root repo only** — images are prebuilt, service sources are never
cloned there.

1. `curl -fsSL https://get.docker.com | sh` (skip if Docker is present)
2. `git clone https://github.com/Sergio-Smirnoff/financial-app.git && cd financial-app`
3. `cp .env.example .env`, then fill in at minimum `POSTGRES_PASSWORD`, `JWT_SECRET`,
   `INTERNAL_AUTH_TOKEN`, `KAFKA_CLUSTER_ID`, `DOMAIN_NAME`, `ACME_EMAIL`,
   `GRAFANA_ADMIN_PASSWORD`, `SWAGGER_AUTH`, and `COOKIE_SECURE=true`
4. Point an A record for `DOMAIN_NAME` at the server's public IP
5. `echo "$GHCR_TOKEN" | docker login ghcr.io -u <github-username> --password-stdin`
6. `docker compose -f docker-compose.yml --profile app up -d`

Traefik requests Let's Encrypt certificates on first start via HTTP-01, so port 80 must be
reachable from the internet.

`scripts/deploy.sh` automates steps 3 and 5 as a wizard; `scripts/deploy.sh --update` pulls
the root repo and images (honouring `*_VERSION` pins) and restarts. Equivalent to the raw
commands — use either.

## Reachable after deploy

| URL | Served by | Auth |
|---|---|---|
| `https://<domain>` | frontend | app login |
| `https://<domain>/api` | gateway | JWT cookie |
| `https://<domain>/swagger-ui.html` | gateway (aggregated) | basic-auth via `SWAGGER_AUTH` |
| `https://<domain>/grafana` | grafana | `admin` / `GRAFANA_ADMIN_PASSWORD` |

Internal-only in production: Postgres, Kafka, MinIO, Prometheus, Loki, Promtail.

## Operations

```bash
docker compose -f docker-compose.yml --profile app pull    # update
docker compose -f docker-compose.yml --profile app up -d
docker compose -f docker-compose.yml --profile app ps
docker compose -f docker-compose.yml --profile app logs -f gateway
docker compose -f docker-compose.yml --profile app down
./scripts/backup.sh                                        # Postgres + MinIO snapshots
```

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Let's Encrypt cert not issued | port 80 unreachable, or DNS not propagated. Check `docker compose logs traefik` |
| Kafka re-formats data on restart | `KAFKA_CLUSTER_ID` not set to a fixed value |
| Swagger basic-auth always fails | `$` not doubled to `$$` in `SWAGGER_AUTH` — compose ate the hash |
| Service exits with auth error at boot | `INTERNAL_AUTH_TOKEN` missing |
| Traefik 502 on `/api` | backend still starting or unhealthy — check `ps` and that service's logs |
| CORS errors in browser | `ALLOWED_ORIGINS` must include `https://<domain>`; `NEXT_PUBLIC_GATEWAY_URL` must be `https://<domain>/api` |
| Container OOM-killed | host under-provisioned — compose caps Spring services at 768 MB each |
