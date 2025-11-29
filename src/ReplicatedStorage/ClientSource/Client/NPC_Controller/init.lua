local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local NPC_Controller = Knit.CreateController({
	Name = "NPC_Controller",
})

---- Configuration
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 5)
NPC_Controller.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	NPC_Controller.Components[v.Name] = require(v)
end
NPC_Controller.GetComponent = require(componentsFolder["Get()"])
NPC_Controller.SetComponent = require(componentsFolder["Set()"])

---- Knit Services

---- Knit Controllers

function NPC_Controller:KnitStart()
	-- Check if UseAnimationController system should be active
	-- This runs after all components are initialized
	if OptimizationConfig.UseAnimationController then
		print("[NPC_Controller] UseAnimationController is enabled globally")
	end

	-- The ClientNPCManager will detect and handle client-physics NPCs
	-- even if the global flag is false (per-NPC override)
end

function NPC_Controller:KnitInit()
	componentsInitializer(script)
end

return NPC_Controller
