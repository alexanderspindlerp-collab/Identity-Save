local ownerCache = {}

local function notify(description, type)
    lib.notify({
        title = Config.NotifyTitle,
        description = description,
        type = type or 'inform'
    })
end

local function normalizePlate(plate)
    if not plate then return nil end
    return tostring(plate):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ''):upper()
end

local function getPlate(vehicle)
    if not vehicle or vehicle == 0 then return nil end
    return GetVehicleNumberPlateText(vehicle)
end

local function ensureNetId(vehicle)
    if not DoesEntityExist(vehicle) then
        return 0
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    if not netId or netId == 0 then
        NetworkRegisterEntityAsNetworked(vehicle)
        Wait(100)
        netId = NetworkGetNetworkIdFromEntity(vehicle)
    end

    return netId or 0
end

local function localLocked(vehicle)
    if not DoesEntityExist(vehicle) then
        return false
    end

    local state = Entity(vehicle).state.yaprivlock_locked

    if state ~= nil then
        return state == true
    end

    local status = GetVehicleDoorLockStatus(vehicle)

    return status == 2 or status == 10
end

local function canUseVehicleLock(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local plate = getPlate(vehicle)
    local key = normalizePlate(plate)

    if not key then return false end

    local now = GetGameTimer()
    local cached = ownerCache[key]

    if cached and cached.expires > now then
        return cached.allowed == true
    end

    local allowed = lib.callback.await('yaprivlock:isOwner', false, plate) == true

    ownerCache[key] = {
        allowed = allowed,
        expires = now + 3000
    }

    return allowed
end

local function flash(vehicle)
    if not DoesEntityExist(vehicle) then return end

    SetVehicleLights(vehicle, 2)
    Wait(200)
    SetVehicleLights(vehicle, 0)
    Wait(150)
    SetVehicleLights(vehicle, 2)
    Wait(200)
    SetVehicleLights(vehicle, 0)
end

local function keyAnim()
    local ped = PlayerPedId()
    local dict = 'anim@mp_player_intmenu@key_fob@'

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end

    TaskPlayAnim(ped, dict, 'fob_click', 8.0, -8.0, 700, 48, 0, false, false, false)
end

local function toggleLock(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local plate = getPlate(vehicle)
    local netId = ensureNetId(vehicle)

    keyAnim()

    local result = lib.callback.await('yaprivlock:toggleLock', false, netId, plate)

    if not result or not result.ok then
        notify((result and result.message) or 'Kunne ikke låse køretøjet.', 'error')
        return
    end

    SetVehicleDoorsLocked(vehicle, result.locked and 2 or 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, result.locked == true)
    Entity(vehicle).state:set('yaprivlock_locked', result.locked == true, true)

    flash(vehicle)
    notify(result.message, result.locked and 'success' or 'inform')
end

local function openVehicleTrunk(vehicle)
    if not DoesEntityExist(vehicle) then return end

    if localLocked(vehicle) then
        notify('Køretøjet er låst.', 'error')
        return
    end

    local netId = ensureNetId(vehicle)

    if not exports.ox_inventory then
        notify('ox_inventory blev ikke fundet.', 'error')
        return
    end

    exports.ox_inventory:openInventory('trunk', {
        netid = netId,
        entity = vehicle
    })
end

local function policeBreak(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local ped = PlayerPedId()
    local plate = getPlate(vehicle)
    local netId = ensureNetId(vehicle)

    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_WELDING', 0, true)

    local done = lib.progressCircle({
        duration = Config.PoliceBreakTime,
        label = 'Bryder køretøjet op...',
        position = 'bottom',
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    })

    ClearPedTasks(ped)

    if not done then
        notify('Afbrudt.', 'error')
        return
    end

    local result = lib.callback.await('yaprivlock:policeBreakOpen', false, netId, plate)

    if result and result.ok then
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        Entity(vehicle).state:set('yaprivlock_locked', false, true)
        flash(vehicle)
        notify(result.message, 'success')
    else
        notify((result and result.message) or 'Kunne ikke bryde køretøjet op.', 'error')
    end
end

CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'yaprivlock_toggle',
            icon = 'fa-solid fa-key',
            label = 'Lås / Lås op',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                return DoesEntityExist(entity) and canUseVehicleLock(entity)
            end,
            onSelect = function(data)
                toggleLock(data.entity)
            end
        },
        {
            name = 'yaprivlock_open_trunk',
            icon = 'fa-solid fa-box-open',
            label = 'Åbn bagagerum',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                return DoesEntityExist(entity)
            end,
            onSelect = function(data)
                openVehicleTrunk(data.entity)
            end
        },
        {
            name = 'yaprivlock_police_break',
            icon = 'fa-solid fa-screwdriver-wrench',
            label = 'Bryd køretøj op',
            distance = Config.TargetDistance,
            canInteract = function(entity)
                return DoesEntityExist(entity) and localLocked(entity)
            end,
            onSelect = function(data)
                policeBreak(data.entity)
            end
        }
    })
end)

RegisterNetEvent('yaprivlock:debugNearest', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 6.0, 0, 71)

    if vehicle == 0 then
        notify('Debug: Ingen bil tæt på.', 'error')
        return
    end

    TriggerServerEvent('yaprivlock:serverDebugPlate', getPlate(vehicle))
end)

CreateThread(function()
    while true do
        local sleep = 800
        local ped = PlayerPedId()

        if not IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsTryingToEnter(ped)

            if vehicle and vehicle ~= 0 and Entity(vehicle).state.yaprivlock_locked == true then
                sleep = 0
                ClearPedTasks(ped)
                notify('Køretøjet er låst.', 'error')
                Wait(1500)
            end
        end

        Wait(sleep)
    end
end)
