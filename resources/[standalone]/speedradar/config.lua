Config = {}

-- Item / command
Config.Command = 'speedradar'
Config.DisableInVehicle = true
Config.ItemName = 'fartkontrol_udstyr'
Config.ReturnItemOnPackup = true

-- Equipment placement
Config.EquipmentModel = `prop_radarpistol` -- skift denne hvis jeres prop har andet spawn/modelnavn
Config.PlaceDistance = 1.45
Config.PlaceZOffset = 0.0
-- 0.0 = stativet vender samme vej som spilleren, når det bliver sat.
Config.PlaceHeadingOffset = 0.0
Config.TargetDistance = 2.0
Config.UseOxTarget = true
Config.OneEquipmentPerPlayer = true
Config.FreezeEquipment = true

-- Radar behaviour
Config.MaxDistance = 300.0
Config.ScanInterval = 75 -- ms while scope is active
Config.IdleInterval = 250
Config.ManualSaveCooldown = 350 -- ms anti-spam ved venstreklik
Config.MaxHistory = 8
Config.MinSpeedToSave = 1 -- km/t

-- Scope / camera. Kameraet starter fra stativet, ikke spilleren.
Config.DefaultFov = 45.0
Config.MinFov = 12.0
Config.MaxFov = 55.0
Config.ZoomStep = 3.0
-- Kamera-position på stativet. Ret kun disse hvis prop-modellen har en anden størrelse.
-- X = side, Y = frem/tilbage ift. proppen, Z = højde.
Config.CameraSideOffset = 0.0
Config.CameraForwardOffset = -0.18
Config.CameraHeight = 1.02
Config.CameraHeadingOffset = 0.0 -- 180.0 hvis kameraet peger bagud
Config.ScopeMouseSensitivity = 4.8
Config.MaxPitchUp = 25.0
Config.MaxPitchDown = -25.0

-- Controls
Config.AimControl = 25      -- Right mouse / aim
Config.MeasureControl = 24  -- Left mouse, manual save while aiming
Config.ZoomInControl = 241  -- Scroll up
Config.ZoomOutControl = 242 -- Scroll down
Config.ExitControl = 177    -- Backspace
Config.ExitControlAlt = 322 -- ESC

-- Optional police only
Config.PoliceOnly = false
Config.PoliceJobs = {
    police = true,
    politi = true,
    lspd = true,
    sheriff = true,
}

-- Printout item
Config.PrintItemName = 'fartkontrol_udskrift'
Config.MaxPrintReadings = 12
