CREATE TABLE IF NOT EXISTS `mdt_employee_awards` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(128) NOT NULL,
  `award_key` VARCHAR(64) NOT NULL DEFAULT 'brave',
  `award_label` VARCHAR(128) NOT NULL DEFAULT '',
  `note` TEXT NULL,
  `granted_by` VARCHAR(128) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `identifier_idx` (`identifier`),
  KEY `award_key_idx` (`award_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
