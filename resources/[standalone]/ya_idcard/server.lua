local ESX = exports['es_extended']:getSharedObject()

local function splitName(fullname)
    fullname = fullname or 'Ukendt Ukendt'
    local first, last = fullname:match('^(%S+)%s+(.+)$')
    return first or fullname, last or ''
end

local function today()
    return os.date('%d/%m/%Y')
end

local function validUntil()
    local year = tonumber(os.date('%Y')) + Config.ValidYears
    return os.date('%d/%m/') .. tostring(year)
end

local function getPlayerData(identifier)
    local user = MySQL.single.await('SELECT firstname, lastname, dateofbirth, sex FROM users WHERE identifier = ?', { identifier })
    if not user then return nil end

    local fullname = ((user.firstname or '') .. ' ' .. (user.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    local firstName, lastName = splitName(fullname)

    return {
        firstName = firstName,
        lastName = lastName,
        fullName = fullname ~= '' and fullname or 'Ukendt',
        dob = user.dateofbirth or 'Ukendt',
        sex = user.sex == 'f' and 'Kvinde' or 'Mand',
        address = Config.DefaultAddress,
        issuer = Config.Issuer,
        issued = today(),
        expires = validUntil(),
        cardId = ('SA%s'):format(string.sub(identifier:gsub('%W', ''), -8):upper()),
        ownerIdentifier = identifier
    }
end

local function getLicenses(identifier)
    local rows = MySQL.query.await('SELECT type FROM user_licenses WHERE owner = ?', { identifier }) or {}
    local categories, seen = {}, {}

    local function add(cat)
        if not seen[cat] then
            seen[cat] = true
            categories[#categories + 1] = cat
        end
    end

    if Config.AutoGiveCategoryB then add('B') end

    local map = Config.LicenseTypeToCategory or {}
    for _, row in pairs(rows) do
        local licenseType = tostring(row.type):lower()
        local cat = map[licenseType]
        if cat then add(cat) end
    end

    return categories
end

local function ensureStarterLicenses(identifier)
    identifier = tostring(identifier or '')
    if identifier == '' then return end
    local starters = Config.StarterLicenses or { 'drive' }
    for _, licenseType in ipairs(starters) do
        local exists = MySQL.scalar.await('SELECT 1 FROM user_licenses WHERE owner = ? AND type = ? LIMIT 1', { identifier, licenseType })
        if not exists then
            MySQL.insert.await('INSERT INTO user_licenses (type, owner) VALUES (?, ?)', { licenseType, identifier })
        end
    end
end

local function buildCardData(source, metadata)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local base = getPlayerData(xPlayer.identifier)
    if not base then return nil end

    -- Metadata på selve itemet bestemmer identiteten på kortet, så stjålne/givne kort viser ejerens info.
    -- Licenser opdateres dog fra databasen, hvis det er ejerens eget kort.
    if type(metadata) == 'table' and next(metadata) then
        base.firstName = metadata.firstName or base.firstName
        base.lastName = metadata.lastName or base.lastName
        base.fullName = metadata.fullName or base.fullName
        base.dob = metadata.dob or base.dob
        base.sex = metadata.sex or base.sex
        base.address = metadata.address or base.address
        base.issuer = metadata.issuer or base.issuer
        base.issued = metadata.issued or base.issued
        base.expires = metadata.expires or base.expires
        base.cardId = metadata.cardId or base.cardId
        base.ownerIdentifier = metadata.ownerIdentifier or metadata.identifier or base.ownerIdentifier

        -- VIGTIG FIX:
        -- Brug IKKE gamle metadata.categories, fordi gamle items kan have gemt Kategori B som aktiv.
        -- Licenser læses altid direkte fra user_licenses, så kortet kun viser rigtige kørekort.
        base.categories = getLicenses(base.ownerIdentifier or xPlayer.identifier)
    else
        base.categories = getLicenses(xPlayer.identifier)
    end

    base.categoryLabels = Config.Categories
    return base
end

local function ensureDriverLicenseItem(source)
    if Config.AutoGiveDriverLicenseItem == false then return end
    local itemName = Config.DriverLicenseItem or 'driver_license'
    local count = exports.ox_inventory:Search(source, 'count', itemName) or 0
    if count > 0 then return end
    local cardData = buildCardData(source)
    if not cardData then return end
    exports.ox_inventory:AddItem(source, itemName, 1, {
        fullName = cardData.fullName,
        dob = cardData.dob,
        ownerIdentifier = cardData.ownerIdentifier,
        categories = cardData.categories
    })
end

local function ensureCard(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local count = exports.ox_inventory:Search(source, 'count', Config.ItemName) or 0
    if count > 0 then return end

    local cardData = buildCardData(source)
    if not cardData then return end

    exports.ox_inventory:AddItem(source, Config.ItemName, 1, cardData)
end

local function showCard(source, cardData)
    TriggerClientEvent('ya_idcard:client:showCard', source, cardData)

    if Config.ShowDistance and Config.ShowDistance > 0 then
        local playerPed = GetPlayerPed(source)
        local playerCoords = GetEntityCoords(playerPed)

        for _, playerId in pairs(ESX.GetPlayers()) do
            if playerId ~= source then
                local targetPed = GetPlayerPed(playerId)
                local targetCoords = GetEntityCoords(targetPed)
                if #(playerCoords - targetCoords) <= Config.ShowDistance then
                    TriggerClientEvent('ya_idcard:client:showCard', playerId, cardData)
                end
            end
        end
    end
end

AddEventHandler('esx:playerLoaded', function(playerId)
    SetTimeout(2500, function()
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if not xPlayer then return end
        ensureStarterLicenses(xPlayer.identifier)
        if Config.AutoGiveOnJoin then
            ensureCard(playerId)
        end
        ensureDriverLicenseItem(playerId)
    end)
end)

local function resolveUseSlot(source, slot, itemName)
    slot = tonumber(slot)
    if slot then
        local item = exports.ox_inventory:GetSlot(source, slot)
        if item and item.name == itemName then
            return item.metadata
        end
    end
    local items = exports.ox_inventory:Search(source, 'slots', itemName) or {}
    local slots = items[itemName]
    if type(slots) == 'table' and slots[1] then
        return slots[1].metadata
    end
    return nil
end

RegisterNetEvent('ya_idcard:server:useCard', function(slot)
    local src = source
    local metadata = resolveUseSlot(src, slot, Config.ItemName)
    local cardData = buildCardData(src, metadata)
    if not cardData then
        print(('[ya_idcard] Kunne ikke bygge kortdata. Source: %s'):format(src))
        return
    end
    showCard(src, cardData)
end)

-- Backup hvis itemet bliver brugt gennem ESX i stedet for ox_inventory export.
ESX.RegisterUsableItem(Config.ItemName, function(source)
    local cardData = buildCardData(source)
    if cardData then showCard(source, cardData) end
end)

RegisterNetEvent('ya_idcard:server:useDriverLicense', function(slot)
    local src = source
    local itemName = Config.DriverLicenseItem or 'driver_license'
    local metadata = resolveUseSlot(src, slot, itemName)
    local cardData = buildCardData(src, metadata)
    if not cardData then return end
    cardData.licenseOnly = true
    showCard(src, cardData)
end)

ESX.RegisterUsableItem(Config.DriverLicenseItem or 'driver_license', function(source)
    local cardData = buildCardData(source)
    if cardData then
        cardData.licenseOnly = true
        showCard(source, cardData)
    end
end)

RegisterNetEvent('ya_idcard:server:testCard', function()
    local source = source
    local cardData = buildCardData(source)
    if cardData then showCard(source, cardData) end
end)

RegisterCommand('giveidcard', function(source)
    if source == 0 then return end
    ensureCard(source)
end, false)

exports('RefreshIdCard', function(source)
    local data = buildCardData(source)
    if not data then return end
    local idName = Config.ItemName or 'id_card'
    local licName = Config.DriverLicenseItem or 'driver_license'
    if (exports.ox_inventory:Search(source, 'count', idName) or 0) > 0 then
        exports.ox_inventory:RemoveItem(source, idName, 1)
        exports.ox_inventory:AddItem(source, idName, 1, data)
    end
    if (exports.ox_inventory:Search(source, 'count', licName) or 0) > 0 then
        exports.ox_inventory:RemoveItem(source, licName, 1)
        exports.ox_inventory:AddItem(source, licName, 1, {
            fullName = data.fullName,
            dob = data.dob,
            ownerIdentifier = data.ownerIdentifier,
            categories = data.categories
        })
    end
end)

exports('EnsureStarterLicenses', ensureStarterLicenses)
