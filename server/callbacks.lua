local serverCallbacks = {}  -- callbacks the client can call
local clientPending = {}    -- [requestId] = { src, promise } (server -> client requests)
local nextRequestId = 0

-- Register a callback clients can request:  AY.RegisterCallback('name', function(src, ...) return ... end)
function AY.RegisterCallback(name, handler)
    serverCallbacks[name] = handler
end

AY.RegisterServerEvent('ay-core:server:callback', function(src, name, requestId, ...)
    if type(name) ~= 'string' or type(requestId) ~= 'number' then return end

    local handler = serverCallbacks[name]
    if not handler then
        AY.Logger.Warn('callbacks', ('Unknown callback "%s" requested by %s'):format(name, src))
        TriggerClientEvent('ay-core:client:callbackResponse', src, requestId, false)
        return
    end

    local result = table.pack(pcall(handler, src, ...))
    if not result[1] then
        AY.Logger.Error('callbacks', ('Error in callback "%s": %s'):format(name, result[2]))
        TriggerClientEvent('ay-core:client:callbackResponse', src, requestId, false)
        return
    end

    TriggerClientEvent('ay-core:client:callbackResponse', src, requestId, true, table.unpack(result, 2, result.n))
end)

-- Ask a client for data (awaitable):  local value = AY.TriggerClientCallback(src, 'name', ...)
function AY.TriggerClientCallback(src, name, ...)
    nextRequestId = (nextRequestId % 65535) + 1
    local requestId = nextRequestId
    local p = promise.new()
    clientPending[requestId] = { src = src, promise = p }

    TriggerClientEvent('ay-core:client:callback', src, name, requestId, ...)

    SetTimeout(Config.CallbackTimeout, function()
        local entry = clientPending[requestId]
        if entry then
            clientPending[requestId] = nil
            entry.promise:resolve(table.pack(false))
        end
    end)

    local res = Citizen.Await(p)
    if not res[1] then return end
    return table.unpack(res, 2, res.n)
end

-- Only accept a response from the player the request was sent to.
AY.RegisterServerEvent('ay-core:server:callbackResponse', function(src, requestId, ...)
    local entry = clientPending[requestId]
    if not entry or entry.src ~= src then return end
    clientPending[requestId] = nil
    entry.promise:resolve(table.pack(...))
end, { RequirePlayer = false })

AddEventHandler('playerDropped', function()
    local src = source
    for id, entry in pairs(clientPending) do
        if entry.src == src then
            clientPending[id] = nil
            entry.promise:resolve(table.pack(false))
        end
    end
end)
