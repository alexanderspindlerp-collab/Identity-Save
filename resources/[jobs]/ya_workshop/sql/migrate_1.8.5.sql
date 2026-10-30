ALTER TABLE `ya_workshop_order_items`
  ADD COLUMN IF NOT EXISTS `line_type` VARCHAR(16) NOT NULL DEFAULT 'item' AFTER `item_key`;
