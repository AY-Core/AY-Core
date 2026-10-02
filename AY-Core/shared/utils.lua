AY = AY or {}
AY.Name = 'AY-Core'
AY.IsServer = IsDuplicityVersion()
AY.Version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.0.0'

local Utils = {}
AY.Utils = Utils

function Utils.DeepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = Utils.DeepCopy(v)
    end
    return copy
end

-- Returns a new table: `defaults` overridden by `values` (recursive).
function Utils.Merge(defaults, values)
    local result = Utils.DeepCopy(defaults or {})
    for k, v in pairs(values or {}) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = Utils.Merge(result[k], v)
        else
            result[k] = Utils.DeepCopy(v)
        end
    end
    return result
end

function Utils.Round(value, decimals)
    local m = 10 ^ (decimals or 0)
    return math.floor(value * m + 0.5) / m
end

function Utils.Trim(value)
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''))
end

function Utils.Count(tbl)
    local n = 0
    for _ in pairs(tbl) do n = n + 1 end
    return n
end

function Utils.Contains(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

function Utils.IsNonEmptyString(value, maxLength)
    return type(value) == 'string' and #value > 0 and #value <= (maxLength or 255)
end

function AY.Debug(...)
    if not Config.Debug then return end
    print(('^5[%s][DEBUG]^7'):format(AY.Name), ...)
end
