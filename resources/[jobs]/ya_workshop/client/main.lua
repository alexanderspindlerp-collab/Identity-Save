local ESX = exports['es_extended']:getSharedObject()

local currentShopKey = nil
local isEmployee = false
local activeShops = {}
local shopZones = {}
local shopBlips = {}
local shopPromptActive = false
local shopKeybind = nil
local openingShop = false

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function getShopRadius(shop)
    return tonumber(shop and shop.radius)
        or (Config.ShopZone and Config.ShopZone.DefaultRadius)
        or 22.0
end

local function getShopHeight()
    return (Config.ShopZone and Config.ShopZone.Height) or 16.0
end

local function isInsideShop(shop, coords)
    if not shop or not shop.pos then return false end

    local radius = getShopRadius(shop)
    local height = getShopHeight()
    local dx = coords.x - shop.pos.x
    local dy = coords.y - shop.pos.y
    local dz = math.abs(coords.z - shop.pos.z)

    return (dx * dx + dy * dy) <= (radius * radius) and dz <= (height * 0.5)
end

local function hideShopPrompt()
    if shopPromptActive and resourceStarted('ox_lib') then
        lib.hideTextUI()
        shopPromptActive = false
    end
end

local function setShopKeybindEnabled(enabled)
    if shopKeybind then
        shopKeybind:disable(not enabled)
    end
end

local function isBoostPriority()
    if not resourceStarted('ya_workshop') then return false end
    local ok, active = pcall(function()
        return exports.ya_workshop:IsBoostInteractionActive()
    end)
    return ok and active == true
end

local function updateShopPrompt()
    if isBoostPriority() then
        hideShopPrompt()
        setShopKeybindEnabled(false)
        return
    end

    if not currentShopKey or not resourceStarted('ox_lib') then
        hideShopPrompt()
        setShopKeybindEnabled(false)
        return
    end

    local shop = activeShops[currentShopKey]
    if not shop then
        hideShopPrompt()
        setShopKeybindEnabled(false)
        return
    end

    local ped = PlayerPedId()
    local inVehicle = IsPedInAnyVehicle(ped, false)
    local label = shop.companyName or shop.label or 'værkstedet'

    if inVehicle then
        lib.showTextUI(('[E] %s — Bestil tuning'):format(label), {
            position = 'right-center',
            icon = 'wrench',
        })
        shopPromptActive = true
        setShopKeybindEnabled(true)
    elseif not isEmployee then
        lib.showTextUI(('Kør ind i %s for at bestille'):format(label), {
            position = 'right-center',
            icon = 'car',
        })
        shopPromptActive = true
        setShopKeybindEnabled(false)
    else
        hideShopPrompt()
        setShopKeybindEnabled(false)
    end
end

local function tryOpenShop(shopKey)
    if openingShop or not shopKey then return end

    if not IsPedInAnyVehicle(PlayerPedId(), false) then
        ESX.ShowNotification('Du skal sidde i et køretøj for at bestille.')
        return
    end

    if resourceStarted('ox_lib') and lib.progressActive and lib.progressActive() then
        return
    end

    openingShop = true
    hideShopPrompt()
    setShopKeybindEnabled(false)

    CreateThread(function()
        local ok, err = pcall(function()
            exports.ya_workshop:OpenTunerMenu(shopKey)
        end)

        if not ok then
            print(('[ya_workshop] OpenTunerMenu failed: %s'):format(tostring(err)))
            ESX.ShowNotification('Kunne ikke åbne værksted.')
        end

        openingShop = false
        if currentShopKey then
            updateShopPrompt()
        end
    end)
end

local function refreshCurrentShopZone()
    local coords = GetEntityCoords(PlayerPedId())
    local foundKey = nil

    for key, shop in pairs(activeShops) do
        if isInsideShop(shop, coords) then
            foundKey = key
            break
        end
    end

    currentShopKey = foundKey
    if currentShopKey then
        updateShopPrompt()
    else
        hideShopPrompt()
        setShopKeybindEnabled(false)
    end
end

local function clearShopZones()
    for _, zone in pairs(shopZones) do
        if zone and zone.remove then
            zone:remove()
        end
    end
    shopZones = {}
end

local function clearShopBlips()
    for _, blip in pairs(shopBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    shopBlips = {}
end

local function createShopBlip(key, shop)
    if not shop.pos or not shop.blip then return end
    local blip = AddBlipForCoord(shop.pos.x, shop.pos.y, shop.pos.z)
    SetBlipSprite(blip, shop.blip.sprite or 72)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, shop.blip.scale or 0.85)
    SetBlipColour(blip, shop.blip.color or 3)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(shop.blip.name or shop.label or 'Værksted')
    EndTextCommandSetBlipName(blip)
    shopBlips[key] = blip
