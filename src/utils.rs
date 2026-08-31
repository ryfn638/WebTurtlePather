use std::collections::{HashMap, HashSet};
use std::hash::{Hash, Hasher};
use strum::{EnumIter, IntoEnumIterator};

#[derive(EnumIter, Clone, Copy, Debug, PartialEq)]
pub enum Direction {
    North,
    South,
    East,
    West,
    Up,
    Down,
}

#[path = "db_ops.rs"]
mod db_search;

#[derive(Clone, Eq, Debug)]
pub struct Block {
    pub x: i64,
    pub y: i64,
    pub z: i64,
    pub block_type: String,
}

impl PartialEq for Block {
    fn eq(&self, other: &Self) -> bool {
        self.x == other.x && self.y == other.y && self.z == other.z
    }
}

impl Hash for Block {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.x.hash(state);
        self.y.hash(state);
        self.z.hash(state);
    }
}

#[derive(Clone)]
struct Node {
    total_score: i64,
    path: Vec<Direction>,
    block: Block,
}

const SEARCH_RANGE: u32 = 100;

fn manhattan_heuristic(a: &Block, b: &Block) -> i64 {
    (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs()
}

fn adjust_movement_direction(target_block: &mut Block, dir: Direction) {
    use Direction::*;
    match dir {
        North => target_block.z -= 1,
        South => target_block.z += 1,
        East  => target_block.x += 1,
        West  => target_block.x -= 1,
        Up    => target_block.y += 1,
        Down  => target_block.y -= 1,
    }
}

// Visited track protects your server from the recursive infinite-loop crash
fn search_node(
    all_blocks: &HashMap<Block, String>, 
    node: &Node, 
    target_block: &Block,
    visited: &mut HashSet<Block>
) -> Option<Vec<Direction>> {
    if target_block == &node.block {
        return Some(node.path.clone());
    }

    visited.insert(node.block.clone());

    let mut direction_nodes = Vec::new();
    for direction in Direction::iter() {
        let mut new_node = node.clone();
        adjust_movement_direction(&mut new_node.block, direction);
        
        if visited.contains(&new_node.block) {
            continue;
        }

        new_node.path.push(direction);
        new_node.total_score += manhattan_heuristic(&new_node.block, target_block);
        direction_nodes.push(new_node);
    }

    direction_nodes.sort_by_key(|n| n.total_score);
    
    for new_node in direction_nodes {
        if all_blocks.contains_key(&new_node.block) {
            if let Some(path) = search_node(all_blocks, &new_node, target_block, visited) {
                return Some(path);
            }
        }
    }
    None
}

// FIXED: Cleaned out Sqlite. Explicitly using Postgres connection pool.
async fn init_hash_map(start_block: &Block, pool: &sqlx::Pool<sqlx::Postgres>) -> Result<HashMap<Block, String>, sqlx::Error> {
    let mut items = HashMap::new();
    let all_blocks = db_search::search_range(pool, start_block, SEARCH_RANGE).await?;
    for block in all_blocks {
        items.insert(block.clone(), block.block_type.clone());
    }
    Ok(items)
}

// FIXED: Cleaned out Sqlite. Explicitly using Postgres connection pool.
pub async fn find_path(pool: &sqlx::Pool<sqlx::Postgres>, start: &Block, target: &Block) -> Result<Option<Vec<Direction>>, sqlx::Error> {
    let all_blocks = init_hash_map(start, pool).await?;

    let start_node = Node {
        total_score: 0,
        path: Vec::new(),
        block: start.clone(),
    };

    let mut visited = HashSet::new();

    Ok(search_node(&all_blocks, &start_node, target, &mut visited))
}
