-- Shared config: loaded on BOTH server and client.
-- Never put secrets (webhooks, keys, passwords) in this file.
Config = {}

Config.Debug = false
Config.ServerName = 'AY Server'

-- How long (ms) a callback waits for a response before giving up.
Config.CallbackTimeout = 10000

Config.Spawn = {
    Enabled = true, -- set to false if you use your own spawn / character system
    Model = 'mp_m_freemode_01',
    Coords = vec4(195.17, -933.77, 30.69, 144.5), -- x, y, z, heading
}