local hasAlreadyEnteredMarker, hasPaid, currentActionData = false, false, {}
local lastZone, currentAction, currentActionMsg
local oldSkin, currentSkin, currentMaxVals = nil, nil, {}
local isShopOpen, cam = false, nil

local function shallowCopy(tbl)
    local out = {}
    if tbl then for k, v in pairs(tbl) do out[k] = v end end
    return out
end

local function getMax(name)
    local value = currentMaxVals and currentMaxVals[name]
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    return value
end

local function buildCategories()
    local cats = {}
    for _, cat in ipairs(Config.ModernCategories or {}) do
        local drawableMax = getMax(cat.drawable)
        local textureMax = cat.texture and getMax(cat.texture) or 0
        cats[#cats + 1] = {
            id = cat.id,
            label = cat.label,
            icon = cat.icon,
            drawable = cat.drawable,
            texture = cat.texture,
            drawableMax = drawableMax,
            textureMax = textureMax,
            currentDrawable = tonumber(currentSkin[cat.drawable]) or 0,
            currentTexture = cat.texture and (tonumber(currentSkin[cat.texture]) or 0) or 0,
            price = Config.Price or 0
        }
    end
    return cats
end

local function changedPieces()
    if not oldSkin or not currentSkin then return 0 end
    local changed = 0
    for _, value in pairs(Config.SkinProps or {}) do
        if currentSkin[value .. '_1'] ~= oldSkin[value .. '_1'] or currentSkin[value .. '_2'] ~= oldSkin[value .. '_2'] then
            changed = changed + 1
        end
    end
    return changed
end

local function currentPrice()
    if Config.ChargePerPiece then
        local pieces = changedPieces()
        if pieces < 1 then return 0 end
        return pieces * (Config.Price or 0)
    end
    return Config.Price or 0
end

local function refreshNui()
    SendNUIMessage({
        action = 'setData',
        categories = buildCategories(),
        price = currentPrice(),
        chargePerPiece = Config.ChargePerPiece or false
    })
end

local function createCam()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local forward = GetEntityForwardVector(ped)
    local camCoords = coords + forward * 2.2 + vector3(0.0, 0.0, 0.65)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(cam, coords.x, coords.y, coords.z + 0.35)
    SetCamFov(cam, 35.0)
    RenderScriptCams(true, true, 350, true, true)
    SetEntityHeading(ped, heading + 180.0)
end

local function destroyCam()
    if cam then
        RenderScriptCams(false, true, 250, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function closeModernShop(save)
    if not isShopOpen then return end
    isShopOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    destroyCam()
    FreezeEntityPosition(PlayerPedId(), false)

    if not save and oldSkin then
        TriggerEvent('skinchanger:loadSkin', oldSkin)
    end

    currentAction     = 'shop_menu'
    currentActionMsg  = TranslateCap('press_menu')
    currentActionData = {}
end

function OpenModernShopMenu()
    ESX.HideUI()
    hasPaid = false
    isShopOpen = true

    TriggerEvent('skinchanger:getSkin', function(skin)
        oldSkin = shallowCopy(skin)
        currentSkin = shallowCopy(skin)
    end)

    TriggerEvent('skinchanger:getData', function(components, maxVals)
        currentMaxVals = maxVals or {}
    end)

    Wait(150)
    FreezeEntityPosition(PlayerPedId(), true)
    createCam()
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'open',
        locale = 'da',
        title = 'Tøjbutik',
        playerName = GetPlayerName(PlayerId()),
        categories = buildCategories(),
        price = currentPrice(),
        currency = 'DKK',
        chargePerPiece = Config.ChargePerPiece or false
    })
end

function OpenShopMenu()
    if Config.UseModernUI then
        OpenModernShopMenu()
        return
    end

    ESX.HideUI()
    hasPaid = false
    TriggerEvent('skinchanger:getSkin', function(skin) oldSkin = skin end)
    TriggerEvent('esx_skin:openRestrictedMenu', function(data, menu)
        menu.close()
        local elements = {
            {unselectable = true, icon = "fas fa-check-double", title = TranslateCap("valid_this_purchase")},
            {icon = "fas fa-check-circle", title = TranslateCap("yes"), value = "yes"},
            {icon = "fas fa-window-close", title = TranslateCap("no"), value = "no"},
        }
        ESX.OpenContext("right", elements, function(menu,element)
            if element.value == "yes" then
                TriggerEvent('skinchanger:getSkin', function(skin) newSkin = skin end)
                ESX.TriggerServerCallback('esx_clotheshop:buyClothes', function(bought)
                    if bought then
                        TriggerEvent('skinchanger:getSkin', function(skin)
                            TriggerServerEvent('esx_skin:save', skin)
                        end)
                        hasPaid = true
                    else
                        ESX.CloseContext()
                        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                            TriggerEvent('skinchanger:loadSkin', skin)
                        end)
                        ESX.ShowNotification(TranslateCap('not_enough_money'))
                    end
                end, newSkin, oldSkin)
            elseif element.value == "no" then
                ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
                    TriggerEvent('skinchanger:loadSkin', skin)
                end)
                ESX.CloseContext()
            end
            currentAction = 'shop_menu'
            currentActionMsg = TranslateCap('press_menu')
            currentActionData = {}
        end, function(menu)
            hasAlreadyEnteredMarker = false
            currentAction = 'shop_menu'
            currentActionMsg = TranslateCap('press_menu')
            currentActionData = {}
        end)
    end, function(data, menu)
        menu.close()
        hasAlreadyEnteredMarker = false
        currentAction = 'shop_menu'
        currentActionMsg = TranslateCap('press_menu')
        currentActionData = {}
    end, {
        'tshirt_1', 'tshirt_2', 'torso_1', 'torso_2', 'decals_1', 'decals_2', 'arms', 'arms_2',
        'pants_1', 'pants_2', 'shoes_1', 'shoes_2', 'bags_1', 'bags_2', 'chain_1', 'chain_2',
        'helmet_1', 'helmet_2', 'glasses_1', 'glasses_2', 'watches_1', 'watches_2'
    })
