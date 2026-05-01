# Expert Feedback: Proposed Secure Group Chat Application

> In-depth, opinionated feedback from seven expert personas on the proposed secure, ephemeral group chat application for small trusted communities.

---

## 1. UX Designer

The concept has genuine merit — small, trusted communities are an underserved design space, and you've avoided the trap of trying to build for everyone. But let me be direct: the friction budget here is enormous, and I'm worried the team hasn't fully reckoned with it.

**The key signing party is a UX cliff.** Requiring a physical meeting before _any_ value is delivered means new users experience zero utility until they've jumped through a logistical hoop that might take weeks to organise. This is fine — even appropriate — if your target users are, say, a neighbourhood mutual aid group or a journalist collective. It is catastrophic if you ever try to grow or if a member moves cities. You need to design the onboarding state carefully: what does the app look like before a user has been signed in? Can they browse profiles, read the forum, see who's in the group? Or is it a blank wall? I'd strongly recommend a "pending" state with read-only access so new users don't churn while waiting for the signing party.

**The "I need help" ad-hoc chat is the core innovation and it needs far more design thought than the brief implies.** Who sees the notification? Everyone in the group? Only online members? What if someone raises a flag at 2am? Is there a history of past ad-hoc sessions (even if the chat itself is deleted) so users can see "Alice needed help 3 times last month"? The ephemerality is a security feature, but users will instinctively want receipts and history. You'll spend a lot of UX energy managing that tension.

**Presence indicators are a psychological minefield.** Showing who is online in a small, tight-knit community creates social pressure. Someone who is online but hasn't responded to a help request will feel judged. Look at how Signal handles this (they removed last-seen by default), or how Slack's "do not disturb" became essential. Build status granularity in from day one: Online, Busy, Invisible. Don't make it binary.

**Profiles listing skills** are delightful and genuinely useful — this is the feature that distinguishes this from generic chat. But discoverability matters: can I search/filter by skill? Can I see "who in this group knows about housing law"? If not, the profiles become digital business cards that nobody reads.

**Accessibility is not mentioned once in the brief, which is a red flag.** Cross-platform means nothing if it's not accessible. Screen reader support for real-time chat is notoriously hard — VoiceOver/TalkBack handle live regions inconsistently. Commit to WCAG 2.1 AA from the start, not as a retrofit. Also: end-to-end encrypted chat with no message history creates genuine problems for users with memory or cognitive disabilities who rely on being able to re-read past conversations.

**Concrete recommendations:**
- Design the onboarding "pending" state as a first-class UX state, not an afterthought.
- Run usability testing specifically on the "raise a flag → join chat → chat ends" flow with non-technical users.
- Add a "skills directory" view with filtering, separate from individual profiles.
- Establish a clear status model (at minimum: online, busy, offline) before writing a line of presence code.
- Commit to an accessibility audit budget before launch.

---

## 2. Security Expert

This proposal gets several things right that most chat apps get catastrophically wrong: the web-of-trust key signing model, the small-group assumption, and the explicit acknowledgement that security is paramount. Let me now tell you everything that still worries me.

**The threat model is absent, and that's the most important document you haven't written yet.** Who is the adversary? A nosy ISP? A nation-state? An abusive ex-partner who gains access to a group member's device? A malicious group member? The answer changes almost every design decision. "Security is paramount" is not a threat model. Write one before you design anything else.

**Key signing parties establish identity, but not ongoing trust.** PGP's web-of-trust model has decades of real-world evidence showing that most people don't revoke keys when they should. What happens when a member leaves the group — voluntarily or otherwise? You need a **key rotation and member removal protocol** that is cryptographically enforced, not just policy-enforced. When Alice leaves, every key used for group communications must be rotated so Alice can no longer decrypt future messages. This is the group membership change problem, and it's genuinely hard. Look at the MLS (Messaging Layer Security, RFC 9420) protocol — it was designed specifically for this.

**Forward secrecy in group chat is not the same as in 1:1 chat.** Signal's Double Ratchet gives you per-message forward secrecy in 1:1 chats. Group chat with 20 members is far harder. If you roll your own group key scheme, you will almost certainly get it wrong. Use MLS or, at a minimum, a sender keys scheme (as Signal uses for groups) and understand its security properties and limitations before deploying.

**Metadata is your biggest leakage surface and the brief doesn't address it at all.** Even with perfect end-to-end encryption, a server-side attacker learns: who is online when, who sends messages to whom, message sizes, and timing patterns. For a sensitive community, this metadata can be as damaging as content. Consider: does the server need to know which group a user belongs to? Does it need to know who sent a message within a group? Look at how Signal's sealed sender works, and consider whether a similar approach is feasible here.

**The "ephemeral chat" feature has a subtle security property that needs explicit design.** When you say the chat is "deleted when no longer needed," deleted where? On the server? On all clients? What if a client is offline when deletion happens? What if someone screenshots it? You can make deletion easy and automatic server-side. You cannot prevent client-side retention. Be explicit with users about what "ephemeral" actually means and doesn't mean — false security promises are worse than no security promises.

**The in-browser target is a significant attack surface expansion.** Browser-based crypto has improved enormously with the Web Crypto API, but the browser is still a hostile environment compared to a native app. Key storage in browsers (IndexedDB, localStorage) is accessible to any JavaScript on the page, and XSS becomes a catastrophic vulnerability. If you must support browsers, consider a Progressive Web App approach with strict Content Security Policy, and be explicit in your threat model that the browser client has a weaker security posture.

