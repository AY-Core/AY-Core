local clientCallbacks = {}
local pending = {}
local nextRequestId = 0

-- Register a callback the server can request:  AY.RegisterClientCallback('name', function(...) return ... end)
function AY.RegisterClientCallback(name, handler)
    clientCallbacks[name] = handler
end

-- Ask the server for data (awaitable):  local value = AY.TriggerCallback('name', ...)
function AY.TriggerCallback(name, ...)
    nextRequestId = (nextRequestId % 65535) + 1
    local requestId = nextRequestId
    local p = promise.new()
    pending[requestId] = p

    TriggerServerEvent('ay-core:server:callback', name, requestId, ...)

    SetTimeout(Config.CallbackTimeout, function()
        if pending[requestId] then
            pending[requestId] = nil
            p:resolve(table.pack(false))
        end
    end)

    local res = Citizen.Await(p)
    if not res[1] then return end
    return table.unpack(res, 2, res.n)
end

RegisterNetEvent('ay-core:client:callbackResponse', function(requestId, ...)
    local p = pending[requestId]
    if not p then return end
    pending[requestId] = nil
    p:resolve(table.pack(...))
end)

RegisterNetEvent('ay-core:client:callback', function(name, requestId, ...)
    local handler = clientCallbacks[name]
    if not handler then
        TriggerServerEvent('ay-core:server:callbackResponse', requestId, false)
        return
    end

    local result = table.pack(pcall(handler, ...))
    if not result[1] then
        print(('^1[%s] Error in client callback "%s": %s^7'):format(AY.Name, name, result[2]))
        TriggerServerEvent('ay-core:server:callbackResponse', requestId, false)
        return
    end

    TriggerServerEvent('ay-core:server:callbackResponse', requestId, true, table.unpack(result, 2, result.n))
end)
