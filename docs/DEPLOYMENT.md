# Deployment Guide

## Infrastructure

- **Server:** Ubuntu + CasaOS at `192.168.0.218`
- **Access:** SSH as `ssmirnoff`
- **App directory:** `~/apps/financial-app`
- **Stack:** Docker Compose (managed via terminal, not CasaOS UI)

---

## First-Time Deployment

### 1. Server prerequisites

```bash
docker --version        # need Docker 24+
docker compose version  # need Compose v2+
git --version
```

### 2. Set up GitHub SSH key on server

```bash
ssh-keygen -t ed25519 -C "casaos-deploy" -N "" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
# Add key at: https://github.com/settings/ssh/new
ssh -T git@github.com   # verify
```

### 3. Clone main repo and all services

```bash
git clone git@github.com:Sergio-Smirnoff/financial-app.git ~/apps/financial-app
cd ~/apps/financial-app
./deploy.sh
```

### 4. Copy production `.env`

From local machine:
```bash
scp .env.production ssmirnoff@192.168.0.218:~/apps/financial-app/.env
```

> Keep `.env.production` locally as backup. Never commit it.

### 5. Build all images (15–30 min first time)

```bash
sudo docker compose -f docker-compose.yml --profile app build
```

### 6. Start infrastructure

```bash
sudo docker compose -f docker-compose.yml up -d postgres zookeeper kafka minio
sleep 20
# Verify schemas created:
sudo docker compose -f docker-compose.yml exec postgres psql -U financialapp -d financialapp -c "\dn"
```

### 7. Start app services

```bash
sudo docker compose -f docker-compose.yml --profile app up -d
sudo docker compose ps
```

### 8. Verify

```bash
curl -s http://localhost:8080/actuator/health
```

Open `http://192.168.0.218:3000` in browser.

---

## Updating After Code Changes

### Single backend service

```bash
ssh ssmirnoff@192.168.0.218
cd ~/apps/financial-app
./deploy.sh --update
sudo docker compose -f docker-compose.yml --profile app build <service-name>
sudo docker compose -f docker-compose.yml --profile app up -d <service-name>
```

### Frontend (always requires full rebuild — env vars baked at build time)

```bash
./deploy.sh --update
sudo docker compose -f docker-compose.yml --profile app build frontend
sudo docker compose -f docker-compose.yml --profile app up -d frontend
```

### All services (when unsure what changed)

```bash
./deploy.sh --update
sudo docker compose -f docker-compose.yml --profile app build
sudo docker compose -f docker-compose.yml --profile app up -d
```

---

## Service Name Reference

| Repo | Docker service name | Port |
|---|---|---|
| ms-gateway | `gateway` | 8080 |
| ms-users | `service-users` | 8081 |
| ms-finances | `service-finances` | 8082 |
| ms-cards | `service-cards` | 8083 |
| ms-notifications | `service-notifications` | 8084 |
| ms-upload | `service-upload` | 8085 |
| ms-investments | `service-investments` | 8086 |
| front/financial-app | `frontend` | 3000 |

---

## Day-to-Day Operations

```bash
# View logs (follow)
sudo docker compose logs -f gateway
sudo docker compose logs -f service-finances

# Restart single service
sudo docker compose -f docker-compose.yml restart service-finances

# Check all containers
sudo docker compose ps

# Stop everything (keeps data volumes)
sudo docker compose -f docker-compose.yml --profile app down
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Frontend 404 / failed to fetch | `NEXT_PUBLIC_GATEWAY_URL` not baked in | Rebuild frontend image |
| CORS error | `ALLOWED_ORIGINS` wrong | Must include `http://192.168.0.218:3000` |
| Login cookies not set | `COOKIE_SECURE=true` on HTTP | Set `COOKIE_SECURE=false` in `.env` |
| Service crash on start | Missing/wrong env var | `sudo docker compose logs <service> --tail=40` |
| DB schemas missing | Postgres volume existed before init | Re-run infra step with fresh volume |
| Notifications crash | Cron expression wrong | Spring needs 6 fields: `0 0 8 * * *` not `0 8 * * *` |

---

## Notes

- Use terminal for all operations — CasaOS UI does not manage this app
- `docker compose down` (without `-v`) keeps data volumes safe
- `.env` on server is the only copy — keep local `.env.production` as backup
- `deploy.sh --update` pulls all 9 repos; only changed services need rebuilding
