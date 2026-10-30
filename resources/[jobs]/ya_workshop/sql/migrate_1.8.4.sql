ALTER TABLE `ya_workshop_company_shops`
  ADD COLUMN IF NOT EXISTS `blip_sprite` INT NULL DEFAULT 72 AFTER `shop_key`;

ALTER TABLE `ya_workshop_company_shops`
  ADD COLUMN IF NOT EXISTS `blip_color` INT NOT NULL DEFAULT 3 AFTER `blip_sprite`;

ALTER TABLE `ya_workshop_company_shops`
  ADD COLUMN IF NOT EXISTS `blip_scale` DOUBLE NOT NULL DEFAULT 0.85 AFTER `blip_color`;

ALTER TABLE `ya_workshop_company_shops`
  ADD COLUMN IF NOT EXISTS `blip_enabled` TINYINT(1) NOT NULL DEFAULT 1 AFTER `blip_scale`;
