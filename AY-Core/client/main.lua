AY.PlayerData = {}
AY.IsLoaded = false

local ready = false

-- Use these functions from other resources: plain fields (AY.PlayerData, AY.IsLoaded) are copied
-- when a resource first gets a reference to the core, so they can be stale there.
function AY.GetPlayerData() return AY.PlayerData end
function AY.IsPlayerLoaded() return AY.IsLoaded end
function AY.IsReady() return ready end

exports('GetCore', function() return AY end)

-- Other client resources can listen with AddEventHandler('ay-core:client:playerLoaded', function(data) end)
RegisterNetEvent('ay-core:client:playerLoaded', function(data)
    AY.PlayerData = data
    AY.IsLoaded = true
    AY.Debug('Player loaded:', data.name, data.group)
end)

RegisterNetEvent('ay-core:client:groupUpdated', function(group)
    AY.PlayerData.group = group
end)

-- Tell the server we're ready once the network session has started.
CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(100) end
    TriggerServerEvent('ay-core:server:playerReady')
end)

ready = true
TriggerEvent('ay-core:client:ready')