use sqlx::{postgres::PgPoolOptions, Connection, PgConnection, Executor, Pool, Postgres, Error};
use std::env;

pub async fn connect_db() -> Result<(), Error>
{
    dotenvy::dotenv().ok();

    let db_url = env::var("DATABASE_URL")
        .expect("DATABASE_URL environment variable must be set in .env");

    let db_name = "my_database";

    let base_url = match db_url.rfind('/') {
        Some(pos) => &db_url[..pos],
        None => &db_url,
    };

    match ensure_database_exists(base_url, db_name).await {
        Ok(_) => println!("Database setup verified."),
        Err(e) => println!("Could not verify database: {}", e),
    }

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await?;

    println!("Successfully connected to PostgreSQL with SQLx!");

    let row: (i32,) = sqlx::query_as("SELECT 1")
        .fetch_one(&pool)
        .await?;

    println!("Query result: {}", row.0);
    Ok(())
}

async fn init_database(base_url: &str, database_name: &str) -> Result<Pool<Postgres>, Box<dyn std::error::Error>>
{
    let full_url = format!("{}/{}", base_url, database_name);
    let admin_url = format!("{}/postgres", base_url);

    let mut admin_conn = PgConnection::connect(&admin_url).await?;

    let mut query_builder = sqlx::QueryBuilder::new("CREATE DATABASE ");
    query_builder.push(database_name);

    println!("Database '{}' not found. Creating it...", database_name);
    query_builder.build().execute(&mut admin_conn).await?;
    println!("Database created successfully.");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&full_url)
        .await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS blocks (
            id SERIAL PRIMARY KEY,
            turtleName VARCHAR(50) NOT NULL UNIQUE,
            blockX INT NOT NULL,
            blockY INT NOT NULL,
            blockZ INT NOT NULL,
            blockData VARCHAR
        );
        "#
    )
    .execute(&pool)
    .await?;

    println!("Schema tables initialized successfully.");
    Ok(pool)
}

async fn ensure_database_exists(base_url: &str, database_name: &str) -> Result<(), Error>
{
    let admin_url = format!("{}/postgres", base_url);
    let mut conn = PgConnection::connect(&admin_url).await?;

    let check_query = "SELECT 1 FROM pg_database WHERE datname = $1";

    let result: Option<(i32,)> = sqlx::query_as(check_query)
            .bind(database_name)
            .fetch_optional(&mut conn)
            .await?;

    if result.is_none() {
        println!("Database '{}' does not exist. Creating it now...", database_name);
        match init_database(base_url, database_name).await {
            Ok(_) => println!("Database setup routine completed successfully."),
            Err(e) => println!("Failed to load database: {}", e),
        }
    } else {
        println!("Database '{}' already exists.", database_name);
    }

    Ok(())
}

