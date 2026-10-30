CREATE TABLE IF NOT EXISTS `iddrugnsale_farms` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(64) NOT NULL DEFAULT 'Farm',
    `drug_key` VARCHAR(32) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `amount_min` INT NOT NULL DEFAULT 1,
    `amount_max` INT NOT NULL DEFAULT 3,
    `cooldown` INT NOT NULL DEFAULT 45,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `give_raw` TINYINT(1) NOT NULL DEFAULT 1,
    `show_marker` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `iddrugnsale_process` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(64) NOT NULL DEFAULT 'Omdan',
    `drug_key` VARCHAR(32) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `input_amount` INT NOT NULL DEFAULT 3,
    `output_amount` INT NOT NULL DEFAULT 1,
    `duration` INT NOT NULL DEFAULT 9000,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    `show_marker` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `iddrugnsale_dealers` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `label` VARCHAR(64) NOT NULL DEFAULT 'Dealer',
    `model` VARCHAR(64) NOT NULL DEFAULT 'a_m_y_stwhi_02',
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `heading` DOUBLE NOT NULL DEFAULT 0,
    `enabled` TINYINT(1) NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `iddrugnsale_prices` (
    `drug_key` VARCHAR(32) NOT NULL,
    `base_price` INT NOT NULL DEFAULT 500,
    `min_percent` INT NOT NULL DEFAULT 70,
    `max_percent` INT NOT NULL DEFAULT 130,
    PRIMARY KEY (`drug_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `iddrugnsale_prices` (`drug_key`, `base_price`, `min_percent`, `max_percent`) VALUES
    ('hash', 420, 70, 130),
    ('skunk', 480, 70, 130),
    ('kokain', 650, 70, 140);

CREATE TABLE IF NOT EXISTS `iddrugnsale_bag_prices` (
    `drug_key` VARCHAR(32) NOT NULL,
    `grams` TINYINT NOT NULL,
    `min_price` INT NOT NULL DEFAULT 300,
    `base_price` INT NOT NULL DEFAULT 500,
    `max_price` INT NOT NULL DEFAULT 650,
    PRIMARY KEY (`drug_key`, `grams`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `iddrugnsale_settings` (
    `key` VARCHAR(64) NOT NULL,
    `value` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `iddrugnsale_settings` (`key`, `value`) VALUES
    ('max_npc_buy', '5');
