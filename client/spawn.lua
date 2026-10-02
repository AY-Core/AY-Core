-- Minimal spawn handling. The loading screen only closes once something calls
-- ShutdownLoadingScreen() / ShutdownLoadingScreenNui(). This file does that after the player is loaded.
-- Set Config.Spawn.Enabled = false if you use your own spawn / character system
-- (then YOUR system must close the loading screen).

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end

    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end

    return HasModelLoaded(hash) and hash or nil
end

function AY.SpawnPlayer(spawn)
    spawn = spawn or Config.Spawn
    local c = spawn.Coords

    DoScreenFadeOut(0)

    local hash = loadModel(spawn.Model)
    if hash then
        SetPlayerModel(PlayerId(), hash)
        SetModelAsNoLongerNeeded(hash)
        SetPedDefaultComponentVariation(PlayerPedId())
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, c.w, true, true, false)

    ped = PlayerPedId()
    SetEntityHeading(ped, c.w)
    ClearPedTasksImmediately(ped)

    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(c.x, c.y, c.z)
        Wait(0)
    end

    FreezeEntityPosition(ped, false)

    -- Close the loading screen (works for custom NUI loading screens too).
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(500)

    TriggerEvent('ay-core:client:spawned')
end

AddEventHandler('ay-core:client:playerLoaded', function()
    if not Config.Spawn.Enabled then return end
    CreateThread(function() AY.SpawnPlayer() end)
end)