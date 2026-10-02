if GetCurrentResourceName() ~= AY.Name then
    print(('^1[%s] This resource must be named "%s" - other resources use that name to access its exports.^7'):format(AY.Name, AY.Name))
end

-- Other resources: add  shared_script '@AY-Core/import.lua'  and use the global `AY`.
-- (Under the hood that calls exports['AY-Core']:GetCore().)
exports('GetCore', function() return AY end)

AY.Modules.Register(AY.Name, { version = AY.Version })

AY.RegisterCallback('ay-core:getPlayerData', function(src)
    local player = AY.GetPlayer(src)
    return player and player.GetPublicData() or nil
end)

CreateThread(function()
    Wait(500)
    print(('^2[%s] v%s started^7'):format(AY.Name, AY.Version))
end)