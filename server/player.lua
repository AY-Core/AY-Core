local players = {}  -- [source] = player object
local loading = {}  -- [source] = true while loading from DB

-- Collects identifiers. IP addresses are intentionally NOT stored (privacy / GDPR).
local function collectIdentifiers(src)
    local ids = {}
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        local kind, value = id:match('^(%w+):(.+)$')
        if kind and kind ~= 'ip' then ids[kind] = value end
    end
    return ids
end

-- Player objects use closures (not `self`), so they stay usable when passed through exports.
local function createPlayer(src, row)
    local self = {}
    local data = {
        id = row.id,
        license = row.license,
        name = row.name,
        group = row.group_name,
        identifiers = json.decode(row.identifiers or '{}') or {},
        metadata = AY.Utils.Merge(ServerConfig.Players.DefaultMetadata, json.decode(row.metadata or '{}') or {}),
    }

    function self.GetSource() return src end
    function self.GetId() return data.id end
    function self.GetLicense() return data.license end
    function self.GetName() return data.name end
    function self.GetGroup() return data.group end
    function self.GetIdentifier(kind) return data.identifiers[kind] end

    function self.GetMetadata(key)
        if key == nil then return AY.Utils.DeepCopy(data.metadata) end
        return AY.Utils.DeepCopy(data.metadata[key])
    end

    function self.SetMetadata(key, value)
        data.metadata[key] = value
    end

    function self.SetGroup(group)
        if ServerConfig.Groups[group] == nil then return false end
        data.group = group
        TriggerClientEvent('ay-core:client:groupUpdated', src, group)
        TriggerEvent('ay-core:server:groupUpdated', src, group)
        self.Save()
        return true
    end

    function self.GetPublicData()
        return { source = src, id = data.id, name = data.name, group = data.group }
    end

    function self.Save()
        local ok, err = pcall(AY.DB.Update,
            'UPDATE ay_players SET name = ?, group_name = ?, metadata = ?, last_seen = CURRENT_TIMESTAMP WHERE id = ?',
            { data.name, data.group, json.encode(data.metadata), data.id }
        )
        if not ok then
            AY.Logger.Error('players', ('Failed to save player %s: %s'):format(data.license, err))
        end
        return ok
    end

    function self.Kick(reason) DropPlayer(src, reason or 'Kicked from the server.') end
    function self.Emit(event, ...) TriggerClientEvent(event, src, ...) end

    return self
end

local function loadPlayer(src)
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then
        DropPlayer(src, 'No valid Rockstar license found.')
        return
    end

    local name = GetPlayerName(src) or 'Unknown'
    local identifiers = json.encode(collectIdentifiers(src))
    local defaultGroup = ServerConfig.Players.DefaultGroup

    local row = AY.DB.Single('SELECT * FROM ay_players WHERE license = ?', { license })
    if row then
        AY.DB.Update('UPDATE ay_players SET name = ?, identifiers = ? WHERE id = ?', { name, identifiers, row.id })
        row.name, row.identifiers = name, identifiers
    else
        local id = AY.DB.Insert(
            'INSERT INTO ay_players (license, name, group_name, identifiers, metadata) VALUES (?, ?, ?, ?, ?)',
            { license, name, defaultGroup, identifiers, '{}' }
        )
        row = { id = id, license = license, name = name, group_name = defaultGroup, identifiers = identifiers, metadata = '{}' }
    end

    if not GetPlayerName(src) then return end -- player left while we were loading

    local player = createPlayer(src, row)
    players[src] = player

    AY.Logger.Info('players', ('Loaded %s (id %s, db %s)'):format(name, src, row.id))
    TriggerEvent('ay-core:server:playerLoaded', src)
    TriggerClientEvent('ay-core:client:playerLoaded', src, player.GetPublicData())
end

function AY.GetPlayer(src)
    return players[tonumber(src)]
end

function AY.GetPlayers()
    local list = {}
    for _, player in pairs(players) do list[#list + 1] = player end
    return list
end

function AY.GetPlayerByLicense(license)
    for _, player in pairs(players) do
        if player.GetLicense() == license then return player end
    end
end

-- Reject connections without a license, and duplicate sessions of the same license.
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then
        deferrals.done('A valid Rockstar license is required to join this server.')
        return
    end
    if AY.GetPlayerByLicense(license) then
        deferrals.done('This account is already connected to the server.')
        return
    end
    deferrals.done()
end)

-- The client fires this once its session has started (see client/main.lua).
AY.RegisterServerEvent('ay-core:server:playerReady', function(src)
    if players[src] or loading[src] then return end
    loading[src] = true

    while not AY.DB.ready do Wait(100) end

    local ok, err = pcall(loadPlayer, src)
    loading[src] = nil

    if not ok then
        AY.Logger.Error('players', ('Failed to load player %s: %s'):format(src, err))
        DropPlayer(src, 'Failed to load your player data. Please reconnect.')
    end
end, { RequirePlayer = false, RateLimit = { Window = 10000, Max = 3 } })

AddEventHandler('playerDropped', function(reason)
    local src = source
    loading[src] = nil

    local player = players[src]
    if not player then return end

    TriggerEvent('ay-core:server:playerDropped', src, reason) -- player still readable here
    player.Save()
    players[src] = nil
end)

CreateThread(function()
    local minutes = ServerConfig.Players.AutosaveMinutes
    if not minutes or minutes <= 0 then return end
    while true do
        Wait(minutes * 60000)
        for _, player in pairs(players) do player.Save() end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, player in pairs(players) do player.Save() end
end)
