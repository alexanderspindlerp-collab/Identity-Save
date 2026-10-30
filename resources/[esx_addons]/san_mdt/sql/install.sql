CREATE TABLE IF NOT EXISTS `mdt_incidents` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `incident_no` VARCHAR(16) NOT NULL,
  `title` VARCHAR(255) DEFAULT '',
  `description` LONGTEXT DEFAULT NULL,
  `status` VARCHAR(64) DEFAULT 'Aktiv',
  `location` VARCHAR(255) DEFAULT '',
  `objects` LONGTEXT DEFAULT NULL,
  `criminals` LONGTEXT DEFAULT NULL,
  `tags` LONGTEXT DEFAULT NULL,
  `evidence` LONGTEXT DEFAULT NULL,
  `officers` LONGTEXT DEFAULT NULL,
  `civilians` LONGTEXT DEFAULT NULL,
  `vehicles` LONGTEXT DEFAULT NULL,
  `references_json` LONGTEXT DEFAULT NULL,
  `created_by` VARCHAR(128) DEFAULT '',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `locked` TINYINT(1) DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `incident_no_idx` (`incident_no`),
  KEY `created_at_idx` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Migration hvis du allerede har en gammel mdt_incidents tabel med case_no.
ALTER TABLE `mdt_incidents` ADD COLUMN IF NOT EXISTS `incident_no` VARCHAR(16) NULL;
UPDATE `mdt_incidents` SET `incident_no` = `case_no` WHERE (`incident_no` IS NULL OR `incident_no` = '') AND `case_no` IS NOT NULL AND `case_no` <> '';
UPDATE `mdt_incidents` SET `incident_no` = CONCAT('OLD', LPAD(`id`, 6, '0')) WHERE `incident_no` IS NULL OR `incident_no` = '';
ALTER TABLE `mdt_incidents` ADD COLUMN IF NOT EXISTS `objects` LONGTEXT DEFAULT NULL;
ALTER TABLE `mdt_incidents` ADD COLUMN IF NOT EXISTS `criminals` LONGTEXT DEFAULT NULL;
ALTER TABLE `mdt_incidents` ADD COLUMN IF NOT EXISTS `references_json` LONGTEXT DEFAULT NULL;
ALTER TABLE `mdt_incidents` ADD COLUMN IF NOT EXISTS `locked` TINYINT(1) DEFAULT 0;

CREATE TABLE IF NOT EXISTS `mdt_news` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `description` TEXT NULL,
  `important` TINYINT(1) DEFAULT 0,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_bolos` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `title` VARCHAR(255) NOT NULL DEFAULT '',
  `description` TEXT NULL,
  `plate` VARCHAR(32) DEFAULT '',
  `active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_warrants` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(128) NOT NULL DEFAULT '',
  `description` TEXT NULL,
  `active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `mdt_audit_logs` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `category` VARCHAR(64) NOT NULL DEFAULT 'System',
  `action` VARCHAR(96) NOT NULL DEFAULT '',
  `officer_identifier` VARCHAR(128) DEFAULT '',
  `officer_name` VARCHAR(128) DEFAULT '',
  `officer_badge` VARCHAR(32) DEFAULT '',
  `target_type` VARCHAR(64) DEFAULT '',
  `target_id` VARCHAR(128) DEFAULT '',
  `target_label` VARCHAR(255) DEFAULT '',
  `message` TEXT NULL,
  `metadata` LONGTEXT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `category_idx` (`category`),
  KEY `action_idx` (`action`),
  KEY `officer_identifier_idx` (`officer_identifier`),
  KEY `target_idx` (`target_type`, `target_id`),
  KEY `created_at_idx` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `mdt_mail` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `recipient` VARCHAR(128) NOT NULL DEFAULT '',
  `sender` VARCHAR(128) NOT NULL DEFAULT '',
  `subject` VARCHAR(255) NOT NULL DEFAULT '',
  `body` LONGTEXT NULL,
  `department` VARCHAR(128) NULL,
  `summary` VARCHAR(255) NULL,
  `recipient_type` VARCHAR(32) NOT NULL DEFAULT 'private',
  `seen_at` TIMESTAMP NULL DEFAULT NULL,
  `thread_id` INT NULL,
  `parent_id` INT NULL,
  `sender_identifier` VARCHAR(80) NULL,
  `reply_allowed` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `recipient_idx` (`recipient`),
  KEY `recipient_type_idx` (`recipient_type`),
  KEY `created_at_idx` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


CREATE TABLE IF NOT EXISTS `mdt_mail_reads` (
  `mail_id` INT NOT NULL,
  `identifier` VARCHAR(128) NOT NULL,
  `seen_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mail_id`, `identifier`),
  INDEX `idx_identifier_seen` (`identifier`, `seen_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE mdt_employee_meta ADD COLUMN profile_image TEXT NULL;

CREATE TABLE IF NOT EXISTS `mdt_employee_permissions` (
  `identifier` VARCHAR(80) NOT NULL,
  `permission` VARCHAR(64) NOT NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`, `permission`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
