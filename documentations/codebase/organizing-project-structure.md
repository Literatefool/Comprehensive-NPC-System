# Organizing Project Structure for Roblox Games

When building Roblox games with SuperbulletAI using an Object-Oriented Programming (OOP) approach and the Knit framework, proper project organization is crucial for maintainability, security, and development efficiency.

## 1. Standard Project Structure

SuperbulletAI follows this organized folder structure for Roblox projects:

```
src/
├── ReplicatedStorage/
│   ├── ClientSource/
│   │   └── Client/          << All Client Systems stored here
│   └── SharedSource/
│       └── Datas/           << Shared Data/Settings for both client and server
└── ServerScriptService/
    └── ServerSource/
        └── Server/          << All Server Systems stored here
```

## 2. Modified Knit Framework: Get() and Set() Components

SuperbulletAI uses a **modified version of Knit** that introduces `Get().lua` and `Set().lua` components to solve IntelliSense limitations and enforce clean architecture.

### 2a. Why Get().lua and Set().lua Components?

The standard Knit framework has a critical flaw: **IntelliSense doesn't work properly** with many Language Server Protocols (LSPs). Our modified framework solves this by introducing:

- **`Get().lua`** - Handles read-only operations or data retrieval logic
- **`Set().lua`** - Handles write operations or data modifications

### 2b. Benefits of This Approach

1. **IntelliSense Support** - Full autocomplete and type checking across LSPs
2. **Clean Architecture** - Enforced separation between read and write operations
3. **Long-term Sustainability** - Clear boundaries make code easier to maintain
4. **Component Organization** - Break down large systems into manageable pieces

### 2c. Component Structure Example

```lua
-- PlayerDataService/Get().lua (Read Operations)
local PlayerDataGet = {}

function PlayerDataGet:GetPlayerLevel(player)
    return self._playerData[player.UserId].Level
end

function PlayerDataGet:GetPlayerCurrency(player)
    return self._playerData[player.UserId].Currency
end

return PlayerDataGet
```

```lua
-- PlayerDataService/Set().lua (Write Operations)
local PlayerDataSet = {}

function PlayerDataSet:AddExperience(player, amount)
    local data = self._playerData[player.UserId]
    data.Experience += amount
    self:_CheckLevelUp(player)
end

function PlayerDataSet:SpendCurrency(player, amount)
    local data = self._playerData[player.UserId]
    if data.Currency >= amount then
        data.Currency -= amount
        return true
    end
    return false
end

return PlayerDataSet
```

```lua
-- PlayerDataService/Others/DataValidator.lua (Additional Component)
local DataValidator = {}

function DataValidator:ValidatePlayerData(data)
    return data.Level >= 1 and data.Currency >= 0
end

function DataValidator:SanitizePlayerName(name)
    return string.match(name, "^[%w_]+$") and name or "Player"
end

return DataValidator
```

### 2d. Complete System Architecture

SuperbulletAI's modified Knit framework supports **three component types**:

1. **`Get().lua`** - Read-only operations
2. **`Set().lua`** - Write operations
3. **`Others/[ComponentScript]`** - Additional specialized components

```
PlayerDataService/
├── init.lua                    << Main service file
└── Components/
    ├── Get().lua               << Read operations
    ├── Set().lua               << Write operations
    └── Others/
        ├── DataValidator.lua   << Validation logic
        ├── DataMigration.lua   << Data migration utilities
        └── DataAnalytics.lua   << Analytics tracking
```

### 2e. Component Loading Pattern

SuperbulletAI uses an **automated component loading system** that eliminates manual require() calls:

```lua
-- init.lua (Main Service File)
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local PlayerDataService = Knit.CreateService {
    Name = "PlayerDataService",
    Client = {},
    Instance = script, -- CRITICAL: This enables automatic component loading
}

-- Components are automatically loaded and integrated!
-- No manual require() needed for Get().lua, Set().lua, or Others/

function PlayerDataService:KnitStart()
    print("PlayerDataService started!")
end

function PlayerDataService:KnitInit()
    self._playerData = {}
    print("PlayerDataService initialized!")
end

return PlayerDataService
```

**Key Points:**

