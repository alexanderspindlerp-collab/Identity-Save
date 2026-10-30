Config = {}

Config.AdminGroups = { 'admin', 'superadmin', 'owner' }

Config.Currency = 'DKK'
Config.VatRate = 0.25
Config.CompanyCvr = '12345678'

Config.Company = {
    MinNameLength = 3,
    MaxNameLength = 48,
    MaxMembers = 40,
    DefaultColor = '#14b8a6',
    StartingBalance = 0,
}

--- Kunde-zone ved værksted (box med ekstra højde til lager/haller)
Config.ShopZone = {
    DefaultRadius = 22.0,
    Height = 16.0,
}

--- Udvalgte GTA blip-navne (resten vises som "Blip #ID" i admin-vælgeren)
Config.BlipSprites = {
    { id = 1, label = 'Cirkel' },
    { id = 8, label = 'Waypoint' },
    { id = 50, label = 'Garage' },
    { id = 72, label = 'Mekaniker / Garage' },
    { id = 73, label = 'Tøjbutik' },
    { id = 76, label = 'Våbenbutik' },
    { id = 93, label = 'Helikopter' },
    { id = 106, label = 'Bilforhandler' },
    { id = 110, label = 'Benzin' },
    { id = 119, label = 'Barber' },
    { id = 120, label = 'Tattoo' },
    { id = 225, label = "Benny's / Tuning" },
    { id = 266, label = 'Impound' },
    { id = 289, label = 'Bilvask' },
    { id = 318, label = 'Hangar' },
    { id = 357, label = 'Båd' },
    { id = 402, label = 'Bil' },
    { id = 408, label = 'Lastbil' },
    { id = 446, label = 'Tuning' },
    { id = 473, label = 'Motorcykel' },
    { id = 524, label = 'Værksted' },
    { id = 544, label = 'Racerbil' },
    { id = 595, label = 'Politi garage' },
    { id = 643, label = 'Levering' },
    { id = 665, label = 'Cargo' },
    { id = 724, label = 'Auto shop' },
    { id = 777, label = 'Tunervej' },
}

Config.BlipColors = {
    { id = 0, label = 'Hvid' },
    { id = 1, label = 'Rød' },
    { id = 2, label = 'Grøn' },
    { id = 3, label = 'Blå' },
    { id = 5, label = 'Gul' },
    { id = 17, label = 'Orange' },
    { id = 27, label = 'Lilla' },
    { id = 46, label = 'Guld' },
    { id = 52, label = 'Cyan' },
}

Config.DefaultRoles = {
    {
        key = 'owner',
        name = 'Ejer',
        isDefault = false,
        sortOrder = 1,
        permissions = {},
    },
    {
        key = 'manager',
        name = 'Manager',
        isDefault = false,
        sortOrder = 2,
        permissions = {
            view_dashboard = true,
            manage_orders = true,
            manage_members = true,
            manage_roles = true,
            manage_prices = true,
            send_invoices = true,
            view_calls = true,
            accept_calls = true,
            repair_vehicles = true,
        },
    },
    {
        key = 'mechanic',
        name = 'Mekaniker',
        isDefault = true,
        sortOrder = 3,
        permissions = {
            view_dashboard = true,
            manage_orders = true,
            manage_prices = true,
            view_calls = true,
            accept_calls = true,
            repair_vehicles = true,
        },
    },
}

Config.PermissionsCatalog = {
    { key = 'view_dashboard', label = 'Se overblik' },
    { key = 'manage_orders', label = 'Håndter bestillinger' },
    { key = 'manage_members', label = 'Administrer medarbejdere' },
    { key = 'manage_roles', label = 'Administrer roller' },
    { key = 'manage_prices', label = 'Rediger prisliste' },
    { key = 'send_invoices', label = 'Send fakturaer' },
    { key = 'view_calls', label = 'Se opkald' },
    { key = 'accept_calls', label = 'Tag opkald' },
    { key = 'repair_vehicles', label = 'Reparer køretøjer' },
}

