ALTER TABLE `ya_workshop_order_items`
  ADD COLUMN IF NOT EXISTS `group_key` VARCHAR(48) NULL AFTER `category_key`;

ALTER TABLE `ya_workshop_order_items`
  ADD COLUMN IF NOT EXISTS `line_type` VARCHAR(16) NOT NULL DEFAULT 'item' AFTER `item_key`;

ALTER TABLE `ya_workshop_order_items`
  ADD COLUMN IF NOT EXISTS `description` VARCHAR(255) NULL AFTER `label`;

ALTER TABLE `ya_workshop_order_items`
  ADD COLUMN IF NOT EXISTS `mod_data` LONGTEXT NULL AFTER `price`;
