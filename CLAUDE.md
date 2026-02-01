# Claude AI Guide for Comprehensive NPC System

This guide helps Claude AI understand the conventions, architecture, and best practices for this repository.

## Repository Overview

This is a **Comprehensive NPC System for Roblox** built on the **SuperbulletFrameworkV1-Knit** framework. It provides server-authoritative NPCs with client-side rendering optimization, advanced pathfinding, sight detection, and behavior systems.

## Technology Stack

- **Language:** Lua (Luau - Roblox's typed Lua variant)
- **Framework:** SuperbulletFrameworkV1-Knit (modified Knit framework)
- **Platform:** Roblox
- **Package Manager:** Wally
- **Build Tool:** Rojo

## Project Structure

```
src/
├── ReplicatedStorage/
│   ├── ClientSource/
│   │   └── Client/              # Client-side controllers
│   └── SharedSource/
│       └── Datas/                # Shared data and configurations
└── ServerScriptService/
    └── ServerSource/
        └── Server/               # Server-side services
            └── NPC_Service/      # Main NPC system
                └── Components/   # Modular components
                    ├── Get().lua           # Read operations
                    ├── Set().lua           # Write operations
                    └── Others/             # Specialized components
```

## Architecture Principles

### 1. Modified Knit Framework

This project uses a **modified Knit framework** with component-based architecture:

- **`Get().lua`**: Read-only operations (fetching data, queries)
- **`Set().lua`**: Write operations (modifying state, mutations)
- **`Others/`**: Specialized components (pathfinding, detection, etc.)

### 2. Component Communication Rules

**CRITICAL RULE:** `Get().lua` and `Set().lua` CANNOT communicate directly with each other.

**✅ ALLOWED:**
- Parent system coordinating between Get and Set
- Components calling other systems through parent
- Others/ components using parent to access Get/Set

**❌ FORBIDDEN:**
- Direct `require()` between Get().lua and Set().lua
- Others/ components calling external systems directly

### 3. Server-Client Architecture

- **Server-Authoritative:** Game logic, NPC behavior, and state management on server
- **Client-Side Rendering:** Visual representation and animations on client
- **Security First:** Never trust client data, always validate on server

## Coding Style and Conventions

### Naming Conventions

- **Services/Controllers:** PascalCase with suffix (e.g., `NPC_Service`, `NPC_Controller`)
- **Functions:** PascalCase (e.g., `SpawnNPC`, `SetTarget`)
- **Variables:** camelCase (e.g., `npcData`, `currentTarget`)
- **Constants:** UPPER_SNAKE_CASE (e.g., `MAX_RENDER_DISTANCE`, `VISUALIZER_ENABLED`)
- **Private Functions:** Prefix with `_` (e.g., `_validatePosition`, `_cleanupNPC`)

### Code Organization

1. **Services should use Component pattern when > 300 lines**
2. **Group related functionality in Others/ components**
3. **Keep init.lua as coordinator, not implementation**
4. **Use ONLY ONE principle for feature additions**

### Documentation Standards

- Add comments for complex algorithms or non-obvious logic
- Document configuration parameters clearly
- Include usage examples in service documentation
- Keep inline comments concise and relevant

## NPC System Specifics

### Key Components

1. **NPCSpawner**: Handles NPC creation and initialization
2. **MovementBehavior**: Controls NPC movement (Ranged, Melee, Flee modes)
3. **PathfindingManager**: Advanced pathfinding with NoobPath integration
4. **SightDetector**: Target detection (Omnidirectional/Directional modes)
5. **SightVisualizer**: Debug visualization tools

### Configuration Philosophy

- **Flexible by default**: Most parameters are optional with sensible defaults
- **Behavior toggles**: Enable/disable features independently
- **Performance conscious**: Options for client-side physics for 1000+ NPCs

### Testing

Test scripts are located in `src/ServerScriptService/` and demonstrate:
- Basic NPC spawning
- Mass spawn tests
- Movement modes (Ranged, Melee, Flee)
- Tower defense scenarios
- Debug single NPC behavior

**These test scripts can be safely deleted** after reviewing the examples.

## Common Tasks

### Adding a New Component

1. Create component in appropriate `Components/` folder
2. Follow Get/Set/Others categorization
3. Use parent system for cross-component communication
4. Test with existing NPC spawning tests

### Modifying NPC Behavior

1. Check which component handles the behavior
2. Make changes in appropriate Get/Set/Others component
3. Update configuration parameters if needed
4. Test with multiple NPCs and edge cases

### Performance Optimization

1. Consider client-side rendering distance
2. Use `UseClientPhysics` for 1000+ NPCs
3. Disable visualizers in production
4. Batch operations when possible

## Security Considerations

1. **Server validates all NPC positions and states**
2. **Client-side physics is opt-in** (UseClientPhysics flag)
3. **Client-side rendering is visual only** (no gameplay impact)
4. **Faction system prevents unnecessary targeting calculations**

## Build and Test

- **No formal build process required** (Roblox Studio or Rojo sync)
- **Test scripts provided** in ServerScriptService
- **Visualizers available** for debugging sight detection and pathfinding

## Contributing Philosophy

- **Minimal changes**: Make the smallest modification necessary
- **Maintain compatibility**: Don't break existing NPC configurations
- **Document changes**: Update README and inline docs
- **Test thoroughly**: Verify with multiple NPCs and scenarios

## Anti-Patterns to Avoid

1. ❌ Direct communication between Get().lua and Set().lua
2. ❌ Putting game logic on client side
3. ❌ Breaking server authority for NPC behavior
4. ❌ Removing working code without clear reason
5. ❌ Adding dependencies without necessity

## Version History

- **v1.0**: Initial release with core NPC system
- **v1.1**: Added UseClientPhysics optimization for 1000+ NPCs

## Additional Resources

- Framework docs: See `/documentations/codebase/organizing-project-structure.md`
- System architecture: See `/src/ReplicatedStorage/SharedSource/Datas/NPCs/Documentations/System_Architecture.md`
- Future plans: See `/documentations/Unimplemented/` directory
