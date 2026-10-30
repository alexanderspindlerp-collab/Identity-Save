Config = {}

Config.PoliceJobs = { 'police', 'politi', 'lspd', 'sheriff' }

Config.Timings = {
    SeatbeltMs = 2000,
    GsrTestMs = 15000,
    AlcoholTestMs = 8000,
    DrugTestMs = 10000,
    DnaSampleMs = 12000,
    FingerprintHoldMs = 10000,
    FingerprintPads = 3,
}

--- Narkotest — stoffer i blodet (realtime timer)
Config.BloodDrugHours = 48
Config.BloodDrugs = {
    kokain = 'Kokain',
    hash = 'Hash',
    skunk = 'Skunk',
}

--- Rus-effekt varighed efter brug (ms)
Config.HighDurationMs = {
    kokain = 180000,
    hash = 240000,
    skunk = 240000,
}

--- Alkohol — promille vises som val / DrunkPromilleScale (0.50‰ ≈ grænse)
Config.DrunkPromilleScale = 500000
Config.DrunkLegalPromille = 0.50

--- Props
Config.Props = {
    HardCuffs = `p_cs_cuffs_02_s`,
    SoftCuffs = `p_cs_cuffs_02_s`,
    Breathalyzer = `prop_cs_breathalyser_01`,
    DrugTest = `prop_syringe_01`,
    DnaSwab = `prop_cs_swab_01`,
}

--- Håndjern-stile: blød foran, hård bagved, blød bagved
Config.CuffStyles = {
    soft_front = {
        label = 'Håndjern foran [Blød]',
        copAnim = { dict = 'mp_arresting', clip = 'a_uncuff', duration = 2800 },
        suspectAnim = { dict = 'mp_arresting', clip = 'idle', duration = 2800 },
        idle = { dict = 'anim@move_m@prisoner_cuffed', clip = 'idle', flag = 49 },
        prop = {
            model = `p_cs_cuffs_02_s`,
            bone = 60309,
            offset = vec3(0.05, 0.08, 0.02),
            rotation = vec3(10.0, 95.0, 20.0),
        },
    },
    hard_back = {
        label = 'Håndjern bagved [Hård]',
        copAnim = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_left', duration = 3500 },
        suspectAnim = { dict = 'mp_arrest_paired', clip = 'crook_p2_back_left', duration = 3500 },
        idle = { dict = 'mp_arresting', clip = 'idle', flag = 49 },
        prop = {
            model = `p_cs_cuffs_02_s`,
            bone = 24818,
            offset = vec3(0.0, 0.07, 0.03),
            rotation = vec3(0.0, 0.0, 0.0),
        },
    },
    soft_back = {
        label = 'Håndjern bagved [Blød]',
        copAnim = { dict = 'mp_arresting', clip = 'a_uncuff', duration = 2800 },
        suspectAnim = { dict = 'mp_arresting', clip = 'idle', duration = 2800 },
        idle = { dict = 'anim@move_m@prisoner_cuffed', clip = 'idle', flag = 49 },
        prop = {
            model = `p_cs_cuffs_02_s`,
            bone = 24818,
            offset = vec3(0.0, 0.07, 0.03),
            rotation = vec3(0.0, 0.0, 0.0),
        },
    },
}

--- Animationer
Config.Anims = {
    EscortCop = { dict = 'amb@code_human_wander_drinking@male@base', clip = 'static', flag = 49 },
    PutInVehicle = { dict = 'mp_common', clip = 'givetake1_a', duration = 2000 },
    OutVehicle = { dict = 'mp_common', clip = 'givetake2_a', duration = 2000 },
    GsrTest = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 49 },
    AlcoholTest = { dict = 'amb@world_human_stand_mobile@male@text@base', clip = 'base', flag = 49 },
    DrugTest = { dict = 'amb@medic@standing@timeofdeath@base', clip = 'base', flag = 49 },
    DnaSample = { dict = 'amb@medic@standing@kneel@base', clip = 'base', flag = 49 },
}

--- Alkoholgrænse (esx_status drunk val) — bruges som fallback
Config.DrunkThreshold = 250000

--- Fængsel (Bolingbroke)
Config.Jail = {
    Location = vector4(1691.86, 2565.68, 45.56, 270.0),
    Release = vector4(1847.9, 2586.2, 45.67, 270.0),
    MaxMinutes = 120,
}
