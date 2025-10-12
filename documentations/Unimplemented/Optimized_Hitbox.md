# Optimized Hitbox Detection

## Overview

This document outlines optimization strategies for hitbox detection, particularly for high fire rate scenarios in tower defense games with many NPCs.

## Batch Detection for High Fire Rate Weapons

### Problem

High fire rate weapons (such as guns or rapid-fire turrets) can generate excessive network traffic and server load when each shot triggers individual hitbox detection and server communication. In tower defense games with multiple NPCs, this can severely impact performance.

### Solution: Client-Side Batch Detection

> ⚠️ **SECURITY WARNING**
>
> This implementation is exploitable because it allows the client to handle hitbox detection. Malicious clients can send false hit data to the server.
>
> **This implementation has NO anti-cheat validation.** It trusts client data completely.
>
> **Why No Anti-Cheat?**
>
> Anti-cheat validation for high fire rate batch detection typically produces **many false positives** due to:
>
> - Network latency variations between client and server
> - Different tickrates/framerates causing timing discrepancies
> - NPC movement prediction mismatches
> - Hitbox position interpolation differences
> - Legitimate lag spikes being flagged as suspicious
>
> These false positives would incorrectly reject valid hits from legitimate players, creating a frustrating experience. For tower defense games, this trade-off is unacceptable.
>
> **You are free to implement your own anti-cheat validation**, but be aware it usually comes with significant false positive rates that may negatively impact legitimate gameplay.
>
> **However**, this approach is necessary for games like tower defense where:
>
> - Hitbox accuracy barely matters (enemies are numerous and less valuable individually)
> - Performance optimization is the key priority (especially if your game will have 100+ loaded NPCs)
> - The cost of potential exploits is lower than the cost of poor performance
> - The game is PvE (player vs environment) rather than competitive
>
> **Not recommended for**: Competitive games, PvP scenarios, or games where individual hits have high value.

#### Concept

Instead of firing individual hit detection requests for each bullet/projectile, batch multiple detections together and send them to the server in a single network call.

#### Implementation Strategy

1. **Client-Side Detection Accumulation**

   - Client performs hitbox detection locally
   - Store hit results in a buffer/queue
   - Accumulate hits over a short time window (e.g., 0.1-0.2 seconds)

2. **Batch Transmission**

   - Send accumulated hit data to server in batches
   - Include timestamp for each hit to maintain proper ordering
   - Compress data format to minimize bandwidth for server

3. **Server-Side Processing**
   - Server receives batched hit data
   - Processes damage/effects in order
   - Returns confirmation to client (optional)

#### Benefits

- **Reduced Network Traffic**: Multiple hits sent in single remote call
- **Lower Server Load**: Fewer remote invocations to handle
- **Better Scalability**: Can handle more NPCs and turrets simultaneously
- **Improved Performance**: Especially critical in tower defense scenarios with many active units

#### Data Structure Example

```lua
{
    turretId = "Turret_001",
    batchTimestamp = tick(),
    hits = {
        {
            npcId = "NPC_123",
            hitPosition = Vector3.new(x, y, z),
            timestamp = tick(),
            damage = 10
        },
        {
            npcId = "NPC_456",
            hitPosition = Vector3.new(x, y, z),
            timestamp = tick(),
            damage = 10
        }
        -- ... more hits
    }
}
```

#### Configuration Parameters

- **Batch Window**: Time interval for accumulating hits (default: 0.15s)
- **Max Batch Size**: Maximum hits per batch (default: 20)
- **Force Send Threshold**: Send immediately if batch reaches size limit

### Considerations

#### Synchronization

- Account for network latency
- Use timestamps for proper hit ordering
- Handle edge cases (NPC dies mid-batch)

#### Tower Defense Specific

- Multiple turrets can send batches independently
- Server processes hits without validation for maximum performance
- Client authority is acceptable for PvE scenarios

## Hitbox Detection Presets

### 1. Sight Detection (Direction-Wise / Cone Detection)

Detects targets within a cone-shaped area in front of the weapon/turret.

**Use Cases:**

- Directional turrets
- Laser weapons
- Aimed projectiles
- Line-of-sight weapons

**Parameters:**

- `Origin`: Starting position of the cone
- `Direction`: Forward direction vector
- `Range`: Maximum detection distance
- `ConeAngle`: Angle of the detection cone (in degrees)
- `LayerMask`: What objects to detect

**Implementation:**

```lua
-- Check if target is within cone
local toTarget = (targetPosition - origin).Unit
local angle = math.deg(math.acos(direction:Dot(toTarget)))
local distance = (targetPosition - origin).Magnitude

if angle <= coneAngle / 2 and distance <= range then
    -- Target is within detection cone
end
```

### 2. Magnitude Detection (360° Detection)

Detects all targets within a spherical radius, regardless of direction.

**Use Cases:**

- Area of effect weapons
- Explosions
- Pulse weapons
- Proximity-based attacks
- Splash damage

**Parameters:**

- `Origin`: Center position of the sphere
- `Radius`: Detection range
- `LayerMask`: What objects to detect

**Implementation:**

```lua
-- Check if target is within radius
local distance = (targetPosition - origin).Magnitude

if distance <= radius then
    -- Target is within detection range
end
```

### Choosing the Right Preset

| Preset           | Performance | Accuracy | Best For                                     |
| ---------------- | ----------- | -------- | -------------------------------------------- |
| Sight (Cone)     | Better      | Higher   | Directional weapons, turrets with rotation   |
| Magnitude (360°) | Good        | Lower    | AoE weapons, explosions, proximity detection |

**Performance Tip**: Sight detection can be optimized further by checking magnitude first (cheap check) before calculating angles (expensive check).

## Future Enhancements

- Predictive hit validation
- Adaptive batch sizing based on server load
- Priority queues for different weapon types
- Spatial partitioning for faster validation
- Hybrid detection methods (combine cone and magnitude)
- Custom detection shapes (rectangles, ellipses)
