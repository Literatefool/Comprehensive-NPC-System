--[[
	ServerFallbackSimulator - Minimal server simulation for unclaimed NPCs

	When no client is within simulation distance of an NPC, this provides
	minimal 1 FPS movement to prevent NPCs from freezing completely.

	This is a FALLBACK system - clients should handle the vast majority of simulation.
	The server only steps in when absolutely necessary.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerFallbackSimulator = {}

---- Knit Services
local NPC_Service

---- Configuration
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

---- State
local UnclaimedNPCs = {} -- [npcID] = unclaimedTimestamp
local ServerSimulatedNPCs = {} -- [npcID] = simData

---- Timing
local accumulator = 0
local FIXED_TIMESTEP -- Set in Init

--[[
	Mark an NPC as unclaimed

	@param npcID string - The NPC ID
]]
function ServerFallbackSimulator.MarkUnclaimed(npcID)
	-- Don't mark if already being server-simulated
	if ServerSimulatedNPCs[npcID] then
		return
	end

	-- Don't mark if already in unclaimed list
	if UnclaimedNPCs[npcID] then
		return
	end

	UnclaimedNPCs[npcID] = tick()
end

--[[
	Mark an NPC as claimed (client took over)

	@param npcID string - The NPC ID
]]
function ServerFallbackSimulator.MarkClaimed(npcID)
	UnclaimedNPCs[npcID] = nil

	-- Stop server simulation if running
	if ServerSimulatedNPCs[npcID] then
		ServerFallbackSimulator.StopServerSimulation(npcID)
	end
end

--[[
	Start minimal server simulation for an NPC

	@param npcID string - The NPC ID
]]
function ServerFallbackSimulator.StartServerSimulation(npcID)
	local ActiveNPCsFolder = ReplicatedStorage:FindFirstChild("ActiveNPCs")
	if not ActiveNPCsFolder then
		return
	end

	local npcFolder = ActiveNPCsFolder:FindFirstChild(npcID)
	if not npcFolder then
		return
	end

	local positionValue = npcFolder:FindFirstChild("Position")
	local configValue = npcFolder:FindFirstChild("Config")

	if not positionValue or not configValue then
		return
	end

	local success, config = pcall(function()
		return game:GetService("HttpService"):JSONDecode(configValue.Value)
	end)

	if not success or not config then
		return
	end

	local spawnPos = Vector3.new(
		config.SpawnPosition and config.SpawnPosition.X or positionValue.Value.X,
		config.SpawnPosition and config.SpawnPosition.Y or positionValue.Value.Y,
		config.SpawnPosition and config.SpawnPosition.Z or positionValue.Value.Z
	)

	ServerSimulatedNPCs[npcID] = {
		Position = positionValue.Value,
		WalkSpeed = (config.WalkSpeed or 16) * OptimizationConfig.ServerFallback.SPEED_MULTIPLIER,
		Destination = nil,
		WanderRadius = config.MaxWanderRadius or 50,
		SpawnPosition = spawnPos,
		EnableIdleWander = config.EnableIdleWander ~= false,
	}
end

--[[
	Stop server simulation for an NPC

	@param npcID string - The NPC ID
]]
function ServerFallbackSimulator.StopServerSimulation(npcID)
	ServerSimulatedNPCs[npcID] = nil
end

--[[
	Main simulation step - runs at configured FPS (e.g., 1 FPS)
	Extremely simple movement: just move toward destination

	@param deltaTime number - Time since last step
]]
function ServerFallbackSimulator.SimulationStep(deltaTime)
	local ActiveNPCsFolder = ReplicatedStorage:FindFirstChild("ActiveNPCs")
	if not ActiveNPCsFolder then
		return
	end

	for npcID, simData in pairs(ServerSimulatedNPCs) do
		-- Check if NPC still exists
		local npcFolder = ActiveNPCsFolder:FindFirstChild(npcID)
		if not npcFolder then
			ServerSimulatedNPCs[npcID] = nil
			continue
		end

		-- Check if NPC is still alive
		local isAliveValue = npcFolder:FindFirstChild("IsAlive")
		if isAliveValue and not isAliveValue.Value then
			ServerSimulatedNPCs[npcID] = nil
			continue
		end

		-- Only wander if enabled
		if not simData.EnableIdleWander then
			continue
		end

		-- Simple wander AI: pick random destination if none
		if not simData.Destination then
			local randomOffset = Vector3.new(
				math.random(-simData.WanderRadius, simData.WanderRadius),
				0,
				math.random(-simData.WanderRadius, simData.WanderRadius)
			)
			simData.Destination = simData.SpawnPosition + randomOffset
		end

		-- Simple movement toward destination (no pathfinding)
		local direction = simData.Destination - simData.Position
		direction = Vector3.new(direction.X, 0, direction.Z) -- Flatten Y

		if direction.Magnitude > 1 then
			direction = direction.Unit
			local movement = direction * simData.WalkSpeed * deltaTime
			simData.Position = simData.Position + movement

			-- Update in ReplicatedStorage
			local positionValue = npcFolder:FindFirstChild("Position")
			if positionValue then
				positionValue.Value = simData.Position
			end
		else
			-- Reached destination, clear it
			simData.Destination = nil
		end
	end
end

--[[
	Check for NPCs that have been unclaimed too long
]]
function ServerFallbackSimulator.UnclaimedCheckLoop()
	local checkInterval = 1.0 -- Check every second
	local timeout = OptimizationConfig.ServerFallback.UNCLAIMED_TIMEOUT
	local maxSimulated = OptimizationConfig.ServerFallback.MAX_SERVER_SIMULATED

	while true do
		task.wait(checkInterval)

		if not OptimizationConfig.ServerFallback.ENABLED then
			continue
		end

		local now = tick()
		local currentCount = 0

		for _ in pairs(ServerSimulatedNPCs) do
			currentCount = currentCount + 1
		end

		for npcID, unclaimedTime in pairs(UnclaimedNPCs) do
			-- Check if unclaimed long enough and we have capacity
			if now - unclaimedTime > timeout then
				if currentCount < maxSimulated then
					ServerFallbackSimulator.StartServerSimulation(npcID)
					UnclaimedNPCs[npcID] = nil
					currentCount = currentCount + 1
				end
			end
		end
	end
end

--[[
	Cleanup when NPC is removed

	@param npcID string - The NPC ID
]]
function ServerFallbackSimulator.CleanupNPC(npcID)
	UnclaimedNPCs[npcID] = nil
	ServerSimulatedNPCs[npcID] = nil
end

--[[
	Get count of server-simulated NPCs
]]
function ServerFallbackSimulator.GetSimulatedCount()
	local count = 0
	for _ in pairs(ServerSimulatedNPCs) do
		count = count + 1
	end
	return count
end

--[[
	Check if NPC is being server-simulated

	@param npcID string - The NPC ID
	@return boolean
]]
function ServerFallbackSimulator.IsServerSimulating(npcID)
	return ServerSimulatedNPCs[npcID] ~= nil
end

function ServerFallbackSimulator.Start()
	if not OptimizationConfig.ServerFallback.ENABLED then
		return
	end

	-- Start unclaimed check loop
	task.spawn(ServerFallbackSimulator.UnclaimedCheckLoop)

	-- Start simulation loop (runs on Heartbeat but only processes at configured FPS)
	RunService.Heartbeat:Connect(function(deltaTime)
		accumulator = accumulator + deltaTime

		-- Only process at configured FPS (e.g., 1 FPS)
		if accumulator >= FIXED_TIMESTEP then
			accumulator = accumulator - FIXED_TIMESTEP
			ServerFallbackSimulator.SimulationStep(FIXED_TIMESTEP)
		end
	end)
end

function ServerFallbackSimulator.Init()
	NPC_Service = Knit.GetService("NPC_Service")

	-- Calculate fixed timestep based on config
	FIXED_TIMESTEP = 1 / OptimizationConfig.ServerFallback.SIMULATION_FPS
end

return ServerFallbackSimulator
