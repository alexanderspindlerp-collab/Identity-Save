local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

RegisterNetEvent('ya_cardealer:spawnSoldVehicle', function(model, plate, x, y, z, heading)
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    heading = tonumber(heading) or 0.0
    if not x or not y or not z or not model or not plate then return end

    local hash = loadModel(model)
    if not hash then return end

    local veh = CreateVehicle(hash, x, y, z, heading, true, false)
    if veh and veh ~= 0 then
        SetVehicleNumberPlateText(veh, plate)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        SetVehicleOnGroundProperly(veh)
        SetModelAsNoLongerNeeded(hash)
    end
end)
