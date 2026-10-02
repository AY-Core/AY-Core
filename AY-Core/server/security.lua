AY.Security = {}

local buckets = {} -- [source][key] = { start, count }

-- Returns true if the event is allowed, false if the player exceeded the rate limit.
-- Used by AY.RegisterServerEvent / AY.RegisterCallback (see import.lua).
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