--- Fysiske butikker på kortet. Hver butik = egen zone med [E] prompt.
--- Et firma kan eje flere butikker (admin-tablet). Hver butik kan kun tilhøre ét firma.
--- Position (X/Y/Z + radius) sættes i admin-tablet under firmaet — config er kun standard/fallback.
--- Tilføj flere Benny's / LS Customs ved at kopiere en entry her.
Config.Shops = {
    bennys = {
        key = 'bennys',
        label = "Los Santos Benny's",
        subtitle = 'Original — La Mesa',
        companyType = 'bennys',
        pos = vector3(-205.57, -1308.85, 31.29),
        radius = 18.0,
        blip = { sprite = 72, color = 3, scale = 0.85 },
    },
    -- Eksempel: anden Benny's (MLO / anden lokation). Fjern kommentar og sæt dine coords.
    -- bennys_burton = {
    --     key = 'bennys_burton',
    --     label = "Benny's Burton",
    --     subtitle = 'Anden Benny\'s lokation',
    --     companyType = 'bennys',
    --     pos = vector3(-515.0, -220.0, 35.0),
    --     radius = 18.0,
    --     blip = { sprite = 72, color = 3, scale = 0.85 },
    -- },
    lscustom_ls = {
        key = 'lscustom_ls',
        label = 'LS Customs',
        subtitle = 'Tuning & styling',
        companyType = 'lscustom',
        pos = vector3(-337.38, -136.92, 38.57),
        radius = 20.0,
        blip = { sprite = 72, color = 5, scale = 0.85 },
    },
    lscustom_harmony = {
        key = 'lscustom_harmony',
        label = 'LS Customs Harmony',
        subtitle = 'Tuning & styling',
        companyType = 'lscustom',
        pos = vector3(1175.04, 2640.21, 37.32),
        radius = 18.0,
        blip = nil,
    },
}

