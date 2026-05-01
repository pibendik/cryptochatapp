# Key Rotation & Emergency Revocation

This document is the operational runbook for handling device loss and key rotation
in the cryptochatapp group. Read it *before* you need it.

---

## Scenario A — Self-rotation (new phone / reinstall)

**Who performs this:** The user who got a new device, while their old account/session still exists.

### Steps

1. **Install the app on the new device.**
2. Open **My Profile → Security → Rotate my key**.
3. The app generates a fresh Ed25519 + X25519 keypair and stores it in the OS
   keychain of the new device.
4. Tap **Rotate my key** and optionally enter a label (e.g. "Alice's new iPhone").
5. The app calls `POST /keys/rotate` with the new public key, authenticated via
   the existing session token from the old key.
6. You see: **"Waiting for 2 approvals from group members."** along with a
   **Proposal ID** and your new key fingerprint.
7. **Tell your group** (out-of-band: Signal, in-person, etc.) that you have a new key
   and share your new fingerprint so peers can verify it.
8. Two existing group members go to **My Profile → Security → View Proposals**
   (p4-consensus) and approve the rotation.
9. Once approved, the server swaps your allowlist entry and broadcasts
   `{ "type": "key_rotated" }` to the group.
10. Tap **Clear local data & re-authenticate** on the new device. The app takes you
    to the onboarding QR screen with the new keypair pre-loaded. Re-authenticate
    against the server — the rotation is now complete.

### What happens under the hood

- The old key stays active until the proposal is approved (you remain reachable).
- After approval, the old key is removed from the allowlist; the old device can no
  longer authenticate.
- MLS group membership still needs a separate `Welcome` operation from the group
  admin to re-add you with the new key package.

---

## Scenario B — Emergency revocation (phone stolen / lost)

**Who performs this:** Any *other* group member, not the person who lost their phone.

> ⚠️ Do this as quickly as possible after the device is known to be compromised.

### Steps

1. Open **My Profile → Security → Report compromised key**.
2. Find the member whose device was compromised in the contacts list.
3. Tap **Report compromised** next to their name.
4. Confirm the dialog: *"Are you sure? This will lock out [Name] until they attend
   a new key-signing ceremony with a fresh device."*
5. The app calls `POST /keys/emergency-revoke` with the target key hex.
6. The screen shows **"Vote open"** — a second group member must also approve
   (via **View Proposals**) for the key to actually be removed.
7. Once 2 approvals are recorded, the key is removed from the allowlist
   and no further authentication is possible with it.
8. Notify the affected person (out-of-band) that their key has been revoked.

### What the affected person must do

1. **Get a new device** (or factory reset / secure-erase the old one if recovered).
2. Install the app and generate a fresh keypair (it happens automatically on first launch).
3. **Attend a new key-signing ceremony** — either:
   - **In-person:** meet with all/most group members; everyone scans your new QR code.
   - **Remote re-ceremony:** join a video call, display your QR code on screen, each
     member scans it from the screen.
4. The group admin adds the new public key package to the server allowlist.
5. The MLS group admin performs a `Welcome` to re-add you with the new key.

---

## Proposal status reference

| Status  | Meaning |
|---------|---------|
| `OPEN`  | Proposal exists; waiting for 2 approvals |
| `APPROVED` | Threshold reached; action was applied |
| `REJECTED` | Majority voted against |

---

## Security notes

- **The server stores ciphertext only.** The rotation proposal (`member_proposals`
  table) contains only public keys and action type — no private key material.
- **Old key stays active until approved.** If you initiated a self-rotation and
  the old device is lost before approval, treat this as Scenario B and have
  a peer also start an emergency revocation for the old key.
- **Two-member threshold.** One compromised member cannot unilaterally lock out
  another. Both ROTATE and REMOVE require exactly 2 independent approvals.
- **MLS forward secrecy.** After a key is rotated/removed, the group admin
  should perform an MLS `Remove` + `Add` cycle so the new epoch keys are
  inaccessible to the old key — even if the private key was extracted.

---

*See also: `docs/key-ceremony.md` for the initial signing party runbook.*
