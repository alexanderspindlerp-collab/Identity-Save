-- Mail-tråde: svar i samme samtale + Rigspolitiet kan lukke for svar
ALTER TABLE `mdt_mail` ADD COLUMN IF NOT EXISTS `thread_id` INT NULL;
ALTER TABLE `mdt_mail` ADD COLUMN IF NOT EXISTS `parent_id` INT NULL;
ALTER TABLE `mdt_mail` ADD COLUMN IF NOT EXISTS `sender_identifier` VARCHAR(80) NULL;
ALTER TABLE `mdt_mail` ADD COLUMN IF NOT EXISTS `reply_allowed` TINYINT(1) NOT NULL DEFAULT 1;

UPDATE `mdt_mail` SET `thread_id` = `id` WHERE `thread_id` IS NULL;

CREATE INDEX IF NOT EXISTS `idx_mdt_mail_thread` ON `mdt_mail` (`thread_id`);
CREATE INDEX IF NOT EXISTS `idx_mdt_mail_parent` ON `mdt_mail` (`parent_id`);
