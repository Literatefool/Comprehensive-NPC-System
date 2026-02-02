# Development Guide

This guide helps developers set up their environment and start working with the Comprehensive NPC System.

## Table of Contents

- [Quick Start](#quick-start)
- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Building and Testing](#building-and-testing)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)

## Quick Start

### For Testing (Fastest)

1. Download `npc_system_place.rbxl`
2. Open in Roblox Studio
3. Press F5 to run and test NPCs

### For Development (Recommended)

```bash
# Clone the repository
git clone https://github.com/Literatefool/Comprehensive-NPC-System.git
cd Comprehensive-NPC-System

# Install Rojo (if not already installed)
# Visit https://rojo.space/docs/installation/

# Start Rojo server
rojo serve

# Open Roblox Studio and connect via Rojo plugin
```

## Development Environment Setup

### Required Tools

1. **Roblox Studio** - Download from [roblox.com/create](https://www.roblox.com/create)
2. **Rojo** (for syncing files) - Install from [rojo.space](https://rojo.space/)
3. **Git** - For version control
4. **Code Editor** (optional but recommended):
   - Visual Studio Code with Luau LSP extension
   - Sublime Text with Lua support
   - Any editor you prefer

### Optional Tools

- **Wally** - Roblox package manager (for dependency management)
- **Selene** - Lua linter (for code quality)
- **Foreman** - Tool manager for Roblox tools

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Literatefool/Comprehensive-NPC-System.git
   cd Comprehensive-NPC-System
   ```

2. **Install Rojo:**
   ```bash
   # Using Aftman (recommended - install from https://github.com/LPGhatguy/aftman)
   aftman install

   # Or manually download from rojo.space
   ```

3. **Start development server:**
   ```bash
   rojo serve
   ```

4. **Connect Roblox Studio:**
   - Open Roblox Studio
   - Install Rojo plugin if not already installed
   - Click "Connect" in the Rojo plugin
   - Project should sync automatically

## Project Structure

```
Comprehensive-NPC-System/
├── src/                              # Source code
│   ├── ReplicatedStorage/
│   │   ├── ClientSource/
│   │   │   └── Client/              # Client controllers
│   │   │       └── NPC_Controller/  # Client-side NPC rendering
│   │   └── SharedSource/
│   │       └── Datas/               # Shared configurations
│   │           └── NPCs/            # NPC-related data
│   └── ServerScriptService/
│       ├── ServerSource/
│       │   └── Server/              # Server services
│       │       └── NPC_Service/     # Main NPC system
│       │           ├── init.lua
│       │           └── Components/
│       │               ├── Get().lua
│       │               ├── Set().lua
│       │               └── Others/  # Pathfinding, movement, etc.
│       ├── KnitServer.server.lua    # Knit initialization
│       └── *Test.server.lua         # Test scripts
│
├── documentations/                   # Documentation
│   ├── codebase/                    # Architecture docs
│   ├── Implementation_Plans/        # Future features
│   └── Unimplemented/               # Planned features
│
├── default.project.json             # Rojo configuration
├── wally.toml                       # Package dependencies
├── selene.toml                      # Linter configuration
├── foreman.toml                     # Tool versions
├── README.md                        # Project overview
├── CLAUDE.md                        # AI assistant guide
├── CONTRIBUTING.md                  # Contribution guidelines
└── DEVELOPMENT.md                   # This file
```

### Key Files

- **`default.project.json`** - Rojo project configuration
- **`wally.toml`** - Package dependencies (Knit, Promise, etc.)
- **`src/ServerScriptService/KnitServer.server.lua`** - Entry point for server
- **`src/StarterPlayer/StarterPlayerScripts/KnitClient.client.lua`** - Entry point for client

## Building and Testing

### Running Tests

Test scripts are located in `src/ServerScriptService/`:

```lua
-- NPC_Test.server.lua - Basic functionality
-- NPC_MassSpawnTest.server.lua - Performance testing
-- FleeMode_Test.server.lua - Flee behavior
-- NPC_Debug_SingleMelee.server.lua - Debug single NPC
-- NPC_TowerDefense_Test.server.lua - Tower defense scenario
```

To run tests:
1. Open `npc_system_place.rbxl` or sync with Rojo
2. Enable the test script you want to run
3. Press F5 to start testing
4. Check output in console

### Creating Custom Tests

```lua
-- MyTest.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Wait for Knit to start
Knit.OnStart():await()

local NPC_Service = Knit.GetService("NPC_Service")

-- Your test code here
local testNPC = NPC_Service:SpawnNPC({
    Name = "TestNPC",
    Position = Vector3.new(0, 10, 0),
    ModelPath = game.ReplicatedStorage.Assets.NPCs.Characters.Rig,
    MaxHealth = 100,
    WalkSpeed = 16,
    SightRange = 60,
})

print("Test NPC spawned:", testNPC)
```

### Disabling Visualizers

For performance testing, disable debug visualizers in RenderConfig:

```lua
-- src/ReplicatedStorage/SharedSource/Datas/NPCs/RenderConfig.lua
local RenderConfig = {
    -- ... other settings ...
    
    -- Show pathfinding waypoints (blue/yellow/red dots along NPC paths)
    SHOW_PATH_VISUALIZER = false,  -- Change from true to false to disable
    
    -- Show sight range visualization (cones/spheres for NPC vision)
    SHOW_SIGHT_VISUALIZER = false,  -- Change from true to false to disable
}
```

**Note:** By default, both visualizers are enabled (`true`). Change to `false` for production or performance testing.

## Development Workflow

### 1. Understanding the Modified Knit Framework

This project uses a modified Knit framework with component architecture:

**Component Types:**
- **Get().lua** - Read-only operations (queries, data fetching)
- **Set().lua** - Write operations (mutations, state changes)
- **Others/** - Specialized components (algorithms, utilities)

**Critical Rule:** Get().lua and Set().lua CANNOT communicate directly. Use the parent system (init.lua) as coordinator.

### 2. Adding New Features

**Step 1: Plan Your Component**

Determine what type of component you need:
- Read-only? → Add to `Get().lua`
- Write operation? → Add to `Set().lua`
- Complex logic? → Create new file in `Others/`

**Step 2: Implement**

```lua
-- Others/MyNewComponent.lua
local MyNewComponent = {}

function MyNewComponent:DoSomething(npc, params)
    -- Implementation
end

return MyNewComponent
```

**Step 3: Test**

Create a test script to validate:

```lua
-- MyFeatureTest.server.lua
local NPC_Service = Knit.GetService("NPC_Service")

local npc = NPC_Service:SpawnNPC({ --[[ config ]] })
NPC_Service:MyNewFeature(npc, params)  -- Your new method
```

### 3. Modifying Existing Features

1. **Locate the component** handling the feature
2. **Understand current behavior** by reading code and testing
3. **Make minimal changes** - only what's necessary
4. **Test thoroughly** with various configurations
5. **Update documentation** if behavior changes

### 4. Working with NPC Behaviors

**Movement Modes:**
- **Ranged** - Maintains distance, strafes
- **Melee** - Closes distance to MeleeOffsetRange
- **Flee** - Runs away from threats

**Sight Modes:**
- **Directional** - Cone-based detection (forward facing)
- **Omnidirectional** - 360° detection

**Configuration Example:**
```lua
local npc = NPC_Service:SpawnNPC({
    Name = "CustomNPC",
    Position = Vector3.new(0, 10, 0),
    ModelPath = modelReference,
    
    -- Behavior
    MovementMode = "Melee",
    SightMode = "Directional",
    MeleeOffsetRange = 5,
    
    -- Toggles
    EnableIdleWander = true,
    EnableCombatMovement = true,
    UsePathfinding = true,
})
```

## Troubleshooting

### Common Issues

**Issue: Rojo won't connect**
- Ensure `rojo serve` is running
- Check Rojo plugin is installed in Studio
- Verify port 34872 is not blocked
- Try restarting Rojo and Studio

**Issue: NPCs not spawning**
- Check ModelPath is valid
- Verify Knit has started (`Knit.OnStart():await()`)
- Check console for error messages
- Ensure model has required structure (Humanoid, HumanoidRootPart)

**Issue: Pathfinding not working**
- Verify `UsePathfinding = true` in config
- Check if terrain/obstacles are too complex
- Try disabling pathfinding visualizer for better performance
- Ensure destination is reachable

**Issue: Sight detection not working**
- Check `SightRange` is set appropriately
- Verify `SightMode` is correct ("Directional" or "Omnidirectional")
- Enable sight visualizer for debugging
- Check for parts blocking line of sight

**Issue: Performance problems with many NPCs**
- Use `UseClientPhysics = true` for 1000+ NPCs
- Reduce `MAX_RENDER_DISTANCE` in RenderConfig
- Lower `MAX_RENDERED_NPCS` setting
- Disable visualizers in production

### Getting Help

1. **Check documentation** in `/documentations/` folder
2. **Review test scripts** for usage examples
3. **Read CLAUDE.md** for architecture patterns
4. **Search existing issues** on GitHub
5. **Open a new issue** with detailed description

## Best Practices

### Code Quality

- **Keep functions focused** - One responsibility per function
- **Use meaningful names** - Self-documenting code
- **Handle edge cases** - Validate inputs, check nil values
- **Comment complex logic** - Explain WHY, not WHAT
- **Follow conventions** - See CLAUDE.md for style guide

### Performance

- **Profile before optimizing** - Measure actual impact
- **Batch operations** - Spawn multiple NPCs together
- **Use appropriate settings** - Don't enable features you don't need
- **Test with target NPC count** - Validate performance at scale

### Testing

- **Test multiple scenarios** - Not just happy path
- **Check edge cases** - Nil values, invalid configs
- **Performance test** - Spawn 50+ NPCs
- **Visual verification** - Actually watch NPCs behave

### Version Control

- **Commit often** - Small, focused commits
- **Write clear messages** - Describe what and why
- **Branch for features** - Keep main branch stable
- **Pull before push** - Stay in sync with team

## Additional Resources

- **Framework Guide:** `/documentations/codebase/organizing-project-structure.md`
- **System Architecture:** `/src/ReplicatedStorage/SharedSource/Datas/NPCs/Documentations/System_Architecture.md`
- **Collision Management:** `/src/ReplicatedStorage/SharedSource/Datas/NPCs/Documentations/Collision_Management.md`
- **Future Features:** `/documentations/Unimplemented/Optimized_Hitbox.md`

## Next Steps

1. **Explore the codebase** - Read through NPC_Service
2. **Run test scripts** - See NPCs in action
3. **Make a small change** - Add a print statement, test it
4. **Create something new** - Add a custom behavior
5. **Share your work** - Submit a PR!

Happy developing! 🚀
