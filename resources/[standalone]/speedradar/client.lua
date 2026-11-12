local ESX = nil
local radarActive = false
local aiming = false
local equipment = nil
local targetAdded = false
local radarCam = nil
local camRot = nil
local camFov = Config.DefaultFov
local lastPayload = nil
local lastSavedAt = 0
local history = {}
local currentReading = { action = 'update', hasTarget = false }
local playerLocked = false
local printOpen = false

CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

local function notify(msg, nType)
    if lib and lib.notify then
        lib.notify({ title = 'Fartkontrol', description = msg, type = nType or 'inform' })
    elseif ESX and ESX.ShowNotification then
        ESX.ShowNotification(msg)
    else
        print(('[speedradar] %s'):format(msg))
    end
end

local function isAllowed()
    if not Config.PoliceOnly then return true end
    if not ESX then return false end
    local data = ESX.GetPlayerData()
    return data and data.job and Config.PoliceJobs[data.job.name] == true
end

local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(10) end
    return HasModelLoaded(model)
end

local function rotationToDirection(rotation)
    local x, z = math.rad(rotation.x), math.rad(rotation.z)
    return vector3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function sendRadar(payload)
    local encoded = json.encode(payload)
    if encoded == lastPayload then return end
    lastPayload = encoded
    SendNUIMessage(payload)
end

local function pushHistory(reading)
    table.insert(history, 1, reading)
    while #history > Config.MaxHistory do table.remove(history) end
    SendNUIMessage({ action = 'history', history = history })
end

local function getUnixTime()
    local ok, cloudTime = pcall(GetCloudTimeAsInt)
    if ok and cloudTime and cloudTime > 0 then return cloudTime end
    return math.floor(os.time and os.time() or (GetGameTimer() / 1000))
end

local function saveReading(reading)
    if not radarActive then return end
    if not reading or not reading.hasTarget then
        notify('Ingen bil i sigtet.', 'error')
        return
    end
    if reading.speed < Config.MinSpeedToSave then
        notify('Bilen holder stille.', 'error')
        return
    end

    local now = GetGameTimer()
    if now - lastSavedAt < Config.ManualSaveCooldown then return end
    lastSavedAt = now

    local savedReading = {
        timestamp = getUnixTime(),
        plate = reading.plate,
        speed = reading.speed,
        distance = reading.distance
    }

    -- Gem lokalt til HUD/historik og send samtidig til serveren.
    -- Rapporten bruger server-listen, så den ikke bliver tom pga. NUI/client state.
    pushHistory(savedReading)
    TriggerServerEvent('speedradar:server:saveReading', savedReading)

    notify(('Måling gemt: %s - %s km/t'):format(reading.plate or 'UKENDT', reading.speed), 'success')
end



local function cloneHistoryForPrint()
    local copy = {}
    for i = #history, 1, -1 do
        local item = history[i]
        copy[#copy + 1] = {
            timestamp = tonumber(item.timestamp) or getUnixTime(),
            plate = tostring(item.plate or 'UKENDT'),
            speed = tonumber(item.speed) or 0,
            distance = tonumber(item.distance) or 0
        }
    end
    return copy
end

local function requestPrintout()
    -- Serveren holder den officielle liste over målinger.
    -- Hvis client-historik af en eller anden grund er tom, kan serveren stadig udskrive gemte målinger.
    TriggerServerEvent('speedradar:server:createPrintout')
end

local function openPrintout(metadata)
    metadata = metadata or {}
    printOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'printout',
        state = true,
        metadata = metadata
    })
end

local function closePrintout()
    if not printOpen then return end
    printOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'printout', state = false })
end

local function getEquipmentCameraBase()
    if not equipment or not DoesEntityExist(equipment) then return nil end

    -- Kameraet sidder nu fast på selve stativet i stedet for spilleren.
    -- Offsets kan tunes i config.lua, hvis prop-modellen ikke passer 100%.
    return GetOffsetFromEntityInWorldCoords(
        equipment,
        Config.CameraSideOffset or 0.0,
        Config.CameraForwardOffset or -0.18,
        Config.CameraHeight or 1.02
    )
end

local function getEquipmentAimPoint(distance)
    if not equipment or not DoesEntityExist(equipment) then return nil end

    local base = getEquipmentCameraBase()
    local heading = GetEntityHeading(equipment) + (Config.CameraHeadingOffset or 0.0)
    local rad = math.rad(heading)
    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)

    return base + (forward * (distance or 60.0))
end

local function setPlayerLocked(state)
    local ped = PlayerPedId()
    playerLocked = state
    FreezeEntityPosition(ped, state)
    SetPedCanRagdoll(ped, not state)
    ClearPedTasks(ped)
