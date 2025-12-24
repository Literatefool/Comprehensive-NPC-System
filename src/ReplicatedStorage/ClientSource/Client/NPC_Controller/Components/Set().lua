--[[
	NPC_Controller Set Component
	
	Purpose: Control methods for client-side NPC rendering
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Set = {}

local NPCRenderer
local RenderConfig

--[[
	Set custom render callback
	
	Allows developers to override default NPC rendering with custom logic
	
	@param callback function(npc: Model, renderData: table): Model? - Custom render function
]]
function Set:SetCustomRenderCallback(callback)
	if NPCRenderer then
		NPCRenderer.CustomRenderCallback = callback
	end
end

--[[
	Manually trigger rendering for a specific NPC
	
	@param npc Model - Server NPC model to render
]]
function Set:RenderNPC(npc)
	if NPCRenderer and RenderConfig.ENABLED then
		NPCRenderer.RenderNPC(npc)
	end
end

--[[
	Manually cleanup/unrender a specific NPC
	
	@param npc Model - Server NPC model to cleanup
]]
function Set:CleanupNPC(npc)
	if NPCRenderer then
		NPCRenderer.CleanupNPC(npc)
	end
end

function Set.Start()
	-- Component start logic
end

function Set.Init()
	NPCRenderer = require(script.Parent.Others.Rendering.NPCRenderer)
	RenderConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.RenderConfig)
end

return Set
