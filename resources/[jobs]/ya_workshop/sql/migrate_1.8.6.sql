CREATE TABLE IF NOT EXISTS `ya_workshop_unlocks` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `vehicle_plate` VARCHAR(16) NOT NULL,
  `shop_key` VARCHAR(48) NOT NULL,
  `category_key` VARCHAR(32) NOT NULL,
  `group_key` VARCHAR(48) NOT NULL,
  `unlocked_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_ws_unlock` (`owner_identifier`, `vehicle_plate`, `shop_key`, `category_key`, `group_key`),
  KEY `owner_plate_shop_idx` (`owner_identifier`, `vehicle_plate`, `shop_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
