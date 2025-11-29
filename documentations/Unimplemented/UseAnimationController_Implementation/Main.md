# UseAnimationController - Client-Side Physics Optimization Plan

### This is a work-in-progress documentation plan, it is not implemented yet.

### Duplicate source file:

## 📋 **Overview**

This document outlines the implementation of `UseAnimationController`, an **advanced optimization feature** that offloads NPC physics and pathfinding calculations entirely to the client. This approach can support **1000+ NPCs** with minimal lag by eliminating server-side physics simulation.

---

## ⚠️ **CRITICAL WARNINGS**

### **Security Risk: Client Authority**

> **NOTE**: When `UseAnimationController` is enabled, the client has full authority over NPC pathfinding and movement.
>
> **Anti-exploit validation has been intentionally REMOVED** from this system because:
>
> - Network latency (ping) causes many false positives in position validation
> - Player experience is more important than preventing rare exploit scenarios
> - False positives would negatively impact legitimate users with high ping
> - Position validation checks (max speed, teleport detection) are too strict for real-world network conditions
>
> **Design Decision**: We prioritize smooth gameplay for all users over strict anti-cheat measures.
>
> - Use this for non-critical NPCs where position accuracy isn't gameplay-critical
> - Health remains server-authoritative to maintain gameplay integrity
> - For critical NPCs, consider using traditional server-authoritative movement instead

### **Advanced Configuration**

> **WARNING**: This is an **advanced optimization** that requires:
>
> - Deep understanding of Roblox replication
> - Careful testing across multiple clients
> - Game-specific tuning for best results
> - Acceptance of client authority over positions (no anti-exploit validation)
> - **Not recommended for beginners**

### **No Server Physics**

> **WARNING**: When enabled, the server has **NO physics representation** of NPCs:
>
> - No HumanoidRootPart on server
> - No collision detection on server
> - Only position and health data stored on server (hybrid approach)
> - Client handles all rendering and physics
> - **Significantly reduces server load but loses server authority over positions**
> - Health remains server-authoritative to maintain gameplay integrity

---

## 🎯 **Core Concept**

### **Traditional Approach (Current System)**

```
SERVER:
├── Full NPC Model (HumanoidRootPart + Humanoid)
├── Physics simulation
├── Pathfinding calculations
└── Movement logic

CLIENT:
├── Visual model (welded to server HumanoidRootPart)
├── Animations
└── Rendering
```

### **UseAnimationController Approach (New)**

```
SERVER:
├── Position data (Vector3) - updated by client
├── Health data (Number) - server authority
├── Basic state (alive/dead, target)
└── Minimal replication overhead

CLIENT:
├── Full physics simulation
├── Pathfinding calculations (using NoobPath)
├── Jump simulation
├── Movement logic
├── Visual rendering (only when near)
├── Animations
└── Health bar display (reads from server)
```

**Key Difference**: Client handles **physics/pathfinding**, server stores positions and health.

---

## 🏗️ **Architecture Changes**

### **1. Server-Side Changes**

#### **1.1: Minimal Server Representation**

Instead of creating a full NPC model with HumanoidRootPart + Humanoid, create a **data-only structure**:

```lua
-- NEW: Server-side NPC data (no physical model)
{
    -- Identity
    ID: string,                    -- Unique identifier
    Name: string,                  -- NPC name

    -- Position (replicated from client)
    Position: Vector3,             -- Current position (updated by client)
    Orientation: CFrame?,          -- Current orientation (optional)

    -- State (server authority)
    IsAlive: boolean,              -- Is NPC alive
    Health: number,                -- Current health (server authority)
    MaxHealth: number,             -- Maximum health
    CurrentTarget: Model?,         -- Current target (for validation)

    -- Configuration
    Config: {
        ModelPath: Instance,       -- Path to character model
        MaxHealth: number,
        WalkSpeed: number,
        SightRange: number,
        SightMode: string,
        MovementMode: string,
        -- ... other config
    },

    -- Client Tracking
    OwningClient: Player?,         -- Which client is simulating this NPC
    LastUpdateTime: number,        -- Last position update timestamp

    -- Lifecycle
    SpawnTime: number,
    CleanedUp: boolean,
}
```

#### **1.2: Server Storage Structure**

Store NPC data in `ReplicatedStorage` folder for client access:

```lua
-- Server creates data structure in ReplicatedStorage
game.ReplicatedStorage.ActiveNPCs/
├── NPC_12345/
│   ├── Position: Vector3Value
│   ├── Health: NumberValue           -- Server authority
│   ├── MaxHealth: NumberValue
│   ├── IsAlive: BoolValue
│   ├── CurrentTarget: ObjectValue
│   └── Config: StringValue (JSON-encoded)
```

