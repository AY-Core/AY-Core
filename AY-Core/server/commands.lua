-- AY.RegisterCommand itself lives in import.lua (shared with satellite resources).
function AY.Reply(src, message)
    if src == 0 then
        print(('[%s] %s'):format(AY.Name, message))
    else
        TriggerClientEvent('chat:addMessage', src, { args = { AY.Name, message } })
    end
end

-- /setgroup [id] [group]  - from the server console you can bootstrap your first admin.
AY.RegisterCommand('setgroup', 'superadmin', function(src, args)
    local target = tonumber(args[1])
    local group = args[2]
    local player = target and AY.GetPlayer(target)

    if not player then
        AY.Reply(src, 'Usage: setgroup [id] [group] (player must be online and loaded)')
        return
    end
    if not player.SetGroup(group) then
        AY.Reply(src, 'Invalid group.')
        return
    end

    local actor = src == 0 and 'console' or (GetPlayerName(src) or src)
    AY.Logger.Info('permissions', ('%s set the group of %s to "%s"'):format(actor, player.GetName(), group))
    AY.Reply(src, ('%s is now "%s".'):format(player.GetName(), group))
end)

-- /car [model]  - spawns a vehicle and puts you in the driver seat.
AY.RegisterCommand('car', ServerConfig.Vehicles.SpawnGroup, function(src, args)
    if src == 0 then
        AY.Reply(src, 'This command can only be used in-game.')
        return
    end
    if not AY.Security.CheckRate(src, 'cmd:car', { Window = 3000, Max = 3 }) then return end

    local model = args[1] and args[1]:lower()
    if not AY.Utils.IsNonEmptyString(model, 32) or not model:match('^[%w_]+$') then
        AY.Reply(src, 'Usage: /car [model]  (e.g. /car adder)')
        return
    end

    TriggerClientEvent('ay-core:client:spawnVehicle', src, model, ServerConfig.Vehicles.DeleteCurrentOnSpawn)
    AY.Logger.Info('vehicles', ('%s (id %s) spawned vehicle "%s"'):format(GetPlayerName(src) or 'unknown', src, model))
end)

-- /dv [radius]  - deletes the vehicle you are in, or the closest one within the radius.
AY.RegisterCommand('dv', ServerConfig.Vehicles.DeleteGroup, function(src, args)
    if src == 0 then
        AY.Reply(src, 'This command can only be used in-game.')
        return
    end
    if not AY.Security.CheckRate(src, 'cmd:dv', { Window = 3000, Max = 5 }) then return end

    local cfg = ServerConfig.Vehicles
    local radius = tonumber(args[1]) or cfg.DefaultDeleteRadius
    radius = math.max(1.0, math.min(radius, cfg.MaxDeleteRadius))

    TriggerClientEvent('ay-core:client:deleteVehicle', src, radius + 0.0)
    AY.Logger.Info('vehicles', ('%s (id %s) used /dv (radius %.1f)'):format(GetPlayerName(src) or 'unknown', src, radius))
end)

-- Shared by /revive and /kill: [id] is optional in-game (defaults to yourself), required from the console.
local function healthCommand(name, event, verb)
    return function(src, args)
        if src ~= 0 and not AY.Security.CheckRate(src, 'cmd:' .. name, { Window = 3000, Max = 5 }) then return end

        local target = args[1] and tonumber(args[1]) or src
        if target == 0 or not AY.GetPlayer(target) then
            AY.Reply(src, ('Usage: /%s [id]  (player must be online and loaded)'):format(name))
            return
        end

        TriggerClientEvent(event, target)

        local actor = src == 0 and 'console' or ('%s (id %s)'):format(GetPlayerName(src) or 'unknown', src)
        AY.Logger.Info('health', ('%s %s %s (id %s)'):format(actor, verb, GetPlayerName(target) or 'unknown', target))
        AY.Reply(src, ('%s %s.'):format(GetPlayerName(target) or target, verb))
    end
end

-- /revive [id]
AY.RegisterCommand('revive', ServerConfig.Health.ReviveGroup, healthCommand('revive', 'ay-core:client:revive', 'revived'))

-- /kill [id]
AY.RegisterCommand('kill', ServerConfig.Health.KillGroup, healthCommand('kill', 'ay-core:client:kill', 'killed'))