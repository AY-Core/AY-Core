-- Client side of /revive and /kill. The server checks permission + rate limit, then tells the target client.

RegisterNetEvent('ay-core:client:revive', function()
    local ped = PlayerPedId()

    if IsEntityDead(ped) then
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId() -- the ped handle can change after a resurrect
    end

    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
end)

RegisterNetEvent('ay-core:client:kill', function()
    SetEntityHealth(PlayerPedId(), 0)
end)