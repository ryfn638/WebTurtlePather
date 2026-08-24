use sqlx::{postgres::PgPoolOptions, Connection, PgConnection, Executor, Pool, Postgres, Error};
use std::env;

pub async fn ConnectDB() -> Result<(), Error> 
{
    dotenvy::dotenv().ok();
    
    let dbUrl = env::var("DATABASE_URL")
        .expect("DATABASE_URL environment variable must be set in .env");

    let dbName = "my_database";

    let baseUrl = match dbUrl.rfind('/') {
        Some(pos) => &dbUrl[..pos],
        None => &dbUrl,
    };

    match EnsureDatabaseExists(baseUrl, dbName).await {
        Ok(_) => println!("Database setup verified."),
        Err(e) => println!("Could not verify database: {}", e),
    }

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&dbUrl) 
        .await?;

    println!("Successfully connected to PostgreSQL with SQLx!");

    let row: (i32,) = sqlx::query_as("SELECT 1")
        .fetch_one(&pool)
        .await?;

    println!("Query result: {}", row.0);
    Ok(())
}

async fn InitDatabase(baseUrl: &str, databaseName : &str) -> Result<Pool<Postgres>, Box<dyn std::error::Error>> 
{
    let fullUrl = format!("{}/{}", baseUrl, databaseName);
    let adminUrl = format!("{}/postgres", baseUrl);
    
    let mut adminConn = PgConnection::connect(&adminUrl).await?;

    let mut queryBuilder = sqlx::QueryBuilder::new("CREATE DATABASE ");
    queryBuilder.push(databaseName);

    println!("Database '{}' not found. Creating it...", databaseName);
    queryBuilder.build().execute(&mut adminConn).await?;
    println!("Database created successfully.");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&fullUrl)
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

async fn EnsureDatabaseExists(baseUrl: &str, databaseName : &str) -> Result<(), Error>
{
    let adminUrl = format!("{}/postgres", baseUrl);
    let mut conn = PgConnection::connect(&adminUrl).await?;

    let checkQuery = "SELECT 1 FROM pg_database WHERE datname = $1";

    let result: Option<(i32,)> = sqlx::query_as(checkQuery)
            .bind(databaseName)
            .fetch_optional(&mut conn)
            .await?;

    if result.is_none() {
        println!("Database '{}' does not exist. Creating it now...", databaseName);
        match InitDatabase(baseUrl, databaseName).await {
            Ok(_) => println!("Database setup routine completed successfully."),
            Err(e) => println!("Failed to load database: {}", e),
        }
    } else {
        println!("Database '{}' already exists.", databaseName);
    }

    Ok(())
}

