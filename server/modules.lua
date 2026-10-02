-- Registry of satellite resources (AY-Jobs, AY-Skin, ...) that run on top of AY-Core.
AY.Modules = {}

local modules = {} -- [name] = { name, version, dependencies, registeredAt }

function AY.Modules.Register(owner, def)
    def = def or {}
    local module = {
        name = owner,
        version = def.version or '0.0.0',
        dependencies = def.dependencies or {},
        registeredAt = os.time(),
    }
    modules[owner] = module

    for _, dependency in ipairs(module.dependencies) do
        if not modules[dependency] then
            AY.Logger.Warn('modules', ('%s depends on "%s" which is not registered (yet)'):format(owner, dependency))
        end
    end

    AY.Logger.Info('modules', ('Module registered: %s v%s'):format(owner, module.version))
    TriggerEvent('ay-core:server:moduleRegistered', owner)
    return true
end

function AY.Modules.Unregister(owner)
    if not modules[owner] then return end
    modules[owner] = nil
    AY.Logger.Info('modules', ('Module unregistered: %s'):format(owner))
    TriggerEvent('ay-core:server:moduleUnregistered', owner)
end

function AY.Modules.IsLoaded(name) return modules[name] ~= nil end

function AY.Modules.Get(name) return AY.Utils.DeepCopy(modules[name]) end

function AY.Modules.List()
    local list = {}
    for _, module in pairs(modules) do list[#list + 1] = AY.Utils.DeepCopy(module) end
    return list
end

-- When a satellite stops, everything it registered in the core is removed.
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then return end
    AY.Hooks.RemoveOwner(resource)
    AY.Modules.Unregister(resource)
end)