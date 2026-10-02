local players = {}  -- [source] = player object
local loading = {}  -- [source] = true while loading from DB

-- Join / leave messages in the server console (toggle: ServerConfig.Logging.LogConnections).
local function logConnection(message)
    if ServerConfig.Logging.LogConnections == false then return end
    AY.Logger.Info('connection', message)
end

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
-- Note: from other resources, Save() is fire-and-forget (it awaits the database inside AY-Core).
local function createPlayer(src, row)
    local self = {}
    local data = {
        id = row.id,
        license = row.license,
        name = row.name,
        group = row.group_name,
        identifiers = json.decode(row.identifiers or '{}') or {},
        metadata = AY.Utils.Merge(ServerConfig.Players.DefaultMetadata, json.decode(row.metadata or '{}') or {}),
        store = json.decode(row.data or '{}') or {}, -- namespaced data of satellite resources
    }

    function self.GetSource() return src end
    function self.GetId() return data.id end
    function self.GetLicense() return data.license end
    function self.GetName() return data.name end
    function self.GetGroup() return data.group end
    function self.GetIdentifier(kind) return data.identifiers[kind] end

    -- Core-owned metadata. Satellite resources should use GetData / SetData instead.
    function self.GetMetadata(key)
        if key == nil then return AY.Utils.DeepCopy(data.metadata) end
        return AY.Utils.DeepCopy(data.metadata[key])
    end

    function self.SetMetadata(key, value)
        data.metadata[key] = value
    end

    -- Namespaced data: use your resource name as the namespace, e.g. player.SetData('AY-Jobs', 'job', 'police')
    function self.GetData(namespace, key)
        local ns = data.store[namespace]
        if key == nil then return AY.Utils.DeepCopy(ns) end
        if ns == nil then return nil end
        return AY.Utils.DeepCopy(ns[key])
    end

    function self.SetData(namespace, key, value)
        if type(namespace) ~= 'string' or type(key) ~= 'string' then return false end
        if type(data.store[namespace]) ~= 'table' then data.store[namespace] = {} end
        data.store[namespace][key] = value
        return true
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
        pcall(AY.Hooks.Run, 'playerSaving', { source = src, license = data.license })

        local ok, err = pcall(AY.DB.Update,
            'UPDATE ay_players SET name = ?, group_name = ?, metadata = ?, data = ?, last_seen = CURRENT_TIMESTAMP WHERE id = ?',
            { data.name, data.group, json.encode(data.metadata), json.encode(data.store), data.id }
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

    local allowedToLoad, reason = AY.Hooks.Run('beforePlayerLoad', { source = src, license = license, name = name })
    if not allowedToLoad then
        DropPlayer(src, tostring(reason or 'Connection refused.'))
        return
    end

    local identifiers = json.encode(collectIdentifiers(src))
    local defaultGroup = ServerConfig.Players.DefaultGroup

    local row = AY.DB.Single('SELECT * FROM ay_players WHERE license = ?', { license })
    if row then
        AY.DB.Update('UPDATE ay_players SET name = ?, identifiers = ? WHERE id = ?', { name, identifiers, row.id })
        row.name, row.identifiers = name, identifiers
    else
        local id = AY.DB.Insert(
            'INSERT INTO ay_players (license, name, group_name, identifiers, metadata, data) VALUES (?, ?, ?, ?, ?, ?)',
            { license, name, defaultGroup, identifiers, '{}', '{}' }
        )
        row = { id = id, license = license, name = name, group_name = defaultGroup, identifiers = identifiers, metadata = '{}', data = '{}' }
    end

    if not GetPlayerName(src) then return end -- player left while we were loading

    local player = createPlayer(src, row)
    players[src] = player

    logConnection(('%s joined the server (id %s, group %s)'):format(name, src, player.GetGroup()))
    TriggerEvent('ay-core:server:playerLoaded', src)
    TriggerClientEvent('ay-core:client:playerLoaded', src, player.GetPublicData())
end

function AY.GetPlayer(src)
    return players[tonumber(src)]
end

function AY.IsPlayerLoaded(src)
    return players[tonumber(src)] ~= nil
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

    local name = GetPlayerName(src) or 'Unknown'
    logConnection(('%s is connecting (id %s)'):format(name, src))

    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then
        logConnection(('%s was rejected: no Rockstar license'):format(name))
        deferrals.done('A valid Rockstar license is required to join this server.')
        return
    end
    if AY.GetPlayerByLicense(license) then
        logConnection(('%s was rejected: account already connected'):format(name))
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
    local name = player and player.GetName() or GetPlayerName(src) or 'Unknown'
    reason = tostring(reason or 'unknown')

    if player then
        logConnection(('%s left the server (id %s): %s'):format(name, src, reason))
    else
        logConnection(('%s disconnected before finishing loading (id %s): %s'):format(name, src, reason))
        return
    end

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