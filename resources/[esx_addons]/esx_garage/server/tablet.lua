local function resolveGarageLabel(garageId)
    garageId = tostring(garageId or ''):gsub('^%s*(.-)%s*$', '%1')
    if garageId == '' then return 'Ukendt garage' end

    local cfg = Config.Garages and Config.Garages[garageId]
    if cfg and cfg.Label then return cfg.Label end

    local ok, label = pcall(function()
        return MySQL.scalar.await('SELECT label FROM esx_garage_locations WHERE name = ? LIMIT 1', { garageId })
    end)
    if ok and label and label ~= '' then return label end

    return garageId:gsub('([a-z])([A-Z])', '%1 %2')
end

local function resolveImpoundLabel(poundId)
    poundId = tostring(poundId or ''):gsub('^%s*(.-)%s*$', '%1')
    if poundId == '' then return 'Impound' end
    return poundId:gsub('([a-z])([A-Z])', '%1 %2') .. ' Impound'
end

local function vehicleModelLabel(props)
    if type(props) ~= 'table' then return 'Køretøj' end
    if props.model then
        return tostring(props.model):gsub('^%s*(.-)%s*$', '%1')
    end
    return 'Køretøj'
end

local function buildVehicleStatus(stored, parking, pound)
    stored = tonumber(stored) or 0

    if stored == 1 then
        return {
            code = 'garage',
            label = 'I garage',
            location = resolveGarageLabel(parking),
            garageId = parking,
        }
    end

    if stored == 2 then
        return {
            code = 'impound',
            label = 'Impound',
            location = resolveImpoundLabel(pound),
            garageId = pound,
        }
    end

    return {
        code = 'out',
        label = 'Ude',
        location = parking and parking ~= '' and ('Sidst: ' .. resolveGarageLabel(parking)) or 'Ikke parkeret',
        garageId = parking,
    }
end

local function fetchPlayerVehicles(identifier)
    local rows = MySQL.query.await([[
        SELECT plate, vehicle, stored, parking, pound, impound_type
        FROM owned_vehicles
        WHERE owner = ?
        ORDER BY plate ASC
    ]], { identifier }) or {}

    local vehicles = {}

    for i = 1, #rows do
        local row = rows[i]
        local props = json.decode(row.vehicle or '{}') or {}
        local status = buildVehicleStatus(row.stored, row.parking, row.pound)

        vehicles[#vehicles + 1] = {
            plate = row.plate,
            model = props.model,
            modelLabel = vehicleModelLabel(props),
            stored = tonumber(row.stored) or 0,
            statusLabel = status.label,
            statusCode = status.code,
            garageLabel = status.location,
            garageId = status.garageId,
            impoundType = row.impound_type,
        }
    end

    return vehicles
end

local function pushTabletAppData(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    TriggerClientEvent('ya_tablet:garageAppData', src, {
        vehicles = fetchPlayerVehicles(xPlayer.getIdentifier()),
    })
end

RegisterNetEvent('esx_garage:getTabletAppData', function()
    pushTabletAppData(source)
end)

local function installGarageApp(identifier)
    if not identifier or GetResourceState('ya_tablet') ~= 'started' then return end
    exports.ya_tablet:InstallAppForIdentifier(identifier, 'garage')
end

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if not xPlayer then return end
    installGarageApp(xPlayer.identifier)
    if playerId then
        exports.ya_tablet:RefreshPlayer(playerId)
    end
end)

CreateThread(function()
    while GetResourceState('ya_tablet') ~= 'started' do
        Wait(200)
    end
    Wait(300)

    exports.ya_tablet:RegisterApp({
        id = 'garage',
        name = 'Garage',
        desc = 'Se hvor dine køretøjer er parkeret.',
        icon = 'garage',
        color = '#2563eb',
        adminOnly = false,
        resource = 'esx_garage',
    })

    print('[esx_garage] Tablet-app "Garage" registreret.')

    local players = ESX.GetExtendedPlayers and ESX.GetExtendedPlayers() or {}
    for i = 1, #players do
        local xPlayer = players[i]
        if xPlayer and xPlayer.identifier then
            installGarageApp(xPlayer.identifier)
            exports.ya_tablet:RefreshPlayer(xPlayer.source)
        end
    end
end)
