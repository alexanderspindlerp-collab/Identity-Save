local ESX = exports['es_extended']:getSharedObject()
local DrugUtils = _G.DrugUtils or lib.load('server.drugs')

local State = {
    farms = {},
    process = {},
    dealers = {},
    prices = {},
    bagPrices = {},
    settings = {},
}

local farmCooldowns = {}
local playerSoldNpcs = {}
local activeNpcDeals = {}

local function normalizeDrugKey(key)
    if type(key) ~= 'string' then return nil end
    key = key:lower()
    if Config.Drugs[key] then return key end

    local legacy = {
        hash_rav = 'hash',
        skunk_rav = 'skunk',
        kokain_rav = 'kokain',
    }

    return legacy[key]
end

local function drugConfig(key)
    local normalized = normalizeDrugKey(key)
    return normalized and Config.Drugs[normalized] or nil
end

local function isEnabled(value)
    return value == 1 or value == true or value == '1'
end

local function isRawFarm(farm)
    return farm.give_raw == 1 or farm.give_raw == true or farm.give_raw == '1'
end

local function drugLooseItem(drug)
    return drug.looseItem or drug.productItem
end

local function drugItemSetAdd(drug, set)
    if drug.bladeItem then set[drug.bladeItem] = true end
    if drug.looseItem then set[drug.looseItem] = true end
    if drug.productItem then set[drug.productItem] = true end
    if drug.rawItem then set[drug.rawItem] = true end
    if drug.sellItem then set[drug.sellItem] = true end
    if drug.seedItem then set[drug.seedItem] = true end
end

local drugItemSet

local function buildDrugItemSet()
    if drugItemSet then return drugItemSet end

    drugItemSet = {}
    for _, name in ipairs(Config.DrugItems or {}) do
        drugItemSet[name] = true
    end

    for _, drug in pairs(Config.Drugs) do
        drugItemSetAdd(drug, drugItemSet)
    end

    if Config.BagItem then
        drugItemSet[Config.BagItem] = true
    end

    return drugItemSet
end

local function getOxItemsSafe()
    if GetResourceState('ox_inventory') ~= 'started' then
        return {}
    end

    local ok, items = pcall(function()
        return exports.ox_inventory:Items()
    end)

    if ok and type(items) == 'table' then
        return items
    end

    ok, items = pcall(function()
        return exports.ox_inventory:ItemList()
    end)

    if ok and type(items) == 'table' then
        return items
    end

    return {}
end

local function itemLabel(itemName)
    local items = getOxItemsSafe()
    local data = items[itemName]
    if data and data.label then
        return data.label
    end

    for _, drug in pairs(Config.Drugs) do
        if drug.looseItem == itemName or drug.productItem == itemName or drug.sellItem == itemName
            or drug.bladeItem == itemName or drug.rawItem == itemName then
            return drug.label
        end
    end

    return itemName
end

local function isValidOxItem(itemName)
    if not itemName or itemName == '' then return false end
    if buildDrugItemSet()[itemName] then return true end

    local items = getOxItemsSafe()
    return items[itemName] ~= nil
end

local function getOxItemsList()
    local items = getOxItemsSafe()
    local list = {}
    local allowed = buildDrugItemSet()

    for name in pairs(allowed) do
        local data = items[name]
        list[#list + 1] = {
            name = name,
            label = (data and data.label) or itemLabel(name),
        }
    end

    table.sort(list, function(a, b)
        return a.label:lower() < b.label:lower()
    end)

    return list
end

local function normalizeItemName(itemName)
    if not itemName or itemName == '' then
        return nil
    end

    local mapped = Config.LegacyItems and Config.LegacyItems[itemName] or itemName
    if isValidOxItem(mapped) then
        return mapped
    end

    return nil
end

local function isRawDrugItem(itemName)
    for _, drug in pairs(Config.Drugs) do
        if itemName == drug.bladeItem or itemName == drug.rawItem then
            return true
        end
    end
    return false
end

local function isProductDrugItem(itemName)
    for _, drug in pairs(Config.Drugs) do
        if itemName == drug.looseItem or itemName == drug.productItem or itemName == drug.sellItem then
            return true
        end
    end
    return false
end

local function resolveDrugItem(itemName, drug, kind)
    local normalized = normalizeItemName(itemName)

    if kind == 'product' then
        if normalized and isProductDrugItem(normalized) then
            return normalized
        end
        return drugLooseItem(drug)
    end

    if normalized and isRawDrugItem(normalized) then
        return normalized
    end

    return drug.bladeItem or drug.rawItem
end

local function resolveGiveItem(data, drug)
    if data.giveItem and data.giveItem ~= '' then
        local item = resolveDrugItem(data.giveItem, drug, 'raw')
        if item then
            return item
        end
        return nil
    end

    local giveRaw = data.giveRaw == true or data.giveRaw == 1 or data.giveRaw == '1'
    return giveRaw and (drug.bladeItem or drug.rawItem) or drugLooseItem(drug)
end

local function resolveProcessItems(data, drug)
    local inputItem = resolveDrugItem(data.inputItem, drug, 'raw')
    local outputItem = resolveDrugItem(data.outputItem, drug, 'product')
    return inputItem, outputItem
end

local function farmRewardItem(farm, drug)
    if farm.give_item and farm.give_item ~= '' then
        return resolveDrugItem(farm.give_item, drug, 'raw')
    end
    return isRawFarm(farm) and (drug.bladeItem or drug.rawItem) or drugLooseItem(drug)
end

local function processItems(point, drug)
    return resolveDrugItem(point.input_item, drug, 'raw'), resolveDrugItem(point.output_item, drug, 'product')
end

local function enrichFarmRow(farm)
    local drug = drugConfig(farm.drug_key)
    if not drug then return farm end
    farm.give_item = farmRewardItem(farm, drug)
    farm.reward_label = itemLabel(farm.give_item)
    return farm
end

local function enrichProcessRow(point)
    local drug = drugConfig(point.drug_key)
    if not drug then return point end
    local inputItem = resolveDrugItem(point.input_item, drug, 'raw')
    local outputItem = drugLooseItem(drug)
    point.input_item = inputItem
    point.output_item = outputItem
    point.input_label = itemLabel(inputItem)
    point.output_label = drug.label
    return point
end

local function enrichState()
    for i, farm in ipairs(State.farms) do
        local drugKey = normalizeDrugKey(farm.drug_key)
        local drug = drugKey and Config.Drugs[drugKey]
        if drug then
            if drugKey ~= farm.drug_key then
                farm.drug_key = drugKey
                MySQL.update.await('UPDATE iddrugnsale_farms SET drug_key = ? WHERE id = ?', { drugKey, farm.id })
            end

            local item = farmRewardItem(farm, drug)
            if farm.give_item ~= item then
                farm.give_item = item
                MySQL.update.await('UPDATE iddrugnsale_farms SET give_item = ? WHERE id = ?', { item, farm.id })
            end
        end
        State.farms[i] = enrichFarmRow(farm)
    end

    for i, point in ipairs(State.process) do
        local drugKey = normalizeDrugKey(point.drug_key)
        local drug = drugKey and Config.Drugs[drugKey]
        if drug then
            if drugKey ~= point.drug_key then
                point.drug_key = drugKey
                MySQL.update.await('UPDATE iddrugnsale_process SET drug_key = ? WHERE id = ?', { drugKey, point.id })
            end

            if tonumber(point.input_amount) == 5 then
                point.input_amount = Config.DefaultProcess.inputAmount
                MySQL.update.await(
                    'UPDATE iddrugnsale_process SET input_amount = ? WHERE id = ?',
                    { point.input_amount, point.id }
                )
            end

            local inputItem = resolveDrugItem(point.input_item, drug, 'raw')
            local outputItem = drugLooseItem(drug)
            if point.input_item ~= inputItem or point.output_item ~= outputItem then
                point.input_item = inputItem
                point.output_item = outputItem
                MySQL.update.await(
                    'UPDATE iddrugnsale_process SET input_item = ?, output_item = ? WHERE id = ?',
                    { inputItem, outputItem, point.id }
                )
            end
        end
        State.process[i] = enrichProcessRow(point)
    end
