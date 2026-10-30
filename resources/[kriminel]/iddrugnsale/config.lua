Config = {}

Config.AdminCommand = 'iddrugadmin'
Config.QuickProcessCommand = 'iddrughere'
Config.QuickFarmCommand = 'iddrugfarm'
Config.QuickSetupCommand = 'iddrugsetup'
Config.QuickDealerCommand = 'iddrugdealer'
Config.MoveSpotCommand = 'iddrugmove'
Config.DebugCommand = 'iddrugdebug'
Config.AdminGroups = {
    admin = true,
    superadmin = true,
}

Config.InteractDistance = 5.0
Config.DealerInteractDistance = 4.0
--- Salg til NPC kræver ALT (øjet) + E. Uden fyldte poser vises intet.
Config.SellTargetKey = 19 -- LMENU / venstre ALT (samme som ox_target)
Config.SellRequiresTargetKey = true
--- Sælg til alle NPC'er i verden (ikke kun admin-dealere)
Config.SellToAllNpcs = true
-- Hvor langt væk scriptet "vågner" og tjekker om spilleren er ved et punkt
Config.PointDetectDistance = 25.0
-- Afstand til at se store verdens-markører (når admin har slået dem til)
Config.FarmMarkerDistance = 25.0
-- Vis markør på afstand når admin har slået den til (show_marker = 1)
Config.AlwaysShowNearbyMarker = false
Config.NearbyMarkerDistance = 10.0

Config.TextUI = {
    position = 'right-center',
    iconColor = '#00f8b9',
}

Config.FarmDuration = 4500
Config.FarmAnim = {
    dict = 'amb@world_human_gardener_plant@male@base',
    clip = 'base',
}

Config.ProcessAnim = {
    dict = 'anim@amb@business@coc@coc_unpack_cut@',
    clip = 'fullcut_cycle_v6_cokecutter',
}

--- Gadehandel — animation + props ved NPC-salg
Config.SellDealDuration = 4000
Config.SellDeal = {
    anim = {
        dict = 'mp_common',
        playerClip = 'givetake1_a',
        npcClip = 'givetake1_b',
        flag = 49,
    },
    playerProp = {
        model = 'prop_paper_bag_small',
        bone = 60309,
        pos = { x = 0.08, y = 0.02, z = 0.01 },
        rot = { x = -55.0, y = 10.0, z = 0.0 },
    },
    npcProp = {
        model = 'prop_anim_cash_pile_01',
        bone = 60309,
        pos = { x = 0.10, y = 0.02, z = -0.02 },
        rot = { x = 0.0, y = 0.0, z = 90.0 },
    },
}

Config.DealerModels = {
    'a_m_y_stwhi_02',
    'a_m_y_hipster_02',
    'a_f_y_hipster_01',
    'g_m_y_mexgoon_01',
}

--- Flow: farm blade → omdan løs bulk → pak i pose → stakket salgs-item (fx Kokain)
Config.BagItem = 'polsemandspose'
Config.BagMinGrams = 1
Config.BagMaxGrams = 1
Config.SellUnitGrams = 1
--- Max antal enheder en NPC kan købe ad gangen (styres i admin, skills kan gange op til AbsoluteMaxNpcBuy)
Config.DefaultMaxNpcBuy = 5
Config.AbsoluteMaxNpcBuy = 15

--- Gadesalg + ya_skilltree
Config.SkillTreeResource = 'ya_skilltree'
Config.MaxPoliceAvoidPct = 70
Config.PoliceCallChance = {
    reject = 42,
    success = 8,
}
Config.DispatchResource = 'san_dispatch'
Config.MdtResource = 'san_mdt'

Config.Drugs = {
    hash = {
        label = 'Hash',
        seedItem = 'cannabis_fro_b',
        bladeItem = 'hash_blade',
        looseItem = 'hash_loose',
        sellItem = 'hash',
        rawItem = 'hash_blade',
        color = '#8bc34a',
    },
    skunk = {
        label = 'Skunk',
        seedItem = 'cannabis_fro_a',
        bladeItem = 'skunk_blade',
        looseItem = 'skunk_loose',
        sellItem = 'skunk',
        rawItem = 'skunk_blade',
        color = '#00f8b9',
    },
    kokain = {
        label = 'Kokain',
        bladeItem = 'kokain_blade',
        looseItem = 'kokain_loose',
        sellItem = 'kokain',
        rawItem = 'kokain_blade',
        color = '#e0e0e0',
    },
}

Config.DefaultPrices = {
    hash = { minPrice = 294, basePrice = 420, maxPrice = 546 },
    skunk = { minPrice = 336, basePrice = 480, maxPrice = 624 },
    kokain = { minPrice = 455, basePrice = 650, maxPrice = 910 },
}

--- Standard pose-priser (total kr for hele posen) — bruges hvis admin ikke har sat egne
Config.DefaultBagPriceMultiplier = {
    min = 0.7,
    base = 1.0,
    max = 1.3,
}

--- Jo højere pris over normal (base), jo lavere accept-chance (0-100)
--- Over 30% over normal: meget høj afvisning, men enkelte købere siger stadig ja
Config.PriceAcceptFormula = function(basePrice, offerPrice)
    if offerPrice <= basePrice then
        return 92
    end

    local over = (offerPrice - basePrice) / basePrice

    if over <= 0.30 then
        return math.max(55, math.floor(92 - (over * 120)))
    end

    local extraOver = over - 0.30
    return math.max(4, math.floor(14 - (extraOver * 30)))
end

Config.DefaultFarm = {
    amountMin = 1,
    amountMax = 3,
    cooldown = 45,
    giveRaw = true,
}

Config.DefaultProcess = {
    inputAmount = 3,
    outputAmount = 1,
    duration = 9000,
}

Config.DefaultDealer = {
    model = 'a_m_y_stwhi_02',
}

--- NPC giver dette ox_inventory-item når de køber (spilleren mister fyldt pose)
Config.PayoutItem = 'money'

--- Items der må vælges i admin (farm/omdan)
Config.DrugItems = {
    'plante_krukke',
    'jord',
    'cannabis_fro_a',
    'cannabis_fro_b',
    'hash_blade',
    'skunk_blade',
    'kokain_blade',
    'hash_loose',
    'skunk_loose',
    'kokain_loose',
    'hash',
    'skunk',
    'kokain',
    'polsemandspose',
}

--- Gamle item-navne fra før oprydning
Config.LegacyItems = {
    hash_rav = 'hash_blade',
    skunk_rav = 'skunk_blade',
    kokain_rav = 'kokain_blade',
    hash_1g = 'hash_loose',
    skunk_1g = 'skunk_loose',
    kokain_1g = 'kokain_loose',
}
