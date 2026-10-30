Config = {}

Config.Framework = 'auto'

Config.AllowedJobs = {
    police = true,
    politi = true,
    lspd = true,
    sheriff = true,
}

Config.OpenCommand = 'radar'
Config.ToggleKey = 'F7'
Config.LockKey = 'NUMPAD5'
Config.ResetKey = 'NUMPAD6'

Config.UseKmh = true
Config.ScanInterval = 250
Config.AnpgInterval = 8000
Config.MaxScanAngle = 45.0
Config.MinScanDistance = 0.8
Config.RelaxedLineOfSight = true
Config.DefaultClass = 1

Config.VehicleClasses = {
    [1] = {
        range = 45.0,
        vehicles = {
            police = true, police2 = true, police3 = true, police4 = true,
            sheriff = true, sheriff2 = true, policet = true, policeb = true,
        }
    },
    [2] = {
        range = 65.0,
        vehicles = { police3 = true, police4 = true, sheriff2 = true, riot = true, fbi2 = true }
    },
    [3] = {
        range = 90.0,
        vehicles = { fbi = true, fbi2 = true, polmav = true }
    }
}