end

local function isAdmin(source)
    if Core and Core.IsPlayerAdmin then
        return Core.IsPlayerAdmin(source)
    end

    if IsPlayerAceAllowed(source --[[@as string]], 'command') then
        return true
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    if xPlayer.admin == true then
        return true
    end

    local group = xPlayer.getGroup()
    return Config.AdminGroups[group] == true
end

local function normalizeStoredPrices(base, minVal, maxVal)
    minVal = tonumber(minVal) or 0
    maxVal = tonumber(maxVal) or 0
    base = tonumber(base) or 500

    -- Ældre DB-rækker gemte min/max som procent (fx 70 / 130)
    if minVal > 0 and minVal <= 200 and maxVal > 0 and maxVal <= 300 then
        return {
            minPrice = math.floor(base * minVal / 100),
            basePrice = base,
            maxPrice = math.floor(base * maxVal / 100),
        }
    end

    return {
        minPrice = minVal,
        basePrice = base,
        maxPrice = maxVal,
    }
end

local function defaultBagPriceFor(drugKey, grams)
    local perGram = Config.DefaultPrices[drugKey] or { minPrice = 350, basePrice = 500, maxPrice = 650 }
    local mult = Config.DefaultBagPriceMultiplier or { min = 0.7, base = 1.0, max = 1.3 }
    local base = math.floor((perGram.basePrice or 500) * grams)

    return {
        minPrice = math.floor(base * (mult.min or 0.7)),
        basePrice = base,
        maxPrice = math.floor(base * (mult.max or 1.3)),
    }
end

local function bagPriceFromPerGram(perGram, grams)
    grams = math.max(1, math.floor(tonumber(grams) or 1))
    return {
        minPrice = math.floor((perGram.minPrice or 350) * grams),
        basePrice = math.floor((perGram.basePrice or 500) * grams),
        maxPrice = math.floor((perGram.maxPrice or 650) * grams),
    }
end

local function buildBagPrices(rows, perGramPrices)
    local bagPrices = {}

    for drugKey in pairs(Config.Drugs) do
        bagPrices[drugKey] = {}
        local perGram = perGramPrices[drugKey] or Config.DefaultPrices[drugKey]
        for grams = Config.BagMinGrams, Config.BagMaxGrams do
            bagPrices[drugKey][grams] = perGram and bagPriceFromPerGram(perGram, grams) or defaultBagPriceFor(drugKey, grams)
        end
    end

    for _, row in ipairs(rows or {}) do
        local drugKey = row.drug_key
        local grams = math.floor(tonumber(row.grams) or 0)
        if bagPrices[drugKey] and grams >= Config.BagMinGrams and grams <= Config.BagMaxGrams then
            local minPrice = math.floor(tonumber(row.min_price) or 0)
            local basePrice = math.floor(tonumber(row.base_price) or 0)
            local maxPrice = math.floor(tonumber(row.max_price) or 0)
            if basePrice < 1 then basePrice = defaultBagPriceFor(drugKey, grams).basePrice end
            if minPrice < 1 then minPrice = math.floor(basePrice * 0.7) end
            if maxPrice < minPrice then maxPrice = math.floor(basePrice * 1.3) end
            bagPrices[drugKey][grams] = {
                minPrice = minPrice,
                basePrice = basePrice,
                maxPrice = maxPrice,
            }
        end
    end

    return bagPrices
end

local function getBagPriceCfg(drugKey, grams)
    grams = math.floor(tonumber(grams) or 0)
    local drugPrices = State.bagPrices[drugKey]
    if drugPrices and drugPrices[grams] then
        return drugPrices[grams]
    end
    return defaultBagPriceFor(drugKey, grams)
end

local function buildPrices(rows)
    local prices = {}
    for key in pairs(Config.Drugs) do
        local def = Config.DefaultPrices[key] or { minPrice = 350, basePrice = 500, maxPrice = 650 }
        prices[key] = {
            minPrice = def.minPrice,
            basePrice = def.basePrice,
            maxPrice = def.maxPrice,
        }
    end
    for _, row in ipairs(rows or {}) do
        if prices[row.drug_key] then
            prices[row.drug_key] = normalizeStoredPrices(row.base_price, row.min_percent, row.max_percent)
        end
    end
    return prices
end

local function syncAll(target)
    TriggerClientEvent('iddrugnsale:sync', target or -1, State)
end

local function ensureTables()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `iddrugnsale_farms` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(64) NOT NULL DEFAULT 'Farm',
            `drug_key` VARCHAR(32) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `amount_min` INT NOT NULL DEFAULT 1,
            `amount_max` INT NOT NULL DEFAULT 3,
            `cooldown` INT NOT NULL DEFAULT 45,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `give_raw` TINYINT(1) NOT NULL DEFAULT 1,
            `give_item` VARCHAR(64) DEFAULT NULL,
            `show_marker` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `iddrugnsale_process` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(64) NOT NULL DEFAULT 'Omdan',
            `drug_key` VARCHAR(32) NOT NULL,
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `input_amount` INT NOT NULL DEFAULT 3,
            `output_amount` INT NOT NULL DEFAULT 1,
            `duration` INT NOT NULL DEFAULT 9000,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            `input_item` VARCHAR(64) DEFAULT NULL,
            `output_item` VARCHAR(64) DEFAULT NULL,
            `show_marker` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `iddrugnsale_dealers` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `label` VARCHAR(64) NOT NULL DEFAULT 'Dealer',
            `model` VARCHAR(64) NOT NULL DEFAULT 'a_m_y_stwhi_02',
            `x` DOUBLE NOT NULL,
            `y` DOUBLE NOT NULL,
            `z` DOUBLE NOT NULL,
            `heading` DOUBLE NOT NULL DEFAULT 0,
            `enabled` TINYINT(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `iddrugnsale_prices` (
            `drug_key` VARCHAR(32) NOT NULL,
            `base_price` INT NOT NULL DEFAULT 500,
            `min_percent` INT NOT NULL DEFAULT 70,
            `max_percent` INT NOT NULL DEFAULT 130,
            PRIMARY KEY (`drug_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        INSERT IGNORE INTO `iddrugnsale_prices` (`drug_key`, `base_price`, `min_percent`, `max_percent`) VALUES
            ('hash', 420, 70, 130),
            ('skunk', 480, 70, 130),
            ('kokain', 650, 70, 140)
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `iddrugnsale_bag_prices` (
            `drug_key` VARCHAR(32) NOT NULL,
            `grams` TINYINT NOT NULL,
            `min_price` INT NOT NULL DEFAULT 300,
            `base_price` INT NOT NULL DEFAULT 500,
            `max_price` INT NOT NULL DEFAULT 650,
            PRIMARY KEY (`drug_key`, `grams`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `iddrugnsale_settings` (
            `key` VARCHAR(64) NOT NULL,
            `value` VARCHAR(255) NOT NULL,
            PRIMARY KEY (`key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        INSERT IGNORE INTO `iddrugnsale_settings` (`key`, `value`) VALUES ('max_npc_buy', '5')
    ]])

    pcall(function()
        MySQL.query.await('ALTER TABLE `iddrugnsale_farms` ADD COLUMN `give_item` VARCHAR(64) DEFAULT NULL')
    end)
    pcall(function()
        MySQL.query.await('ALTER TABLE `iddrugnsale_process` ADD COLUMN `input_item` VARCHAR(64) DEFAULT NULL')
    end)
    pcall(function()
        MySQL.query.await('ALTER TABLE `iddrugnsale_process` ADD COLUMN `output_item` VARCHAR(64) DEFAULT NULL')
    end)
    pcall(function()
        MySQL.query.await('ALTER TABLE `iddrugnsale_farms` ADD COLUMN `show_marker` TINYINT(1) NOT NULL DEFAULT 0')
    end)
    pcall(function()
        MySQL.query.await('ALTER TABLE `iddrugnsale_process` ADD COLUMN `show_marker` TINYINT(1) NOT NULL DEFAULT 0')
    end)
