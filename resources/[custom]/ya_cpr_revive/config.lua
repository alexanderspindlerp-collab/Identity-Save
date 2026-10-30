Config = {}

-- Antal CPR-forsøg pr. død person (nulstilles ved ny død / succesfuld genoplivning)
Config.MaxAttempts = 5

-- Varighed af ét CPR-forsøg (millisekunder)
Config.CprDuration = 9000

-- Maks afstand til target (meter)
Config.MaxDistance = 2.5

-- CPR-animation (samme som esx_ambulancejob)
Config.Anim = {
    dict = 'mini@cpr@char_a@cpr_str',
    clip = 'cpr_pumpchest',
    flag = 1
}

-- Chance for succes pr. forsøg (1-100). Sidste forsøg kan gøres garanteret nedenfor.
Config.SuccessChance = 25

-- Sidste forsøg (#5) genopliver altid hvis de fire første fejler
Config.GuaranteedOnLastAttempt = true

-- Tilladte jobs (nil = alle spillere). Eksempel: { 'ambulance', 'police' }
Config.AllowedJobs = nil

-- Bloker CPR hvis der er ambulance på job (valgfrit)
Config.BlockWhenAmbulanceOnDuty = false
Config.AmbulanceJobs = { 'ambulance' }
