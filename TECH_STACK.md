# Tech Stack Decision: Secure Group Chat Application

> **Context:** Small trusted groups (~20 users), physically-verified key exchange, ephemeral chats, E2E encryption mandatory, cross-platform, not VC-scale — a secure community tool.

---

## 1. Transport / Real-time Layer

### Options considered

| Option | Pro | Con |
|--------|-----|-----|
| Raw WebSockets | Simple, universal | No built-in federation, no E2E at protocol level |
| Matrix (Synapse) | Federation, Megolm E2E, open standard | Heavy Rust/Python infra, complex ops, overkill for closed group |
| XMPP + OMEMO | Mature, federated | Fragmented clients, poor mobile UX, dated feel |
| Signal Protocol stack | Best-in-class E2E | Server component is opaque; self-hosting is complex |
| WebRTC | Good for P2P media | Needs signalling server anyway; not designed for persistent chat |
| **Custom WebSocket + MLS** | Full control, lean server | We own the implementation burden |

### Decision: **WebSockets over TLS, application-level MLS encryption**

The server is a "dumb relay" — it routes sealed envelopes, stores only ciphertext. WebSockets give us real-time push without complexity. Because the group is closed and self-hosted, federation is unnecessary overhead.

---

## 2. End-to-End Encryption

### Options considered

| Option | Pro | Con |
|--------|-----|-----|
| Signal Protocol (Double Ratchet + X3DH) | Forward secrecy per-message, battle-tested | Designed for 1:1; group uses Sender Keys (less PFS) |
| OpenPGP | Web-of-trust fits key-signing-party model | No forward secrecy; key management UX is terrible |
| Matrix Megolm | Good for groups | Tied to Matrix stack |
| **MLS (RFC 9420)** | Designed for secure group messaging, forward secrecy, post-compromise security, IETF standard | Newer, fewer production libs (but growing fast) |

### Decision: **MLS (RFC 9420) via OpenMLS (Rust crate) for group chats + Signal Protocol Double Ratchet (libsodium) for 1:1 DMs**