end

local function waitForOxInventory()
    local deadline = GetGameTimer() + 15000

    while GetGameTimer() < deadline do
        if GetResourceState('ox_inventory') == 'started' then
            local ok = pcall(function()
                exports.ox_inventory:Items()
            end)

            if ok then
                return true
            end
        end

        Wait(200)
    end

    print('^3[iddrugnsale] ox_inventory export ikke klar — bruger Config.DrugItems som fallback.^0')
    return false
end

local function getMaxNpcBuy()
    local value = State.settings and State.settings.maxNpcBuy or Config.DefaultMaxNpcBuy or 5
    return math.max(1, math.min(50, math.floor(tonumber(value) or 5)))
end

local function getStreetBonuses(src)
    local res = Config.SkillTreeResource or 'ya_skilltree'
    local empty = { street_want_mult = 1, street_price_pct = 0, street_accept_pct = 0, police_reduce_pct = 0 }
    if GetResourceState(res) ~= 'started' then return empty end

    local ok, bonuses = pcall(function()
        return exports[res]:GetCriminalBonuses(src)
    end)
    if not ok or type(bonuses) ~= 'table' then return empty end
    return bonuses
end

local function getEffectiveMaxNpcBuy(src)
    local adminMax = getMaxNpcBuy()
    local bonuses = getStreetBonuses(src)
    local mult = math.max(1, tonumber(bonuses.street_want_mult) or 1)
    local absolute = Config.AbsoluteMaxNpcBuy or 15
    return math.max(1, math.min(absolute, math.floor(adminMax * mult)))
end

local function getAcceptChance(src, basePrice, offerPrice)
    local chance = Config.PriceAcceptFormula(basePrice, offerPrice)
    local acceptBonus = tonumber(getStreetBonuses(src).street_accept_pct) or 0
    return math.min(98, chance + acceptBonus)
end

local function applyStreetPriceBonus(src, amount)
    local pct = tonumber(getStreetBonuses(src).street_price_pct) or 0
    if pct <= 0 then return amount end
    return math.floor(amount * (1 + pct / 100))
end

local function rollNpcPoliceCall(src, context, target)
    local bonuses = getStreetBonuses(src)
    local reduce = math.min(Config.MaxPoliceAvoidPct or 70, tonumber(bonuses.police_reduce_pct) or 0)
    local chances = Config.PoliceCallChance or {}
    local base = context == 'reject' and (chances.reject or 42) or (chances.success or 8)
    local callChance = math.max(0, math.floor(base * (1 - reduce / 100)))
    if callChance < 1 or math.random(100) > callChance then return end
    TriggerClientEvent('iddrugnsale:requestPoliceDispatch', src, context, target)
end

local function awardStreetSalePoints(src)
    local res = Config.SkillTreeResource or 'ya_skilltree'
    if GetResourceState(res) ~= 'started' then return end
    pcall(function()
        exports[res]:AwardPoints(src, 'street_sale')
    end)
end

local function loadSettings()
    State.settings = {
        maxNpcBuy = Config.DefaultMaxNpcBuy or 5,
    }

    local row = MySQL.single.await("SELECT value FROM iddrugnsale_settings WHERE `key` = 'max_npc_buy' LIMIT 1")
    if row and row.value then
        State.settings.maxNpcBuy = math.max(1, math.min(50, math.floor(tonumber(row.value) or Config.DefaultMaxNpcBuy or 5)))
    end
end

local function loadState()
    ensureTables()
    State.farms = MySQL.query.await('SELECT * FROM iddrugnsale_farms') or {}
    State.process = MySQL.query.await('SELECT * FROM iddrugnsale_process') or {}
    State.dealers = MySQL.query.await('SELECT * FROM iddrugnsale_dealers') or {}
    local priceRows = MySQL.query.await('SELECT * FROM iddrugnsale_prices') or {}
    State.prices = buildPrices(priceRows)
    local bagPriceRows = MySQL.query.await('SELECT * FROM iddrugnsale_bag_prices') or {}
    State.bagPrices = buildBagPrices(bagPriceRows, State.prices)
    loadSettings()
    enrichState()
end

local function startup()
    waitForOxInventory()

    local ok, err = pcall(loadState)
    if not ok then
        print('^1[iddrugnsale] Startup fejlede — tjek oxmysql/database:^0', err)
        return
    end
    syncAll()
    print(('^2[iddrugnsale] Klar — %d farme, %d omdan-punkter, %d dealere.^0'):format(
        #(State.farms or {}),
        #(State.process or {}),
        #(State.dealers or {})
    ))
    if #(State.process or {}) == 0 then
        print('^3[iddrugnsale] Ingen omdan-punkter! Stå i labbet og kør /iddrughere hash (admin)^0')
    end
end

MySQL.ready(function()
    startup()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        waitForOxInventory()
        Wait(500)
        local ok, err = pcall(loadState)
        if ok then
            syncAll()
        else
            print('^1[iddrugnsale] Reload fejlede:^0', err)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    playerSoldNpcs[source] = nil
    activeNpcDeals[source] = nil
end)

lib.callback.register('iddrugnsale:isAdmin', function(source)
    return isAdmin(source)
end)

lib.callback.register('iddrugnsale:getOxItems', function(source)
    if not isAdmin(source) then return {} end
    return getOxItemsList()
end)

lib.callback.register('iddrugnsale:getState', function(source)
    return State
end)

local function npcCoordsFromTarget(target)
    if type(target) ~= 'table' then return end
    local x = tonumber(target.x)
    local y = tonumber(target.y)
    local z = tonumber(target.z)
    if not x or not y or not z then return end
    return vector3(x, y, z)
end

local function npcNetIdFromTarget(target)
    if type(target) ~= 'table' then return end
    local netId = math.floor(tonumber(target.netId) or 0)
    if netId < 1 then return end
    return netId
end

local function npcSaleKeyFromTarget(target)
    local netId = npcNetIdFromTarget(target)
    if netId then
        return ('net:%s'):format(netId)
    end

    if type(target) ~= 'table' then return end
    local model = math.floor(tonumber(target.model) or 0)
    local x = tonumber(target.x)
    local y = tonumber(target.y)
    local z = tonumber(target.z)
    if model < 1 or not x or not y or not z then return end

    return ('pos:%s:%d:%d:%d'):format(model, math.floor(x * 2), math.floor(y * 2), math.floor(z * 2))
end

local function hasSoldToNpc(src, target)
    local saleKey = npcSaleKeyFromTarget(target)
    if not saleKey then return false end
    local sold = playerSoldNpcs[src]
    return sold and sold[saleKey] == true
end