end

local function createShopZone(key, shop)
    if not shop.pos or not resourceStarted('ox_lib') then return end

    local coords = vector3(shop.pos.x, shop.pos.y, shop.pos.z)
    local radius = getShopRadius(shop)
    local height = getShopHeight()

    shopZones[key] = lib.zones.box({
        coords = coords,
        size = vec3(radius * 2.0, radius * 2.0, height),
        rotation = 0,
        debug = false,
        onEnter = function()
            currentShopKey = key
            updateShopPrompt()
        end,
        onExit = function()
            if currentShopKey == key then
                currentShopKey = nil
                hideShopPrompt()
                setShopKeybindEnabled(false)
            end
        end,
    })
end

local function refreshShopPromptIfNeeded()
    if not currentShopKey or isBoostPriority() then return end
    updateShopPrompt()
end

local function applyShopLocations(payload)
    if type(payload) ~= 'table' then return end

    hideShopPrompt()
    setShopKeybindEnabled(false)
    currentShopKey = nil

    activeShops = payload
    clearShopZones()
    clearShopBlips()

    for key, shop in pairs(activeShops) do
        createShopBlip(key, shop)
        createShopZone(key, shop)
    end

    SetTimeout(500, refreshCurrentShopZone)
end

local function loadShopLocations()
    ESX.TriggerServerCallback('ya_workshop:getShopLocations', function(payload)
        applyShopLocations(payload)
    end)
end

function IsNearShop()
    local coords = GetEntityCoords(PlayerPedId())
    for key, shop in pairs(activeShops) do
        if isInsideShop(shop, coords) then
            return true, key
        end
    end
    return false, nil
end

exports('IsNearShop', IsNearShop)

local function refreshEmployeeState()
    ESX.TriggerServerCallback('ya_workshop:isEmployee', function(result)
        isEmployee = result == true
        if currentShopKey then
            updateShopPrompt()
        end
    end)
end

CreateThread(function()
    while GetResourceState('ox_lib') ~= 'started' do
        Wait(200)
    end

    shopKeybind = lib.addKeybind({
        name = 'ya_workshop_shop_order',
        description = 'Bestil tuning ved værksted',
        defaultKey = 'E',
        disabled = true,
        onPressed = function()
            if currentShopKey then
                tryOpenShop(currentShopKey)
            end
        end,
    })
end)

CreateThread(function()
    while not ESX.IsPlayerLoaded() do Wait(500) end
    refreshEmployeeState()
    loadShopLocations()
end)

RegisterNetEvent('esx:playerLoaded', function()
    refreshEmployeeState()
    loadShopLocations()
end)

RegisterNetEvent('esx:setJob', function()
    refreshEmployeeState()
end)

RegisterNetEvent('ya_workshop:syncShopLocations', function(payload)
    applyShopLocations(payload)
end)

RegisterNetEvent('ya_workshop:tunerClosed', function()
    openingShop = false
    if currentShopKey and not isBoostPriority() then
        updateShopPrompt()
    else
        hideShopPrompt()
        setShopKeybindEnabled(false)
    end
end)

CreateThread(function()
    local lastInVehicle = nil
    while true do
        Wait(350)
        if currentShopKey then
            local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
            if isBoostPriority() then
                hideShopPrompt()
                setShopKeybindEnabled(false)
                lastInVehicle = nil
            elseif inVehicle ~= lastInVehicle then
                lastInVehicle = inVehicle
                updateShopPrompt()
            elseif not shopPromptActive then
                refreshShopPromptIfNeeded()
            end
        else
            lastInVehicle = nil
        end
    end
end)

function OpenWorkTablet()
    if not resourceStarted('ya_tablet') then
        ESX.ShowNotification('ya_tablet kører ikke.')
        return
    end
    TriggerEvent('ya_workshop:openWorkTablet')
end

exports('OpenWorkTablet', OpenWorkTablet)

exports('IsWorkshopEmployee', function()
    return isEmployee
end)

RegisterNetEvent('ya_workshop:setWaypoint', function(x, y)
    x, y = tonumber(x), tonumber(y)
    if x and y then
        SetNewWaypoint(x, y)
        ESX.ShowNotification('GPS sat til opkald.')
    end
end)

RegisterNetEvent('ya_workshop:orderPlaced', function()
    -- tuner.lua lukker menu
end)

RegisterCommand('shopfix', function()
    openingShop = false
    hideShopPrompt()
    setShopKeybindEnabled(false)
    refreshCurrentShopZone()
    ESX.ShowNotification('Værksteds-zone nulstillet.')
end, false)
