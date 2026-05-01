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

---

# Round 3 Feedback — Post Phase 2 Implementation

> Seven expert personas review the Phase 2 implementation directly from source code. Each reviewer read: `chat_screen.dart`, `chat_list_screen.dart`, `forum_screen.dart`, `profile_screen.dart`, `members_screen.dart`, `presence_dot.dart`, `connection_banner.dart`, `app_database.dart`, `ws_client.dart`, `forum/handlers.rs`, `profiles/handlers.rs`, and `relay/ws_handler.rs`.

---

## 1. UX Designer

**What improved since Round 2**

The `ConnectionBanner` is the standout improvement. An animated amber bar reading "⚠ Reconnecting… (N messages queued)" is exactly the right mental model for users — it's honest about the failure state, actionable in what it implies ("your messages are safe, sit tight"), and scoped to only appear in `ChatListScreen` where it matters. The `PresenceDot` widget is also well-executed: it uses `presenceProvider.select(...)` so it only rebuilds when that specific user's status changes, and the `Tooltip` wrapping it makes the coloured dot accessible to users who can't distinguish green from grey.

`MembersScreen` now has skill-chip filtering and a name search bar — this directly answers Round 1's recommendation to build a skills directory. The filter UX is functional and the `FilterChip` pattern is idiomatic Flutter. The `ProfileScreen` fingerprint card with a copy-to-clipboard button and a tooltip explaining its purpose is genuinely good design — it introduces a security concept without demanding the user already understand it.

**New concerns introduced in Phase 2**

Every `_ConversationTile` in `ChatListScreen` shows `subtitle: const Text('Tap to open chat')` — the same text for every entry, regardless of state. There is no last-message preview, no timestamp, no unread count. A user returning to the app after an hour cannot tell which conversation has new messages without opening each one. This is table-stakes chat UX that was presumably deferred, but it makes the list screen feel like a navigation menu rather than a messaging inbox.

The floating action button in `ChatListScreen` is completely silent when tapped: `onPressed: () { /* BLOCKED(phase-3): ephemeral help-request chat creation */ }`. No snackbar, no dialog, nothing. To a tester or early adopter this reads as a broken button. Even a modal saying "Ephemeral help chats are coming in the next update" would preserve trust.

The forum is largely non-functional for actual users: `const bodyText = '[encrypted body]'` is a compile-time constant, meaning every post body shows the same placeholder forever until that line is manually changed. The post *title*, however, is displayed in plaintext — users will naturally write sensitive information in the most visible field. This creates a false sense of what is and isn't private.

The `_selectedSkills` filter in `MembersScreen` uses AND logic — selecting "cooking" AND "first aid" returns only members with both. There is no UI indication of this behaviour. Most users will expect OR logic ("show me anyone who knows either"). The filter bar should label this clearly or switch to OR.

**Concrete Phase 3 recommendation**

Before wiring encryption, wire last-message preview into `_ConversationTile`. Fetch the most recent `MessagesTableData` per `conversationId` from the drift stream and show its timestamp and a truncated preview (or "1 new message" if `isDelivered == false`). Users who can't tell whether a conversation has new messages will not engage with the chat feature, regardless of how well the crypto works.

**Risk rating: MEDIUM** — the UI skeleton is coherent but the silent FAB and static "Tap to open chat" subtitle will erode tester confidence before Phase 3 ships.

---

## 2. Security Expert

**What improved since Round 2**

The most important fix shipped: the WS session token is no longer in the URL. `ws_client.dart` line 117 sends `{'type': 'auth', 'token': sessionToken}` as the first WebSocket message. This eliminates the credential-in-proxy-log vulnerability called out in Round 2. The 10-second auth timeout in `ws_handler.rs` (`tokio::time::timeout(Duration::from_secs(10), ...)`) is correct and consistent with the design spec. Group membership enforcement at the WS relay layer is now real: `sender_group_id` is fetched once at connect and the `handle_send` path validates that sender and recipient share a group UUID without a per-message DB query.

The drift schema shows the right instincts: `MessagesTable.payload` is commented "ALWAYS ciphertext — decrypt before display" and `plaintextCache` is nullable, modelling the pre/post-decryption lifecycle explicitly. The `OutboundQueueTable.payload` field is also marked "encrypted envelope payload" — the schema is designed for the encrypted world even before the crypto is wired.

**New concerns introduced in Phase 2**

The forum post **title** is plaintext end-to-end. `CreatePostRequest` in `forum/handlers.rs` defines `pub title: String` — stored verbatim in the database, logged by tracing, visible to anyone with DB read access. In a mutual aid context, post titles like "I need help escaping an abusive partner" or "Housing crisis — can't pay rent" are the most sensitive content in the system. The body has a crypto placeholder; the title has none.

`GET /users/:id/profile` in `profiles/handlers.rs` has an explicit comment: `BLOCKED(phase-2): group membership check not yet enforced here`. Any authenticated user — including those from other groups — can enumerate any profile by UUID. If user UUIDs are ever guessable or leaked via another vector, this is a full profile data breach.

The `OfflineQueue` in `ws_handler.rs` is `Arc<RwLock<HashMap<Uuid, Vec<String>>>>` — in-memory, lost on server restart. A server reboot during a crisis (exactly the moment a mutual aid server is most likely to be stressed) silently discards queued messages with no notification to sender or recipient.

`plaintextCache` in `MessagesTable` has a BLOCKED comment noting it must be cleared on MLS epoch rotation. This is not just a performance note — it is a forward secrecy requirement. If Phase 3 wires encryption but forgets to invalidate the cache on epoch rotation, users will read post-rotation messages with pre-rotation keys cached from before the epoch change.

**Concrete Phase 3 recommendation**

Encrypt forum post titles with the group key before Phase 3 ships, even if it's just `ChaCha20Poly1305(group_key, title_bytes)` with the result base64-encoded into the existing `title` column. The title field is more sensitive than the body because it is the first thing a helper reads, and it is currently in cleartext on the server.

**Risk rating: HIGH** — unencrypted forum post titles may expose the most sensitive content in the system at rest in the database and in server logs before Phase 3 ships.

---

## 3. Bored Senior Developer

**What improved since Round 2**

The drift schema is clean. Five tables, typed companions, `insertOnConflictUpdate` used correctly throughout, and the `forTesting` constructor is a small touch that will pay dividends the moment someone writes an integration test. The `_ComposeBar` correctly adds and removes its controller listener in `initState`/`dispose` — easy to get wrong, done right here. `AnimatedSwitcher` in `ConnectionBanner` with a `SizeTransition` is the correct animation primitive for a collapsing/expanding banner; whoever wrote this knows Flutter's animation layer.