local function markSoldToNpc(src, target)
    local saleKey = npcSaleKeyFromTarget(target)
    if not saleKey then return end
    playerSoldNpcs[src] = playerSoldNpcs[src] or {}
    playerSoldNpcs[src][saleKey] = true
end

local function givePayoutItem(src, amount)
    local item = Config.PayoutItem or 'money'
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return false, 'invalid_amount' end

    if exports.ox_inventory:CanCarryItem(src, item, amount) ~= true then
        return false, 'no_space'
    end

    if not exports.ox_inventory:AddItem(src, item, amount) then
        return false, 'add_failed'
    end

    return true
end

local function isNearNpcCoords(src, target)
    local coords = npcCoordsFromTarget(target)
    if not coords then return false end

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - coords) <= (Config.DealerInteractDistance or 4.0) + 2.5
end

lib.callback.register('iddrugnsale:getInventoryDrugs', function(source, target)
    if not isNearNpcCoords(source, target) then
        return { ok = false, message = 'Du er for langt væk fra personen.' }
    end

    if hasSoldToNpc(source, target) then
        return { ok = false, message = 'Du har allerede solgt til denne mand' }
    end

    local items = {}
    for key, drug in pairs(Config.Drugs) do
        local bags = DrugUtils.getFilledBagBreakdown(source, key)
        if #bags > 0 then
            local totalGrams = 0
            local pricedBags = {}

            for _, bag in ipairs(bags) do
                local price = getBagPriceCfg(key, bag.grams)
                totalGrams = totalGrams + (bag.grams * bag.count)
                pricedBags[#pricedBags + 1] = {
                    grams = bag.grams,
                    count = bag.count,
                    minPrice = price.minPrice,
                    basePrice = price.basePrice,
                    maxPrice = price.maxPrice,
                }
            end

            items[#items + 1] = {
                key = key,
                label = drug.label,
                item = drug.sellItem,
                count = pricedBags[1] and pricedBags[1].count or 0,
                bags = pricedBags,
                color = drug.color,
            }
        end
    end

    if #items == 0 then
        for drugKey in pairs(Config.Drugs) do
            if DrugUtils.getLooseGrams(source, drugKey) > 0 then
                return {
                    ok = false,
                    message = 'Du skal pakke stoffet i poser først — løst stof kan ikke sælges.',
                }
            end
        end

        return { ok = false, message = 'Du har intet at sælge. Pak stoffet i poser først.' }
    end

    local saleKey = npcSaleKeyFromTarget(target)
    local maxNpcBuy = getEffectiveMaxNpcBuy(source)
    local adminMaxNpcBuy = getMaxNpcBuy()
    local bonuses = getStreetBonuses(source)
    local npcBagCount = math.random(1, maxNpcBuy)

    activeNpcDeals[source] = {
        saleKey = saleKey,
        bagCount = npcBagCount,
        maxNpcBuy = maxNpcBuy,
    }

    return {
        ok = true,
        dealerLabel = 'Lokal borger',
        items = items,
        npcBagCount = npcBagCount,
        maxNpcBuy = maxNpcBuy,
        adminMaxNpcBuy = adminMaxNpcBuy,
        skillBonuses = {
            acceptPct = tonumber(bonuses.street_accept_pct) or 0,
            pricePct = tonumber(bonuses.street_price_pct) or 0,
            policeReducePct = math.min(Config.MaxPoliceAvoidPct or 70, tonumber(bonuses.police_reduce_pct) or 0),
            wantMult = tonumber(bonuses.street_want_mult) or 1,
        },
    }
end)

lib.callback.register('iddrugnsale:canSellAtDealer', function(source, target)
    if not isNearNpcCoords(source, target) then
        return { ok = false, reason = 'far' }
    end

    if hasSoldToNpc(source, target) then
        return { ok = false, reason = 'sold' }
    end

    if DrugUtils.hasFilledBags(source) then
        return { ok = true, reason = 'bags' }
    end

    for drugKey in pairs(Config.Drugs) do
        if DrugUtils.getLooseGrams(source, drugKey) > 0 then
            return { ok = false, reason = 'loose' }
        end
    end

    return { ok = false, reason = 'empty' }
end)

RegisterNetEvent('iddrugnsale:adminCreateFarm', function(data)
    local src = source
    if not isAdmin(src) then return end

    local drug = drugConfig(data.drugKey)
    if not drug then return end

    local giveItem = resolveGiveItem(data, drug)
    if not giveItem then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Ugyldigt item — vælg fra ox_inventory.' })
        return
    end

    local giveRaw = giveItem == (drug.bladeItem or drug.rawItem) and 1 or 0

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_farms (label, drug_key, x, y, z, amount_min, amount_max, cooldown, enabled, give_raw, give_item, show_marker)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 1)
    ]], {
        data.label or ('Farm ' .. drug.label),
        data.drugKey,
        data.x, data.y, data.z,
        tonumber(data.amountMin) or Config.DefaultFarm.amountMin,
        tonumber(data.amountMax) or Config.DefaultFarm.amountMax,
        tonumber(data.cooldown) or Config.DefaultFarm.cooldown,
        giveRaw,
        giveItem,
    })

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Farm oprettet (#' .. id .. ')' })
end)

RegisterNetEvent('iddrugnsale:adminCreateProcess', function(data)
    local src = source
    if not isAdmin(src) then return end

    local drug = drugConfig(data.drugKey)
    if not drug then return end

    local inputItem, outputItem = resolveProcessItems(data, drug)

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_process (label, drug_key, x, y, z, input_amount, output_amount, duration, enabled, input_item, output_item, show_marker)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 1)
    ]], {
        data.label or ('Omdan ' .. drug.label),
        data.drugKey,
        data.x, data.y, data.z,
        tonumber(data.inputAmount) or Config.DefaultProcess.inputAmount,
        tonumber(data.outputAmount) or Config.DefaultProcess.outputAmount,
        tonumber(data.duration) or Config.DefaultProcess.duration,
        inputItem,
        outputItem,
    })

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Omdan-punkt oprettet (#' .. id .. ')' })
end)

RegisterNetEvent('iddrugnsale:adminCreateDealer', function(data)
    local src = source
    if not isAdmin(src) then return end

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_dealers (label, model, x, y, z, heading, enabled)
        VALUES (?, ?, ?, ?, ?, ?, 1)
    ]], {
        data.label or 'Dealer',
        data.model or Config.DefaultDealer.model,
        data.x, data.y, data.z,
        tonumber(data.heading) or 0.0,
    })

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'NPC-dealer oprettet (#' .. id .. ')' })
end)

RegisterNetEvent('iddrugnsale:adminToggleMarker', function(kind, id)
    local src = source
    if not isAdmin(src) then return end

    local tableName = ({
        farm = 'iddrugnsale_farms',
        process = 'iddrugnsale_process',
    })[kind]

    if not tableName then return end

    local rows = MySQL.query.await(('SELECT show_marker FROM %s WHERE id = ?'):format(tableName), { id })
    if not rows or not rows[1] then return end

    local nextValue = isEnabled(rows[1].show_marker) and 0 or 1
    MySQL.update.await(('UPDATE %s SET show_marker = ? WHERE id = ?'):format(tableName), { nextValue, id })
    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = nextValue == 1 and 'Marker synlig' or 'Marker skjult',
    })
end)

RegisterNetEvent('iddrugnsale:adminToggle', function(kind, id, enabled)
    local src = source
    if not isAdmin(src) then return end

    local tableName = ({
        farm = 'iddrugnsale_farms',
        process = 'iddrugnsale_process',
        dealer = 'iddrugnsale_dealers',
    })[kind]

    if not tableName then return end

    MySQL.update.await(('UPDATE %s SET enabled = ? WHERE id = ?'):format(tableName), { enabled and 1 or 0, id })
    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = enabled and 'Punkt åbnet' or 'Punkt lukket',
    })
