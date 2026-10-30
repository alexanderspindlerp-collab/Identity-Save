-- Kør én gang på eksisterende databaser (v1.8.0+)
ALTER TABLE `ya_workshop_orders`
  ADD COLUMN IF NOT EXISTS `target_vehicle_props` LONGTEXT NULL AFTER `vehicle_props`;
