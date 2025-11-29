# UseAnimationController - Client-Side Components

This document covers all client-side components for the `UseAnimationController` feature, including the NPC manager, pathfinding, jump simulation, and rendering.

**Parent Document**: [Main.md](./Main.md)

---

## Table of Contents

1. [Important: Two Rendering Systems](#important-two-rendering-systems)
2. [Client-Side NPC Manager](#1-client-side-npc-manager)
3. [Client-Side Pathfinding (NoobPath)](#2-client-side-pathfinding-noobpath)
4. [Client-Side Jump Simulation](#3-client-side-jump-simulation)
5. [Client Physics Renderer](#4-client-physics-renderer)

---

## Important: Two Rendering Systems

The NPC system supports **two different rendering approaches**, each with its own renderer:

| Feature             | NPCRenderer.lua                     | ClientPhysicsRenderer.lua           |
| ------------------- | ----------------------------------- | ----------------------------------- |
| **Purpose**         | Render visuals on server NPCs       | Render full NPCs from position data |
| **When Used**       | `UseAnimationController = false`    | `UseAnimationController = true`     |
| **Server Model**    | Full NPC with HumanoidRootPart      | No physical model (data only)       |
| **What It Renders** | Visual parts welded to server model | Complete standalone model           |
| **Position Source** | Server NPC's HumanoidRootPart       | ReplicatedStorage position data     |
| **Collision**       | Server handles                      | No collision (visual only)          |
| **Physics**         | Server-side                         | Client-side                         |
| **Health Display**  | Optional client visuals             | Reads from server health values     |

**Why Two Systems?**

- **Traditional Approach**: Server has full physics control, client renders visuals on top
- **Client Physics Approach**: Server stores position/health only, client handles everything else
- Both systems can run simultaneously (different NPCs can use different approaches)
- `ClientPhysicsRenderer` is specifically for the advanced optimization feature

---

## 1. Client-Side NPC Manager

**Location**: `NPC_Controller/Components/Others/ClientNPCManager.lua`

**Responsibilities**:

- Monitor `ReplicatedStorage.ActiveNPCs` for new NPCs
- Assign NPCs to clients based on distance
- Handle NPC creation, simulation, and cleanup
- Synchronize positions back to server

```lua
local ClientNPCManager = {}

-- Track which NPCs this client is simulating
local SimulatedNPCs = {}  -- [npcID] = npcData

-- Track which NPCs are visible (rendered)
local RenderedNPCs = {}   -- [npcID] = visualModel

function ClientNPCManager.Init()
    -- Watch for new NPCs in ReplicatedStorage
    local activeNPCsFolder = ReplicatedStorage:WaitForChild("ActiveNPCs")

    activeNPCsFolder.ChildAdded:Connect(function(npcFolder)
        ClientNPCManager.OnNPCAdded(npcFolder)
    end)

    -- Handle existing NPCs
    for _, npcFolder in activeNPCsFolder:GetChildren() do
        ClientNPCManager.OnNPCAdded(npcFolder)
    end

    -- Start simulation loop
    RunService.Heartbeat:Connect(ClientNPCManager.SimulationStep)

    -- Start distance check loop
    task.spawn(ClientNPCManager.DistanceCheckLoop)
end

function ClientNPCManager.OnNPCAdded(npcFolder)
    local npcID = npcFolder.Name

    -- Determine if this client should simulate this NPC
    local shouldSimulate = ClientNPCManager.ShouldSimulateNPC(npcFolder)

    if shouldSimulate then
        ClientNPCManager.StartSimulation(npcFolder)
    else
        -- Just render if nearby, don't simulate
        ClientNPCManager.CheckRenderDistance(npcFolder)
    end
end

function ClientNPCManager.ShouldSimulateNPC(npcFolder): boolean
    -- Distribute NPCs across clients based on distance
    -- Closest client simulates the NPC

    local position = npcFolder.Position.Value
    local localPlayer = Players.LocalPlayer

    if not localPlayer.Character or not localPlayer.Character.PrimaryPart then
        return false
    end

    local distance = (localPlayer.Character.PrimaryPart.Position - position).Magnitude

    -- Simple distribution: closest client simulates
    -- TODO: More advanced load balancing
    return distance <= 200  -- Simulate NPCs within 200 studs
end

return ClientNPCManager
```

---

## 2. Client-Side Pathfinding (NoobPath)

**Location**: `NPC_Controller/Components/Others/ClientPathfinding.lua`

**Purpose**: Handle all pathfinding on the client using **NoobPath** (same library as server-side PathfindingManager)

**Note**: We use NoobPath instead of raw PathfindingService because it provides:

- Better jump handling
- Timeout detection
- Visualization support for debugging
- Error handling built-in
- Similar API to server-side PathfindingManager

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientPathfinding = {}

-- Import NoobPath (same as server-side PathfindingManager)
local NoobPath = require(ReplicatedStorage.SharedSource.Utilities.Pathfinding.NoobPath)

--[[
    Create NoobPath instance for client-side NPC
    Similar to PathfindingManager.CreatePath but for client simulation

    @param npcData table - Client-side NPC data
    @param visualModel Model - The visual NPC model with Humanoid
    @return NoobPath - Configured pathfinding instance
]]
function ClientPathfinding.CreatePath(npcData, visualModel)
    local humanoid = visualModel:FindFirstChild("Humanoid")
    if not humanoid then
        warn("[ClientPathfinding] Visual model missing Humanoid")
        return nil
    end

    -- Create NoobPath instance (same pattern as PathfindingManager)
    local path = NoobPath.Humanoid(visualModel, {
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,  -- Client handles jumps
        WaypointSpacing = 4,
        Costs = {
            Water = math.huge,  -- Avoid water
        },
    })

    -- Configure path settings
    path.Timeout = true  -- Enable timeout detection
    path.Speed = humanoid.WalkSpeed

    -- Show visualizer in debug mode (optional)
    local RenderConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.RenderConfig)
    if RenderConfig.DEBUG_MODE then
        path.Visualize = true
    end

    -- Setup automatic speed synchronization
    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if path then
            path.Speed = humanoid.WalkSpeed
        end
    end)

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
]]
function ClientPathfinding.HandlePathError(npcData, errorType)
    if errorType == "ComputationError" then
        warn("[ClientPathfinding] Computation error for NPC:", npcData.ID)
        npcData.Destination = nil
    elseif errorType == "TargetUnreachable" then
        npcData.Destination = nil
    end
end

--[[
    Handle NPC being blocked/stuck
    Client-side jump handling
]]
function ClientPathfinding.HandlePathBlocked(npcData, visualModel, reason)
    local humanoid = visualModel:FindFirstChild("Humanoid")
    if not humanoid then return end

    if reason == "ReachTimeout" then
        -- Try jumping to unstuck
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    elseif reason == "ReachFailed" then
        -- Clear destination and retry
        npcData.Destination = nil
    end
end

--[[
    Run pathfinding to destination
    Similar to PathfindingManager.RunPath
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
]]
function ClientPathfinding.StopPath(npcData)
    if npcData.Pathfinding then
        npcData.Pathfinding:Stop()
    end
end

return ClientPathfinding
```

---

## 3. Client-Side Jump Simulation

**Location**: `NPC_Controller/Components/Others/ClientJumpSimulator.lua`

**Purpose**: Simulate realistic jump physics on the client

```lua
local ClientJumpSimulator = {}

local JUMP_POWER = 50  -- Default jump power

function ClientJumpSimulator.SimulateJump(npcData)
    local jumpPower = npcData.Config.JumpPower or JUMP_POWER
    local gravity = workspace.Gravity  -- Use workspace gravity for consistency
    local currentVelocity = Vector3.new(0, jumpPower, 0)

    local startPosition = npcData.Position
    local startTime = tick()

    -- Simulate jump arc
    while currentVelocity.Y > 0 or not ClientJumpSimulator.IsOnGround(npcData.Position) do
        local deltaTime = RunService.Heartbeat:Wait()

        -- Apply gravity
        currentVelocity = currentVelocity - Vector3.new(0, gravity * deltaTime, 0)

        -- Update position
        local newPosition = npcData.Position + (currentVelocity * deltaTime)

        -- Raycast to check for ground
        local rayResult = workspace:Raycast(
            newPosition + Vector3.new(0, 1, 0),
            Vector3.new(0, -2, 0)
        )

        if rayResult then
            -- Landed on ground
            newPosition = rayResult.Position + Vector3.new(0, 0.5, 0)
            break
        end

        -- Update NPC position
        ClientJumpSimulator.UpdatePosition(npcData, newPosition)

        -- Safety timeout
        if tick() - startTime > 3 then
            warn("[ClientJumpSimulator] Jump timeout")
            break
        end
    end
end

function ClientJumpSimulator.IsOnGround(position: Vector3): boolean
    local rayResult = workspace:Raycast(
        position + Vector3.new(0, 0.5, 0),
        Vector3.new(0, -1, 0)
    )

    return rayResult ~= nil
end

function ClientJumpSimulator.UpdatePosition(npcData, newPosition: Vector3)
    npcData.Position = newPosition

    -- Update in ReplicatedStorage for server sync
    local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcData.ID)
    if npcFolder and npcFolder:FindFirstChild("Position") then
        npcFolder.Position.Value = newPosition
    end