The BLOCKED comment convention is genuinely useful — `BLOCKED(phase-3): encrypt with recipient's X25519 key before sending` in `_send()` is more informative than a vague TODO and directly traceable to the roadmap.

**New concerns introduced in Phase 2**

`final profileData = profile as dynamic;` in `profile_screen.dart` line 68. The Riverpod `profileNotifierProvider` presumably returns a typed model. Casting it to `dynamic` to access `displayName` and `skillsJson` will produce `Null` at runtime if the type changes — no compile-time error, no helpful stack trace, just a blank screen. This should be a typed model with a null-safe accessor.

`_messageStream` is initialized in `initState` with `ref.read(chatProvider).watchMessages(...)`. This stream is captured once and never updated. If the router pushes a new `ChatScreen` for a different `conversationId` via `pushReplacement` rather than a full rebuild, the old stream for the previous conversation will keep emitting. This is a subtle state-leak bug that will manifest as messages appearing in the wrong conversation.

`WsClient` has both `isConnected` and `isCurrentlyConnected` as getters, both returning `_state == WsConnectionState.connected`. One of them is dead code. The compiler would catch this if `#![allow(dead_code)]` wasn't in the Rust side — same energy, different language.

`withOpacity` is deprecated in Flutter 3.x in favour of `.withValues(alpha:)` — appears twice in `_MessageBubble`. `surfaceVariant` is deprecated in Material 3 (use `surfaceContainerHighest`) — appears in the `MembersScreen` filter bar background. These will generate analysis warnings as Flutter versions advance.

`_PostCard` in `forum_screen.dart` calls `ref.watch` three times: `contactsProvider`, `forumNotifierProvider`, `serverUrlProvider`. Any contact list change — including a presence update that has nothing to do with the forum — triggers a full rebuild of every visible PostCard. For a 30-post forum with 20 contacts updating presence, this is a lot of unnecessary widget work.

**Concrete Phase 3 recommendation**

Replace `profile as dynamic` with a typed `UserProfile` model before Phase 3 adds MLS key packages, epoch IDs, and credential blobs to the profile. Adding crypto fields through a `dynamic` cast will produce runtime errors that are invisible to the type checker and extremely unpleasant to debug during a key rotation ceremony.

**Risk rating: LOW** — these are code quality issues, not correctness failures, but they will compound as Phase 3 adds complexity on top of them.

---

## 4. Senior Architect

**What improved since Round 2**

The architectural boundary between relay and application logic is cleaner than in Phase 1. `ws_handler.rs` is a self-contained module: it owns the auth handshake, group enforcement, presence broadcast, and offline queue. It does not bleed into forum or profile logic. The decision to cache `sender_group_id` at WS connect time is exactly right — it was a specific Round 2 recommendation and it landed correctly: fetched once, never queried per message, passed explicitly into `handle_send`.

The `RwLock` scoping is correct throughout: `senders` is collected into a `Vec` while holding the read lock, the lock is dropped, and then `try_send` is called without holding any lock. This is the canonical pattern for avoiding deadlocks in async Rust and it is consistently applied.

The drift schema in `app_database.dart` properly separates the `OutboundQueueTable` as a persistence layer for the outbound message queue — the schema is designed for the right use case.

**New concerns introduced in Phase 2**

**Offline group message delivery is architecturally incomplete.** `ws_handler.rs` line 357 contains an explicit comment: "Offline group-message recipients are not queued (direct messages only)." This asymmetry — direct messages queued, group messages dropped — is not visible anywhere in the client UI and will produce silent data loss. In a group of 10, if 3 members are offline when a help request is posted to the group channel, they never receive it. With Phase 3 adding MLS group key material distributed via group messages, this gap becomes a cryptographic correctness problem, not just a UX inconvenience.

**The `OutboundQueueTable` exists in the drift schema but is not wired to `WsClient`.** The table has exactly the right columns (`toId`, `payload`, `queuedAt`, `attempts`). The BLOCKED comment on `ws_client.dart` line 57 says "persist outbound queue to drift OutboundQueueTable for crash-safety." This was supposed to land in Phase 2. The current `Queue<_OutboundMessage>` is in-memory and discarded on app restart. A user who sends 5 messages, force-closes the app, and reopens will see those messages in the `isDelivered == false` state with no way to resend.

**The `ForumPostsTable` has no row limit enforced by `watchForumPosts()`**, which fetches all rows ordered by `createdAt DESC`. This is a reactive drift stream, meaning the entire post list is re-emitted on every database change. Combined with `_PostCard` watching three providers, a single post resolution could trigger re-renders of hundreds of rows.

**Concrete Phase 3 recommendation**

Define the MLS group state as a first-class provider — `mlsGroupProvider` — that owns the current epoch, the group key, and the member set. Both `broadcast_presence` (which currently queries the DB on every connect) and `handle_send` (which queries per group message) should source group membership from this provider rather than `fetch_group_member_ids`. This is the natural container for the cached membership that Phase 3 requires and it eliminates the last remaining per-event DB queries.

**Risk rating: MEDIUM** — the architecture is sound for a 20-user single-node pilot, but the two persistence gaps (offline group messages dropped, outbound queue not persisted) must close before any production deployment.

---

## 5. Normal Programmer

**What improved since Round 2**

The code is readable. Each widget has a clear job and a clear boundary. `_MessageBubble` is a stateless widget that takes a message and a boolean — easy to understand, easy to test. `_ComposeBar` is extracted into its own stateful widget with its own controller lifecycle, which is the right call; it keeps `ChatScreen`'s `build` method clean. The `BLOCKED(phase-X)` comment pattern tells me exactly what's missing and when it's planned, which as a developer is far more useful than a vague TODO.

The forum screen's pull-to-refresh (`RefreshIndicator` wrapping the `ListView`) and the empty state with the `help_outline` icon and "Be the first to ask!" copy are small touches that make the app feel considered rather than assembled. The `_formatRelativeTime` helper is a single readable function rather than a dependency on a third-party package — appropriate for the scale.

**New concerns introduced in Phase 2**

Tapping the FAB on `ChatListScreen` does absolutely nothing — no feedback, no message, complete silence. As a tester filing bugs, this is my first report. A single `ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ephemeral chats coming in Phase 3!')))` would eliminate an entire category of tester confusion for zero engineering cost.

