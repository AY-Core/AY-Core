-- Client side of /car and /dv. The server checks permission + rate limit, then tells us what to do.
-- No chat messages here on purpose; turn on Config.Debug to see what happened in the F8 console.

local function loadVehicleModel(model)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then return false end

    RequestModel(model)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

-- Returns true if the vehicle is gone afterwards.
local function removeVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return true end

    local ped = PlayerPedId()

    -- Get out first (flag 16 = instantly): deleting a vehicle you are still sitting in can fail silently.
    if GetVehiclePedIsIn(ped, false) == vehicle then
        TaskLeaveVehicle(ped, vehicle, 16)
        local deadline = GetGameTimer() + 1500
        while GetVehiclePedIsIn(ped, false) == vehicle and GetGameTimer() < deadline do
            Wait(0)
        end
    end

    if NetworkGetEntityIsNetworked(vehicle) and not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        local deadline = GetGameTimer() + 2000
        while not NetworkHasControlOfEntity(vehicle) and GetGameTimer() < deadline do
            Wait(0)
        end
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end

    local gone = not DoesEntityExist(vehicle)
    if not gone then AY.Debug('Could not delete vehicle', vehicle) end
    return gone
end

-- /car [model]
RegisterNetEvent('ay-core:client:spawnVehicle', function(modelName, deleteCurrent)
    if type(modelName) ~= 'string' then return end

    local model = joaat(modelName)
    if not loadVehicleModel(model) then
        AY.Debug(('"%s" is not a valid vehicle model'):format(modelName))
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    if deleteCurrent then
        local current = GetVehiclePedIsIn(ped, false)
        if current ~= 0 then removeVehicle(current) end
    end

    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    SetModelAsNoLongerNeeded(model)

    if vehicle == 0 then
        AY.Debug('Failed to spawn vehicle', modelName)
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(PlayerPedId(), vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
end)

-- /dv [radius]  - deletes the vehicle you are in, otherwise the closest one within `radius`.
RegisterNetEvent('ay-core:client:deleteVehicle', function(radius)
    radius = tonumber(radius) or 5.0

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        vehicle = GetClosestVehicle(GetEntityCoords(ped), radius + 0.0, 0, 71)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        AY.Debug('No vehicle found nearby')
        return
    end

    removeVehicle(vehicle)
end)