end

return ClientJumpSimulator
```

---

## 4. Client Physics Renderer

**Location**: `NPC_Controller/Components/Others/ClientPhysicsRenderer.lua`

**Purpose**: Render full NPC models for client-physics NPCs (UseAnimationController = true)

**⚠️ Note**: This is **different** from the existing `NPCRenderer.lua`:

- **NPCRenderer.lua** - Renders visuals on top of server-physics NPCs (traditional approach)
- **ClientPhysicsRenderer.lua** - Renders full NPCs from position data only (no server model)

Both systems coexist and serve different purposes based on `UseAnimationController` setting.

```lua
local ClientPhysicsRenderer = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RenderConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.RenderConfig)

local RenderedNPCs = {}  -- [npcID] = visualModel

function ClientPhysicsRenderer.Init()
    task.spawn(ClientPhysicsRenderer.DistanceCheckLoop)
end

function ClientPhysicsRenderer.DistanceCheckLoop()
    local Players = game:GetService("Players")
    local localPlayer = Players.LocalPlayer

    while task.wait(RenderConfig.DISTANCE_CHECK_INTERVAL) do
        -- Respect global rendering toggle
        if not RenderConfig.ENABLED then
            continue
        end

        if not localPlayer.Character or not localPlayer.Character.PrimaryPart then
            continue
        end

        local playerPos = localPlayer.Character.PrimaryPart.Position

        -- Check all NPCs in ReplicatedStorage
        local activeNPCsFolder = ReplicatedStorage:FindFirstChild("ActiveNPCs")
        if not activeNPCsFolder then continue end

        for _, npcFolder in activeNPCsFolder:GetChildren() do
            local npcID = npcFolder.Name
            local positionValue = npcFolder:FindFirstChild("Position")

            if positionValue then
                local npcPos = positionValue.Value
                local distance = (playerPos - npcPos).Magnitude

                local isRendered = RenderedNPCs[npcID] ~= nil

                -- Render if within range and not rendered
                if distance <= RenderConfig.MAX_RENDER_DISTANCE and not isRendered then
                    -- Check if we haven't exceeded max rendered NPCs
                    local renderedCount = 0
                    for _ in pairs(RenderedNPCs) do
                        renderedCount = renderedCount + 1
                    end

                    if renderedCount < RenderConfig.MAX_RENDERED_NPCS then
                        ClientPhysicsRenderer.RenderNPC(npcFolder)
                    end
                end

                -- Unrender if out of range and rendered (hysteresis: 1.3x render distance)
                local unrenderDistance = RenderConfig.MAX_RENDER_DISTANCE * 1.3
                if distance > unrenderDistance and isRendered then
                    ClientPhysicsRenderer.UnrenderNPC(npcID)
                end
            end
        end
    end