**One-on-one encrypted chats should use the Double Ratchet or a well-audited equivalent.** Do not invent your own ratchet. Use libsodium or the Signal Protocol library. The one thing I will praise unreservedly is the decision to have a physical trust anchor — in a world of TOFU (trust on first use) key exchange, that is a genuinely strong foundation.

**Concrete recommendations:**
- Write a threat model document before any design decisions are finalised.
- Adopt MLS (RFC 9420) for group key management — it solves member addition/removal correctly.
- Use the Double Ratchet (via libsignal or equivalent) for 1:1 chats.
- Design a metadata-minimising server architecture — the server should learn as little as possible.
- Be precise and honest in user-facing language about what "ephemeral" and "encrypted" actually guarantee.

---

## 3. Bored Senior Developer

Oh good, another secure chat app. I've reviewed four of these in the past two years. Here's how they all ended: half-finished, the crypto was subtly broken, the person who understood the key management left, and the remaining team quietly switched to a Signal group. I hope this one is different. Let me tell you why it probably won't be.

**You are proposing to solve several genuinely hard distributed systems problems simultaneously.** Real-time presence, group key management, ephemeral message lifecycle, cross-platform delivery, and a forum-style board. Each of these is a project. Together they are a platform. Platforms take years and teams. If this is a side project or an MVP by a small team, you need to ruthlessly cut scope or you will ship nothing.

**The cross-platform requirement is where projects go to die.** "Linux, macOS, Windows, Android, iOS, and in-browser" means you're either writing everything six times, or you're betting on a cross-platform framework. Flutter, React Native, Electron — they all work until they don't, and then you spend three weeks debugging a WebSocket reconnect bug that only happens on iOS 17.2 in background mode. I've seen projects spend 40% of their engineering time on platform-specific edge cases. Budget for it honestly or drop platforms.

**NIH syndrome is a clear and present danger.** The brief mentions "PGP-style web of trust." PGP has been around since 1991. It works. GnuPG exists. OpenPGP libraries exist for every platform. Why are you designing your own trust model? Similarly, for real-time messaging: XMPP with OMEMO encryption has solved most of this. Matrix/Element exists. Briar exists specifically for high-trust small groups with offline-first mesh networking. The question "why not use an existing solution" needs to be answered explicitly and convincingly, or you're building resume-driven development at the expense of your users.

**The "ephemeral chat is deleted when no longer needed" requirement will generate an infinite stream of edge cases.** Who decides when it's no longer needed? What's the timeout? What if the last person forgets to close it? What if the server crashes mid-session? What if a user's client is offline and they miss the deletion event? I guarantee this feature will account for 30% of your bug reports.

**Maintenance burden is invisible at design time.** Key signing parties require someone to coordinate them. New member? Party. Old member's key expires? Party. This is operational overhead that will fall on whoever runs the community. Document the admin burden explicitly. Build admin tooling as a first-class concern, not as "we'll add that later." (You won't add it later.)

**What I do like:** The constraint of ≤20 users per group is genuinely smart engineering. It means you can make assumptions — fan-out to 20 WebSocket connections is trivial, group key distribution to 20 members is manageable, and you're not designing for scale you'll never need. Hold that constraint firmly against the inevitable pressure to "make it work for bigger groups too."

**Concrete recommendations:**
- Write a "Why not Matrix/Element/Briar?" document and share it with the team. If you can't write it convincingly, consider using one of those instead.
- Cut the forum board from the MVP. It's a separate product.
- Hire or designate a dedicated platform engineer for mobile/desktop builds, or drop mobile from v1.
- Define "ephemeral" with a concrete state machine before writing a line of code.

---

## 4. Senior Architect

This is an interesting design challenge precisely because the constraints are tight in useful ways: small groups, high-trust membership, and sensitive data. Let me work through the architectural decisions that will define whether this succeeds or becomes a maintenance nightmare.

**The data model for group membership changes is the hardest problem in this system.** Groups are bounded at 20 members, but membership changes — someone joins, someone leaves, someone's device is compromised. Your data model needs to version group membership, not just record current state. Every encrypted message should be associated with a specific membership epoch, so that if you ever need to audit or reason about what a given message recipient set was, you can. This sounds like over-engineering; it is not. It is the foundation of correct key rotation.

**The server architecture has a fundamental tension: how much should the server know?** There are two broad approaches. First, a "dumb pipe" server that stores and forwards encrypted blobs and knows nothing about content or group membership beyond routing identifiers. This maximises privacy but makes features like presence, forum indexing, and message ordering harder to implement correctly. Second, a "smart server" that manages group state, presence, and message ordering, but has access to metadata. Given the sensitivity requirements, I'd recommend a hybrid: the server manages routing and ordering using opaque identifiers, but never has access to plaintext content or, ideally, the social graph (who is in which group).

**Presence is architecturally at odds with privacy.** To show presence, you need a server that knows who is connected. That server therefore has a real-time record of when each user is online. Consider whether presence should be server-brokered (efficient but leaks timing data) or peer-brokered (complex but more private). For a small group, you could gossip presence information peer-to-peer through the encrypted channel, avoiding server-side visibility entirely — at the cost of latency and complexity.

**The forum board and the real-time chat are two different consistency models.** Forum posts are eventually consistent append-only data; chat messages need ordering guarantees and delivery receipts. Running both through the same infrastructure is tempting but will create subtle bugs. I'd model them as separate concerns at the data layer, even if they share transport. Forum posts should have vector clocks or logical timestamps for ordering; chat messages need sequence numbers per conversation.