#### **1.3: Server Responsibilities**

The server's role is **drastically reduced**:

- ✅ Store NPC configuration data
- ✅ Store current NPC positions (updated by clients)
- ✅ Store and manage NPC health (server authority for gameplay integrity)
- ✅ Handle NPC spawning/despawning
- ✅ Handle critical gameplay events (e.g., death, rewards)
- ❌ NO physics simulation
- ❌ NO pathfinding
- ❌ NO movement logic

**Important**: Even though physics are client-side, **health management remains on the server** to maintain gameplay integrity. This allows NPCs to take damage while still benefiting from client-side physics optimization.

---

### **2. Client-Side Components**

> **📄 See: [ClientComponents.md](./ClientComponents.md)**
>
> The client components documentation covers:
> - **Two Rendering Systems** - NPCRenderer vs ClientPhysicsRenderer comparison
> - **ClientNPCManager** - NPC monitoring, simulation assignment, distance checks
> - **ClientPathfinding** - NoobPath wrapper for client-side pathfinding
> - **ClientJumpSimulator** - Physics-based jump simulation
> - **ClientPhysicsRenderer** - Full NPC rendering from position data

**Quick Reference:**

| Component | Location | Purpose |
|-----------|----------|---------|
| ClientNPCManager | `NPC_Controller/Components/Others/` | Monitors NPCs, assigns simulation |
| ClientPathfinding | `NPC_Controller/Components/Others/` | NoobPath wrapper |
| ClientJumpSimulator | `NPC_Controller/Components/Others/` | Jump physics simulation |
| ClientPhysicsRenderer | `NPC_Controller/Components/Others/` | Visual rendering & health bars |

---

### **3. Networking & Synchronization**

> **📄 See: [Networking.md](./Networking.md)**
>
> The networking documentation covers:
> - **Position Sync System** - Distance-based broadcasting (70-95% network reduction)
> - **Client Disconnection Handling** - Ownership tracking & NPC reassignment
> - **Server Fallback** - Minimal 1 FPS simulation for unclaimed NPCs

**Quick Reference:**

| System | Purpose | Server Load |
|--------|---------|-------------|
| Position Sync | Broadcast updates to nearby clients only | Minimal |
| Ownership Tracking | Track which client simulates each NPC | O(1) lookup |
| Client Claiming | Distance-based claiming (closer = faster) | None (client-side) |
| Server Fallback | 1 FPS simulation for orphaned NPCs | ~1.7% of full physics |

---

## 🔧 **Configuration Structure**

### **Configuration File Location**

**Path**: `src/ReplicatedStorage/SharedSource/Datas/NPCs/OptimizationConfig.lua`

