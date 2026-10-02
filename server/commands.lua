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