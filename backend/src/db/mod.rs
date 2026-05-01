use sqlx::PgPool;

/// Shared Postgres connection pool alias used across the application.
pub type DbPool = PgPool;

/// Create a connection pool from the given database URL.
pub async fn create_pool(database_url: &str) -> Result<DbPool, sqlx::Error> {
    sqlx::postgres::PgPoolOptions::new()
        .max_connections(10)
        .connect(database_url)
        .await
}

/// Apply all pending sqlx migrations from `src/db/migrations/`.
pub async fn run_migrations(pool: &PgPool) -> Result<(), sqlx::migrate::MigrateError> {
    sqlx::migrate!("src/db/migrations").run(pool).await
}