end

function ClientPhysicsRenderer.RenderNPC(npcFolder)
    local npcID = npcFolder.Name
    local configJSON = npcFolder:FindFirstChild("Config")

    if not configJSON then
        warn("[ClientPhysicsRenderer] No config found for NPC:", npcID)
        return
    end

    local config = HttpService:JSONDecode(configJSON.Value)

    -- Clone visual model
    local originalModel = config.ModelPath
    local visualModel = originalModel:Clone()
    visualModel.Name = npcID .. "_Visual"

    -- Make non-collidable (client-side visuals only)
    for _, descendant in visualModel:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
        end
    end

    -- Parent to workspace
    visualModel.Parent = workspace.Characters.NPCs

    -- Track rendered NPC
    RenderedNPCs[npcID] = visualModel

    -- Setup position sync
    ClientPhysicsRenderer.SetupPositionSync(npcFolder, visualModel)

    -- Setup animator
    ClientPhysicsRenderer.SetupAnimator(visualModel)
end

function ClientPhysicsRenderer.SetupPositionSync(npcFolder, visualModel)
    local positionValue = npcFolder:FindFirstChild("Position")
    local healthValue = npcFolder:FindFirstChild("Health")
    local maxHealthValue = npcFolder:FindFirstChild("MaxHealth")

    if positionValue then
        -- Initial position
        visualModel:PivotTo(CFrame.new(positionValue.Value))

        -- Track position updates
        positionValue.Changed:Connect(function(newPosition)
            visualModel:PivotTo(CFrame.new(newPosition))
        end)
    end

    -- Setup health bar (if needed)
    if healthValue and maxHealthValue then
        ClientPhysicsRenderer.SetupHealthBar(visualModel, healthValue, maxHealthValue)
    end