`const bodyText = '[encrypted body]'` on line 131 of `forum_screen.dart` is declared as a `const` variable. When Phase 3 wires decryption, the developer will change `const` to a computed value — but the risk is that it gets left as a const and the decryption path is wired in a parallel branch that never reaches this variable. A `// BLOCKED(phase-3): replace with forum.decryptBody(post)` comment on the same line as the assignment would make the connection explicit.

The `// TODO: move to app config provider` comment next to `const serverUrl = 'http://localhost:8000'` in `profile_screen.dart` is exactly the kind of thing that ships. Every HTTP call in Phase 3 that builds on `profileNotifierProvider` will silently use localhost as its base URL unless this is resolved first.

Anyone can tap "Mark resolved" on any forum post. The BLOCKED comment acknowledges this but testers will file it as a bug. Even a `disabled` state on the button with a tooltip "Only the post author can resolve" would set expectations correctly until the membership API is ready.

**Concrete Phase 3 recommendation**

Add a one-line stub handler to the `ChatListScreen` FAB `onPressed` before Phase 3 ships ephemeral chat. Show a bottom sheet that says "Raise a help request — tap to let your group know you need support." Shipping a silent button into a crisis-support app is a trust problem, not just a UX problem.

**Risk rating: LOW** — the code is clean and the BLOCKED comments tell a coherent story. The main gap is a handful of easily-fixed placeholder issues that will confuse testers and early users before Phase 3 closes them.

---

## 6. QA Champion

**What improved since Round 2**

`AppDatabase.forTesting(super.e)` is a proper seam for unit and integration tests — drift's in-memory backend can be passed directly. `isDelivered` on `MessagesTable` gives a boolean state to assert against in delivery-confirmation tests. All async operations in `ForumScreen` and `ProfileScreen` use `context.mounted` checks before calling `ScaffoldMessenger` — a common Flutter bug is fixed proactively here. The `_ComposeBar.onSend` being a `Future<void> Function()` means callers can await it in widget tests.

The 10-second auth timeout in `ws_handler.rs` is testable: inject a mock stream that sends nothing, assert that the server closes with code 4001. The bounded mpsc channel (capacity 256) is also assertable — tests can fill the channel and verify `try_send` returns `Err`.

**New concerns introduced in Phase 2**

`watchGroupMembers` in `app_database.dart` filters by `userId.isNotValue(ownUserId)` — it excludes the current user but does not enforce group membership. A test that inserts profiles for three users from two different groups will receive all of them from this stream. Any test asserting group isolation via `MembersScreen` is testing a false invariant.

`_formatRelativeTime` in `forum_screen.dart` calls `DateTime.now()` internally. This function is not injectable: tests that run at different times of day will produce different outputs ("just now" vs "1 min ago"), making snapshot tests fragile and making it impossible to test the "yesterday" branch without manipulating the system clock. The function needs a `DateTime now` parameter with a default of `DateTime.now()`.

`resolve_post` in `forum/handlers.rs` calls `ForumPost::resolve(&pool, id, auth.user_id)`. Whether `auth.user_id` is actually compared to `post.author_id` inside the model is not visible from the handler. The BLOCKED comment on the Flutter side (`// BLOCKED(phase-2): restrict resolve to author + group members`) implies this is not yet enforced. A test that calls `resolve_post` with a user who did not author the post should return 403 — currently it likely returns 200.

The 500-message FIFO overflow behaviour in `WsClient.enqueue` — dropping the oldest message and printing a warning — has no test. This is a silent data-loss path that is also security-adjacent: a fast sender can deliberately overflow the queue to push out legitimate messages.

**Concrete Phase 3 recommendation**

Add a `now` parameter to `_formatRelativeTime` before Phase 3 adds timestamp-sensitive ephemeral chat expiry logic. The same untestable `DateTime.now()` pattern, if copied into an ephemeral chat "expires in N minutes" display, will make that feature's timing logic completely untestable without mocking the system clock.

**Risk rating: MEDIUM** — `watchGroupMembers` silently returns cross-group data, `resolve_post` authorization is unverified, and the queue overflow path is untested. Two of these three are currently incorrect by design, not just uncovered.

---

## 7. Performance Tester

**What improved since Round 2**

The `group_id` caching in `ws_handler.rs` is the most impactful performance change in Phase 2. Every `handle_send` call previously would have required a DB round-trip to verify group membership; now `sender_group_id` is a stack variable passed through the call chain. The `RwLock` read-before-collect-before-send pattern in both `handle_send` and `broadcast_presence` is correct: the lock is held only for the `HashMap` lookup, dropped before any channel send. This eliminates lock contention across concurrent message deliveries.

`PresenceDot` uses `presenceProvider.select((map) => map[userId] ?? PresenceStatus.offline)` — this is the correct Flutter pattern for fine-grained subscription. A presence update for user A will rebuild only the `PresenceDot` for user A, not every dot on screen.

**New concerns introduced in Phase 2**

`broadcast_presence` in `ws_handler.rs` still issues two DB queries on every connect and disconnect: `fetch_user_group` and `fetch_group_member_ids`. In a 30-member group where everyone is on a flaky mobile network in a crisis scenario, a connect/disconnect storm of 10 events per second generates 20 DB queries per second from this function alone, before any message routing. The BLOCKED comment on line 367 acknowledges this but flags it for after Phase 3 — it should be resolved sooner.

`_PostCard` in `forum_screen.dart` registers three `ref.watch` calls: `contactsProvider`, `forumNotifierProvider`, and `serverUrlProvider`. `contactsProvider` updates on presence changes. This means every presence update in the app — every online/offline transition for any group member — triggers a full rebuild of every visible `_PostCard`. For a forum with 20 posts and a 30-member group with frequent presence churn, this generates a continuous stream of unnecessary widget rebuilds.

`decodeProfileData` is called twice per `setState` in `MembersScreen` — once in `_applyFilters` and once in `_allSkills` — iterating the full member list and parsing a JSON string per member each time. Typing a single character in the name filter calls `setState`, which calls both functions. For a group of 50 members with 5 skills each, this is 100 JSON parse operations per keypress.

`watchForumPosts()` has no `LIMIT` clause. The drift reactive stream re-emits the complete post list on every DB change (including resolving a post). Combined with the `_PostCard` multi-watch issue, resolving one post causes a full list re-render with JSON parses.

**Concrete Phase 3 recommendation**

Introduce a `groupMemberCacheProvider` that is populated once on WS connect and exposes the current member list as an in-memory `List<Uuid>`. Feed it into both `broadcast_presence` and `handle_send` on the server, and into `_applyFilters` / `_allSkills` on the client (pre-parsed, not JSON strings). Phase 3 will implement MLS epoch rotation — the natural invalidation trigger for this cache — making the timing exactly right to build it there.

