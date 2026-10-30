Config = {}

Config.StartingPoints = 0
Config.MaxPoints = 200
Config.OpenEvent = 'ya_skilltree:open'
Config.DefaultCategory = 'criminal'

-- Points tjenes ved kriminelle aktiviteter
Config.PointRewards = {
    street_sale = 1,
    phone_sale = 1,
    house_robbery = 2,
    mission = 3,
}

Config.Categories = {
    {
        id = 'criminal',
        title = 'KRIMINEL',
        desc = 'Narko, salg og underverdenen',
        icon = 'criminal',
        color = '#4dffc8',
        enabled = true
    },
    {
        id = 'garbage',
        title = 'SKRALDEMAND',
        desc = 'Kommer snart',
        icon = 'garbage',
        color = '#5eead4',
        enabled = false
    },
    {
        id = 'civilian',
        title = 'CIVILT',
        desc = 'Kommer snart',
        icon = 'civilian',
        color = '#a78bfa',
        enabled = false
    }
}

Config.Branches = {
    gade = {
        category = 'criminal',
        label = 'Gadesalg',
        tag = 'GADE',
        color = '#4dffc8',
        headerX = 0.18
    },
    narko = {
        category = 'criminal',
        label = 'Narko Salg',
        tag = 'NARKO',
        color = '#fbbf24',
        headerX = 0.50
    },
    mission = {
        category = 'criminal',
        label = 'Missioner',
        tag = 'MIS',
        color = '#fb7185',
        headerX = 0.82
    }
}

