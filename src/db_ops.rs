use sqlx::{postgres::PgPoolOptions, Connection, PgConnection, Executor, Pool, Postgres, Error};

// This module is included from utils.rs (as `db_search`), so its parent
// module already provides `Block` via `super::` — no need to re-include utils.rs here.
use super::Block;

// General DB Operations
pub async fn add_record(
    pool: &sqlx::Pool<sqlx::Postgres>,
		turtle_name : &String,
    block_name: &str,
    x_pos: i32,
    y_pos: i32,
    z_pos: i32
) -> Result<(), sqlx::Error> {
    sqlx::query("INSERT INTO blocks (blockdata, turtlename, blockx, blocky, blockz) VALUES ($1, $2, $3, $4, $5)")
        .bind(block_name)
				.bind(turtle_name)
        .bind(x_pos)
        .bind(y_pos)
        .bind(z_pos)
        .execute(pool)
        .await?;

    Ok(())
}

pub async fn remove_record(
    pool: &sqlx::Pool<sqlx::Postgres>,
    id: i32
) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM blocks WHERE id = $1")
        .bind(id)
        .execute(pool)
        .await?;

    Ok(())
}

pub async fn modify_record(
    pool: &sqlx::Pool<sqlx::Postgres>,
    id: i32,
    block_name: &str,
    x_pos: i32,
    y_pos: i32,
    z_pos: i32
) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE blocks SET name = $1, x = $2, y = $3, z = $4 WHERE id = $5")
        .bind(block_name)
        .bind(x_pos)
        .bind(y_pos)
        .bind(z_pos)
        .bind(id)
        .execute(pool)
        .await?;

    Ok(())
}

// Searches a range around a block and returns
// all blocks inside that radius
// range will typically be something like 100
use sqlx::{Row}; // Added Row trait import
pub async fn search_range(
    pool: &Pool<Postgres>, // Changed to Postgres
    block: &Block,
    search_area: u32
) -> Result<Vec<Block>, sqlx::Error> {
    // Cast range to i64 to match the x, y, z coordinate fields exactly
    let range = search_area as i64;

    let min_x = block.x - range;
    let max_x = block.x + range;
    let min_y = block.y - range;
    let max_y = block.y + range;
    let min_z = block.z - range;
    let max_z = block.z + range;

    // Postgres uses numbered placeholders ($1, $2, etc.) instead of '?'
    let rows = sqlx::query(
        "SELECT id, name, x, y, z FROM blocks WHERE x BETWEEN $1 AND $2 AND y BETWEEN $3 AND $4 AND z BETWEEN $5 AND $6"
    )
    .bind(min_x)
    .bind(max_x)
    .bind(min_y)
    .bind(max_y)
    .bind(min_z)
    .bind(max_z)
    .fetch_all(pool)
    .await?;

    let mut matching_blocks = Vec::new();
    for row in rows {
        let x_val: i64 = row.get("x");
        let y_val: i64 = row.get("y");
        let z_val: i64 = row.get("z");
        let name_val: String = row.get("name");

        let new_block = Block {
            x: x_val,
            y: y_val,
            z: z_val,
            // Assuming you renamed the field in utils::Block from 'type' to 'block_type'
            // to avoid Rust's reserved keyword collision
            block_type: name_val,
        };

        matching_blocks.push(new_block);
    }

    Ok(matching_blocks)
}
