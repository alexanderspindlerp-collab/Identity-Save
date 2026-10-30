CREATE TABLE IF NOT EXISTS `ya_workshop_companies` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `company_type` VARCHAR(24) NOT NULL DEFAULT 'mechanic',
  `job_name` VARCHAR(48) NULL,
  `color` VARCHAR(16) NOT NULL DEFAULT '#14b8a6',
  `balance` INT NOT NULL DEFAULT 0,
  `locked` TINYINT(1) NOT NULL DEFAULT 0,
  `closed` TINYINT(1) NOT NULL DEFAULT 0,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_workshop_name` (`name`),
  KEY `owner_idx` (`owner_identifier`),
  KEY `type_idx` (`company_type`),
  KEY `closed_idx` (`closed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_roles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `role_key` VARCHAR(32) NOT NULL,
  `name` VARCHAR(48) NOT NULL,
  `permissions` LONGTEXT NULL,
  `is_default` TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_workshop_role` (`company_id`, `role_key`),
  KEY `company_idx` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `identifier` VARCHAR(80) NOT NULL,
  `character_name` VARCHAR(120) NULL,
  `role_id` INT NOT NULL,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_workshop_member` (`identifier`),
  KEY `company_idx` (`company_id`),
  KEY `role_idx` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_orders` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `order_number` VARCHAR(32) NOT NULL,
  `status` VARCHAR(24) NOT NULL DEFAULT 'pending',
  `customer_identifier` VARCHAR(80) NOT NULL,
  `customer_name` VARCHAR(120) NOT NULL,
  `vehicle_plate` VARCHAR(12) NOT NULL,
  `vehicle_model` VARCHAR(48) NULL,
  `vehicle_label` VARCHAR(80) NULL,
  `vehicle_props` LONGTEXT NULL,
  `target_vehicle_props` LONGTEXT NULL,
  `total_price` INT NOT NULL DEFAULT 0,
  `notes` VARCHAR(255) NULL,
  `assigned_to` VARCHAR(80) NULL,
  `assigned_name` VARCHAR(120) NULL,
  `shop_key` VARCHAR(32) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_order_number` (`order_number`),
  KEY `company_idx` (`company_id`),
  KEY `status_idx` (`status`),
  KEY `customer_idx` (`customer_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_order_items` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `order_id` INT NOT NULL,
  `category_key` VARCHAR(32) NOT NULL,
  `group_key` VARCHAR(48) NULL,
  `item_key` VARCHAR(48) NOT NULL,
  `line_type` VARCHAR(16) NOT NULL DEFAULT 'item',
  `label` VARCHAR(80) NOT NULL,
  `description` VARCHAR(255) NULL,
  `price` INT NOT NULL DEFAULT 0,
  `mod_data` LONGTEXT NULL,
  PRIMARY KEY (`id`),
  KEY `order_idx` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_calls` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `caller_identifier` VARCHAR(80) NULL,
  `caller_name` VARCHAR(120) NOT NULL,
  `message` VARCHAR(255) NOT NULL,
  `coords_x` DOUBLE NOT NULL,
  `coords_y` DOUBLE NOT NULL,
  `coords_z` DOUBLE NOT NULL DEFAULT 0,
  `status` VARCHAR(24) NOT NULL DEFAULT 'open',
  `accepted_by` VARCHAR(80) NULL,
  `accepted_name` VARCHAR(120) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `closed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `company_idx` (`company_id`),
  KEY `status_idx` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_invoices` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `order_id` INT NULL,
  `invoice_number` VARCHAR(32) NOT NULL,
  `status` VARCHAR(16) NOT NULL DEFAULT 'unpaid',
  `customer_identifier` VARCHAR(80) NULL,
  `customer_name` VARCHAR(120) NOT NULL,
  `description` VARCHAR(255) NOT NULL,
  `subtotal` INT NOT NULL DEFAULT 0,
  `vat_amount` INT NOT NULL DEFAULT 0,
  `total` INT NOT NULL DEFAULT 0,
  `created_by` VARCHAR(80) NULL,
  `created_by_name` VARCHAR(120) NULL,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_ws_invoice_number` (`invoice_number`),
  KEY `company_idx` (`company_id`),
  KEY `status_idx` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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

CREATE TABLE IF NOT EXISTS `ya_workshop_prices` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `category_key` VARCHAR(32) NOT NULL,
  `group_key` VARCHAR(48) NOT NULL,
  `item_key` VARCHAR(48) NOT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_ws_price` (`company_id`, `category_key`, `group_key`, `item_key`),
  KEY `company_idx` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_company_shops` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `company_id` INT NOT NULL,
  `shop_key` VARCHAR(48) NOT NULL,
  `blip_sprite` INT NULL DEFAULT 72,
  `blip_color` INT NOT NULL DEFAULT 3,
  `blip_scale` DOUBLE NOT NULL DEFAULT 0.85,
  `blip_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_shop_key` (`shop_key`),
  KEY `company_idx` (`company_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_workshop_shop_locations` (
  `shop_key` VARCHAR(48) NOT NULL,
  `pos_x` DOUBLE NOT NULL,
  `pos_y` DOUBLE NOT NULL,
  `pos_z` DOUBLE NOT NULL,
  `radius` DOUBLE NOT NULL DEFAULT 18.0,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`shop_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
