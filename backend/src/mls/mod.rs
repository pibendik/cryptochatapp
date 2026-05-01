// BLOCKED(mls-phase-4): openmls crate integration — currently stores/forwards opaque blobs only.
//
// This module scaffolds the MLS epoch-based key rotation API surface so Phase 4
// can slot in the real openmls implementation without touching the route structure.
//
// Phase 4 work required here:
//   - Replace opaque blob storage with openmls KeyPackage / Commit validation
//   - Apply Commit messages atomically (MLS epoch transition must be atomic)
//   - Integrate X3DH / Double Ratchet for the 1:1 DM path

pub mod handlers;