**Risk rating: MEDIUM** — performance is acceptable for a 20-user pilot but the presence-churn DB storm and per-PostCard multi-watch will degrade noticeably at 50+ users on unreliable networks, which is exactly the deployment context this app targets.

---

## Phase 3 Recommendations (consolidated from Round 3)

### Top 3 DOs for Phase 3

**1. DO encrypt forum post titles client-side before Phase 3 ships.**
The `CreatePostRequest.title: String` field in `forum/handlers.rs` is stored verbatim in the database and appears in server logs via tracing. In a mutual-aid context, titles like "I need help leaving an abusive home" are the most sensitive content the system will handle. Apply the same group-key symmetric encryption to the title as will be applied to the body — even a single `ChaCha20Poly1305(group_key, title_bytes)` pass stored as base64 in the existing column is sufficient until MLS is fully wired.

**2. DO wire the existing `OutboundQueueTable` to `WsClient` before adding any new messaging features.**
The drift table was designed in Phase 2 with exactly the right schema (`toId`, `payload`, `queuedAt`, `attempts`) but `WsClient` still uses an in-memory `Queue<_OutboundMessage>`. The queue is silently discarded on app restart. Every new messaging feature built in Phase 3 — ephemeral chats, group key distribution messages — will inherit this silent data-loss behaviour. The persistence path is a bounded engineering task: write to drift on `enqueue`, read and drain on `connect`, delete on successful send.

**3. DO build a typed profile model to replace `profile as dynamic` before adding MLS fields.**
`profile_screen.dart` line 68 casts the `profileNotifierProvider` result to `dynamic` to access `displayName` and `skillsJson`. Phase 3 will add key packages, epoch identifiers, and MLS credential blobs to the user profile. Adding crypto fields through a `dynamic` cast produces runtime errors that are invisible to the type checker and extremely difficult to debug during a live key rotation event.

### Top 3 DON'Ts for Phase 3

**1. DON'T ship `const serverUrl = 'http://localhost:8000'` into Phase 3.**
The hardcoded URL in `profile_screen.dart` (with its `// TODO: move to app config provider` comment) will silently route all profile HTTP calls to localhost in any non-development deployment. Phase 3 will add more HTTP calls for key distribution and allowlist management — each one will inherit this bug if the config provider isn't built first. Fix the plumbing before laying more pipe.

**2. DON'T let offline group message delivery remain broken through Phase 3.**
`ws_handler.rs` line 357 explicitly drops messages to offline group members: "Offline group-message recipients are not queued (direct messages only)." Phase 3 will distribute MLS key material via group messages. If a member is offline when a key update is sent, they will receive no update, fail to decrypt future messages, and have no way to recover without a manual re-add. The group offline queue gap is a UX problem today and a cryptographic correctness problem in Phase 3.

**3. DON'T forget to implement `plaintextCache` invalidation on MLS epoch rotation.**
`MessagesTable` has a `plaintextCache` column with a `BLOCKED(phase-3)` comment: "plaintextCache must be cleared on MLS epoch rotation." This is not a performance optimisation — it is a forward secrecy requirement. If the cache is populated by Phase 3's decryption wiring but never invalidated on epoch rotation, users will read post-rotation messages decrypted with pre-rotation cached keys. The MLS epoch rotation and the cache invalidation must be a single atomic operation, not two separate tasks that can be accidentally shipped out of order.

---

# Round 4 Feedback — Post Phase 3 Implementation

> Seven expert personas review the Phase 3 implementation directly from source code and the stated deliverables. Each reviewer focused on: `AppConfig` provider wiring, public-key allowlist (`/admin/allowlist`), `DartCryptographyService` ECIES crypto, drift `OutboundQueueTable` persistence, last-message preview, forum title encryption (self-encrypt), ephemeral help-request chat (RAISED→ACTIVE→CLOSED state machine), and MLS scaffolding (`mls_key_packages`, `mls_commits`, `MlsService` stub).

---

## 1. UX Designer — Round 4

**What improved since Round 3**

The FAB finally does something: a confirmation dialog before raising an ephemeral help request is exactly the right interaction design for a feature with irreversible side effects in a crisis-support context. The `MaterialBanner` notification for incoming help requests is idiomatic — it's dismissible, app-wide visible, and doesn't hijack navigation. Last-message preview with a relative timestamp in the conversation list is the single biggest usability improvement since Round 1; users can now tell at a glance which conversations have new activity without opening each one.

**New concerns introduced in Phase 3**

The forum title encryption produces `🔒 [encrypted title]` for every other group member's posts. This will be experienced as a broken app. A user who writes "Need urgent help — housing crisis" as a forum title will see it clearly on their own device. Every helper who opens the forum will see `🔒 [encrypted title]`. They cannot tell whether the request is urgent or routine, whether to respond or wait. The feature is technically correct (self-encrypt before the group key exists) but the UX is indistinguishable from a bug. A UI label — "Titles visible after group key is set up" — or an explicit placeholder like "🔒 Post from [author name]" that at least shows the author would reduce confusion significantly.

**[HIGH]** The `EphemeralChatScreen` "End session" button has no confirmation dialog, but the FAB that opens the session does. A user under stress who taps "End session" by accident permanently destroys an active conversation with no recovery. The asymmetry — confirm to open, no confirm to close — is a crisis-context UX failure. The close action should require the same confirmation treatment as the open.

**[HIGH]** There is no visible timer or expiry indicator on an active ephemeral session. The state machine goes RAISED→ACTIVE→CLOSED but the user never knows how long a session has been open or if it will auto-close. A helper who joins 30 minutes late has no way to know whether the session is still relevant or whether the original requester has already been helped elsewhere. Even a simple "Session open for N minutes" subtitle in `EphemeralChatScreen` would orient participants.

**[MEDIUM]** The two fallback strings — `🔒 Encrypted message` and `🔒 Decryption failed` — are shown in message bubbles without context. A user who sees `🔒 Decryption failed` in the middle of a conversation has no actionable path: can they request a re-send? Is their key corrupt? Should they contact an admin? The fallback covers the error but surfaces no recovery UX.

**[LOW]** The relative timestamp on last-message preview ("just now", "2 min ago") is the right design and the implementation mirrors the `_formatRelativeTime` pattern from forum posts — consistent language across the app is a small but meaningful trust signal for users.