end

RegisterNUICallback('selectDrawable', function(data, cb)
    if not isShopOpen or not data or not data.key then cb(false) return end
    local value = tonumber(data.value) or 0
    currentSkin[data.key] = value
    TriggerEvent('skinchanger:change', data.key, value)

    if data.textureKey then
        currentSkin[data.textureKey] = 0
        TriggerEvent('skinchanger:change', data.textureKey, 0)
    end

    Wait(25)
    TriggerEvent('skinchanger:getData', function(_, maxVals)
        currentMaxVals = maxVals or currentMaxVals or {}
    end)
    refreshNui()
    cb(true)
end)

RegisterNUICallback('setTexture', function(data, cb)
    if not isShopOpen or not data or not data.key then cb(false) return end
    local value = tonumber(data.value) or 0
    local max = getMax(data.key)
    if value < 0 then value = max end
    if value > max then value = 0 end
    currentSkin[data.key] = value
    TriggerEvent('skinchanger:change', data.key, value)
    refreshNui()
    cb(true)
end)

RegisterNUICallback('rotatePed', function(data, cb)
    local ped = PlayerPedId()
    local dir = tonumber(data.dir) or 0
    SetEntityHeading(ped, GetEntityHeading(ped) + dir)
    cb(true)
end)

RegisterNUICallback('buy', function(data, cb)
    if not isShopOpen then cb(false) return end
    TriggerEvent('skinchanger:getSkin', function(skin)
        currentSkin = shallowCopy(skin)
        ESX.TriggerServerCallback('esx_clotheshop:buyClothes', function(bought)
            if bought then
                TriggerServerEvent('esx_skin:save', currentSkin)
                hasPaid = true
                closeModernShop(true)
            else
                ESX.ShowNotification(TranslateCap('not_enough_money'))
            end
            cb(bought)
        end, currentSkin, oldSkin)
    end)
end)

RegisterNUICallback('close', function(data, cb)
    closeModernShop(false)
    cb(true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        closeModernShop(false)
        destroyCam()
    end
end)

AddEventHandler('esx_clotheshop:hasEnteredMarker', function(zone)
    currentAction     = 'shop_menu'
    currentActionMsg  = TranslateCap('press_menu')
    currentActionData = {}
    ESX.TextUI(currentActionMsg)
end)

AddEventHandler('esx_clotheshop:hasExitedMarker', function(zone)
    ESX.CloseContext()
    ESX.HideUI()
    currentAction = nil
    if isShopOpen then closeModernShop(false) end
    if not hasPaid and oldSkin then
        ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
            TriggerEvent('skinchanger:loadSkin', skin)
        end)
    end
end)

CreateThread(function()
    for k,v in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(v)
        SetBlipSprite (blip, 73)
        SetBlipColour (blip, 47)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(TranslateCap('clothes'))
        EndTextCommandSetBlipName(blip)
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        local playerCoords, isInMarker, currentZone, letSleep = GetEntityCoords(PlayerPedId()), false, nil, true
        for k,v in pairs(Config.Shops) do
            local distance = #(playerCoords - v)
            if distance < Config.DrawDistance then
                letSleep = false
                DrawMarker(Config.MarkerType, v, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.MarkerSize.x, Config.MarkerSize.y, Config.MarkerSize.z, Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, nil, nil, false)
                if distance < Config.MarkerSize.x then
                    isInMarker, currentZone = true, k
                end
            end
        end
        if (isInMarker and not hasAlreadyEnteredMarker) or (isInMarker and lastZone ~= currentZone) then
            hasAlreadyEnteredMarker, lastZone = true, currentZone
            TriggerEvent('esx_clotheshop:hasEnteredMarker', currentZone)
        end
        if not isInMarker and hasAlreadyEnteredMarker then
            hasAlreadyEnteredMarker = false
            TriggerEvent('esx_clotheshop:hasExitedMarker', lastZone)
        end
        if letSleep then Wait(500) end
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if isShopOpen then
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 200, true)
            if IsDisabledControlJustPressed(0, 200) then
                closeModernShop(false)
            end
        elseif currentAction then
            if IsControlJustReleased(0, 38) then
                if currentAction == 'shop_menu' then OpenShopMenu() end
                currentAction = nil
            end
        else
            Wait(500)
        end
    end
end)
