use axum::{routing::post, Router};
use std::env;
use std::net::SocketAddr;
use tokio::net::TcpListener;

#[path = "serialize_types.rs"]
mod serialize_types;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("High-performance pathfinder listening on http://{}", addr);

    // 1. Establish the PostgreSQL Connection Pool
    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL environment variable must be set in .env");
    let pool = sqlx::PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to PostgreSQL database");

    // 2. Build the router and attach the database pool as shared state
    let app = Router::new()
        .route("/path", post(serialize_types::calculate_path))
        .with_state(pool);

    // 3. Bind the async TCP listener
    let listener = TcpListener::bind(addr)
        .await
        .expect("Failed to bind to port 3000");

    // 4. Run the high-concurrency server engine
    axum::serve(listener, app)
        .await
        .expect("Server runtime error encountered");
}
