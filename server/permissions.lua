function AY.GetGroupLevel(group)
    return ServerConfig.Groups[group] or 0
end

-- True if the player's group level is >= the required group's level. The console (source 0) always passes.
function AY.HasPermission(src, requiredGroup)
    if src == 0 then return true end
    local player = AY.GetPlayer(src)
    if not player then return false end
    return AY.GetGroupLevel(player.GetGroup()) >= AY.GetGroupLevel(requiredGroup)
end
