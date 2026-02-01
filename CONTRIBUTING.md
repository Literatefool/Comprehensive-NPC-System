# Contributing to Comprehensive NPC System

Thank you for your interest in contributing to the Comprehensive NPC System! This document provides guidelines for contributing to the project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

- Be respectful and constructive in all interactions
- Focus on what is best for the community and the project
- Show empathy towards other community members
- Accept constructive criticism gracefully

## Getting Started

### Prerequisites

- Roblox Studio installed
- Basic knowledge of Lua/Luau
- Understanding of Roblox scripting fundamentals
- Familiarity with the Knit framework (helpful but not required)

### Installation Methods

Choose one of these methods to get started:

#### Method 1: Rojo (Recommended for Development)

```bash
# Clone the repository
git clone https://github.com/Literatefool/Comprehensive-NPC-System.git
cd Comprehensive-NPC-System

# Install Rojo if not already installed
# See https://rojo.space/docs/installation/

# Start Rojo server
rojo serve

# Connect from Roblox Studio using the Rojo plugin
```

#### Method 2: RBXL Place File

1. Download `npc_system_place.rbxl` from the repository
2. Open in Roblox Studio
3. Make your changes
4. Export modified scripts back to the repository structure

## Development Workflow

### Understanding the Architecture

Before making changes, familiarize yourself with:

1. **Modified Knit Framework**: Read `/documentations/codebase/organizing-project-structure.md`
2. **System Architecture**: Check `/src/ReplicatedStorage/SharedSource/Datas/NPCs/Documentations/System_Architecture.md`
3. **CLAUDE.md**: Review for coding conventions and patterns

### Component Structure

The project uses a component-based architecture:

```
ServiceName/
├── init.lua              # Main service coordinator
└── Components/
    ├── Get().lua         # Read-only operations
    ├── Set().lua         # Write operations
    └── Others/           # Specialized components
        ├── Component1.lua
        └── Component2.lua
```

**Key Rules:**
- `Get().lua` and `Set().lua` CANNOT communicate directly
- Use parent system (init.lua) to coordinate between components
- Keep components focused and single-purpose

### Making Changes

1. **Create a branch** for your feature or bugfix:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make minimal changes**: Only modify what's necessary
3. **Test your changes**: Use the test scripts in ServerScriptService
4. **Document your changes**: Update relevant documentation

### Testing Your Changes

Test scripts are provided in `src/ServerScriptService/`:
- `NPC_Test.server.lua` - Basic NPC spawning
- `NPC_MassSpawnTest.server.lua` - Performance testing
- `FleeMode_Test.server.lua` - Flee behavior
- Others for specific features

Create your own test script to validate your changes:

```lua
-- MyFeatureTest.server.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.OnStart():await()

local NPC_Service = Knit.GetService("NPC_Service")

-- Test your feature here
local testNPC = NPC_Service:SpawnNPC({
    Name = "TestNPC",
    Position = Vector3.new(0, 10, 0),
    ModelPath = game.ReplicatedStorage.Assets.NPCs.Characters.Rig,
    -- Your feature configuration...
})
```

## Coding Standards

### Lua Style Guide