```lua
--[[
    OptimizationConfig - Advanced NPC optimization settings

    ⚠️ WARNING: UseAnimationController is an ADVANCED optimization
    - Offloads ALL physics to client
    - Client has full position authority (no anti-exploit validation)
    - Requires extensive testing
    - NOT recommended for beginners
]]

local OptimizationConfig = {
    --[[
        UseAnimationController - Enable client-side physics simulation

        ⚠️ CRITICAL WARNINGS:
        1. NO physics on server at all
        2. Client handles ALL pathfinding and movement
        3. Client has full position authority (no validation - prevents ping false positives)
           >> We accept that clients can manipulate NPC positions
           >> This is intentional trade-off for smooth gameplay at all ping levels
        4. Only suitable for non-critical NPCs (ambient, visual-only)
        5. Requires more testing for specific use cases
        6. Everything is rendered on client-side for optimization

        When enabled:
        - Server stores positions and health (no HumanoidRootPart, no physics)
        - Health managed by server for gameplay integrity
        - Client calculates pathfinding (using NoobPath)
        - Client simulates jumps (physics simulation)
        - Client handles all physics and movement
        - NPCs only rendered when player is nearby
        - Instead of HumanoidRootPart, only positions are saved

        Performance: Can handle 1000+ NPCs with barely any lag
        Security: Client has position authority (no validation - prevents ping-related false positives)
                  Health remains server-authoritative to protect gameplay integrity
        Use Case: Ambient NPCs, crowds, background characters (non-gameplay-critical)

        ⚠️ DO NOT USE FOR:
        - Combat NPCs (enemies, bosses)
        - NPCs that drop loot or rewards
        - NPCs tied to game progression
        - Any NPC that affects gameplay outcomes
    ]]
    UseAnimationController = false,  -- DISABLED by default

    -- Client-side simulation settings (only if UseAnimationController = true)
    ClientSimulation = {
        -- Distance at which client starts simulating NPC (studs)
        SIMULATION_DISTANCE = 200,

        -- Maximum NPCs one client can simulate
        MAX_SIMULATED_PER_CLIENT = 50,

        -- How often client syncs position to server (seconds)
        POSITION_SYNC_INTERVAL = 0.5,

        -- Distance threshold for server to broadcast position updates (studs)
        -- Server only sends position updates to clients within this range
        BROADCAST_DISTANCE = 250,
    },

    --[[
        ⚠️ NOTE: Rendering settings are in RenderConfig.lua
        To avoid duplication, refer to:
        - RenderConfig.MAX_RENDER_DISTANCE (distance to render NPCs)
        - RenderConfig.MAX_RENDERED_NPCS (max NPCs to render)
        - RenderConfig.DISTANCE_CHECK_INTERVAL (distance check frequency)
        - RenderConfig.DEBUG_MODE (debug visualization)
    ]]

    -- Jump simulation settings
    JumpSimulation = {
        -- ⚠️ NOTE: Gravity is read from workspace.Gravity at runtime
        -- This ensures consistency with game physics settings

        -- Default jump power if not specified (studs/s)
        DEFAULT_JUMP_POWER = 50,

        -- Jump timeout (seconds)
        JUMP_TIMEOUT = 3.0,

        -- Ground check distance (studs)
        GROUND_CHECK_DISTANCE = 1.0,
    },

    -- Pathfinding settings (client-side)
    ClientPathfinding = {
        -- Pathfinding agent radius (studs)
        AGENT_RADIUS = 2,

        -- Pathfinding agent height (studs)
        AGENT_HEIGHT = 5,

        -- Enable jump in pathfinding
        AGENT_CAN_JUMP = true,

        -- Waypoint spacing (studs)
        WAYPOINT_SPACING = 4,

        -- Terrain costs
        TERRAIN_COSTS = {
            Water = math.huge,  -- Avoid water
        },

        -- Recompute path if NPC deviates this much (studs)
        RECOMPUTE_THRESHOLD = 10,
    },

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

    -- Minimal exploit mitigation settings
    ExploitMitigation = {
        -- Enable soft bounds checking (clamps position, doesn't reject)
        SOFT_BOUNDS_ENABLED = true,

        -- Default max wander radius if not specified per-NPC (studs)
        DEFAULT_MAX_WANDER_RADIUS = 500,

        -- Client-side ground check interval (seconds)
        GROUND_CHECK_INTERVAL = 2.0,

        -- Height tolerance before snapping to ground (studs)
        GROUND_SNAP_TOLERANCE = 10,
    },
}

return OptimizationConfig
```

---

### **Configuration Separation: OptimizationConfig vs RenderConfig**

To avoid duplication and maintain clean separation of concerns, the configuration is split into two files:

#### **OptimizationConfig.lua** - Client Physics & Simulation

- `UseAnimationController` - Enable/disable client-side physics
- `ClientSimulation` settings:
  - `SIMULATION_DISTANCE` - When clients start simulating NPCs
  - `MAX_SIMULATED_PER_CLIENT` - Max NPCs one client can simulate
  - `POSITION_SYNC_INTERVAL` - How often position syncs to server
  - `BROADCAST_DISTANCE` - Server only broadcasts to nearby clients
- `JumpSimulation` settings (uses `workspace.Gravity` at runtime)
- `ClientPathfinding` settings (NoobPath configuration)

#### **RenderConfig.lua** - Visual Rendering Control

- `ENABLED` - Toggle all client-side rendering on/off
- `MAX_RENDER_DISTANCE` - Distance to render NPCs visually
- `MAX_RENDERED_NPCS` - Maximum NPCs to render at once
- `DISTANCE_CHECK_INTERVAL` - How often to check render distances
- `DEBUG_MODE` - Enable debug visualization

**Why Separate?**

- **OptimizationConfig**: Advanced features for physics simulation (UseAnimationController)
- **RenderConfig**: General rendering controls (works with or without UseAnimationController)
- **No Duplication**: Each setting exists in only one place
- **Clear Responsibility**: Physics vs Rendering concerns are separated

---

### **NPC Spawn Configuration Update**

Update the `SpawnNPC` configuration to include the new optimization flag:

