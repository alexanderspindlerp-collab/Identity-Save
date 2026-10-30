CREATE TABLE IF NOT EXISTS `nsk_gangs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(80) NOT NULL,
  `tag` VARCHAR(32) NULL,
  `color` VARCHAR(16) NOT NULL DEFAULT '#ff3048',
  `threat_level` VARCHAR(24) NOT NULL DEFAULT 'medium',
  `status` VARCHAR(24) NOT NULL DEFAULT 'active',
  `notes` TEXT NULL,
  `created_by` VARCHAR(80) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `name_idx` (`name`),
  KEY `status_idx` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `nsk_gang_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `identifier` VARCHAR(80) NOT NULL,
  `person_name` VARCHAR(120) NULL,
  `role` VARCHAR(48) NOT NULL DEFAULT 'Medlem',
  `board_tier` VARCHAR(24) NOT NULL DEFAULT 'unknown',
  `board_rank` INT NOT NULL DEFAULT 0,
  `notes` TEXT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `registered_by` VARCHAR(80) NULL,
  `registered_by_name` VARCHAR(80) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_active_member` (`identifier`, `active`),
  KEY `gang_idx` (`gang_id`),
  KEY `identifier_idx` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `nsk_territories` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_id` INT NOT NULL,
  `name` VARCHAR(80) NOT NULL,
  `color` VARCHAR(16) NULL,
  `center_x` DOUBLE NOT NULL DEFAULT 0,
  `center_y` DOUBLE NOT NULL DEFAULT 0,
  `radius` DOUBLE NOT NULL DEFAULT 120,
  `vertices_json` LONGTEXT NULL,
  `notes` TEXT NULL,
  `created_by` VARCHAR(80) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_idx` (`gang_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `nsk_observations` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `target_type` VARCHAR(16) NOT NULL DEFAULT 'gang',
  `gang_id` INT NULL,
  `identifier` VARCHAR(80) NULL,
  `person_name` VARCHAR(120) NULL,
  `subject` VARCHAR(120) NOT NULL,
  `body` TEXT NULL,
  `priority` VARCHAR(16) NOT NULL DEFAULT 'normal',
  `created_by` VARCHAR(80) NULL,
  `created_by_name` VARCHAR(80) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_idx` (`gang_id`),
  KEY `identifier_idx` (`identifier`),
  KEY `target_type_idx` (`target_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `nsk_gang_links` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `gang_a_id` INT NOT NULL,
  `gang_b_id` INT NOT NULL,
  `relation_type` VARCHAR(24) NOT NULL DEFAULT 'unknown',
  `notes` TEXT NULL,
  `created_by` VARCHAR(80) NULL,
  `created_by_name` VARCHAR(80) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `gang_a_idx` (`gang_a_id`),
  KEY `gang_b_idx` (`gang_b_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
