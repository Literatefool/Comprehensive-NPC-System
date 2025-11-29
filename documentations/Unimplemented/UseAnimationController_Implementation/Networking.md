# UseAnimationController - Networking & Synchronization

This document covers the position synchronization, client ownership, and server fallback systems for the `UseAnimationController` feature.

**Parent Document**: [Main.md](./Main.md)

---

## Table of Contents

1. [Optimized Position Sync System](#1-optimized-position-sync-system)
2. [Client Disconnection Handling](#2-client-disconnection-handling)
3. [Server Fallback for Unclaimed NPCs](#3-server-fallback-for-unclaimed-npcs)

---

## 1. Optimized Position Sync System

### 1.1: Overview

The position sync system is **highly optimized** to minimize network traffic and scale to 1000+ NPCs by using **distance-based broadcasting**.

**Key Optimizations:**

1. **Client → Server**: Client sends position updates via Knit service method at configurable intervals (`POSITION_SYNC_INTERVAL`)
2. **Server → Nearby Clients Only**: Server broadcasts position updates **ONLY** to clients within `BROADCAST_DISTANCE` (not all clients)
3. **Result**: 70-95% network traffic reduction compared to broadcasting to all clients
4. **Frequency Control**: Updates fire based on `POSITION_SYNC_INTERVAL` config (default: 0.5 seconds)
5. **No Position Validation**: Server accepts all position updates (no anti-exploit checks to avoid ping-related false positives)

**Network Flow:**

```
Simulating Client:
├── Updates NPC position locally (every Heartbeat)
├── Sends position to server (every POSITION_SYNC_INTERVAL)
└── Via Knit Signal: "UpdateNPCPosition"

Server:
├── Receives position update
├── No validation (accepts all updates - prevents false positives)
├── Updates ReplicatedStorage data
└── Broadcasts ONLY to nearby clients (within BROADCAST_DISTANCE)

Nearby Clients:
├── Receive position update via Knit Signal
├── Update their local rendering
└── No update if client is too far away (optimization)
```

### 1.2: Client-Side Position Sync

**Location**: `NPC_Controller/Components/Others/ClientNPCManager.lua`

```lua
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local OptimizationConfig = require(game.ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

local ClientNPCManager = {}
local SimulatedNPCs = {}  -- [npcID] = npcData

-- Track last sync time for each NPC
local LastSyncTimes = {}  -- [npcID] = lastSyncTick

function ClientNPCManager.Init()
    -- Wait for NPC service to be available
    local NPC_Service = Knit.GetService("NPC_Service")

    -- ... existing init code ...

    -- Start position sync loop
    task.spawn(ClientNPCManager.PositionSyncLoop)
end

--[[
    Position sync loop - sends position updates to server
    Only sends updates for NPCs this client is simulating
]]
function ClientNPCManager.PositionSyncLoop()
    local NPC_Service = Knit.GetService("NPC_Service")
    local syncInterval = OptimizationConfig.ClientSimulation.POSITION_SYNC_INTERVAL

    while task.wait(syncInterval) do
        for npcID, npcData in pairs(SimulatedNPCs) do
            -- Only sync if NPC is alive and has a position
            if npcData.IsAlive and npcData.Position then
                -- Send position update to server via Knit signal
                NPC_Service:UpdateNPCPosition(npcID, npcData.Position, npcData.Orientation)

                -- Track last sync time
                LastSyncTimes[npcID] = tick()
            end
        end
    end
end

--[[
    Listen for position updates from other clients
    This receives updates for NPCs simulated by other clients
]]
function ClientNPCManager.ListenForPositionUpdates()
    local NPC_Service = Knit.GetService("NPC_Service")

    -- Connect to Knit signal for NPC position updates
    NPC_Service.NPCPositionUpdated:Connect(function(npcID, newPosition, newOrientation)
        -- Only update if we're NOT simulating this NPC ourselves
        if not SimulatedNPCs[npcID] then
            ClientNPCManager.UpdateRemoteNPCPosition(npcID, newPosition, newOrientation)
        end
    end)
end

--[[
    Update position of NPC being simulated by another client
]]
function ClientNPCManager.UpdateRemoteNPCPosition(npcID, newPosition, newOrientation)
    -- Update in ReplicatedStorage
    local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
    if npcFolder then
        local positionValue = npcFolder:FindFirstChild("Position")
        if positionValue then
            positionValue.Value = newPosition
        end

        -- Update orientation if provided
        if newOrientation and npcFolder:FindFirstChild("Orientation") then
            npcFolder.Orientation.Value = newOrientation
        end
    end
end

return ClientNPCManager
```

### 1.3: Server-Side Distance-Based Broadcasting

**Location**: `NPC_Service/Components/Others/ClientPhysicsSync.lua`

**Purpose**: Receive position updates from clients and broadcast only to nearby players

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

local ClientPhysicsSync = {}

-- Track NPC positions for distance checks
local NPCPositions = {}  -- [npcID] = Vector3

--[[
    Initialize the sync system
    Setup Knit service method for clients to call
]]
function ClientPhysicsSync.Init(NPCService)
    -- This is called from NPC_Service.KnitInit

    -- Clients will call this method to update NPC positions
    function NPCService.Client:UpdateNPCPosition(player: Player, npcID: string, position: Vector3, orientation: CFrame?)
        ClientPhysicsSync.HandlePositionUpdate(player, npcID, position, orientation)
    end
end

--[[
    Handle position update from client
    Validates and broadcasts to nearby clients only
]]
function ClientPhysicsSync.HandlePositionUpdate(fromPlayer: Player, npcID: string, newPosition: Vector3, newOrientation: CFrame?)
    -- Validate NPC exists
    local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
    if not npcFolder then
        warn("[ClientPhysicsSync] Invalid NPC ID:", npcID)
        return
    end

    -- REMOVED: Position validation (caused false positives from ping/latency)
    -- We accept all position updates to ensure smooth gameplay for high-ping users
    -- Anti-exploit validation has been intentionally disabled

    -- Update position tracking (for reference, no validation)
    local oldPosition = NPCPositions[npcID]

    -- Update position in ReplicatedStorage
    local positionValue = npcFolder:FindFirstChild("Position")
    if positionValue then
        positionValue.Value = newPosition
    end

    if newOrientation and npcFolder:FindFirstChild("Orientation") then
        npcFolder.Orientation.Value = newOrientation
    end

    -- Track position
    NPCPositions[npcID] = newPosition

    -- Broadcast to nearby clients ONLY
    ClientPhysicsSync.BroadcastToNearbyClients(npcID, newPosition, newOrientation)
end

--[[
    Broadcast position update only to clients within BROADCAST_DISTANCE
    This is the KEY optimization - reduces network traffic by 70-90%
]]
function ClientPhysicsSync.BroadcastToNearbyClients(npcID: string, position: Vector3, orientation: CFrame?)
    local broadcastDistance = OptimizationConfig.ClientSimulation.BROADCAST_DISTANCE

    -- Get all players and check distance
    for _, player in pairs(Players:GetPlayers()) do
        local character = player.Character
        if character and character.PrimaryPart then
            local playerPosition = character.PrimaryPart.Position
            local distance = (playerPosition - position).Magnitude

            -- Only send update if player is within broadcast distance
            if distance <= broadcastDistance then
                -- Fire client signal via Knit
                ClientPhysicsSync.FireClientPositionUpdate(player, npcID, position, orientation)
            end
        end
    end
end

--[[
    Fire position update to specific client
]]
function ClientPhysicsSync.FireClientPositionUpdate(player: Player, npcID: string, position: Vector3, orientation: CFrame?)
    -- This fires the Knit signal that clients listen to
    -- Using :Fire() instead of :FireAll() for targeted updates
    local NPCService = require(script.Parent.Parent.Parent)  -- Get NPC_Service
    NPCService.Client.NPCPositionUpdated:Fire(player, npcID, position, orientation)
end

--[[
    REMOVED: Anti-exploit validation intentionally disabled

    Position validation has been removed because:
    - Network latency (ping) causes many false positives
    - Players with high ping would experience stuttering/rejection of legitimate movements
    - The tolerance multipliers (1.5x, 2x, etc.) are never enough for all network conditions
    - User experience is more important than preventing rare exploit scenarios

    Original validation checked if position changes exceeded max speed,
    but real-world testing showed this negatively impacted legitimate users.

    For critical gameplay NPCs, use server-authoritative movement instead of UseAnimationController.
]]

-- This function has been removed - no validation performed
-- function ClientPhysicsSync.ValidatePositionUpdate(...) -- REMOVED

--[[
    Cleanup when NPC is removed
]]
function ClientPhysicsSync.CleanupNPC(npcID: string)
    NPCPositions[npcID] = nil
end

return ClientPhysicsSync
```

### 1.4: Knit Service Integration

**Location**: `NPC_Service/init.lua`

Add the position sync system to the NPC_Service:

```lua
local Knit = require(game.ReplicatedStorage.Packages.Knit)
local NPC_Service = Knit.CreateService({
    Name = "NPC_Service",
    Client = {
        -- Signal for broadcasting NPC position updates to clients
        -- Only fired to nearby clients (within BROADCAST_DISTANCE)
        NPCPositionUpdated = Knit.CreateSignal(),
    },
})

function NPC_Service:KnitInit()
    -- Load components
    NPC_Service.Components = require(script.Components)

    -- Initialize client physics sync system
    local ClientPhysicsSync = require(script.Components.Others.ClientPhysicsSync)
    ClientPhysicsSync.Init(NPC_Service)
end

-- ... rest of service code ...

return NPC_Service
```

### 1.5: Network Traffic Comparison

**Traditional Approach** (all clients receive all updates):

```
1000 NPCs × 30 updates/sec × 100 players = 3,000,000 updates/sec
Network load: EXTREME (unplayable)
```

**Optimized Approach** (only nearby clients receive updates):

```
1000 NPCs × 30 updates/sec × ~5 nearby players = 150,000 updates/sec
Network load: 95% reduction (playable)
```

**Key Benefits:**

- ✅ 70-95% reduction in network traffic
- ✅ Players only receive updates for nearby NPCs
- ✅ Scales better with large player counts
- ✅ Configurable broadcast distance

---

## 2. Client Disconnection Handling

### 2.1: Overview

When a client that is simulating NPCs disconnects, those NPCs must be reassigned to other nearby clients. This system is designed to keep server load minimal - **clients handle the reassignment logic themselves**.

**Key Principles:**
- Server only tracks which client owns each NPC (lightweight)
- Server broadcasts "owner left" events (minimal work)
- Clients compete to claim orphaned NPCs based on distance
- No server-side simulation fallback (maintains zero server physics)

### 2.2: Server-Side Ownership Tracking

**Location**: `NPC_Service/Components/Others/ClientPhysicsSync.lua`

Add ownership tracking to the existing sync system:

```lua
-- Track which client is simulating each NPC
local NPCOwnership = {}  -- [npcID] = Player

-- Track last update time for timeout detection
local LastUpdateTimes = {}  -- [npcID] = tick()

-- Timeout threshold (seconds) - if no update received, NPC is orphaned
local OWNERSHIP_TIMEOUT = 3.0

--[[
    Called when client claims ownership of an NPC
    Server just records this - no validation (minimal load)
]]
function ClientPhysicsSync.ClaimNPC(player: Player, npcID: string)
    -- Simple ownership assignment - no complex logic
    NPCOwnership[npcID] = player
    LastUpdateTimes[npcID] = tick()
end

--[[
    Called when client releases an NPC (intentional handoff)
]]
function ClientPhysicsSync.ReleaseNPC(player: Player, npcID: string)
    if NPCOwnership[npcID] == player then
        NPCOwnership[npcID] = nil
        LastUpdateTimes[npcID] = nil

        -- Broadcast that this NPC needs a new owner
        ClientPhysicsSync.BroadcastOrphanedNPC(npcID)
    end
end

--[[
    Handle player disconnection
    Called from Players.PlayerRemoving
]]
function ClientPhysicsSync.HandlePlayerLeft(player: Player)
    local orphanedNPCs = {}

    -- Find all NPCs owned by this player
    for npcID, owner in pairs(NPCOwnership) do
        if owner == player then
            NPCOwnership[npcID] = nil
            LastUpdateTimes[npcID] = nil
            table.insert(orphanedNPCs, npcID)
        end
    end

    -- Broadcast orphaned NPCs to all remaining clients
    -- Clients will compete to claim them based on distance
    if #orphanedNPCs > 0 then
        ClientPhysicsSync.BroadcastOrphanedNPCs(orphanedNPCs)
    end
end

--[[
    Broadcast orphaned NPCs to nearby clients
    Server does minimal work - just sends the list
]]
function ClientPhysicsSync.BroadcastOrphanedNPCs(npcIDs: {string})
    local NPCService = require(script.Parent.Parent.Parent)

    -- Get positions for distance-based claiming
    local npcPositions = {}
    for _, npcID in ipairs(npcIDs) do
        local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
        if npcFolder and npcFolder:FindFirstChild("Position") then
            npcPositions[npcID] = npcFolder.Position.Value
        end
    end

    -- Fire to all clients - they decide if they should claim
    NPCService.Client.NPCsOrphaned:FireAll(npcPositions)
end

--[[
    Broadcast single orphaned NPC
]]
function ClientPhysicsSync.BroadcastOrphanedNPC(npcID: string)
    ClientPhysicsSync.BroadcastOrphanedNPCs({npcID})
end
```

### 2.3: Client-Side Claiming System

**Location**: `NPC_Controller/Components/Others/ClientNPCManager.lua`

Add claiming logic to handle orphaned NPCs:

```lua
local CLAIM_DELAY_BASE = 0.1  -- Base delay before claiming (seconds)
local CLAIM_DELAY_PER_STUD = 0.001  -- Additional delay per stud of distance

--[[
    Listen for orphaned NPC broadcasts
    Clients compete to claim based on distance (closer = faster claim)
]]
function ClientNPCManager.ListenForOrphanedNPCs()
    local NPC_Service = Knit.GetService("NPC_Service")

    NPC_Service.NPCsOrphaned:Connect(function(npcPositions: {[string]: Vector3})
        ClientNPCManager.HandleOrphanedNPCs(npcPositions)
    end)
end

--[[
    Handle orphaned NPCs - claim those within range
    Uses distance-based delay so closest client claims first
]]
function ClientNPCManager.HandleOrphanedNPCs(npcPositions: {[string]: Vector3})
    local localPlayer = Players.LocalPlayer
    if not localPlayer.Character or not localPlayer.Character.PrimaryPart then
        return
    end

    local playerPos = localPlayer.Character.PrimaryPart.Position
    local simulationDistance = OptimizationConfig.ClientSimulation.SIMULATION_DISTANCE
    local maxSimulated = OptimizationConfig.ClientSimulation.MAX_SIMULATED_PER_CLIENT

    for npcID, npcPos in pairs(npcPositions) do
        local distance = (playerPos - npcPos).Magnitude

        -- Only attempt to claim if within simulation distance
        if distance <= simulationDistance then
            -- Check if we have capacity
            local currentCount = 0
            for _ in pairs(SimulatedNPCs) do
                currentCount = currentCount + 1
            end

            if currentCount < maxSimulated then
                -- Distance-based delay: closer clients claim faster
                local claimDelay = CLAIM_DELAY_BASE + (distance * CLAIM_DELAY_PER_STUD)

                task.delay(claimDelay, function()
                    ClientNPCManager.AttemptClaimNPC(npcID, npcPos)
                end)
            end
        end
    end
end

--[[
    Attempt to claim an orphaned NPC
    Server accepts first valid claim (no complex arbitration)
]]
function ClientNPCManager.AttemptClaimNPC(npcID: string, lastKnownPos: Vector3)
    -- Check if already being simulated by us
    if SimulatedNPCs[npcID] then
        return
    end

    -- Check if NPC still exists
    local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
    if not npcFolder then
        return
    end

    -- Check if already claimed by checking for recent position updates
    local positionValue = npcFolder:FindFirstChild("Position")
    if positionValue then
        -- If position changed from last known, someone else claimed it
        local currentPos = positionValue.Value
        if (currentPos - lastKnownPos).Magnitude > 1 then
            -- Another client already claimed and moved it
            return
        end
    end

    -- Claim the NPC
    local NPC_Service = Knit.GetService("NPC_Service")
    NPC_Service:ClaimNPC(npcID)

    -- Start simulating
    ClientNPCManager.StartSimulation(npcFolder)
end

--[[
    Release NPCs when player is leaving or moving away
]]
function ClientNPCManager.ReleaseNPC(npcID: string)
    if SimulatedNPCs[npcID] then
        -- Notify server
        local NPC_Service = Knit.GetService("NPC_Service")
        NPC_Service:ReleaseNPC(npcID)

        -- Stop local simulation
        ClientNPCManager.StopSimulation(npcID)
    end
end

--[[
    Graceful handoff when moving away from NPCs
    Called periodically from DistanceCheckLoop
]]
function ClientNPCManager.CheckForHandoff()
    local localPlayer = Players.LocalPlayer
    if not localPlayer.Character or not localPlayer.Character.PrimaryPart then
        return
    end

    local playerPos = localPlayer.Character.PrimaryPart.Position
    local simulationDistance = OptimizationConfig.ClientSimulation.SIMULATION_DISTANCE
    local handoffDistance = simulationDistance * 1.5  -- Hysteresis

    for npcID, npcData in pairs(SimulatedNPCs) do
        local distance = (playerPos - npcData.Position).Magnitude

        -- Release if too far away
        if distance > handoffDistance then
            ClientNPCManager.ReleaseNPC(npcID)
        end
    end
end
```

### 2.4: Knit Service Additions

**Location**: `NPC_Service/init.lua`

Add the new signals and methods:

```lua
local NPC_Service = Knit.CreateService({
    Name = "NPC_Service",
    Client = {
        NPCPositionUpdated = Knit.CreateSignal(),
        NPCsOrphaned = Knit.CreateSignal(),  -- NEW: Broadcast orphaned NPCs
    },
})

function NPC_Service:KnitInit()
    -- ... existing init code ...

    -- Handle player leaving
    Players.PlayerRemoving:Connect(function(player)
        ClientPhysicsSync.HandlePlayerLeft(player)
    end)
end

-- Client methods for claiming/releasing
function NPC_Service.Client:ClaimNPC(player: Player, npcID: string)
    ClientPhysicsSync.ClaimNPC(player, npcID)
end

function NPC_Service.Client:ReleaseNPC(player: Player, npcID: string)
    ClientPhysicsSync.ReleaseNPC(player, npcID)
end
```

### 2.5: Timeout Detection (Optional Heartbeat)

For cases where a client crashes without proper disconnection, add optional timeout detection. This runs infrequently to minimize server load:

```lua
-- Run every 5 seconds (very low server load)
local TIMEOUT_CHECK_INTERVAL = 5.0

function ClientPhysicsSync.StartTimeoutChecker()
    task.spawn(function()
        while true do
            task.wait(TIMEOUT_CHECK_INTERVAL)
            ClientPhysicsSync.CheckForTimeouts()
        end
    end)
end

function ClientPhysicsSync.CheckForTimeouts()
    local now = tick()
    local orphanedNPCs = {}

    for npcID, lastUpdate in pairs(LastUpdateTimes) do
        if now - lastUpdate > OWNERSHIP_TIMEOUT then
            -- NPC hasn't received updates - owner likely crashed
            NPCOwnership[npcID] = nil
            LastUpdateTimes[npcID] = nil
            table.insert(orphanedNPCs, npcID)
        end
    end

    if #orphanedNPCs > 0 then
        ClientPhysicsSync.BroadcastOrphanedNPCs(orphanedNPCs)
    end
end
```

### 2.6: Server Load Analysis

**Server work when client disconnects:**
1. Loop through ownership table: O(n) where n = NPCs owned by that player
2. Collect orphaned NPC IDs: Simple table insert
3. Fire signal to all clients: Single network call

**Server does NOT:**
- Simulate any NPC physics
- Calculate which client should take over
- Validate claims (first come, first served)
- Run complex arbitration logic

**Result:** Minimal server impact even with 1000+ NPCs

---

## 3. Server Fallback for Unclaimed NPCs

### 3.1: Overview

When no client is within `SIMULATION_DISTANCE` of an NPC, the NPC becomes orphaned with no one to simulate it. To prevent NPCs from freezing indefinitely, the server provides a **minimal fallback simulation** at 1 update per second.

**Design Principles:**
- Fallback runs at 1 FPS (1 update per second) - extremely low server load
- Only activates for NPCs that remain unclaimed after timeout
- Basic movement only (no complex pathfinding)
- Immediately hands off to client when one comes in range

### 3.2: Configuration

**Location**: `OptimizationConfig.lua`

```lua
-- Server fallback settings (for unclaimed NPCs)
ServerFallback = {
    -- Enable server fallback for unclaimed NPCs
    ENABLED = true,

    -- How long to wait before server takes over (seconds)
    UNCLAIMED_TIMEOUT = 5.0,

    -- Server simulation rate (updates per second)
    -- 1 FPS = minimal load, NPCs still move slowly
    SIMULATION_FPS = 1,

    -- Simplified movement speed (fraction of normal speed)
    -- Lower = less server work, NPCs move slower when unclaimed
    SPEED_MULTIPLIER = 0.5,

    -- Maximum NPCs server will simulate as fallback
    -- Prevents server overload if many NPCs unclaimed
    MAX_SERVER_SIMULATED = 100,
},
```

### 3.3: Server-Side Fallback Manager

**Location**: `NPC_Service/Components/Others/ServerFallbackSimulator.lua`

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)

local ServerFallbackSimulator = {}

-- Track unclaimed NPCs and when they became unclaimed
local UnclaimedNPCs = {}  -- [npcID] = unclaimedTimestamp
local ServerSimulatedNPCs = {}  -- [npcID] = simData

-- Accumulator for fixed timestep
local accumulator = 0
local FIXED_TIMESTEP = 1 / OptimizationConfig.ServerFallback.SIMULATION_FPS

--[[
    Initialize the fallback simulator
    Runs on Heartbeat but only processes at configured FPS
]]
function ServerFallbackSimulator.Init()
    if not OptimizationConfig.ServerFallback.ENABLED then
        return
    end

    RunService.Heartbeat:Connect(function(deltaTime)
        accumulator = accumulator + deltaTime

        -- Only process at configured FPS (e.g., 1 FPS)
        if accumulator >= FIXED_TIMESTEP then
            accumulator = accumulator - FIXED_TIMESTEP
            ServerFallbackSimulator.SimulationStep(FIXED_TIMESTEP)
        end
    end)

    -- Check for unclaimed NPCs periodically
    task.spawn(ServerFallbackSimulator.UnclaimedCheckLoop)
end

--[[
    Check for NPCs that have been unclaimed too long
]]
function ServerFallbackSimulator.UnclaimedCheckLoop()
    local checkInterval = 1.0  -- Check every second
    local timeout = OptimizationConfig.ServerFallback.UNCLAIMED_TIMEOUT

    while true do
        task.wait(checkInterval)

        local now = tick()
        local maxSimulated = OptimizationConfig.ServerFallback.MAX_SERVER_SIMULATED
        local currentCount = 0

        for npcID in pairs(ServerSimulatedNPCs) do
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
    Mark NPC as unclaimed (called when no client claims it)
]]
function ServerFallbackSimulator.MarkUnclaimed(npcID: string)
    -- Don't mark if already being server-simulated
    if ServerSimulatedNPCs[npcID] then
        return
    end

    UnclaimedNPCs[npcID] = tick()
end

--[[
    Mark NPC as claimed (called when client claims it)
]]
function ServerFallbackSimulator.MarkClaimed(npcID: string)
    UnclaimedNPCs[npcID] = nil

    -- Stop server simulation if running
    if ServerSimulatedNPCs[npcID] then
        ServerFallbackSimulator.StopServerSimulation(npcID)
    end
end

--[[
    Start minimal server simulation for an NPC
]]
function ServerFallbackSimulator.StartServerSimulation(npcID: string)
    local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
    if not npcFolder then return end

    local positionValue = npcFolder:FindFirstChild("Position")
    local configValue = npcFolder:FindFirstChild("Config")

    if not positionValue or not configValue then return end

    local config = game:GetService("HttpService"):JSONDecode(configValue.Value)

    ServerSimulatedNPCs[npcID] = {
        Position = positionValue.Value,
        WalkSpeed = (config.WalkSpeed or 16) * OptimizationConfig.ServerFallback.SPEED_MULTIPLIER,
        Destination = nil,  -- Will be set by simple AI
        WanderRadius = config.WanderRadius or 50,
        SpawnPosition = positionValue.Value,
    }
end

--[[
    Stop server simulation for an NPC
]]
function ServerFallbackSimulator.StopServerSimulation(npcID: string)
    ServerSimulatedNPCs[npcID] = nil
end

--[[
    Main simulation step - runs at configured FPS (e.g., 1 FPS)
    Extremely simple movement: just move toward destination
]]
function ServerFallbackSimulator.SimulationStep(deltaTime: number)
    for npcID, simData in pairs(ServerSimulatedNPCs) do
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
        local direction = (simData.Destination - simData.Position)
        direction = Vector3.new(direction.X, 0, direction.Z)  -- Flatten Y

        if direction.Magnitude > 1 then
            direction = direction.Unit
            local movement = direction * simData.WalkSpeed * deltaTime
            simData.Position = simData.Position + movement

            -- Update in ReplicatedStorage
            local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
            if npcFolder and npcFolder:FindFirstChild("Position") then
                npcFolder.Position.Value = simData.Position
            end
        else
            -- Reached destination, clear it
            simData.Destination = nil
        end
    end
end

--[[
    Cleanup when NPC is removed
]]
function ServerFallbackSimulator.CleanupNPC(npcID: string)
    UnclaimedNPCs[npcID] = nil
    ServerSimulatedNPCs[npcID] = nil
end

return ServerFallbackSimulator
```

### 3.4: Integration with ClientPhysicsSync

Update `ClientPhysicsSync.lua` to notify the fallback simulator:

```lua
local ServerFallbackSimulator = require(script.Parent.ServerFallbackSimulator)

-- When broadcasting orphaned NPCs, also mark them as unclaimed
function ClientPhysicsSync.BroadcastOrphanedNPCs(npcIDs: {string})
    -- ... existing code ...

    -- Mark NPCs as unclaimed for fallback system
    for _, npcID in ipairs(npcIDs) do
        ServerFallbackSimulator.MarkUnclaimed(npcID)
    end

    -- Fire to all clients
    NPCService.Client.NPCsOrphaned:FireAll(npcPositions)
end

-- When client claims NPC, notify fallback system
function ClientPhysicsSync.ClaimNPC(player: Player, npcID: string)
    NPCOwnership[npcID] = player
    LastUpdateTimes[npcID] = tick()

    -- Stop server fallback if running
    ServerFallbackSimulator.MarkClaimed(npcID)
end
```

### 3.5: Server Load Analysis

**Fallback simulation cost per NPC:**
- 1 update per second
- Simple vector math (no pathfinding)
- 1 ReplicatedStorage write per update

**With 100 unclaimed NPCs:**
- 100 updates per second total
- Negligible CPU impact
- Minimal network (position changes replicate automatically)

**Comparison to full server physics:**

| Metric | Full Server Physics | Fallback (1 FPS) |
|--------|---------------------|------------------|
| Updates/sec | 60 per NPC | 1 per NPC |
| Pathfinding | Full NoobPath | None (straight line) |
| Physics | Full Humanoid | None (position only) |
| Network | High | Minimal |

**Result:** Fallback adds ~1.7% of full server physics load per NPC

---

## Related Documents

- [Main.md](./Main.md) - Overview and quick reference
- [Configuration.md](./Configuration.md) - Full configuration reference (planned)
- [Security.md](./Security.md) - Exploit mitigation details (planned)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-29
**Extracted From**: Main.md v1.3
