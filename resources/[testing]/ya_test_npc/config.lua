Config = {}

Config.Command = 'testnpc'
Config.DeleteCommand = 'delselvnpc'

--- Freemode = ligner en rigtig spiller. BRUG IKKE politi-ped-modeller —
--- mange servere blokerer dem (anti-cheat / entity filter).
Config.DefaultModel = 'mp_m_freemode_01'

--- Modeller der afvises ved spawn (politi / SWAT / ambulance osv.)
Config.BlockedModels = {
    's_m_y_cop_01',
    's_f_y_cop_01',
    's_m_y_sheriff_01',
    's_f_y_sheriff_01',
    's_m_y_swat_01',
    's_m_m_paramedic_01',
    's_m_m_security_01',
    'csb_cop',
    'ig_bankman',
}

--- Tilladte alternativer: /testnpc mp_f_freemode_01
Config.AllowedModels = {
    'mp_m_freemode_01',
    'mp_f_freemode_01',
    'a_m_y_hipster_01',
    'a_f_y_hipster_01',
    'a_m_m_business_01',
    'a_f_m_business_02',
}

--- Vist navn ved ID-kort / visitér (test)
Config.FakeName = 'Test Borger'
Config.FakeJob = 'Arbejdsløs'

--- Normal borger — kan gå rundt, ragdoll, tages i håndjern osv.
Config.Invincible = false
Config.Freeze = false
Config.BlockAmbientEvents = false
Config.Wander = false

--- Job-navne der må bruge test-interaktioner (tilpas til jeres server)
Config.PoliceJobs = { 'police', 'politi', 'lspd', 'sheriff' }

--- Sæt true = alle kan se politi-menu på test-NPC (godt til test)
Config.AllowAnyoneForTesting = true

--- Vis /testnpcinfo for at tjekke om du kigger på rigtige NPC
Config.DebugCommand = 'testnpcinfo'

--- Standard GSR på test-NPC ved spawn (true = positiv, false = negativ)
Config.DefaultTestGsr = false

--- /testnpcgsr — skift mellem positiv/negativ GSR på test-borgeren
Config.GsrToggleCommand = 'testnpcgsr'

--- Test til alkohol/drog (positiv/negativ)
Config.DefaultTestDrunk = false
Config.DefaultTestDrugs = false
Config.DrunkToggleCommand = 'testnpcdrunk'
Config.DrugToggleCommand = 'testnpcdrugs'

--- Timings (matcher ya_police_interactions)
Config.Timings = {
    SeatbeltMs = 2000,
    GsrTestMs = 15000,
    AlcoholTestMs = 8000,
    DrugTestMs = 10000,
    DnaSampleMs = 12000,
    FingerprintHoldMs = 10000,
    FingerprintPads = 3,
}

--- Vis blip på test-NPC i X sekunder (0 = slået fra)
Config.ShowBlipSeconds = 45

--- Respawn hvis OneSync sletter ped'en
Config.AutoRespawn = true

--- Udseende (freemode komponenter) — kan udvides
Config.Outfit = {
    male = {
        { component = 3, drawable = 0, texture = 0 },
        { component = 4, drawable = 1, texture = 0 },
        { component = 6, drawable = 1, texture = 0 },
        { component = 8, drawable = 15, texture = 0 },
        { component = 11, drawable = 5, texture = 2 },
    },
    female = {
        { component = 3, drawable = 0, texture = 0 },
        { component = 4, drawable = 0, texture = 0 },
        { component = 6, drawable = 1, texture = 0 },
        { component = 8, drawable = 15, texture = 0 },
        { component = 11, drawable = 15, texture = 0 },
    },
}
