CREATE TABLE IF NOT EXISTS `mdt_incident_invoices` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `incident_id` INT NOT NULL,
    `incident_no` VARCHAR(32) NOT NULL DEFAULT '',
    `identifier` VARCHAR(60) NOT NULL,
    `billing_id` INT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `label` VARCHAR(255) NOT NULL DEFAULT '',
    `issued_by` VARCHAR(80) NOT NULL DEFAULT '',
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_incident_person` (`incident_id`, `identifier`),
    KEY `incident_id_idx` (`incident_id`),
    KEY `identifier_idx` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