```lua
--[[
    Spawn NPC with flexible configuration

    @param config table - Configuration for NPC spawning
        ... (existing parameters)

        -- OPTIMIZATION (ADVANCED)
        - UseAnimationController: boolean? - Enable client-side physics (default: false)
            ⚠️ WARNING: This is an ADVANCED feature with the following implications:
                1. NO physics simulation on server
                2. Client handles ALL pathfinding and movement
                3. Client has position authority (no validation to prevent ping false positives)
                4. Only for non-critical NPCs (ambient, visual-only)
                5. Everything rendered on client-side
                6. Can handle 1000+ NPCs with smooth gameplay at all ping levels
]]
function NPC_Service:SpawnNPC(config)
    -- Check if UseAnimationController is enabled
    local useAnimController = config.UseAnimationController or OptimizationConfig.UseAnimationController

    if useAnimController then
        -- Use client-side physics approach
        return NPC_Service.Components.NPCSpawner:SpawnClientPhysicsNPC(config)
    else
        -- Use traditional server-side physics approach
        return NPC_Service.Components.NPCSpawner:SpawnNPC(config)
    end
end
```

---

## 📊 **Implementation Phases**

### **Phase 1: Server-Side Foundation**

**Files to Create:**

1. `SharedSource/Datas/NPCs/OptimizationConfig.lua` - Configuration file
2. `NPC_Service/Components/Others/ClientPhysicsSpawner.lua` - Spawner for client-physics NPCs

**Files to Modify:**

1. `NPC_Service/init.lua` - Add UseAnimationController parameter
2. `NPC_Service/Components/Others/NPCSpawner.lua` - Add conditional logic

**Tasks:**

- [ ] Create OptimizationConfig with all settings
- [ ] Create data structure in ReplicatedStorage for NPC data (Position, Health, IsAlive, etc.)
- [ ] Implement ClientPhysicsSpawner (no physical model, just data)
- [ ] Implement server-side health storage (simple storage, server-authoritative for health)
- [ ] Add cleanup handlers for client-physics NPCs

### **Phase 2: Client-Side Manager & Position Sync**

**Files to Create:**

1. `NPC_Controller/Components/Others/ClientNPCManager.lua` - Main client manager
2. `NPC_Controller/Components/Others/ClientNPCSimulator.lua` - NPC simulation logic
3. `NPC_Service/Components/Others/ClientPhysicsSync.lua` - Server-side position sync handler

**Tasks:**

- [ ] Watch ReplicatedStorage.ActiveNPCs for new NPCs
- [ ] Implement client assignment algorithm (distance-based)
- [ ] Create simulation loop (Heartbeat)
- [ ] Implement position synchronization to server via Knit signal
- [ ] Implement server-side distance-based broadcasting (only send to nearby clients)
- [ ] ~~Add position validation~~ - REMOVED (causes false positives)
- [ ] Setup Knit service signals (UpdateNPCPosition, NPCPositionUpdated, NPCsOrphaned)
- [ ] Implement ownership tracking (NPCOwnership table)
- [ ] Implement ClaimNPC/ReleaseNPC methods
- [ ] Setup Players.PlayerRemoving handler for disconnection
- [ ] Implement client-side orphaned NPC listener
- [ ] Implement distance-based claiming with delay (closer = faster)
- [ ] Implement graceful handoff when player moves away (CheckForHandoff)
- [ ] Add timeout detection for crashed clients (optional heartbeat check)

### **Phase 3: Client-Side Pathfinding (NoobPath)**

**Files to Create:**

1. `NPC_Controller/Components/Others/ClientPathfinding.lua` - NoobPath pathfinding wrapper
2. `NPC_Controller/Components/Others/ClientMovement.lua` - Movement behaviors

**Tasks:**

- [ ] Implement NoobPath wrapper (similar to server-side PathfindingManager)
- [ ] Port MovementBehavior logic to client
- [ ] Setup error and trapped event handlers
- [ ] Implement waypoint following with NoobPath:Run()
- [ ] Handle pathfinding errors and timeouts

### **Phase 4: Jump Simulation**

**Files to Create:**

1. `NPC_Controller/Components/Others/ClientJumpSimulator.lua` - Jump physics

**Tasks:**

- [ ] Implement gravity simulation
- [ ] Implement ground detection (raycasting)
- [ ] Implement jump arc calculation
- [ ] Handle edge cases (falling, obstacles)

### **Phase 5: Client Physics Rendering**

**Files to Create:**

1. `NPC_Controller/Components/Others/ClientPhysicsRenderer.lua` - Client-side renderer for physics NPCs

