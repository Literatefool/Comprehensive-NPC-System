---
name: Bug Report
about: Report a bug or issue with the NPC system
title: '[BUG] '
labels: bug
assignees: ''
---

## Bug Description

A clear and concise description of what the bug is.

## Steps to Reproduce

1. Go to '...'
2. Click on '...'
3. Spawn NPC with config '...'
4. See error

## Expected Behavior

A clear description of what you expected to happen.

## Actual Behavior

What actually happened instead.

## Configuration

```lua
-- NPC spawn configuration that causes the issue
local npc = NPC_Service:SpawnNPC({
    Name = "BuggyNPC",
    -- ... your configuration
})
```

## Error Messages

```
Paste any error messages or console output here
```

## Environment

- **Roblox Studio Version:** [e.g., 0.543.0.123456]
- **Operating System:** [e.g., Windows 11, macOS 13]
- **Repository Commit:** [e.g., abc1234]
- **Installation Method:** [Rojo / RBXL file / SuperbulletAI]

## Additional Context

Add any other context about the problem here, such as:
- Does it happen with all NPCs or specific configurations?
- Does it happen consistently or intermittently?
- Screenshots or videos if applicable

## Possible Solution (Optional)

If you have ideas on how to fix this, please share them here.
