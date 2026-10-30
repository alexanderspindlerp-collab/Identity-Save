-- Sørg for at licenstyper findes (esx_dmvschool / esx_license)
INSERT IGNORE INTO `licenses` (`type`, `label`) VALUES
    ('drive', 'Bil kørekort'),
    ('drive_bike', 'Motorcykel kørekort'),
    ('drive_truck', 'Lastbil kørekort');

-- Valgfrit: giv alle eksisterende spillere personbil-kørekort
-- INSERT IGNORE INTO user_licenses (type, owner)
-- SELECT 'drive', identifier FROM users;
