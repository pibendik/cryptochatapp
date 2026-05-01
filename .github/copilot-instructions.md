# Copilot Instructions

## Project Overview

**cryptochatapp** is a privacy-first, end-to-end encrypted group chat application for small, high-trust communities (~20 users per group). It combines permanent group chats, one-on-one encrypted DMs, an ephemeral ad-hoc "I need help" chat feature, and a forum board — all with a dumb-pipe server that routes ciphertext only and never reads content. Trust is bootstrapped at a physical key-signing ceremony; there are no passwords. The app targets Linux, macOS, Windows, Android, iOS, and the browser from a shared codebase.

## Tech Stack

| Layer | Choice |
|-------|--------|
| **Backend** | Rust + Axum + Tokio |
| **Transport** | WebSockets over TLS 1.3 (Caddy) |
| **E2E Group Crypto** | MLS RFC 9420 via `openmls` crate |
| **E2E 1:1 Crypto** | Double Ratchet + X3DH via `libsodium` (`sodiumoxide`) |
| **Authentication** | Ed25519 challenge-response; short-lived JWTs (4 h); no passwords |
| **Server Database** | PostgreSQL (ciphertext blobs only) |
| **Client Database** | SQLCipher (AES-256 encrypted SQLite, all platforms) |
| **Key Storage** | OS Keychain / Secure Enclave (platform-native; never synced to server) |
| **Frontend** | Flutter (iOS / Android / Linux / macOS / Windows / Web — single codebase) |
| **Infrastructure** | Single VPS (Hetzner DE or Bahnhof/Mullvad SE), Docker Compose, Caddy (auto Let's Encrypt) |

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                   CLIENT (all platforms)             │
│                                                      │
│  Flutter UI  (Material / Cupertino adaptive widgets) │
│          │                                           │
│  crypto/ module  (openmls + sodiumoxide wrappers)    │
│          │                                           │
│  SQLCipher local DB  (decrypted messages + keys)     │
│          │                                           │
│  OS Keychain  (Ed25519 identity keypair — never      │
│               leaves the device)                     │
└──────────────────────┬──────────────────────────────┘
                       │  WebSocket (TLS 1.3)
                       │  sealed ciphertext envelopes
┌──────────────────────▼──────────────────────────────┐
│               SERVER (Rust + Axum)                   │
│                                                      │
│  Auth: Ed25519 challenge-response → short JWT        │
│  Routing: forward encrypted blobs by opaque ID       │
│  Key Package directory: MLS public keys only         │
│  Presence: in-memory only, not persisted             │
│  Offline queue: ciphertext blobs, TTL-bounded        │
│                                                      │
│  PostgreSQL  (ciphertext blobs, MLS Key Packages,    │
│              encrypted profiles, forum post bodies)  │
└─────────────────────────────────────────────────────┘
```

**Data flow (outbound message):**
1. Client encrypts payload with MLS (group) or Double Ratchet (1:1) — plaintext never leaves the device.
2. Encrypted envelope is sent over the authenticated WebSocket.
3. Server validates the JWT, looks up recipient routing ID(s), forwards the ciphertext blob.
4. Server persists the blob in PostgreSQL (cannot decrypt it).
5. Recipient client receives blob, decrypts locally via `crypto/` module, stores in SQLCipher.

**Key-signing ceremony:**
- New user generates an Ed25519 identity keypair on their device.
- At an in-person meeting, every member cross-signs every other member's public key.
- The resulting signed attestation bundle is stored client-side and sent to the server as an opaque blob.
- Admin adds the new member's public Key Package to the server directory; the MLS group admin performs a `Welcome` operation.

### Storage Model (Sealed-Envelope)
**Server stores (PostgreSQL):** public keys, undelivered envelopes (deleted on ACK ~1 min), forum posts (deleted on resolve/30d), auth challenges (5-min TTL).  
**Server NEVER stores:** message history, read receipts, bio/skills, plaintext content.  
**Client stores (drift SQLite):** full message history, contacts, profiles, outbound queue.  
**Design principle:** A compromised server reveals almost nothing — only metadata (who is in which group, message timing, sizes).

## Security Model

- **Primary adversary is a compromised device.** Keys live in the OS Keychain / Secure Enclave only — never in the app's data directory, SQLCipher, or server. Forward secrecy via MLS + Double Ratchet limits the blast radius of a key compromise.
- **Server sees only ciphertext.** It stores encrypted blobs, MLS Key Packages (public keys), and opaque routing IDs. It cannot read messages, profiles, or group composition.
- **No passwords.** Identity IS the Ed25519 keypair. Authentication is challenge-response: server issues a nonce, client signs it, server verifies against the registered public key.
- **Key-signing QR-code ceremony bootstraps trust.** Physical in-person verification is the root of trust — not TOFU, not certificate authorities. New members generate their keypair, display a QR code, and every existing member scans and signs it.
- **No single admin.** Group decisions (member add/remove, key rotation) require 2/3 member consensus. No individual holds unilateral power over the group.
- **MLS (RFC 9420) for groups.** Epoch-based key rotation on every member add/remove ensures removed members cannot decrypt future messages and new members cannot decrypt past epochs (forward secrecy + post-compromise security).
- **Double Ratchet for 1:1 DMs.** X3DH key agreement followed by per-message ratcheting gives per-message forward secrecy.
- **No server-side key material ever.** Private keys are stored in the platform's Secure Enclave / OS Keychain and never transmitted.
- **Ephemeral chats are truly ephemeral.** Server purges blobs on session close; clients delete local session on receiving the `DELETE` event. "Ephemeral" means server-side deletion; screenshot prevention is out of scope and explicitly disclosed to users.

## Key Conventions

> These conventions are non-negotiable for correctness and security. Add to this list as the project grows.

- **All crypto operations go through `crypto/`** — never call `openmls`, `sodiumoxide`, or any crypto primitive directly from UI or server routing code. The `crypto/` module is the single crypto abstraction layer.
- **Never store plaintext in the server database.** `messages.body`, `profiles.data`, `forum_posts.body` are always encrypted blobs. If you find yourself inserting a string the server could read, it's a bug.
- **Never store private keys outside the OS Keychain abstraction.** Do not write key material to SQLCipher, localStorage, or any file — use the platform keychain via the unified `keychain/` module.
- **MLS epoch transitions are atomic.** A Commit message and its associated Update/Remove must be applied together or not at all. Never apply a partial MLS tree update.
- **Presence is coarse-grained on mobile.** Do not add background WebSocket heartbeats on iOS/Android — they will be killed by Doze/background restrictions. Use APNs/FCM push wakeup instead.
- **Forum and chat are separate data models.** `forum_posts` uses vector-clock ordering; `messages` uses per-conversation sequence numbers. Do not conflate them.
- **All state machine transitions for ephemeral chats are idempotent.** The server must handle duplicate `CLOSE` or `DELETE` events without corrupting state.
- **Tests assert properties, not ciphertext values.** "Alice can decrypt what Bob sent to her" is a valid test. "The encrypted blob equals `0xABCD...`" is not — nonces are random.

## Deployment

**Target:** Hetzner CX21 (Germany) or Bahnhof (Sweden) — see `docs/DEPLOYMENT.md` for full runbook.

**Quick start:**
```bash
# On the server (apt only — no snap)
apt install -y docker.io docker-compose-v2 git ufw
git clone <repo> /opt/cryptochatapp
cd /opt/cryptochatapp/infra && cp .env.example .env
# Edit .env: set DOMAIN, POSTGRES_PASSWORD, ALLOWED_ORIGINS
docker compose up -d
```

## Build, Test & Lint

```bash
# Backend (Rust)
cd backend && cargo build
cd backend && cargo test
cd backend && cargo clippy -- -D warnings
cd backend && cargo run  # dev server

# Single test
cd backend && cargo test auth::challenge::tests::test_challenge_verify

# Frontend (Flutter)
cd client && flutter pub get
cd client && flutter run
cd client && flutter test
cd client && flutter test test/crypto/crypto_service_test.dart  # single test

# Docker dev stack
cd infra && docker compose up -d
cd infra && docker compose logs -f backend
```

## Project Structure

```
cryptochatapp/
├── backend/                    # Rust + Axum server
│   ├── src/
│   │   ├── main.rs             # Tokio runtime entry point
│   │   ├── ws/                 # WebSocket handlers (connect, relay, presence)
│   │   ├── auth/               # Ed25519 challenge-response + JWT issuance
│   │   ├── routes/             # HTTP REST routes (key packages, profile, forum)
│   │   ├── db/                 # PostgreSQL models and migrations (sqlx)
│   │   └── crypto/             # openmls + sodiumoxide wrappers
│   ├── Cargo.toml
│   └── config.dev.toml
│
├── client/                     # Flutter frontend (all platforms)
│   ├── lib/
│   │   ├── screens/            # Navigation screens (Chat, Forum, Profile, etc.)
│   │   ├── widgets/            # Reusable adaptive widgets
│   │   ├── crypto/             # Dart crypto bindings (FFI → Rust or dart:ffi)
│   │   ├── keychain/           # Platform keychain abstraction (iOS/Android/desktop/web)
│   │   ├── db/                 # SQLCipher schema + migrations + query helpers
│   │   ├── ws/                 # WebSocket client (reconnect, message queue, gap detection)
│   │   └── state/              # App state (Riverpod / Bloc)
│   ├── test/                   # Flutter unit and widget tests
│   └── pubspec.yaml
│
├── shared/                     # Shared types and constants
│   └── src/lib.rs              # Rust serde types (also used by backend)
│
├── infra/
│   ├── docker-compose.yml      # Production stack (postgres + backend + caddy)
│   ├── Caddyfile               # TLS 1.3, reverse proxy, security headers
│   ├── .env.example            # Environment variable template
│   ├── backend/
│   │   └── Dockerfile          # Multi-stage Rust build (musl static binary)
│   └── postgres/
│       └── init.sql            # Initial schema (all payload columns = ciphertext)
│
├── docs/
│   ├── threat-model.md         # Written before Phase 1 — gates design decisions
│   ├── ephemeral-state-machine.md  # Formal state diagram for help-request flow
│   └── key-ceremony.md         # Admin runbook for signing party
│
├── .gitignore
├── FEEDBACK.md                 # Expert persona feedback (design input)
├── TECH_STACK.md               # Tech stack decision record
└── .github/
    ├── copilot-instructions.md  # This file
    └── workflows/
        ├── ci.yml               # cargo test + flutter test on every PR
        └── compat.yml           # Cross-platform encrypt/decrypt matrix
```
