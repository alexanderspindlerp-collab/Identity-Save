local ESX = exports['es_extended']:getSharedObject()

local isOnDuty = false
local canRepair = false
local isRepairing = false
local repairUIOpen = false
local activeRepairNetId = 0
local repairVehicleMissTicks = 0

local function resolveRepairVehicle()
    if not activeRepairNetId or activeRepairNetId == 0 then return 0 end
    if not NetworkDoesNetworkIdExist(activeRepairNetId) then return 0 end
    local vehicle = NetworkGetEntityFromNetworkId(activeRepairNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return vehicle
end

local function repairCfg()
    return Config.Repair or {}
end

local function mechanicCfg()
    return repairCfg().Mechanic or {}
end

local function selfCfg()
    return repairCfg().SelfRepair or {}
end

local function normalizePlate(plate)
    if type(plate) ~= 'string' then return '' end
    return plate:upper():gsub('%s+', ''):gsub('[^%w]', ''):sub(1, 8)
end

local function getTargetDistance()
    return tonumber(mechanicCfg().TargetDistance) or 6.0
end

local function ensureAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

function GetVehicleDamageSnapshot(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local burstCount = 0
    for tyre = 0, 7 do
        if IsVehicleTyreBurst(vehicle, tyre, false) then
            burstCount = burstCount + 1
        end
    end

    local engine = math.floor(math.max(0.0, math.min(100.0, (GetVehicleEngineHealth(vehicle) / 1000.0) * 100.0)) + 0.5)
    local body = math.floor(math.max(0.0, math.min(100.0, (GetVehicleBodyHealth(vehicle) / 1000.0) * 100.0)) + 0.5)
    local tank = math.floor(math.max(0.0, math.min(100.0, (GetVehiclePetrolTankHealth(vehicle) / 1000.0) * 100.0)) + 0.5)
    local wheels = math.max(0, 100 - (burstCount * 25))

    return {
        engine = engine,
        body = body,
        tank = tank,
        wheels = wheels,
        plate = normalizePlate(GetVehicleNumberPlateText(vehicle)),
    }
end

local function applyFullRepairNative(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    SetVehicleFixed(vehicle)
    SetVehicleDeformationFixed(vehicle)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleEngineHealth(vehicle, 1000.0)
    SetVehicleBodyHealth(vehicle, 1000.0)
    SetVehiclePetrolTankHealth(vehicle, 1000.0)
    SetVehicleDirtLevel(vehicle, 0.0)

    for tyre = 0, 7 do
        if IsVehicleTyreBurst(vehicle, tyre, false) then
            SetVehicleTyreFixed(vehicle, tyre)
        end
    end

    for window = 0, 7 do
        FixVehicleWindow(vehicle, window)
    end

    local props = ESX.Game.GetVehicleProperties(vehicle)
    if props then
        props.engineHealth = 1000.0
        props.bodyHealth = 1000.0
        props.tankHealth = 1000.0
        props.dirtLevel = 0.0
        ESX.Game.SetVehicleProperties(vehicle, props)
    end
end

local function applyMechanicRepairNative(vehicle, damage, placements)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    damage = damage or GetVehicleDamageSnapshot(vehicle) or {}
    placements = placements or {}

    local catalog = {}
    for i = 1, #(repairCfg().Items or {}) do
        local entry = repairCfg().Items[i]
        catalog[entry.name] = entry
    end

    local engineDamage = math.max(0, 100 - (tonumber(damage.engine) or 100))
    local bodyDamage = math.max(0, 100 - (tonumber(damage.body) or 100))
    local tankDamage = math.max(0, 100 - (tonumber(damage.tank) or 100))
    local wheelDamage = math.max(0, 100 - (tonumber(damage.wheels) or 100))
    local fullRepair = false

    for i = 1, #placements do
        local placement = placements[i]
        local entry = placement and catalog[placement.name]
        if entry then
            local zone = placement.zone or 'universal'
            local power = tonumber(entry.power) or 0
            if power >= 100 and zone == 'universal' then
                fullRepair = true
            end
            if zone == 'engine' then engineDamage = math.max(0, engineDamage - power) end
            if zone == 'body' then bodyDamage = math.max(0, bodyDamage - power) end
            if zone == 'tank' then tankDamage = math.max(0, tankDamage - power) end
            if zone == 'wheels' then wheelDamage = math.max(0, wheelDamage - power) end
            if zone == 'universal' then
                engineDamage = math.max(0, engineDamage - power)
                bodyDamage = math.max(0, bodyDamage - power)
                tankDamage = math.max(0, tankDamage - power)
                wheelDamage = math.max(0, wheelDamage - power)
            end
        end
    end

    if fullRepair or (engineDamage <= 0 and bodyDamage <= 0 and tankDamage <= 0 and wheelDamage <= 0) then
        applyFullRepairNative(vehicle)
        return
    end

    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    local tankHealth = GetVehiclePetrolTankHealth(vehicle)

    SetVehicleEngineHealth(vehicle, math.min(1000.0, engineHealth + (100 - engineDamage) * 4.0))
    SetVehicleBodyHealth(vehicle, math.min(1000.0, bodyHealth + (100 - bodyDamage) * 4.0))
    SetVehiclePetrolTankHealth(vehicle, math.min(1000.0, tankHealth + (100 - tankDamage) * 4.0))

    if wheelDamage <= 0 then
        for tyre = 0, 7 do
            if IsVehicleTyreBurst(vehicle, tyre, false) then
                SetVehicleTyreFixed(vehicle, tyre)
            end
        end
    end

    SetVehicleUndriveable(vehicle, false)
end

local function refreshDutyState(doneCb)
    ESX.TriggerServerCallback('ya_workshop:getDutyState', function(state)
        state = type(state) == 'table' and state or {}
        isOnDuty = state.isOnDuty == true
        canRepair = state.canRepair == true
        if type(doneCb) == 'function' then doneCb(state) end
    end)
end

local function getPlayerVehicleForSelfRepair()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        if GetPedInVehicleSeat(veh, -1) == ped then
            return veh
        end
    end

    local coords = GetEntityCoords(ped)
    local veh = ESX.Game.GetClosestVehicle(coords)
    if veh and veh ~= 0 and DoesEntityExist(veh) and #(coords - GetEntityCoords(veh)) <= 8.0 then
        return veh
    end

    return 0
end

local function runRepairProgress(duration, label)
    if GetResourceState('ox_lib') ~= 'started' then
        ESX.ShowNotification('ox_lib mangler.')
        return false
    end

    local anim = mechanicCfg().Anim or {}
    if not ensureAnimDict(anim.dict or 'mini@repair') then
        return false
    end

    return lib.progressBar({
        duration = duration,
        label = label or 'Reparerer...',
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true, sprint = true },
        anim = {
            dict = anim.dict or 'mini@repair',
            clip = anim.clip or 'fixing_a_player',
            flag = anim.flag or 49,
        },
    }) == true
end

local function getZoneAnchors()
    return repairCfg().ZoneAnchors or {}
end

local function getWalkAroundDistance()
    return tonumber(repairCfg().WalkAroundDistance) or (getTargetDistance() + 2.0)
end

local function getZoneWorldPos(vehicle, anchor)
    if type(anchor) ~= 'table' then return nil end

    if anchor.bone then
        local boneIndex = GetEntityBoneIndexByName(vehicle, anchor.bone)
        if boneIndex ~= -1 then
            return GetWorldPositionOfEntityBone(vehicle, boneIndex)
        end
    end

    return GetOffsetFromEntityInWorldCoords(
        vehicle,
        tonumber(anchor.x) or 0.0,
        tonumber(anchor.y) or 0.0,
        tonumber(anchor.z) or 0.0
    )
end

local function worldToScreenPercent(coords)
    if not coords then return false, 50.0, 50.0 end
    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    return onScreen == true or onScreen == 1, (sx or 0.5) * 100.0, (sy or 0.5) * 100.0
end

local function sendZonePositions()
    local vehicle = resolveRepairVehicle()
    if not repairUIOpen or vehicle == 0 then
        return
    end

    local anchors = getZoneAnchors()
    local zones = {}

    for zoneName, anchor in pairs(anchors) do
        local world = getZoneWorldPos(vehicle, anchor)
        local visible, sx, sy = worldToScreenPercent(world)
        zones[zoneName] = {
            visible = visible,
            x = sx,
            y = sy,
        }
    end

    SendNUIMessage({
        action = 'updateZonePositions',
        zones = zones,
    })
end

local function closeRepairUI()
    if not repairUIOpen then return end
    repairUIOpen = false
    activeRepairNetId = 0
    repairVehicleMissTicks = 0
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRepair' })
end

local function openRepairUI(netId, session, damage)
    netId = tonumber(netId) or 0
    if netId == 0 then return end

    repairUIOpen = true
    activeRepairNetId = netId
    repairVehicleMissTicks = 0
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'openRepair',
        session = session,
        damage = damage,
    })
    sendZonePositions()
