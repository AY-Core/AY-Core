# AY-Core

Core scripts of **AY-Core**, a custom framework for FiveM focused on a structured, scalable and secure foundation.

> Status: under active development (v0.1.0).

## Requirements

- FiveM server (Lua 5.4)
- [oxmysql](https://github.com/overextended/oxmysql) + MySQL/MariaDB

## Installation

1. Put this folder in `resources/` and keep the name **`AY-Core`**.
2. Make sure `oxmysql` starts first, then add to `server.cfg`:

```cfg
ensure oxmysql
ensure AY-Core
# optional: Discord log webhook (kept out of git)
set ay_log_webhook "https://discord.com/api/webhooks/..."
```

3. Tables are created automatically (or run `sql/install.sql` manually).
4. Give yourself your first admin from the **server console**: `setgroup [id] superadmin`

## Structure

```
AY-Core/
├─ fxmanifest.lua
├─ config/
│  ├─ shared.lua      # server + client (no secrets!)
│  └─ server.lua      # server only
├─ shared/utils.lua   # AY.Utils, AY.Debug
├─ server/
│  ├─ logger.lua      # console / database / Discord logging
│  ├─ database.lua    # oxmysql wrapper + schema
│  ├─ security.lua    # rate limiting + AY.RegisterServerEvent
│  ├─ callbacks.lua   # client <-> server callbacks
│  ├─ player.lua      # player loading, saving, objects
│  ├─ permissions.lua # group based permissions
│  ├─ commands.lua    # AY.RegisterCommand + /setgroup
│  └─ main.lua
├─ client/
│  ├─ callbacks.lua
│  └─ main.lua
└─ sql/install.sql
```

## Using AY-Core from another resource

```lua
local AY = exports['AY-Core']:GetCore()
```

### Secure server events

```lua
AY.RegisterServerEvent('myresource:doSomething', function(src, value)
    -- src is trusted (taken from `source`), rate limited, wrapped in pcall
    local player = AY.GetPlayer(src)
end, { Permission = 'moderator', RateLimit = { Window = 1000, Max = 5 } })
```

### Callbacks

```lua
-- server
AY.RegisterCallback('myresource:getThing', function(src, id) return { id = id } end)
local coords = AY.TriggerClientCallback(src, 'myresource:getCoords')

-- client
local thing = AY.TriggerCallback('myresource:getThing', 5)
AY.RegisterClientCallback('myresource:getCoords', function() return GetEntityCoords(PlayerPedId()) end)
```

### Players & permissions (server)

```lua
local player = AY.GetPlayer(src)
player.GetName(); player.GetLicense(); player.GetGroup()
player.SetMetadata('job', 'police'); player.GetMetadata('job')
player.SetGroup('admin'); player.Kick('Reason'); player.Emit('event', ...)

AY.HasPermission(src, 'admin')
AY.RegisterCommand('mycmd', 'admin', function(src, args) end)
```

### Events

| Event | Side | Args |
|---|---|---|
| `ay-core:server:ready` | server | - (database ready) |
| `ay-core:server:playerLoaded` | server | `src` |
| `ay-core:server:playerDropped` | server | `src, reason` |
| `ay-core:server:groupUpdated` | server | `src, group` |
| `ay-core:client:playerLoaded` | client | `{ source, id, name, group }` |

### Database & logging

```lua
local rows = AY.DB.Query('SELECT * FROM ay_players WHERE group_name = ?', { 'admin' })
AY.Logger.Info('myresource', 'Something happened', { foo = 'bar' })
```

## Security notes

- Never trust client data; always use `source` (`src`) and validate arguments.
- Use SQL placeholders (`?`) only.
- Secrets belong in `config/server.lua` or convars, never in `config/shared.lua`.
- IP addresses are not stored.

## License

Defined by the repository owner.