**Concrete Phase 4 recommendation**

Before Phase 4 ships, replace `🔒 [encrypted title]` with `🔒 Post by [displayName]` so helpers can at least see who needs support even without the title text. The author's identity is already server-visible metadata and loses nothing by being shown. This requires one line of change in the forum list rendering and prevents the feature from shipping as a user-visible regression.

**Risk rating: MEDIUM** — The core UX is functional, but the session close asymmetry and the opaque `🔒 [encrypted title]` placeholder will erode tester and early user confidence before Phase 4 ships the group key that fixes the underlying issue.

---

## 2. Security Expert — Round 4

**What improved since Round 3**

The public key allowlist is the most important security improvement in Phase 3. Rejecting unknown keys at the server layer (403 Forbidden) means a compromised credential from outside the trusted group cannot be used to receive messages or join the routing graph. The `BOOTSTRAP_ADMIN_KEY` mechanism is the right approach for bootstrapping without a chicken-and-egg problem. Forum title encryption — even self-encrypt only — closes the plaintext title gap that was rated HIGH in Round 3; titles are no longer stored verbatim in the database or emitted in server traces. The `clearPlaintextCacheForGroup()` hook, placed at the MLS epoch rotation site, correctly identifies forward secrecy as a cache invalidation problem and creates the right seam for Phase 4.

**New concerns introduced in Phase 3**

**[HIGH]** Forum title encryption is self-encrypt: the title is encrypted with the author's own key, not a shared group key. This means only the author can decrypt it. Every other group member sees `🔒 [encrypted title]`. The server stores an opaque BYTEA blob it cannot read — which is the stated design goal — but the confidentiality property is achieved by making the content unreadable to everyone, including legitimate readers. This is not group confidentiality; it is content destruction. Until the group key exists, the only choices are: store plaintext (Round 3's HIGH risk), or store self-encrypted content that is unreadable to the group. Accepting the self-encrypt approach is fine as a temporary measure, but it must be documented as an explicitly broken state with a hard Phase 4 gate — not just a BLOCKED comment.

**[HIGH]** `BOOTSTRAP_ADMIN_KEY` as an environment variable at server startup: what is the fail-closed behavior when this variable is absent or empty? If the allowlist defaults to "allow all" on empty `BOOTSTRAP_ADMIN_KEY`, the server ships with no access control until an admin explicitly adds entries. This is a deployment footgun — a server brought up without the env var set would accept any key. The allowlist must default to "allow none" and the server should refuse to start (or log a prominent warning) when `BOOTSTRAP_ADMIN_KEY` is unset. Validate this in `config.dev.toml` and in the infra `docker-compose.yml`.

**[HIGH]** `DartCryptographyService` implements per-message ECIES (X25519+HKDF+ChaCha20-Poly1305). For a group message to 20 members, either: (a) the message is encrypted once to the server's key and the server decrypts it for routing — which means the server can read everything, violating the core design principle; or (b) the message is encrypted 20 times, once per recipient key — which means O(N) ECIES operations per send and N copies stored on the server. Neither is acceptable as the long-term group crypto model. The current implementation needs a clear annotation stating which of these is happening and an explicit `BLOCKED(mls-phase-4)` referencing the MLS replacement. If option (a) is currently the implementation, it must be highlighted as a Phase 4 blocker, not merely a performance concern.

**[MEDIUM]** The `/admin/allowlist` CRUD endpoints: the security model for who may add or remove keys is not stated in the deliverables. If any valid JWT can POST to `/admin/allowlist`, a group member can add an attacker's key without consensus. The stated design principle is "no single admin" with 2/3 consensus for member changes. The allowlist API as described gives unilateral key-add power to whoever holds a valid JWT. Even a simple "only the bootstrap admin key holder may modify the allowlist" check would be more defensible than the current implied "any authenticated user."

**[LOW]** The `mls_key_packages` and `mls_commits` database tables being established before the implementation is correct security architecture practice. Migrating schema after MLS is wired risks subtle type errors in key package serialization; having the BYTEA columns defined means the Phase 4 implementation can focus on the protocol logic rather than schema migration.

**Concrete Phase 4 recommendation**

Before Phase 4 ships MLS group key distribution, explicitly document and test the fail-closed behavior of `BOOTSTRAP_ADMIN_KEY`: an absent or empty value must cause the server to start with an empty allowlist (zero admitted keys), log `WARN: BOOTSTRAP_ADMIN_KEY is unset — allowlist is empty, all connections will be rejected` at startup, and reject all connections until a key is added via a privileged bootstrap mechanism. Add an integration test that starts the server without the env var and asserts that a connection attempt returns 403.

**Risk rating: HIGH** — Three HIGH items remain open: the ambiguous group ECIES implementation potentially routes through the server, the self-encrypt forum title is functionally broken for group confidentiality, and the `BOOTSTRAP_ADMIN_KEY` fail-open risk creates a deployment footgun.

---

## 3. Bored Senior Developer — Round 4

**What improved since Round 3**

`AppConfig` via `--dart-define` is the right fix and it's implemented correctly — a Riverpod provider that reads compile-time constants means the URL is injected at build time, not hardcoded, and can be overridden per environment without a rebuild. The persistent `OutboundQueueTable` actually being wired to `WsClient` finally closes the crash-safety gap that was flagged in Round 2 and deferred through Round 3. The `BLOCKED(mls-phase-4)` comment convention is consistently applied throughout the MLS scaffolding — every stub method, every placeholder endpoint, and every skipped validation is tagged with its migration target. This is exactly the kind of technical debt annotation that doesn't age badly.

**New concerns introduced in Phase 3**

**[HIGH]** The ephemeral chat state machine is distributed: client holds local state (RAISED/ACTIVE/CLOSED), server holds authoritative state. The spec requirement is that all transitions are idempotent, but this is an assertion about the implementation, not a property enforced by the type system or a test. If `close_session` in the server handler is not idempotent — if it calls `DELETE FROM ephemeral_sessions WHERE id = $1` and then tries to broadcast a CLOSED event to participants, a duplicate CLOSE from a reconnecting client will hit a `None` on the session lookup and either panic or return an unhandled error. Show me the test that sends CLOSE twice and asserts the second one returns 200 rather than 500.

**[MEDIUM]** `MlsService` is a stub returning placeholder values. The Riverpod provider that injects it — presumably `mlsServiceProvider` — will be called by `WsClient` or `ChatScreen` during Phase 4. When a stub method returns `null` or an empty `Uint8List`, the caller's handling of that return value sets the behavior for the actual MLS implementation. If the stub silently returns garbage that the caller ignores, the Phase 4 MLS implementation will discover its integration contract only at runtime. Stubs should either `throw UnimplementedError()` to force callers to handle the not-ready case, or return typed sentinel values with explicit contracts.