end

local function startMechanicRepair(entity)
    if isRepairing or repairUIOpen then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if not isOnDuty or not canRepair then
        ESX.ShowNotification('Du skal være på arbejde med reparations-adgang.')
        return
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        ESX.ShowNotification('Stig ud af køretøjet først.')
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local damage = GetVehicleDamageSnapshot(entity)

    ESX.TriggerServerCallback('ya_workshop:getRepairSession', function(session)
        session = type(session) == 'table' and session or {}
        if not session.ok then
            ESX.ShowNotification(session.message or 'Kunne ikke åbne reparation.')
            return
        end

        if #(session.inventory or {}) == 0 then
            ESX.ShowNotification('Du har ingen reparationsdele i inventory.')
            return
        end

        openRepairUI(netId, session, damage)
    end, netId)
end

local function registerRepairTarget()
    if GetResourceState('ox_target') ~= 'started' then return end

    pcall(function()
        exports.ox_target:removeGlobalVehicle('ya_workshop_repair')
    end)

    exports.ox_target:addGlobalVehicle({
        {
            name = 'ya_workshop_repair',
            icon = 'fa-solid fa-wrench',
            label = 'Reparer køretøj',
            distance = getTargetDistance(),
            canInteract = function()
                return isOnDuty and canRepair and not isRepairing and not repairUIOpen
            end,
            onSelect = function(data)
                CreateThread(function()
                    startMechanicRepair(data.entity)
                end)
            end,
        },
    })
