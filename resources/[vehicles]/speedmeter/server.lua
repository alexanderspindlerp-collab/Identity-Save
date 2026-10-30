local function trim(v)
    return (tostring(v or '')):gsub('^%s*(.-)%s*$', '%1')
end

local function normalizePlate(plate)
    return trim(plate):upper()
end

local function getDriverIdentifier(src)
    if not src then return nil end
    local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function checkPlate(plate, driverIdentifier, vehicleClass)
    plate = normalizePlate(plate)
    local empty = { hit = false, reason = nil, detail = nil, displayPlate = nil, foererret = false }
    if plate == '' then return empty end

    if GetResourceState('san_mdt') ~= 'started' then
        print('[speedmeter] san_mdt er ikke startet — ANPG kan ikke tjekke databasen.')
        return empty
    end

    local ok, result = pcall(function()
        return exports['san_mdt']:CheckAnpgPlate(plate, driverIdentifier, vehicleClass)
    end)

    if not ok then
        print(('[speedmeter] CheckAnpgPlate fejlede: %s'):format(tostring(result)))
        return empty
    end

    if type(result) ~= 'table' or result.hit ~= true then
        return empty
    end

    return {
        hit = true,
        reason = result.reason,
        detail = result.detail,
        displayPlate = result.displayPlate or plate,
        foererret = result.foererret == true,
    }
end

lib.callback.register('speedmeter:checkAnpg', function(source, plate, driverServerId, vehicleClass)
    plate = normalizePlate(plate)
    vehicleClass = tonumber(vehicleClass) or 0
    local result = checkPlate(plate, getDriverIdentifier(driverServerId), vehicleClass)

    if source and source > 0 and result.hit then
        TriggerClientEvent(
            'speedmeter:anpgHit',
            source,
            plate,
            result.reason,
            result.detail,
            result.displayPlate,
            result.foererret
        )
    end

    return result
end)