**[MEDIUM]** `DartCryptographyService` lives in `client/lib/crypto/`. The backend has its own crypto wrappers in `backend/src/crypto/`. Phase 4's MLS implementation will need to share key package serialization formats between client and server. If the two crypto modules independently derive their serialization (one in Dart, one in Rust), the first cross-platform decryption test will fail because the byte layouts don't match. The `shared/src/lib.rs` serde types are the right place to pin the MLS key package wire format — establish that now before two implementations diverge.

**[LOW]** The `clearPlaintextCacheForGroup()` method name is precise and self-documenting. Whoever named it understood that "clear cache" without a scope is a footgun — the group parameter ensures only the relevant epoch's cache is invalidated, not the entire message store. Small win.

**Concrete Phase 4 recommendation**

Write a `MockMlsService` that throws `UnimplementedError` for every stub method and make it the default in tests. This forces every Phase 4 feature that touches MLS to explicitly handle the "MLS not ready" case rather than silently receiving null. The mock should be in `test/mocks/` and re-exported by the test harness so all widget tests that touch crypto automatically get the strict version.

**Risk rating: MEDIUM** — The architecture is on the right track but three fault lines need attention before Phase 4 complexity lands on them: the unverified idempotency of the state machine, the ambiguous stub contract for `MlsService`, and the risk of Dart/Rust serialization divergence on key packages.

---

## 4. Senior Architect — Round 4

**What improved since Round 3**

The `AppConfig` provider resolves the hardcoded localhost issue that was a DON'T in Round 3 and had survived from Phase 1. The persistent outbound queue finally closes the architecture gap that was flagged in Round 2's consolidated recommendations and deferred twice — `OutboundQueueTable` with `queuedAt` and `attempts` columns is the right schema for a retry-with-backoff queue. The public key allowlist enforcement at the WS connection layer (before JWT validation reaches routing logic) is the correct architectural placement — it gates the trust domain at the perimeter rather than deep in the request handler. MLS scaffolding tables (`mls_key_packages`, `mls_commits`) being defined before the implementation is the correct migration-first architecture approach.

**New concerns introduced in Phase 3**

**[HIGH]** The offline group message delivery gap — flagged as a DON'T in Round 3 — is still open, and Phase 3 has made it architecturally worse. The `mls_commits` table implies that MLS `Commit` and `Welcome` messages will be distributed as group messages. If a member is offline when a `Commit` is broadcast (e.g., during an ephemeral chat key rotation), they miss the epoch transition. They cannot decrypt subsequent group messages and have no recovery path short of being manually re-added by the group admin. The MLS protocol defines a recovery mechanism (re-joining via a new `Welcome`), but the architecture for triggering it — "member comes online, detects epoch mismatch, requests re-invite" — is not present in the current design. This must be designed before Phase 4 wires actual MLS commits, not discovered when the first member misses a key rotation.

**[HIGH]** The ephemeral chat sessions live in server-side state that is not persisted to PostgreSQL. The known gaps note "Redis session store — currently in-memory HashMap — single-node only." The RAISED→ACTIVE→CLOSED state machine is entirely lost on server restart. If the server restarts while a session is ACTIVE, the clients hold local ACTIVE state indefinitely. They will attempt to send messages that the server routes to a session that no longer exists. There is no timeout mechanism on the client side to detect server-side session loss. The state machine spec says "the server must handle duplicate CLOSE or DELETE events without corrupting state" — but a server restart isn't a duplicate event; it's a state erasure. Persist ephemeral session state to PostgreSQL with a TTL, even if the messages themselves are not persisted.

**[MEDIUM]** The `/admin/allowlist` CRUD endpoints represent a new privileged API surface that sits outside the existing WebSocket routing architecture. All other sensitive operations (message relay, key package upload) go through the authenticated WS connection. The allowlist admin API is a REST endpoint using what authorization mechanism? If it shares the same JWT validation middleware as the forum and profile endpoints, then any group member with a valid session JWT can modify the allowlist. The allowlist admin API should require a separate, higher-privilege credential — or at minimum, verify that the JWT holder's public key is in a designated admin set.

**[LOW]** The `attempts` column in `OutboundQueueTable` is the right foundation for exponential backoff. Pairing it with a `lastAttemptedAt` timestamp would allow the client to implement delay-based retry without storing the backoff state in memory — particularly important for messages queued across app restarts.

**Concrete Phase 4 recommendation**

Design the MLS epoch recovery flow before writing the `openmls` integration: define what happens when `ws_handler.rs` receives a message from a client whose stored epoch is behind the current group epoch. The server should detect the mismatch (epoch ID in message envelope vs. current epoch in `mls_commits`), reject the message with a structured error code (e.g., `4010 EPOCH_MISMATCH`), and the client should respond by requesting a new `Welcome` from the group. This flow must be a first-class design document before Phase 4 ships — retrofitting epoch recovery onto a running MLS implementation is the hardest category of distributed systems bug.

**Risk rating: HIGH** — Two HIGH architectural gaps remain that Phase 4 will collide with directly: offline members missing MLS epoch transitions have no recovery path, and ephemeral session state erasure on server restart leaves clients in an inconsistent state indefinitely.

---

## 5. Normal Programmer — Round 4

**What improved since Round 3**

`AppConfig` is a clean implementation — `--dart-define=SERVER_URL=https://...` at build time, read via `String.fromEnvironment()` in the provider, with a sensible localhost default for development. No more `grep -r localhost` hunts before deployment. The BLOCKED comment convention has been consistently applied to the MLS scaffolding and the comments are now specific enough to be actionable: `BLOCKED(mls-phase-4): replace stub with openmls KeyPackage generation` tells the next developer exactly what code to write, not just that something is missing.

**New concerns introduced in Phase 3**

**[MEDIUM]** `🔒 Encrypted message` vs `🔒 Decryption failed` — as a developer reading the code that produces these strings, what is the difference? The first presumably appears when a message is received but decryption is not yet possible (e.g., key not loaded), the second when decryption was attempted and produced an error. But these look identical to the user and their code paths are presumably different. Name the constants explicitly: `kMessagePendingDecryption` and `kDecryptionErrorPlaceholder`, add a one-line comment at each constant definition explaining when it appears, and centralise them in a `crypto_strings.dart` constants file so a future developer doesn't add a third variant by copy-pasting.

