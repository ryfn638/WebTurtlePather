local Turtle = {}
Turtle.__index = Turtle

local API_URL = "http://127.0.0.1:3000"
local lastTime = os.time()
local updateRate = 1/20
local directionToIndex = {
	["north"] = 1,
	["east"] = 2,
	["south"] = 3,
	["west"] = 4
}

local function IsCompassDirection(direction)
	return (direction == "north" or direction == "south" or direction == "east" or direction == "west")
end

local function GetCompassDirectionIndex(direction)
	local index = directionToIndex[direction]
	if (index) then return index end
	return -1
end

function CreatePoint(x, y, z)
	local point = {x = x or 0, y = y or 0, z = z or 0 }

	setmetatable(point, {
		__newindex = function(t, key, value)
			error("Cannot add new coordinate at" .. tostring(key))
		end
	})

	return point
end

-- General API for moving the turtle and operations
-- Safely without losing it.
-- Turtles always return back to home if fuel is a concern

--     Fuel Points are defined by the user
--     and mainly serve to identify reliable
--     Places to refuel that the Turtle keeps
--     track of how to get back to it

--     Fuel Points movements take priority
--     Over instructions, this can be ignored
--     If the user calls IgnoreFuelRecall()


-- Never get rid of the step recall, but for sure this'll save fuel

-- Init() -> Initialises a Turtle with a name

function Turtle:Init(name, fuelLevel, direction, posX, posY, posZ)
    print(string.format("Initialising Turtle with name %s", name))
    
    local instance = setmetatable({}, self)
    
    -- Turtle Variables 
    instance.name = name

		instance.directions = direction
		instance.position = CreatePoint(posX, posY, posZ)

    instance.fuelLevel = turtle.getFuelLevel()
    instance.inventorySpace = self:GetInventorySpace()
    instance.doesFuelRecall = true    
		instance.running = false   
    instance.homeCost = 0 -- Assuming you're initialising it in the home

		-- If the fuelBuffer, is 2 times larger than manhattan distance to the neastest fuel source, just requests the coordinates back to the fuel source
		-- I dont like this though, this is an estimated guess, it may be fine for the first return. but for complex caves, I'd like a better approach
		-- Try to think of one
		instance.fuelBuffer = 2;

		-- Known blocks, and their data
		instance.knownBlocks = {}
		instance.blockData = {}

		-- These are all Points in space, and a list
		-- TO access it is like (3*posnumber + 1) and the next 3 indexes are the positional values
    instance.fuelSources = {}
    instance.storageSources = {}
    instance.toolSources = {}
end

-- Euclidean distance to the point
-- Maybe can do something better
function Turtle:GetDistance(location)
    return math.sqrt((self.position[1] - location[1]) ^ 2) + 
           ((self.position[2] - location[2]) ^ 2) + 
           ((self.position[3] - location[3]) ^ 2)
end

-- General function for getting the nearest source
-- Returns a Point object
-- returns the turtle position if none are in the list
function Turtle:GetNearestSource(source)
	if next(self.fuelSources) == nil then return end
	local maxDist = -1;
	local closestSource = self.position

	for index, _ in ipairs(source) do
		local offset = index * 3
		local fuelPoint = CreatePoint(
			self.fuelSources[offset],
			self.fuelSources[offset+1],
			self.fuelSources[offset+2]
		)

		local distance = self:GetDistance(fuelPoint)
		if (distance > maxDist) then
			maxDist = distance
			self.closestFuelSource = fuelPoint
		end
	end

	return closestSource
end

-- This updates at a rate of 20Hz by default
function Turtle:Run(controlFunc)
	self.running = true
	while self.running do

		-- Control Func is the user instructions
		controlFunc()

		local currentTime = os.time()
		if (currentTime - lastTime >= 5) then -- Every 5 Seconds, send an update over to the 
			self:SendSeenBlocks() -- Update the API with the known blocks every 5 seconds

			self:PursueSource(self.fuelSources, self:Refuel())

			-- Dump inventory loop
			local availSlots = self:GetInventorySpace()
			if (availSlots == 0) then
				self:PursueSource(self.storageSources, self:DumpInventory())
			end

			lastTime = currentTime
		end

		os.sleep(updateRate)
		self:UpdateFuel()
	end
end

function Turtle:Refuel()
	turtle.select(1)
	if (turtle.refuel()) then
		print("Failed to refuel")
	else
		print("No fuel available")
	end
