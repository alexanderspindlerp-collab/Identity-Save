Config = {}

-- Jobnavne der må åbne MDT'en. Tilføj flere hvis jeres jobs hedder noget andet.
Config.AllowedJobs = {
    police = true,
    politi = true,
    lspd = true,
    sheriff = true,
    ambulance = true,
    ems = true,
    mechanic = true,
    mekaniker = true,
    lawyer = true,
    advokat = true,
    judge = true,
    dommer = true
}

Config.PoliceJob = 'police'
Config.ReturnPermanentMinGrade = 7
Config.VehicleImpoundViewPermission = 'vehicles.impound.view'
Config.VehicleImpoundReleasePermission = 'vehicles.impound.release' -- legacy/fallback
Config.VehicleImpoundReleaseLockedPermission = 'vehicles.impound.locked.release'
Config.VehicleImpoundReleasePermanentPermission = 'vehicles.impound.permanent.release'
Config.DefaultImpound = 'LosSantos'
Config.MaxReturnPrice = 1000000

Config.DeleteIncidentMinGrade = 4
Config.IncidentPrefixLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'

-- Evidence locker / ox_inventory stash settings
Config.EvidenceLockerPermission = 'evidence.locker'
Config.EvidenceLockerMinGrade = 7
Config.EvidenceLockerSlots = 80
Config.EvidenceLockerWeight = 500000


-- Flådestyring: kun disse jobs sender live GPS til MDT.
Config.FleetPoliceJobs = {
    police = true,
    politi = true,
    lspd = true,
    sheriff = true
}

-- Hvis listen er tom/nil, godkendes alle klasse-18 emergency/politi køretøjer.
-- Tilføj modelnavne her hvis I kun vil godkende garage-køretøjer, fx police, police2, sheriff.

-- Ambulance/EMS fleet support: samme lille bilikon i MDT, men gul.
Config.FleetEMSJobs = {
    ambulance = true,
    ems = true,
    ["læge"] = true,
    laege = true
}

Config.FleetEMSVehicleModels = {
    ambulance = true,
    ems = true,
    firetruk = true
}

-- MDT/NUI blip farver
Config.FleetNativePoliceBlipColor = 3       -- blå
Config.FleetNativeEMSBlipColor = 5          -- gul
Config.FleetNativeEmergencyFlash = true     -- blip blinker/glower ved udrykning

Config.FleetPoliceVehicleModels = {
    police = true,
    police2 = true,
    police3 = true,
    police4 = true,
    policeold1 = true,
    policeold2 = true,
    policet = true,
    policeb = true,
    riot = true,
    riot2 = true,
    fbi = true,
    fbi2 = true,
    sheriff = true,
    sheriff2 = true,
    polmav = true
}

-- V80: sæt true hvis jeres custom police garage bruger køretøjer der ikke er GTA emergency class.
-- false = kun modeller på listen nedenfor + class 18 emergency.
Config.FleetAllowAnyPoliceVehicle = false

-- V81: scanner også serverens spawned police vehicles (kræver normalt OneSync) så køretøjer ude af garagen kan vises for alle.
Config.FleetServerScanVehicles = true

-- V83: true = hvis spilleren har politi-job, trackes bilen vedkommende sidder i, også custom modeller.
Config.FleetTrackAnyVehicleDrivenByPolice = false

-- V84: slå til midlertidigt hvis I vil se tracking i F8/server console.
Config.FleetDebug = false

-- Kun køretøjer der er taget ud via esx_garage og registreret som politi-køretøj kommer på MDT-kortet.
Config.FleetRequireGarageSpawn = false -- SAN: spawned police vehicles are allowed when model/class matches
Config.FleetGarageSpawnTTL = 28800 -- sekunder (8 timer)

-- Fleet V2 — native minimap-blips håndteres af povh. MDT-kortet viser kun emergency units.
Config.FleetNativeBlips = false
Config.FleetNativeBlipSprite = 56           -- politibil/køretøj ikon
Config.FleetNativeBlipColor = 3             -- blå
Config.FleetNativeBlipScale = 0.62
Config.FleetUnitTimeout = 900               -- sekunder før en inaktiv bil fjernes fra MDT
Config.FleetServerScanInterval = 750        -- ms, holder garage-spawnede biler aktive/smooth
Config.FleetClientPingInterval = 250        -- ms, sender præcis coords fra fører
Config.FleetCrossServiceView = true           -- politi kan trykke Se EMS / EMS kan trykke Se Politi i MDT


-- STEAM PRIMARY MODE
-- Serveren skal have i server.cfg:
--   set steam_webApiKey "DIN_STEAM_WEB_API_KEY"
--   setr esx:identifier "steam"
-- Slå RequireSteamIdentifier fra hvis ESX stadig bruger license (standard på denne server).
Config.MdtIdentifierType = 'steam'
Config.RequireSteamIdentifier = false
Config.SteamConnectAttempts = 50
Config.SteamConnectRetryMs = 100
Config.SteamMissingKickMessage = 'Du skal have Steam åbent før du starter FiveM for at joine denne server.'


-- SAN MDT V2 login/session
-- Efter en betjent går af arbejde, bliver MDT-sessionen lukket og kræver login igen.
-- Brugernavn kan være P-nummer (fx P-99), navn eller identifier. Kode kan ændres her.
Config.MDTRequireLogin = true
Config.MDTLoginCode = '1234'
Config.MDTLoginAllowName = true
Config.MDTLoginAllowPNumber = true

-- Bøder/fakturaer fra hændelser (esx_billing)
Config.FineSociety = 'society_police'
Config.FineRequireIdentifier = true

-- Licenser i MDT (user_licenses / esx_license)
Config.LicenseManagePermission = 'profiles.licenses.manage'
Config.MDTLicenseTypes = {
    { type = 'drive', label = 'Personbil (B)', category = 'B' },
    { type = 'drive_bike', label = 'Motorcykel (A)', category = 'A' },
    { type = 'drive_truck', label = 'Større køretøj (C)', category = 'C' },
}
Config.MDTHideLicenseTypes = { dmv = true }
Config.LicenseMaxActivePoints = 3
Config.LicenseAutoRevokeAtMaxPoints = true
Config.LicenseRevokeTypes = { 'drive', 'drive_bike', 'drive_truck' }
-- Karenstid før frakendt borger kan få kørekort igen (timer)
Config.LicenseRevocationCooldownHours = 48

-- NSK / bandeintelligens
Config.NskViewPermission = 'nsk.view'
Config.NskManagePermission = 'nsk.manage'
Config.NskGangViewPermission = 'profiles.gang.view'
Config.NskAutoRoles = { 'NSK Chef', 'NSK Afdeling', 'nsk_chef', 'nsk_afdeling' }
Config.NskAutoDivisions = { 'NSK' }

-- MDT-Logs: kun vigtige handlinger (aflytning, afskedigelser, sletninger osv.)
-- Sæt false for at logge alt som før (søgninger, rapport-oprettelse, login, patrulje osv.)
Config.MDTAuditImportantOnly = true

-- Dispatch V102: midlertidig test - politi kan også udløse skud/tyveri alarms til test. Sæt false senere.
Config.DispatchPoliceCanTriggerTest = true

-- Maks antal vidneudsagn der vises på et merged dispatch-opkald.
Config.DispatchMaxWitnessStatements = 5
