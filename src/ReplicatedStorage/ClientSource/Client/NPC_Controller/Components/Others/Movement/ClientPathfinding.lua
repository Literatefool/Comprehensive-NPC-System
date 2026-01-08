--[[
	ClientPathfinding - NoobPath wrapper for client-side NPC pathfinding

	ARCHITECTURE OVERVIEW:
	----------------------
	This mirrors the server-side PathfindingManager but runs on the client
	for UseClientPhysics NPCs with custom physics.

	KEY DIFFERENCES FROM SERVER:
	-----------------------------
	Server (PathfindingManager):
	- Uses NoobPath in NORMAL mode (automatic Humanoid movement)
	- NoobPath calls Humanoid:MoveTo() to move NPCs
	- Physical HumanoidRootPart exists on server
	- Roblox physics engine handles collision

	Client (ClientPathfinding):
	- Uses NoobPath in MANUAL mode (compute paths only)
	- NoobPath does NOT move the visual model
	- ClientNPCSimulator reads waypoints and updates npcData.Position
	- ClientPhysicsRenderer syncs visual model to npcData.Position
	- No physics - purely visual positioning

	HOW IT WORKS:
	-------------
	1. ClientPathfinding.CreatePath() creates NoobPath with ManualMovement=true
	2. ClientPathfinding.RunPath() starts path computation
	3. NoobPath generates waypoints but doesn't move anything
	4. ClientNPCSimulator reads current waypoint via GetWaypoint()
	5. ClientNPCSimulator updates npcData.Position toward waypoint
	6. When close enough, ClientNPCSimulator calls AdvanceWaypoint()
	7. Repeat steps 4-6 until destination reached

	VISUAL MODEL SYNC:
	------------------
	The visual model is NOT moved by pathfinding directly:
	- npcData.Position is the source of truth
	- ClientPhysicsRenderer syncs visual model CFrame to npcData.Position every RenderStepped
	- This keeps pathfinding logic separate from rendering

	BACKWARDS COMPATIBILITY:
	------------------------
	Server-side NPCs continue using PathfindingManager (normal NoobPath mode).
	This code ONLY affects client-side NPCs with UseClientPhysics=true.

	Uses the same NoobPath library for consistent pathfinding behavior.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientPathfinding = {}

---- Dependencies
local NoobPath = require(ReplicatedStorage.SharedSource.Utilities.Pathfinding.NoobPath)
local GoodSignal = require(ReplicatedStorage.SharedSource.Utilities.Pathfinding.NoobPath.GoodSignal)
local RenderConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.RenderConfig)
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

--[[
	Create NoobPath instance for client-side NPC

	Supports both Humanoid mode and AnimationController mode:
	- Humanoid mode: Uses NoobPath.Humanoid() constructor
	- AnimationController mode: Uses NoobPath.new() with dummy signals

	Both modes use ManualMovement=true since ClientNPCSimulator handles position updates.

	@param npcData table - Client-side NPC data
	@param visualModel Model - The visual NPC model (with Humanoid or AnimationController)
	@return NoobPath? - Configured pathfinding instance or nil
]]
function ClientPathfinding.CreatePath(npcData, visualModel)
	if not visualModel then
		return nil
	end

	-- Get pathfinding config
	local pathConfig = OptimizationConfig.ClientPathfinding
	local agentParams = {
		AgentRadius = pathConfig.AGENT_RADIUS,
		AgentHeight = pathConfig.AGENT_HEIGHT,
		AgentCanJump = pathConfig.AGENT_CAN_JUMP,
		WaypointSpacing = pathConfig.WAYPOINT_SPACING,
		Costs = pathConfig.TERRAIN_COSTS,
	}

	local humanoid = visualModel:FindFirstChild("Humanoid")
	local path

	if humanoid then
		-- Humanoid mode: Use standard NoobPath.Humanoid constructor
		path = NoobPath.Humanoid(
			visualModel,
			agentParams,
			false, -- Precise (not needed for manual movement)
			true -- ManualMovement mode (only compute paths, don't auto-move)
		)

		-- Setup automatic speed synchronization (Humanoid mode only)
		local speedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if path then
				path.Speed = humanoid.WalkSpeed
			end
		end)

		-- Store connection for cleanup
		npcData.PathfindingConnections = npcData.PathfindingConnections or {}
		table.insert(npcData.PathfindingConnections, speedConnection)
	else
		-- AnimationController mode: Use NoobPath.new() with dummy signals
		-- In ManualMovement mode, Move/Jump functions are never called,
		-- so we can use empty functions and fake signals
		local dummyMove = function() end
		local dummyJump = function() end
		local dummyMoveFinished = GoodSignal.new()
		local dummyJumpFinished = GoodSignal.new()

		path = NoobPath.new(
			visualModel,
			agentParams,
			dummyMove,
			dummyJump,
			dummyJumpFinished,
			dummyMoveFinished
		)

		-- Enable manual movement mode
		path.ManualMovement = true
	end

	-- Configure path settings
	path.Timeout = true -- Enable timeout detection
	path.Speed = npcData.Config.WalkSpeed or 16

	-- Show path visualizer if enabled (configured in RenderConfig)
	if RenderConfig.SHOW_PATH_VISUALIZER then
		path.Visualize = true
	end

	-- Setup error handling
	path.Error:Connect(function(errorType)
		ClientPathfinding.HandlePathError(npcData, errorType)
	end)

	-- Setup trapped detection (stuck/blocked)
	path.Trapped:Connect(function(reason)
		ClientPathfinding.HandlePathBlocked(npcData, visualModel, reason)
	end)

	-- Setup reached detection (destination arrived)
	path.Reached:Connect(function(waypoint, partial)
		-- In manual mode, Reached shouldn't clear destination until we confirm arrival
		-- The simulator will clear it when actually at destination
		if not npcData.Pathfinding or not npcData.Pathfinding.ManualMovement then
			npcData.Destination = nil
		end
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
		-- Computation failed - clear destination after retries
		npcData._pathErrorCount = (npcData._pathErrorCount or 0) + 1
		if npcData._pathErrorCount > 3 then
			npcData.Destination = nil
			npcData._pathErrorCount = 0
		end
	elseif errorType == "TargetUnreachable" then
		-- Target unreachable - this might be a false positive due to async pathfinding
		-- Don't clear destination immediately, let rate limiting handle retries
		npcData._pathUnreachableCount = (npcData._pathUnreachableCount or 0) + 1

		-- Only clear after multiple consecutive failures
		if npcData._pathUnreachableCount > 5 then
			npcData.Destination = nil
			npcData._pathUnreachableCount = 0
		end
	elseif errorType == "AgentStuck" then
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
	if reason == "ReachTimeout" then
		-- Try jumping to unstuck
		-- Works with both Humanoid and AnimationController modes
		local humanoid = visualModel and visualModel:FindFirstChild("Humanoid")
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
		-- Also set npcData jump state for client simulation
		npcData.IsJumping = true
		npcData.JumpVelocity = npcData.Config.JumpPower or 50
	elseif reason == "ReachFailed" then
		-- Clear destination and retry
		npcData.Destination = nil
	end
end

--[[
	Run pathfinding to destination (ASYNC - non-blocking)

	Path computation runs in background thread. NPC continues moving with
	old waypoints until new path is ready. This prevents stuttering/pausing
	during path recomputation.

	If called while a previous computation is running, the old one is cancelled
	and a new computation starts with the updated destination.

	@param npcData table - NPC data
	@param visualModel Model - The visual model
	@param destination Vector3 - Target destination
]]
function ClientPathfinding.RunPath(npcData, visualModel, destination)
	-- Respect UsePathfinding config: if false, don't use pathfinding
	local usePathfinding = npcData.Config.UsePathfinding
	if usePathfinding == nil then
		usePathfinding = true -- Default to true if not specified
	end

	if not usePathfinding then
		return -- Let SimulateMovement use fallback direct movement
	end

	-- Convert destination to ground-level coordinates (NoobPath expects Y ≈ 0)
	-- Pathfinding works on ground plane, not character height
	local groundDestination = Vector3.new(destination.X, 0, destination.Z)

	if not npcData.Pathfinding then
		npcData.Pathfinding = ClientPathfinding.CreatePath(npcData, visualModel)
	end

	if npcData.Pathfinding then
		-- Increment version to cancel any in-progress computation (wrap at 100)
		local newVersion = ((npcData._pathVersion or 0) % 100) + 1
		npcData._pathVersion = newVersion
		local thisVersion = newVersion

		-- Run path computation in background thread
		task.spawn(function()
			-- Safety check in case NPC was destroyed during yield
			if not npcData.Pathfinding then
				return
			end

			-- Compute the path (this is the blocking call)
			npcData.Pathfinding:Run(groundDestination)

			-- Check if this computation was cancelled (newer one started)
			if npcData._pathVersion ~= thisVersion then
				return -- Cancelled, discard results
			end

			-- Safety check in case NPC was destroyed during computation
			if not npcData.Pathfinding then
				return
			end

			-- Reset error counters on successful path start
			if not npcData.Pathfinding.Idle and #npcData.Pathfinding.Route > 0 then
				npcData._pathErrorCount = 0
				npcData._pathUnreachableCount = 0
			end

			--[[
				FIX: Find correct starting waypoint after async computation

				Problem: While path was computing, NPC continued moving. The computed
				path starts from where the NPC WAS, but NPC is now further along.

				Solution: Find the first waypoint that is AHEAD of the current
				npcData.Position (not behind it). Skip waypoints we've already passed.
			]]
			if npcData.Pathfinding.ManualMovement and not npcData.Pathfinding.Idle then
				local route = npcData.Pathfinding.Route
				local currentPos = npcData.Position
				local posFlat = Vector3.new(currentPos.X, 0, currentPos.Z)

				-- Find the best starting waypoint
				local bestIndex = 1
				local skippedCount = 0
				for i = 1, math.min(#route - 1, 3) do -- Check first 3 waypoints max
					local wp = route[i].Position
					local nextWp = route[i + 1] and route[i + 1].Position

					if nextWp then
						local wpFlat = Vector3.new(wp.X, 0, wp.Z)
						local nextWpFlat = Vector3.new(nextWp.X, 0, nextWp.Z)

						local distWpToNext = (nextWpFlat - wpFlat).Magnitude
						local distPosToNext = (nextWpFlat - posFlat).Magnitude

						-- If we're closer to the next waypoint than the current waypoint is,
						-- we've already passed the current waypoint - skip it
						if distPosToNext < distWpToNext then
							bestIndex = i + 1
							skippedCount = skippedCount + 1
						else
							break -- Found a waypoint we haven't passed
						end
					end
				end

				npcData.Pathfinding.Index = bestIndex
			end
		end)
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

	-- Cancel any in-progress async computation
	npcData._pathVersion = nil

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
	-- IMPORTANT: Use Destroy() not Dump() - Destroy() disconnects MoveFinishedC/JumpFinishedC
	-- before clearing the object. Dump() leaves those connections active, causing
	-- "attempt to call missing method" errors when Humanoid.MoveToFinished fires
	-- after the NoobPath metatable has been removed.
	if npcData.Pathfinding then
		pcall(function()
			npcData.Pathfinding:Destroy()
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