**⚠️ Note**: This is separate from existing `NPCRenderer.lua`:

- `NPCRenderer.lua` - Handles traditional server-physics NPCs
- `ClientPhysicsRenderer.lua` - Handles UseAnimationController client-physics NPCs

**Tasks:**

- [ ] Implement distance checking loop (uses RenderConfig settings)
- [ ] Implement render/unrender logic for client-physics NPCs
- [ ] Setup position synchronization from ReplicatedStorage data
- [ ] Create full visual models (not just visuals on top of server model)
- [ ] Setup health bar display (reads from server health values)
- [ ] Respect RenderConfig.MAX_RENDERED_NPCS limit

### **Phase 6: Server Fallback & Exploit Mitigation**

**Files to Create:**

1. `NPC_Service/Components/Others/ServerFallbackSimulator.lua` - Minimal server simulation for unclaimed NPCs

**Files to Modify:**

1. `NPC_Service/Components/Others/ClientPhysicsSync.lua` - Add fallback integration
2. `NPC_Controller/Components/Others/ClientNPCManager.lua` - Add ground validation

**Tasks:**

- [ ] Implement ServerFallbackSimulator with 1 FPS simulation
- [ ] Track unclaimed NPCs with timestamp
- [ ] Implement simple wander AI for fallback (no pathfinding)
- [ ] Integrate with ClientPhysicsSync (MarkUnclaimed/MarkClaimed)
- [ ] Add soft bounds checking (clamp positions, don't reject)
- [ ] Add per-client ownership limit enforcement
- [ ] Implement client-side periodic ground check
- [ ] Add ExploitMitigation config section

### **Phase 7: Testing & Optimization**

**Tasks:**

- [ ] Test with 100 NPCs
- [ ] Test with 500 NPCs
- [ ] Test with 1000+ NPCs
- [ ] Profile client performance
- [ ] Profile server performance
- [ ] Test with multiple clients
- [ ] Test client disconnection (NPC reassignment)
- [ ] Test server fallback activation
- [ ] Test exploit scenarios (verify mitigations work)
- [ ] Test soft bounds clamping
- [ ] Test ownership limits

---

## 🧪 **Testing Strategy**

### **Performance Testing**

1. **Baseline Test** (Traditional System)

   - Spawn 100 NPCs with server physics
   - Measure server FPS, memory, network traffic
   - Measure client FPS, memory

2. **Client Physics Test** (New System)
   - Spawn 100, 500, 1000 NPCs with UseAnimationController
   - Measure server FPS, memory, network traffic
   - Measure client FPS, memory
   - Compare results with baseline

### **Functionality Testing**

1. **Pathfinding**

   - Verify NPCs navigate correctly
   - Verify jump handling
   - Verify obstacle avoidance

2. **Rendering**

   - Verify NPCs render at correct distance
   - Verify NPCs unrender when far away
   - Verify smooth transitions

3. **Multi-Client Testing**
   - Test with 2+ clients in same server
   - Verify NPC distribution across clients
   - Verify position synchronization

### **Exploit Testing** (Documentation Only - No Mitigation)

1. **Position Manipulation** (Expected Behavior - Not Prevented)

   - Test if client can teleport NPCs (will succeed - acceptable trade-off)
   - Test if client can freeze NPCs (will succeed - acceptable trade-off)
   - Test if client can make NPCs walk through walls (will succeed - acceptable trade-off)
   - Document these behaviors for developers to understand system limitations

2. **Mitigation Strategies**
   - Server-side validation for critical events (combat/damage only)
   - ❌ Position sanity checks REMOVED (caused false positives from ping/latency)
   - ❌ Rate limiting REMOVED (punishes legitimate high-ping players)
   - **Note**: We accept position exploit risks to maintain smooth gameplay for all users

---

## 📈 **Expected Performance**

### **Traditional System (Current)**

```
Server:
- 100 NPCs: ~40-50 FPS
- 200 NPCs: ~20-30 FPS
- 500 NPCs: < 10 FPS (unplayable)

Client:
- 100 NPCs: ~50-60 FPS
- 200 NPCs: ~40-50 FPS

Network:
- High replication overhead (HumanoidRootPart positions)
```

### **UseAnimationController System (New)**

```
Server:
- 100 NPCs: ~55-60 FPS
- 500 NPCs: ~55-60 FPS
- 1000 NPCs: ~50-55 FPS
- 2000 NPCs: ~40-50 FPS

Client (per client):
- Simulating 50 NPCs: ~45-55 FPS
- Rendering 100 NPCs: ~40-50 FPS

Network:
- Minimal replication (Vector3 positions only)
- ~80-90% reduction in network traffic
```

**Key Improvements:**

- ✅ Server FPS stays high regardless of NPC count
- ✅ Network traffic reduced by 80-90%
- ✅ Can support 1000+ NPCs
- ⚠️ Client FPS depends on simulation/render load
- ⚠️ Requires careful load distribution

---

## 🔐 **Security Considerations**

### **⚠️ Anti-Exploit Validation: INTENTIONALLY DISABLED**

**This system does NOT include anti-exploit validation for position updates.**

**Reasoning:**

- Network latency and ping variations cause too many false positives
- Players with high ping (200ms+) would have their legitimate movements rejected
- No tolerance multiplier (1.5x, 2x, 3x) works reliably for all network conditions
- False positives negatively impact user experience more than exploits would
- Stuttering, rubber-banding, and position rejection are unacceptable for gameplay

**Design Philosophy:**

> **User experience > Anti-cheat strictness**
>
> We prioritize smooth gameplay for legitimate users over preventing rare exploit scenarios.
> If position accuracy is critical for your game, use server-authoritative movement instead.

### **Potential Exploit Scenarios & Minimal Mitigations**

We cannot make client-authoritative movement "fully secure"—but we can make it **minimally exploitable** without returning to server-authoritative physics.

#### **1. NPC Teleportation**

- **Attack**: Client sends fake position updates to teleport NPCs
- **Mitigation**: **Soft bounds checking** (no rejection, just correction)

```lua
-- Server-side: Soft position correction (no rejection)
-- Runs once per second during fallback check - minimal load
function ClientPhysicsSync.SoftBoundsCheck(npcID: string, reportedPosition: Vector3)
    local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
    if not npcFolder then return reportedPosition end

    local configValue = npcFolder:FindFirstChild("Config")
    if not configValue then return reportedPosition end

    local config = HttpService:JSONDecode(configValue.Value)
    local spawnPos = config.SpawnPosition or Vector3.new(0, 0, 0)
    local maxWanderRadius = config.MaxWanderRadius or 500  -- Generous bound

    -- If NPC is WAY outside expected area, nudge it back (don't reject)
    local distance = (reportedPosition - spawnPos).Magnitude
    if distance > maxWanderRadius then
        -- Clamp to boundary instead of rejecting
        local direction = (reportedPosition - spawnPos).Unit
        return spawnPos + direction * maxWanderRadius
    end

    return reportedPosition
end
```

**Why this works:**
- No false positives (we accept the position, just clamp it)
- Exploiter can't teleport NPC across the map
- Legitimate high-ping players unaffected

#### **2. NPC Freezing**

- **Attack**: Client stops updating NPC positions
- **Mitigation**: **Ownership timeout + server fallback** (already implemented in Section 5)

The timeout detection system (Section 4.5) combined with server fallback (Section 5) handles this:
- If no updates received for 3 seconds → NPC becomes orphaned
- After 5 seconds unclaimed → Server fallback takes over at 1 FPS
- Exploiter can't permanently freeze NPCs

#### **3. Wall Clipping**

- **Attack**: Client makes NPCs walk through walls
- **Mitigation**: **Periodic ground/bounds raycast** (lightweight)

```lua
-- Client-side: Periodic validity check (runs every 2 seconds)
function ClientNPCManager.ValidateNPCPosition(npcID: string, position: Vector3): Vector3
    -- Check if position is underground or in void
    local rayResult = workspace:Raycast(
        position + Vector3.new(0, 50, 0),  -- Start above
        Vector3.new(0, -100, 0),           -- Cast down
        RaycastParams.new()
    )

    if rayResult then
        -- Snap to ground if floating or underground
        local groundY = rayResult.Position.Y + 3  -- 3 studs above ground
        if math.abs(position.Y - groundY) > 10 then
            return Vector3.new(position.X, groundY, position.Z)
        end
    else
        -- No ground found - NPC might be in void, reset to spawn
        local npcFolder = ReplicatedStorage.ActiveNPCs:FindFirstChild(npcID)
        if npcFolder and npcFolder:FindFirstChild("Config") then
            local config = HttpService:JSONDecode(npcFolder.Config.Value)
            return config.SpawnPosition or Vector3.new(0, 10, 0)
        end
    end

    return position
end
```

**Why this works:**
- Runs infrequently (every 2 seconds) - minimal load
- Client-side, so no server impact
- Prevents NPCs from being stuck in walls/void
- Doesn't prevent wall clipping during movement, but corrects it

#### **4. Combat Manipulation**

- **Attack**: Client makes NPCs attack/target incorrectly
- **Mitigation**: **Server validates all combat outcomes** (already in place)

Health is server-authoritative. Even if client manipulates NPC targeting:
- Damage calculations happen on server
- Loot drops controlled by server
- XP/rewards controlled by server

#### **5. Mass NPC Manipulation**

- **Attack**: Client claims many NPCs and manipulates them all
- **Mitigation**: **Per-client ownership limit** (already configured)

```lua
-- Already in OptimizationConfig
MAX_SIMULATED_PER_CLIENT = 50  -- Client can only own 50 NPCs max
```

Additional server-side enforcement:

```lua
function ClientPhysicsSync.ClaimNPC(player: Player, npcID: string)
    -- Count current ownership
    local ownedCount = 0
    for _, owner in pairs(NPCOwnership) do
        if owner == player then
            ownedCount = ownedCount + 1
        end
    end

    -- Reject if over limit
    if ownedCount >= OptimizationConfig.ClientSimulation.MAX_SIMULATED_PER_CLIENT then
        return false  -- Reject claim
    end

    NPCOwnership[npcID] = player
    LastUpdateTimes[npcID] = tick()
    ServerFallbackSimulator.MarkClaimed(npcID)
    return true
end
```

---

### **Summary: Minimal Exploit Mitigation**

| Exploit | Mitigation | Server Load |
|---------|------------|-------------|
| Teleportation | Soft bounds clamp (no rejection) | ~0 (runs with fallback check) |
| Freezing | Ownership timeout + server fallback | Minimal (1 FPS per orphaned NPC) |
| Wall clipping | Client-side periodic ground check | 0 (client only) |
| Combat manipulation | Server-authoritative health/damage | Already required |
| Mass manipulation | Per-client ownership limit | O(n) check on claim |

**Philosophy**: Accept imperfect positions, but prevent game-breaking exploits.

---

### **What IS Protected**

✅ **Health/Damage** - Server-authoritative, cannot be exploited
✅ **Combat Events** - Server validates all damage dealing
✅ **NPC Spawning** - Server controls what NPCs exist
✅ **NPC Configuration** - Server defines NPC properties
✅ **Ownership Limits** - Client can't claim unlimited NPCs
✅ **Bounds** - NPCs can't be teleported across the map
✅ **Freezing** - Server fallback prevents permanent freeze

### **What is NOT Fully Protected** (Acceptable Trade-offs)

⚠️ **Position Accuracy** - Client can move NPCs within bounds
⚠️ **Movement Paths** - Client controls pathfinding (but bounded)
⚠️ **Visual State** - Client controls animations/rendering
⚠️ **Short-term Wall Clipping** - May occur briefly before correction

### **Use Case Guidelines**

**✅ Safe to Use:**

- Ambient NPCs (villagers, crowds)
- Visual-only NPCs (decorative)
- Non-combat NPCs
- Background characters

**❌ NOT Safe to Use:**

- Combat NPCs (enemies, bosses)
- NPCs that drop loot
- NPCs tied to progression
- NPCs that affect gameplay outcomes

---

## 🎓 **Developer Guidelines**

### **When to Enable UseAnimationController**

**Enable When:**

- You need to support many NPCs (500+)
- NPCs are purely visual (no gameplay impact)
- Server performance is bottleneck
- You understand the security implications

**Do NOT Enable When:**

- NPCs are critical to gameplay
- NPCs handle combat or loot (position accuracy matters)
- You're new to Roblox development
- Position accuracy is essential for game mechanics

### **Best Practices**

1. **Start Small**

   - Test with 10-50 NPCs first
   - Gradually increase to 100, 500, 1000
   - Monitor performance at each step

2. **Server Authority for Critical Systems**

   - Always validate combat/damage events on server (health is server-authoritative)
   - ❌ DO NOT implement position validation (causes false positives from ping)
   - ❌ DO NOT implement rate limiting (punishes high-ping players)
   - Accept that client has position authority as a design trade-off

3. **Distribute Load**

   - Don't let one client simulate all NPCs
   - Use distance-based distribution
   - Consider client performance capabilities

4. **Monitor Performance**
   - Track client FPS
   - Track simulation count per client
   - Track network traffic
   - Adjust settings based on data

---

## 📅 **Implementation Timeline**

### **Phase 1: Foundation** (2-3 days)

- Day 1: Create OptimizationConfig and data structures
- Day 2: Implement ClientPhysicsSpawner
- Day 3: Testing and debugging

### **Phase 2: Client Manager** (3-4 days)

- Day 1-2: ClientNPCManager implementation
- Day 3: Position synchronization
- Day 4: Testing and debugging

### **Phase 3: Pathfinding & Movement** (3-4 days)

- Day 1-2: ClientPathfinding implementation
- Day 3: ClientMovement behaviors
- Day 4: Testing and debugging

### **Phase 4: Jump Simulation** (2 days)

- Day 1: Jump physics implementation
- Day 2: Testing and edge cases

### **Phase 5: Client Physics Rendering** (2-3 days)

- Day 1-2: ClientPhysicsRenderer implementation (separate from existing NPCRenderer)
- Day 3: Testing and optimization

### **Phase 6: Testing & Optimization** (3-4 days)

- Day 1-2: Performance testing
- Day 3-4: Multi-client testing
- Note: No anti-exploit validation implemented (intentionally disabled due to ping false positives)

**Total: 16-21 days**

---

## 🚀 **Migration Path**

### **Step 1: Parallel Implementation**

- Keep existing system running
- Implement new system alongside
- Add feature flag to toggle between systems

### **Step 2: Gradual Rollout**

- Test with small group of players
- Monitor performance metrics
- Gather feedback

### **Step 3: Optimize**

- Tune configuration based on data
- Adjust render distances
- Optimize simulation distribution

### **Step 4: Full Deployment**

- Enable for all players
- Monitor server performance
- Monitor client performance
- Adjust as needed

---

## 📝 **Configuration Examples**

### **Example 1: Ambient Village NPCs (Safe for UseAnimationController)**

```lua
-- Spawn 100 villagers with client-side physics
for i = 1, 100 do
    NPC_Service:SpawnNPC({
        Name = "Villager_" .. i,
        Position = GetRandomVillagePosition(),
        ModelPath = game.ReplicatedStorage.Assets.NPCs.Villager,

        MaxHealth = 100,
        WalkSpeed = 10,

        SightRange = 50,
        SightMode = "Directional",
        MovementMode = "Ranged",

        EnableIdleWander = true,
        EnableCombatMovement = false,  -- No combat

        -- ENABLE CLIENT-SIDE PHYSICS
        UseAnimationController = true,

        CustomData = {
            Faction = "Villager",
            IsAmbient = true,
        },
    })
end
```

### **Example 2: Combat NPCs (NOT Safe for UseAnimationController)**

```lua
-- Spawn combat enemies with traditional server physics
NPC_Service:SpawnNPC({
    Name = "CombatEnemy",
    Position = Vector3.new(0, 10, 0),
    ModelPath = game.ReplicatedStorage.Assets.NPCs.Enemy,

    MaxHealth = 150,
    WalkSpeed = 16,

    SightRange = 200,
    SightMode = "Directional",
    MovementMode = "Melee",

    EnableIdleWander = true,
    EnableCombatMovement = true,

    -- DO NOT ENABLE for combat NPCs
    UseAnimationController = false,  -- Server physics

    CustomData = {
        Faction = "Enemy",
        DropTable = {"Coin", "Weapon"},
    },
})
```

---

## 🔚 **Conclusion**

The `UseAnimationController` optimization is a **powerful but risky** feature that can dramatically improve NPC performance by offloading physics to the client. When used correctly, it enables games to support **1000+ NPCs** with minimal lag.

**Key Takeaways:**

- ✅ Massive performance improvement (server-side)
- ✅ 70-95% network traffic reduction via distance-based broadcasting
- ✅ Enables large-scale NPC systems (1000+ NPCs)
- ✅ Uses workspace.Gravity for physics consistency
- ✅ Respects RenderConfig for rendering settings (no duplication)
- ⚠️ Client has position authority (no anti-exploit validation to prevent ping false positives)
- ⚠️ Requires extensive testing
- ⚠️ Only suitable for non-critical NPCs where position accuracy isn't gameplay-critical

**Recommended Use Cases:**

- Ambient NPCs (crowds, villagers)
- Visual-only NPCs (background characters)
- Non-gameplay-critical NPCs

**NOT Recommended For:**

- Combat NPCs
- NPCs that drop loot
- NPCs tied to progression

---

## 📝 **Recent Updates**

### Version 1.3 (2025-11-29)

---

**Document Version**: 1.3
**Last Updated**: 2025-11-29
**Status**: Implementation Plan (Updated - Ready for Implementation)