**[MEDIUM]** `DartCryptographyService` is named for its implementation technology rather than its role. When Phase 4 adds the `openmls`-backed group crypto, there will be at least two implementations: `DartCryptographyService` (ECIES 1:1) and something like `MlsCryptographyService` (group). The `CryptoService` interface is the right abstraction, but the Riverpod provider selection logic — "use MLS service for group messages, ECIES for DMs" — does not yet exist. Adding this dispatch logic as an afterthought when both services are simultaneously live will be messy. Design the provider selection strategy now: a `groupCryptoServiceProvider` and a `dmCryptoServiceProvider` would make the dispatch explicit at the callsite.

**[MEDIUM]** The `EphemeralChatScreen` is a new screen. Does it use the same `WsClient` singleton that `ChatScreen` uses? If so, `_handleRawMessage` in `WsClient` now needs to demultiplex three message types: group messages, DMs, and ephemeral chat messages. If that handler is a growing `if/else` or `switch`, it will become the most-edited file in the codebase over the next two phases. A handler registry — `Map<String, Function(Map<String, dynamic>)>` keyed by message type — would allow each screen to register and deregister its handler on mount/unmount rather than requiring a central dispatcher to know about every screen.

**[LOW]** The `MaterialBanner` for ephemeral chat notifications is the right primitive choice. It requires no additional package dependency and is natively accessible, which rounds out the accessibility story for this feature. Good call.

**Concrete Phase 4 recommendation**

Before Phase 4 adds MLS message handling to `_handleRawMessage`, refactor the method to use a handler registry pattern. Each message type (`chat`, `ephemeral`, `mls_commit`, `mls_welcome`) registers a handler function. `_handleRawMessage` dispatches by `message['type']` to the registered handler, logging an unhandled-type warning for anything not registered. This is a 50-line refactor now that will prevent a 500-line dispatcher from emerging organically as Phase 4 adds MLS message types.

**Risk rating: MEDIUM** — The code is readable and the BLOCKED comments tell a coherent story. The main Phase 4 risk is that two simultaneous crypto service implementations (ECIES and MLS) with no dispatch strategy will produce subtle "wrong service selected" bugs that are invisible to the type checker.

---

## 6. QA Champion — Round 4

**What improved since Round 3**

The confirmation dialog before raising an ephemeral help request means the "accidental flag raise" path is now explicitly gated — a test can assert that the flag is not raised until the confirmation is accepted. The persistent `OutboundQueueTable` means delivery tests can now assert "message is in the queue after send" and "message is removed from the queue after ACK" as durable state assertions, not race-prone in-memory checks. `AppConfig` via `--dart-define` means integration tests can target a local test server at `http://localhost:8000` without modifying source code.

**New concerns introduced in Phase 3**

**[HIGH]** The ephemeral chat state machine has no test coverage for invalid transitions. A test matrix is required: RAISED→RAISED (double-raise from same client), RAISED→CLOSED (close before anyone joins), ACTIVE→RAISED (re-raise while active), CLOSED→ACTIVE (late join after close), CLOSED→CLOSED (duplicate CLOSE from reconnect). The spec says all transitions are idempotent — that means "CLOSED→CLOSED returns 200 and does nothing," not "CLOSED→CLOSED returns 500." Without these tests, a reconnecting client that replays its last event (CLOSE) will trigger an unhandled state machine error in production.

**[HIGH]** `DartCryptographyService.decrypt()` returns a fallback placeholder string on failure rather than throwing. This makes negative-path testing deceptively easy: a test that calls `decrypt()` with a wrong key and asserts the result is not null will pass — but it's asserting the wrong property. The actual security property is "decrypt with wrong key does NOT return the plaintext." The fallback pattern makes it structurally impossible to write a test that fails when the wrong key accidentally decrypts a message. Add a property-based test: generate a random keypair B distinct from keypair A, encrypt a message to A, attempt to decrypt with B, assert the result is `kDecryptionErrorPlaceholder` (not the original plaintext, and not a successful decryption).

**[MEDIUM]** Outbound queue retry ordering: the `OutboundQueueTable` retries on reconnect. Is the drain ordered by `queuedAt ASC` (FIFO)? If the retry implementation issues all pending sends concurrently (a `Future.wait` over all queued messages), the server will receive them in non-deterministic order. A test that queues messages A, B, C and asserts the recipient sees them in order A, B, C will be flaky unless the drain is explicitly sequential.

**[MEDIUM]** The allowlist `403 Forbidden` for unknown public keys: at what point in the request lifecycle is this check performed? If the check is in a middleware that runs before JWT validation, an unauthenticated request with an unknown public key returns 403. An unauthenticated request with a known public key but no JWT returns 401. This ordering is observable by an attacker probing the allowlist: try known vs. unknown keys unauthenticated, observe 401 vs. 403, enumerate the allowlist without credentials. A test that sends an unauthenticated request with a known key vs. an unknown key and asserts both return 401 (not distinguishing based on allowlist membership) would verify the check order is correct.

**[LOW]** The `AppDatabase.forTesting()` constructor now enables an `OutboundQueueTable` persistence test that was previously blocked by the in-memory queue. Writing this test is a bounded, well-defined task: insert a message into `OutboundQueueTable`, simulate an app restart (re-initialize the DB), assert the message is still present, drain the queue, assert it is gone. This test would have caught the Round 2 and Round 3 persistence gap before it was filed as a finding.

**Concrete Phase 4 recommendation**

Write the ephemeral state machine transition matrix as a parameterized test before Phase 4 adds any features that depend on the session lifecycle. Define an enum of valid and invalid transitions, assert valid ones return the correct next state, and assert invalid ones return an idempotent response (same state, 2xx) rather than an error. Run these tests against the server's `EphemeralSession` handler directly (not through the WebSocket), so they are fast and deterministic.

**Risk rating: HIGH** — The decrypt-fallback pattern structurally prevents the most important security property test from being written, and the state machine has no transition coverage. Both gaps will allow correctness regressions to ship silently.

---

## 7. Performance Tester — Round 4

**What improved since Round 3**

The persistent outbound queue with the `attempts` counter is a meaningful performance improvement for reconnect behaviour: exponential backoff can be computed from `attempts` without in-memory state, which means the backoff schedule survives app restarts. `AppConfig` centralises the server URL, eliminating the possibility of a test accidentally sending traffic to localhost and measuring localhost latency instead of network latency. The `mls_key_packages` and `mls_commits` tables use BYTEA columns — compact binary storage rather than JSON text — which is the right choice for cryptographic material that will be fetched frequently in Phase 4.

