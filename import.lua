--[[
    AY-Core import
    ----------------------------------------------------------------------------
    Satellite resources (AY-Jobs, AY-Skin, ...) add this to their fxmanifest.lua:

        dependency 'AY-Core'
        shared_script '@AY-Core/import.lua'

    and get a global `AY` that:
      * always points at the running AY-Core (survives Core restarts)
      * has AY.OnReady(cb): runs cb when AY-Core is ready, and again after every Core restart
      * registers callbacks / events / commands in YOUR resource's own runtime, so async
        handlers (Wait, MySQL.await, ...) work and everything is cleaned up when you stop.

    AY-Core loads this same file for itself, so there is exactly one implementation.
]]

local CORE = 'AY-Core'
local RESOURCE = GetCurrentResourceName()
local IS_SERVER = IsDuplicityVersion()
local IS_CORE = RESOURCE == CORE
local CALLBACK_TIMEOUT = 10000

------------------------------------------------------------------------------
-- 1. Access to AY-Core (satellite resources only)
------------------------------------------------------------------------------
local core

local function getCore()
    if core then return core end
    if GetResourceState(CORE) ~= 'started' then return nil end
    local ok, result = pcall(function() return exports[CORE]:GetCore() end)
    if ok and result then core = result end
    return core
end

if not IS_CORE then
    local readyEvent = IS_SERVER and 'ay-core:server:ready' or 'ay-core:client:ready'
    local readyCallbacks = {}

    AY = setmetatable({
        Resource = RESOURCE,

        IsCoreReady = function()
            local c = getCore()
            if not c then return false end
            local ok, ready = pcall(c.IsReady)
            return ok and ready == true
        end,

        -- Put your registrations (callbacks, hooks, migrations, module) in here.
        OnReady = function(cb)
            readyCallbacks[#readyCallbacks + 1] = cb
            if AY.IsCoreReady() then CreateThread(cb) end
        end,
    }, {
        __index = function(_, key)
            local c = getCore()
            return c and c[key]
        end,
    })

    AddEventHandler(readyEvent, function()
        core = nil -- Core (re)started: fetch a fresh reference
        for _, cb in ipairs(readyCallbacks) do CreateThread(cb) end
    end)

    AddEventHandler('onResourceStop', function(name)
        if name == CORE then core = nil end
    end)
end

------------------------------------------------------------------------------
-- 2. Server side
------------------------------------------------------------------------------
if IS_SERVER then
    local function logError(category, message)
        local ok = pcall(function() AY.Logger.Error(category, message) end)
        if not ok then print(('^1[%s][%s] %s^7'):format(RESOURCE, category, message)) end
    end

    -- Rate limit + "player loaded" + permission check (all provided by AY-Core).
    local function allowed(src, key, opts)
        opts = opts or {}
        local ok, result = pcall(function()
            if not AY.Security.CheckRate(src, key, opts.RateLimit) then return false end
            if opts.RequirePlayer ~= false and not AY.IsPlayerLoaded(src) then return false end
            if opts.Permission and not AY.HasPermission(src, opts.Permission) then
                AY.Logger.Warn('security', ('%s (id %s) triggered "%s" without permission'):format(GetPlayerName(src) or 'unknown', src, key))
                return false
            end
            return true
        end)
        return ok and result == true
    end

    -- Secure RegisterNetEvent. Handler: function(src, ...)
    -- opts: RequirePlayer (default true), Permission (group), RateLimit ({ Window, Max })
    function AY.RegisterServerEvent(name, handler, opts)
        RegisterNetEvent(name, function(...)
            local src = source -- capture immediately, never trust client-sent identity
            if not allowed(src, name, opts) then return end
            local ok, err = pcall(handler, src, ...)
            if not ok then logError('events', ('Error in event "%s": %s'):format(name, err)) end
        end)
    end

    -- Permission-checked command. Handler: function(src, args, rawCommand)
    function AY.RegisterCommand(name, requiredGroup, handler)
        RegisterCommand(name, function(src, args, raw)
            if requiredGroup and not AY.HasPermission(src, requiredGroup) then
                AY.Reply(src, 'You do not have permission to use this command.')
                return
            end
            local ok, err = pcall(handler, src, args, raw)
            if not ok then logError('commands', ('Error in command "%s": %s'):format(name, err)) end
        end, false)
    end

    -- Client -> server callbacks. Handler: function(src, ...) return ... end  (may Wait / await)
    local serverCallbacks = {}

    function AY.RegisterCallback(name, handler, opts)
        if not serverCallbacks[name] then
            RegisterNetEvent(('ay:cb:%s'):format(name), function(invoker, requestId, ...)
                local src = source
                if type(invoker) ~= 'string' or type(requestId) ~= 'number' then return end

                local entry = serverCallbacks[name]
                if not allowed(src, 'cb:' .. name, entry.opts) then return end

                local response = ('ay:cbr:%s'):format(invoker)
                local result = table.pack(pcall(entry.handler, src, ...))
                if not result[1] then
                    logError('callbacks', ('Error in callback "%s": %s'):format(name, result[2]))
                    TriggerClientEvent(response, src, requestId, false)
                    return
                end
                TriggerClientEvent(response, src, requestId, true, table.unpack(result, 2, result.n))
            end)
        end
        serverCallbacks[name] = { handler = handler, opts = opts }
    end

    -- Server -> client callbacks (awaitable):  local value = AY.TriggerClientCallback(src, 'name', ...)
    local pendingClient = {}
    local nextClientId = 0

    RegisterNetEvent(('ay:ccbr:%s'):format(RESOURCE), function(requestId, ok, ...)
        local src = source
        local entry = pendingClient[requestId]
        if not entry or entry.src ~= src then return end -- only the asked player may answer
        pendingClient[requestId] = nil
        entry.promise:resolve(table.pack(ok == true, ...))
    end)

    function AY.TriggerClientCallback(src, name, ...)
        nextClientId = nextClientId % 65535 + 1
        local id = nextClientId
        local p = promise.new()
        pendingClient[id] = { src = src, promise = p }

        TriggerClientEvent(('ay:ccb:%s'):format(name), src, RESOURCE, id, ...)

        SetTimeout(CALLBACK_TIMEOUT, function()
            if pendingClient[id] then
                pendingClient[id] = nil
                p:resolve(table.pack(false))
            end
        end)

        local res = Citizen.Await(p)
        if not res[1] then return end
        return table.unpack(res, 2, res.n)
    end

    AddEventHandler('playerDropped', function()
        local src = source
        for id, entry in pairs(pendingClient) do
            if entry.src == src then
                pendingClient[id] = nil
                entry.promise:resolve(table.pack(false))
            end
        end
    end)

    -- Registrations stored inside AY-Core, tagged with your resource name so they are removed
    -- automatically when your resource stops. Hook handlers must be synchronous (see README).
    function AY.RegisterModule(def) return AY.Modules.Register(RESOURCE, def) end
    function AY.RegisterHook(name, handler, priority) return AY.Hooks.Register(RESOURCE, name, handler, priority) end
    function AY.RunHook(name, ctx) return AY.Hooks.Run(name, ctx) end
    function AY.RegisterMigrations(migrations, cb) return AY.DB.Migrate(RESOURCE, migrations, cb) end

------------------------------------------------------------------------------
-- 3. Client side
------------------------------------------------------------------------------
else
    -- Server -> client callbacks. Handler: function(...) return ... end
    local clientCallbacks = {}

    function AY.RegisterClientCallback(name, handler)
        if not clientCallbacks[name] then
            RegisterNetEvent(('ay:ccb:%s'):format(name), function(invoker, requestId, ...)
                local response = ('ay:ccbr:%s'):format(tostring(invoker))
                local result = table.pack(pcall(clientCallbacks[name], ...))
                if not result[1] then
                    print(('^1[%s] Error in client callback "%s": %s^7'):format(RESOURCE, name, result[2]))
                    TriggerServerEvent(response, requestId, false)
                    return
                end
                TriggerServerEvent(response, requestId, true, table.unpack(result, 2, result.n))
            end)
        end
        clientCallbacks[name] = handler
    end

    -- Client -> server callbacks (awaitable):  local value = AY.TriggerCallback('name', ...)
    local pending = {}
    local nextId = 0

    RegisterNetEvent(('ay:cbr:%s'):format(RESOURCE), function(requestId, ok, ...)
        local p = pending[requestId]
        if not p then return end
        pending[requestId] = nil
        p:resolve(table.pack(ok == true, ...))
    end)

    function AY.TriggerCallback(name, ...)
        nextId = nextId % 65535 + 1
        local id = nextId
        local p = promise.new()
        pending[id] = p

        TriggerServerEvent(('ay:cb:%s'):format(name), RESOURCE, id, ...)

        SetTimeout(CALLBACK_TIMEOUT, function()
            if pending[id] then
                pending[id] = nil
                p:resolve(table.pack(false))
            end
        end)

        local res = Citizen.Await(p)
        if not res[1] then return end
        return table.unpack(res, 2, res.n)
    end
end