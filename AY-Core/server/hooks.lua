-- Hooks let other resources influence what the core does, without editing the core.
--
-- A handler receives a context table and may return:
--   nothing / true   -> continue
--   false, 'reason'  -> cancel the action
--   a table          -> merged into the context for the next handlers
--
-- IMPORTANT: handlers from other resources are called across resources, so they must be
-- fast and synchronous (no Wait / MySQL.await inside a hook handler).
--
-- Built-in hooks:
--   beforePlayerLoad  { source, license, name }  (cancel = player is kicked with the reason)
--   playerSaving      { source, license }        (write your data with player.SetData before it is saved)

AY.Hooks = {}

local hooks = {} -- [name] = { { owner, handler, priority, seq }, ... }
local seq = 0

function AY.Hooks.Register(owner, name, handler, priority)
    if type(name) ~= 'string' or handler == nil then return false end
    seq = seq + 1
    hooks[name] = hooks[name] or {}
    table.insert(hooks[name], { owner = owner, handler = handler, priority = priority or 0, seq = seq })
    table.sort(hooks[name], function(a, b)
        if a.priority ~= b.priority then return a.priority > b.priority end -- higher priority runs first
        return a.seq < b.seq
    end)
    return true
end

-- Returns true, ctx  or  false, reason
function AY.Hooks.Run(name, ctx)
    ctx = ctx or {}
    local list = {}
    for i, entry in ipairs(hooks[name] or {}) do list[i] = entry end -- snapshot

    for _, entry in ipairs(list) do
        local ok, a, b = pcall(entry.handler, ctx)
        if not ok then
            AY.Logger.Error('hooks', ('Hook "%s" from %s failed: %s'):format(name, entry.owner, tostring(a)))
        elseif a == false then
            return false, b or ('cancelled by ' .. entry.owner)
        elseif type(a) == 'table' then
            ctx = AY.Utils.Merge(ctx, a)
        end
    end
    return true, ctx
end

function AY.Hooks.RemoveOwner(owner)
    for _, list in pairs(hooks) do
        for i = #list, 1, -1 do
            if list[i].owner == owner then table.remove(list, i) end
        end
    end
end