end)

RegisterNetEvent('iddrugnsale:adminDelete', function(kind, id)
    local src = source
    if not isAdmin(src) then return end

    local tableName = ({
        farm = 'iddrugnsale_farms',
        process = 'iddrugnsale_process',
        dealer = 'iddrugnsale_dealers',
    })[kind]

    if not tableName then return end

    MySQL.update.await(('DELETE FROM %s WHERE id = ?'):format(tableName), { id })
    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Slettet' })
end)

RegisterNetEvent('iddrugnsale:adminUpdateFarm', function(id, data)
    local src = source
    if not isAdmin(src) then return end

    local drug = drugConfig(data.drugKey or data.drug_key)
    if not drug then return end

    local giveItem = resolveGiveItem(data, drug)
    if not giveItem then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Ugyldigt item — vælg fra ox_inventory.' })
        return
    end

    local giveRaw = giveItem == (drug.bladeItem or drug.rawItem) and 1 or 0

    MySQL.update.await([[
        UPDATE iddrugnsale_farms
        SET label = ?, amount_min = ?, amount_max = ?, cooldown = ?, give_raw = ?, give_item = ?
        WHERE id = ?
    ]], {
        data.label,
        tonumber(data.amountMin) or 1,
        tonumber(data.amountMax) or 1,
        tonumber(data.cooldown) or 45,
        giveRaw,
        giveItem,
        id,
    })

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Farm opdateret' })
end)

RegisterNetEvent('iddrugnsale:adminUpdateProcess', function(id, data)
    local src = source
    if not isAdmin(src) then return end

    local point
    for _, row in ipairs(State.process) do
        if row.id == id then point = row break end
    end

    local drug = drugConfig(point and point.drug_key or data.drugKey)
    if not drug then return end

    local inputItem, outputItem = resolveProcessItems(data, drug)

    MySQL.update.await([[
        UPDATE iddrugnsale_process
        SET label = ?, input_amount = ?, output_amount = ?, duration = ?, input_item = ?, output_item = ?
        WHERE id = ?
    ]], {
        data.label,
        tonumber(data.inputAmount) or 5,
        tonumber(data.outputAmount) or 1,
        tonumber(data.duration) or 9000,
        inputItem,
        outputItem,
        id,
    })

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Omdan opdateret' })
end)

RegisterNetEvent('iddrugnsale:adminUpdatePrices', function(data)
    local src = source
    if not isAdmin(src) then return end

    local maxNpcBuy = math.floor(tonumber(data and data.maxNpcBuy) or 0)
    if maxNpcBuy >= 1 and maxNpcBuy <= 50 then
        MySQL.update.await([[
            INSERT INTO iddrugnsale_settings (`key`, `value`) VALUES ('max_npc_buy', ?)
            ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)
        ]], { tostring(maxNpcBuy) })
        State.settings = State.settings or {}
        State.settings.maxNpcBuy = maxNpcBuy
    end

    local bagPrices = data and (data.bagPrices or data.prices) or {}

    for drugKey, sizes in pairs(bagPrices) do
        if not Config.Drugs[drugKey] or type(sizes) ~= 'table' then goto continue_drug end

        if sizes.minPrice and sizes.basePrice and sizes.maxPrice then
            for grams = Config.BagMinGrams, Config.BagMaxGrams do
                local bagRow = bagPriceFromPerGram(sizes, grams)
                MySQL.update.await([[
                    INSERT INTO iddrugnsale_bag_prices (drug_key, grams, min_price, base_price, max_price)
                    VALUES (?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        min_price = VALUES(min_price),
                        base_price = VALUES(base_price),
                        max_price = VALUES(max_price)
                ]], {
                    drugKey,
                    grams,
                    bagRow.minPrice,
                    bagRow.basePrice,
                    bagRow.maxPrice,
                })
            end
            goto continue_drug
        end

        for gramsKey, row in pairs(sizes) do
            local grams = math.floor(tonumber(gramsKey) or 0)
            if grams >= Config.BagMinGrams and grams <= Config.BagMaxGrams and type(row) == 'table' then
                local minPrice = math.floor(tonumber(row.minPrice) or 0)
                local basePrice = math.floor(tonumber(row.basePrice) or 0)
                local maxPrice = math.floor(tonumber(row.maxPrice) or 0)

                if basePrice < 1 then basePrice = defaultBagPriceFor(drugKey, grams).basePrice end
                if minPrice < 1 then minPrice = math.floor(basePrice * 0.7) end
                if maxPrice < minPrice then maxPrice = math.floor(basePrice * 1.3) end

                MySQL.update.await([[
                    INSERT INTO iddrugnsale_bag_prices (drug_key, grams, min_price, base_price, max_price)
                    VALUES (?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                        min_price = VALUES(min_price),
                        base_price = VALUES(base_price),
                        max_price = VALUES(max_price)
                ]], {
                    drugKey,
                    grams,
                    minPrice,
                    basePrice,
                    maxPrice,
                })
            end
        end

        ::continue_drug::
    end

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Pose-priser gemt' })
end)

local function sameId(a, b)
    return tonumber(a) == tonumber(b)
end

local function getFarmById(farmId)
    for _, farm in ipairs(State.farms) do
        if sameId(farm.id, farmId) then return farm end
    end
end

local function getProcessById(processId)
    for _, point in ipairs(State.process) do
        if sameId(point.id, processId) then return point end
    end
end

local function countItem(source, itemName)
    local count = exports.ox_inventory:Search(source, 'count', itemName)
    if type(count) == 'number' then
        return count
    end
    return 0
end

local function spotVector(row)
    return vector3(tonumber(row.x) or 0.0, tonumber(row.y) or 0.0, tonumber(row.z) or 0.0)
end

local function isNearCoords(src, coords, maxDist)
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - coords) <= maxDist
end

local function upsertFarmAt(source, drugKey, coords)
    local drug = drugConfig(drugKey)
    if not drug then return false, 'Ugyldigt stof.' end

    local giveItem = drug.bladeItem or drug.rawItem
    local farm = State.farms and State.farms[1]

    if farm then
        MySQL.update.await([[
            UPDATE iddrugnsale_farms
            SET label = ?, drug_key = ?, x = ?, y = ?, z = ?, give_item = ?, give_raw = 1, enabled = 1, show_marker = 1
            WHERE id = ?
        ]], {
            ('Farm %s'):format(drug.label),
            drugKey,
            coords.x, coords.y, coords.z,
            giveItem,
            farm.id,
        })
        return true, farm.id
    end

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_farms (label, drug_key, x, y, z, amount_min, amount_max, cooldown, enabled, give_raw, give_item, show_marker)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 1, ?, 1)
    ]], {
        ('Farm %s'):format(drug.label),
        drugKey,
        coords.x, coords.y, coords.z,
        Config.DefaultFarm.amountMin,
        Config.DefaultFarm.amountMax,
        Config.DefaultFarm.cooldown,
        giveItem,
    })

    return true, id
end

