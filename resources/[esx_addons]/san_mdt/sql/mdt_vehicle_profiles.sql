CREATE TABLE IF NOT EXISTS `mdt_vehicle_profiles` (
  `plate` VARCHAR(16) NOT NULL,
  `profile_image` TEXT NULL,
  `notes` LONGTEXT NULL,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mdt_vehicle_tracks` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `plate` VARCHAR(16) NOT NULL,
  `officer_name` VARCHAR(128) NULL,
  `officer_id` VARCHAR(80) NULL,
  `status_note` VARCHAR(255) NULL,
  `garage_label` VARCHAR(128) NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `plate_idx` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
