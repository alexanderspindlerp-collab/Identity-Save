local ESX = exports.es_extended:getSharedObject()

local Locks = {}

local function normalizePlate(plate)
    if not plate then return nil end
    return tostring(plate):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ''):upper()
end

local function decodeVehiclePlate(vehicleJson)
    if not vehicleJson or vehicleJson == '' then return nil end

    local ok, data = pcall(json.decode, vehicleJson)
    if not ok or type(data) ~= 'table' then return nil end

    return data.plate
end

local function getXPlayer(source)
    return ESX.GetPlayerFromId(source)
end

local function getRowsByPlate(plate)
    local normalized = normalizePlate(plate)
    if not normalized then return {} end

    local rows = MySQL.query.await(([[ 
        SELECT `%s`, `%s`, `%s`
        FROM `%s`
        WHERE REPLACE(UPPER(`%s`), ' ', '') = ?
           OR `%s` LIKE ?
           OR `%s` LIKE ?
    ]]):format(
        Config.OwnerColumn,
        Config.PlateColumn,
        Config.VehicleJsonColumn,
        Config.VehicleTable,
        Config.PlateColumn,
        Config.VehicleJsonColumn,
        Config.VehicleJsonColumn
    ), {
        normalized,
        '%' .. tostring(plate) .. '%',
        '%' .. normalized .. '%'
    }) or {}

    local filtered = {}

    for _, row in ipairs(rows) do
        local dbPlate = row[Config.PlateColumn]
        local jsonPlate = decodeVehiclePlate(row[Config.VehicleJsonColumn])

        if normalizePlate(dbPlate) == normalized or normalizePlate(jsonPlate) == normalized then
            filtered[#filtered + 1] = row
        end
    end

    return filtered
end

local function ownsVehicle(source, plate)
    local xPlayer = getXPlayer(source)
    local identifier = xPlayer and xPlayer.identifier or nil
    local normalized = normalizePlate(plate)

    if not identifier or not normalized then
        return false, {
            reason = 'missing_identifier_or_plate',
            identifier = identifier,
            checkedPlate = plate,
            normalizedPlate = normalized,
            rows = {}
        }
    end

    local rows = getRowsByPlate(plate)

    for _, row in ipairs(rows) do
        if row[Config.OwnerColumn] == identifier then
            return true, {
                reason = 'matched',
                identifier = identifier,
                checkedPlate = plate,
                normalizedPlate = normalized,
                dbOwner = row[Config.OwnerColumn],
                dbPlate = row[Config.PlateColumn],
                jsonPlate = decodeVehiclePlate(row[Config.VehicleJsonColumn]),
                rows = rows
            }
        end
    end

    return false, {
        reason = #rows == 0 and 'vehicle_not_found' or 'owner_mismatch',
        identifier = identifier,
        checkedPlate = plate,
        normalizedPlate = normalized,
        rows = rows
    }
end

local function isPolice(source)
    local xPlayer = getXPlayer(source)
    if not xPlayer or not xPlayer.job then return false end

    return Config.PoliceJobs[xPlayer.job.name] == true
end

local function applyLock(netId, plate, locked)
    local normalized = normalizePlate(plate)

    if normalized then
        Locks[normalized] = locked == true
    end

    local entity = netId and NetworkGetEntityFromNetworkId(netId) or 0

    if entity and entity ~= 0 then
        SetVehicleDoorsLocked(entity, locked and 2 or 1)
        Entity(entity).state:set('yaprivlock_locked', locked == true, true)
    end
end

lib.callback.register('yaprivlock:isOwner', function(source, plate)
    local owner = ownsVehicle(source, plate)
    return owner == true
end)

lib.callback.register('yaprivlock:getLockState', function(source, plate)
    local normalized = normalizePlate(plate)
    return normalized and Locks[normalized] == true or false
end)

lib.callback.register('yaprivlock:toggleLock', function(source, netId, plate)
    local owner, info = ownsVehicle(source, plate)

    if Config.Debug then
        print('[yaprivlock TOGGLE] '..json.encode(info))
    end

    if not owner then
        return {
            ok = false,
            message = 'Du ejer ikke dette køretøj.'
        }
    end

    local normalized = normalizePlate(plate)
    local locked = not (Locks[normalized] == true)

    applyLock(netId, plate, locked)

    return {
        ok = true,
        locked = locked,
        message = locked and 'Køretøjet er låst.' or 'Køretøjet er låst op.'
    }
end)

lib.callback.register('yaprivlock:policeBreakOpen', function(source, netId, plate)
    if not isPolice(source) then
        return {
            ok = false,
            message = 'Du er ikke politi.'
        }
    end

    applyLock(netId, plate, false)

    return {
        ok = true,
        locked = false,
        message = 'Køretøjet blev brudt op.'
    }
end)

RegisterCommand('yaprivdebug', function(source)
    local ped = GetPlayerPed(source)
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        TriggerClientEvent('yaprivlock:debugNearest', source)
        return
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    local owner, info = ownsVehicle(source, plate)

    print('[yaprivlock DEBUG] '..json.encode(info))

    TriggerClientEvent('ox_lib:notify', source, {
        title = Config.NotifyTitle,
        description = owner and 'Debug: Du ejer bilen. Se server console.' or 'Debug: Matcher ikke. Se server console.',
        type = owner and 'success' or 'error'
    })
end, false)

RegisterNetEvent('yaprivlock:serverDebugPlate', function(plate)
    local src = source
    local owner, info = ownsVehicle(src, plate)

    print('[yaprivlock DEBUG] '..json.encode(info))

    TriggerClientEvent('ox_lib:notify', src, {
        title = Config.NotifyTitle,
        description = owner and 'Debug: Du ejer bilen. Se server console.' or 'Debug: Matcher ikke. Se server console.',
        type = owner and 'success' or 'error'
    })
end)
