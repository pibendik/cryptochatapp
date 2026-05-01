# Deployment Runbook — cryptochatapp

> **Architecture model**: sealed-envelope postal service.
> The server is a blind relay: it stores encrypted ciphertext envelopes and forgets them on delivery.
> It never sees plaintext. Message history lives on users' devices only.

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Server setup (one-time)](#2-server-setup-one-time)
3. [Deploy the app](#3-deploy-the-app)
4. [Environment variables reference](#4-environment-variables-reference)
5. [First-run checklist](#5-first-run-checklist)
6. [Key-signing ceremony setup](#6-key-signing-ceremony-setup)
7. [Backup and recovery](#7-backup-and-recovery)
8. [Updates](#8-updates)
9. [Monitoring (simple)](#9-monitoring-simple)
10. [Data retention policy](#10-data-retention-policy)
11. [Security notes](#11-security-notes)

---

## 1. Prerequisites

| Requirement | Notes |
|---|---|
| **VPS** | Hetzner CX21 (2 vCPU, 4 GB RAM, AMD64, Germany) or equivalent Bahnhof VPS (Sweden) — both are privacy-friendly providers |
| **Domain name** | A domain with a DNS A-record pointed at the server IP |
| **Git** (local) | To clone the repo onto the server |

That's it — no other local tools needed. Docker and everything else is installed on the server during setup.

---

## 2. Server setup (one-time)

SSH into your freshly provisioned server and run the following as root:

```bash
ssh root@your-server-ip

# Update system packages
apt update && apt upgrade -y

# Install Docker via apt — NOT snap
apt install -y docker.io docker-compose-v2 git ufw

# Configure firewall
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP (Caddy auto-redirects to HTTPS)
ufw allow 443/tcp   # HTTPS
ufw allow 443/udp   # HTTP/3 (QUIC)
ufw enable

# Create a non-root deploy user
useradd -m -s /bin/bash deploy
usermod -aG docker deploy

# Copy your SSH public key to the deploy user
# (run this from your local machine, replacing placeholders)
# ssh-copy-id deploy@your-server-ip
```

> **Why `apt` and not `snap`?** The snap-packaged Docker has known permission issues with
> volume mounts and compose networking. Always install `docker.io` from apt.

From here, all further steps should be run as the `deploy` user:

```bash
su - deploy
```

---

## 3. Deploy the app

```bash
# Clone the repository
git clone https://github.com/YOUR_USER/cryptochatapp /opt/cryptochatapp
cd /opt/cryptochatapp/infra

# Create environment file from template
cp .env.example .env
nano .env   # fill in values — see section 4 for reference

# Build the backend image and start all services
docker compose up -d --build

# Watch logs to confirm startup
docker compose logs -f --tail=50
```

Expected healthy startup sequence in logs:

1. `postgres` — `database system is ready to accept connections`
2. `backend` — `running migrations` then `listening on 0.0.0.0:8080`
3. `caddy` — `certificate obtained successfully` (may take ~10 s on first run)

---

## 4. Environment variables reference

All variables live in `infra/.env`. Copy from `infra/.env.example` and fill in values.

### `DOMAIN`

The public domain name Caddy will serve and obtain a TLS certificate for.

```
DOMAIN=chat.example.com
```

Must match the DNS A-record you configured. Caddy uses this via the `{$DOMAIN}` placeholder in `Caddyfile`.

---

### `POSTGRES_USER`

PostgreSQL username created at database initialisation.

```
POSTGRES_USER=chatapp
```

Only used inside the `chatnet` Docker network — never exposed to the host or internet.

---

### `POSTGRES_PASSWORD`

Password for the PostgreSQL user.

```
POSTGRES_PASSWORD=<strong random value>
```

> **Security**: generate with:
> ```bash
> openssl rand -hex 32
> ```
> Never reuse a password from another service.

---

### `POSTGRES_DB`

Name of the PostgreSQL database.

```
POSTGRES_DB=chatapp
```

---

### `DATABASE_URL`

Full connection string consumed by the Rust backend. Must be kept in sync with the three `POSTGRES_*` values above.

```
DATABASE_URL=postgresql://chatapp:<POSTGRES_PASSWORD>@postgres:5432/chatapp
```

The hostname `postgres` resolves to the `postgres` container on the internal `chatnet` bridge network.

---

### `RUST_LOG`

Log verbosity for the backend binary.

```
RUST_LOG=info
```

Use `debug` or `trace` for troubleshooting; revert to `info` in production to reduce log volume.

---

### `SERVER_ADDR`

The address and port the backend HTTP/WebSocket server binds to inside the container.

```
SERVER_ADDR=0.0.0.0:8080
```

Caddy is the sole public ingress — this port is never exposed to the host.

---

### `ALLOWED_ORIGINS`

Comma-separated list of origins permitted by the CORS policy. Leave empty to deny all cross-origin requests (safe default if you only serve the bundled Flutter web app from the same domain).

```
ALLOWED_ORIGINS=https://chat.example.com
```

Include `tauri://localhost` if you ship a desktop client built with Tauri:

```
ALLOWED_ORIGINS=https://chat.example.com,tauri://localhost
```

---

### `SESSION_TTL_SECS`

How long an authenticated session token remains valid, in seconds.

```
SESSION_TTL_SECS=14400   # 4 hours
```

Auth challenge tokens have a hard-coded 5-minute TTL regardless of this setting; they are garbage-collected automatically.

---

## 5. First-run checklist

Work through these after `docker compose up -d` completes.

- [ ] **DNS propagated** — `dig +short your-domain.com` returns your server IP
- [ ] **HTTP → HTTPS redirect** — `curl -I http://your-domain.com` returns `301` pointing to `https://`
- [ ] **HTTPS working** — `curl -I https://your-domain.com/health` returns `200`
- [ ] **Caddy issued certificate** — `docker compose logs caddy | grep certificate`
- [ ] **Backend healthy** — `curl https://your-domain.com/api/health` returns `200`
- [ ] **Migrations ran** — `docker compose logs backend | grep migration`
- [ ] **WebSocket reachable** — open the app in a browser; check DevTools Network tab for a `101 Switching Protocols` on `/ws`

---

## 6. Key-signing ceremony setup

Before any two users can exchange encrypted messages, all users must meet **physically once** to verify each other's identity and exchange public keys. This is the trust anchor — no central authority, no TOFU.

### Steps

1. **Install the app** — each participant installs cryptochatapp on their device and completes onboarding Step 1 (generates their Ed25519 keypair locally).
2. **Gather in person** — everyone brings their device.
3. **Show QR codes** — each person displays their public-key QR code.
4. **Scan everyone** — each participant scans every other participant's QR code. The app records the verified binding of identity → public key locally.
5. **Register keys on server** — the admin submits all verified public keys to the server. This enables routing: the server can now deliver encrypted envelopes to the right key.
6. **Complete auth** — each user completes the challenge-response auth flow. The session token proves key ownership; the server never sees the private key.
7. **Start communicating** — after ceremony, users can send and receive messages.

```
# BLOCKED(allowlist): Step 5 is currently manual — Phase 3 adds a server-side allowlist UI
# that lets the admin approve or bulk-import public keys without SSH access.
```

### Why physical?

The sealed-envelope model is only as strong as the initial key exchange. A compromised server cannot forge messages because it lacks private keys, but a MITM at key-exchange time could substitute keys. Physical QR scanning prevents that.

---

## 7. Backup and recovery

### What the server backup contains

The server database holds **only**:

| Data | Notes |
|---|---|
| Public keys & user registrations | Permanent — needed for routing and future ceremonies |
| Undelivered message envelopes | Ciphertext blobs only — no plaintext |
| Forum post metadata & encrypted bodies | Ciphertext blobs only |
| Group membership | Permanent — needed for routing |

**Not in the backup**: message history, read receipts, profile data — all of that lives on users' devices.

### Backup command

```bash
# Run on the server as deploy user, from /opt/cryptochatapp/infra
docker compose exec postgres pg_dump -U chatapp chatapp > backup_$(date +%Y%m%d).sql
```

Copy the dump off-server immediately:

```bash
# Run from your local machine
scp deploy@your-server-ip:/opt/cryptochatapp/infra/backup_$(date +%Y%m%d).sql ./
```

> **Note**: Restoring a server backup does **not** restore chat history. That data never left users' devices.

### Recovery

```bash
# Restore into a running postgres container
docker compose exec -T postgres psql -U chatapp chatapp < backup_YYYYMMDD.sql
```

---

## 8. Updates

```bash
cd /opt/cryptochatapp

# Pull latest code
git pull

# Rebuild backend image (Rust binary, statically linked musl)
docker compose build backend

# Roll backend with zero downtime (Caddy keeps serving during the 1-2 s restart)
docker compose up -d backend

# Migrations run automatically on backend startup — watch for errors:
docker compose logs --tail=30 backend
```

For updates that also change Caddy config or postgres init scripts:

```bash
docker compose up -d   # re-creates only changed services
```

---

## 9. Monitoring (simple)

```bash
# Are all three containers running?
docker compose ps

# Disk usage — main concern is the postgres_data volume
docker system df
docker volume inspect infra_postgres_data

# Recent errors from the backend
docker compose logs --since=1h backend | grep -i error

# Caddy access log (JSON format)
docker compose exec caddy tail -f /var/log/caddy/access.log
```

For a heavier setup, point a Prometheus scraper at `/metrics` (if exposed) or ship logs to a LOKI/Grafana stack. For a small private install, the above is sufficient.

---

## 10. Data retention policy

This section documents what the server stores and for how long, consistent with the sealed-envelope model.

| Data | Retention | Rationale |
|---|---|---|
| **Undelivered messages** | Deleted on delivery ACK — server-side lifetime is typically seconds to minutes | Server is a blind relay; holding delivered messages serves no purpose |
| **Forum posts** | Deleted when marked resolved, or after **30 days** automatically | TODO: implement a scheduled cleanup task (cron or background worker) |
| **Auth challenge tokens** | **5 minutes** TTL, GC'd automatically | Replay protection; short window reduces exposure |
| **Public keys** | **Permanent** | Required so others can address encrypted envelopes to you; needed at future ceremonies |
| **Group membership** | **Permanent** | Required for server-side routing of group messages |
| **User history / read receipts / profiles** | **Never stored on server** | Lives on device only — by design |

### What this means in practice

A fully delivered conversation leaves **zero traces** on the server. An attacker who compromises the server after the fact learns nothing about message content — only metadata: who is registered, who belongs to which group, and the sizes of any undelivered envelopes.

---

## 11. Security notes

### What the server cannot see

- **Message content** — all payloads are encrypted with recipients' public keys before leaving the sender's device. The server stores and forwards opaque ciphertext.
- **Forum post content** — encrypted blobs; the server cannot read them.
- **Private keys** — generated and stored on devices only; never transmitted.

### What a compromised server reveals

If the server is seized or breached, an attacker learns:

- Who is registered (public keys and usernames)
- Who belongs to which group
- When users were online (connection timestamps)
- Sizes of undelivered message envelopes (not their content)
- Sizes of forum post blobs (not their content)

### Incident response

If the server is seized or you suspect compromise:

1. **Notify all users immediately** out-of-band.
2. **Take the server offline** — `docker compose down` or destroy the VPS.
3. **Spin up a new server** using this runbook on a fresh machine.
4. **Restore from backup** (public keys and group membership only; message history is on devices).
5. **At the next physical meeting**, rotate all encryption keypairs — each user generates a new keypair and the key-signing ceremony is repeated.

> Rotating keypairs is the definitive response to any key-compromise scenario. Physical ceremony is the only trust anchor.
