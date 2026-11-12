Config = {}

Config.Debug = false

-- MDT integration
Config.MdtEvent = 'san_mdt:autoDispatchCall'

-- General
Config.RequireWitness = true
Config.MaxWitnesses = 5
Config.WitnessRadius = 65.0
Config.AssaultWitnessRadius = 45.0
Config.VehicleWitnessRadius = 55.0
Config.ShotWitnessRadius = 120.0
Config.LineOfSight = true

-- Chances after at least one valid NPC witness exists
Config.Chance = {
    weapon_seen = 18,       -- pistol/weapon held, low chance
    longgun_seen = 55,      -- rifle/shotgun/long gun held
    shots_fired = 100,      -- shots are serious
    assault = 100,          -- if player actually attacks/hits NPC
    vehicle_theft = 35,     -- parked NPC/civilian vehicle theft
    carjacking = 95,        -- NPC dragged/forced out
    explosion = 100,
    drug_sale = 100,
}

-- Cooldowns prevent spam. MDT can still merge too.
Config.Cooldown = {
    weapon_seen = 180000,       -- 3 min
    longgun_seen = 120000,
    shots_fired = 45000,
    assault = 60000,
    vehicle_theft = 90000,
    carjacking = 60000,
    explosion = 60000,
    drug_sale = 90000,
}

-- Area size for cooldown keys
Config.AreaGrid = 180.0

-- Scanning intervals
Config.Tick = {
    weapon = 2500,
    vehicle = 250,
    assault = 120,
    cleanup = 15000
}

-- Photo: OFF by default because screenshot-basic cannot take a true NPC-view photo without moving the player's camera.
-- MDT will show a clean 'Intet foto modtaget' placeholder.
Config.PhotoChance = 0

-- Commands for testing
Config.EnableTestCommands = true

-- Weapon groups considered long guns
Config.LongGunGroups = {
    [`GROUP_RIFLE`] = true,
    [`GROUP_MG`] = true,
    [`GROUP_SHOTGUN`] = true,
    [`GROUP_SNIPER`] = true
}

-- Ignore these weapons for weapon seen dispatch
Config.IgnoredWeapons = {
    [`WEAPON_UNARMED`] = true,
    [`WEAPON_FLASHLIGHT`] = true,
    [`WEAPON_PETROLCAN`] = true,
    [`WEAPON_FIREEXTINGUISHER`] = true
}