**Protocol choice will define your cross-platform life for years.** I'd strongly recommend building on top of an existing, audited messaging protocol rather than designing your own. **MLS (RFC 9420)** is the current state of the art for group messaging and has implementations in Rust, TypeScript, and Swift. It handles member add/remove with forward secrecy correctly. Pair this with a transport layer using WebSockets for real-time delivery, with a message store for offline delivery. Avoid reinventing the transport protocol.

**The key signing party creates an interesting bootstrapping architecture.** I'd model this as a ceremony that produces a signed attestation graph (a set of GPG-style signatures or MLS credential bundles), stored client-side and potentially backed up by the server as opaque blobs. The server should be able to verify that a user has been vouched for without learning the social graph structure of the vouching.

**Concrete recommendations:**
- Model group membership as an epoch-versioned log, not just a current-state table.
- Adopt MLS RFC 9420 as the group key management protocol.
- Design the server as a metadata-minimising routing layer from day one — retrofitting this is extremely painful.
- Separate forum and chat at the data model layer.
- Define a clear "offline member" story: what happens to messages, presence, and ephemeral chats when a member's device is unreachable?

---

## 5. Normal Programmer

I want to be honest: this is a lot. Not impossible, but a lot. Let me walk through what the actual day-to-day implementation experience will look like, because I think the brief undersells the complexity.

**Let's start with good news: the library ecosystem for this is better than it's ever been.** For cryptography, `libsodium` has excellent bindings for Python, JavaScript, Rust, and most mobile platforms. For the Double Ratchet (1:1 chats), `libsignal-client` is open source and has bindings for Java/Kotlin, Swift, and Node. For MLS group key management, there are implementations like `openmls` in Rust with WASM compilation support. You don't have to write crypto from scratch, and you absolutely should not.

**The cross-platform story is genuinely hard, though.** My honest recommendation: pick **Flutter** for the mobile/desktop clients. It gives you one Dart codebase for Android, iOS, macOS, Windows, and Linux, with a web build that's passable. The main pain point is that `libsignal` and crypto libraries need FFI bindings, which in Flutter means writing platform channels for each platform. That's not insurmountable, but it's weeks of work per library. Alternatively, a React Native app with a shared crypto layer in Rust via `wasm-pack`/`napi-rs` is viable but has its own integration pain.

**The backend is more tractable.** A Go or Rust service with WebSocket connections for real-time delivery, a PostgreSQL database for persistent storage (forum posts, user profiles, message envelopes — all encrypted), and Redis for presence state is a well-understood stack. You're not inventing anything novel at the backend layer; you're connecting known components. The interesting engineering is the key management and the message protocol, not the infrastructure.

**The ephemeral chat feature specifically worries me as an implementer.** You need: a mechanism to create a chat room, notify online members, accept joins, relay encrypted messages, detect when "done," notify all participants, and delete server-side state. Each of those is a state machine transition. State machines are fine — but you need to draw this one out explicitly, including every failure mode (member goes offline, server restarts, notification delivery fails) before writing code. I've seen "simple" ephemeral features turn into 2,000-line state machine handlers.

**Testing the crypto integration will be painful.** Deterministic crypto (fixed nonces for testing) is a security anti-pattern, so your test suite can't easily assert on ciphertext. You'll be testing properties ("can Bob decrypt what Alice encrypted") not values. This is fine but requires deliberate test design from the start.

**Things I'd use specifically:**
- `libsodium` (via `sodiumoxide` in Rust or `libsodium-wrappers` in JS) for symmetric/asymmetric primitives
- `openmls` for MLS group key management
- `sqlcipher` for encrypted local storage on mobile/desktop
- `tokio` + `axum` or `actix-web` in Rust for the backend, or `Go` with `gorilla/websocket`
- `PostgreSQL` with row-level encryption for server-side storage

**The single thing I'd caution most strongly:** don't write your own WebSocket reconnection and message ordering logic from scratch. Use an existing library that handles sequence numbers, acknowledgements, and reconnect backoff. Reinventing this is where the subtle bugs that corrupt message ordering live.

---

## 6. QA Champion

I love this project from a testing perspective — and I mean that with the same energy as "this will be fascinating to test" rather than "this will be easy to test." Let me be specific about what will break.

**End-to-end testing cryptographic applications is fundamentally different from testing normal apps.** You cannot assert on ciphertext values. You cannot easily create "known good" encrypted state for test fixtures because keys change. Your test strategy needs to be property-based: "Alice can always decrypt a message she is the recipient of," "Bob cannot decrypt a message intended only for Alice," "after Carol leaves the group, she cannot decrypt new group messages." Write these as your acceptance criteria, not as assertions on specific byte values.

