# Server Deployment & Maintenance Guide

This document outlines the workflow and server deployment procedure for the Financial App.

## 1. Git Workflow (`develop` to `master`)

The application follows a standard branching model:
*   **`develop`**: All new features, bug fixes, and active development happen here. Code is tested locally or in staging against this branch.
*   **`master`**: The production-ready branch. Once code in `develop` is verified, it is merged into `master`. 

**The production server ALWAYS pulls from the `master` branch.**

## 2. Initial Server Setup (One-time)

Your production server (e.g., a CasaOS environment) needs the following prerequisites:
*   **Git** installed.
*   **Docker** and **Docker Compose** (v2) installed.
*   **SSH Keys**: The server must be authorized to pull from GitHub. 
    *   Generate a key: `ssh-keygen -t ed25519 -C "server-deploy"`
    *   Add the contents of `~/.ssh/id_ed25519.pub` to your GitHub account.

### GitHub Container Registry (GHCR) Setup
The application uses GitHub Actions to build Docker images and push them to GHCR. Your server will only *download* these pre-built images.
1. Go to your GitHub settings -> Developer Settings -> Personal Access Tokens.
2. Generate a new token (Classic) with the `read:packages` scope.
3. Save this token. The deployment script will ask for it during the first run to authenticate the server.

### Network Configuration & SSL (Traefik)
Because the server runs CasaOS (which manages its own Docker networks and other apps like Ollama/n8n), **we do not use UFW**. Instead, security is handled entirely by Docker:
*   The `docker-compose.yml` does **NOT** expose ports for internal services (Postgres, Minio, Kafka, Gateway, Frontend) to the host.
*   Only the `traefik` service exposes ports `80` and `443` to the internet. 

**Domain and SSL:** The system uses Traefik as an intelligent reverse proxy. It will automatically generate and renew SSL certificates using Let's Encrypt for your domain. 
*   **Requirement**: You must have a domain name (e.g. via DuckDNS or Cloudflare) pointing to your server's Public IP.
*   Port 80 and 443 must be forwarded in your router to your CasaOS server.

## 3. Deploying / Updating

To deploy the application for the first time, or to pull the latest changes from `master`:

1.  SSH into your server.
2.  Navigate to the project root directory.
3.  Run the deployment script:
    ```bash
    # For a fresh install (clones repos):
    ./scripts/deploy.sh

    # To update existing code to the latest master branch:
    ./scripts/deploy.sh --update
    ```
4.  **First time only**: The script will interactively ask for your Domain Name, Let's Encrypt email, new passwords, and your GitHub Username and PAT to automatically generate a secure `.env` file and log you into GHCR.
5.  After the script finishes, pull the latest images and start the containers:
    ```bash
    # Start Infra, Traefik & DuckDNS
    docker compose -f docker-compose.yml up -d postgres zookeeper kafka minio traefik duckdns

    # Download updated images from GHCR
    docker compose -f docker-compose.yml --profile app pull

    # Start Microservices & Frontend
    docker compose -f docker-compose.yml --profile app up -d
    ```

*Note: Never use `docker-compose.override.yml` or `./scripts/dev.sh` in the production server, as they open insecure debugging ports.*

## 4. Backups

A backup script is provided to safely export your PostgreSQL database and MinIO files.

```bash
./scripts/backup.sh
```
This creates timestamped `.sql.gz` and `.tar.gz` archives in the `backups/` folder. It is recommended to set up a Cron job on your server to run this script daily or weekly.

---

## 5. Troubleshooting

If services fail to start or connect, check these common issues:

### A. "Database connection refused" (Spring Boot logs)
*   **Cause**: `postgres` container is down, or credentials in `.env` don't match.
*   **Fix**: 
    1. Check status: `docker compose ps`
    2. Read DB logs: `docker compose logs postgres`
    3. Ensure `POSTGRES_PASSWORD` matches exactly in the `.env` file.

### B. "Kafka broker not available"
*   **Cause**: Zookeeper hasn't fully started, or the JVM ran out of memory.
*   **Fix**: Kafka requires a lot of RAM. Check if the container was OOMKilled (`docker compose ps`). Try restarting it individually: `docker compose restart kafka`.

### C. Traefik "502 Bad Gateway"
*   **Cause**: Traefik is running, but either `gateway:8080` or `frontend:3000` is down or still booting.
*   **Fix**: 
    1. Java microservices take ~30-60 seconds to boot on limited RAM (`-Xmx256m`). Wait a minute and refresh.
    2. Check gateway logs: `docker compose --profile app logs gateway`.

### D. Frontend CORS Errors or "Network Error" on Login
*   **Cause**: The `NEXT_PUBLIC_GATEWAY_URL` or `ALLOWED_ORIGINS` in `.env` are misconfigured.
*   **Fix**: 
    1. Ensure `NEXT_PUBLIC_GATEWAY_URL=https://<YOUR_DOMAIN>/api`
    2. Ensure `ALLOWED_ORIGINS` includes `https://<YOUR_DOMAIN>` and `http://localhost`.
    3. **Crucial**: If you changed `.env`, you MUST rebuild the frontend image or ensure GH Actions is triggered to bake the correct `NEXT_PUBLIC_` variable. (Note: in production, images are pre-baked; you may need to use environment injection at runtime or re-build the specific image via GH Actions).


### E. High Memory Usage / Host Freezing
*   **Cause**: Java limits are not being applied.
*   **Fix**: Verify that `JAVA_TOOL_OPTIONS: "-Xmx256m -Xms128m"` is present in `docker-compose.yml` for all Spring Boot services, and that Docker `deploy.resources.limits.memory` is set to `350M`.
