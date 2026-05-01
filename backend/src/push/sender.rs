//! `PushSender` — issues silent wake-only pushes to APNs and FCM.
//!
//! Privacy guarantee: no message content, sender info, or badge counts are
//! ever included in the push payload.  Apple/Google only see that an app was
//! woken at a given time for a given device token.

use std::sync::Arc;

use reqwest::Client;
use serde_json::json;
use thiserror::Error;
use tracing::{instrument, warn};

#[derive(Debug, Error)]
pub enum PushError {
    #[error("reqwest error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("APNs rejected push: status {status}, body: {body}")]
    ApnsRejected { status: u16, body: String },
    #[error("FCM rejected push: status {status}, body: {body}")]
    FcmRejected { status: u16, body: String },
    #[error("push disabled: no credentials configured for platform '{0}'")]
    Disabled(String),
}

/// Shared push-notification sender.  Cheaply cloneable via inner `Arc`.
#[derive(Clone, Debug)]
pub struct PushSender(Arc<Inner>);

#[derive(Debug)]
struct Inner {
    http: Client,
    fcm_server_key: Option<String>,
    apns_key_path: Option<String>,
    apns_key_id: Option<String>,
    apns_team_id: Option<String>,
    apns_bundle_id: Option<String>,
}

impl PushSender {
    /// Build from environment variables.  All fields are optional; if a
    /// platform's credentials are absent, `send_silent_wake` returns
    /// `PushError::Disabled` for that platform (logged as a warning, not an
    /// error — the message is still stored in the offline queue).
    pub fn from_env() -> Self {
        let inner = Inner {
            http: Client::builder()
                .use_rustls_tls()
                .build()
                .expect("failed to build reqwest client"),
            fcm_server_key: std::env::var("FCM_SERVER_KEY").ok().filter(|v| !v.is_empty()),
            apns_key_path: std::env::var("APNS_KEY_PATH").ok().filter(|v| !v.is_empty()),
            apns_key_id: std::env::var("APNS_KEY_ID").ok().filter(|v| !v.is_empty()),
            apns_team_id: std::env::var("APNS_TEAM_ID").ok().filter(|v| !v.is_empty()),
            apns_bundle_id: std::env::var("APNS_BUNDLE_ID").ok().filter(|v| !v.is_empty()),
        };
        PushSender(Arc::new(inner))
    }

    /// Send a silent wake-only push to the given device token.
    ///
    /// * APNs: `content-available=1`, `apns-push-type=background`, `apns-priority=5`.
    ///         Body: `{"aps":{"content-available":1}}`.
    /// * FCM:  Legacy endpoint, `data`-only — no `notification` key.
    ///         Body: `{"to":"<token>","data":{"wake":"1"}}`.
    ///
    /// Returns an error if credentials for the platform are not configured or
    /// if the remote service rejects the request.  Callers should fire-and-forget
    /// and log the error rather than propagating it.
    #[instrument(skip(self), fields(platform, token = %&token[..token.len().min(12)]))]
    pub async fn send_silent_wake(&self, token: &str, platform: &str) -> Result<(), PushError> {
        match platform {
            "apns" => self.send_apns(token).await,
            "fcm" => self.send_fcm(token).await,
            other => Err(PushError::Disabled(other.to_string())),
        }
    }

    async fn send_fcm(&self, token: &str) -> Result<(), PushError> {
        let server_key = self
            .0
            .fcm_server_key
            .as_deref()
            .ok_or_else(|| PushError::Disabled("fcm".into()))?;

        // Legacy FCM endpoint — data-only, no "notification" key.
        let body = json!({
            "to": token,
            "data": { "wake": "1" }
        });

        let resp = self
            .0
            .http
            .post("https://fcm.googleapis.com/fcm/send")
            .header("Authorization", format!("key={server_key}"))
            .json(&body)
            .send()
            .await?;

        let status = resp.status().as_u16();
        if status != 200 {
            let body = resp.text().await.unwrap_or_default();
            return Err(PushError::FcmRejected { status, body });
        }
        Ok(())
    }

    async fn send_apns(&self, token: &str) -> Result<(), PushError> {
        let bundle_id = self
            .0
            .apns_bundle_id
            .as_deref()
            .ok_or_else(|| PushError::Disabled("apns".into()))?;

        // Verify all required APNs credentials are present before building the request.
        if self.0.apns_key_path.is_none()
            || self.0.apns_key_id.is_none()
            || self.0.apns_team_id.is_none()
        {
            return Err(PushError::Disabled("apns".into()));
        }

        let url = format!("https://api.push.apple.com/3/device/{token}");

        // Payload: minimal APNs background push.
        let body = json!({ "aps": { "content-available": 1 } });

        let resp = self
            .0
            .http
            .post(&url)
            .header("apns-push-type", "background")
            .header("apns-priority", "5")
            .header("apns-topic", bundle_id)
            .json(&body)
            .send()
            .await?;

        let status = resp.status().as_u16();
        // APNs returns 200 on success.
        if status != 200 {
            let body = resp.text().await.unwrap_or_default();
            return Err(PushError::ApnsRejected { status, body });
        }
        Ok(())
    }
}

/// Fire-and-forget helper: spawn a task that sends a silent wake push and
/// logs any error.  Message storage is never blocked on push success.
pub fn fire_and_forget(sender: PushSender, token: String, platform: String) {
    tokio::spawn(async move {
        if let Err(e) = sender.send_silent_wake(&token, &platform).await {
            warn!(platform, "silent push failed (non-fatal): {e}");
        }
    });
}
