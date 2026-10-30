Config = {}

Config.ItemName = 'id_card'
Config.DriverLicenseItem = 'driver_license'

-- Giv kun ID-kort ved join (ID-kortet inkluderer kørekort-kategorier fra user_licenses)
Config.AutoGiveOnJoin = true
Config.AutoGiveDriverLicenseItem = false

-- Alle nye/eksisterende spillere får disse licenser i user_licenses hvis de mangler
Config.StarterLicenses = {
    'drive' -- Personbil / kategori B
}

-- false = Kategori B vises kun hvis spilleren har 'drive' i user_licenses
Config.AutoGiveCategoryB = false

Config.ShowDistance = 3.0

Config.DefaultAddress = 'Tildelt et Herberg'
Config.Issuer = 'San Andreas DMV'
Config.ValidYears = 10

Config.Categories = {
    A = 'Motorcykel',
    B = 'Personbil',
    C = 'Større køretøj'
}

-- Mapping fra user_licenses.type til ID-kort kategori
Config.LicenseTypeToCategory = {
    drive_bike = 'A',
    drive_a = 'A',
    motorcycle = 'A',
    drive = 'B',
    drive_car = 'B',
    drive_b = 'B',
    drive_truck = 'C',
    drive_c = 'C'
}
