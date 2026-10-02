# AY-Core

Core scripts of **AY-Core**, a custom framework for FiveM focused on a structured, scalable and secure foundation.
Feature resources (AY-Jobs, AY-Skin, ...) are separate resources that run **on top of** AY-Core.

> Status: under active development (v0.2.0).

## Requirements

- FiveM server (Lua 5.4)
- [oxmysql](https://github.com/overextended/oxmysql) + MySQL/MariaDB

## Installation

1. Put this folder in `resources/` and keep the name **`AY-Core`**.
2. Add to `server.cfg` (`oxmysql` first, AY-Core before every AY-* resource):

```cfg
ensure oxmysql
ensure AY-Core
ensure AY-Jobs
# optional: Discord log webhook (kept out of git)
set ay_log_webhook "https://discord.com/api/webhooks/..."
```

3. Tables are created and migrated automatically.
4. First admin, from the **server console**: `setgroup [id] superadmin`
5. Spawn: AY-Core spawns players and closes the loading screen (`Config.Spawn` in `config/shared.lua`). Set `Config.Spawn.Enabled = false` if you use your own spawn system - then YOUR system must call `ShutdownLoadingScreen()` and `ShutdownLoadingScreenNui()`.

## Structure

```
AY-Core/
├─ fxmanifest.lua
├─ import.lua          # what satellite resources load: shared_script '@AY-Core/import.lua'
├─ config/shared.lua   # server + client (no secrets!)
├─ config/server.lua   # server only
├─ shared/utils.lua
├─ server/
│  ├─ logger.lua       # console / database / Discord
│  ├─ database.lua     # oxmysql wrapper, schema, migrations
│  ├─ security.lua     # rate limiting
│  ├─ hooks.lua        # hook system
│  ├─ modules.lua      # registry of satellite resources
│  ├─ player.lua       # player loading / saving / objects
│  ├─ permissions.lua
│  ├─ commands.lua
│  └─ main.lua
├─ client/main.lua, client/spawn.lua
└─ sql/install.sql
```

## Writing a satellite resource (AY-Jobs, AY-Skin, ...)

`fxmanifest.lua`:

```lua
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

dependency 'AY-Core'

shared_script '@AY-Core/import.lua'   -- gives you the global `AY`
server_script '@oxmysql/lib/MySQL.lua' -- use oxmysql directly for your own queries
server_script 'server/main.lua'
client_script 'client/main.lua'
```

`server/main.lua`:

```lua
-- Put registrations in AY.OnReady: it runs when AY-Core is ready AND again after every AY-Core restart.
AY.OnReady(function()
    AY.RegisterModule({ version = '0.1.0', dependencies = {} })

    AY.RegisterMigrations({
        { id = '001_init', sql = [[CREATE TABLE IF NOT EXISTS ay_jobs (...)]] },
    }, function(ok, err) end)

    -- Callbacks run in YOUR resource, so Wait / MySQL.await inside them are fine.
    AY.RegisterCallback('AY-Jobs:getJob', function(src)
        return AY.GetPlayer(src).GetData('AY-Jobs', 'job')
    end)

    AY.RegisterHook('beforePlayerLoad', function(ctx) end)
end)

-- Normal event handlers are registered once, outside OnReady.
AddEventHandler('ay-core:server:playerLoaded', function(src) end)

AY.RegisterServerEvent('AY-Jobs:setDuty', function(src, onDuty)
    -- src is trusted, rate limited, player must be loaded, wrapped in pcall
end, { Permission = 'user', RateLimit = { Window = 1000, Max = 5 } })

AY.RegisterCommand('setjob', 'admin', function(src, args) end)
```

Client: `local job = AY.TriggerCallback('AY-Jobs:getJob')` and `AY.RegisterClientCallback('name', function(...) return ... end)`.

### Rules that keep it reliable

- **Use your resource name as the namespace** for player data: `player.SetData('AY-Jobs', 'job', 'police')`, `player.GetData('AY-Jobs', 'job')`. Core metadata (`SetMetadata`) is for AY-Core only.
- **Hook handlers must be synchronous** (no `Wait`, no `MySQL.await`): they are called from inside AY-Core. A handler may return `false, 'reason'` to cancel, or a table to merge into the context.
- **Use functions, not fields** of `AY` from other resources (`AY.IsPlayerLoaded(src)`, `AY.GetPlayerData()`): plain fields are copied once and can be stale.
- `player.Save()` from another resource is fire-and-forget. For your own tables use oxmysql directly.
- Everything you register (module, hooks) is removed automatically when your resource stops.

### Built-in hooks

| Hook | Context | Notes |
|---|---|---|
| `beforePlayerLoad` | `{ source, license, name }` | return `false, 'reason'` to kick |
| `playerSaving` | `{ source, license }` | call `player.SetData(...)` to persist your data |

### Events

| Event | Side | Args |
|---|---|---|
| `ay-core:server:ready` | server | - (database ready, Core usable) |
| `ay-core:server:playerLoaded` | server | `src` |
| `ay-core:server:playerDropped` | server | `src, reason` |
| `ay-core:server:groupUpdated` | server | `src, group` |
| `ay-core:server:moduleRegistered` / `moduleUnregistered` | server | `name` |
| `ay-core:client:ready` | client | - |
| `ay-core:client:playerLoaded` | client | `{ source, id, name, group }` |

## API (server)

```lua
local player = AY.GetPlayer(src)
player.GetName(); player.GetLicense(); player.GetGroup(); player.GetIdentifier('discord')
player.SetGroup('admin'); player.Kick('Reason'); player.Emit('event', ...)

AY.HasPermission(src, 'admin')
AY.GetPlayers(); AY.GetPlayerByLicense(license)
AY.Modules.IsLoaded('AY-Jobs'); AY.Modules.List()
AY.Logger.Info('category', 'message', { extra = 'data' })
local value = AY.TriggerClientCallback(src, 'name', ...)
```

## Security notes

- Never trust client data; use `src` from the secure wrappers and validate arguments.
- Use SQL placeholders (`?`) only.
- Secrets belong in `config/server.lua` or convars, never in `config/shared.lua`.
- IP addresses are not stored.
