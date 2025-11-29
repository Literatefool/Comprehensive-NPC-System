--[[
	ClientMovement - Movement behavior logic for UseAnimationController NPCs

	Handles:
	- Different movement modes (Ranged, Melee)
	- Combat positioning
	- Idle wandering patterns
	- Movement state management

	This is a helper module used by ClientNPCSimulator.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClientMovement = {}

---- Configuration
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

---- Constants
local RANGED_DISTANCE_FACTOR = 0.7 -- Stay at 70% of sight range for ranged
local MELEE_MIN_DISTANCE = 2 -- Minimum distance for melee
local MELEE_MAX_DISTANCE = 8 -- Maximum distance for melee (default)
local STRAFE_CHANCE = 0.3 -- 30% chance to strafe during combat
local STRAFE_DURATION = 1.5 -- How long to strafe (seconds)
local STRAFE_DISTANCE = 5 -- How far to strafe

--[[
	Calculate combat position based on movement mode

	@param npcData table - NPC data
	@param targetPosition Vector3 - Target's position
	@return Vector3 - Desired position for combat
]]
function ClientMovement.CalculateCombatPosition(npcData, targetPosition)
	local currentPos = npcData.Position
	local config = npcData.Config

	local direction = targetPosition - currentPos
	direction = Vector3.new(direction.X, 0, direction.Z)
	local distance = direction.Magnitude

	if distance < 0.1 then
		return currentPos
	end

	direction = direction.Unit

	local desiredDistance

	if config.MovementMode == "Melee" then
		-- Melee: get close to target
		local meleeRange = config.MeleeOffsetRange or MELEE_MAX_DISTANCE
		desiredDistance = math.random(MELEE_MIN_DISTANCE, meleeRange)
	else
		-- Ranged: stay at safe distance
		local sightRange = config.SightRange or 200
		desiredDistance = sightRange * RANGED_DISTANCE_FACTOR
	end

	-- Calculate desired position
	local desiredPos = targetPosition - direction * desiredDistance

	return desiredPos
end

--[[
	Calculate strafe position for combat variety

	@param npcData table - NPC data
	@param targetPosition Vector3 - Target's position
	@return Vector3 - Strafe destination
]]
function ClientMovement.CalculateStrafePosition(npcData, targetPosition)
	local currentPos = npcData.Position

	-- Calculate perpendicular direction
	local toTarget = targetPosition - currentPos
	toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)

	if toTarget.Magnitude < 0.1 then
		return currentPos
	end

	toTarget = toTarget.Unit

	-- Perpendicular directions (left or right)
	local perpendicular
	if math.random() > 0.5 then
		perpendicular = Vector3.new(-toTarget.Z, 0, toTarget.X) -- Left
	else
		perpendicular = Vector3.new(toTarget.Z, 0, -toTarget.X) -- Right
	end

	return currentPos + perpendicular * STRAFE_DISTANCE
end

--[[
	Calculate idle wander destination

	@param npcData table - NPC data
	@return Vector3 - Wander destination
]]
function ClientMovement.CalculateWanderDestination(npcData)
	local config = npcData.Config

	-- Get spawn position
	local spawnPos
	if config.SpawnPosition then
		spawnPos = Vector3.new(
			config.SpawnPosition.X,
			config.SpawnPosition.Y,
			config.SpawnPosition.Z
		)
	else
		spawnPos = npcData.Position
	end

	-- Random wander within bounds
	local wanderRadius = math.min(
		config.MaxWanderRadius or OptimizationConfig.ExploitMitigation.DEFAULT_MAX_WANDER_RADIUS,
		50 -- Default wander radius for idle
	)

	local angle = math.random() * math.pi * 2
	local distance = math.random() * wanderRadius

	local offsetX = math.cos(angle) * distance
	local offsetZ = math.sin(angle) * distance

	return spawnPos + Vector3.new(offsetX, 0, offsetZ)
end

--[[
	Determine if NPC should strafe during combat

	@param npcData table - NPC data
	@return boolean
]]
function ClientMovement.ShouldStrafe(npcData)
	-- Only strafe in ranged mode or when has target
	if not npcData.CurrentTarget then
		return false
	end

	-- Check if currently strafing
	if npcData.StrafeEndTime and tick() < npcData.StrafeEndTime then
		return true
	end

	-- Random chance to start strafing
	if math.random() < STRAFE_CHANCE then
		npcData.StrafeEndTime = tick() + STRAFE_DURATION
		return true
	end

	return false
end

--[[
	Update movement state based on current situation

	@param npcData table - NPC data
	@return string - New movement state
]]
function ClientMovement.DetermineMovementState(npcData)
	-- Check if has target
	if npcData.CurrentTarget then
		local targetPart = npcData.CurrentTarget:FindFirstChild("HumanoidRootPart")
			or npcData.CurrentTarget.PrimaryPart

		if targetPart then
			local distance = (npcData.Position - targetPart.Position).Magnitude
			local config = npcData.Config

			if config.MovementMode == "Melee" then
				local meleeRange = config.MeleeOffsetRange or MELEE_MAX_DISTANCE
				if distance <= meleeRange then
					return "CombatMelee"
				else
					return "CombatApproaching"
				end
			else
				local sightRange = config.SightRange or 200
				local desiredDistance = sightRange * RANGED_DISTANCE_FACTOR

				if math.abs(distance - desiredDistance) < 5 then
					return "CombatRanged"
				elseif distance > desiredDistance then
					return "CombatApproaching"
				else
					return "CombatRetreating"
				end
			end
		end
	end

	-- Check if moving to destination
	if npcData.Destination then
		return "Moving"
	end

	return "Idle"
end

--[[
	Calculate movement speed modifier based on state

	@param npcData table - NPC data
	@return number - Speed multiplier (1.0 = normal)
]]
function ClientMovement.GetSpeedModifier(npcData)
	local state = npcData.MovementState or "Idle"

	if state == "CombatRetreating" then
		return 1.2 -- Move faster when retreating
	elseif state == "CombatApproaching" then
		return 1.0 -- Normal speed when approaching
	elseif state == "CombatMelee" or state == "CombatRanged" then
		return 0.5 -- Slower when in combat position (strafing)
	end

	return 1.0
end

--[[
	Calculate facing direction for NPC

	@param npcData table - NPC data
	@return CFrame - Orientation to face
]]
function ClientMovement.CalculateFacing(npcData)
	local position = npcData.Position

	-- If has target, face target
	if npcData.CurrentTarget then
		local targetPart = npcData.CurrentTarget:FindFirstChild("HumanoidRootPart")
			or npcData.CurrentTarget.PrimaryPart

		if targetPart then
			local targetPos = targetPart.Position
			local lookAt = Vector3.new(targetPos.X, position.Y, targetPos.Z)
			return CFrame.lookAt(position, lookAt)
		end
	end

	-- If moving to destination, face movement direction
	if npcData.Destination then
		local destPos = npcData.Destination
		local lookAt = Vector3.new(destPos.X, position.Y, destPos.Z)
		local direction = lookAt - position

		if direction.Magnitude > 0.1 then
			return CFrame.lookAt(position, lookAt)
		end
	end

	-- Keep current orientation
	return npcData.Orientation or CFrame.new(position)
end

--[[
	Check if NPC has reached destination

	@param npcData table - NPC data
	@param threshold number? - Distance threshold (default: 2)
	@return boolean
]]
function ClientMovement.HasReachedDestination(npcData, threshold)
	threshold = threshold or 2

	if not npcData.Destination then
		return true
	end

	local distance = (npcData.Position - npcData.Destination).Magnitude
	return distance < threshold
end

--[[
	Check if NPC should pursue target

	@param npcData table - NPC data
	@return boolean
]]
function ClientMovement.ShouldPursueTarget(npcData)
	if not npcData.CurrentTarget then
		return false
	end

	if not npcData.Config.EnableCombatMovement then
		return false
	end

	local targetPart = npcData.CurrentTarget:FindFirstChild("HumanoidRootPart")
		or npcData.CurrentTarget.PrimaryPart

	if not targetPart then
		return false
	end

	local distance = (npcData.Position - targetPart.Position).Magnitude
	local sightRange = npcData.Config.SightRange or 200

	-- Pursue if within sight range
	return distance <= sightRange * 1.2 -- 20% buffer
end

function ClientMovement.Start()
	-- Component start
end

function ClientMovement.Init()
	-- Component init
end

return ClientMovement