local function upsertProcessAt(source, drugKey, coords)
    local drug = drugConfig(drugKey)
    if not drug then return false, 'Ugyldigt stof.' end

    local inputItem = drug.bladeItem or drug.rawItem
    local outputItem = drugLooseItem(drug)
    local point = State.process and State.process[1]

    if point then
        MySQL.update.await([[
            UPDATE iddrugnsale_process
            SET label = ?, drug_key = ?, x = ?, y = ?, z = ?, input_item = ?, output_item = ?, enabled = 1, show_marker = 1
            WHERE id = ?
        ]], {
            ('Omdan %s'):format(drug.label),
            drugKey,
            coords.x, coords.y, coords.z,
            inputItem,
            outputItem,
            point.id,
        })
        return true, point.id
    end

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_process (label, drug_key, x, y, z, input_amount, output_amount, duration, enabled, input_item, output_item, show_marker)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 1)
    ]], {
        ('Omdan %s'):format(drug.label),
        drugKey,
        coords.x, coords.y, coords.z,
        Config.DefaultProcess.inputAmount,
        Config.DefaultProcess.outputAmount,
        Config.DefaultProcess.duration,
        inputItem,
        outputItem,
    })

    return true, id
end

lib.callback.register('iddrugnsale:canFarm', function(source, farmId)
    local farm = getFarmById(farmId)
    if not farm or not isEnabled(farm.enabled) then
        return { ok = false, message = 'Denne farm er lukket.' }
    end

    local drug = drugConfig(farm.drug_key)
    if not drug then
        return { ok = false, message = 'Ugyldigt stoftype på farmen.' }
    end

    if not isNearCoords(source, spotVector(farm), Config.InteractDistance + 2.0) then
        return { ok = false, message = 'Du er for langt væk.' }
    end

    local key = ('farm:%s:%s'):format(farmId, source)
    local now = os.time()
    if farmCooldowns[key] and farmCooldowns[key] > now then
        return { ok = false, message = ('Vent %ds før du kan farme igen.'):format(farmCooldowns[key] - now) }
    end

    local item = farmRewardItem(farm, drug)
    if not item or item == '' then
        return { ok = false, message = 'Farmen mangler et gyldigt item.' }
    end

    local amountMax = math.max(tonumber(farm.amount_min) or 1, tonumber(farm.amount_max) or 1)
    if isProductDrugItem(item) then
        if not DrugUtils.canCarryProduct(source, item, drug.label, amountMax) then
            return { ok = false, message = 'Du har ikke plads i inventory.' }
        end
    elseif not exports.ox_inventory:CanCarryItem(source, item, amountMax) then
        return { ok = false, message = 'Du har ikke plads i inventory.' }
    end

    return {
        ok = true,
        item = item,
        label = itemLabel(item),
    }
end)

lib.callback.register('iddrugnsale:collectFarm', function(source, farmId)
    local farm = getFarmById(farmId)
    if not farm or not isEnabled(farm.enabled) then
        return { ok = false, message = 'Denne farm er lukket.' }
    end

    local drug = drugConfig(farm.drug_key)
    if not drug then
        return { ok = false, message = 'Ugyldigt stoftype på farmen.' }
    end

    if not isNearCoords(source, spotVector(farm), Config.InteractDistance + 2.0) then
        return { ok = false, message = 'Du er for langt væk.' }
    end

    local key = ('farm:%s:%s'):format(farmId, source)
    local now = os.time()
    if farmCooldowns[key] and farmCooldowns[key] > now then
        return { ok = false, message = ('Vent %ds før du kan farme igen.'):format(farmCooldowns[key] - now) }
    end

    local minAmount = math.min(tonumber(farm.amount_min) or 1, tonumber(farm.amount_max) or 1)
    local maxAmount = math.max(tonumber(farm.amount_min) or 1, tonumber(farm.amount_max) or 1)
    local amount = math.random(minAmount, maxAmount)
    local item = farmRewardItem(farm, drug)
    local label = itemLabel(item)

    if isProductDrugItem(item) then
        if not DrugUtils.canCarryProduct(source, item, drug.label, amount) then
            return { ok = false, message = 'Du har ikke plads i inventory.' }
        end

        local added, reason = DrugUtils.addProductGrams(source, item, drug.label, amount)
        if not added then
            local detail = reason == 'no_space' and 'Du har ikke plads i inventory.'
                or reason == 'add_failed' and 'ox_inventory kunne ikke oprette item.'
                or 'Ukendt fejl.'
            return { ok = false, message = ('Kunne ikke give %s. %s'):format(DrugUtils.productLabel(drug.label), detail) }
        end

        farmCooldowns[key] = now + (tonumber(farm.cooldown) or 45)

        return {
            ok = true,
            message = ('Du fik %s'):format(DrugUtils.productLabel(drug.label)),
            item = item,
            amount = amount,
        }
    end

    if not exports.ox_inventory:CanCarryItem(source, item, amount) then
        return { ok = false, message = 'Du har ikke plads i inventory.' }
    end

    local added = exports.ox_inventory:AddItem(source, item, amount)
    if not added then
        return { ok = false, message = ('Kunne ikke give %s — tjek at item findes i ox_inventory.'):format(item) }
    end

    farmCooldowns[key] = now + (tonumber(farm.cooldown) or 45)

    return {
        ok = true,
        message = ('Du fik %dx %s'):format(amount, label),
        item = item,
        amount = amount,
    }
end)

lib.callback.register('iddrugnsale:canProcess', function(source, processId)
    local point = getProcessById(processId)
    if not point or not isEnabled(point.enabled) then
        return { ok = false, message = 'Omdanning er lukket.' }
    end

    local drug = drugConfig(point.drug_key)
    if not drug then
        return { ok = false, message = 'Ugyldigt stoftype på omdan-punktet.' }
    end

    if not isNearCoords(source, spotVector(point), Config.InteractDistance + 2.0) then
        return { ok = false, message = 'Du er for langt væk.' }
    end

    local inputItem, _ = processItems(point, drug)
    local outputItem = drugLooseItem(drug)
    local inputAmount = math.max(1, tonumber(point.input_amount) or Config.DefaultProcess.inputAmount)
    local outputAmount = math.max(1, tonumber(point.output_amount) or Config.DefaultProcess.outputAmount)

    local has = countItem(source, inputItem)
    if has < inputAmount then
        return {
            ok = false,
            message = ('Du mangler %dx %s (har %d).'):format(inputAmount, itemLabel(inputItem), has),
        }
    end

    if not DrugUtils.canCarryProduct(source, outputItem, drug.label, outputAmount) then
        return { ok = false, message = ('Du har ikke plads til %s.'):format(DrugUtils.productLabel(drug.label)) }
    end

    return {
        ok = true,
        inputItem = inputItem,
        outputItem = outputItem,
        inputLabel = itemLabel(inputItem),
        outputLabel = DrugUtils.productLabel(drug.label),
    }
end)

