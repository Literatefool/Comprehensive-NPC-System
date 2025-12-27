# NPC System Architecture

## Overview

The NPC System is a modular, client-server architecture that manages NPC spawning, behavior, rendering, and physics. It supports two modes: **Server-Side Physics** (traditional) and **Client-Side Physics** (optimized for 1000+ NPCs).

---

## System Components

### Server-Side (`NPC_Service`)

**Location**: `src/ServerScriptService/ServerSource/Server/NPC_Service/`

#### Core Components

**Spawning** (`Components/Others/Spawning/`)
- **NPCSpawner.lua** - Spawns NPCs with server-side physics (traditional mode)

**Physics** (`Components/Others/Physics/`)
- **ClientPhysicsSpawner.lua** - Spawns NPCs with client-side physics (optimized mode)
- **ClientPhysicsSync.lua** - Syncs client-side NPC data to server
- **ServerFallbackSimulator.lua** - Server-side simulation fallback for client physics NPCs

**Movement** (`Components/Others/Movement/`)
- **MovementBehavior.lua** - Handles NPC movement logic (ranged, melee, idle wandering)
- **PathfindingManager.lua** - Manages pathfinding using NoobPath library

**Sight** (`Components/Others/Sight/`)
- **SightDetector.lua** - Detects targets (omnidirectional or directional vision)
- **SightVisualizer.lua** - Visual debugging for sight ranges and cones

**Data Access** (`Components/`)
- **Get().lua** - Read NPC data
- **Set().lua** - Modify NPC data

---

### Client-Side (`NPC_Controller`)

**Location**: `src/ReplicatedStorage/ClientSource/Client/NPC_Controller/`

#### Core Components

**Rendering** (`Components/Others/Rendering/`)
- **NPCRenderer.lua** - Renders NPC visual models on client (traditional mode)
- **NPCAnimator.lua** - Handles NPC animations using BetterAnimate
- **ClientPhysicsRenderer.lua** - Renders and simulates client physics NPCs

**NPC Management** (`Components/Others/NPC/`)
- **ClientNPCManager.lua** - Manages client-side NPC instances
- **ClientNPCSimulator.lua** - Main client-side physics simulation loop

**Movement** (`Components/Others/Movement/`)
- **ClientMovement.lua** - Client-side movement behavior
- **ClientPathfinding.lua** - Client-side pathfinding using NoobPath
- **ClientJumpSimulator.lua** - Handles client-side NPC jumping

**Sight** (`Components/Others/Sight/`)
- **ClientSightDetector.lua** - Client-side target detection
- **ClientSightVisualizer.lua** - Client-side sight debugging visuals

**Data Access** (`Components/`)
- **Get().lua** - Read client NPC data
- **Set().lua** - Modify client NPC data

---

### Shared Components

**Location**: `src/ReplicatedStorage/SharedSource/Datas/NPCs/`

- **RenderConfig** - Client rendering configuration (distance culling, render limits)
- **OptimizationConfig** - Global optimization flags (UseClientPhysics)

---

## System Flow

### Traditional Server-Side Physics Mode

```
1. NPC_Service:SpawnNPC(config) called
2. NPCSpawner creates NPC model on server
3. MovementBehavior & SightDetector initialize
4. PathfindingManager handles pathfinding
5. NPCRenderer (client) clones visual model
6. NPCAnimator (client) handles animations
```

### Client-Side Physics Mode (UseClientPhysics = true)

```
1. NPC_Service:SpawnNPC(config) called with UseClientPhysics=true
2. ClientPhysicsSpawner creates minimal server data
3. Data synced to clients via ClientPhysicsSync
4. ClientPhysicsRenderer (client) creates full NPC model
5. ClientNPCSimulator (client) runs physics loop
6. ClientMovement & ClientPathfinding handle behavior
7. ClientSightDetector detects targets
8. ServerFallbackSimulator provides backup server simulation
```

---

## Component Connections

