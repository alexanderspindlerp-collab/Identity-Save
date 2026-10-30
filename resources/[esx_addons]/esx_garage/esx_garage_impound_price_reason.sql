-- Importér denne SQL i din ESX database.
-- Tilføjer felter til pris, årsag, betjent og tidspunkt for beslaglæggelse.

ALTER TABLE `owned_vehicles`
  ADD COLUMN IF NOT EXISTS `impound_price` INT NOT NULL DEFAULT 0 AFTER `pound`,
  ADD COLUMN IF NOT EXISTS `impound_type` VARCHAR(32) NOT NULL DEFAULT 'normal' AFTER `impound_price`,
  ADD COLUMN IF NOT EXISTS `impound_locked` TINYINT(1) NOT NULL DEFAULT 0 AFTER `impound_type`,
  ADD COLUMN IF NOT EXISTS `impound_reason` TEXT NULL AFTER `impound_price`,
  ADD COLUMN IF NOT EXISTS `impound_officer` VARCHAR(128) NULL AFTER `impound_reason`,
  ADD COLUMN IF NOT EXISTS `impound_time` INT NULL AFTER `impound_officer`;