lib.callback.register('iddrugnsale:processDrug', function(source, processId)
    local point = getProcessById(processId)
    if not point or not isEnabled(point.enabled) then
        return { ok = false, message = 'Omdanning er lukket.' }
    end

    local drug = drugConfig(point.drug_key)
    if not drug then
        return { ok = false, message = 'Ugyldigt stoftype på omdan-punktet.' }
    end

    if not isNearCoords(source, spotVector(point), Config.InteractDistance + 2.0) then
        return { ok = false, message = 'Du er for langt væk.' }
    end

    local inputItem, _ = processItems(point, drug)
    local outputItem = drugLooseItem(drug)
    local inputAmount = math.max(1, tonumber(point.input_amount) or Config.DefaultProcess.inputAmount)
    local outputAmount = math.max(1, tonumber(point.output_amount) or Config.DefaultProcess.outputAmount)

    local has = countItem(source, inputItem)
    if has < inputAmount then
        return {
            ok = false,
            message = ('Du mangler %dx %s (har %d).'):format(inputAmount, itemLabel(inputItem), has),
        }
    end

    if not DrugUtils.canCarryProduct(source, outputItem, drug.label, outputAmount) then
        return { ok = false, message = ('Du har ikke plads til %s.'):format(DrugUtils.productLabel(drug.label)) }
    end

    if not exports.ox_inventory:RemoveItem(source, inputItem, inputAmount) then
        return { ok = false, message = ('Kunne ikke fjerne %dx %s fra inventory.'):format(inputAmount, itemLabel(inputItem)) }
    end

    local added, reason = DrugUtils.addProductGrams(source, outputItem, drug.label, outputAmount)
    if not added then
        exports.ox_inventory:AddItem(source, inputItem, inputAmount)
        local detail = reason == 'no_space' and 'Du har ikke plads i inventory.'
            or reason == 'add_failed' and 'ox_inventory kunne ikke oprette item.'
            or 'Ukendt fejl.'
        return { ok = false, message = ('Kunne ikke give %s. %s'):format(DrugUtils.productLabel(drug.label), detail) }
    end

    return {
        ok = true,
        message = ('Omdannet %dx %s → %s'):format(
            inputAmount, itemLabel(inputItem),
            DrugUtils.productLabel(drug.label)
        ),
    }
end)

RegisterNetEvent('iddrugnsale:sellDrug', function(target, drugKey, bagGrams, bagCount, offerPrice)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    bagGrams = math.floor(tonumber(bagGrams) or 0)
    bagCount = math.floor(tonumber(bagCount) or 0)
    offerPrice = math.floor(tonumber(offerPrice) or 0)

    if bagGrams < Config.BagMinGrams or bagGrams > Config.BagMaxGrams then return end
    if bagCount < 1 or offerPrice < 1 then return end

    local deal = activeNpcDeals[src]
    local maxNpcBuy = deal and deal.maxNpcBuy or getEffectiveMaxNpcBuy(src)
    if bagCount > maxNpcBuy then
        TriggerClientEvent('iddrugnsale:sellResult', src, {
            ok = false,
            message = ('NPC kan max købe %dx ad gangen.'):format(maxNpcBuy),
        })
        return
    end

    local saleKey = npcSaleKeyFromTarget(target)
    if not deal or deal.saleKey ~= saleKey or deal.bagCount ~= bagCount then
        TriggerClientEvent('iddrugnsale:sellResult', src, {
            ok = false,
            message = 'Køberen har ændret mening — prøv at åbne salget igen.',
        })
        return
    end

    if not isNearNpcCoords(src, target) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Du er for langt væk fra personen.' })
        return
    end

    if hasSoldToNpc(src, target) then
        TriggerClientEvent('iddrugnsale:sellResult', src, {
            ok = false,
            message = 'Du har allerede solgt til denne mand',
        })
        return
    end

    local drug = drugConfig(drugKey)
    if not drug then return end

    if not DrugUtils.hasFilledBags(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = 'Du skal pakke stoffet i en pølsemandspose først — løse gram kan ikke sælges.',
        })
        return
    end

    local priceCfg = getBagPriceCfg(drugKey, bagGrams)
    if offerPrice < priceCfg.minPrice or offerPrice > priceCfg.maxPrice then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Ugyldig pris for denne pose.' })
        return
    end

    local has = DrugUtils.countFilledBagsBySize(src, drugKey, bagGrams)
    if has < bagCount then
        TriggerClientEvent('iddrugnsale:sellResult', src, {
            ok = false,
            message = ('Køberen vil have %dx %s — du har kun %dx.'):format(bagCount, drug.label, has),
        })
        return
    end

    local acceptChance = getAcceptChance(src, priceCfg.basePrice, offerPrice)
    if math.random(100) > acceptChance then
        rollNpcPoliceCall(src, 'reject', target)
        TriggerClientEvent('iddrugnsale:sellResult', src, {
            ok = false,
            message = 'Køberen afviser prisen. Prøv lavere.',
        })
        return
    end

    if not DrugUtils.removeFilledBagsBySize(src, drugKey, bagGrams, bagCount) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Kunne ikke fjerne stof fra inventory.' })
        return
    end

    local basePayout = offerPrice * bagCount
    local payout = applyStreetPriceBonus(src, basePayout)
    local paid, payReason = givePayoutItem(src, payout)
    if not paid then
        DrugUtils.addSellUnits(src, drugKey, bagCount)

        local detail = payReason == 'no_space' and 'Du har ikke plads til kontanter i inventory.'
            or payReason == 'add_failed' and 'Kunne ikke give penge-item.'
            or 'Ukendt fejl.'
        TriggerClientEvent('iddrugnsale:sellResult', src, {
            ok = false,
            message = detail,
        })
        return
    end

    markSoldToNpc(src, target)
    activeNpcDeals[src] = nil
    awardStreetSalePoints(src)
    rollNpcPoliceCall(src, 'success', target)

    local payoutMsg = payout
    if payout > basePayout then
        payoutMsg = ('%s (+%s skill bonus)'):format(payout, payout - basePayout)
    end

    TriggerClientEvent('iddrugnsale:sellResult', src, {
        ok = true,
        message = ('Solgt %dx %s — modtaget %s kr kontanter.'):format(bagCount, drug.label, payoutMsg),
        payout = payout,
        netId = npcNetIdFromTarget(target),
    })
end)

RegisterNetEvent('iddrugnsale:bagProduct', function(slotId, bagCount)
    local src = source
    bagCount = math.floor(tonumber(bagCount) or 0)
    slotId = tonumber(slotId)
    local gramsPerBag = Config.BagMinGrams or 1

    if not slotId then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Ugyldigt inventory-slot.' })
        return
    end

    if bagCount < 1 then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Vælg mindst én pose.' })
        return
    end

    local slot = DrugUtils.findProductSlot(src, slotId)
    if not slot then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Kunne ikke finde stoffet i inventory.' })
        return
    end

    local drugKey = DrugUtils.drugKeyFromLooseItem(slot.name)
    if not drugKey then return end

    local available = DrugUtils.getSlotGrams(slot)
    local emptyPoses = DrugUtils.countEmptyPoses(src)
    local totalGrams = bagCount * gramsPerBag

    if available < totalGrams then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Du har kun %dg i denne bunke — kan max lave %d poser.'):format(available, math.floor(available / gramsPerBag)),
        })
        return
    end

    if emptyPoses < bagCount then
        TriggerClientEvent('ox_lib:notify', src, {
            type = 'error',
            description = ('Du mangler tomme poser — har %d, skal bruge %d.'):format(emptyPoses, bagCount),
        })
        return
    end

    if not DrugUtils.canCarrySellUnits(src, drugKey, bagCount) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Du har ikke plads til alt stoffet i inventory.' })
        return
    end

    if not DrugUtils.removeProductGramsFromSlot(src, slotId, totalGrams) then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Kunne ikke tage gram fra inventory.' })
        return
    end

    if not DrugUtils.removeEmptyPoses(src, bagCount) then
        DrugUtils.addProductGrams(src, slot.name, Config.Drugs[drugKey].label, totalGrams)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Kunne ikke bruge tomme poser.' })
        return
    end

    if not DrugUtils.addSellUnits(src, drugKey, bagCount) then
        DrugUtils.addProductGrams(src, slot.name, Config.Drugs[drugKey].label, totalGrams)
        exports.ox_inventory:AddItem(src, Config.BagItem, bagCount)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Kunne ikke pakke stoffet.' })
        return
    end

    local drugLabel = Config.Drugs[drugKey].label
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = bagCount == 1
            and ('Pakket 1x %s.'):format(drugLabel)
            or ('Pakket %dx %s.'):format(bagCount, drugLabel),
    })