end

function ClientPhysicsRenderer.SetupHealthBar(visualModel, healthValue, maxHealthValue)
    -- Create health bar UI above NPC
    -- This reads from server-authoritative health values

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "HealthBar"
    billboardGui.Size = UDim2.new(4, 0, 0.5, 0)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = visualModel.PrimaryPart

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    frame.BorderSizePixel = 0
    frame.Parent = billboardGui

    local healthBar = Instance.new("Frame")
    healthBar.Name = "Health"
    healthBar.Size = UDim2.new(healthValue.Value / maxHealthValue.Value, 0, 1, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = frame

    -- Update health bar when server updates health
    healthValue.Changed:Connect(function(newHealth)
        local percentage = math.clamp(newHealth / maxHealthValue.Value, 0, 1)
        healthBar.Size = UDim2.new(percentage, 0, 1, 0)

        -- Color gradient: green -> yellow -> red
        if percentage > 0.5 then
            healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)  -- Green
        elseif percentage > 0.25 then
            healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)  -- Yellow
        else
            healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)  -- Red
        end
    end)
end

function ClientPhysicsRenderer.SetupAnimator(visualModel)
    local humanoid = visualModel:FindFirstChild("Humanoid")
    if not humanoid then return end

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = humanoid
    end

    -- Store animator reference for animation playback
    visualModel:SetAttribute("HasAnimator", true)
end

function ClientPhysicsRenderer.UnrenderNPC(npcID)
    local visualModel = RenderedNPCs[npcID]

    if visualModel then
        visualModel:Destroy()
        RenderedNPCs[npcID] = nil
    end
end

return ClientPhysicsRenderer
```

---

## Component Interaction Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     CLIENT-SIDE ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ReplicatedStorage.ActiveNPCs                                    │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────────┐                                         │
│  │  ClientNPCManager   │ ◄── Monitors for new NPCs               │
│  │                     │     Assigns simulation ownership        │
│  │  - SimulatedNPCs    │     Runs simulation loop                │
│  │  - RenderedNPCs     │                                         │
│  └──────────┬──────────┘                                         │
│             │                                                    │
│     ┌───────┴───────┬─────────────────┐                          │
│     ▼               ▼                 ▼                          │
│  ┌──────────┐  ┌───────────────┐  ┌─────────────────────┐        │
│  │ Client   │  │ ClientJump    │  │ ClientPhysics       │        │
│  │Pathfinding│  │ Simulator     │  │ Renderer            │        │
│  │          │  │               │  │                     │        │
│  │ NoobPath │  │ Jump physics  │  │ Visual models       │        │
│  │ wrapper  │  │ Ground detect │  │ Health bars         │        │
│  └──────────┘  └───────────────┘  │ Position sync       │        │
│                                   └─────────────────────┘        │
│                                                                  │
│  Position Updates ──────────────────────► Server (via Knit)      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Tasks

### Phase 2: Client Manager

- [ ] Watch ReplicatedStorage.ActiveNPCs for new NPCs
- [ ] Implement client assignment algorithm (distance-based)
- [ ] Create simulation loop (Heartbeat)
- [ ] Implement position synchronization to server via Knit signal

### Phase 3: Pathfinding

- [ ] Implement NoobPath wrapper (similar to server-side PathfindingManager)
- [ ] Port MovementBehavior logic to client
- [ ] Setup error and trapped event handlers
- [ ] Implement waypoint following with NoobPath:Run()
- [ ] Handle pathfinding errors and timeouts

### Phase 4: Jump Simulation

- [ ] Implement gravity simulation
- [ ] Implement ground detection (raycasting)
- [ ] Implement jump arc calculation
- [ ] Handle edge cases (falling, obstacles)

### Phase 5: Rendering

- [ ] Implement distance checking loop (uses RenderConfig settings)
- [ ] Implement render/unrender logic for client-physics NPCs
- [ ] Setup position synchronization from ReplicatedStorage data
- [ ] Create full visual models (not just visuals on top of server model)
- [ ] Setup health bar display (reads from server health values)
- [ ] Respect RenderConfig.MAX_RENDERED_NPCS limit

---

## Related Documents

- [Main.md](./Main.md) - Overview and quick reference
- [Networking.md](./Networking.md) - Position sync and ownership systems
- [Configuration.md](./Configuration.md) - Full configuration reference (planned)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-29
**Extracted From**: Main.md v1.3
