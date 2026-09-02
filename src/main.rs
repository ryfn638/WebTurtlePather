use axum::{routing::post, Router};
use std::env;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tower_http::services::ServeDir;

#[path = "serialize_types.rs"]
mod serialize_types;

// TODO: REFACTOR THIS SHIT U TARD
#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("High-performance pathfinder listening on http://{}", addr);

    let database_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL environment variable must be set in .env");

    let pool = sqlx::PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to PostgreSQL database");

		// Write new routes here
		// Routes that I will want in future, just not right now
		// /map, returns all known turtles and their positions
    let app = Router::new()
        .route("/path", post(serialize_types::calculate_path))
				.route("/block", post(serialize_types::add_block))
				.route("/ping", post(serialize_types::ping))
				.fallback_service(ServeDir::new("static"))
        .with_state(pool);

    let listener = TcpListener::bind(addr)
        .await
        .expect("Failed to bind to port 3000");

    axum::serve(listener, app)
        .await
        .expect("Server runtime error encountered");
}