- MLS is purpose-built for our exact use-case: small, membership-managed groups. It provides forward secrecy and post-compromise security better than Sender Keys.
- The key-signing-party maps cleanly onto MLS's "credential" model — each member's identity key is signed by every other member's key at the in-person event.
- 1:1 DMs use Double Ratchet (X3DH key agreement + ratcheting) via [libsodium](https://libsodium.gitbook.io) bindings, giving per-message forward secrecy.
- All crypto runs **client-side only**. Server sees only: encrypted blobs, MLS Welcome/Commit messages, and metadata it strictly needs (recipient IDs, timestamps).

---

## 3. Frontend

### Options considered

| Option | Pro | Con |
|--------|-----|-----|
| React Native + React Native Web | One codebase for iOS/Android/browser | Native desktop still needs Electron wrapper; JS crypto can be tricky |
| **Flutter** | True native cross-platform incl. desktop and web; single Dart codebase | Dart crypto ecosystem less mature than Rust; larger binary |
| Tauri + React/Svelte | Lightweight native desktop + browser via web tech; Rust core | Mobile story (Tauri Mobile) is still maturing |
| React Native + Expo + Tauri (desktop) | Proven mobile+web; Tauri for desktop avoids Electron bloat | Two build targets to maintain |

### Decision: **Flutter** (single codebase for iOS / Android / Linux / macOS / Windows / Web)

- Flutter gives us a single Dart codebase that compiles to native code on all six platforms — no separate desktop build target needed.
- The `flutter_secure_storage` plugin wraps the platform keychain on every target (iOS Keychain, Android Keystore, Linux secret-service, macOS Keychain, Windows DPAPI), keeping key storage consistent.
- The `cryptography` / `cryptography_flutter` packages provide all required primitives (Ed25519, X25519, ChaCha20-Poly1305, HKDF) and can delegate to hardware AES on Android/iOS.
- UI framework: **Flutter Material 3** with platform-adaptive widgets — no separate component library required.
- The `mobile_scanner` plugin handles QR scanning on mobile; `qr_flutter` renders QR codes on all platforms.

---

## 4. Backend

### Options considered

| Option | Pro | Con |
|--------|-----|-----|
| Node.js (Fastify) | Fast to write, same language as frontend | Single-threaded; crypto-heavy work needs worker threads |
| Python (FastAPI) | Easy, quick | GIL, slower, not ideal for concurrent WebSocket fans |
| Go | Excellent concurrency, simple deployment | Separate language from Rust crypto; FFI overhead |
| **Rust (Axum)** | Shares OpenMLS crate directly, memory-safe, fast, single binary deploy | Steeper learning curve, longer compile times |

### Decision: **Rust + Axum**

- The backend is intentionally thin (a relay + key directory), but correctness under concurrency matters.
- Axum's `tokio` async runtime handles thousands of WebSocket connections on modest hardware.
- We share `openmls` and `libsodium` (via `sodiumoxide` / `libsodium-sys`) directly — no FFI boundary, no version drift.
- A single statically-linked binary simplifies deployment.
- Key operations: route encrypted messages, serve the MLS Key Package directory, store/serve group state (as ciphertext), manage presence.

---

## 5. Database

### What lives server-side

The server is intentionally storage-minimal. It holds:
- Encrypted message history (blobs — server cannot read content)
- MLS Key Packages (public keys only)
- MLS group state (encrypted Welcome/Commit messages)
- User presence state (in-memory, not persisted)
- Forum posts (encrypted body, plaintext title optional — see below)
- User profile metadata (name, skills — encrypted at rest)

### What lives client-side only

- Private keys (NEVER leaves the device)
- Decrypted message history
- Contact trust records (which keys were verified at the signing party)

### Decision: **PostgreSQL (server) + SQLite via SQLCipher (client)**

- **PostgreSQL**: Reliable, battle-tested, good JSONB for flexible encrypted blobs. No need for CockroachDB (not distributed). Runs in Docker alongside the backend.
- **SQLCipher** (encrypted SQLite): Client-side local database, AES-256 encrypted with the user's device passphrase. Stores decrypted messages and key material locally. Works on all platforms.

---

## 6. Key Storage

### Decision: **OS Keychain for long-term identity key + passphrase-derived encryption for local SQLCipher DB**

- **Identity keypair** (Ed25519 signing key + X25519 for DH): stored in the platform's secure enclave/keychain:
  - macOS/iOS: Keychain Services / Secure Enclave
  - Android: Android Keystore
  - Linux/Windows: `secret-service` (GNOME Keyring / KWallet) / DPAPI via `flutter_secure_storage`
  - Browser: OPFS (Origin Private File System) + WebCrypto, passphrase-protected
- **Key signing party records**: a local JSON file, signed by the user's own key, listing all verified peer keys with signatures. This is the web-of-trust anchor.
- **Hardware security keys (YubiKey)**: supported as an optional second-factor for desktop/Linux via FIDO2/WebAuthn, but not required — the primary auth is the keypair itself.
- **No server-side key material ever.** The server stores only public Key Packages for MLS.

---

## 7. Infrastructure

### Decision: **Self-hosted on a single VPS (Hetzner/Vultr), Docker Compose, no Kubernetes**

- The user base is ~20 people. Kubernetes is massive overkill and increases the attack surface.
- A single Hetzner CX21 (2 vCPU, 4 GB RAM) comfortably handles 20 concurrent WebSocket connections.
- **Docker Compose** with: `backend` (Rust/Axum), `postgres`, `caddy` (TLS termination + HTTP/2).
- Caddy handles automatic Let's Encrypt TLS. All traffic is TLS 1.3 only.
- Backups: `pg_dump` encrypted with the admin's GPG key, stored off-site (e.g., Backblaze B2 with SSE).
- The server is hardened (UFW, fail2ban, SSH key-only, no root login). Ideally hosted in a privacy-friendly jurisdiction.

---

## 8. Authentication

### Options considered

| Option | Pro | Con |
|--------|-----|-----|
| Username + password | Familiar | Passwords are the weakest link; server sees credentials |
| WebAuthn / FIDO2 | Phishing-resistant, hardware key support | Requires server-side challenge; adds complexity |
| **Key-only (challenge-response)** | Zero knowledge to server; identity IS the keypair | Key loss = account loss (but: key rotation + group re-add solves this) |
| Passphrase-protected keypair | Simple, no server secret | Passphrase brute-forceable if keypair leaked |

### Decision: **Cryptographic challenge-response — no passwords**

- Client signs a server-issued nonce with their Ed25519 identity key. Server verifies against the registered public key.
- No password ever exists. The server never learns the private key.
- Initial registration: an existing group member (admin) adds the new user's public key to the server's key directory after the in-person signing party. No self-registration.
- **Account recovery**: if a key is lost, the group admin holds a revocation certificate (generated at onboarding). A new keypair is generated; the admin adds it; peers re-verify in person or via authenticated channel.
- Sessions: short-lived JWTs (4 hour expiry) signed by the server after successful challenge-response, scoped to a device. Stored in memory only (never localStorage on web).

---

## Final Stack Summary

| Dimension | Choice | Rationale |
|-----------|--------|-----------|
| **Transport** | WebSockets over TLS 1.3 | Simple relay; dumb server model |
| **E2E Encryption (group)** | MLS RFC 9420 via OpenMLS | Purpose-built for groups; forward secrecy; PCS |
| **E2E Encryption (1:1)** | Double Ratchet + X3DH (libsodium) | Per-message forward secrecy for DMs |
| **Key ceremony** | Ed25519 identity keys, web-of-trust at signing party | Maps to physical trust model |
| **Frontend** | Flutter | Single-codebase: iOS / Android / Linux / macOS / Windows / Web |
| **UI Components** | Flutter Material 3 | Built-in, platform-adaptive |
| **Backend** | Rust + Axum + Tokio | Type-safe, async, shares crypto crates |
| **Server DB** | PostgreSQL | Reliable; stores only ciphertext |
| **Client DB** | SQLCipher (encrypted SQLite) | Encrypted local storage, all platforms |
| **Key storage** | OS Keychain / Secure Enclave (platform-native) | Never leaves device |
| **Authentication** | Ed25519 challenge-response; no passwords | Zero server-side secret knowledge |
| **Infrastructure** | Single VPS + Docker Compose + Caddy | Right-sized; minimal attack surface |
| **TLS** | TLS 1.3 only via Caddy (auto Let's Encrypt) | Modern, forward-secret transport |
| **Backup** | `pg_dump` + GPG-encrypted off-site | Admin-controlled recovery |

---

## Key Architectural Principle

> **The server is a sealed-envelope postal service.** It routes, timestamps, and stores ciphertext. It cannot read messages, cannot impersonate users, and cannot forge group membership. All trust is anchored in physical key exchange, not in the server's honesty.

This "server-agnostic trust" model means that even a fully-compromised server leaks only metadata (who talked to whom, when) — not content, not identities, not keys.

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| OpenMLS library maturity | Pin to audited release; review changelogs carefully; fallback to Sender Keys if needed |
| Flutter Web crypto performance | Use `cryptography_flutter` on mobile for hardware AES; benchmark on target platforms |
| Key loss = account loss | Revocation certificate held by admin; document recovery process clearly |
| Metadata leakage (traffic analysis) | Encourage VPN/Tor use; consider padding messages to fixed sizes |
| Single VPS is a SPOF | Acceptable for this scale; document manual restore procedure |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2024-01-01 | Switched from React Native + Tauri to Flutter | Flutter provides a single-codebase cross-platform solution covering mobile, desktop, and web without the two-build-target overhead of React Native (Expo) + Tauri. The `flutter_secure_storage` plugin gives uniform keychain access across all platforms; the `cryptography` package covers all required primitives in pure Dart with hardware acceleration where available. |