--- Hovedkategorier (venstre menu) → grupper (bund-navbar) → valg (efter lås op)
Config.Categories = {
    {
        key = 'customization',
        label = 'Tilpasning',
        desc = 'Personliggør dit køretøj',
        icon = 'car',
        image = 'img/categories/customization.svg',
        groups = {
            {
                key = 'paint',
                label = 'Farve',
                desc = 'Primær & sekundær lak',
                openPrice = 4500,
                icon = 'paint_primary',
                image = 'img/groups/paint.svg',
                items = {
                    { key = 'paint_primary', label = 'Primær lak', desc = 'Ny primær farve', price = 4500 },
                    { key = 'paint_secondary', label = 'Sekundær lak', desc = 'Ny sekundær farve', price = 3200 },
                },
            },
            {
                key = 'livery',
                label = 'Livery',
                desc = 'Dekor & wrap',
                openPrice = 6381,
                icon = 'livery',
                image = 'img/groups/livery.svg',
                items = {
                    { key = 'livery', label = 'Livery', desc = 'Dekor / wrap', price = 6381 },
                },
            },
            {
                key = 'pynt',
                label = 'Pynt',
                desc = 'Interiørdetalje',
                openPrice = 6381,
                icon = 'interior_trim',
                image = 'img/groups/pynt.svg',
                items = {
                    { key = 'interior_trim', label = 'Interiør', desc = 'Indvendige detaljer', price = 6381 },
                    { key = 'dashboard', label = 'Dashboard', desc = 'Dashboard styling', price = 3800 },
                    { key = 'fuzzy_dice', label = 'Terninger', desc = 'Klassisk pynt', price = 2200 },
                },
            },
            {
                key = 'brakes',
                label = 'Bremser',
                desc = 'Bedre bremseevne',
                openPrice = 0,
                icon = 'brakes',
                image = 'img/groups/brakes.svg',
                items = {
                    { key = 'brakes', label = 'Bremser', desc = 'Opgraderede bremser', price = 0 },
                },
            },
            {
                key = 'roll_cage',
                label = 'Sikkerhedsbur',
                desc = 'Ekstra sikkerhed',
                openPrice = 6381,
                icon = 'roll_cage',
                image = 'img/groups/roll_cage.svg',
                items = {
                    { key = 'roll_cage', label = 'Sikkerhedsbur', desc = 'Racing bur', price = 6381 },
                },
            },
            {
                key = 'antenna',
                label = 'Antenne',
                desc = 'Signal & look',
                openPrice = 6381,
                icon = 'antenna',
                image = 'img/groups/antenna.svg',
                items = {
                    { key = 'antenna', label = 'Antenne', desc = 'Ekstra antenne', price = 6381 },
                },
            },
            {
                key = 'windows',
                label = 'Ruder',
                desc = 'Tonning og glas',
                openPrice = 3399,
                icon = 'window_tint',
                image = 'img/groups/windows.svg',
                items = {
                    { key = 'window_tint', label = 'Rude-toning', desc = 'Tonerede ruder', price = 3399 },
                    { key = 'window_trim', label = 'Rude-liste', desc = 'Chrome / sort liste', price = 2800 },
                },
            },
            {
                key = 'side_skirts',
                label = 'Sideskørter',
                desc = 'Lavere sideskørter',
                openPrice = 6381,
                icon = 'side_skirts',
                image = 'img/groups/side_skirts.svg',
                items = {
                    { key = 'side_skirts', label = 'Sideskørter', desc = 'Sport sideskørter', price = 6381 },
                },
            },
            {
                key = 'spoiler',
                label = 'Spoiler',
                desc = 'Bagspoiler',
                openPrice = 4200,
                icon = 'spoiler',
                image = 'img/groups/spoiler.svg',
                items = {
                    { key = 'spoiler', label = 'Spoiler', desc = 'Bagspoiler', price = 4200 },
                },
            },
            {
                key = 'hood',
                label = 'Motorhjelm',
                desc = 'Carbon / custom hood',
                openPrice = 5200,
                icon = 'hood',
                image = 'img/groups/hood.svg',
                items = {
                    { key = 'hood', label = 'Motorhjelm', desc = 'Carbon motorhjelm', price = 5200 },
                },
            },
            {
                key = 'trunk',
                label = 'Bagklap',
                desc = 'Deck lid — muscle & lowrider',
                openPrice = 4800,
                icon = 'spoiler',
                image = 'img/groups/spoiler.svg',
                alwaysShow = true,
                items = {
                    { key = 'trunk', label = 'Bagklap', desc = 'Anden bagklap (som GTA Online)', price = 4800 },
                },
            },
            {
                key = 'roof',
                label = 'Tag',
                desc = 'Tag / roof mods',
                openPrice = 4500,
                icon = 'hood',
                image = 'img/groups/hood.svg',
                items = {
                    { key = 'roof', label = 'Tag', desc = 'Tag-variant', price = 4500 },
                },
            },
            {
                key = 'grille',
                label = 'Grill',
                desc = 'Frontgrill',
                openPrice = 3800,
                icon = 'hood',
                image = 'img/groups/hood.svg',
                items = {
                    { key = 'grille', label = 'Grill', desc = 'Grill-variant', price = 3800 },
                },
            },
            {
                key = 'exhaust',
                label = 'Udstødning',
                desc = 'Udstødningsrør',
                openPrice = 4200,
                icon = 'spoiler',
                image = 'img/groups/spoiler.svg',
                items = {
                    { key = 'exhaust', label = 'Udstødning', desc = 'Udstødnings-variant', price = 4200 },
                },
            },
        },
    },
    {
        key = 'stance',
        label = 'Stance',
        desc = 'Hjuljustering og stance',
        icon = 'wheel',
        image = 'img/categories/stance.svg',
        groups = {
            {
                key = 'wheels',
                label = 'Fælge',
                desc = 'Nye fælge',
                openPrice = 8500,
                icon = 'wheels',
                image = 'img/groups/wheels.svg',
                items = {
                    { key = 'wheels', label = 'Fælge', desc = 'Nye fælge', price = 8500 },
                },
            },
            {
                key = 'suspension',
                label = 'Affjedring',
                desc = 'Sænkning / lift',
                openPrice = 5500,
                icon = 'suspension',
                image = 'img/groups/suspension.svg',
                items = {
                    { key = 'suspension', label = 'Affjedring', desc = 'Sænkning / lift', price = 5500 },
                },
            },
            {
                key = 'wheel_offset',
                label = 'Hjul-offset',
                desc = 'Stance justering',
                openPrice = 4200,
                icon = 'wheel_offset',
                image = 'img/groups/wheel_offset.svg',
                items = {
                    { key = 'wheel_offset', label = 'Hjul-offset', desc = 'Stance justering', price = 4200 },
                },
            },
        },
    },
    {
        key = 'performance',
        label = 'Performance',
        desc = 'Motor, gear og turbo',
        icon = 'performance',
        image = 'img/categories/performance.svg',
        groups = {
            {
                key = 'engine',
                label = 'Motor',
                desc = 'Motoropgradering',
                openPrice = 12500,
                icon = 'engine',
                image = 'img/groups/engine.svg',
                items = {
                    { key = 'engine', label = 'Motor', desc = 'Motoropgradering', price = 12500 },
                },
            },
            {
                key = 'transmission',
                label = 'Gearkasse',
                desc = 'Hurtigere skift',
                openPrice = 9800,
                icon = 'transmission',
                image = 'img/groups/transmission.svg',
                items = {
                    { key = 'transmission', label = 'Gearkasse', desc = 'Hurtigere skift', price = 9800 },
                },
            },
            {
                key = 'turbo',
                label = 'Turbo',
                desc = 'Turbolader',
                openPrice = 15000,
                icon = 'turbo',
                image = 'img/groups/turbo.svg',
                items = {
                    { key = 'turbo', label = 'Turbo', desc = 'Turbolader', price = 15000 },
                },
            },
        },
    },
    {
        key = 'ekstra',
        label = 'Ekstra',
        desc = 'Tilbehør på denne bil',
        icon = 'extra',
        image = 'img/categories/customization.svg',
        groups = {
            {
                key = 'vehicle_extras',
                label = 'Udstyr',
                desc = 'Ekstra dele (lygtebar, bullbar osv.)',
                openPrice = 0,
                icon = 'antenna',
                image = 'img/groups/antenna.svg',
                items = {
                    { key = 'vehicle_extras', label = 'Ekstra udstyr', desc = 'Til/fra på bilen', price = 2500 },
                },
            },
        },
    },
}

