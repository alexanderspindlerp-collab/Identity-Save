local MOD_PROP_KEYS = {
    [0] = 'modSpoilers',
    [2] = 'modRearBumper',
    [4] = 'modExhaust',
    [5] = 'modFrame',
    [6] = 'modGrille',
    [7] = 'modHood',
    [10] = 'modRoof',
    [11] = 'modEngine',
    [12] = 'modBrakes',
    [13] = 'modTransmission',
    [15] = 'modSuspension',
    [23] = 'modFrontWheels',
    [27] = 'modTrimA',
    [28] = 'modOrnaments',
    [29] = 'modDashboard',
    [37] = 'modTrunk',
    [38] = 'modHydrolic',
    [43] = 'modAerials',
    [46] = 'modWindows',
    [48] = 'modLivery',
}

local function cloneTable(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do
        if type(v) == 'table' then
            copy[k] = cloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

function WS.normalizePlate(plate)
    if type(plate) ~= 'string' then return '' end
    return plate:upper():gsub('%s+', ''):gsub('[^%w]', ''):sub(1, 8)
end

function WS.findOwnedVehicle(owner, plate)
    if not owner or owner == '' then return nil end

    plate = WS.normalizePlate(plate)
    if plate == '' then return nil end

    return MySQL.single.await(
        'SELECT plate, vehicle FROM owned_vehicles WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), " ", "") = ? LIMIT 1',
        { owner, plate }
    )
end

function WS.playerOwnsVehicle(owner, plate)
    return WS.findOwnedVehicle(owner, plate) ~= nil
end

function WS.mergeModIntoProps(props, modData)
    if not props or type(modData) ~= 'table' then return props end

    if modData.kind == 'color' then
        local prop = modData.prop == 'color2' and 'color2' or 'color1'
        props[prop] = tonumber(modData.index) or 0
    elseif modData.kind == 'customColor' then
        local prop = modData.prop == 'color2' and 'color2' or 'color1'
        props[prop] = {
            tonumber(modData.r) or 255,
            tonumber(modData.g) or 255,
            tonumber(modData.b) or 255,
        }
    elseif modData.kind == 'vehicleMod' then
        local propKey = MOD_PROP_KEYS[modData.modType]
        if propKey then
            props[propKey] = modData.modIndex
        end
    elseif modData.kind == 'windowTint' then
        props.windowTint = modData.index
    elseif modData.kind == 'turbo' then
        props.modTurbo = modData.enabled == true
    elseif modData.kind == 'extra' then
        props.extras = props.extras or {}
        props.extras[tostring(modData.extraId)] = modData.enabled == true
    elseif modData.kind == 'policeExtra' then
        props.policeExtras = props.policeExtras or {}
        props.policeExtras[tostring(modData.extraId)] = modData.enabled == true
    end

    return props
end

function WS.saveJobVehicleProps(owner, jobName, vehicleProps)
    if not owner or not jobName or type(vehicleProps) ~= 'table' or not vehicleProps.plate then
        return false, 'Ugyldige køretøjsdata.'
    end

    local row = WS.findJobVehicle(owner, vehicleProps.plate, jobName)
    if not row then
        return false, 'Tjenestekøretøj ikke fundet.'
    end

    vehicleProps.plate = row.plate or vehicleProps.plate
    local plate = WS.normalizePlate(vehicleProps.plate)
    MySQL.update.await(
        'UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), " ", "") = ? AND job = ?',
        { json.encode(vehicleProps), owner, plate, jobName }
    )
    return true
end

function WS.buildTargetVehicleProps(baselineProps, cartLines)
    local props = cloneTable(baselineProps or {})
    if type(cartLines) ~= 'table' then return props end

    for i = 1, #cartLines do
        local line = cartLines[i]
        if type(line) == 'table' and line.type ~= 'unlock' and type(line.mod) == 'table' then
            WS.mergeModIntoProps(props, line.mod)
        end
    end

    return props
end

function WS.buildTargetFromOrderItems(baselineProps, orderItems)
    local props = cloneTable(baselineProps or {})
    if type(orderItems) ~= 'table' then return props end

    for i = 1, #orderItems do
        local item = orderItems[i]
        local modData = item.mod_data and json.decode(item.mod_data) or nil
        if type(modData) == 'table' then
            WS.mergeModIntoProps(props, modData)
        end
    end

    return props
end

function WS.saveOwnedVehicleProps(customerIdentifier, vehicleProps)
    if not customerIdentifier or type(vehicleProps) ~= 'table' or not vehicleProps.plate then
        return false, 'Ugyldige køretøjsdata.'
    end

    local row = WS.findOwnedVehicle(customerIdentifier, vehicleProps.plate)

    if not row then
        return false, 'Køretøjet findes ikke i garagen for kunden.'
    end

    local stored = row.vehicle and json.decode(row.vehicle) or nil
    if stored and vehicleProps.model and stored.model and vehicleProps.model ~= stored.model then
        return false, 'Køretøjsmodel matcher ikke garagen.'
    end

    vehicleProps.plate = row.plate or vehicleProps.plate
    local plate = WS.normalizePlate(vehicleProps.plate)
    MySQL.update.await(
        'UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), " ", "") = ?',
        { json.encode(vehicleProps), customerIdentifier, plate }
    )

    return true
end
