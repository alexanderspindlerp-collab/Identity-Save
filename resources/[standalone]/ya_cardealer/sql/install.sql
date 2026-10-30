CREATE TABLE IF NOT EXISTS `ya_cardealer_dealerships` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(64) NOT NULL,
  `color` VARCHAR(16) NOT NULL DEFAULT '#1e3a5f',
  `balance` INT NOT NULL DEFAULT 0,
  `spawn_x` DOUBLE NULL,
  `spawn_y` DOUBLE NULL,
  `spawn_z` DOUBLE NULL,
  `spawn_heading` DOUBLE NULL DEFAULT 0,
  `locked` TINYINT(1) NOT NULL DEFAULT 0,
  `closed` TINYINT(1) NOT NULL DEFAULT 0,
  `owner_identifier` VARCHAR(80) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_dealer_name` (`name`),
  KEY `owner_idx` (`owner_identifier`),
  KEY `closed_idx` (`closed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_roles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership_id` INT NOT NULL,
  `role_key` VARCHAR(32) NOT NULL,
  `name` VARCHAR(48) NOT NULL,
  `permissions` LONGTEXT NULL,
  `is_default` TINYINT(1) NOT NULL DEFAULT 0,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_dealer_role` (`dealership_id`, `role_key`),
  KEY `dealership_idx` (`dealership_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_members` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership_id` INT NOT NULL,
  `identifier` VARCHAR(80) NOT NULL,
  `character_name` VARCHAR(120) NULL,
  `role_id` INT NOT NULL,
  `joined_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_dealer_member` (`identifier`),
  KEY `dealership_idx` (`dealership_id`),
  KEY `role_idx` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_catalog` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `model` VARCHAR(48) NOT NULL,
  `label` VARCHAR(80) NOT NULL,
  `manufacturer` VARCHAR(64) NOT NULL DEFAULT 'Ukendt',
  `year` INT NOT NULL DEFAULT 2024,
  `category` VARCHAR(48) NOT NULL DEFAULT 'misc',
  `import_price` INT NOT NULL DEFAULT 0,
  `list_price` INT NOT NULL DEFAULT 0,
  `supplier_stock` INT NOT NULL DEFAULT 50,
  `image_url` VARCHAR(255) NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_catalog_model` (`model`),
  KEY `active_idx` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_dealership_catalog` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership_id` INT NOT NULL,
  `catalog_id` INT NOT NULL,
  `enabled` TINYINT(1) NOT NULL DEFAULT 0,
  `import_price` INT NOT NULL DEFAULT 0,
  `list_price` INT NOT NULL DEFAULT 0,
  `max_stock` INT NOT NULL DEFAULT 20,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_dealer_catalog` (`dealership_id`, `catalog_id`),
  KEY `dealership_idx` (`dealership_id`),
  KEY `catalog_idx` (`catalog_id`),
  KEY `enabled_idx` (`enabled`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_stock` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership_id` INT NOT NULL,
  `catalog_id` INT NOT NULL,
  `plate` VARCHAR(12) NULL,
  `import_price` INT NOT NULL DEFAULT 0,
  `list_price` INT NOT NULL DEFAULT 0,
  `status` VARCHAR(24) NOT NULL DEFAULT 'in_stock',
  `imported_by` VARCHAR(80) NULL,
  `sold_to` VARCHAR(80) NULL,
  `sold_to_name` VARCHAR(120) NULL,
  `sale_price` INT NULL,
  `sold_by` VARCHAR(80) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `sold_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `dealership_idx` (`dealership_id`),
  KEY `catalog_idx` (`catalog_id`),
  KEY `status_idx` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_invoices` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership_id` INT NOT NULL,
  `invoice_type` VARCHAR(24) NOT NULL,
  `stock_id` INT NULL,
  `catalog_id` INT NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `balance_after` INT NOT NULL DEFAULT 0,
  `description` VARCHAR(255) NOT NULL,
  `created_by` VARCHAR(80) NULL,
  `created_by_name` VARCHAR(120) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `dealership_idx` (`dealership_id`),
  KEY `type_idx` (`invoice_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ya_cardealer_sales_invoices` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `dealership_id` INT NOT NULL,
  `stock_id` INT NOT NULL,
  `invoice_number` VARCHAR(32) NOT NULL,
  `transaction_number` VARCHAR(32) NOT NULL,
  `payment_method` VARCHAR(16) NOT NULL DEFAULT 'invoice',
  `status` VARCHAR(16) NOT NULL DEFAULT 'unpaid',
  `buyer_name` VARCHAR(120) NOT NULL,
  `buyer_dob` VARCHAR(32) NULL,
  `buyer_phone` VARCHAR(32) NULL,
  `buyer_identifier` VARCHAR(80) NULL,
  `vehicle_label` VARCHAR(80) NOT NULL,
  `vehicle_model` VARCHAR(48) NOT NULL,
  `plate` VARCHAR(12) NOT NULL,
  `subtotal` INT NOT NULL DEFAULT 0,
  `vat_amount` INT NOT NULL DEFAULT 0,
  `total` INT NOT NULL DEFAULT 0,
  `sold_by` VARCHAR(80) NULL,
  `sold_by_name` VARCHAR(120) NULL,
  `paid_at` TIMESTAMP NULL DEFAULT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_invoice_number` (`invoice_number`),
  KEY `dealership_idx` (`dealership_id`),
  KEY `stock_idx` (`stock_id`),
  KEY `status_idx` (`status`),
  KEY `buyer_identifier_idx` (`buyer_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
