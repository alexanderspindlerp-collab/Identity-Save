local ESX = exports['es_extended']:getSharedObject()

local trackedVehicles = {}

local function isLocalPolice()
    local data = ESX.GetPlayerData()
    local job = data and data.job
    if not job or not job.name then return false end
    local jobs = Config.Police and Config.Police.Jobs or { 'police' }
    local lower = job.name:lower()
    for i = 1, #jobs do
        if jobs[i]:lower() == lower then
            return true
        end
    end
    return false
end

local function getAllowedExtraSet()
    local set = {}
    local ids = Config.Police and Config.Police.OnlyExtraIds or {}
    for i = 1, #ids do
        set[tonumber(ids[i])] = true
    end
    return set
end

function ApplyPoliceExtrasToVehicle(vehicle, policeExtras)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if type(policeExtras) ~= 'table' then policeExtras = {} end

    local allowed = getAllowedExtraSet()
    local isPolice = isLocalPolice()

    for extraId = 0, 20 do
        if allowed[extraId] and DoesExtraExist(vehicle, extraId) then
            local key = tostring(extraId)
            local wantOn = policeExtras[key] == true
            if isPolice then
                SetVehicleExtra(vehicle, extraId, not wantOn)
            else
                SetVehicleExtra(vehicle, extraId, true)
            end
        end
    end

    if NetworkGetEntityIsNetworked(vehicle) then
        Entity(vehicle).state:set('yaPoliceExtras', policeExtras, true)
    end

    trackedVehicles[vehicle] = policeExtras
end

exports('ApplyPoliceExtrasToVehicle', ApplyPoliceExtrasToVehicle)

exports('CapturePoliceVehicleProps', function(vehicle, props)
    props = props or {}
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return props end

    local policeExtras = {}
    if NetworkGetEntityIsNetworked(vehicle) then
        local stateExtras = Entity(vehicle).state.yaPoliceExtras
        if type(stateExtras) == 'table' then
            policeExtras = stateExtras
        end
    end

    if not next(policeExtras) and type(props.policeExtras) == 'table' then
        policeExtras = props.policeExtras
    end

    props.policeExtras = policeExtras
    if props.extras and type(props.extras) == 'table' then
        local allowed = getAllowedExtraSet()
        for id, _ in pairs(policeExtras) do
            props.extras[id] = nil
        end
        for id, _ in pairs(allowed) do
            props.extras[tostring(id)] = nil
        end
    end

    return props
end)

RegisterNetEvent('ya_workshop:client:applyPoliceExtras', function(netId, policeExtras)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 then
        ApplyPoliceExtrasToVehicle(vehicle, policeExtras or {})
    end
end)

AddStateBagChangeHandler('yaPoliceExtras', nil, function(bagName, _, value)
    if type(value) ~= 'table' then return end
    local vehicle = GetEntityFromStateBagName(bagName)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    ApplyPoliceExtrasToVehicle(vehicle, value)
end)

CreateThread(function()
    while true do
        Wait(1500)
        local police = isLocalPolice()
        for vehicle, extras in pairs(trackedVehicles) do
            if not DoesEntityExist(vehicle) then
                trackedVehicles[vehicle] = nil
            elseif not police then
                ApplyPoliceExtrasToVehicle(vehicle, extras)
            end
        end
    end
end)

RegisterNetEvent('esx:setJob', function()
    for vehicle, extras in pairs(trackedVehicles) do
        if DoesEntityExist(vehicle) then
            ApplyPoliceExtrasToVehicle(vehicle, extras)
        end
    end
end)
