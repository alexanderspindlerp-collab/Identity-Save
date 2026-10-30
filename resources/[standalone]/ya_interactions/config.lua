Config = {}

Config.Key = 'F1'
--- true = hold F1 for at holde menuen åben, slip for at lukke
Config.HoldToOpen = true
--- Millisekunder F1 skal holdes før menuen åbner (undgår utilsigtet tap)
Config.HoldOpenMs = 150

Config.MenuItems = {
    -- GARAGE vises automatisk i roden når du står ved en garage (se client/main.lua).
    { id = 'job',    title = 'JOB',       desc = 'Dit arbejde',              icon = 'job' },
    { id = 'skills', title = 'SKILLTREE', desc = 'Udvikl dine færdigheder', icon = 'skills' },
}

Config.DefaultIndex = 0

Config.Events = {
    Job = '',
    Skills = ''
}

-- Vises som kort over menuen når man klikker SKILLTREE
Config.SkillCategories = {
    { id = 'criminal', title = 'KRIMINEL', desc = 'Narko, salg og underverdenen', enabled = true, color = '#fbbf24' },
    { id = 'garbage',  title = 'SKRALDEMAND', desc = 'Kommer snart', enabled = false, color = '#5eead4' },
    { id = 'civilian', title = 'CIVILT', desc = 'Kommer snart', enabled = false, color = '#a78bfa' },
}

Config.MDTJobs = {
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
