-- Shared config: loaded on BOTH server and client.
-- Never put secrets (webhooks, keys, passwords) in this file.
Config = {}

Config.Debug = false
Config.ServerName = 'AY Server'

-- How long (ms) a callback waits for a response before giving up.
Config.CallbackTimeout = 10000