end

local function startScope()
    if aiming or not equipment or not DoesEntityExist(equipment) then return end
    aiming = true

    local coords = getEquipmentCameraBase()
    local aimPoint = getEquipmentAimPoint(80.0)
    camRot = vector3(0.0, 0.0, GetEntityHeading(equipment) + (Config.CameraHeadingOffset or 0.0))
    camFov = Config.DefaultFov

    radarCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(radarCam, coords.x, coords.y, coords.z)
    if aimPoint then
        PointCamAtCoord(radarCam, aimPoint.x, aimPoint.y, aimPoint.z)
        Wait(0)
        camRot = GetCamRot(radarCam, 2)
        StopCamPointing(radarCam)
    else
        SetCamRot(radarCam, camRot.x, 0.0, camRot.z, 2)
    end
    SetCamFov(radarCam, camFov)
    SetCamActive(radarCam, true)
    RenderScriptCams(true, false, 0, true, true)
    SendNUIMessage({ action = 'scope', state = true, fov = math.floor(camFov) })
end

local function stopScope()
    if not aiming then return end
    aiming = false
    RenderScriptCams(false, false, 0, true, true)
    if radarCam then DestroyCam(radarCam, false) end
    radarCam = nil
    currentReading = { action = 'update', hasTarget = false }
    SendNUIMessage({ action = 'scope', state = false })
    sendRadar({ action = 'update', hasTarget = false })
end

local function stopRadarMode()
    if not radarActive then return end
    radarActive = false
    stopScope()
    if playerLocked then setPlayerLocked(false) end
    SendNUIMessage({ action = 'hide' })
    notify('Fartkontrol lukket.', 'inform')
end


local function disableRadarControls()
    local pid = PlayerId()
    DisablePlayerFiring(pid, true)

    -- Lås karakteren, så man ikke kan gå/køre/slås mens kameraet er åbent
    DisableControlAction(0, 30, true)  -- move left/right
    DisableControlAction(0, 31, true)  -- move forward/back
    DisableControlAction(0, 32, true)  -- W
    DisableControlAction(0, 33, true)  -- S
    DisableControlAction(0, 34, true)  -- A
    DisableControlAction(0, 35, true)  -- D
    DisableControlAction(0, 21, true)  -- sprint
    DisableControlAction(0, 22, true)  -- jump
    DisableControlAction(0, 23, true)  -- enter vehicle
    DisableControlAction(0, 24, true)  -- attack / left click
    DisableControlAction(0, 25, true)  -- aim / right click
    DisableControlAction(0, 37, true)  -- weapon wheel
    DisableControlAction(0, 44, true)
    DisableControlAction(0, 140, true)
    DisableControlAction(0, 141, true)
    DisableControlAction(0, 142, true)
    DisableControlAction(0, 257, true)
    DisableControlAction(0, 263, true)
    DisableControlAction(0, 264, true)

    DisableControlAction(0, Config.ZoomInControl, true)
    DisableControlAction(0, Config.ZoomOutControl, true)
    DisableControlAction(0, Config.ExitControl, true)
    if Config.ExitControlAlt then DisableControlAction(0, Config.ExitControlAlt, true) end
end

local function updateScopeCamera()
    if not radarCam then return end

    local coords = getEquipmentCameraBase()
    if coords then SetCamCoord(radarCam, coords.x, coords.y, coords.z) end

    disableRadarControls()
    DisableControlAction(0, 1, true)
    DisableControlAction(0, 2, true)

    local lookX = GetDisabledControlNormal(0, 1)
    local lookY = GetDisabledControlNormal(0, 2)
    local sensitivity = (Config.ScopeMouseSensitivity or 9.0) * (camFov / Config.DefaultFov)

    camRot = vector3(
        math.max(Config.MaxPitchDown or -25.0, math.min(Config.MaxPitchUp or 25.0, camRot.x - lookY * sensitivity)),
        0.0,
        camRot.z - lookX * sensitivity
    )

    local zoomChanged = false
    if IsDisabledControlJustPressed(0, Config.ZoomInControl) then
        camFov = math.max(Config.MinFov, camFov - Config.ZoomStep)
        zoomChanged = true
    elseif IsDisabledControlJustPressed(0, Config.ZoomOutControl) then
        camFov = math.min(Config.MaxFov, camFov + Config.ZoomStep)
        zoomChanged = true
    end

    SetCamRot(radarCam, camRot.x, 0.0, camRot.z, 2)
    SetCamFov(radarCam, camFov)

    if zoomChanged then
        SendNUIMessage({ action = 'zoom', fov = math.floor(camFov) })
    end
end

