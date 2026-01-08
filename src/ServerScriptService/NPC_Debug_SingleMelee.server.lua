--[[
	DEBUG: Spawns a single Melee NPC for pathfinding debugging

	Use with [PF_DBG] prints in ClientNPCSimulator and ClientPathfinding
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Wait for Knit to initialize
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

-- comment out to enable debug test
if true then
	return
end

local NPC_Service = Knit.GetService("NPC_Service")

print("\n" .. string.rep("=", 50))
print("[PF_DBG] SINGLE MELEE NPC DEBUG TEST")
print(string.rep("=", 50) .. "\n")

-- Get rig model
local rigModel = ReplicatedStorage:WaitForChild("Assets", 10)
	and ReplicatedStorage.Assets:WaitForChild("NPCs", 10)
	and ReplicatedStorage.Assets.NPCs:WaitForChild("Characters", 10)
	and ReplicatedStorage.Assets.NPCs.Characters:WaitForChild("Rig", 10)

if not rigModel then
	warn("[PF_DBG] No rig model found!")
	return
end

-- Find a melee spawner
local spawnerPart = nil
local spawners = Workspace:FindFirstChild("Spawners")
if spawners then
	local meleeFolder = spawners:FindFirstChild("Melee")
	if meleeFolder then
		for _, spawner in pairs(meleeFolder:GetChildren()) do
			if spawner:IsA("BasePart") then
				spawnerPart = spawner
				break
			elseif spawner:IsA("Model") and spawner.PrimaryPart then
				spawnerPart = spawner.PrimaryPart
				break
			end
		end
	end
end

-- Spawn config
local spawnConfig = {
	Name = "DEBUG_MELEE_NPC",
	ModelPath = rigModel,

	-- Stats
	MaxHealth = 100,
	WalkSpeed = 16,
	JumpPower = 50,

	-- Behavior - MELEE MODE
	SightRange = 60,
	SightMode = "Omnidirectional",
	MovementMode = "Melee",
	UsePathfinding = true,
	CanWalk = true,
	EnableIdleWander = false, -- Disable wander so it only moves when chasing
	EnableCombatMovement = true,

	ClientRenderData = {
		Scale = 1.0,
	},

	CustomData = {
		Faction = "Enemy",
		EnemyType = "Melee",
	},
}

-- Use spawner or fallback position
if spawnerPart then
	spawnConfig.SpawnerPart = spawnerPart
	print("[PF_DBG] Using spawner:", spawnerPart:GetFullName())
else
	spawnConfig.Position = Vector3.new(0, 10, 0)
	print("[PF_DBG] No spawner found, using default position")
end

-- Spawn the NPC
local debugNPC = NPC_Service:SpawnNPC(spawnConfig)

if debugNPC then
	print("[PF_DBG] Spawned DEBUG_MELEE_NPC successfully!")
	print("[PF_DBG] Now walk around to trigger combat movement and watch for teleports")
else
	warn("[PF_DBG] Failed to spawn debug NPC!")
end
