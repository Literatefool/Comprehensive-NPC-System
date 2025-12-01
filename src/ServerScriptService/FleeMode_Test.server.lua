--[[
	FleeMode Movement Behavior Test Script

	Tests the FleeMode movement behavior for NPCs that flee from detected targets.

	Usage:
	1. Run this script in Studio
	2. Approach the spawned NPCs
	3. Observe NPCs fleeing away from you
	4. Move away to see NPCs return to idle wandering
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for Knit to initialize
local Knit = require(ReplicatedStorage.Packages.Knit)
Knit.OnStart():await()

local NPC_Service = Knit.GetService("NPC_Service")

print("\n" .. string.rep("=", 50))
print("FLEEMODE MOVEMENT BEHAVIOR TEST")
print("Testing NPCs that flee from detected targets")
print(string.rep("=", 50) .. "\n")

-- Get spawners from Workspace
local Workspace = game:GetService("Workspace")
local spawnersFolder = Workspace:FindFirstChild("Spawners")
	and Workspace.Spawners:FindFirstChild("Scared-NPC")

if not spawnersFolder then
	warn("No spawners found at: Workspace.Spawners.Scared-NPC")
	return
end

-- Collect spawners (NPC_Spawner_1 to NPC_Spawner_4)
local spawners = {}
for i = 1, 4 do
	local spawner = spawnersFolder:FindFirstChild("NPC_Spawner_" .. i)
	if spawner then
		table.insert(spawners, spawner)
	else
		warn("Missing spawner: NPC_Spawner_" .. i)
	end
end

if #spawners == 0 then
	warn("No valid spawners found!")
	return
end

print("Found " .. #spawners .. " spawners")

-- Use the rig from ReplicatedStorage
local rigModel = ReplicatedStorage:WaitForChild("Assets", 10)
	and ReplicatedStorage.Assets:WaitForChild("NPCs", 10)
	and ReplicatedStorage.Assets.NPCs:WaitForChild("Characters", 10)
	and ReplicatedStorage.Assets.NPCs.Characters:WaitForChild("Rig", 10)

if not rigModel then
	warn("No rig model found at: ReplicatedStorage.Assets.NPCs.Characters.Rig")
	return
end

-- Store spawned NPCs for cleanup
local testNPCs = {}

-- ============================================
-- Spawn FleeMode NPCs at each spawner
-- ============================================
print("\nSpawning FleeMode NPCs at spawner locations...")

for i, spawner in ipairs(spawners) do
	local spawnPos = spawner.Position

	local npc = NPC_Service:SpawnNPC({
		Name = "FleeNPC_" .. i,
		Position = spawnPos,
		ModelPath = rigModel,

		-- Stats
		MaxHealth = 100,
		WalkSpeed = 16,
		JumpPower = 50,

		-- FleeMode Behavior
		SightRange = 40,
		SightMode = "Omnidirectional",
		MovementMode = "Flee",
		EnableIdleWander = true,
		EnableCombatMovement = true,
		UsePathfinding = true,

		-- Flee-specific configuration
		FleeSpeedMultiplier = 1.3,
		FleeSafeDistanceFactor = 1.5,
		FleeDistanceFactor = 1.5,

		-- Visual customization
		ClientRenderData = {
			Scale = 1.0,
			CustomColor = Color3.fromRGB(255, 200, 100), -- Yellow/gold for flee NPCs
			Transparency = 0,
		},

		CustomData = {
			Faction = "Civilian",
			NPCType = "Fleeing",
		},
	})

	if npc then
		table.insert(testNPCs, npc)
		print("  Spawned FleeNPC_" .. i .. " at " .. spawner.Name)
	else
		warn("  Failed to spawn FleeNPC_" .. i)
	end
end

-- ============================================
-- TEST SUMMARY
-- ============================================
print("\n" .. string.rep("=", 50))
print("FLEEMODE TEST SUMMARY")
print(string.rep("=", 50))
print("Total NPCs spawned: " .. #testNPCs)
print("")
print("TEST INSTRUCTIONS:")
print("  1. Walk toward the NPCs - they should flee from you")
print("  2. Move away and watch NPCs return to idle wandering")
print(string.rep("=", 50) .. "\n")

-- Cleanup function
local function cleanupTest()
	print("\nCleaning up FleeMode test NPCs...")
	for _, npc in pairs(testNPCs) do
		if npc then
			if typeof(npc) == "Instance" and npc.Parent then
				NPC_Service:DestroyNPC(npc)
			elseif typeof(npc) == "string" then
				-- Client physics NPC (stored as ID)
				NPC_Service:DestroyClientPhysicsNPC(npc)
			end
		end
	end
	print("FleeMode test cleanup complete")
end

-- Expose cleanup function globally for manual cleanup
_G.CleanupFleeModeTest = cleanupTest

print("Run _G.CleanupFleeModeTest() to manually cleanup NPCs")