end

RegisterNUICallback('repairClose', function(_, cb)
    closeRepairUI()
    cb('ok')
end)

RegisterNUICallback('repairSubmit', function(data, cb)
    cb('ok')

    local vehicle = resolveRepairVehicle()
    if not repairUIOpen or vehicle == 0 then
        closeRepairUI()
        ESX.ShowNotification('Køretøjet er væk.')
        return
    end

    local placements = type(data) == 'table' and data.placements or {}
    local damage = type(data) == 'table' and data.damage or GetVehicleDamageSnapshot(vehicle)
    local netId = activeRepairNetId
    local cfg = mechanicCfg()
    local duration = math.min(
        cfg.MaxDuration or 90000,
        math.max(cfg.MinDuration or 12000, (cfg.MinDuration or 12000) + (#placements * (cfg.MsPerPart or 4000)))
    )

    closeRepairUI()
    isRepairing = true
    TaskTurnPedToFaceEntity(PlayerPedId(), vehicle, 800)
    Wait(400)

    local completed = runRepairProgress(duration, 'Monterer dele...')
    isRepairing = false

    if not completed then
        ESX.ShowNotification('Reparation afbrudt.')
        return
    end

    if not NetworkDoesNetworkIdExist(netId) then
        ESX.ShowNotification('Bilen er væk.')
        return
    end

    local repairedVehicle = NetworkGetEntityFromNetworkId(netId)
    if repairedVehicle == 0 or not DoesEntityExist(repairedVehicle) then
        ESX.ShowNotification('Bilen er væk.')
        return
    end

    TriggerServerEvent('ya_workshop:completeMechanicRepair', netId, damage, placements)
end)

RegisterNetEvent('ya_workshop:applyFullRepair', function(netId)
    netId = tonumber(netId)
    if not netId then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        applyFullRepairNative(vehicle)
    end
end)

RegisterNetEvent('ya_workshop:applyMechanicRepair', function(netId, damage, placements)
    netId = tonumber(netId)
    if not netId then return end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        applyMechanicRepairNative(vehicle, damage, placements)
    end
end)

RegisterNetEvent('ya_workshop:requestRepairPropsSave', function(netId, ownerIdentifier, plate)
    netId = tonumber(netId)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local props = ESX.Game.GetVehicleProperties(vehicle)
    if not props then return end
    props.plate = plate or props.plate
    TriggerServerEvent('ya_workshop:saveRepairedVehicle', ownerIdentifier, props)
end)

RegisterNetEvent('ya_workshop:saveSelfRepairProps', function(netId)
    netId = tonumber(netId)
    local vehicle = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    Wait(200)
    local props = ESX.Game.GetVehicleProperties(vehicle)
    if not props then return end
    TriggerServerEvent('ya_workshop:saveRepairedVehicle', nil, props)
end)

RegisterNetEvent('ya_workshop:dutyState', function(onDuty, data)
    isOnDuty = onDuty == true
    if data and data.companyName then
        ESX.ShowNotification(onDuty and ('På arbejde — %s'):format(data.companyName) or 'Af arbejde.')
    end
end)

RegisterCommand(selfCfg().Command or 'repair', function()
    if isRepairing then return end

    local vehicle = getPlayerVehicleForSelfRepair()
    if vehicle == 0 then
        ESX.ShowNotification('Stå ved dit køretøj eller sid i det som fører.')
        return
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    ESX.TriggerServerCallback('ya_workshop:canSelfRepair', function(result)
        result = type(result) == 'table' and result or {}
        if not result.ok then
            ESX.ShowNotification(result.message or 'Reparation ikke mulig.')
            return
        end

        local priceDisplay = result.priceDisplay or '19.999,99'
        local duration = tonumber(result.duration) or 60000

        if GetResourceState('ox_lib') == 'started' then
            local confirmed = lib.alertDialog({
                header = 'Nødreparation',
                content = ('Ingen mekanikere online.\n\nPris: **%s kr**\nVarighed: 1 minut\n\nFortsæt?'):format(priceDisplay),
                centered = true,
                cancel = true,
            })
            if confirmed ~= 'confirm' then return end
        end

        isRepairing = true
        local completed = runRepairProgress(duration, ('Nødreparation — %s kr...'):format(priceDisplay))
        isRepairing = false

        if not completed then
            ESX.ShowNotification('Reparation afbrudt.')
            return
        end

        if not DoesEntityExist(vehicle) then
            ESX.ShowNotification('Køretøj ikke fundet.')
            return
        end

        TriggerServerEvent('ya_workshop:completeSelfRepair', netId)
    end, netId)
end, false)

RegisterCommand('wsduty', function()
    TriggerServerEvent('ya_workshop:toggleDuty')
end, false)

RegisterNetEvent('esx:playerLoaded', function()
    refreshDutyState()
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(500) end
    refreshDutyState()
end)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do
        Wait(500)
    end
    registerRepairTarget()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'ox_target' then return end
    Wait(500)
    registerRepairTarget()
end)

exports('IsOnDutyMechanic', function()
    return isOnDuty and canRepair
end)

exports('GetVehicleDamageSnapshot', GetVehicleDamageSnapshot)

CreateThread(function()
    while true do
        if repairUIOpen then
            local vehicle = resolveRepairVehicle()
            if vehicle == 0 then
                repairVehicleMissTicks = repairVehicleMissTicks + 1
                if repairVehicleMissTicks >= 15 then
                    closeRepairUI()
                    ESX.ShowNotification('Køretøjet er væk.')
                end
            else
                repairVehicleMissTicks = 0
                local ped = PlayerPedId()
                local dist = #(GetEntityCoords(ped) - GetEntityCoords(vehicle))
                if dist > getWalkAroundDistance() then
                    closeRepairUI()
                    ESX.ShowNotification('Du er for langt væk fra bilen.')
                else
                    sendZonePositions()
                end
            end
            Wait(50)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if repairUIOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 58, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)