--- Politi AutoShop (gratis · kun farve, toning & politi-ekstra)
Config.Police = {
    Jobs = { 'police', 'politi', 'lspd', 'sheriff' },
    --- Ekstra-ID'er der kun vises i politi-AutoShop og kun er synlige for betjente
    OnlyExtraIds = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 },
    ExtraLabels = {
        default = {
            ['1'] = 'Markering 1',
            ['2'] = 'Markering 2',
            ['3'] = 'Markering 3',
            ['4'] = 'Markering 4',
            ['5'] = 'Markering 5',
            ['6'] = 'Lygtebar / blink',
            ['7'] = 'Front-udstyr',
            ['8'] = 'Bullbar',
            ['9'] = 'Tag-udstyr',
            ['10'] = 'Civil markering',
            ['11'] = 'Ekstra udstyr 11',
            ['12'] = 'Ekstra udstyr 12',
        },
    },
}

Config.PoliceCategories = {
    {
        key = 'customization',
        label = 'Tilpasning',
        desc = 'Farve & toning',
        icon = 'car',
        image = 'img/categories/customization.svg',
        groups = {
            {
                key = 'paint',
                label = 'Farve',
                desc = 'Primær & sekundær lak',
                openPrice = 0,
                icon = 'paint_primary',
                image = 'img/groups/paint.svg',
                items = {
                    { key = 'paint_primary', label = 'Primær lak', desc = 'Ny primær farve', price = 0 },
                    { key = 'paint_secondary', label = 'Sekundær lak', desc = 'Ny sekundær farve', price = 0 },
                },
            },
            {
                key = 'windows',
                label = 'Ruder',
                desc = 'Tonning',
                openPrice = 0,
                icon = 'window_tint',
                image = 'img/groups/windows.svg',
                items = {
                    { key = 'window_tint', label = 'Rude-toning', desc = 'Tonerede ruder', price = 0 },
                },
            },
        },
    },
    {
        key = 'ekstra',
        label = 'Politi-udstyr',
        desc = 'Kun synligt for betjente',
        icon = 'car',
        image = 'img/categories/customization.svg',
        groups = {
            {
                key = 'vehicle_extras',
                label = 'Ekstra udstyr',
                desc = 'Lygter, markering m.m.',
                openPrice = 0,
                icon = 'vehicle_extras',
                image = 'img/groups/antenna.svg',
                items = {
                    { key = 'vehicle_extras', label = 'Politi-ekstra', desc = 'Til/fra udstyr', price = 0 },
                },
            },
        },
    },
}