- `Instance = script` enables automatic component loading
- Framework automatically loads all components from `Components/` folder
- All component methods are merged into the parent service
- No manual `require()` calls needed

## 3. Component Communication Rules

### 3a. Communication Restrictions

#### 3a.i. Others/ Components

**✅ CAN communicate with:**

- Parent system (service/controller)
- `Get().lua` component (via parent system's GetComponent)
- `Set().lua` component (via parent system's SetComponent)

**❌ CANNOT communicate with:**

- Other systems' components directly
- Other `Others/` components from different systems

#### 3a.ii. Set().lua Components

**✅ CAN communicate with:**

- Parent system
- Other systems (services/controllers)
- `Others/` components (in same system)

**❌ CANNOT communicate with:**

- `Get().lua` component directly (must use parent system)

#### 3a.iii. Get().lua Components

**✅ CAN communicate with:**

- Parent system
- Other systems (services/controllers)
- `Others/` components (in same system)

**❌ CANNOT communicate with:**

- `Set().lua` component directly (must use parent system)

### 3b. Forbidden Communication: Get().lua ↔ Set().lua

**❌ NEVER DO THIS:**

```lua
-- Get().lua
local PlayerDataGet = {}
local Set = require(script.Parent.Set) -- FORBIDDEN!

function PlayerDataGet:GetAndModifyLevel(player)
    Set:SetPlayerLevel(player, 100) -- This breaks architecture!
    return self:GetPlayerLevel(player)
end

return PlayerDataGet
```

**✅ DO THIS INSTEAD:**

```lua
-- init.lua (Parent System)
function PlayerDataService:GetAndModifyLevel(player)
    self:SetPlayerLevel(player, 100) -- Coordinate through parent
    return self:GetPlayerLevel(player)
end
```

### 3c. Communication Flow Diagram

```
┌─────────────────────────────────────────────────┐
│            Parent System (init.lua)             │
│  (Coordinates all component communication)      │
└─────────────────────────────────────────────────┘
         ↓                ↓                ↓
    ┌────────┐      ┌─────────┐      ┌─────────┐
    │Get().lua│      │Set().lua│      │Others/  │
    │         │      │         │      │ Scripts │
    └────────┘      └─────────┘      └─────────┘
         ↓                ↓                ↓
    ┌───────────────────────────────────────────┐
    │    Other Systems (Services/Controllers)    │
    └───────────────────────────────────────────┘
```

### 3d. Parent System Communication

The parent system (`init.lua`) acts as the **coordinator** for all component interactions:

```lua
-- init.lua
function PlayerDataService:ProcessLevelUp(player)
    -- Coordinate between Get and Set through parent
    local currentLevel = self:GetPlayerLevel(player) -- Calls Get().lua
    self:SetPlayerLevel(player, currentLevel + 1)    -- Calls Set().lua

    -- Can also call Others/ components
    self:ValidatePlayerData(player) -- Calls Others/DataValidator.lua
end
```

## 4. When to Use Get/Set Components

### 4a. USE Get/Set/Others When:

1. **System grows beyond 300 lines** - Break it down for maintainability
2. **Clear separation needed** - Different team members working on reads vs writes
3. **Complex business logic** - Multiple specialized operations warrant their own files
4. **IntelliSense is struggling** - Framework's automated loading ensures proper autocomplete

### 4b. DON'T Use Get/Set When:

1. **System is small (< 100 lines)** - Unnecessary overhead
2. **Simple CRUD operations** - Basic create/read/update/delete doesn't need separation
3. **Tightly coupled logic** - Operations that always happen together shouldn't be split
4. **Prototype/MVP phase** - Start simple, refactor later when complexity grows

## 5. System Grouping Best Practices

### 5a. Folder Organization Guidelines

**Group related systems into folders when you have 3+ related services:**

```
Server/
├── Combat/
│   ├── DamageService/
│   ├── WeaponService/
│   └── HealthService/
├── Economy/
│   ├── CurrencyService/
│   ├── ShopService/
│   └── TradingService/
└── Social/
    ├── FriendsService/
    ├── ChatService/
    └── PartyService/
```

**Don't over-organize small projects:**

```
Server/
├── PlayerDataService/
├── InventoryService/
└── QuestService/
```

## 6. The 300-Line Rule

### 6a. When to Follow the Rule:

- **Large systems** - Combat, inventory, questing systems that naturally grow
- **Team projects** - Multiple developers need clear boundaries
- **Long-term maintenance** - Project will be maintained for months/years

### 6b. When to Ignore the Rule:

- **Simple utilities** - Math helpers, string formatters, etc.
- **Prototype phase** - Get it working first, refactor later
- **Tightly coupled logic** - Breaking it up would make it harder to understand
- **Small solo projects** - You're the only one working on it

## 7. Practical Prompting Guidelines

### 7a. Adding New Features/Components

**Use the "ONLY ONE" principle:**

```
❌ BAD PROMPT:
"Create a player data service with saving, loading, validation,
 and also add an inventory system with equipping items"

✅ GOOD PROMPT:
"Create ONLY a player data service that handles saving and
 loading player stats using ProfileService"
```

**Then in a separate prompt:**

```
"Now create ONLY an inventory service that manages player items
 and equipping/unequipping"
```

### 7b. Refactoring Best Practices

**When refactoring existing code:**

```
✅ GOOD APPROACH:
"Refactor the CombatService by splitting the damage calculation
 logic into a separate Others/DamageCalculator.lua component"

✅ ALSO GOOD:
"Break down the InventoryService into Get().lua for reading items
 and Set().lua for modifying inventory"
```

### 7c. Safe Refactoring Process

1. **Read existing code first** - Understand what you're working with
2. **Make a plan** - Identify what needs to be split
3. **Refactor incrementally** - One component at a time
4. **Test after each change** - Ensure functionality remains intact

### 7d. Feature Addition Examples

**❌ AVOID - Too broad:**

```
"Build a complete combat system with weapons, skills, and player stats"
```

**✅ PREFER - Specific and focused:**

```
"Create ONLY a weapon service that handles weapon equipping and basic attack functionality"
```

**Then follow up with:**

```
"Now create ONLY a skill system for player abilities"
```

**Then:**

```
"Create ONLY a combat stats service for player health and damage"
```

### 7e. Experimentation and Growth

**These are solid rules of thumb, but don't stop here!**

Once you understand these foundational principles:

- **Experiment** with your own prompting techniques
- **Test** different approaches and see what works best for your specific use cases
- **Iterate** and refine your prompts based on results
- **Push boundaries** while keeping the core "ONLY ONE" principle

**The goal:** Eventually you'll surpass the knowledge in this guide and become a **monster at making Roblox games** with your own advanced prompting mastery.

This guide gives you the foundation - your experimentation will build the expertise! 🚀

## 8. Understanding the Three Categories

### 8a. Frontend-Only (Client)

**Location:** `src/ReplicatedStorage/ClientSource/Client`

These are systems that only run on the player's device and handle user interface, input, and visual effects.

**Examples:**

- UI Controllers (inventory display, shop interface, settings menu)
- Input handlers (mouse clicks, keyboard shortcuts)
- Visual effects (particles, animations, camera effects)
- Sound effects and music players
- Local data caching for UI responsiveness

**When to explicitly prompt for client-only:**

```
"Create a client-only inventory UI system that displays player items"
"Build a frontend camera controller for third-person view"
"Make a client-side particle effect system for spell casting"
```

### 8b. Backend-Only (Server)

**Location:** `src/ServerScriptService/ServerSource/Server`

These are systems that only run on the server and handle game logic, data persistence, and security-critical operations.

**Examples:**

- Player data management (saving/loading stats, inventory)
- Game logic enforcement (damage calculation, win conditions)
- Anti-cheat systems and validation
- Economy systems (currency transactions, shop purchases)
- Matchmaking and server events

**When to explicitly prompt for server-only:**

```
"Create a server-only player data service that saves stats to DataStore"
"Build a backend damage calculation system with anti-cheat validation"
"Make a server-side economy service for handling purchases"
```

### 8c. Shared (Both Frontend and Backend)

**Location:** `src/ReplicatedStorage/SharedSource/Datas`

These are configurations, constants, and utilities that both client and server need access to.

**Examples:**

- Game configuration (weapon stats, level data, shop items)
- Shared utilities (math functions, data structures)
- Constants and enums (item types, game states)
- Data schemas and interfaces
- Shared validation functions

## 9. Prompting Best Practices

### 9a. For Client-Only Features

```
"Create a CLIENT-ONLY UI system for displaying player inventory with smooth animations"
```

### 9b. For Server-Only Features

```
"Create a SERVER-ONLY player data service that handles saving and loading player stats with DataStore2"
```

### 9c. For Shared Components

```
"Create shared configuration data for weapon stats that both client and server can access"
```

### 9d. Security-Conscious Prompting

```
"Create a server-side combat system where clients can only request attacks, but the server calculates all damage and validates hit detection"
```

## 10. Example System Breakdown

### 10a. Player Inventory System

**Client-Side (`ClientSource/Client`):**

- `InventoryController` - Displays UI, handles clicks
- `InventoryAnimations` - Smooth opening/closing effects

**Server-Side (`ServerSource/Server`):**

- `InventoryService` - Manages actual inventory data
- `InventoryDataStore` - Saves/loads inventory from DataStore

**Shared (`SharedSource/Datas`):**

- `ItemConfigurations` - Item stats, descriptions, icons
- `InventoryTypes` - TypeScript/Luau type definitions

## 11. Common Mistakes to Avoid

1. **Putting sensitive logic on client** - Always keep important calculations server-side
2. **Trusting client remote event parameters** - Validate everything on server
3. **Not using shared configurations** - Leads to duplicate code and inconsistencies
4. **Mixing client and server code** - Keep them separated for clarity and security

## 12. Summary

### 12a. Project Structure

- **Client:** UI, effects, input handling (`ClientSource/Client`)
- **Server:** Game logic, data, security (`ServerSource/Server`)
- **Shared:** Configurations and constants (`SharedSource/Datas`)

### 12b. Modified Knit Components

- **`Get().lua`:** Read-only operations (can be called by other systems and Others/)
- **`Set().lua`:** Write operations (can be called by other systems and Others/)
- **`Others/`:** Specialized components (cannot be called by other systems directly)

### 12c. Communication Rules

- **Get().lua ↔ Set().lua:** FORBIDDEN - use parent system for coordination
- **Others/ → External:** FORBIDDEN - use GetComponent/SetComponent or parent system
- **Parent System:** Acts as coordinator between all components
- **Component Loading:** Automated with `Instance = script` - framework handles all component initialization

### 12d. Security & Architecture

- **Security:** Never trust the client, always validate on server
- **Remote Events:** Use action-based events, not value-based ones
- **300-Line Rule:** Break down large files, but use judgment
- **IntelliSense:** Modified Knit framework ensures full LSP support

Remember: If an exploiter can see it or interact with it on their screen, they can potentially modify it. Design your architecture accordingly!

## 13. Security Best Practices: Preventing Exploiters

### 13a. Critical Security Rule

**What exploiters CAN manipulate:** Anything that runs on the frontend/client/player's device can be modified by exploiters no matter what you do.

### 13b. Remote Events Security with Knit

When using Knit's remote events (like `PointsService.AddPoints:Fire()`), follow these security principles:

#### 13b.i. NEVER DO THIS - Trusting Client Data

```lua
-- BAD: Client tells server how many points to add
-- Exploiter can easily change the amount
PointsService.AddPoints:Fire(player, 99999) -- Exploitable!
```

#### 13b.ii. ALWAYS DO THIS - Server Validates Everything

```lua
-- GOOD: Client requests action, server determines the reward
PointsService.CompleteQuest:Fire(player, questId) -- Server calculates points
```

### 13c. Security Guidelines for Remote Events

1. **Never trust numerical values from client**

   - Don't let clients specify how much currency/XP/items they get
   - Server should calculate rewards based on validated actions

2. **Use action-based remote events**

```lua
-- Good examples:
CombatService.AttackTarget:Fire(targetId)
QuestService.TurnInQuest:Fire(questId)
ShopService.PurchaseItem:Fire(itemId)
```

3. **Always validate on server**

```lua
-- Server-side validation example
function ShopService:PurchaseItem(player, itemId)
    local item = GameData.Items[itemId]
    if not item then return false end

    if player.Currency.Value < item.Price then
        return false -- Not enough currency
    end

    -- Proceed with purchase...
end
```
