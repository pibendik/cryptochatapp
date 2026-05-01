use std::env;

/// Application configuration loaded from environment variables.
#[derive(Debug, Clone)]
pub struct Config {
    /// PostgreSQL connection URL (DATABASE_URL)
    pub database_url: String,
    /// Address to bind the HTTP server to (SERVER_ADDR, default: 0.0.0.0:8080)
    pub server_addr: String,
    /// Explicit CORS origin allowlist (ALLOWED_ORIGINS, comma-separated).
    ///
    /// Example: `https://chat.example.com,tauri://localhost`
    /// Defaults to an empty list (deny all cross-origin requests) if not set.
    pub allowed_origins: Vec<String>,
    /// Challenge TTL in seconds (CHALLENGE_TTL_SECS, default: 60)
    pub challenge_ttl_secs: u64,
}

impl Config {
    /// Load configuration from environment, panicking on missing required vars.
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL")
                .expect("DATABASE_URL must be set"),
            server_addr: env::var("SERVER_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:8080".to_string()),
            allowed_origins: env::var("ALLOWED_ORIGINS")
                .unwrap_or_default()
                .split(',')
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(str::to_string)
                .collect(),
            challenge_ttl_secs: env::var("CHALLENGE_TTL_SECS")
                .unwrap_or_else(|_| "60".to_string())
                .parse()
                .expect("CHALLENGE_TTL_SECS must be a valid integer"),
        }
    }
}