--- Menu-katalog per branding. Hvert firma arver sit brands menu og egne priser.
Config.CategoriesByType = {
    bennys = Config.Categories,
    lscustom = Config.Categories,
    police = Config.PoliceCategories,
}

Config.OrderStatuses = {
    pending = 'Afventer',
    in_progress = 'I gang',
    completed = 'Færdig',
    cancelled = 'Annulleret',
}

Config.CallStatuses = {
    open = 'Åben',
    accepted = 'Taget',
    closed = 'Lukket',
}

--- Reparation: /repair når ingen mekanikere er online · ox_target + dele-UI når på arbejde
Config.Repair = {
    SelfRepair = {
        Command = 'repair',
        Price = 20000,
        PriceDisplay = '19.999,99',
        Duration = 60000,
    },
    Mechanic = {
        TargetDistance = 6.0,
        MaxParts = 5,
        MinDuration = 12000,
        MaxDuration = 90000,
        MsPerPart = 4000,
        Anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_player',
            flag = 49,
        },
    },
    --- ox_inventory item-navne → zoner på bilen (træk & slip)
    Items = {
        {
            name = 'fixtool',
            label = 'Reparationsværktøj',
            desc = 'Motor & småskader',
            zones = { 'engine', 'body' },
            power = 28,
            icon = 'wrench',
        },
        {
            name = 'fixkit',
            label = 'Repair Kit',
            desc = 'Motor og karoseri',
            zones = { 'engine', 'body' },
            power = 55,
            icon = 'toolbox',
        },
        {
            name = 'advancedrepairkit',
            label = 'Advanced Repair Kit',
            desc = 'Omfattende reparation',
            zones = { 'engine', 'body', 'wheels', 'tank', 'universal' },
            power = 100,
            icon = 'toolbox',
        },
        {
            name = 'carotool',
            label = 'Karosseriværktøj',
            desc = 'Pladedele og karoseri',
            zones = { 'body' },
            power = 30,
            icon = 'body',
        },
        {
            name = 'carokit',
            label = 'Body Kit',
            desc = 'Karoseri & paneler',
            zones = { 'body' },
            power = 65,
            icon = 'body',
        },
        {
            name = 'gazbottle',
            label = 'Gasflaske',
            desc = 'Tank & brændstofsystem',
            zones = { 'tank' },
            power = 80,
            icon = 'tank',
        },
        {
            name = 'tyre_repair_kit',
            label = 'Dæk-reparationssæt',
            desc = 'Punkterede dæk',
            zones = { 'wheels' },
            power = 90,
            icon = 'wheel',
        },
    },
    ZoneLabels = {
        engine = 'Motor',
        body = 'Karoseri',
        wheels = 'Hjul',
        tank = 'Tank',
        universal = 'Hel bil',
    },
    --- 3D-ankre på køretøjet (offset fra center · eller bone-navn)
    ZoneAnchors = {
        engine = { x = 0.0, y = 1.35, z = 0.5 },
        body = { x = 0.0, y = 0.0, z = 1.0 },
        windows = { x = 0.0, y = 0.55, z = 0.7 },
        tank = { x = 0.0, y = -1.45, z = 0.45 },
        wheels = { bone = 'wheel_lr' },
        universal = { x = -1.0, y = 0.0, z = 0.4 },
    },
    WalkAroundDistance = 8.0,
}