end)

RegisterCommand(Config.AdminCommand, function(source)
    if source == 0 then return end
    if not isAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Ingen adgang — kræver server-admin (ACE) eller ESX admin-gruppe.',
        })
        return
    end
    TriggerClientEvent('iddrugnsale:openAdmin', source)
end, false)

RegisterCommand(Config.QuickProcessCommand or 'iddrughere', function(source, args)
    if source == 0 then
        print('[iddrugnsale] /iddrughere skal bruges in-game som admin.')
        return
    end

    if not isAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Kun admin kan oprette omdan-punkter.',
        })
        return
    end

    local drugKey = normalizeDrugKey(args[1] or 'hash')
    local drug = drugKey and Config.Drugs[drugKey]
    if not drug then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Ugyldigt stof. Brug: hash, skunk eller kokain.',
        })
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local inputItem = drug.bladeItem or drug.rawItem
    local outputItem = drugLooseItem(drug)

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_process (label, drug_key, x, y, z, input_amount, output_amount, duration, enabled, input_item, output_item, show_marker)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, 1)
    ]], {
        ('Omdan %s'):format(drug.label),
        drugKey,
        coords.x, coords.y, coords.z,
        Config.DefaultProcess.inputAmount,
        Config.DefaultProcess.outputAmount,
        Config.DefaultProcess.duration,
        inputItem,
        outputItem,
    })

    loadState()
    syncAll()

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = ('Omdan-punkt #%d oprettet her (%s). Grøn markør + [E] for at omdanne.'):format(id, drug.label),
    })
end, false)

RegisterCommand(Config.QuickFarmCommand or 'iddrugfarm', function(source, args)
    if source == 0 then return end
    if not isAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Kun admin.' })
        return
    end

    local drugKey = normalizeDrugKey(args[1] or 'hash')
    if not drugKey then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Brug: hash, skunk eller kokain.' })
        return
    end

    local coords = GetEntityCoords(GetPlayerPed(source))
    local ok, id = upsertFarmAt(source, drugKey, coords)
    if not ok then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = id })
        return
    end

    loadState()
    syncAll()
    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = ('Farm #%s sat her — stå på markøren og tryk [E] for at høste.'):format(id),
    })
end, false)

RegisterCommand(Config.QuickSetupCommand or 'iddrugsetup', function(source, args)
    if source == 0 then return end
    if not isAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Kun admin.' })
        return
    end

    local drugKey = normalizeDrugKey(args[1] or 'hash')
    if not drugKey then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Brug: /iddrugsetup hash' })
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local farmOk, farmId = upsertFarmAt(source, drugKey, coords)
    local processCoords = vector3(coords.x + 1.2, coords.y, coords.z)
    local processOk, processId = upsertProcessAt(source, drugKey, processCoords)

    if not farmOk or not processOk then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Kunne ikke oprette lab-punkter.' })
        return
    end

    loadState()
    syncAll()

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = ('Lab klar! Farm #%s + Omdan #%s (%s). Gå til markørerne og tryk [E].'):format(farmId, processId, drugKey),
        duration = 10000,
    })
end, false)

RegisterCommand(Config.MoveSpotCommand or 'iddrugmove', function(source, args)
    if source == 0 then return end
    if not isAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Kun admin.' })
        return
    end

    local kind = (args[1] or 'process'):lower()
    if kind ~= 'process' and kind ~= 'farm' then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Brug: /iddrugmove process eller /iddrugmove farm' })
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local rows = kind == 'farm' and State.farms or State.process
    local closest, closestDist

    for _, row in ipairs(rows or {}) do
        local dist = #(coords - vector3(tonumber(row.x) or 0, tonumber(row.y) or 0, tonumber(row.z) or 0))
        if not closestDist or dist < closestDist then
            closest = row
            closestDist = dist
        end
    end

    if not closest then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = kind == 'process'
                and 'Ingen omdan-punkter — kør /iddrugsetup hash'
                or 'Ingen farme — kør /iddrugfarm hash',
        })
        return
    end

    local tableName = kind == 'farm' and 'iddrugnsale_farms' or 'iddrugnsale_process'
    MySQL.update.await(('UPDATE %s SET x = ?, y = ?, z = ?, show_marker = 1 WHERE id = ?'):format(tableName), {
        coords.x, coords.y, coords.z, closest.id,
    })

    loadState()
    syncAll()

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = ('Punkt #%d flyttet til din position (%.1f, %.1f, %.1f)'):format(closest.id, coords.x, coords.y, coords.z),
    })
end, false)

RegisterCommand(Config.QuickDealerCommand or 'iddrugdealer', function(source)
    if source == 0 then return end
    if not isAdmin(source) then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Kun admin kan oprette dealere.' })
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local id = MySQL.insert.await([[
        INSERT INTO iddrugnsale_dealers (label, model, x, y, z, heading, enabled)
        VALUES (?, ?, ?, ?, ?, ?, 1)
    ]], {
        'Dealer',
        Config.DefaultDealer.model,
        coords.x, coords.y, coords.z,
        heading,
    })

    loadState()
    syncAll()

    TriggerClientEvent('ox_lib:notify', source, {
        type = 'success',
        description = ('Salgs-NPC oprettet her (#' .. id .. ') — stå ved NPC og tryk [E] Sælg Stoffer'),
    })
end, false)

RegisterCommand(Config.DebugCommand or 'iddrugdebug', function(source)
    if source == 0 then return end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local lines = {
        ('Din position: %.2f, %.2f, %.2f'):format(coords.x, coords.y, coords.z),
        ('Farme: %d | Omdan: %d | Dealere: %d'):format(#(State.farms or {}), #(State.process or {}), #(State.dealers or {})),
    }

    for _, farm in ipairs(State.farms or {}) do
        local dist = #(coords - spotVector(farm))
        lines[#lines + 1] = ('Farm #%s %s — %.1fm (%s)'):format(
            farm.id, farm.label or 'Farm', dist, farm.drug_key or '?'
        )
    end

    local nearestDist, nearestLabel
    for _, point in ipairs(State.process or {}) do
        local dist = #(coords - spotVector(point))
        local label = ('Omdan #%s %s — %.1fm (%s)'):format(point.id, point.label or 'Omdan', dist, point.drug_key or '?')
        lines[#lines + 1] = label
        if not nearestDist or dist < nearestDist then
            nearestDist = dist
            nearestLabel = label
        end
    end

    if nearestLabel then
        lines[#lines + 1] = 'Tættest omdan: ' .. nearestLabel
    elseif #(State.process or {}) == 0 then
        lines[#lines + 1] = 'Ingen omdan — kør /iddrugsetup hash hvor du står'
    end

    if #(State.farms or {}) > 0 then
        local farm = State.farms[1]
        local farmDist = #(coords - spotVector(farm))
        if farmDist > Config.InteractDistance then
            lines[#lines + 1] = ('Farm er %.1fm væk — kør /iddrugmove farm eller /iddrugsetup hash'):format(farmDist)
        end
    end

    for _, dealer in ipairs(State.dealers or {}) do
        local dist = #(coords - spotVector(dealer))
        lines[#lines + 1] = ('Dealer #%s %s — %.1fm'):format(dealer.id, dealer.label or 'Dealer', dist)
    end

    if #(State.dealers or {}) == 0 then
        lines[#lines + 1] = 'Ingen dealere — admin: /iddrugdealer hvor du står'
    end

    for _, line in ipairs(lines) do
        TriggerClientEvent('ox_lib:notify', source, { type = 'inform', description = line, duration = 9000 })
    end
end, false)
