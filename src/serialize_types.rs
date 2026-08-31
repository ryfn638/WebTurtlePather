#[path = "utils.rs"]
mod utils;

use axum::{extract::State, Json};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SerializableBlock {
    pub x: String,
    pub y: String,
    pub z: String,

    #[serde(rename = "type")]
    pub block_type: String,
}

// JSON Payload Struct
#[derive(Deserialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SerializedPathPayload {
    pub start_block: SerializableBlock,
    pub end_block: SerializableBlock,
}

// JSON Response Struct
#[derive(Serialize, Debug)]
#[serde(rename_all = "camelCase")]
pub struct SerializablePath {
    pub path: Vec<String>,
}

fn serialize_path(path: &[utils::Direction]) -> Vec<String> {
    let mut serialized_path = Vec::new();
    for direction in path {
        use utils::Direction::*;
        let string_dir = match direction {
            North => "north",
            South => "south",
            East => "east",
            West => "west",
            Up => "up",
            Down => "down",
        };
        serialized_path.push(string_dir.to_string());
    }
    serialized_path
}

// Calculate and return a path handler
// Note: Axum uses State(pool) extractor pattern for database sharing
pub async fn calculate_path(
    State(pool): State<sqlx::Pool<sqlx::Postgres>>,
    Json(payload): Json<SerializedPathPayload>,
) -> Result<Json<SerializablePath>, StatusCodeResponse> {
    println!("Received Path Request");

    // Coerce parsed strings directly into the i64 type expected by utils::Block
    let start_block = utils::Block {
        x: payload.start_block.x.parse::<i64>().map_err(|_| StatusCodeResponse::BadRequest)?,
        y: payload.start_block.y.parse::<i64>().map_err(|_| StatusCodeResponse::BadRequest)?,
        z: payload.start_block.z.parse::<i64>().map_err(|_| StatusCodeResponse::BadRequest)?,
        block_type: payload.start_block.block_type,
    };

    let target_block = utils::Block {
        x: payload.end_block.x.parse::<i64>().map_err(|_| StatusCodeResponse::BadRequest)?,
        y: payload.end_block.y.parse::<i64>().map_err(|_| StatusCodeResponse::BadRequest)?,
        z: payload.end_block.z.parse::<i64>().map_err(|_| StatusCodeResponse::BadRequest)?,
        block_type: payload.end_block.block_type,
    };

    // Await the asynchronous pathfinder and bubble up internal DB errors safely
    let enum_path_result = utils::find_path(&pool, &start_block, &target_block)
        .await
        .map_err(|_| StatusCodeResponse::InternalError)?;

    let string_path = match enum_path_result {
        Some(path) => serialize_path(&path),
        None => Vec::new(), // Returns empty array if no path is found
    };

    let response = SerializablePath { path: string_path };

    println!("Path Result Sent");
    Ok(Json(response))
}

// Minimal error enum to satisfy web framework return rules safely
#[derive(Debug)]
pub enum StatusCodeResponse {
    BadRequest,
    InternalError,
}

impl axum::response::IntoResponse for StatusCodeResponse {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::BadRequest => (axum::http::StatusCode::BAD_REQUEST, "Invalid integer coordinates").into_response(),
            Self::InternalError => (axum::http::StatusCode::INTERNAL_SERVER_ERROR, "Database lookup error").into_response(),
        }
    }
}
