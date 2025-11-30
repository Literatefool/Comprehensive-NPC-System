# NPC Collision Management

## Overview

This guide explains how to disable NPC collisions in the NPC System. By default, NPCs have collisions enabled, which means they physically interact with players, other NPCs, and the environment. Disabling collisions can improve performance and allow NPCs to pass through objects.

---

## Disabling NPC Collisions

### Using Superbullet Marketplace

The easiest way to disable NPC collisions is by installing the official collision management system from the Superbullet Marketplace.

#### Marketplace ID
```
ba93b1f6-7e7a-42fe-8eb9-23e74224f4b5
```

#### Installation

Once you reference this system ID, the SuperbulletAI will automatically install and configure it for you.

---

## What This System Does

The collision management system:

- Disables/Enables physical collisions for NPC models
- Maintains visual appearance of NPCs
- Improves performance by reducing physics calculations
- Prevents NPCs from blocking pathways
- Allows NPCs to pass through walls and objects

---

## Use Cases

**When to Disable Collisions:**
- Ambient/background NPCs that don't need physical interaction
- Ghost or ethereal NPCs
- High-density NPC environments (1000+ NPCs)
- NPCs that follow predefined paths through complex geometry
- Performance optimization scenarios

**When to Keep Collisions:**
- Combat NPCs that need to physically block players
- NPCs that should interact with physics-based obstacles
- NPCs used in puzzle mechanics
- Scenarios requiring realistic crowd simulation

---

## Performance Impact

Disabling collisions can significantly improve performance:

- Reduces physics calculations per frame
- Lowers CPU usage in high NPC count scenarios
- Allows more NPCs to be spawned simultaneously
- Particularly beneficial when combined with Client Physics Mode

---

## Compatibility

This collision management system works with:

- **Traditional Server-Side Physics Mode**
- **Client-Side Physics Mode**
- **Both RenderConfig and OptimizationConfig settings**

---

## Integration Notes

The collision management component integrates seamlessly with:

- NPCSpawner (traditional mode)
- ClientPhysicsSpawner (client physics mode)
- NPCRenderer (client rendering)
- ClientPhysicsRenderer (client physics rendering)

No additional configuration required after installation.

---

## Related Documentation

- [System_Architecture.md](./System_Architecture.md) - Full NPC System architecture overview
- RenderConfig.lua - Client rendering configuration
- OptimizationConfig.lua - Global optimization settings
