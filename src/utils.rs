use pathfinding::prelude::astar;
use std::collections::HashMap;
use strum::IntoEnumIterator;
use strum_macros::EnumIter;

#[path = "dbLink.rs"]
mod dbSearch;

struct Block
{
    x: i64,
    y: i64,
    z: i64,
    type: String
}

// So Blocks are hashed by coords, and not type
// Because serialising strings is stupid
impl PartialEq for Block
{
    fn eq(&self, other : &Self) -> bool 
    {
        self.x == other.x && self.y == other.y && self.z == other.z;
    }
}

impl Eq for Block {}

impl Hash for Block{
    fn hash<H: Hasher>(&self, state : &mut H)
    {
        self.x.hash(state);
        self.y.hash(state);
        self.z.hash(state);
    }
}

enum Direction
{
    North,
    South,
    East,
    West,
    Up,
    Down
};

struct Node
{
    totalScore : i64,
    path : Vec<Direction>,
    block : Block
}

const let searchRange : u32 = 100;
fn ManhattanHeuristic(const a : &Block, const b : &Block) -> f32
{
    return (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs();
}

fn AdjustMovementDirection(targetBlock : &Block, dir : Direction)
{
    use Direction::*;
    match dir 
    {
        North => (targetBlock.x,     targetBlock.y,     targetBlock.z - 1),
        South => (targetBlock.x,     targetBlock.y,     targetBlock.z + 1),
        East  => (targetBlock.x + 1, targetBlock.y,     targetBlock.z),
        West  => (targetBlock.x - 1, targetBlock.y,     targetBlock.z),
        Up    => (targetBlock.x,     targetBlock.y + 1, targetBlock.z),
        Down  => (targetBlock.x,     targetBlock.y - 1, targetBlock.z),
    }
}

fn SearchNode(allBlocks : &HashMap, node : &Node, targetBlock : &Block)
{
    if (targetBlock == node.block)
        return node.path;

    let mut directionNodes = Vec::new()
    for direction in Direction::iter()
    {
        let newNode : Node = node.clone();
        AdjustMovementDirection(newNode.block, direction);
        newNode.totalScore += ManhattanHeuristic(newNode.block, targetBlock)
        directionNodes.push(newNode);
    }

    directionNodes.sort_by_key(|node| node.totalScore);
    for (node in directionNodes)
    {
        if (allBlocks.contains_key(&newNode.block))
        {
            return SearchNode(node, targetBlock);
        }
    }
}

fn InitHashMap(startBlock : &Block, &sqlx::Pool<sqlx::Sqlite>) -> HashMap<Block, String>
{
    let mut items = HashMap::new();
    let allBlocks = dbSearch::SearchRange(sqlx, startBlock, searchRange).await?;
    for block in allBlocks
    {
        items.insert(block, block.type);
    }
    items
}

async fn FindPath(const start : &Block, &sqlx::Pool<sqlx::Sqlite>, const target : &Block)
{
    let found : bool = false;
    let allBlocks = InitHashMap(start, sqlx);

    let startNode = Node {
        totalScore = 0;
        path = Vec::new();
        block = start;
    };

    return SearchNode(allBlocks, startNode);
}