**The ephemeral chat lifecycle is a QA nightmare waiting to happen.** Edge cases I would immediately put into the test plan:
- User A raises a flag, User B joins, User A closes the chat before User B has read all messages
- User A raises a flag, no one joins, the flag expires (what's the timeout? is it configurable?)
- User A raises a flag, User B joins, the server restarts mid-session
- User A raises a flag while offline (queued notification? silent drop?)
- Two users simultaneously raise flags — do they merge into one chat or create two?
- A user raises a flag, the chat is auto-deleted, then that user immediately raises another flag

None of these are exotic. All of them will happen in production on day one.

**Key management edge cases are where security regressions live.** You need a dedicated suite of key lifecycle tests:
- Device key rotation (user gets a new phone)
- Member removal key rotation (does Carol's old key work after she's removed? it must not)
- Key signing party bootstrapping (can a new member join before attending a signing party? what exactly happens if they try?)
- Key expiry (if PGP-style keys have expiry dates, what happens when one expires mid-conversation?)

**Cross-platform compatibility testing is where you'll spend the most calendar time.** A message composed on iOS must be correctly decrypted on Android, Windows, Linux, macOS, and the web client. That's 15 combinations for every message format version. You need a compatibility test matrix that runs on CI for every protocol change. If you don't set this up early, you'll discover a "works on my machine" decryption failure three weeks before launch.

**Presence and delivery receipts will have timing-dependent bugs that are nearly impossible to reproduce deterministically.** Use a fake clock abstraction in your backend from day one so that tests can control time. "User goes offline at exactly the moment a message is delivered" is not an exotic scenario; it's Tuesday afternoon.

**Security regression testing needs its own suite.** Every time you change a cryptographic primitive, key exchange flow, or message format, you need a suite that verifies the old security properties still hold. This suite should include negative tests: attempts to decrypt with the wrong key, attempts to join a group without a valid signing party attestation, replay attacks. If this suite doesn't exist, a refactor will silently break a security property and you won't find out until a security researcher does.

**What I'd prioritise in the test strategy:**
1. Property-based crypto tests using `hypothesis` (Python) or `proptest` (Rust) — generate random keys and messages, assert properties hold
2. A cross-platform compatibility matrix in CI
3. A dedicated key lifecycle test suite
4. Chaos testing for the ephemeral chat state machine (inject random failures at each state transition)
5. A security regression suite that runs on every PR

---

## 7. Performance Tester

Small user base means most performance concerns are manageable — but there are a few places where this design will surprise you with bad numbers, and one or two where the crypto overhead is non-trivial. Let me be specific.

**WebSocket is the right choice for real-time delivery.** Don't let anyone talk you into long-polling, SSE for bidirectional comms, or anything else. WebSockets have well-understood reconnection semantics, good library support everywhere, and the overhead for 20 concurrent connections per group is genuinely negligible. The concern is not throughput — it's reconnection behaviour on mobile. iOS and Android aggressively kill background WebSocket connections. You need an exponential-backoff reconnection strategy with a maximum retry interval, and you need to test it explicitly: kill the app, wait 5 minutes, reopen, and verify that message delivery resumes with no gaps or duplicates.

**Crypto overhead for group messages depends entirely on the protocol you choose.** With MLS and 20 group members, key encapsulation for a new message involves encrypting the message key once and distributing it via the ratchet tree — the computational cost is O(log n) where n is group size. For 20 members, that's roughly 4-5 tree operations per message send. With modern hardware and libsodium, this is in the microsecond range on desktop. On a mid-range Android phone from 2020, expect 1-5ms per message for the key operations. That's fine for chat. What will be slow is **key rotation on member add/remove**: updating the ratchet tree for all remaining members involves O(n log n) operations. Test this explicitly and set a performance budget (I'd target < 500ms for a full group key rotation on a 2019 mid-range Android device).

**Battery impact on mobile is the silent killer for presence-based apps.** Maintaining a WebSocket connection in the foreground is fine. The problem is presence heartbeats: to reliably track who is online, you need periodic pings (typically every 30-60 seconds). On Android, a background app sending a ping every 30 seconds will be killed by Doze mode within minutes. On iOS, background network activity is tightly restricted. Your presence system must gracefully degrade: use push notifications (APNs/FCM) to wake the app for important events (someone raised a help flag), and accept that presence indicators will be delayed or coarse-grained when users are on mobile. Design for "probably online" rather than "definitively online."

**The ephemeral chat notification delivery path has a latency budget you should define upfront.** When Alice raises a "I need help" flag, how quickly should Bob's device display the notification? I'd set a target of < 2 seconds for an online user on a good connection, and design the delivery path with that budget in mind. Measure: server processing time, WebSocket delivery time, client-side decryption time (to decrypt the notification envelope), UI render time. Each of these has a budget; make it explicit.

**Local encrypted database performance matters more than people expect.** SQLCipher (encrypted SQLite) has roughly 5-15% overhead compared to unencrypted SQLite for typical query patterns. That's fine. What's not fine is decrypting 500 historical messages every time the user opens a chat. Implement a decrypted in-memory cache for the active conversation with a clear invalidation strategy. Also, establish a maximum message history depth per conversation — storing unlimited history in an encrypted local database on a phone with 64GB of storage will eventually cause user complaints.

**Concrete performance targets I'd establish before writing code:**
- Message send-to-receive latency (same region, both online): < 200ms p95
- Group key rotation (20 members, mid-range Android): < 500ms
- Cold start to first message rendered: < 3 seconds on a 2019 mid-range Android device
- WebSocket reconnection after network interruption: < 5 seconds
- Presence update propagation: < 10 seconds (accept coarser granularity on mobile)

---

## Cross-Cutting Themes

Five themes appeared independently across multiple personas, suggesting they are the highest-priority risks for this project.

### 1. The Threat Model Must Come First
_(Security Expert, Senior Architect, QA Champion)_

Not a single design decision — not the encryption scheme, not the presence architecture, not the server model — can be correctly evaluated without a written threat model. "Security is paramount" is a value statement, not a design constraint. The adversary, their capabilities, and the acceptable risk level must be defined before architecture is agreed upon. This is the single most impactful missing artefact in the current proposal.

### 2. Group Key Management on Member Changes Is the Hardest Problem
_(Security Expert, Senior Architect, Normal Programmer, Bored Senior Developer)_

The group membership change problem — ensuring that a removed member cannot decrypt future messages, and that a new member cannot decrypt past messages, with forward secrecy preserved throughout — is genuinely hard and has a well-studied solution (MLS, RFC 9420). Every persona that touched cryptography independently converged on this. Do not attempt a custom solution. Adopt MLS and budget significant implementation and testing time for the key rotation flows.

### 3. Cross-Platform Is an Underestimated Engineering Tax
_(Bored Senior Developer, Normal Programmer, QA Champion, Performance Tester)_

Supporting six platforms is not a multiplier on features — it is a multiplier on every bug, every test case, every release, and every crypto library integration. Four personas flagged this independently. The choice of cross-platform framework (Flutter, React Native, or a Rust core with thin native UIs) will define the team's life for years. A cross-platform compatibility test matrix in CI is non-negotiable, not a nice-to-have.

### 4. The Ephemeral Chat Feature Is a State Machine That Will Bite You
_(UX Designer, Bored Senior Developer, QA Champion, Performance Tester)_

What sounds like a simple "create, use, delete" flow involves at least a dozen failure modes that real users will encounter in the first week of production use. The feature is architecturally interesting and genuinely differentiating, but it needs an explicit state machine diagram covering every failure transition before implementation begins. This is the feature most likely to generate disproportionate support burden relative to its complexity on paper.

### 5. The Server Should Know As Little As Possible, By Design
_(Security Expert, Senior Architect, Bored Senior Developer)_

Metadata leakage — the server learning who is online when, who communicates with whom, message sizes, and timing patterns — was identified as a critical risk independent of content encryption. A "dumb pipe" or metadata-minimising server architecture is significantly harder to retrofit than to build in from the start. The architecture should treat the server as an untrusted routing layer, not a trusted service, from the very first design decision. This applies equally to presence (which leaks timing data) and to group membership (which reveals the social graph).

---

# Round 2 Feedback — Post Phase 1 Implementation

> Personas now reviewing **actual code**: `main.rs`, `challenge.rs`, `middleware.rs`, `ws_handler.rs`, `message_types.rs`, `user.rs`, `crypto_service.dart`, `sodium_crypto_service.dart`, `ws_client.dart`, `auth_provider.dart`, `onboarding_screen.dart`, `contact.dart`, `contacts_provider.dart`.

---

## 1. UX Designer — Round 2

**What was done well:** The 3-step key-signing ceremony in `onboarding_screen.dart` is genuinely thoughtful. The `_StepIndicator` widget, the camera-permission error handling with a specific message about device settings, and the debounce on duplicate QR scans (`_lastScannedKey` with a 2-second cooldown) all show care for real-world use. Labelling the onboarding flow "Key-Signing Ceremony" rather than "Setup" is a good tone choice — it signals that this is a meaningful, one-time ritual, not a boring form.

**Specific concerns:**

The fingerprint shown to users is `_fingerprint(auth.publicKey!)` which calls `_toHex(key).substring(0, 8)` — that is 4 bytes, or 32 bits. This is the piece of information a user compares with someone standing physically next to them to confirm identity. 32 bits is trivially collision-prone and visually meaningless: `a3f1bc09` reads identically to `a3f1bc09` on a small screen in bad lighting. Signal uses 60-character Safety Numbers. Wire uses 12 words. Even a 12-character hex or a short word-pair encoding would be a dramatic improvement.

The `send()` method in `ws_client.dart` throws a `StateError` synchronously if the socket is not connected. The call site in `auth_provider.dart` has no try-catch around WS sends. In Phase 2, when users compose and send messages while the app is reconnecting (exponential backoff starts at 1s, reaches 32s), their compose action will silently fail or crash. There is a `// TODO: consider queuing outbound envelopes while reconnecting` comment in the file — that todo is now urgent.

Step 2 of onboarding ("I'm done being scanned → Start scanning others") is a single `FilledButton` with no visual affordance for the user who doesn't understand that they need to wait for *others* to scan them before pressing it. At a real ceremony with 15 people, half will skip Step 2 in under 5 seconds.

**Recommendations for Phase 2:** Extend the fingerprint to at least 20 hex characters or a word-phrase encoding. Implement outbound message queuing in `WsClient` before shipping any chat UI. Add a "waiting for others to scan you" state to Step 2 of onboarding — a live counter of "X people have scanned you" would be compelling if the backend can support it.

**Risk rating: MEDIUM** — The core ceremony flow works, but the dangerously short fingerprint and silent send-failures will create real trust and usability problems at the first live event.

---

## 2. Security Expert — Round 2

**What was done well:** `verify_strict` (not `verify`) is used in `challenge.rs` — this is the correct choice; it rejects non-canonical signatures that are accepted by the laxer variant and would otherwise open a malleability vector. The `used` flag on `PendingChallenge` plus expiry check enforces single-use nonces correctly. The `SodiumCryptoService` HKDF salt is the ephemeral public key bytes, which binds the derived key to the specific exchange — a subtlety many developers miss. Separate Ed25519 signing and X25519 encryption keypairs are correctly implemented; the `crypto_service.dart` comment explicitly warns "Ed25519 and X25519 use different elliptic curves and must NOT share key material." Good.

**Specific concerns:**

`build_router` in `main.rs` configures CORS as `allow_origin(tower_http::cors::Any)`. For a private, invite-only application, this means any origin on the internet can make authenticated cross-origin requests. At minimum, this should be locked to the specific client origin(s) in production config.

Session tokens in `SessionStore` have no TTL. After a successful login, the token lives in the in-memory HashMap indefinitely until the server restarts. The Round 1 doc mentioned "short-lived JWTs (4 hour expiry)" — the implementation drifted to opaque random tokens with zero expiry logic. A user who leaves the group still has a valid session token until server restart.

The WebSocket upgrade URL is `?token=<session_token>` — visible in `ws_handler.rs` and `WsQuery`. Query parameters are logged verbatim by every reverse proxy, load balancer, and tracing system (including the `TraceLayer` added in `build_router`). This leaks session tokens to anyone with log access. The standard mitigation is to send the token as the first WebSocket message after upgrade, not in the URL.

`/auth/challenge` accepts any hex public key with no rate limiting and no registration check. An unauthenticated attacker can enumerate challenges for arbitrary public keys at any rate. More critically, `User::upsert` in `user.rs` inserts a new user row for any public key that completes the challenge-response — so any keypair holder can self-register. The Phase 1 design doc stated "No self-registration — an existing admin adds the user's public key." The code does not enforce this.

The expired challenge GC never runs. `challenge.rs` marks challenges `used` or checks expiry on lookup, but never removes entries. Under a DoS scenario (or just time), the HashMap grows without bound.

**Recommendations for Phase 2:** Lock CORS to specific origins. Add session TTL (4h as documented) and a cleanup task. Move WS auth token to first-message protocol, not URL. Add a server-side public-key allowlist checked before issuing challenges. Add a background task to prune expired challenges.

**Risk rating: HIGH** — Three of the five issues above (unrestricted self-registration, session tokens in logs, missing session expiry) are directly exploitable in a real deployment.

---

## 3. Bored Senior Developer — Round 2

**What was done well:** The Rust code is actually pretty clean. `FromRef<AppState>` sub-state extraction is idiomatic Axum. The `message_types.rs` `#[serde(tag = "type", rename_all = "snake_case")]` wire protocol is exactly right — typed, self-describing, easy to extend. The `CryptoService` abstract interface in Dart with `SodiumCryptoService` as the concrete implementation and a comment about swapping in a mock for tests — that is exactly the separation I'd want to see, and it's rare to see it done up front.

**Specific concerns:**

The file opens with `#![allow(dead_code)]` in `main.rs`. I know it's a scaffold. Ship one sprint with that attribute and you have permanently trained your CI to ignore dead code warnings. Remove it now and fix the warnings — it takes 20 minutes and pays dividends for the life of the project.

`SodiumCryptoService` does not use libsodium. It uses the Dart `cryptography` package. This is fine — `cryptography` is a reasonable choice — but the naming will confuse every developer who joins the project. They will spend time trying to find the `flutter_sodium` dependency that doesn't exist. Rename it `DartCryptoCryptoService` or simply `CryptographyPackageCryptoService` (or better: just `CryptoServiceImpl`).

`generateAndStoreKeypair()` in `auth_provider.dart` derives a local `userId` as `base64Url.encode(keypair.publicKey.sublist(0, 16))`. This ID is used for local routing. But after calling `requestChallenge`, the server assigns its own `Uuid` and stores it in `state.userId`. So there are two different user-ID schemes in play simultaneously, and the local-only one leaks into persistent storage via `storage.saveUserId(userId)` before the server assignment is known. If any code path reads `userId` before `requestChallenge` completes and sends it to the server, you have a silent data corruption bug.

The contacts list in `contacts_provider.dart` is stored as a single JSON blob under the key `'contacts'` in secure storage. Every `addContact` call reads the entire list, appends, and re-serialises the whole thing. With 20 contacts this is fine. When you add the forum board and skills directory in Phase 2, if contacts grow or the model changes, this will bite you.

**Recommendations for Phase 2:** Remove `#![allow(dead_code)]` immediately. Rename `SodiumCryptoService`. Unify user-ID handling to a single scheme — use the server UUID everywhere once obtained. Plan a proper local persistence layer (SQLite via `sqflite` or `drift`) before the contacts/profiles/forum data model grows.

**Risk rating: MEDIUM** — Nothing will blow up today, but the dead-code suppression and dual user-ID scheme are landmines for future developers.

---

## 4. Senior Architect — Round 2

**What was done well:** The TECH_STACK.md documented decision to use MLS + Double Ratchet was ambitious and correct. The actual implementation has sensibly deferred the full MLS complexity in favour of shipping a working skeleton — ECIES with ephemeral X25519 + HKDF + ChaCha20-Poly1305 per message is a reasonable intermediate step, and it's correctly implemented. The dumb-relay model is intact in `ws_handler.rs`: the server genuinely never inspects `payload`. Group membership enforcement at the relay layer, using DB-verified group IDs, is architecturally clean.

**Specific concerns:**

The biggest architectural fact not stated anywhere in the code is that the entire stack pivoted from React Native + Tauri (as documented in TECH_STACK.md) to Flutter. TECH_STACK.md is now wrong. It still says "React Native (Expo) for iOS/Android/Web + Tauri for Linux/macOS/Windows desktop." The actual client is Flutter. The documented rationale for the original decision ("Tauri Rust core shares OpenMLS code with the backend") is now moot. Update the document — or future contributors will make architectural decisions based on fiction.

`ConnectionMap` and `OfflineQueue` use `std::sync::Mutex` (blocking) inside async Axum handlers. In `handle_send`, the lock is acquired synchronously with `connections.lock().expect(...)` inside a `tokio::spawn` context. For 20 users this will never matter. But when you add the forum board and presence in Phase 2, or if a group broadcast iterates 20 connections while holding the lock, you are blocking a Tokio worker thread. The pattern should be `tokio::sync::Mutex` or — better — a `DashMap` for the connection map.

Every `ClientMessage::Send` triggers two sequential database round-trips: `fetch_user_group(db, from)` and then `fetch_user_group(db, to)`, plus a third `fetch_group_member_ids` for group sends. This runs on the hot path of every single message. Group membership is stable — users don't change groups mid-session. Cache the sender's group at WS connection time in the per-connection state, eliminating the first DB call entirely.

The current crypto scheme (ECIES per message) provides forward secrecy per message (fresh ephemeral key each time), but does not provide post-compromise security — if a user's long-term X25519 private key is compromised, an attacker can decrypt all future messages encrypted to that key until it is rotated. MLS (the documented target) solves this with epoch-based group keys and regular Commits. The gap between the documentation and the implementation is not wrong — it's a reasonable Phase 1 shortcut — but it needs to be explicitly acknowledged in a tech debt note.

**Recommendations for Phase 2:** Update TECH_STACK.md to reflect Flutter. Replace `std::sync::Mutex` on `ConnectionMap` and `OfflineQueue` with `tokio::sync::RwLock` or `DashMap`. Cache group membership at WS connection time. Document the "no post-compromise security yet" gap and schedule MLS migration.

**Risk rating: MEDIUM** — The architecture is sound for the current scale. The blocking-mutex-in-async and per-message DB queries will become problems during Phase 2 load.

---

## 5. Normal Programmer — Round 2

**What was done well:** The `Contact.fromQrPayload` factory is clean and the field validation (`payload['v'] != 1 || ...`) in `onboarding_screen.dart` is defensive and clear. The Riverpod `@riverpod` generator annotation on `CryptoService` (returning `SodiumCryptoService()` with a comment about swapping for tests) is a pattern that a normal programmer joining the team can immediately understand and use. `DuplicateContactException` as a typed exception rather than a string error is the right call.

**Specific concerns:**

`_handleRawMessage` in `ws_client.dart` swallows all parse errors silently:
```dart
} catch (_) {
  // TODO: log parse errors via a proper logger, not print
}
```
This means if the server sends a malformed envelope, the client does nothing — no user feedback, no log entry, nothing. In Phase 2 with a chat UI, a message that silently disappears is indistinguishable from a message that was never sent, which is a genuinely bad experience that will be hard to debug.

`_fromHex` in `auth_provider.dart` is a manual implementation. There are two other manual hex implementations in the codebase (`_toHex` also in `auth_provider.dart`, `_Uint8ListHexConverter` in `contact.dart`). This is three different implementations of the same utility, none of them in a shared location. One of them will have a subtle edge case.

The challenge store in `challenge.rs` never cleans up. There is no background expiry task, no periodic sweep, and no eviction policy. The `is_expired()` check only fires when the specific challenge is looked up. If someone repeatedly hammers `/auth/challenge` with different (or fake) public keys, entries accumulate indefinitely. This is a normal programmer error — easy to miss during initial implementation, easy to fix with a 10-line background task.

The `#[allow(dead_code)]` at the top of `main.rs` will mask real unused-code warnings introduced in Phase 2 feature branches. Remove it now.

**Recommendations for Phase 2:** Add a shared `hex_utils.dart` with `toHex` and `fromHex` and remove the duplicates. Add a logger call (not print) in `_handleRawMessage`. Add a periodic cleanup task for the challenge store. Fix the dead-code lint.

**Risk rating: LOW** — The bugs are real but mostly benign for this scale. The duplicated hex utilities are the one that will cause a subtle production issue eventually.

---

## 6. QA Champion — Round 2

**What was done well:** The `CryptoService` abstract interface is the single best testability decision in the codebase. Because `SodiumCryptoService` hides behind `CryptoService`, and because `cryptoServiceProvider` is a Riverpod provider that can be overridden in tests, the entire auth and encryption flow can be tested without cryptographic operations. That's the right foundation. The typed `ClientMessage` / `ServerMessage` enum in `message_types.rs` with `#[serde(tag = "type")]` means serialization round-trip tests are straightforward to write.

**Specific concerns:**

There are no tests visible in any of the reviewed files. I understand this is Phase 1 scaffolding, but there are several flows that are already complex enough to break in non-obvious ways and that have no coverage:

1. The `verify_challenge` function in `challenge.rs` has 5 distinct error paths (missing challenge, expired, used, bad public key hex, bad signature hex) and one happy path. These are 6 unit tests that take 30 minutes to write and would have caught the "expired challenge entry never removed" issue.

2. The `requestChallenge` method in `auth_provider.dart` is 60 lines of async state machine across 7 steps with network calls. If the POST `/auth/challenge` call fails, the state is left with `isLoading: false, error: e.toString()` — but the error message will contain the raw HTTP body, which might include internal server error details. That's a QA and security issue in one.

3. The onboarding QR scan flow has a race condition: `_onDetect` is called on every frame from the camera. The `_lastScannedKey` debounce is a widget-local variable, not a `ValueNotifier` or `StreamController`. If `addContact` is slow (storage write), a second scan of the same QR can arrive before the first `Future.delayed` fires. The `await ref.read(contactsProvider.notifier).addContact(contact)` call is not guarded against concurrent execution.

4. The `_restoreSession` flow in `auth_provider.dart` marks the state as loaded even when it recovers keys but no session token (line: `state = AuthState(... sessionToken: sessionToken ...` where sessionToken may be null). Downstream code checks `isAuthenticated` which requires `sessionToken != null`. A test that restores only keys (no token) would catch whether the router correctly redirects to onboarding vs. home.

**Recommendations for Phase 2:** Write unit tests for `verify_challenge` (all 6 paths) before adding any new auth feature. Add a concurrent-call guard to `_onDetect` using an `_isProcessingScan` bool flag. Set up a test override for `cryptoServiceProvider` and write one integration test for the full auth handshake flow.

**Risk rating: MEDIUM** — The concurrency bug in QR scanning is a real defect that will manifest at the first ceremony. The missing error-path tests mean regressions will ship silently.

---

## 7. Performance Tester — Round 2

**What was done well:** The exponential backoff in `ws_client.dart` is correctly implemented — doubles on each failure, caps at `maxReconnectDelay` (default 32s), resets on successful connect. This prevents reconnect storms under a server restart. The `mpsc::unbounded_channel` per-connection in `ws_handler.rs` decouples the read loop from the write path cleanly — a slow client sink won't block message routing. The `broadcast_presence` function correctly locks, sends, and unlocks in one pass rather than making per-member lock acquisitions.

**Specific concerns:**

Every `ClientMessage::Send` in `ws_handler.rs` makes at minimum two sequential database queries before touching a connection:
```rust
let sender_group_id = match fetch_user_group(db, from).await { ... };
// ... then ...
fetch_user_group(db, to).await
// ... and for group sends, also ...
fetch_group_member_ids(db, to).await
```
For a group of 20 members all sending messages at once, each message triggers 2-3 DB round-trips. At 20 concurrent users sending messages at 1Hz each, that is 40-60 DB queries per second just for routing. PostgreSQL on a CX21 handles this fine, but it's entirely unnecessary: group membership is invariant during a session. Cache `sender_group_id` in the per-connection state at connect time and eliminate the `fetch_user_group(db, from)` call on every message.

`ConnectionMap` is a `Arc<Mutex<HashMap<Uuid, PeerTx>>>` with `std::sync::Mutex` — the standard library blocking mutex. In `handle_send`, after routing logic, the code calls `connections.lock().expect(...)` inside a Tokio async task. `std::sync::Mutex` blocks the OS thread, which can starve other Tokio tasks on the same thread if lock contention occurs during a group broadcast (iterating 20 entries while holding the lock). Replace with `tokio::sync::RwLock` for reads and writes, or `DashMap` for a lock-free alternative.

`OfflineQueue` is unbounded: `Arc<Mutex<HashMap<Uuid, Vec<String>>>>` with `or_default()` on every push. An offline user in an active group will accumulate every group message sent while they are disconnected. With no size cap, a user who is offline for a day in an active group could return to gigabytes of queued JSON strings. Add a configurable max-queue-depth (e.g., 500 messages) with oldest-first eviction.

The `mpsc::unbounded_channel` per connection has the same problem from the send side: `UnboundedSender` never applies backpressure. If the client's TCP receive window fills (slow phone on 2G), the Tokio task draining `rx` into the sink will block on `sink.send(msg).await`, but the routing side will keep pushing into the unbounded channel. Switch to a bounded channel (`mpsc::channel(256)`) and drop or error on overflow.

**Risk rating: MEDIUM** — For 20 users the current implementation will perform fine. But the unbounded structures (queue, channel) and per-message DB calls are architecture decisions that will require rewrites when Phase 2 adds the forum board and presence updates to the same hot path.

---

## Phase 2 Recommendations (consolidated)

### Top 3 things to DO in Phase 2

**1. Fix the three exploitable security issues before shipping anything new.**
Lock CORS to specific origins in `build_router`. Add session TTL (expire tokens after 4 hours, as the original design said). Move the WS session token from the URL query param to the first WebSocket message — the current `?token=` approach logs credentials to every proxy and tracing system. These are simple changes, each under 30 lines, and each currently exploitable.

**2. Unify and persist local data with a proper SQLite layer before the forum/profiles data model grows.**
`contacts_provider.dart` stores everything as a single JSON blob. Adding forum posts, user profiles, and skills in Phase 2 to the same pattern will create an unmanageable tangle. Switch to `drift` (Dart's type-safe SQLite ORM) now, before there are three more blob-stores to migrate. Define the schema once, get querying and indexing, and enable the skills-directory filter feature the UX designer asked for.

**3. Add the two-line guard to `_onDetect` and extend the fingerprint length before the next ceremony.**
The QR scanner concurrency bug (`_isProcessingScan` guard is missing) will silently add duplicate contacts if storage is slow. The 8-character (32-bit) fingerprint is inadequate for identity verification. Both are small changes with high safety impact and must land before a real key-signing ceremony is run with actual users.

### Top 3 things to AVOID in Phase 2

**1. Do not add any new feature that sends a WS message without first implementing outbound message queuing.**
The `ws_client.dart` `send()` method throws synchronously when disconnected. The Phase 2 chat UI will be built on top of this. If users compose messages during a reconnect cycle, they will silently fail. Build the outbound queue first, or every chat feature ships broken.

**2. Do not let `#![allow(dead_code)]` survive into Phase 2 feature branches.**
Once the compiler is trained to ignore dead code warnings, unused code from removed features accumulates invisibly. With a growing team and Phase 2 complexity, this becomes a maintenance and security liability (dead code often includes half-finished, untested paths). Remove it now, fix the handful of warnings it was suppressing, and keep CI clean.

**3. Do not add Phase 2 features on top of per-message DB queries without first caching group membership.**
The two `fetch_user_group` calls per message are fine at 20 users. Adding forum-board notifications, presence updates, and message history to the same relay path in Phase 2 will multiply the DB load significantly. Cache the sender's `group_id` at WS connect time. This is a single-session-scoped optimisation that eliminates the majority of relay DB queries and takes an afternoon to implement.
