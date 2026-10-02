AY.Logger = {}

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local COLORS = { debug = '^5', info = '^2', warn = '^3', error = '^1' }
local DISCORD_COLORS = { debug = 10181046, info = 3066993, warn = 15105570, error = 15158332 }

local function sendToDiscord(level, category, message)
    PerformHttpRequest(ServerConfig.Logging.DiscordWebhook, function() end, 'POST', json.encode({
        username = AY.Name,
        allowed_mentions = { parse = {} },
        embeds = {{
            title = ('[%s] %s'):format(level:upper(), category),
            description = message:sub(1, 2000),
            color = DISCORD_COLORS[level],
        }},
    }), { ['Content-Type'] = 'application/json' })
end

function AY.Logger.Log(level, category, message, data)
    local cfg = ServerConfig.Logging
    local value = LEVELS[level]
    if not value or value < (LEVELS[cfg.Level] or LEVELS.info) then return end

    message = tostring(message)
    print(('%s[%s][%s][%s]^7 %s'):format(COLORS[level], AY.Name, level:upper(), category, message))

    if cfg.Database and AY.DB and AY.DB.ready and value >= LEVELS[cfg.DatabaseMinLevel] then
        MySQL.insert(
            'INSERT INTO ay_logs (level, category, message, data) VALUES (?, ?, ?, ?)',
            { level, category, message, json.encode(data or {}) }
        )
    end

    if cfg.DiscordWebhook ~= '' and value >= LEVELS[cfg.DiscordMinLevel] then
        sendToDiscord(level, category, message)
    end
end

function AY.Logger.Debug(category, message, data) AY.Logger.Log('debug', category, message, data) end
function AY.Logger.Info(category, message, data)  AY.Logger.Log('info', category, message, data) end
function AY.Logger.Warn(category, message, data)  AY.Logger.Log('warn', category, message, data) end
function AY.Logger.Error(category, message, data) AY.Logger.Log('error', category, message, data) end
