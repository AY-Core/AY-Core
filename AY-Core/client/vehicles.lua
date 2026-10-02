-- Client side of /car and /dv. The server checks permission + rate limit, then tells us what to do.

local function notify(message)
    TriggerEvent('chat:addMessage', { args = { AY.Name, message } })
end

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

local function removeVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return end

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
end

-- /car [model]
RegisterNetEvent('ay-core:client:spawnVehicle', function(modelName, deleteCurrent)
    if type(modelName) ~= 'string' then return end

    local model = joaat(modelName)
    if not loadVehicleModel(model) then
        notify(('"%s" is not a valid vehicle model.'):format(modelName))
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
        notify('Failed to spawn the vehicle.')
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleOnGroundProperly(vehicle)
    SetPedIntoVehicle(ped, vehicle, -1)
    SetVehicleEngineOn(vehicle, true, true, false)
end)

-- /dv [radius]  - deletes the vehicle you are in, otherwise the closest one within `radius`.
RegisterNetEvent('ay-core:client:deleteVehicle', function(radius)
    if type(radius) ~= 'number' then return end

    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        vehicle = GetClosestVehicle(GetEntityCoords(ped), radius + 0.0, 0, 71)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        notify('No vehicle found nearby.')
        return
    end

    removeVehicle(vehicle)
end)