**New concerns introduced in Phase 3**

**[HIGH]** `DartCryptographyService` performs X25519 key agreement + HKDF + ChaCha20-Poly1305 on the Dart main isolate. For a group of 20 members, a group message send requires 20 independent ECIES operations (one per recipient key). On a 2019 mid-range Android device, a single X25519 key agreement in Dart takes approximately 2–5ms. Twenty operations is 40–100ms of synchronous crypto on the UI thread per outbound group message. The compose bar will freeze noticeably on every send. This is not a Phase 4 problem — it is a Phase 3 problem that is already in production code. Move encryption to `compute()` (for one-shot operations) or a long-lived `Isolate` with a port (for streaming encryption of large messages).

**[MEDIUM]** The persistent outbound queue retry-on-reconnect drains all pending messages when the WS connection is re-established. If a user was offline during an active group conversation and has 50 queued outbound messages, all 50 are drained on reconnect. Each drain step requires a `DartCryptographyService.encrypt()` call (if messages are queued as plaintext and encrypted on send) or a direct WS send (if messages are queued pre-encrypted). If the former, 50 reconnect sends = 50 × 20 = 1,000 ECIES operations in a burst on the UI isolate. The drain must be rate-limited (e.g., 5 messages/second with jitter) and must run on a background isolate.

**[MEDIUM]** The `/admin/allowlist` endpoints perform a database read on every key verification. If allowlist checking occurs on every WS message (not just at connection establishment), a group of 20 members sending at 1Hz generates 20 allowlist DB reads per second. The allowlist changes rarely — add/remove member events. Cache the allowlist in-process (an `Arc<RwLock<HashSet<PublicKeyBytes>>>`) and invalidate only on admin write operations. The current architecture does not indicate where the allowlist check is positioned in the message handling pipeline; if it is per-message rather than per-connection, this is an immediate performance issue.

**[LOW]** The `MaterialBanner` for ephemeral chat notifications uses `AnimatedSwitcher` with a `SizeTransition`. The animation frame rate is independent of the message stream and does not trigger message list rebuilds. This is the correct Flutter performance pattern for a notification overlay — it was called out as a potential issue in Round 3 for the `ConnectionBanner` and has been applied consistently here.

**Concrete Phase 4 recommendation**

Before Phase 4 wires MLS key distribution — which involves key package fetches for all N members — define a `POST /mls/key-packages/batch` endpoint that accepts a list of user IDs and returns all their current key packages in a single response. Phase 4's `Welcome` operation requires key packages for every existing member. N individual `GET /mls/key-packages/:id` requests is O(N) round-trips; a batch endpoint is O(1). Building the batch endpoint after the MLS client is already coded against individual endpoints requires a client-side refactor. Design the API contract now.

**Risk rating: HIGH** — The synchronous ECIES encryption on the UI isolate for group messages is an immediately measurable performance regression in Phase 3 production code, not a future concern. Twenty operations per group send will produce visible UI jank on mid-range hardware at the target deployment context.

---

## Phase 4 Recommendations (consolidated from Round 4)

### Top 3 DOs for Phase 4

**1. DO move all ECIES encryption off the UI isolate before Phase 4 adds MLS key operations.**
`DartCryptographyService` currently runs X25519+HKDF+ChaCha20-Poly1305 on the Dart main isolate. For a 20-member group, this is 20 key-encapsulation operations per send — 40–100ms of crypto that freezes the compose bar. Wrapping `DartCryptographyService.encrypt()` in `compute()` is a one-afternoon change. Phase 4's MLS operations (tree hashing, ratchet updates) are more expensive than ECIES per-message. If the crypto is still on the UI isolate when MLS lands, every group message send will produce a perceptible freeze on the target hardware.

**2. DO design the MLS epoch recovery flow before writing the `openmls` integration.**
An offline member who misses a `Commit` message cannot decrypt subsequent group messages and has no recovery path in the current architecture. Define the full recovery sequence — client detects epoch mismatch on receive, sends `4010 EPOCH_MISMATCH` error to server, server triggers a re-invite `Welcome` from the group epoch holder — as a state diagram and write it into `docs/ephemeral-state-machine.md` (or a new `docs/mls-epoch-recovery.md`) before any Phase 4 MLS code is written. The MLS spec defines this mechanism; the implementation must reflect it.

**3. DO persist ephemeral session state to PostgreSQL with a TTL before Phase 4 ships any ephemeral chat feature that users depend on.**
The RAISED→ACTIVE→CLOSED state machine is entirely in-memory and is erased on server restart. A server reboot during a crisis session leaves clients stuck in ACTIVE with no timeout mechanism. Persisting session state (session ID, raiser ID, participants, state, created_at) to a `ephemeral_sessions` PostgreSQL table with a `expires_at` column and a background cleanup task closes this gap with a single well-scoped migration.

### Top 3 DON'Ts for Phase 4

**1. DON'T ship `BOOTSTRAP_ADMIN_KEY` with fail-open behavior.**
An absent or empty `BOOTSTRAP_ADMIN_KEY` must cause the server to start with an empty allowlist that rejects all connections, not an allowlist that accepts all keys. The current behavior is not specified in the deliverables, which means it was probably not tested. An integration test that starts the server without `BOOTSTRAP_ADMIN_KEY` and asserts that all connection attempts return 403 must exist before Phase 4 ships to any non-development environment.

**2. DON'T let `MlsService` stubs return `null` or empty bytes without a contract.**
Every stub method in `MlsService` that returns `null`, an empty `Uint8List`, or a placeholder value is a silent contract violation waiting to become a runtime bug when Phase 4 replaces the stub. Change all stub returns to `throw UnimplementedError('MlsService.${method}: not yet implemented — see BLOCKED(mls-phase-4)')`. This converts silent misbehavior into an explicit error that surfaces immediately in tests, rather than a subtle decryption failure that surfaces in production.

**3. DON'T wire the Phase 4 MLS group crypto without first resolving whether group message ECIES currently routes through the server key.**
If `DartCryptographyService` currently encrypts group messages to the server's X25519 public key (option a — the server can read everything), this is an active security regression, not a future gap. If it encrypts to each recipient's key individually (option b — N copies per message), the server storage model is already incorrect for MLS. Either way, the current group ECIES design must be audited and explicitly documented before MLS is layered on top of it. Building MLS on an undocumented group crypto assumption is how subtle "the server was always decrypting these" bugs survive into production.
