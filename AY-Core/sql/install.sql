-- Optional: AY-Core creates these tables automatically (ServerConfig.Database.AutoCreateTables).
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ay_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `level` VARCHAR(10) NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    `message` TEXT NOT NULL,
    `data` LONGTEXT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_level_created` (`level`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
