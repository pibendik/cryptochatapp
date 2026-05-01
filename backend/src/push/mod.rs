//! Silent push notification module.
//!
//! Sends wake-only push notifications to offline users via APNs (iOS) and
//! FCM (Android).  The payload is intentionally empty — no message content,
//! sender name, or count is ever sent to Apple/Google servers.
//!
//! APNs payload:  `{"aps":{"content-available":1}}`
//! FCM payload:   `{"to":"<token>","data":{"wake":"1"}}`  (no "notification" key)
//!
//! When the app wakes it opens a WebSocket and drains `GET /messages/pending`.

pub mod handlers;
pub mod sender;
