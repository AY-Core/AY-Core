local function reply(src, message)
    if src == 0 then
        print(('[%s] %s'):format(AY.Name, message))
    else
        TriggerClientEvent('chat:addMessage', src, { args = { AY.Name, message } })
    end
end
AY.Reply = reply

-- Permission-checked command. Handler signature: function(src, args, rawCommand)
function AY.RegisterCommand(name, requiredGroup, handler)
    RegisterCommand(name, function(src, args, raw)
        if requiredGroup and not AY.HasPermission(src, requiredGroup) then
            reply(src, 'You do not have permission to use this command.')
            return
        end
        local ok, err = pcall(handler, src, args, raw)
        if not ok then
            AY.Logger.Error('commands', ('Error in command "%s": %s'):format(name, err))
        end
    end, false)
end

-- /setgroup [id] [group]  - from the server console you can bootstrap your first admin.
AY.RegisterCommand('setgroup', 'superadmin', function(src, args)
    local target = tonumber(args[1])
    local group = args[2]
    local player = target and AY.GetPlayer(target)

    if not player then
        reply(src, 'Usage: setgroup [id] [group] (player must be online and loaded)')
        return
    end
    if not player.SetGroup(group) then
        reply(src, 'Invalid group.')
        return
    end

    local actor = src == 0 and 'console' or (GetPlayerName(src) or src)
    AY.Logger.Info('permissions', ('%s set the group of %s to "%s"'):format(actor, player.GetName(), group))
    reply(src, ('%s is now "%s".'):format(player.GetName(), group))
end)
