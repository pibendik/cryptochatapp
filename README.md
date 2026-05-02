# cryptochatapp

A privacy-first, end-to-end encrypted group chat for small high-trust communities (~20 people). Designed so the server is a dumb pipe that routes ciphertext and never reads your messages.

**Features**
- Permanent group chat with MLS RFC 9420 epoch-based key rotation
- One-on-one encrypted DMs (Double Ratchet / ECIES)
- Ephemeral "I need help" ad-hoc sessions — raised, joined, then permanently deleted
- Forum board for posting help requests
- User profiles with skills/availability
- Physical key-signing ceremony for onboarding — no passwords, no TOFU
- 2-member consensus required to add or remove anyone from the group
- Silent push notifications (APNs/FCM) — zero message content ever reaches Apple or Google

**Platforms:** iOS · Android · Linux · macOS · Windows · Web (Flutter)

---

## Table of contents

1. [Security model](#security-model)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Local development](#local-development)
   - [Backend (Rust)](#backend-rust)
   - [Flutter client](#flutter-client)
   - [Full stack with Docker](#full-stack-with-docker)
5. [Running tests](#running-tests)
6. [Code generation](#code-generation)
7. [Project structure](#project-structure)
8. [Key conventions](#key-conventions)
9. [Deployment](#deployment)
10. [Contributing](#contributing)
11. [Docs index](#docs-index)

---

## Security model

> Read this before touching crypto code.

| Principle | Implementation |
|-----------|---------------|
| Server sees only ciphertext | All message bodies, forum titles, and profiles are encrypted client-side before upload |
| No passwords | Identity IS the Ed25519 keypair. Auth is challenge-response: server issues nonce, client signs it |
| Keys never leave the device | Private keys live in the OS Keychain / Secure Enclave only — never in the app DB or on the server |
| Physical trust bootstrap | New members generate a keypair, display a QR code, every existing member scans and signs it in person |
| No single admin | Any member add/remove requires approval from **2 existing members** |
| Forward secrecy + PCS | MLS RFC 9420 for groups; ECIES fallback for 1:1 DMs while MLS FFI codegen is pending |
| Ephemeral means ephemeral | Server deletes ephemeral session blobs on close; clients delete local session on `ephemeral_deleted` event |

**Primary threat: compromised device.** A stolen phone can only access messages stored locally on that device. The blast radius is bounded because MLS epoch rotation on member removal ensures the removed party cannot decrypt future messages. See `docs/KEY_ROTATION.md` for the lost-phone recovery runbook.

---

## Architecture

```
Flutter client (all platforms)
  │  E2E encrypted envelopes over WebSocket (TLS 1.3)
  ▼
Rust + Axum server          ← routes ciphertext blobs by group ID, never decrypts
  │
  ├── PostgreSQL             ← public keys, undelivered envelopes (deleted on ACK ~1 min),
  │                            forum posts (deleted on resolve / 30 days), auth challenges
  └── (no message history)  ← history lives on device in drift SQLite (SQLCipher-ready)
```

Data flow on send:
1. Client encrypts plaintext with MLS epoch key (group) or ECIES (1:1) — plaintext never leaves the device.
2. Encrypted envelope is sent over the authenticated WebSocket (`Authorization` token in first message).
3. Server verifies JWT, looks up recipient group members, stores blob in PostgreSQL.
4. On delivery, server sends ACK; client confirms; server deletes the blob ~60 seconds later.
5. Recipient decrypts locally, stores plaintext in drift SQLite.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Rust | 1.77+ | `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh` |
| Flutter | 3.13+ | See [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install) — **use apt or official installer, not snap** |
| Docker + Docker Compose v2 | latest | `apt install -y docker.io docker-compose-v2` |
| PostgreSQL client (optional) | 15+ | For direct DB inspection |
| `sqlx-cli` (optional) | 0.7+ | `cargo install sqlx-cli --no-default-features --features postgres` |

> **Note on Flutter installation:** If you are on Ubuntu/Debian, install Flutter via the [official Linux installer](https://docs.flutter.dev/get-started/install/linux) or the Flutter snap — but **do not mix** apt-installed Docker with snap-installed Docker. Pick one source per tool.

---

## Local development

### Backend (Rust)

```bash
# 1. Create your local env files (never committed — gitignored)
cp infra/.env.example infra/.env
# Edit infra/.env — minimum changes for local dev:
#   POSTGRES_PASSWORD=devpassword
#   DATABASE_URL=postgresql://chatapp:devpassword@postgres:5432/chatapp
#   APP_ENV=development        ← skips production safety checks

# Create backend/.env so cargo run picks up the DB URL automatically:
cat > backend/.env << 'EOF'
DATABASE_URL=postgresql://chatapp:devpassword@localhost:5432/chatapp
APP_ENV=development
RUST_LOG=info
SERVER_ADDR=0.0.0.0:8080
EOF

# 2. Start postgres (docker-compose.override.yml publishes port 5432 to localhost automatically)
cd infra && docker compose up -d postgres
# Wait for: "infra-postgres-1  Up (healthy)"

# 3. Start the backend — runs all 18 migrations automatically on first start
cd backend && cargo run

# You should see:
#   INFO database pool established
#   INFO database migrations applied
#   INFO listening addr=0.0.0.0:8080

# Verify:
curl http://localhost:8080/health   # → {"status":"ok"}
```

> **How the port works:** `infra/docker-compose.override.yml` (committed, dev-only) publishes
> postgres port 5432 and backend port 8080 to `127.0.0.1` so `cargo run` can reach them directly.
> In production, omit the override: `docker compose -f docker-compose.yml up -d`.

**Useful backend commands:**

```bash
cd backend

cargo build                          # compile
cargo check                          # fast type-check (no binary)
cargo clippy -- -D warnings          # lint (must be clean before merging)
cargo test                           # run all tests
cargo test auth::challenge::tests    # run a single test module
```

### Flutter client

```bash
cd client

flutter pub get                      # install dependencies
dart run build_runner build \
  --delete-conflicting-outputs       # regenerate drift + riverpod code (run after any model change)

# Point at your local backend (dev default is http://localhost:8080):
flutter run \
  --dart-define=SERVER_URL=http://localhost:8080 \
  --dart-define=WS_URL=ws://localhost:8080/ws

# Run on a specific device:
flutter devices                      # list connected devices
flutter run -d linux                 # Linux desktop
flutter run -d chrome                # Web
```

> **After any change to drift table definitions or Riverpod `@riverpod` annotations**, re-run `build_runner` before running the app — otherwise you will get type errors on generated files.

### Full stack with Docker

```bash
cd infra
cp .env.example .env
# Edit .env — set DOMAIN, POSTGRES_PASSWORD, ALLOWED_ORIGINS, BOOTSTRAP_ADMIN_KEY

docker compose up -d                 # starts postgres + backend + caddy
docker compose logs -f backend       # tail backend logs
docker compose down                  # stop everything
```

The full stack exposes only port 443 (Caddy terminates TLS). For local testing without a real domain, set `DOMAIN=localhost` and accept the self-signed cert.

---

## Running tests

```bash
# Backend unit + integration tests
cd backend && cargo test

# Single test
cd backend && cargo test auth::challenge::tests::test_challenge_verify

# Flutter unit tests
cd client && flutter test

# Single Flutter test file
cd client && flutter test test/crypto/crypto_service_test.dart

# MLS bridge Rust crate (compiled separately)
cd client/rust/mls_bridge && cargo test
```

There are no automated end-to-end tests yet. For manual QA:
1. Run the full Docker stack locally.
2. Run the Flutter app on two devices / simulators pointed at it.
3. Complete the key-signing ceremony flow (QR scan → consensus proposal → approval).
4. Send a group message, verify it arrives encrypted and decrypts correctly on the other device.

---

## Code generation

Two code-generation steps are needed after certain changes:

| What changed | Command |
|--------------|---------|
| Any drift table (`@DataClassName`, columns) | `cd client && dart run build_runner build --delete-conflicting-outputs` |
| Any `@riverpod` annotated provider | Same as above |
| MLS bridge Rust API (`client/rust/mls_bridge/src/lib.rs`) | `cd client && dart run flutter_rust_bridge_codegen generate` *(requires `flutter_rust_bridge_codegen` installed — see `docs/MLS_SETUP.md`)* |

Generated files (`*.g.dart`) are committed to the repo so the app builds without requiring codegen on every checkout.

---

## Project structure

```
cryptochatapp/
├── backend/                    # Rust + Axum server
│   └── src/
│       ├── main.rs             # Tokio entry point, AppState, router
│       ├── auth/               # Ed25519 challenge-response + JWT issuance + session TTL
│       ├── admin/              # Public key allowlist CRUD
│       ├── consensus/          # 2-member proposal + vote system
│       ├── ephemeral/          # Help-request chat state machine (RAISED→ACTIVE→CLOSED)
│       ├── forum/              # Forum post CRUD
│       ├── key_rotation/       # Key rotation + emergency revocation endpoints
│       ├── mls/                # MLS Delivery Service (KeyPackage validation, Commit routing)
│       ├── profiles/           # Public profile directory
│       ├── push/               # Silent push notification sender (APNs + FCM)
│       ├── relay/              # WebSocket handler + ACK + offline queue
│       ├── db/
│       │   └── migrations/     # sqlx migration files (000001 … 000018)
│       └── error.rs            # Unified AppError → HTTP response
│
├── client/                     # Flutter app (iOS/Android/Linux/macOS/Windows/Web)
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/         # AppConfig (serverUrl/wsUrl via --dart-define)
│   │   │   ├── crypto/         # DartCryptographyService, MlsService, MlsGroupService
│   │   │   ├── db/             # drift schema (7 tables) + migrations
│   │   │   ├── network/        # WsClient (auth, queue, reconnect)
│   │   │   ├── push/           # PushService (silent wake-only)
│   │   │   └── utils/          # hex_utils (keyFingerprint, bytesToHex, …)
│   │   └── features/
│   │       ├── auth/           # Onboarding, QR ceremony, auth provider
│   │       ├── chat/           # Chat list + chat screen (drift-backed)
│   │       ├── consensus/      # Proposals screen + propose-member screens
│   │       ├── ephemeral/      # Ephemeral chat screen + provider
│   │       ├── forum/          # Forum board
│   │       ├── presence/       # Online/offline dot + connection banner
│   │       ├── profile/        # Profile view/edit, members directory, key rotation
│   │       └── settings/       # Key rotation + emergency revocation screens
│   └── rust/
│       └── mls_bridge/         # Rust crate — MLS state machine (openmls 0.8.1)
│                               # Compiled via flutter_rust_bridge to native lib
│
├── infra/
│   ├── docker-compose.yml      # postgres + backend + caddy
│   ├── Caddyfile               # TLS 1.3, auto Let's Encrypt, security headers
│   ├── .env.example            # All env vars documented
│   └── postgres/init.sql       # Initial schema seed
│
└── docs/
    ├── DEPLOYMENT.md           # Full server provisioning runbook (Hetzner/Bahnhof)
    ├── KEY_ROTATION.md         # Lost-phone recovery + self-rotation guide
    ├── MLS_SETUP.md            # How to build the MLS native library + run codegen
    └── PUSH_SETUP.md           # Firebase / APNs setup for push notifications
```

---

## Key conventions

> These are non-negotiable for security and correctness.

- **All crypto goes through `core/crypto/`** — never call `openmls`, `cryptography`, or any primitive directly from UI code.
- **Never store plaintext on the server** — `messages.body`, `forum_posts.title`, `profiles.data` are always encrypted blobs. If you find yourself inserting a string the server could read, it is a bug.
- **Never store private keys outside the OS Keychain abstraction** — do not write key material to drift, localStorage, or any file.
- **MLS epoch transitions are atomic** — `process_commit` in `mls_bridge` merges the staged commit in one step. Never apply a partial MLS tree update.
- **Use `compute()` for all crypto ops in Flutter** — `DartCryptographyService` calls are wrapped in `Flutter.compute()` to keep the UI isolate unblocked.
- **No background WebSocket heartbeats on mobile** — use silent push (APNs/FCM) to wake the app instead. Background heartbeats are killed by iOS/Android power management.
- **Tests assert behaviour, not ciphertext** — "Alice can decrypt what Bob sent" is a valid test. "The encrypted blob equals `0xABCD…`" is not — nonces are random.
- **`FALLBACK(mls-not-ready)`** comments mark places where the app falls back to ECIES because the MLS native library has not been built yet. These are not permanent — remove them after running `flutter_rust_bridge_codegen generate` and completing group setup.

---

## Deployment

See **`docs/DEPLOYMENT.md`** for the full runbook. Quick version:

```bash
# On a fresh Debian/Ubuntu server (use apt — not snap)
apt install -y docker.io docker-compose-v2 git ufw

git clone <repo> /opt/cryptochatapp
cd /opt/cryptochatapp/infra
cp .env.example .env
# Edit .env: DOMAIN, POSTGRES_PASSWORD, ALLOWED_ORIGINS, BOOTSTRAP_ADMIN_KEY

ufw allow 80/tcp && ufw allow 443/tcp && ufw enable
docker compose up -d
```

**First deployment checklist:**
1. DNS `A` record pointing to your server IP.
2. Caddy obtains a Let's Encrypt certificate automatically on first request.
3. `GET https://your-domain/health` returns `{"status":"ok"}`.
4. Generate your Ed25519 keypair in the app, note the public key hex.
5. Set `BOOTSTRAP_ADMIN_KEY=<your_hex>` in `.env`, restart backend.
6. Gather all members physically. Each generates a keypair. Admin scans each QR code → submits a `POST /consensus/propose` (ADD). One other member approves each proposal.
7. Once all members are in the allowlist, clear `BOOTSTRAP_ADMIN_KEY` from `.env` and restart.

---

## Contributing

1. **Fork** the repo and create a branch: `git checkout -b feat/my-feature`.
2. Follow the [key conventions](#key-conventions) above.
3. Run lints before pushing:
   ```bash
   cd backend && cargo clippy -- -D warnings
   cd client && flutter analyze
   ```
4. Run tests: `cargo test` and `flutter test`.
5. Re-run `build_runner` if you changed any drift table or Riverpod provider.
6. Open a PR. The CI workflow (`.github/workflows/ci.yml`) runs `cargo test` + `flutter test` on every PR.

**Good first contributions:**
- Add unit tests for `chat_provider.dart` (coverage is thin — see Round 4 QA feedback in `FEEDBACK.md`)
- Write integration tests for the consensus proposal flow
- Build and test the MLS native library on your platform (see `docs/MLS_SETUP.md`) and report any issues

---

## Docs index

| File | Contents |
|------|----------|
| `docs/DEPLOYMENT.md` | Full server provisioning runbook, env vars, backup, data retention |
| `docs/KEY_ROTATION.md` | Lost-phone recovery (Scenario A: self-rotation; Scenario B: emergency revocation) |
| `docs/MLS_SETUP.md` | Building the `mls_bridge` native library + flutter_rust_bridge codegen steps |
| `docs/PUSH_SETUP.md` | Firebase project + APNs key setup for silent push |
| `TECH_STACK.md` | Tech stack decision record with rationale |
| `FEEDBACK.md` | 4 rounds of 7-persona expert feedback (security, UX, architecture, QA, perf) |
