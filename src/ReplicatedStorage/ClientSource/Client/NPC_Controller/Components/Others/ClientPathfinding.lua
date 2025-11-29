--[[
	ClientPathfinding - NoobPath wrapper for client-side NPC pathfinding

	This mirrors the server-side PathfindingManager but runs on the client
	for UseAnimationController NPCs.

	Uses the same NoobPath library for consistent behavior.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientPathfinding = {}

---- Dependencies
local NoobPath = require(ReplicatedStorage.SharedSource.Utilities.Pathfinding.NoobPath)
local RenderConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.RenderConfig)
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

--[[
	Create NoobPath instance for client-side NPC

	@param npcData table - Client-side NPC data
	@param visualModel Model - The visual NPC model with Humanoid
	@return NoobPath? - Configured pathfinding instance or nil
]]
function ClientPathfinding.CreatePath(npcData, visualModel)
	if not visualModel then
		return nil
	end

	local humanoid = visualModel:FindFirstChild("Humanoid")
	if not humanoid then
		warn("[ClientPathfinding] Visual model missing Humanoid for NPC:", npcData.ID)
		return nil
	end

	-- Get pathfinding config
	local pathConfig = OptimizationConfig.ClientPathfinding

	-- Create NoobPath instance (same pattern as PathfindingManager)
	local path = NoobPath.Humanoid(visualModel, {
		AgentRadius = pathConfig.AGENT_RADIUS,
		AgentHeight = pathConfig.AGENT_HEIGHT,
		AgentCanJump = pathConfig.AGENT_CAN_JUMP,
		WaypointSpacing = pathConfig.WAYPOINT_SPACING,
		Costs = pathConfig.TERRAIN_COSTS,
	})

	-- Configure path settings
	path.Timeout = true -- Enable timeout detection
	path.Speed = npcData.Config.WalkSpeed or humanoid.WalkSpeed

	-- Show visualizer in debug mode
	if RenderConfig.DEBUG_MODE then
		path.Visualize = true
	end

	-- Setup automatic speed synchronization
	local speedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if path then
			path.Speed = humanoid.WalkSpeed
		end
	end)

	-- Store connection for cleanup
	npcData.PathfindingConnections = npcData.PathfindingConnections or {}
	table.insert(npcData.PathfindingConnections, speedConnection)

	-- Setup error handling
	path.Error:Connect(function(errorType)
		ClientPathfinding.HandlePathError(npcData, errorType)
	end)

	-- Setup trapped detection (stuck/blocked)
	path.Trapped:Connect(function(reason)
		ClientPathfinding.HandlePathBlocked(npcData, visualModel, reason)
	end)

	return path
end

--[[
	Handle pathfinding errors

	@param npcData table - NPC data
	@param errorType string - Error type from NoobPath
]]
function ClientPathfinding.HandlePathError(npcData, errorType)
	if errorType == "ComputationError" then
		warn("[ClientPathfinding] Computation error for NPC:", npcData.ID)
		npcData.Destination = nil
	elseif errorType == "TargetUnreachable" then
		-- Target is unreachable, clear destination
		npcData.Destination = nil
	elseif errorType == "AgentStuck" then
		-- Agent is stuck, try to unstuck
		npcData.Destination = nil
	end
end

--[[
	Handle NPC being blocked/stuck
	Client-side jump handling

	@param npcData table - NPC data
	@param visualModel Model - The visual model
	@param reason string - Reason for being blocked
]]
function ClientPathfinding.HandlePathBlocked(npcData, visualModel, reason)
	local humanoid = visualModel and visualModel:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	if reason == "ReachTimeout" then
		-- Try jumping to unstuck
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		npcData.IsJumping = true
		npcData.JumpVelocity = npcData.Config.JumpPower or 50
	elseif reason == "ReachFailed" then
		-- Clear destination and retry
		npcData.Destination = nil
	end
end

--[[
	Run pathfinding to destination

	@param npcData table - NPC data
	@param visualModel Model - The visual model
	@param destination Vector3 - Target destination
]]
function ClientPathfinding.RunPath(npcData, visualModel, destination)
	if not npcData.Pathfinding then
		npcData.Pathfinding = ClientPathfinding.CreatePath(npcData, visualModel)
	end

	if npcData.Pathfinding then
		npcData.Pathfinding:Run(destination)
	end
end

--[[
	Stop pathfinding

	@param npcData table - NPC data
]]
function ClientPathfinding.StopPath(npcData)
	if npcData.Pathfinding then
		pcall(function()
			npcData.Pathfinding:Stop()
		end)
	end
end

--[[
	Cleanup pathfinding for NPC

	@param npcData table - NPC data
]]
function ClientPathfinding.Cleanup(npcData)
	-- Stop pathfinding
	ClientPathfinding.StopPath(npcData)

	-- Disconnect connections
	if npcData.PathfindingConnections then
		for _, connection in pairs(npcData.PathfindingConnections) do
			if connection then
				pcall(function()
					connection:Disconnect()
				end)
			end
		end
		npcData.PathfindingConnections = nil
	end

	-- Clear pathfinding instance
	if npcData.Pathfinding then
		pcall(function()
			npcData.Pathfinding:Dump()
		end)
		npcData.Pathfinding = nil
	end
end

--[[
	Check if pathfinding is active for NPC

	@param npcData table - NPC data
	@return boolean
]]
function ClientPathfinding.IsPathfindingActive(npcData)
	return npcData.Pathfinding ~= nil
end

function ClientPathfinding.Start()
	-- Component start
end

function ClientPathfinding.Init()
	-- Component init
end

return ClientPathfinding
