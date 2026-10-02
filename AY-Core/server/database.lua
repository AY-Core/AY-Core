AY.DB = { ready = false }

local SCHEMA = {
    [[
        CREATE TABLE IF NOT EXISTS `ay_players` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(60) NOT NULL,
            `name` VARCHAR(100) NOT NULL,
            `group_name` VARCHAR(32) NOT NULL DEFAULT 'user',
            `identifiers` LONGTEXT NULL,
            `metadata` LONGTEXT NULL,
            `first_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `uniq_license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
    [[
        CREATE TABLE IF NOT EXISTS `ay_logs` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `level` VARCHAR(10) NOT NULL,
            `category` VARCHAR(50) NOT NULL,
            `message` TEXT NOT NULL,
            `data` LONGTEXT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_level_created` (`level`, `created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]],
}

local MIGRATIONS_TABLE = [[
    CREATE TABLE IF NOT EXISTS `ay_migrations` (
        `resource` VARCHAR(64) NOT NULL,
        `id` VARCHAR(64) NOT NULL,
        `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`resource`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
]]

-- AY-Core's own schema changes after v0.1.0 live here.
local CORE_MIGRATIONS = {
    { id = '001_player_data', sql = 'ALTER TABLE `ay_players` ADD COLUMN `data` LONGTEXT NULL' },
}

-- Thin wrappers over oxmysql. Always use placeholders (?) - never concatenate user input into SQL.
-- NOTE: these await, so use them inside AY-Core. Other resources should use oxmysql directly.
function AY.DB.Query(query, params)  return MySQL.query.await(query, params or {}) end
function AY.DB.Single(query, params) return MySQL.single.await(query, params or {}) end
function AY.DB.Scalar(query, params) return MySQL.scalar.await(query, params or {}) end
function AY.DB.Insert(query, params) return MySQL.insert.await(query, params or {}) end
function AY.DB.Update(query, params) return MySQL.update.await(query, params or {}) end

function AY.IsReady() return AY.DB.ready end

-- Applies migrations that were not applied yet, in order, and records them in ay_migrations.
-- Errors stop the run (nothing after a failed migration is applied).
local function runMigrations(resource, migrations)
    local applied = {}
    local rows = MySQL.query.await('SELECT `id` FROM `ay_migrations` WHERE `resource` = ?', { resource }) or {}
    for _, row in ipairs(rows) do applied[row.id] = true end

    for _, migration in ipairs(migrations) do
        if type(migration.id) ~= 'string' then error('every migration needs a string "id"') end

        if not applied[migration.id] then
            local statements = type(migration.sql) == 'table' and migration.sql or { migration.sql }
            for _, statement in ipairs(statements) do
                if MySQL.query.await(statement) == nil then
                    error(('statement failed in migration "%s"'):format(migration.id))
                end
            end
            MySQL.insert.await('INSERT INTO `ay_migrations` (`resource`, `id`) VALUES (?, ?)', { resource, migration.id })
            AY.Logger.Info('database', ('Applied migration %s/%s'):format(resource, migration.id))
        end
    end
end

-- Asynchronous (the callback is called when done), because it is meant to be called from other resources.
--   AY.DB.Migrate('AY-Jobs', { { id = '001_init', sql = '...' } }, function(ok, err) end)
function AY.DB.Migrate(resource, migrations, cb)
    CreateThread(function()
        while not AY.DB.ready do Wait(100) end

        local ok, err = pcall(runMigrations, resource, migrations)
        if not ok then
            AY.Logger.Error('database', ('Migration failed for %s: %s'):format(resource, tostring(err)))
        end
        if cb then pcall(cb, ok, (not ok) and tostring(err) or nil) end
    end)
end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(MIGRATIONS_TABLE)
        if ServerConfig.Database.AutoCreateTables then
            for _, statement in ipairs(SCHEMA) do
                MySQL.query.await(statement)
            end
        end
        runMigrations(AY.Name, CORE_MIGRATIONS)
    end)

    if not ok then
        AY.Logger.Error('database', ('Database setup failed, AY-Core will not become ready: %s'):format(tostring(err)))
        return
    end

    AY.DB.ready = true
    AY.Logger.Info('database', 'Database ready.')
    TriggerEvent('ay-core:server:ready')
end)