--- Mekaniker boost: progressbar + emote (varighed skalerer med antal dele)
Config.Boost = {
    MinDuration = 30000,
    MaxDuration = 45000,
    MsPerItem = 3000,
    MaxDistance = 6.0,
    Anim = {
        dict = 'mini@repair',
        clip = 'fixing_a_player',
        flag = 49,
    },
    Labels = {
        few = 'Monterer dele...',
        medium = 'Udfører tuning...',
        many = 'Færdiggør omfattende tuning...',
    },
}

--- Gameplay-kamera (GTA Online LSC-stil) — heading = orbit om bilen, zoom = 0-4
Config.Camera = {
    vehicleViewMode = 1,
    rotateSpeed = 1.4,
    zoomStep = 1,
    defaultPreset = 'default',
}

Config.CameraViews = {
    front = { heading = 180.0, zoom = 1 },
    back = { heading = 0.0, zoom = 1 },
    left = { heading = 90.0, zoom = 2 },
    left_low = { heading = 90.0, zoom = 0 },
    right = { heading = -90.0, zoom = 2 },
    front_top = { heading = 180.0, zoom = 2 },
}

Config.ItemModBindings = {
    paint_primary = { kind = 'color', prop = 'color1' },
    paint_secondary = { kind = 'color', prop = 'color2' },
    livery = { kind = 'vehicleMod', modType = 48 },
    interior_trim = { kind = 'vehicleMod', modType = 27 },
    dashboard = { kind = 'vehicleMod', modType = 29 },
    fuzzy_dice = { kind = 'vehicleMod', modType = 28 },
    brakes = { kind = 'performance', modType = 12 },
    roll_cage = { kind = 'vehicleMod', modType = 5 },
    antenna = { kind = 'vehicleMod', modType = 43 },
    window_tint = { kind = 'windowTint' },
    window_trim = { kind = 'vehicleMod', modType = 46 },
    side_skirts = { kind = 'vehicleMod', modType = 3 },
    spoiler = { kind = 'vehicleMod', modType = 0 },
    hood = { kind = 'vehicleMod', modType = 7 },
    trunk = { kind = 'vehicleMod', modType = 37, altModTypes = { 38, 2 }, mergeAltModTypes = true },
    roof = { kind = 'vehicleMod', modType = 10 },
    grille = { kind = 'vehicleMod', modType = 6 },
    exhaust = { kind = 'vehicleMod', modType = 4 },
    wheels = { kind = 'vehicleMod', modType = 23 },
    suspension = { kind = 'performance', modType = 15 },
    engine = { kind = 'performance', modType = 11 },
    transmission = { kind = 'performance', modType = 13 },
    turbo = { kind = 'turbo' },
    vehicle_extras = { kind = 'vehicleExtras' },
}