Config.Skills = {
    -- ========== GADESALG — iddrugnsale (max 15x, indkomst, politi) ==========
    {
        id = 'crim_gade_start',
        category = 'criminal',
        branch = 'gade',
        title = 'Gade-øje',
        desc = 'Du læser kunder bedre og får lidt mere ud af hver handel på gaden.',
        cost = 1,
        x = 0.18,
        y = 0.78,
        requires = {},
        blocks = {},
        rewards = { '+3% indkomst ved gadesalg' },
        effects = { street_price_pct = 3 }
    },
    {
        id = 'crim_gade_volumen2',
        category = 'criminal',
        branch = 'gade',
        title = 'Større kunder',
        desc = 'Borgere vil købe op til 2x dit normale maks-antal.',
        cost = 1,
        x = 0.18,
        y = 0.64,
        requires = { 'crim_gade_start' },
        blocks = {},
        rewards = { '2x maks antal per kunde' },
        effects = { street_want_mult = 2 }
    },
    {
        id = 'crim_gade_volumen3',
        category = 'criminal',
        branch = 'gade',
        title = 'Bulk-handel',
        desc = 'Top gadesælger — kunder tager op til 3x (maks 15 stk).',
        cost = 2,
        x = 0.18,
        y = 0.48,
        requires = { 'crim_gade_volumen2' },
        blocks = {},
        rewards = { '3x maks antal (op til 15x)' },
        effects = { street_want_mult = 3 }
    },
    {
        id = 'crim_gade_smal',
        category = 'criminal',
        branch = 'gade',
        title = 'Forhandling',
        desc = 'Flere kunder siger ja til dit pris-tilbud.',
        cost = 1,
        x = 0.30,
        y = 0.58,
        requires = { 'crim_gade_start' },
        blocks = { 'crim_gade_diskret' },
        rewards = { '+10% accept-chance' },
        effects = { street_accept_pct = 10 }
    },
    {
        id = 'crim_gade_pris',
        category = 'criminal',
        branch = 'gade',
        title = 'Bedre margin',
        desc = 'Du presser bedre priser uden at skræmme kunden væk.',
        cost = 2,
        x = 0.30,
        y = 0.42,
        requires = { 'crim_gade_smal' },
        blocks = {},
        rewards = { '+7% ekstra indkomst (10% total)' },
        effects = { street_price_pct = 7 }
    },
    {
        id = 'crim_gade_diskret',
        category = 'criminal',
        branch = 'gade',
        title = 'Diskret',
        desc = 'Mindre chance for at borgere ringer til politiet.',
        cost = 1,
        x = 0.06,
        y = 0.58,
        requires = { 'crim_gade_start' },
        blocks = { 'crim_gade_smal' },
        rewards = { '-20% politi-alarm' },
        effects = { police_reduce_pct = 20 }
    },
    {
        id = 'crim_gade_skygge',
        category = 'criminal',
        branch = 'gade',
        title = 'Skygge',
        desc = 'Du forsvinder hurtigere i mængden efter handler.',
        cost = 2,
        x = 0.06,
        y = 0.42,
        requires = { 'crim_gade_diskret' },
        blocks = {},
        rewards = { '-25% politi-alarm (45% total)' },
        effects = { police_reduce_pct = 25 }
    },
    {
        id = 'crim_gade_professionel',
        category = 'criminal',
        branch = 'gade',
        title = 'Professionel',
        desc = 'Maksimal gade-disciplin — op til 70% mindre politi.',
        cost = 3,
        x = 0.06,
        y = 0.26,
        requires = { 'crim_gade_skygge' },
        blocks = {},
        rewards = { 'Op til 70% chance for ingen politi' },
        effects = { police_reduce_pct = 25 }
    },
    {
        id = 'crim_gade_mester',
        category = 'criminal',
        branch = 'gade',
        title = 'Gade-mester',
        desc = 'Kriminiel gade-erfaring — hver handel giver dobbelt skillpoints (KRIMINEL).',
        cost = 120,
        x = 0.50,
        y = 0.08,
        requires = { 'crim_gade_start' },
        blocks = {},
        rewards = { '+2 skillpoints per gadesalg', 'Kræver 120 points · findes under KRIMINEL' },
        effects = { street_sale_point_bonus = 1 }
    },

    -- ========== NARKO SALG — telefon & pris ==========
    {
        id = 'crim_narko_start',
        category = 'criminal',
        branch = 'narko',
        title = 'Telefon-start',
        desc = 'Grundlæggende telefonsalg og kontakter.',
        cost = 1,
        x = 0.50,
        y = 0.78,
        requires = {},
        blocks = {},
        rewards = { '+5% telefonsalgspris' },
        effects = { phone_price_pct = 5 }
    },
    {
        id = 'crim_narko_qty',
        category = 'criminal',
        branch = 'narko',
        title = 'Større ordre',
        desc = 'Telefonkunder bestiller mere per handel.',
        cost = 1,
        x = 0.50,
        y = 0.62,
        requires = { 'crim_narko_start' },
        blocks = {},
        rewards = { '+2 maks stk ved telefonsalg' },
        effects = { phone_amount_bonus = 2 }
    },
    {
        id = 'crim_narko_deal',
        category = 'criminal',
        branch = 'narko',
        title = 'Forhandling',
        desc = 'Pres bedre priser i telefonforhandlinger.',
        cost = 2,
        x = 0.50,
        y = 0.46,
        requires = { 'crim_narko_qty' },
        blocks = {},
        rewards = { '+10% forhandlingsgevinst' },
        effects = { negotiate_pct = 10 }
    },
    {
        id = 'crim_narko_trust',
        category = 'criminal',
        branch = 'narko',
        title = 'Tillidsbygger',
        desc = 'Kunder stoler hurtigere på dig.',
        cost = 1,
        x = 0.50,
        y = 0.30,
        requires = { 'crim_narko_start' },
        blocks = {},
        rewards = { '+15% trust ved salg' },
        effects = { trust_pct = 15 }
    },
    {
        id = 'crim_narko_network',
        category = 'criminal',
        branch = 'narko',
        title = 'Netværk',
        desc = 'Plads til flere aktive kontakter.',
        cost = 2,
        x = 0.62,
        y = 0.38,
        requires = { 'crim_narko_trust' },
        blocks = { 'crim_narko_ghost' },
        rewards = { '+1 kontakt-plads' },
        effects = { contact_slots = 1 }
    },
    {
        id = 'crim_narko_ghost',
        category = 'criminal',
        branch = 'narko',
        title = 'Ghost-linje',
        desc = 'Sværere at spore telefonsalg.',
        cost = 2,
        x = 0.62,
        y = 0.54,
        requires = { 'crim_narko_trust' },
        blocks = { 'crim_narko_network' },
        rewards = { '-10% politi ved telefonsalg' },
        effects = { phone_police_reduce_pct = 10 }
    },

    -- ========== MISSIONER — husrøveri m.m. ==========
    {
        id = 'crim_miss_start',
        category = 'criminal',
        branch = 'mission',
        title = 'Gadeklog',
        desc = 'Du lærer grundlaget for kriminelle missioner.',
        cost = 1,
        x = 0.82,
        y = 0.78,
        requires = {},
        blocks = {},
        rewards = { '+2 points ved missioner' },
        effects = { mission_point_bonus = 1 }
    },
    {
        id = 'crim_miss_hus',
        category = 'criminal',
        branch = 'mission',
        title = 'Husrøveri',
        desc = 'Bedre udbytte og points fra husrøveri.',
        cost = 2,
        x = 0.82,
        y = 0.62,
        requires = { 'crim_miss_start' },
        blocks = {},
        rewards = { '+1 ekstra point ved husrøveri', '+8% loot' },
        effects = { house_loot_pct = 8, house_point_bonus = 1 }
    },
    {
        id = 'crim_miss_runner',
        category = 'criminal',
        branch = 'mission',
        title = 'Runner',
        desc = 'Hurtigere færdig med leveringsmissioner.',
        cost = 1,
        x = 0.82,
        y = 0.46,
        requires = { 'crim_miss_start' },
        blocks = {},
        rewards = { '-10% mission-tid' },
        effects = { mission_time_pct = 10 }
    },
    {
        id = 'crim_miss_pro',
        category = 'criminal',
        branch = 'mission',
        title = 'Professionel',
        desc = 'Topniveau i kriminelle opgaver.',
        cost = 3,
        x = 0.82,
        y = 0.30,
        requires = { 'crim_miss_hus', 'crim_miss_runner' },
        blocks = {},
        rewards = { '+3 points ved missioner', '+15% mission-belønning' },
        effects = { mission_point_bonus = 2, mission_reward_pct = 15 }
    }
}
