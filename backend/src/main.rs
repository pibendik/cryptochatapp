// Scaffold — many types are defined but not yet wired to handlers.

use std::{net::SocketAddr, sync::Arc, time::{Duration, Instant}};

use axum::{
    extract::{FromRef, State},
    http::{header, HeaderValue, Method, StatusCode},
    response::{IntoResponse, Response},
    routing::{patch, post, put},
    Json, Router,
};
use rand::RngCore;
use serde_json::json;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use tracing::instrument;

mod auth;
mod config;
mod db;
mod error;
mod forum;
mod models;
mod profiles;
mod relay;

use auth::challenge::{
    issue_challenge, verify_challenge, spawn_challenge_cleanup, spawn_session_cleanup,
    ChallengeRequest, ChallengeStore, SessionEntry, SessionStore,
    VerifyRequest, VerifyResponse,
};
use models::user::User;
use relay::ws_handler::{ws_handler, ConnectionMap, OfflineQueue};

/// Shared application state threaded through all handlers.
#[derive(Clone)]
struct AppState {
    db: db::DbPool,
    challenges: ChallengeStore,
    sessions: SessionStore,
    connections: ConnectionMap,
    offline_queue: OfflineQueue,
    config: Arc<config::Config>,
}

/// Allow the middleware extractor to pull SessionStore out of AppState.
impl FromRef<AppState> for SessionStore {
    fn from_ref(state: &AppState) -> Self {
        state.sessions.clone()
    }
}

impl FromRef<AppState> for ConnectionMap {
    fn from_ref(state: &AppState) -> Self {
        state.connections.clone()
    }
}

impl FromRef<AppState> for OfflineQueue {
    fn from_ref(state: &AppState) -> Self {
        state.offline_queue.clone()
    }
}

impl FromRef<AppState> for db::DbPool {
    fn from_ref(state: &AppState) -> Self {
        state.db.clone()
    }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

#[tokio::main]
async fn main() {
    // Load .env (ignore errors if the file is absent — env vars may be set directly).
    let _ = dotenvy::dotenv();

    // Structured logging.
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=debug".into()),
        )
        .init();

    let cfg = Arc::new(config::Config::from_env());
    tracing::info!(addr = %cfg.server_addr, "starting cryptochatapp backend");

    // Database pool.
    let pool = db::create_pool(&cfg.database_url)
        .await
        .expect("failed to create database pool");

    tracing::info!("database pool established");

    db::run_migrations(&pool)
        .await
        .expect("DB migrations failed");

    tracing::info!("database migrations applied");

    let state = AppState {
        db: pool,
        challenges: ChallengeStore::new(),
        sessions: SessionStore::new(),
        connections: ConnectionMap::default(),
        offline_queue: OfflineQueue::default(),
        config: cfg.clone(),
    };

    // Start background cleanup tasks.
    spawn_challenge_cleanup(state.challenges.clone());
    spawn_session_cleanup(state.sessions.clone());

    // Cleanup task: delete acknowledged messages after 1 minute
    // Average server-side message lifetime: seconds to minutes
    {
        let pool = state.db.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(60)).await;
                let _ = sqlx::query(
                    "DELETE FROM messages WHERE acknowledged_at < NOW() - INTERVAL '1 minute'"
                )
                .execute(&pool)
                .await;
            }
        });
    }

    // Cleanup task: delete resolved or old forum posts after 30 days
    {
        let pool = state.db.clone();
        tokio::spawn(async move {
            loop {
                tokio::time::sleep(Duration::from_secs(3600)).await; // hourly
                let _ = sqlx::query(
                    "DELETE FROM forum_posts WHERE resolved = true OR created_at < NOW() - INTERVAL '30 days'"
                )
                .execute(&pool)
                .await;
            }
        });
    }

    let app = build_router(state);

    let addr: SocketAddr = cfg
        .server_addr
        .parse()
        .expect("SERVER_ADDR is not a valid socket address");

    tracing::info!(%addr, "listening");
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind");

    axum::serve(listener, app)
        .await
        .expect("server error");
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

fn build_router(state: AppState) -> Router {
    let origins: Vec<HeaderValue> = state
        .config
        .allowed_origins
        .iter()
        .filter_map(|o| o.parse().ok())
        .collect();

    let cors = CorsLayer::new()
        .allow_origin(origins)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::PATCH])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION]);

    use axum::routing::get;
    Router::new()
        // Health check — no auth required.
        .route("/health", get(health_handler))
        // Auth routes.
        .route("/auth/challenge", post(challenge_handler))
        .route("/auth/verify", post(verify_handler))
        // Profile routes.
        .route("/users/me/profile", get(profiles::handlers::get_own_profile))
        .route("/users/me/profile", put(profiles::handlers::update_profile))
        .route("/users/:id/profile", get(profiles::handlers::get_profile))
        .route("/groups/me/members", get(profiles::handlers::list_group_members))
        // Message ACK routes — sealed-envelope model.
        .route("/messages/pending", get(relay::ack_handler::get_pending_messages))
        .route("/messages/:id/ack", post(relay::ack_handler::ack_message))
        // Forum routes — require auth.
        .route("/forum/posts", post(forum::handlers::create_post))
        .route("/forum/posts", get(forum::handlers::list_posts))
        .route("/forum/posts/:id/resolve", patch(forum::handlers::resolve_post))
        // WebSocket relay — auth via first message, not URL query param.
        .route("/ws", get(ws_handler::<AppState>))
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(state)
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// GET /health — simple liveness probe.
async fn health_handler() -> impl IntoResponse {
    (StatusCode::OK, Json(json!({ "status": "ok" })))
}

/// POST /auth/challenge — issue an Ed25519 challenge.
#[instrument(skip(state))]
async fn challenge_handler(
    State(state): State<AppState>,
    Json(body): Json<ChallengeRequest>,
) -> impl IntoResponse {
    let ttl = Duration::from_secs(state.config.challenge_ttl_secs);
    let response = issue_challenge(&state.challenges, &body.public_key, ttl);
    (StatusCode::OK, Json(response))
}

/// POST /auth/verify — verify an Ed25519 challenge response, upsert user, issue session token.
#[instrument(skip(state))]
async fn verify_handler(
    State(state): State<AppState>,
    Json(body): Json<VerifyRequest>,
) -> Response {
    // 1. Verify the signature over the stored challenge bytes.
    let public_key = match verify_challenge(&state.challenges, &body.challenge_id, &body.signature)
    {
        Ok(pk) => pk,
        Err(reason) => {
            return (StatusCode::UNAUTHORIZED, Json(json!({ "error": reason }))).into_response();
        }
    };

    // 2. Upsert the user in the database.
    let user = match User::upsert(
        &state.db,
        &public_key,
        &body.encryption_public_key,
        &body.display_name,
    )
    .await
    {
        Ok(u) => u,
        Err(e) => {
            tracing::error!("DB upsert failed: {}", e);
            return (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "error": "database error" })),
            )
                .into_response();
        }
    };

    // 3. Mint a random 32-byte session token and register it.
    let mut token_bytes = [0u8; 32];
    rand::thread_rng().fill_bytes(&mut token_bytes);
    let session_token = hex::encode(token_bytes);

    {
        let mut sessions = state.sessions.0.lock().expect("session store poisoned");
        sessions.insert(session_token.clone(), SessionEntry { user_id: user.id, created_at: Instant::now() });
    }

    tracing::info!(user_id = %user.id, "session created");
    (
        StatusCode::OK,
        Json(VerifyResponse {
            session_token,
            user_id: user.id,
        }),
    )
        .into_response()
}

