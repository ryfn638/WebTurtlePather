local Turtle = {}
Turtle.__index = Turtle
local API_URL = "http://127.0.0.1:3000"
local PATH_ENDPOINT = API_URL .. "/path"
local BLOCK_ENDPOINT = API_URL .. "/block"
local PING_ENDPOINT = API_URL .. "/ping"

local MIN_FUEL_REQUIREMENT = 100;
local lastTime = os.time()
local updateRate = 1/20
local directionToIndex = {
	["north"] = 1,
	["east"] = 2,
	["south"] = 3,
	["west"] = 4
}
-- Which way each compass index faces, in block offsets.
-- Minecraft: north is -Z, east is +X, south is +Z, west is -X
local directionOffsets = {
	[1] = {x =  0, z = -1}, -- north
	[2] = {x =  1, z =  0}, -- east
	[3] = {x =  0, z =  1}, -- south
	[4] = {x = -1, z =  0}  -- west
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
	local point = {x = x or 0, y = y or 0, z = z or 0}
	setmetatable(point, {
		__newindex = function(t, key, value)
			error("Cannot add new coordinate at " .. tostring(key))
		end,
		__index = function(t, key)
			error("Cannot read unknown coordinate " .. tostring(key))
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
function Turtle:Init(name, direction, posX, posY, posZ)
    print(string.format("Initialising Turtle with name %s", name))

    local instance = setmetatable({}, self)

    -- Turtle Variables
    instance.name = name
		-- Accept either "north" or the raw index
		if (type(direction) == "string") then
			instance.direction = GetCompassDirectionIndex(direction)
		else
			instance.direction = direction or 1
		end
		if (instance.direction == -1) then
			error("Unknown starting direction: " .. tostring(direction))
		end

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
		-- Each entry is a Point created by CreatePoint
    instance.fuelSources = {}
    instance.storageSources = {}
    instance.toolSources = {}

		return instance
end
-- Euclidean distance to the point
-- Maybe can do something better
function Turtle:GetDistance(location)
    return math.sqrt(
        (self.position.x - location.x) ^ 2 +
        (self.position.y - location.y) ^ 2 +
        (self.position.z - location.z) ^ 2
    )
end

-- General function for getting the nearest source
-- Returns a Point object
-- returns the turtle position if none are in the list
function Turtle:GetNearestSource(source)
	if (source == nil or next(source) == nil) then return self.position end
	local minDist = math.huge
	local closestSource = self.position
	for _, point in ipairs(source) do
		local distance = self:GetDistance(point)
		if (distance < minDist) then
			minDist = distance
			closestSource = point
		end
	end
	return closestSource
end

-- This updates at a rate of 20Hz by default
function Turtle:Run(controlFunc)
	self.running = true
	lastTime = os.clock()
	while self.running do
		-- Control Func is the user instructions
		controlFunc()

		self:RegisterFront()
		self:RegisterUp()
		self:RegisterDown()

		local currentTime = os.clock()
		if (currentTime - lastTime >= 5) then -- Every 5 Seconds, send an update over to the
			self:SendSeenBlocks() -- Update the API with the known blocks every 5 seconds


			if (self.fuelLevel < MIN_FUEL_REQUIREMENT) then
				-- If the fuel level is low then pursue the source
				self:PursueSource(self.fuelSources, function() self:Refuel() end)
			end

			-- Dump inventory loop
			local availSlots = self:GetInventorySpace()
			if (availSlots == 0) then
				self:PursueSource(self.storageSources, function() self:DumpInventory() end)
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
		print("Refuelled")
	else
		print("No fuel available")
	end

	self.fuelLevel = turtle.getFuelLevel()
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
	-- Copy, because self.position mutates as we move
	local origin = CreatePoint(self.position.x, self.position.y, self.position.z)
	local nearestSource = self:GetNearestSource(source)
	local path = self:RequestPath(nearestSource)
	if (path == nil) then
		print("Failed to find source")
		return
	 end
	self:FollowPath(path)
	action()
	local returnPath = self:RequestPath(origin)
	if (returnPath == nil) then
		print("Failed to fetch return path source")
		return
	end
	self:FollowPath(returnPath) -- travels back to the original position
end
function Turtle:UpdateFuel()
	self.fuelLevel = turtle.getFuelLevel()
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
	return turtle.inspectUp()
end
function Turtle:InspectDown()
	return turtle.inspectDown()
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
	self:RegisterUp()
	self:RegisterDown()
end
-- Registers whatever is directly infront
function Turtle:RegisterFront()
	local success, data = self:Inspect()
	if (not success) then return end
	local offset = directionOffsets[self.direction]
	table.insert(self.knownBlocks, CreatePoint(self.position.x + offset.x, self.position.y, self.position.z + offset.z))
	table.insert(self.blockData, data)
end
function Turtle:RegisterUp()
	local success, data = self:InspectUp()
	if (not success) then return end
	table.insert(self.knownBlocks, CreatePoint(self.position.x, self.position.y + 1, self.position.z))
	table.insert(self.blockData, data)
end
function Turtle:RegisterDown()
	local success, data = self:InspectDown()
	if (not success) then return end
	table.insert(self.knownBlocks, CreatePoint(self.position.x, self.position.y - 1, self.position.z))
	table.insert(self.blockData, data)
end

-- Sends seen objects to the http server API
function Turtle:SendSeenBlocks()
	if (next(self.knownBlocks) == nil) then return true end
	print("Sending seen blocks")

	local blocks = {}
	for i, pos in ipairs(self.knownBlocks) do
		table.insert(blocks, {
			x = tostring(pos.x),
			y = tostring(pos.y),
			z = tostring(pos.z),
			type = self.blockData[i].name
		})
	end

	local payload = textutils.serializeJSON({ blocks = blocks })
	local response = http.post(BLOCK_ENDPOINT, payload, {["Content-Type"] = "application/json"})
	if response then
		response.close()
		self.knownBlocks = {}
		self.blockData = {}
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
	if not turtle.forward() then return false end
	local offset = directionOffsets[self.direction]
	self.position.x = self.position.x + offset.x
	self.position.z = self.position.z + offset.z
	return true
end
function Turtle:MoveBackward()
	if not turtle.back() then return false end
	local offset = directionOffsets[self.direction]
	self.position.x = self.position.x - offset.x
	self.position.z = self.position.z - offset.z
	return true
end
function Turtle:MoveUp()
	if not turtle.up() then return false end
	self.position.y = self.position.y + 1
	return true
end
function Turtle:MoveDown()
	if not turtle.down() then return false end
	self.position.y = self.position.y - 1
	return true
end
-- Updates an internal direction tracker
function Turtle:TurnRight()
	self.direction = (self.direction % 4) + 1
	turtle.turnRight()
end
function Turtle:TurnLeft()
	self.direction = ((self.direction - 2) % 4) + 1
	turtle.turnLeft()
end
function Turtle:TurnToAxis(direction)
	local index = GetCompassDirectionIndex(direction)
	if (index == -1) then return false end
	-- TODO: Smart Turning, this just turns right until its the right direction
	while (index ~= self.direction) do
		self:TurnRight() -- Turn right until the direction
	end
	return true
end
-- Move Direction relative to current rotation
-- directions
-- 1 -> Forward
-- 2 -> Right
-- 3 -> Left
-- 4 -> Behind
-- 5 -> Down
-- 6 -> Up
function Turtle:MoveDirection(direction)
	if (direction == 1) then return self:Move()
	elseif (direction == 5) then return self:MoveDown()
	elseif (direction == 6) then return self:MoveUp()
	elseif (direction == 2) then
		self:TurnRight()
		return self:Move()
	elseif (direction == 3) then
		self:TurnLeft()
		return self:Move()
	elseif (direction == 4) then
		self:TurnRight()
		self:TurnRight()
		return self:Move()
	end
	return false
end
-- Moves a compass direction
function Turtle:MoveCompass(direction)
	if not self:TurnToAxis(direction) then return false end
	return self:Move()
end
-- Follows the path form the actions of the drone
-- Returns false if the movements did not complete successfully
function Turtle:FollowPath(path)
	if not path then return false end
	for _, action in ipairs(path) do
		local moved
		if (IsCompassDirection(action)) then moved = self:MoveCompass(action)
		elseif action == "up" then moved = self:MoveUp()
		elseif action == "down" then moved = self:MoveDown()
		else moved = false
		end
		if (not moved) then return false end
	end
	return true
end
-- Requests a path to the http server and returns the received path
function Turtle:RequestPath(destination)
	local payload = textutils.serializeJSON({
		startBlock = {
			x = tostring(self.position.x),
			y = tostring(self.position.y),
			z = tostring(self.position.z),
			type = "minecraft:air" -- not used by the pathfinder, just required by the struct
		},
		endBlock = {
			x = tostring(destination.x),
			y = tostring(destination.y),
			z = tostring(destination.z),
			type = "minecraft:air"
		}
	})

	local response = http.post(PATH_ENDPOINT, payload, {["Content-Type"] = "application/json"})
	if response then
		local jsonString = response.readAll()
		response.close()
		local data = textutils.unserializeJSON(jsonString)
		if (data == nil) then return nil end
		return data.path
	else
		print("Error: Could not find pathfinding server")
		return nil
	end
end
-- Adds a storage chest location
function Turtle:AddStorageChest(x, y, z)
	local newPoint = CreatePoint(x, y, z)
	table.insert(self.storageSources, newPoint)
end
-- Creates a new Tool Repair position
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
        if (turtle.getItemCount(slot) == 0) then
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
	if not self:TurnToAxis(direction) then return false end
	return self:Mine()
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
	if (direction == 1) then return self:Mine(tool)
	elseif (direction == 5) then return self:MineDown(tool)
	elseif (direction == 6) then	return self:MineUp(tool)
	elseif (direction == 2) then
		self:TurnRight()
		return self:Mine(tool)
	elseif (direction == 3) then
		self:TurnLeft()
		return self:Mine(tool)
	elseif (direction == 4) then
		self:TurnRight()
		self:TurnRight()
		return self:Mine(tool)
	end
	return false
end
-- Pings and receives a response from the http server
function Turtle:Ping()
	local response = http.post(PING_ENDPOINT, "", {["Content-Type"] = "application/json"})
	if response then
		response.close()
		return true
	else
		return false
	end
end

return Turtle
