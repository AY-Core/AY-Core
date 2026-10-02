AY.Security = {}

local buckets = {} -- [source][key] = { start, count }

-- Returns true if the event is allowed, false if the player exceeded the rate limit.
function AY.Security.CheckRate(src, key, limit)
    local cfg = ServerConfig.Security.RateLimit
    local max = (limit and limit.Max) or cfg.Max
    local window = (limit and limit.Window) or cfg.Window
    local now = GetGameTimer()

    buckets[src] = buckets[src] or {}
    local bucket = buckets[src][key]

    if not bucket or now - bucket.start >= window then
        buckets[src][key] = { start = now, count = 1 }
        return true
    end

    bucket.count = bucket.count + 1
    if bucket.count > max then
        if not bucket.flagged then
            bucket.flagged = true
            AY.Logger.Warn('security', ('Rate limit exceeded by %s (id %s) on event "%s"'):format(GetPlayerName(src) or 'unknown', src, key))
        end
        return false
    end
    return true
end

AddEventHandler('playerDropped', function()
    buckets[source] = nil
end)

-- Secure replacement for RegisterNetEvent. Handler signature: function(src, ...)
-- opts: RequirePlayer (default true), Permission (group name), RateLimit ({ Window, Max })
function AY.RegisterServerEvent(name, handler, opts)
    opts = opts or {}

    RegisterNetEvent(name, function(...)
        local src = source -- capture immediately, never trust client-sent identity

        if not AY.Security.CheckRate(src, name, opts.RateLimit) then return end

        if opts.RequirePlayer ~= false and not AY.GetPlayer(src) then return end

        if opts.Permission and not AY.HasPermission(src, opts.Permission) then
            AY.Logger.Warn('security', ('%s (id %s) triggered "%s" without permission'):format(GetPlayerName(src) or 'unknown', src, name))
            return
        end

        local ok, err = pcall(handler, src, ...)
        if not ok then
            AY.Logger.Error('events', ('Error in event "%s": %s'):format(name, err))
        end
    end)
end