### Server Components
```
NPC_Service (Main)
├── Components/
│   ├── Get()
│   ├── Set()
│   └── Others/
│       ├── Spawning/
│       │   └── NPCSpawner
│       ├── Physics/
│       │   ├── ClientPhysicsSpawner
│       │   ├── ClientPhysicsSync
│       │   └── ServerFallbackSimulator
│       ├── Movement/
│       │   ├── MovementBehavior
│       │   └── PathfindingManager
│       └── Sight/
│           ├── SightDetector
│           └── SightVisualizer
```

### Client Components
```
NPC_Controller (Main)
├── Components/
│   ├── Get()
│   ├── Set()
│   └── Others/
│       ├── Rendering/
│       │   ├── NPCRenderer
│       │   ├── NPCAnimator
│       │   └── ClientPhysicsRenderer
│       ├── NPC/
│       │   ├── ClientNPCManager
│       │   └── ClientNPCSimulator
│       ├── Movement/
│       │   ├── ClientMovement
│       │   ├── ClientPathfinding
│       │   └── ClientJumpSimulator
│       └── Sight/
│           ├── ClientSightDetector
│           └── ClientSightVisualizer
```

---

## Data Flow

### Traditional Mode
```
Server (NPC_Service)
    ↓ (Replicates NPC Model)
Client (NPC_Controller)
    ↓ (Reads ModelPath attribute)
NPCRenderer (Clones visual)
    ↓
NPCAnimator (Animates visual)
```

### Client Physics Mode
```
Server (NPC_Service)
    ↓ (Sends NPC data via RemoteEvents)
ClientPhysicsSync
    ↓
Client (ClientNPCManager)
    ↓
ClientPhysicsRenderer (Creates full model)
    ↓
ClientNPCSimulator (Physics loop)
    ├── ClientMovement
    ├── ClientPathfinding
    ├── ClientSightDetector
    └── ClientJumpSimulator
    ↓ (Sends position updates)
Server (ServerFallbackSimulator)
```

---

## Key Differences Between Modes

| Feature | Traditional Mode | Client Physics Mode |
|---------|-----------------|---------------------|
| **Physics** | Server | Client |
| **Pathfinding** | Server | Client |
| **Network Traffic** | High | Low (70-95% reduction) |
| **NPC Limit** | ~100 NPCs | 1000+ NPCs |
| **Security** | Full server authority | Client has position authority |
| **Use Case** | Combat NPCs | Ambient/background NPCs |

---

## Configuration Files

- **RenderConfig.lua** - Controls client rendering behavior
  - `ENABLED` - Toggle client rendering
  - `MAX_RENDER_DISTANCE` - Distance culling
  - `MAX_RENDERED_NPCS` - Render limit

- **OptimizationConfig.lua** - Global optimization settings
  - `UseClientPhysics` - Global client physics toggle

---

## API Entry Points

### Server API
```lua
-- Spawn NPC (traditional or client physics based on config)
NPC_Service:SpawnNPC(config)

-- Read NPC data
NPC_Service.GetComponent:GetNPCData(npcModel)
NPC_Service.GetComponent:GetCurrentTarget(npcModel)
NPC_Service.GetComponent:GetAllNPCs()

-- Modify NPC data
NPC_Service.SetComponent:SetTarget(npcModel, target)
NPC_Service.SetComponent:SetDestination(npcModel, destination)
NPC_Service.SetComponent:SetCustomData(npcModel, key, value)
NPC_Service.SetComponent:DestroyNPC(npcModel)
```

### Client API
```lua
-- Read rendered NPC data
NPC_Controller.GetComponent:GetRenderedNPCs()

-- Access client NPC manager
NPC_Controller.Components.ClientNPCManager
```

---

## External Dependencies

- **NoobPath** - Advanced pathfinding library
- **BetterAnimate** - Animation system
- **Knit** - Framework for services/controllers
- **ProfileService** - Player data management (collision integration)