end

function Turtle:DumpInventory()
	for slot = 2, 16 do
		turtle.select(slot)
		if (turtle.getItemCount() > 0) then
			turtle.drop()
		end
	end
end

-- Pursues a source, and then does an action when it arrives
function Turtle:PursueSource(source, action)
	local currentPosition = self.position
	local nearestSource = self:GetNearestSource(source)
	local path = self:RequestPath(nearestSource)
	if (path == nil) then 
		print("Failed to find source")
		return
	 end

	self:FollowPath(path)
	action()
	local returnPath = self:RequestPath(path)

	if (returnPath == nil) then 
		print("Failed to fetch return path source")
		return
	end

	self:FollowPath(returnPath) -- travels back to the original position
end

function Turtle:UpdateFuel()
	self.fuellevel = turtle.getFuelLevel()
end

-- Creates a new Fuel Point position
function Turtle:AddFuelPoint(x, y, z)
	local newPoint = CreatePoint(x, y, z)
	table.insert(self.fuelSources, newPoint)
end

-- Can just use turtle.inspect, but i think its nicer from the Turtle object
function Turtle:Inspect()
	return turtle.inspect()
end

function Turtle:InspectUp()
	return turtle.inspectDown()
end

function Turtle:InspectDown()
	return turtle.inspectUp()
end

function Turtle:ScanSurroundings()
	self:RegisterFront()
	self:TurnRight()
	self:RegisterFront()
	self:TurnRight()
	self:RegisterFront()
	self:TurnRight()
	self:RegisterFront()
	self:TurnRight()

	self:InspectUp()
	self:InspectDown()
end

-- Registers whatever is directly infront
function Turtle:RegisterFront()
	local success, data = self:Inspect()
	if (!success) then return end

	if (self.direction == 1) then -- North
		table.insert(self.knownBlocks, CreatePoint(self.position[1], self.position[2], self.position[3] - 1))
	elseif (self.direction == 2) then -- South
		table.insert(self.knownBlocks, CreatePoint(self.position[1] + 1, self.position[2], self.position[3]))
	elseif (self.direction == 3) then -- East
		table.insert(self.knownBlocks, CreatePoint(self.position[1], self.position[2], self.position[3] - 1))
	elseif (self.direction == 4) then -- West
		table.insert(self.knownBlocks, CreatePoint(self.position[1] - 1, self.position[2], self.position[3]))
	end

	table.insert(self.blockData, data)
end

function Turtle:RegisterUp()
	local success, data = self:InspectUp()
	if (!success) then return end
	table.insert(self.knownBlocks, CreatePoint(self.position[1], self.position[2] + 1, self.position[3]))
	table.insert(self.blockData, data)
end

function Turtle:RegisterDown()
	local success, data = self:InspectDown()
	if (!success) then return end

	table.insert(self.knownBlocks, CreatePoint(self.position[1], self.position[2] + 1, self.position[3]))
	table.insert(self.blockData, data)
end

-- Sends seen objects to the http server API
function Turtle:SendSeenBlocks()
	print("Sending Send blocks")

	local payload = textutils.SerializeJSON({
		turtle_id = os.getComputerID(),
		block_updates = self.knownBlocks,
		block_data = self.blockData
	})

	-- Clear payload
	self.knownBlocks = {}

	local response = http.post(API_URL, payload, {["Content-Type"] = "application/json"})
	if response then
		return true
	else
		print("Error: Could not find pathfinding server")
		return false
	end
end

-----------------------------
--- MOVEMENT COMMANDS
-----------------------------

-- Returns true if moved successful
function Turtle:Move()
	return turtle.forward()
end

function Turtle:MoveBackward()
	return turtle.back()
end

function Turtle:MoveUp()
	return turtle.up()
end

function Turtle:MoveDown()
	return turtle.down()
end

-- Updates an internal direction tracker
function Turtle:TurnRight()
	if (self.direction == 4) then self.direction = 1 end

	turtle.turnRight()
end

function Turtle:TurnLeft()
	if (self.direction == 1) then self.direction = 4 end

	turtle.turnLeft()
end

function Turtle:TurnToAxis(direction)
	local index = GetCompassDirectionIndex(direction)
	if (index == -1) then return false end

	-- TODO: Smart Turning, this just turns right until its the right direction
	while (index ~= self.direction) do
		self:TurnRight() -- Turn right until the direction
	end