local function raycastFromCamera(distance)
    local camCoord = radarCam and GetCamCoord(radarCam) or GetGameplayCamCoord()
    local camRotation = radarCam and GetCamRot(radarCam, 2) or GetGameplayCamRot(2)
    local direction = rotationToDirection(camRotation)
    local destination = camCoord + direction * distance
    local ray = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, destination.x, destination.y, destination.z, 10, equipment or PlayerPedId(), 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(ray)
    return hit == 1, endCoords, entityHit
end

local function scanTarget()
    if not radarActive or not aiming then return end

    local hit, _, entity = raycastFromCamera(Config.MaxDistance)
    local reading = { action = 'update', hasTarget = false }

    if hit and entity and entity ~= 0 and DoesEntityExist(entity) and IsEntityAVehicle(entity) then
        local baseCoords = GetEntityCoords(equipment)
        local vehCoords = GetEntityCoords(entity)
        reading = {
            action = 'update',
            hasTarget = true,
            speed = math.floor(GetEntitySpeed(entity) * 3.6 + 0.5),
            distance = math.floor(#(baseCoords - vehCoords) + 0.5),
            plate = string.gsub(GetVehicleNumberPlateText(entity) or 'UNKNOWN', '^%s*(.-)%s*$', '%1')
        }
    end

    currentReading = reading
    sendRadar(reading)
end

local function removeTarget()
    if targetAdded and equipment and DoesEntityExist(equipment) and GetResourceState('ox_target') == 'started' then
        pcall(function() exports.ox_target:removeLocalEntity(equipment) end)
    end
    targetAdded = false
end

local function packEquipment()
    stopRadarMode()
    if playerLocked then setPlayerLocked(false) end
    removeTarget()

    if equipment and DoesEntityExist(equipment) then
        SetEntityAsMissionEntity(equipment, true, true)
        DeleteObject(equipment)
        if DoesEntityExist(equipment) then DeleteEntity(equipment) end
    end

    equipment = nil
    TriggerServerEvent('speedradar:server:returnEquipment')
    notify('Fartkontrols Udstyr pakket sammen.', 'success')
end

local function openRadarMode()
    if not equipment or not DoesEntityExist(equipment) then
        notify('Fartkontrols Udstyr findes ikke.', 'error')
        return
    end

    if not isAllowed() then
        notify('Du har ikke adgang til fartkontrollen.', 'error')
        return
    end

    radarActive = true
    setPlayerLocked(true)
    lastPayload = nil
    SendNUIMessage({ action = 'show', history = history })
    startScope()
    notify('Fartkontrol åbnet. Venstreklik gemmer målingen. ESC/Backspace lukker.', 'success')
end

local function addTarget(entity)
    if not Config.UseOxTarget then return end
    if GetResourceState('ox_target') ~= 'started' then
        notify('ox_target er ikke startet, så øje-interaktion virker ikke.', 'error')
        return
    end

    exports.ox_target:addLocalEntity(entity, {
        {
            name = 'speedradar_use_equipment',
            icon = 'fa-solid fa-gauge-high',
            label = 'Brug fartkontrol',
            distance = Config.TargetDistance,
            canInteract = function(target)
                return target == equipment and DoesEntityExist(target)
            end,
            onSelect = function()
                openRadarMode()
            end
        },
        {
            name = 'speedradar_print_equipment',
            icon = 'fa-solid fa-file-lines',
            label = 'Udskriv rapport',
            distance = Config.TargetDistance,
            canInteract = function(target)
                return target == equipment and DoesEntityExist(target)
            end,
            onSelect = function()
                requestPrintout()
            end
        },
        {
            name = 'speedradar_pack_equipment',
            icon = 'fa-solid fa-box',
            label = 'Pak fartkontrol sammen',
            distance = Config.TargetDistance,
            canInteract = function(target)
                return target == equipment and DoesEntityExist(target)
            end,
            onSelect = function()
                packEquipment()
            end
        }
    })

    targetAdded = true
end

local function placeEquipmentObject()
    if Config.OneEquipmentPerPlayer and equipment and DoesEntityExist(equipment) then
        notify('Du har allerede sat Fartkontrols Udstyr op.', 'error')
        return
    end

    local ped = PlayerPedId()
    if Config.DisableInVehicle and IsPedInAnyVehicle(ped, false) then
        notify('Du kan ikke sætte udstyret fra et køretøj.', 'error')
        TriggerServerEvent('speedradar:server:returnEquipment')
        return
    end

    if not loadModel(Config.EquipmentModel) then
        notify('Kunne ikke loade proppen. Tjek stream-filer og modelnavn.', 'error')
        TriggerServerEvent('speedradar:server:returnEquipment')
        return
    end

    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local placeCoords = coords + (forward * Config.PlaceDistance)
    local _, groundZ = GetGroundZFor_3dCoord(placeCoords.x, placeCoords.y, placeCoords.z + 1.0, false)
    if groundZ and groundZ ~= 0.0 then placeCoords = vector3(placeCoords.x, placeCoords.y, groundZ + Config.PlaceZOffset) end

    local heading = GetEntityHeading(ped) + Config.PlaceHeadingOffset
    equipment = CreateObject(Config.EquipmentModel, placeCoords.x, placeCoords.y, placeCoords.z, true, true, false)
    SetEntityHeading(equipment, heading)
    PlaceObjectOnGroundProperly(equipment)
    SetEntityAsMissionEntity(equipment, true, true)
    if Config.FreezeEquipment then FreezeEntityPosition(equipment, true) end
    SetModelAsNoLongerNeeded(Config.EquipmentModel)

    addTarget(equipment)
    notify('Fartkontrols Udstyr sat op. Brug øjet på stativet.', 'success')
end

RegisterNetEvent('speedradar:client:placeEquipment', placeEquipmentObject)

RegisterNetEvent('speedradar:client:placeFailed', function(msg)
    notify(msg or 'Kunne ikke sætte Fartkontrols Udstyr.', 'error')
end)

RegisterNetEvent('speedradar:client:printCreated', function()
    notify('Fartkontrol Udskrift lagt i inventory.', 'success')
end)

RegisterNetEvent('speedradar:client:printFailed', function(msg)
    notify(msg or 'Kunne ikke lave udskrift.', 'error')
end)

local function useFartkontrolItem(data, slot)
    exports.ox_inventory:useItem(data, function(success)
        if success then
            TriggerServerEvent('speedradar:server:placeEquipment')
        end
    end)
end

exports('useRadar', useFartkontrolItem)
exports('useFartkontrol', useFartkontrolItem)

RegisterNetEvent('speedradar:client:openPrintout', function(metadata)
    metadata = metadata or {}

    if metadata.printData then
        metadata.officer = metadata.officer or metadata.printData.officer
        metadata.created = metadata.created or metadata.printData.created
        metadata.readings = metadata.readings or metadata.printData.readings or metadata.printData.measurements
        metadata.measurements = metadata.measurements or metadata.printData.measurements or metadata.printData.readings
    end

    metadata.readings = metadata.readings or metadata.measurements or {}
    openPrintout(metadata)
end)

local function getPrintoutSlot(data, slot)
    if type(slot) == 'number' then
        return slot
    elseif type(data) == 'table' and type(data.slot) == 'number' then
        return data.slot
    elseif type(data) == 'number' then
        return data
    end

    return nil
end

exports('usePrintout', function(data, slot)
    local slotId = getPrintoutSlot(data, slot)

    -- Brug itemet = læs udskriften.
    -- Ødelæg udskrift ligger som højreklik-knap i ox_inventory/data/items.lua.
    if slotId then
        TriggerServerEvent('speedradar:server:openPrintout', slotId)
    else
        TriggerEvent('speedradar:client:openPrintout', data and data.metadata or {})
    end
end)

RegisterNUICallback('closePrintout', function(_, cb)
    closePrintout()
    cb(true)
end)

RegisterCommand(Config.Command, function()
    if equipment and DoesEntityExist(equipment) then
        openRadarMode()
    else
        notify('Du skal sætte Fartkontrols Udstyr op via inventory først.', 'error')
    end
end, false)

CreateThread(function()
    while true do
        if not radarActive then
            Wait(500)
        else
            local ped = PlayerPedId()
            if IsEntityDead(ped) or not equipment or not DoesEntityExist(equipment) then
                stopRadarMode()
                Wait(500)
            else
                -- Kameraet er aktivt med det samme når man bruger øjet.
                -- Højreklik bruges ikke længere til at holde sigtet åbent.
                if not aiming then startScope() end
                updateScopeCamera()

                if IsDisabledControlJustPressed(0, Config.MeasureControl) then
                    saveReading(currentReading)
                end

                if IsDisabledControlJustPressed(0, Config.ExitControl) or (Config.ExitControlAlt and IsDisabledControlJustPressed(0, Config.ExitControlAlt)) then
                    stopRadarMode()
                end

                Wait(0)
            end
        end
    end
end)

CreateThread(function()
    while true do
        if radarActive and aiming then
            scanTarget()
            Wait(Config.ScanInterval)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    stopRadarMode()
    closePrintout()
    removeTarget()
    if equipment and DoesEntityExist(equipment) then
        SetEntityAsMissionEntity(equipment, true, true)
        DeleteObject(equipment)
        if DoesEntityExist(equipment) then DeleteEntity(equipment) end
    end
end)
