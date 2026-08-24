use sqlx::{postgres::PgPoolOptions, Connection, PgConnection, Executor, Pool, Postgres, Error};

#[path = "types.rs"]
mod types;

#![allow(non_snake_case)]

// General DB Operations
async fn AddRecord(
    pool: &sqlx::Pool<sqlx::Sqlite>, 
    blockName: &str, 
    xPos: i32, 
    yPos: i32, 
    zPos: i32
) -> Result<(), sqlx::Error> {
    sqlx::query("INSERT INTO blocks (name, x, y, z) VALUES (?, ?, ?, ?)")
        .bind(blockName)
        .bind(xPos)
        .bind(yPos)
        .bind(zPos)
        .execute(pool)
        .await?;

    Ok(())
}

async fn RemoveRecord(
    pool: &sqlx::Pool<sqlx::Sqlite>, 
    id: i32
) -> Result<(), sqlx::Error> {
    sqlx::query("DELETE FROM blocks WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;

    Ok(())
}

// 3. MODIFY RECORD
async fn ModifyRecord(
    pool: &sqlx::Pool<sqlx::Sqlite>, 
    id: i32, 
    blockName: &str, 
    xPos: i32, 
    yPos: i32, 
    zPos: i32
) -> Result<(), sqlx::Error> {
    sqlx::query("UPDATE blocks SET name = ?, x = ?, y = ?, z = ? WHERE id = ?")
        .bind(blockName)
        .bind(xPos)
        .bind(yPos)
        .bind(zPos)
        .bind(id)
        .execute(pool)
        .await?;

    Ok(())
}

// Searches a range around a block and returns
// all blocks inside that radius
// range will typically be something like 100
async fn SearchRange(
    pool: &sqlx::Pool<sqlx::Sqlite>, 
    block: &types::Block, 
    searchArea: u32
) -> Result<Vec<types::Block>, sqlx::Error> {
    // Convert the range to an i32 to match your coordinate types
    let range = searchArea as i32;

    // Calculate the boundaries of our search box using camelCase
    let minX = block.x - range;
    let maxX = block.x + range;
    let minY = block.y - range;
    let maxY = block.y + range;
    let minZ = block.z - range;
    let maxZ = block.z + range;

    // Grab all records inside those boundaries
    let rows = sqlx::query("SELECT id, name, x, y, z FROM blocks WHERE x BETWEEN ? AND ? AND y BETWEEN ? AND ? AND z BETWEEN ? AND ?")
        .bind(minX)
        .bind(maxX)
        .bind(minY)
        .bind(maxY)
        .bind(minZ)
        .bind(maxZ)
        .fetch_all(pool)
        .await?;

    let mut matchingBlocks = Vec::new();
    for row in rows {
        let xVal: i64 = row.get::<i64, &str>("x");
        let yVal: i64 = row.get::<i64, &str>("y");
        let zVal: i64 = row.get::<i64, &str>("z");

        let nameVal: String = row.get::<String, &str>("name");

        let newBlock = types::Block {
            x: xVal,
            y: yVal,
            z: zVal,
            type: nameVal,
        };

        matchingBlocks.push(newBlock);
    }

    Ok(matchingBlocks)
}