Config.ItemImages = {
    paint_primary = 'img/groups/paint.svg',
    paint_secondary = 'img/groups/paint.svg',
    paint_rgb = 'img/groups/rgb.svg',
    livery = 'img/groups/livery.svg',
    interior_trim = 'img/groups/pynt.svg',
    dashboard = 'img/groups/pynt.svg',
    fuzzy_dice = 'img/groups/pynt.svg',
    brakes = 'img/groups/brakes.svg',
    roll_cage = 'img/groups/roll_cage.svg',
    antenna = 'img/groups/antenna.svg',
    window_tint = 'img/groups/windows.svg',
    window_trim = 'img/groups/windows.svg',
    side_skirts = 'img/groups/side_skirts.svg',
    spoiler = 'img/groups/spoiler.svg',
    hood = 'img/groups/hood.svg',
    trunk = 'img/groups/spoiler.svg',
    roof = 'img/groups/hood.svg',
    grille = 'img/groups/hood.svg',
    exhaust = 'img/groups/spoiler.svg',
    wheels = 'img/groups/wheels.svg',
    suspension = 'img/groups/suspension.svg',
    wheel_offset = 'img/groups/wheel_offset.svg',
    engine = 'img/groups/engine.svg',
    transmission = 'img/groups/transmission.svg',
    turbo = 'img/groups/turbo.svg',
}

Config.PaintSwatches = {
    { index = 0, label = 'Sort', hex = '#0d0d0d' },
    { index = 1, label = 'Graphite', hex = '#1c1f21' },
    { index = 4, label = 'Sølv', hex = '#9aa0a6' },
    { index = 27, label = 'Rød', hex = '#c62828' },
    { index = 38, label = 'Orange', hex = '#e65100' },
    { index = 49, label = 'Mørkegrøn', hex = '#1b5e20' },
    { index = 54, label = 'Topaz blå', hex = '#0277bd' },
    { index = 61, label = 'Galaxy blå', hex = '#1565c0' },
    { index = 64, label = 'Marineblå', hex = '#0d47a1' },
    { index = 88, label = 'Gul', hex = '#f9a825' },
    { index = 111, label = 'Hvid', hex = '#f5f5f5' },
    { index = 135, label = 'Pink', hex = '#ec407a' },
    { index = 145, label = 'Lilla metallic', hex = '#7b1fa2' },
    { index = 147, label = 'Carbon sort', hex = '#212121' },
    { index = 158, label = 'Guld', hex = '#c9a227' },
}

--- view = nøgle fra Config.CameraViews (heading/zoom per del)
Config.CameraPresets = {
    default = { view = 'front' },
    customization = { view = 'front' },
    stance = { view = 'front' },
    performance = { view = 'front' },

    paint = { view = 'front' },
    pynt = { view = 'front' },
    brakes = { view = 'left_low' },
    roll_cage = { view = 'front_top' },
    antenna = { view = 'back' },
    windows = { view = 'left' },
    side_skirts = { view = 'left_low' },
    spoiler = { view = 'back' },
    hood = { view = 'front' },
    trunk = { view = 'back' },
    roof = { view = 'front_top' },
    grille = { view = 'front' },
    exhaust = { view = 'back' },
    trunk = { view = 'back' },
    roof = { view = 'front_top' },
    grille = { view = 'front' },
    exhaust = { view = 'back' },

    wheels = { view = 'left_low' },
    suspension = { view = 'left_low' },
    wheel_offset = { view = 'left_low' },

    engine = { view = 'front' },
    transmission = { view = 'front' },
    turbo = { view = 'front' },

    paint_primary = { view = 'front' },
    paint_secondary = { view = 'front' },
    paint_rgb = { view = 'front' },
    livery = { view = 'back' },
    interior_trim = { view = 'front' },
    dashboard = { view = 'front' },
    fuzzy_dice = { view = 'front' },
    window_tint = { view = 'left' },
    window_trim = { view = 'left' },

    ekstra = { view = 'front' },
    vehicle_extras = { view = 'front' },
}

--- Valgfrie pæne navne til vehicle extras (per model-hash eller default)
Config.ExtraLabels = {
    default = {
        ['1'] = 'Ekstra 1',
        ['2'] = 'Ekstra 2',
        ['3'] = 'Ekstra 3',
        ['4'] = 'Ekstra 4',
        ['5'] = 'Ekstra 5',
        ['6'] = 'Lygtebar',
        ['7'] = 'Ekstra 7',
        ['8'] = 'Bullbar',
        ['9'] = 'Ekstra 9',
        ['10'] = 'Ekstra 10',
    },
}