**Naming Conventions:**
- Services/Controllers: `PascalCase` with suffix (e.g., `CombatService`)
- Functions: `PascalCase` (e.g., `CalculateDamage`)
- Variables: `camelCase` (e.g., `playerHealth`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_HEALTH`)
- Private functions: Prefix with `_` (e.g., `_validateInput`)

**Code Structure:**
```lua
-- Services at top
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- External requires
local Knit = require(ReplicatedStorage.Packages.Knit)
local Promise = require(ReplicatedStorage.Packages.Promise)

-- Constants
local MAX_NPCS = 100
local UPDATE_INTERVAL = 0.5

-- Local variables
local activeNPCs = {}

-- Private functions
local function _validateNPC(npc)
    return npc and npc:IsA("Model")
end

-- Public functions
function MyService:SpawnNPC(config)
    -- Implementation
end
```

**Comments:**
- Use comments sparingly for complex logic
- Explain WHY, not WHAT (code should be self-documenting)
- Keep comments up-to-date with code changes

**Best Practices:**
- Keep functions under 50 lines when possible
- One function, one responsibility
- Avoid deep nesting (max 3 levels)
- Use early returns to reduce nesting
- Handle edge cases explicitly

### Component Guidelines

**Get().lua (Read Operations):**
```lua
local NPCGet = {}

function NPCGet:GetNPCData(npcId)
    return self._npcs[npcId]
end

function NPCGet:GetCurrentTarget(npcId)
    local npc = self._npcs[npcId]
    return npc and npc.target
end

return NPCGet
```

**Set().lua (Write Operations):**
```lua
local NPCSet = {}

function NPCSet:SetTarget(npcId, target)
    local npc = self._npcs[npcId]
    if npc then
        npc.target = target
        self:_notifyTargetChange(npcId)
    end
end

return NPCSet
```

**Others/ (Specialized Components):**
```lua
local PathfindingManager = {}

function PathfindingManager:CalculatePath(start, destination)
    -- Complex pathfinding logic
end

return PathfindingManager
```

## Submitting Changes

### Pull Request Process

1. **Update documentation** if you've made significant changes
2. **Test thoroughly** with multiple scenarios
3. **Write a clear PR description**:
   - What problem does this solve?
   - What changes were made?
   - How was it tested?
   - Any breaking changes?

4. **Keep PRs focused**: One feature or fix per PR
5. **Follow the PR template** (if available)

### PR Title Format

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

Examples:
- `feat: Add flee mode for civilian NPCs`
- `fix: Resolve pathfinding issue on uneven terrain`
- `docs: Update usage examples in README`

### Commit Message Guidelines

Write clear, descriptive commit messages:

```
Good:
✓ Add melee offset configuration for close combat NPCs
✓ Fix sight detection not working with transparent parts
✓ Optimize pathfinding for large maps

Bad:
✗ Update stuff
✗ Fix bug
✗ Changes
```

## Reporting Issues

### Bug Reports

When reporting bugs, include:

1. **Clear description** of the issue
2. **Steps to reproduce** the problem
3. **Expected behavior** vs. **actual behavior**
4. **System information**:
   - Roblox Studio version
   - Operating system
   - Repository version/commit

5. **Error messages** or console output
6. **Minimal test case** if possible

**Template:**
```markdown
**Description:**
NPCs are not detecting players when using Directional sight mode.

**Steps to Reproduce:**
1. Spawn an NPC with SightMode = "Directional"
2. Walk in front of the NPC within sight range
3. NPC does not detect player

**Expected Behavior:**
NPC should detect and target the player.

**Actual Behavior:**
NPC ignores player completely.

**Error Messages:**
[None in console]

**Environment:**
- Roblox Studio: 0.543.0.123456
- OS: Windows 11
- Commit: abc1234
```

### Feature Requests

When suggesting features:

1. **Describe the feature** clearly
2. **Explain the use case** - why is it needed?
3. **Provide examples** of how it would work
4. **Consider compatibility** with existing features
5. **Note any breaking changes** or dependencies

## Areas for Contribution

We welcome contributions in these areas:

- **New Movement Behaviors**: Custom movement patterns
- **Sight Detection Modes**: Additional detection algorithms
- **Performance Optimizations**: Improve efficiency
- **Documentation**: Tutorials, examples, guides
- **Bug Fixes**: Resolve existing issues
- **Test Coverage**: Add more test scenarios
- **Example Scenarios**: Tower defense, RPG, etc.

## Questions?

If you have questions about contributing:

1. Check existing documentation in `/documentations/`
2. Review similar code in the repository
3. Open a discussion issue on GitHub
4. Read the CLAUDE.md guide for conventions

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to making this the best open-source NPC system for Roblox! 🎮✨