end

-- Mine Direction relative to current rotation
-- directions
-- 1 -> Forward
-- 2 -> Right
-- 3 -> Left
-- 4 -> Behind
-- 5 -> Down
-- 6 -> Up
function Turtle:MoveDirection(direction)
	if (direction == 1) then self:Move() 
	elseif (direction == 5) then self:MoveUp()
	elseif (direction == 6) then	self:MoveDown()
	elseif (direction == 2) then
		self:TurnRight()
		self:Move()
	elseif (direction == 3) then
		self:TurnLeft()
		self:Move()
	elseif (direction == 4) then
		self:TurnRight()
		self:TurnRight()
		self:Move()
	end
end

-- Moves a compass direction
function Turtle:MoveCompass(direction)
	self:TurnToAxis(direction)
	self:MoveForward()
end

-- Follows the path form the actions of the drone
-- Returns false if the movements did not complete successfully
function Turtle:FollowPath(path)
	if not path then return false end 
	local didSucceed = false;
	for _, action in ipairs(path) do
		if (IsCompassDirection(action)) then	didSucceed = didSucceed or self:MoveDirection(action)
		elseif action == "up" then didSucceed = didSucceed or self:MoveUp()
		elseif action == "down" then didSucceed = didSucceed or self:MoveDown()

		if (!didSucceed) then break end
	end

	return didSucceed;
end

-- Requests a fuel path to the http server and returns the received request
function Turtle:RequestPath(newPath)
	print("Low on Fuel, returning to refueling station")

	local payload = textutils.SerializeJSON({
		turtle_id = os.getComputerID(),
		position = self.position,
		wanted_position = newPath
	})

	local response = http.post(API_URL, payload, {["Content-Type"] = "application/json"})
	if response then
		local jsonString =- response.readAll()
		response.close()
		local data = textutils.unserializeJSON(jsonString)
		return data.path
	else
		print("Error: Could not find pathfinding server")
		return nil
	end
end

-- Adds a storage chest location
function Turtle:AddStorageChest(x, y, z)
	local newPoint = CreatePoint(x, y, z)
	table.insert(self.storageChests, newPoint)
end

-- Creates a new Fuel Point position
function Turtle:AddToolRepair(x, y, z)
	local newPoint = CreatePoint(x, y, z)
	table.insert(self.toolSources, newPoint)
end

-- Sets the doesFuelRecall variable.
-- Arguably, you should never turn this off.
-- I cant imagine a use case where you'd want a turtle to just go and kill itself
function Turtle:SetFuelRecall(doRecall)
    self.doesFuelRecall = doRecall    
end

-- Gets the amount of available inventory slots of the turtle
function Turtle:GetInventorySpace()
    local freeSlots = 0
    for slot = 1, 16 do
        if (turtle.GetItemCount(slot) == 0) then
            freeSlots = freeSlots + 1
        end
    end
    
    return freeSlots
end

-- Mine the block directly ahead
function Turtle:Mine(tool)
	return turtle.dig()
end

function Turtle:MineUp(tool)
	return turtle.digUp()
end

function Turtle:MineDown(tool)
	return turtle.digDown()
end

-- Mine using compass directions (N, S, E, W)
function Turtle:MineCompass(direction)
	self:TurnToAxis(direction)
	self:Mine()
end

-- Mine Direction relative to current rotation
-- directions
-- 1 -> Forward
-- 2 -> Right
-- 3 -> Left
-- 4 -> Behind
-- 5 -> Down
-- 6 -> Up
function Turtle:MineDirection(tool, direction)
	if (direction == 1) then self:Mine(tool)
	elseif (direction == 5) then self:MineUp(tool)
	elseif (direction == 6) then	self:MineDown(tool)
	elseif (direction == 2) then
		self:TurnRight()
		self:Mine(tool)
	elseif (direction == 3) then
		self:TurnLeft()
		self:Mine(tool)
	elseif (direction == 4) then
		self:TurnRight()
		self:TurnRight()
		self:Mine(tool)
	end
end

-- Pings and receives a response from the http server
function Turtle:Ping()
	local payload = textutils.SerializeJSON({
		turtle_id = os.getComputerID()
	})

	-- Clear payload
	self.knownBlocks = {}

	local response = http.post(API_URL, payload, {["Content-Type"] = "application/json"})

	if response then
		return true
	else
		return false
	end

end

return Turtle
end
