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
| `ALLOWED_ORIGINS` | derived — leave empty | gateway CORS list. Empty means compose derives `https://$DOMAIN_NAME[,https://$SECONDARY_DOMAIN_NAME],http://localhost`; a value set here wins outright. TLS terminates at the edge, so the gateway sees `http://gateway:8080` against an `https://<host>` `Origin` and treats even same-host calls as CORS — **every** served hostname must appear here or state-changing requests 403 |
| `NEXT_PUBLIC_GATEWAY_URL` | empty | must stay empty. The published frontend image is built with no such build-arg, so the bundle inlines an empty base URL and calls the gateway same-origin at `/api` (edge routes `PathPrefix('/api')` to the gateway, no prefix stripping). An empty base is what lets one image serve every hostname; an absolute value would pin the build to one host and yield a broken `/api/api/v1/...` |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | `minioadmin` / `changeme` | object storage |
| `IOL_USERNAME` / `IOL_PASSWORD` | — | InvertirOnline price feed |
| `DOMAIN_NAME` | — | primary public hostname; feeds `ALLOWED_ORIGINS` and `GF_SERVER_ROOT_URL`. Host routing + TLS are configured in the edge stack, not here |
| `SECONDARY_DOMAIN_NAME` | empty | optional second public hostname served alongside `DOMAIN_NAME`. Set during a domain migration so both are accepted at once; purely additive |
| `GRAFANA_ROOT_URL` | derived from `DOMAIN_NAME` | overrides Grafana's `root_url`. Only Grafana's own absolute links (alert notifications, share links) follow it — the UI keeps serving from `/grafana` on every hostname via `GF_SERVER_SERVE_FROM_SUB_PATH` |
| `MAIL_HOST` / `MAIL_PORT` / `MAIL_USERNAME` / `MAIL_PASSWORD` | — | notification email |
| `GRAFANA_ADMIN_PASSWORD` | — | Grafana at `/grafana` |
| `<SERVICE>_VERSION` | `latest` | pins the GHCR tag per service |

## Routing and TLS (external — `homelab-infra/stacks/edge/`)

This repo no longer runs Traefik or DuckDNS. Ingress, TLS termination, Let's Encrypt and
dynamic DNS live in the separate **edge stack** at `homelab-infra/stacks/edge/`, which runs
Traefik with the **file provider** (no Docker socket). Consequences:

- App compose publishes **no host port at all** in production. Only the edge stack binds 80/443.
- `gateway`, `frontend` and `grafana` join the **external `edge` network** under exactly those
  DNS names — that is what the edge `dynamic/dynamic.yml` service URLs resolve to
  (`http://gateway:8080`, `http://frontend:3000`, `http://grafana:3000`). Data stores
  (postgres, kafka, minio, prometheus, loki, promtail) stay on `internal` only.
- **Changing an app route (host, path prefix, port) requires a matching `dynamic.yml` commit
  in homelab-infra.** There are no `traefik.*` labels in this repo any more; adding some would
  do nothing.
- Swagger basic-auth is enforced by the edge stack's middleware, so `SWAGGER_AUTH` is an edge
  env var now, not an app one. `ACME_EMAIL`, `DUCKDNS_TOKEN` and `DUCKDNS_DOMAIN` moved there too.
- Prod bring-up **expects the external `edge` network to already exist**:
  `docker network create edge` (or bring the edge stack up first). Compose fails fast otherwise.

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
per-service Swagger is reachable, and monitoring (9090, 3001, 3100). Compose auto-loads it
whenever you run plain `docker compose` with no `-f`.

**Dev prerequisite (once per machine):** `grafana` carries no profile and joins `edge`, so even
a plain dev `up` needs that network to exist. On a fresh clone, run:

```bash
docker network create edge     # once per machine; harmless if it already exists
```

Production therefore **must** name the file explicitly, so the override is never picked up:

```bash
docker compose -f docker-compose.yml --profile app up -d
```

In production the app stack publishes **no host ports**. The edge stack
(`homelab-infra/stacks/edge/`) owns 80/443, terminates TLS and routes by host + path prefix
over the shared `edge` network to `gateway:8080`, `frontend:3000` or `grafana:3000`.

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
disk; Docker Engine 24+ with Compose v2; a GHCR classic PAT with `read:packages` if the images
are private. Ports 80/443, the domain and the certificates are the edge stack's business —
see `homelab-infra/stacks/edge/`.

The server needs the **root repo only** — images are prebuilt, service sources are never
cloned there.

1. `curl -fsSL https://get.docker.com | sh` (skip if Docker is present)
2. `git clone https://github.com/Sergio-Smirnoff/financial-app.git && cd financial-app`
3. `cp .env.example .env`, then fill in at minimum `POSTGRES_PASSWORD`, `JWT_SECRET`,
   `INTERNAL_AUTH_TOKEN`, `KAFKA_CLUSTER_ID`, `DOMAIN_NAME`, `GRAFANA_ADMIN_PASSWORD`, and
   `COOKIE_SECURE=true`
4. Bring up the edge stack (`homelab-infra/stacks/edge/`), which creates the external `edge`
   network and handles DNS/TLS. Standalone check: `docker network create edge` if it is missing
5. `echo "$GHCR_TOKEN" | docker login ghcr.io -u <github-username> --password-stdin`
6. `docker compose -f docker-compose.yml --profile app up -d`

The app stack will not start if the external `edge` network does not exist.

`scripts/deploy.sh` automates steps 3 and 5 as a wizard and then **prints** steps 4 and 6 for
you to run — it does not bring the stack up itself. `scripts/deploy.sh --update` pulls the root
repo and images (honouring `*_VERSION` pins), creates the external `edge` network if it is
missing, and restarts the stack — that path is equivalent to running steps 4 and 6 by hand.
Neither path starts the edge stack; routing/TLS are brought up separately from homelab-infra.

## Reachable after deploy

| URL | Served by | Auth |
|---|---|---|
| `https://<domain>` | frontend | app login |
| `https://<domain>/api` | gateway | JWT cookie |
| `https://<domain>/swagger-ui.html` | gateway (aggregated) | basic-auth, enforced by the edge stack |
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
| `network edge declared as external, but could not be found` | the edge stack is not up. Start it, or `docker network create edge` |
| Kafka re-formats data on restart | `KAFKA_CLUSTER_ID` not set to a fixed value |
| Swagger basic-auth always fails | `SWAGGER_AUTH` is configured in the edge stack now — fix it there |
| Service exits with auth error at boot | `INTERNAL_AUTH_TOKEN` missing |
| 502 on `/api` | backend still starting or unhealthy, or `gateway` is not on the `edge` network — check `ps`, that service's logs, and `docker network inspect edge` |
| CORS errors in browser | `ALLOWED_ORIGINS` must include `https://<domain>` for **every** hostname served — add the second one via `SECONDARY_DOMAIN_NAME`. `NEXT_PUBLIC_GATEWAY_URL` must be empty |
| New hostname 403s on login but GETs work | that hostname is missing from `ALLOWED_ORIGINS`. Browsers send `Origin` on same-host non-GET requests and the gateway sees them as CORS |
| Container OOM-killed | host under-provisioned — compose caps Spring services at 768 MB each |
