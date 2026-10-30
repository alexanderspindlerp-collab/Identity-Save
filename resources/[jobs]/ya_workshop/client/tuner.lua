local ESX = exports['es_extended']:getSharedObject()

--- Bruger GTA's normale køretøjs-POV (som esx_lscustom / GTA Online LSC) — ingen script-cam.
local TunerCamera = {
    active = false,
    vehicle = 0,
    mouseInMenu = true,
    orbitOffset = 0.0,
    targetHeading = 0.0,
    targetZoom = 1,
    currentPresetName = 'default',
    savedVehicleViewMode = nil,
    savedVehicleZoom = nil,
}

local tunerOpen = false
local activeShopKey = nil
local policeModeActive = false
local policeSavePending = false
local pendingPoliceCart = nil
local shopData = nil
local activeVehicle = 0
local cachedSessionVehicle = nil

local function getCameraView(name)
    local views = Config.CameraViews or {}
    return views[name] or views.front or { heading = 0.0, zoom = 1 }
end

local function getCameraPreset(name)
    local presets = Config.CameraPresets or {}
    return presets[name] or presets.default or presets.customization
end

local function clampCamera(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

local function resolvePresetName(categoryKey, groupKey, itemKey)
    if itemKey then
        if itemKey == 'paint_rgb' and getCameraPreset('paint_primary') then
            return 'paint_primary'
        end

        local rgbBase = itemKey:match('^(.+)_rgb$')
        if rgbBase and getCameraPreset(rgbBase) then
            return rgbBase
        end

        local baseKey = itemKey:match('^(.+)_%-?%d+$') or itemKey
        if getCameraPreset(baseKey) then return baseKey end
        if getCameraPreset(itemKey) then return itemKey end
    end
    if groupKey and getCameraPreset(groupKey) then return groupKey end
    if categoryKey and getCameraPreset(categoryKey) then return categoryKey end
    return Config.Camera and Config.Camera.defaultPreset or 'default'
end

local function requestEntityControl(entity, attempts)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    local maxAttempts = attempts or 50
    local count = 0
    while not NetworkHasControlOfEntity(entity) and count < maxAttempts do
        Wait(10)
        NetworkRequestControlOfEntity(entity)
        count = count + 1
    end

    return NetworkHasControlOfEntity(entity)
end

local function releaseVehicle(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        FreezeEntityPosition(vehicle, false)
        SetVehicleDoorsLocked(vehicle, 1)
    end
end

local function prepareTunerSession(vehicle)
    requestEntityControl(vehicle)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetVehicleDoorsShut(vehicle, true)
    FreezeEntityPosition(vehicle, true)
    return true
end

local function applyGameplayVehicleCam(self)
    if not self.active or not DoesEntityExist(self.vehicle) then return end

    local viewMode = (Config.Camera and Config.Camera.vehicleViewMode) or 1
    SetFollowVehicleCamViewMode(viewMode)
    SetFollowPedCamViewMode(viewMode)
    InvalidateIdleCam()
    InvalidateVehicleIdleCam()
    DisableFirstPersonCamThisFrame()

    local zoom = clampCamera(self.targetZoom or 1, 0, 4)
    SetFollowVehicleCamZoomLevel(zoom)

    local heading = (self.targetHeading or 0.0) + (self.orbitOffset or 0.0)
    SetGameplayCamRelativeHeading(heading)
end

local function forceCleanupTuner(vehicle)
    vehicle = vehicle or TunerCamera.vehicle or activeVehicle or 0

    TunerCamera.active = false
    TunerCamera.mouseInMenu = true
    TunerCamera.vehicle = 0

    pcall(function()
        if TunerCamera.savedVehicleViewMode ~= nil then
            SetFollowVehicleCamViewMode(TunerCamera.savedVehicleViewMode)
            TunerCamera.savedVehicleViewMode = nil
        end
        if TunerCamera.savedVehicleZoom ~= nil then
            SetFollowVehicleCamZoomLevel(TunerCamera.savedVehicleZoom)
            TunerCamera.savedVehicleZoom = nil
        end

        SetFollowPedCamViewMode(0)
        InvalidateIdleCam()
        InvalidateVehicleIdleCam()
    end)

    pcall(function()
        releaseVehicle(vehicle)
    end)

    DisplayRadar(true)
    DisplayHud(true)
end

function TunerCamera:ApplyPreset(presetName, keepAdjustments)
    local preset = getCameraPreset(presetName)
    if not preset then return end

    self.currentPresetName = presetName
    if not keepAdjustments then
        self.orbitOffset = 0.0
    end

    local view = getCameraView(preset.view or 'front')
    self.targetHeading = preset.heading or view.heading or 0.0
    self.targetZoom = preset.zoom or view.zoom or 1
    applyGameplayVehicleCam(self)
end

function TunerCamera:Focus(categoryKey, groupKey, itemKey)
    if not self.active then return end

    local presetName = resolvePresetName(categoryKey, groupKey, itemKey)
    local preset = getCameraPreset(presetName)
    local view = getCameraView(preset and preset.view or 'front')
    local nextHeading = preset and (preset.heading or view.heading) or view.heading or 180.0
    local nextZoom = preset and (preset.zoom or view.zoom) or view.zoom or 1

    if math.abs((self.targetHeading or 0.0) - nextHeading) > 0.01
        or (self.targetZoom or 1) ~= nextZoom then
        self.orbitOffset = 0.0
    end

    self:ApplyPreset(presetName, true)
end

function TunerCamera:DisableControls()
    local controls = {
        30, 31, 32, 33, 34, 35, 21, 22, 23, 24, 25, 44, 37, 288, 289,
        75, 71, 72, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70,
    }
    for i = 1, #controls do
        DisableControlAction(0, controls[i], true)
    end
    DisableControlAction(2, 75, true)
    DisableControlAction(27, 75, true)
end

function TunerCamera:Start(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    self.vehicle = vehicle
    self.active = true
    self.mouseInMenu = false
    self.orbitOffset = 0.0

    self.savedVehicleViewMode = GetFollowVehicleCamViewMode()
    self.savedVehicleZoom = GetFollowVehicleCamZoomLevel()

    self:ApplyPreset(Config.Camera and Config.Camera.defaultPreset or 'default')

    DisplayRadar(false)
    DisplayHud(false)

    CreateThread(function()
        while TunerCamera.active do
            TunerCamera:DisableControls()
            applyGameplayVehicleCam(TunerCamera)
            DisplayHud(false)
            DisplayRadar(false)
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)

    return true
end

function TunerCamera:Stop()
    forceCleanupTuner(self.vehicle)
end

function TunerCamera:SetMouseInMenu(inside)
    self.mouseInMenu = inside == true
end

function TunerCamera:Rotate(delta)
    local rotateSpeed = (Config.Camera and Config.Camera.rotateSpeed) or 1.4
    delta = tonumber(delta) or 0
    if delta == 0 then return end
    self.orbitOffset = (self.orbitOffset or 0.0) + (delta * rotateSpeed)
end

function TunerCamera:Zoom(delta)
    local zoomStep = (Config.Camera and Config.Camera.zoomStep) or 1
    delta = tonumber(delta) or 0
    if delta > 0 then
        self.targetZoom = clampCamera((self.targetZoom or 1) - zoomStep, 0, 4)
    elseif delta < 0 then
        self.targetZoom = clampCamera((self.targetZoom or 1) + zoomStep, 0, 4)
    end
end

local function getVehicleEntity()
    if tunerOpen and activeVehicle ~= 0 and DoesEntityExist(activeVehicle) then
        return activeVehicle
    end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0 end
    return GetVehiclePedIsIn(ped, false)
end

local function getVehicleData()
    local veh = getVehicleEntity()
    if veh == 0 then return nil end

    local props = ESX.Game.GetVehicleProperties(veh)
    local model = props.model
    local display = GetDisplayNameFromVehicleModel(model)
    local label = GetLabelText(display)
    if label == 'NULL' or label == '' then label = display end

    return {
        plate = props.plate or GetVehicleNumberPlateText(veh),
        model = model,
        label = label,
        props = props,
    }
end

local function getSessionVehicleData()
    if cachedSessionVehicle then
        return cachedSessionVehicle
    end
    return getVehicleData()
end

local function closeTuner(options)
    options = options or {}
    local veh = activeVehicle ~= 0 and activeVehicle or TunerCamera.vehicle
    local skipReset = options.skipPreviewReset == true

    tunerOpen = false
    activeShopKey = nil
    policeModeActive = false
    policeSavePending = false
    shopData = nil
    activeVehicle = 0
    cachedSessionVehicle = nil

    TunerCamera.active = false

    SetNuiFocus(false, false)
    pcall(SetNuiFocusKeepInput, false)
    SendNUIMessage({ action = 'close', keepVehicle = skipReset })

    if not skipReset then
        pcall(function()
            VehicleCatalog.ResetPreview(veh)
        end)
    end
    VehicleCatalog.baselineProps = nil
    VehicleCatalog.activePreview = nil

    CreateThread(function()
        Wait(0)
        pcall(function()
            TunerCamera:Stop()
        end)
        pcall(function()
            releaseVehicle(veh)
        end)
        if GetResourceState('ox_lib') == 'started' then
            pcall(lib.hideTextUI)
        end
        TriggerEvent('ya_workshop:tunerClosed')
    end)
end

local function startTunerUI(shopKey, data, veh, vehicle, options)
    options = options or {}
    activeShopKey = shopKey
    shopData = data
    activeVehicle = veh
    cachedSessionVehicle = vehicle
    policeModeActive = options.policeMode == true

    if GetResourceState('ox_lib') == 'started' then
        lib.hideTextUI()
    end

    CreateThread(function()
        local ok, err = pcall(function()
            prepareTunerSession(veh)
            VehicleCatalog.SetBaseline(veh)
            Wait(100)

            if not TunerCamera:Start(veh) then
                error('camera_start_failed')
            end

            TunerCamera:Focus('customization')
            Wait(50)

            local enrichOptions = policeModeActive and { policeMode = true } or nil
            local categories = VehicleCatalog.EnrichCategories(data.categories or {}, veh, enrichOptions)

            tunerOpen = true

            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)

            SendNUIMessage({
                action = 'open',
                policeMode = policeModeActive,
                shop = {
                    key = data.shopKey or shopKey,
                    label = data.shopLabel,
                    companyName = data.companyName,
                    branding = data.branding,
                    brandingLabel = data.brandingLabel,
                },
                vehicle = vehicle,
                categories = categories,
                unlockedGroups = data.unlockedGroups or {},
            })

            CreateThread(function()
                while tunerOpen do
                    if IsControlJustPressed(0, 200) or IsControlJustPressed(0, 322) then
                        SendNUIMessage({ action = 'escape' })
                    end
                    Wait(0)
                end
            end)
        end)

        if not ok then
            print(('[ya_workshop] openTuner failed: %s'):format(tostring(err)))
            ESX.ShowNotification('Kunne ikke åbne værksted.')
            closeTuner()
        end
    end)
end

local function openTuner(shopKey, options)
    options = options or {}

    if tunerOpen then
        if activeVehicle == 0 or not DoesEntityExist(activeVehicle) then
            closeTuner()
        else
            return
        end
    end

    local vehicle, veh
    if options.vehicle and options.vehicleEntity then
        vehicle = options.vehicle
        veh = options.vehicleEntity
    else
        vehicle = getVehicleData()
        veh = getVehicleEntity()
    end

    if not vehicle or veh == 0 then
        ESX.ShowNotification('Du skal sidde i et køretøj.')
        return
    end

    if options.policeMode and options.shopData then
        if not veh or veh == 0 then
            veh = getVehicleEntity()
        end
        if not vehicle then
            vehicle = getVehicleData()
        end
        if not vehicle or veh == 0 then
            ESX.ShowNotification('Du skal sidde i et køretøj.')
            return
        end
        startTunerUI(shopKey or 'police_autoshop', options.shopData, veh, vehicle, options)
        return
    end

    ESX.TriggerServerCallback('ya_workshop:canTuneVehicle', function(canTune, tuneMsg)
        if not canTune then
            ESX.ShowNotification(tuneMsg or 'Du kan ikke tune denne bil.')
            TriggerEvent('ya_workshop:tunerClosed')
            return
        end

        ESX.TriggerServerCallback('ya_workshop:getCompanyForShop', function(data)
            if not data then
                ESX.ShowNotification('Kunne ikke åbne værksted.')
                TriggerEvent('ya_workshop:tunerClosed')
                return
            end
            if data.error then
                ESX.ShowNotification(data.error)
                TriggerEvent('ya_workshop:tunerClosed')
                return
            end

            startTunerUI(shopKey, data, veh, vehicle, options)
        end, shopKey, vehicle.plate)
    end, vehicle.plate)
end

function OpenTunerMenu(shopKey, options)
    openTuner(shopKey, options)
end

exports('OpenTunerMenu', OpenTunerMenu)

RegisterNUICallback('close', function(_, cb)
    closeTuner()
    cb('ok')
end)

RegisterNUICallback('previewItem', function(data, cb)
    if not tunerOpen or activeVehicle == 0 then cb('ok'); return end

    if data and data.reset then
        if not policeSavePending then
            VehicleCatalog.ResetPreview(activeVehicle)
        end
    elseif data then
        local modData = data.mod
        if not modData and data.itemKey then
            modData = VehicleCatalog.ResolveModFromItemKey(data.itemKey)
        end

        if data.itemKey then
            TunerCamera:Focus(data.categoryKey, data.groupKey, data.itemKey)
        end

        if modData then
            VehicleCatalog.Preview(activeVehicle, modData)
        end
    end
    cb('ok')
end)

RegisterNUICallback('focusCamera', function(data, cb)
    if tunerOpen and data and data.itemKey then
        TunerCamera:Focus(data.categoryKey, data.groupKey, data.itemKey)
    end
    cb('ok')
end)

RegisterNUICallback('applyRgbColor', function(data, cb)
    if not tunerOpen or activeVehicle == 0 or type(data) ~= 'table' then cb('ok'); return end

    local modData = {
        kind = 'customColor',
        prop = data.prop or 'color1',
        r = tonumber(data.r) or 255,
        g = tonumber(data.g) or 255,
        b = tonumber(data.b) or 255,
    }

    if data.itemKey then
        TunerCamera:Focus(data.categoryKey, data.groupKey, data.itemKey)
    end

    VehicleCatalog.Preview(activeVehicle, modData)
    cb('ok')
end)

RegisterNUICallback('previewMod', function(data, cb)
    if tunerOpen and activeVehicle ~= 0 then
        if data and data.reset then
            VehicleCatalog.ResetPreview(activeVehicle)
        elseif data and data.mod then
            VehicleCatalog.Preview(activeVehicle, data.mod)
        end
    end
    cb('ok')
end)

RegisterNUICallback('cameraRotate', function(data, cb)
    if tunerOpen then
        TunerCamera:Rotate(data and data.delta)
    end
    cb('ok')
end)

RegisterNUICallback('cameraZoom', function(data, cb)
    if tunerOpen then
        TunerCamera:Zoom(data and data.delta)
    end
    cb('ok')
end)

RegisterNUICallback('setMouseInMenu', function(data, cb)
    TunerCamera:SetMouseInMenu(data and data.inside == true)
    cb('ok')
end)

RegisterNUICallback('submitOrder', function(data, cb)
    local vehicle = getSessionVehicleData()
    if not vehicle then
        ESX.ShowNotification('Køretøjsdata mangler.')
        cb('ok')
        return
    end

    if policeModeActive then
        local cart = data and data.cart or {}
        if type(cart) ~= 'table' or next(cart) == nil then
            ESX.ShowNotification('Ingen ændringer valgt.')
            cb('ok')
            return
        end

        policeSavePending = true
        pendingPoliceCart = cart
        TriggerServerEvent('ya_workshop:submitPoliceTune', cart, vehicle)
        cb('ok')
        return
    end

    if not activeShopKey then cb('ok'); return end
    TriggerServerEvent('ya_workshop:submitOrder', activeShopKey, data and data.cart or {}, vehicle)
    closeTuner()
    cb('ok')
end)

local function applyPoliceCartToVehicle(vehicle, cart)
    if not vehicle or vehicle == 0 or type(cart) ~= 'table' then return end

    for i = 1, #cart do
        local line = cart[i]
        if type(line) == 'table' and line.type ~= 'unlock' and type(line.mod) == 'table' then
            pcall(function()
                VehicleCatalog.ApplyModNative(vehicle, line.mod)
            end)
        end
    end
end

RegisterNetEvent('ya_workshop:client:policeTuneSaved', function(props)
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        pendingPoliceCart = nil
        CreateThread(function()
            Wait(50)
            TriggerEvent('ya_workshop:policeTunerSaveDone')
        end)
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if not vehicle or vehicle == 0 then return end

    if props and props.plate then
        local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
        local saved = ESX.Math.Trim(props.plate)
        if plate:gsub('%s+', ''):upper() ~= saved:gsub('%s+', ''):upper() then
            pendingPoliceCart = nil
            return
        end
    end

    -- Undgå ESX.Game.SetVehicleProperties med fulde DB-props — crasher ofte på politibiler.
    if pendingPoliceCart then
        applyPoliceCartToVehicle(vehicle, pendingPoliceCart)
        pendingPoliceCart = nil
    end

    if props and type(props.policeExtras) == 'table' then
        exports.ya_workshop:ApplyPoliceExtrasToVehicle(vehicle, props.policeExtras)
    end

    pcall(function()
        VehicleCatalog.SetBaseline(vehicle)
    end)

    CreateThread(function()
        Wait(50)
        TriggerEvent('ya_workshop:policeTunerSaveDone')
    end)
end)

RegisterNetEvent('ya_workshop:orderPlaced', function()
    closeTuner()
end)

AddEventHandler('ya_workshop:policeTunerSaveDone', function()
    if tunerOpen or policeSavePending then
        closeTuner({ skipPreviewReset = true })
    end
end)

RegisterNetEvent('ya_workshop:client:policeTuneFailed', function()
    policeSavePending = false
    pendingPoliceCart = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeTuner()
end)

RegisterCommand('tunerfix', function()
    closeTuner()
    forceCleanupTuner()
    if GetResourceState('ox_lib') == 'started' then
        lib.hideTextUI()
    end
    TriggerEvent('ya_workshop:tunerClosed')
    ESX.ShowNotification('Tuner nulstillet.')
end, false)
