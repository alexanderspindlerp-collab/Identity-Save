CreateThread(function()
    while true do
        Wait(0)

        local player = PlayerId()
        SetPlayerWantedLevel(player, 0, false)
        SetPlayerWantedLevelNow(player, false)
        SetPoliceIgnorePlayer(player, true)
        SetDispatchCopsForPlayer(player, false)

        for i = 1, 15 do
            EnableDispatchService(i, false)
        end

        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)

        DistantCopCarSirens(false)
    end
end)

local function isCopPed(ped)
    return GetPedType(ped) == 6
end

local function hasPlayerOccupant(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then
            return true
        end
    end

    return false
end

--- Spiller-/job-køretøjer (OneSync) må aldrig slettes — kun ambient NPC-politi.
local function isProtectedVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return true end
    if hasPlayerOccupant(vehicle) then return true end

    if NetworkGetEntityIsNetworked(vehicle) then
        return true
    end

    local state = Entity(vehicle).state
    if state and (state.yaJobVehicle or state.esxJobVehicle) then
        return true
    end

    return false
end

local AMBIENT_POLICE_MODELS = {
    [`police`] = true,
    [`police2`] = true,
    [`police3`] = true,
    [`police4`] = true,
    [`policeb`] = true,
    [`polmav`] = true,
    [`sheriff`] = true,
    [`sheriff2`] = true,
    [`fbi`] = true,
    [`fbi2`] = true,
}

CreateThread(function()
    while true do
        Wait(3000)

        for _, ped in ipairs(GetGamePool('CPed')) do
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) and isCopPed(ped) then
                DeleteEntity(ped)
            end
        end

        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(vehicle) and not isProtectedVehicle(vehicle) then
                if AMBIENT_POLICE_MODELS[GetEntityModel(vehicle)] then
                    DeleteEntity(vehicle)
                end
            end
        end
    end
end)
