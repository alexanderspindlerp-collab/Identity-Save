local ESX = exports['es_extended']:getSharedObject()

WS = WS or {}

local OnDuty = {}

local function repairCfg()
    return Config.Repair or {}
end

local function mechanicCfg()
    return repairCfg().Mechanic or {}
end

local function selfCfg()
    return repairCfg().SelfRepair or {}
end

local function itemCatalog()
    return repairCfg().Items or {}
end

local function catalogByName()
    local map = {}
    for i = 1, #(itemCatalog()) do
        local entry = itemCatalog()[i]
        if entry.name then
            map[entry.name] = entry
        end
    end
    return map
end

function WS.countOnlineMechanics()
    local rows = MySQL.query.await([[
        SELECT m.identifier
        FROM ya_workshop_members m
        JOIN ya_workshop_companies c ON c.id = m.company_id
        WHERE c.closed = 0
    ]]) or {}

    local count = 0
    for i = 1, #rows do
        if ESX.GetPlayerFromIdentifier(rows[i].identifier) then
            count = count + 1
        end
    end
    return count
end

function WS.isOnDuty(src)
    local identifier = WS.getIdentifier(src)
    return identifier ~= nil and OnDuty[identifier] ~= nil
end

function WS.getOnDutyServices()
    local companies = {}
    local seen = {}

    for identifier, data in pairs(OnDuty) do
        local companyId = data.companyId
        if companyId and not seen[companyId] then
            seen[companyId] = {
                companyId = companyId,
                companyName = data.companyName or 'Værksted',
                companyType = data.companyType or 'mechanic',
                color = data.companyColor or '#14b8a6',
                onDutyCount = 0,
                staff = {},
            }
        end
        if companyId and seen[companyId] then
            seen[companyId].onDutyCount = seen[companyId].onDutyCount + 1
            seen[companyId].staff[#seen[companyId].staff + 1] = {
                name = data.name or 'Mekaniker',
                source = data.source,
            }
        end
    end

    for _, company in pairs(seen) do
        companies[#companies + 1] = company
    end

    table.sort(companies, function(a, b)
        return (a.companyName or '') < (b.companyName or '')
    end)

    return companies
end

local function setDutyState(src, onDuty)
    local row, err = WS.requireMember(src)
    if not row then
        return false, err or 'Ingen adgang.'
    end

    local identifier = row.identifier
    if onDuty then
        OnDuty[identifier] = {
            source = src,
            companyId = row.company_id,
            companyName = row.company_name,
            companyType = row.company_type,
            companyColor = row.company_color,
            name = row.character_name or WS.getCharacterName(ESX.GetPlayerFromId(src)),
            since = os.time(),
        }
        TriggerClientEvent('ya_workshop:dutyState', src, true, OnDuty[identifier])
        return true, 'Du er nu på arbejde.'
    end

    OnDuty[identifier] = nil
    TriggerClientEvent('ya_workshop:dutyState', src, false, nil)
    return true, 'Du er gået af arbejde.'
end

local function playerNearVehicle(src, netId, maxDistance)
    netId = tonumber(netId)
    if not netId then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    local pCoords = GetEntityCoords(ped)
    local vCoords = GetEntityCoords(vehicle)
    return #(pCoords - vCoords) <= (tonumber(maxDistance) or 6.0)
end

local function getRepairItemCount(src, itemName)
    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:Search(src, 'count', itemName) or 0
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return 0 end
    local item = xPlayer.getInventoryItem and xPlayer.getInventoryItem(itemName)
    return item and item.count or 0
end

local function removeRepairItem(src, itemName, count)
    count = tonumber(count) or 1
    if count <= 0 then return true end

    if GetResourceState('ox_inventory') == 'started' then
        return exports.ox_inventory:RemoveItem(src, itemName, count) == true
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    if xPlayer.removeInventoryItem then
        xPlayer.removeInventoryItem(itemName, count)
        return true
    end
    return false
end

function WS.getMechanicRepairInventory(src)
    local catalog = itemCatalog()
    local items = {}

    for i = 1, #catalog do
        local entry = catalog[i]
        local count = getRepairItemCount(src, entry.name)
        if count > 0 then
            items[#items + 1] = {
                name = entry.name,
                label = entry.label or entry.name,
                desc = entry.desc or '',
                count = count,
                zones = entry.zones or {},
                power = tonumber(entry.power) or 25,
                icon = entry.icon or 'part',
            }
        end
    end

    return items
end

local function chargePlayer(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false, 'Spiller ikke fundet.' end

    local bank = xPlayer.getAccount and xPlayer.getAccount('bank')
    local bankMoney = bank and bank.money or 0
    local cash = xPlayer.getMoney and xPlayer.getMoney() or 0

    if bankMoney >= amount then
        xPlayer.removeAccountMoney('bank', amount, 'ya_workshop_self_repair')
        return true
    end
    if cash >= amount then
        xPlayer.removeMoney(amount, 'ya_workshop_self_repair')
        return true
    end

    return false, ('Du har ikke råd (%s kr).'):format(selfCfg().PriceDisplay or tostring(amount))
end

local function findVehicleOwner(plate)
    plate = WS.normalizePlate(plate)
    if plate == '' then return nil end
    local row = MySQL.single.await(
        'SELECT owner, plate, vehicle FROM owned_vehicles WHERE REPLACE(UPPER(TRIM(plate)), " ", "") = ? LIMIT 1',
        { plate }
    )
    return row
end

function WS.applyRepairToProps(props, damage, placements)
    props = props or {}
    damage = damage or {}
    placements = placements or {}

    local engineDamage = math.max(0, 100 - (tonumber(damage.engine) or 100))
    local bodyDamage = math.max(0, 100 - (tonumber(damage.body) or 100))
    local tankDamage = math.max(0, 100 - (tonumber(damage.tank) or 100))
    local wheelDamage = math.max(0, 100 - (tonumber(damage.wheels) or 100))

    local catalog = catalogByName()
    local fullRepair = false

    for i = 1, #placements do
        local placement = placements[i]
        local entry = catalog[placement.name]
        if entry then
            local zone = placement.zone or 'universal'
            local power = tonumber(entry.power) or 0
            if zone == 'universal' or (entry.zones and power >= 100) then
                fullRepair = fullRepair or power >= 100
            end
            if zone == 'engine' or (zone == 'universal' and entry.zones and entry.zones[1]) then
                for z = 1, #(entry.zones or {}) do
                    if entry.zones[z] == 'engine' or entry.zones[z] == 'universal' then
                        engineDamage = math.max(0, engineDamage - power)
                    end
                end
            end
            if zone == 'body' then
                bodyDamage = math.max(0, bodyDamage - power)
            elseif zone == 'engine' then
                engineDamage = math.max(0, engineDamage - power)
            elseif zone == 'tank' then
                tankDamage = math.max(0, tankDamage - power)
            elseif zone == 'wheels' then
                wheelDamage = math.max(0, wheelDamage - power)
            elseif zone == 'universal' then
                engineDamage = math.max(0, engineDamage - power)
                bodyDamage = math.max(0, bodyDamage - power)
                tankDamage = math.max(0, tankDamage - power)
                wheelDamage = math.max(0, wheelDamage - power)
            end
        end
    end

    if fullRepair or (#placements > 0 and engineDamage <= 0 and bodyDamage <= 0 and tankDamage <= 0 and wheelDamage <= 0) then
        props.engineHealth = 1000.0
        props.bodyHealth = 1000.0
        props.tankHealth = 1000.0
        props.dirtLevel = 0.0
        if props.tyreBurst then
            for k in pairs(props.tyreBurst) do
                props.tyreBurst[k] = false
            end
        end
        if props.windowsBroken then
            for k in pairs(props.windowsBroken) do
                props.windowsBroken[k] = false
            end
        end
        if props.doorsBroken then
            for k in pairs(props.doorsBroken) do
                props.doorsBroken[k] = false
            end
        end
        return props, true
    end

    local engineHealth = tonumber(props.engineHealth) or 1000.0
    local bodyHealth = tonumber(props.bodyHealth) or 1000.0
    local tankHealth = tonumber(props.tankHealth) or 1000.0

    props.engineHealth = math.min(1000.0, engineHealth + ((100 - engineDamage) / 100) * 200)
    props.bodyHealth = math.min(1000.0, bodyHealth + ((100 - bodyDamage) / 100) * 200)
    props.tankHealth = math.min(1000.0, tankHealth + ((100 - tankDamage) / 100) * 200)

    if wheelDamage <= 0 and props.tyreBurst then
        for k in pairs(props.tyreBurst) do
            props.tyreBurst[k] = false
        end
    end

    return props, false
end

RegisterNetEvent('ya_workshop:toggleDuty', function()
    local src = source
    local onDuty = not WS.isOnDuty(src)
    local ok, message = setDutyState(src, onDuty)
    WS.notify(src, message, ok and 'success' or 'error')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = WS.getIdentifier(src)
    if identifier and OnDuty[identifier] and OnDuty[identifier].source == src then
        OnDuty[identifier] = nil
    end
end)

ESX.RegisterServerCallback('ya_workshop:canSelfRepair', function(source, cb, netId)
    local cfg = selfCfg()
    local priceDisplay = cfg.PriceDisplay or '19.999,99'

    if WS.countOnlineMechanics() > 0 then
        cb({
            ok = false,
            message = 'Der er mekanikere online — kør til et værksted eller ring efter hjælp.',
        })
        return
    end

    if not playerNearVehicle(source, netId, 8.0) then
        cb({ ok = false, message = 'Du skal stå ved dit køretøj.' })
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 then
        cb({ ok = false, message = 'Køretøj ikke fundet.' })
        return
    end

    local plate = WS.normalizePlate(GetVehicleNumberPlateText(vehicle))
    local ownerRow = findVehicleOwner(plate)
    local identifier = WS.getIdentifier(source)
    if ownerRow and ownerRow.owner ~= identifier then
        cb({ ok = false, message = 'Du ejer ikke dette køretøj.' })
        return
    end

    cb({
        ok = true,
        price = tonumber(cfg.Price) or 20000,
        priceDisplay = priceDisplay,
        duration = tonumber(cfg.Duration) or 60000,
        plate = plate,
    })
end)

RegisterNetEvent('ya_workshop:completeSelfRepair', function(netId)
    local src = source
    local cfg = selfCfg()

    if WS.countOnlineMechanics() > 0 then
        WS.notify(src, 'Der er mekanikere online — reparation afbrudt.', 'error')
        return
    end

    if not playerNearVehicle(src, netId, 8.0) then
        WS.notify(src, 'Du er for langt væk fra bilen.', 'error')
        return
    end

    local paid, payErr = chargePlayer(src, cfg.Price or 20000)
    if not paid then
        WS.notify(src, payErr or 'Betaling fejlede.', 'error')
        return
    end

    TriggerClientEvent('ya_workshop:applyFullRepair', -1, tonumber(netId))
    TriggerClientEvent('ya_workshop:saveSelfRepairProps', src, tonumber(netId))
    WS.notify(src, ('Køretøj repareret for %s kr.'):format(cfg.PriceDisplay or '19.999,99'), 'success')
end)

ESX.RegisterServerCallback('ya_workshop:getRepairSession', function(source, cb, netId)
    local row, err = WS.requireMember(source)
    if not row then
        cb({ ok = false, message = err or 'Ingen adgang.' })
        return
    end

    if not WS.isOnDuty(source) then
        cb({ ok = false, message = 'Du skal være på arbejde (/wsduty).' })
        return
    end

    if not WS.roleCan(row, 'repair_vehicles') then
        cb({ ok = false, message = 'Ingen adgang til reparation.' })
        return
    end

    if not playerNearVehicle(source, netId, mechanicCfg().TargetDistance or 6.0) then
        cb({ ok = false, message = 'Du er for langt væk fra bilen.' })
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if not vehicle or vehicle == 0 then
        cb({ ok = false, message = 'Køretøj ikke fundet.' })
        return
    end

    local plate = WS.normalizePlate(GetVehicleNumberPlateText(vehicle))
    local ownerRow = findVehicleOwner(plate)

    cb({
        ok = true,
        plate = plate,
        vehicleLabel = GetEntityModel(vehicle),
        maxParts = tonumber(mechanicCfg().MaxParts) or 5,
        zoneLabels = repairCfg().ZoneLabels or {},
        inventory = WS.getMechanicRepairInventory(source),
        ownerName = ownerRow and WS.ownerDisplayName(ownerRow.owner) or nil,
        companyName = row.company_name,
    })
end)

RegisterNetEvent('ya_workshop:completeMechanicRepair', function(netId, damage, placements)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then
        WS.notify(src, err or 'Ingen adgang.', 'error')
        return
    end

    if not WS.isOnDuty(src) then
        WS.notify(src, 'Du skal være på arbejde.', 'error')
        return
    end

    if not WS.roleCan(row, 'repair_vehicles') then
        WS.notify(src, 'Ingen adgang.', 'error')
        return
    end

    if not playerNearVehicle(src, netId, mechanicCfg().TargetDistance or 6.0) then
        WS.notify(src, 'For langt væk fra bilen.', 'error')
        return
    end

    if type(placements) ~= 'table' or #placements == 0 then
        WS.notify(src, 'Placer mindst én del på bilen.', 'error')
        return
    end

    local maxParts = tonumber(mechanicCfg().MaxParts) or 5
    if #placements > maxParts then
        WS.notify(src, ('Maks %d dele ad gangen.'):format(maxParts), 'error')
        return
    end

    local catalog = catalogByName()
    local usage = {}

    for i = 1, #placements do
        local placement = placements[i]
        local name = placement and placement.name
        local zone = placement and placement.zone
        local entry = name and catalog[name]
        if not entry then
            WS.notify(src, 'Ugyldig del.', 'error')
            return
        end
        local allowed = false
        for z = 1, #(entry.zones or {}) do
            if entry.zones[z] == zone or entry.zones[z] == 'universal' or zone == 'universal' then
                allowed = true
                break
            end
        end
        if not allowed then
            WS.notify(src, ('%s kan ikke monteres på %s.'):format(entry.label or name, zone or '?'), 'error')
            return
        end
        usage[name] = (usage[name] or 0) + 1
    end

    for name, count in pairs(usage) do
        if getRepairItemCount(src, name) < count then
            WS.notify(src, ('Du har ikke nok %s.'):format(catalog[name].label or name), 'error')
            return
        end
    end

    for name, count in pairs(usage) do
        if not removeRepairItem(src, name, count) then
            WS.notify(src, 'Kunne ikke fjerne dele fra inventory.', 'error')
            return
        end
    end

    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    local plate = vehicle and vehicle ~= 0 and WS.normalizePlate(GetVehicleNumberPlateText(vehicle)) or ''
    local ownerRow = plate ~= '' and findVehicleOwner(plate) or nil

    TriggerClientEvent('ya_workshop:applyMechanicRepair', -1, tonumber(netId), damage, placements)

    if ownerRow then
        TriggerClientEvent('ya_workshop:requestRepairPropsSave', src, tonumber(netId), ownerRow.owner, plate)
    end

    WS.notify(src, 'Reparation udført.', 'success')
end)

ESX.RegisterServerCallback('ya_workshop:getDutyState', function(source, cb)
    local row = WS.getMemberRow(WS.getIdentifier(source))
    local identifier = row and row.identifier
    cb({
        isEmployee = row ~= nil,
        isOnDuty = identifier ~= nil and OnDuty[identifier] ~= nil,
        canRepair = row and WS.roleCan(row, 'repair_vehicles') or false,
        companyName = row and row.company_name or nil,
    })
end)

exports('GetOnDutyServices', function()
    return WS.getOnDutyServices()
end)

exports('IsMechanicOnDuty', function(src)
    return WS.isOnDuty(src)
end)

exports('GetOnlineMechanicCount', function()
    return WS.countOnlineMechanics()
end)

exports('GetActiveWorkshopServices', function()
    return WS.getOnDutyServices()
end)

RegisterNetEvent('ya_workshop:saveRepairedVehicle', function(ownerIdentifier, props)
    local src = source
    if type(props) ~= 'table' then return end

    local identifier = WS.getIdentifier(src)
    if not identifier then return end

    local isMechanicSave = false
    local row = WS.getMemberRow(identifier)
    if row and WS.isOnDuty(src) and WS.roleCan(row, 'repair_vehicles') then
        isMechanicSave = true
    end

    local targetOwner = identifier
    if isMechanicSave and ownerIdentifier and ownerIdentifier ~= '' then
        targetOwner = ownerIdentifier
    elseif ownerIdentifier and ownerIdentifier ~= '' and ownerIdentifier ~= identifier then
        return
    end

    local ok, saveErr = WS.saveOwnedVehicleProps(targetOwner, props)
    if not ok and saveErr then
        print(('[ya_workshop] saveRepairedVehicle: %s'):format(saveErr))
    end
end)
