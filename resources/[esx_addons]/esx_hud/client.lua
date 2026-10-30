local ESX = exports['es_extended']:getSharedObject()

local config = Config or {}
local speedMultiplier = config.UseMPH and 2.23694 or 3.6

local hunger = 100
local thirst = 100
local stress = 0
local oxygen = 100
local cashAmount = 0
local bankAmount = 0
local radioActive = false
local seatbeltOn = false
local showMenu = false
local hudLoaded = false
local playerLoaded = false
local hudStyle = Config.DefaultHudStyle or 1
local editMode = false
local minimapUserOffset = { x = 0.0, y = 0.0 }
local applyMinimapPosition

local speedLimiterHudEnabled = false

RegisterNetEvent('esx_hud:setSpeedLimiter', function(enabled)
    speedLimiterHudEnabled = enabled == true

    SendNUIMessage({
        action = 'speedLimiter',
        enabled = speedLimiterHudEnabled
    })
end)


DisplayRadar(false)

local function Notify(msg, typ)
    typ = typ or 'info'
    if ESX and ESX.ShowNotification then
        -- notification removed
    else
        print(('[esx_hud] %s'):format(msg))
    end
end

local function clamp(value, min, max)
    value = tonumber(value) or 0
    if value < min then return min end
    if value > max then return max end
    return value
end

local function getVoiceLevel()
    -- pma-voice default ranges are often 1-3; this UI expects roughly 1-5.
    local mode = LocalPlayer.state and LocalPlayer.state.proximity and LocalPlayer.state.proximity.index
    if mode then return clamp(mode, 1, 5) end
    return 2
end

local function getAccounts()
    local pdata = ESX.GetPlayerData()
    cashAmount = 0
    bankAmount = 0

    if pdata and pdata.accounts then
        for _, account in pairs(pdata.accounts) do
            if account.name == 'money' or account.name == 'cash' then
                cashAmount = account.money or 0
            elseif account.name == 'bank' then
                bankAmount = account.money or 0
            end
        end
    end
end


local function getCardinalDirection(heading)
    local dirs = { 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW' }
    local index = math.floor(((heading or 0) + 22.5) / 45.0) + 1
    return dirs[((index - 1) % 8) + 1]
end

local function getStreetInfo(entity)
    local coords = GetEntityCoords(entity)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    return getCardinalDirection(GetEntityHeading(entity)), streetName or ''
end

local function getFuel(vehicle)
    if vehicle == 0 then return 0 end
    local fuel = GetVehicleFuelLevel(vehicle)
    if exports['LegacyFuel'] then
        local ok, val = pcall(function()
            return exports['LegacyFuel']:GetFuel(vehicle)
        end)
        if ok and val then fuel = val end
    end
    return clamp(fuel, 0, 100)
end

local function loadSettings()
    local hudSettings = GetResourceKvpString('hudSettings')
    if hudSettings then
        local decoded = json.decode(hudSettings)
        if decoded then
            for k, v in pairs(decoded) do
                if Config.Menu and Config.Menu[k] ~= nil then
                    Config.Menu[k] = v
                end
                SendNUIMessage({ test = true, event = k, toggle = v })
            end
        end
    end

    local savedHudStyle = GetResourceKvpString('hudStyle')
    if savedHudStyle then
        local style = tonumber(savedHudStyle)
        if style == 1 or style == 2 then
            hudStyle = style
        end
    end

    SendNUIMessage({ action = 'setHudStyle', style = hudStyle })

    local savedMinimap = GetResourceKvpString('minimapOffset')
    if savedMinimap then
        local decoded = json.decode(savedMinimap)
        if decoded then
            minimapUserOffset.x = tonumber(decoded.x) or 0.0
            minimapUserOffset.y = tonumber(decoded.y) or 0.0
        end
    end

    local savedPositions = GetResourceKvpString('hudPositions')
    local decodedPositions = savedPositions and json.decode(savedPositions) or nil
    SendNUIMessage({
        action = 'loadPositions',
        positions = decodedPositions,
        minimap = minimapUserOffset
    })

    Wait(500)
    TriggerEvent('hud:client:LoadMap')
end


local function sendSafezone()
    -- Låst normal HUD/safezone-størrelse, så spillernes egne safezone-indstillinger ikke forstørrer HUD'en.
    SendNUIMessage({ action = 'safezone', size = 1.0 })
end

local function saveSettings()
    if Config.Menu then
        SetResourceKvp('hudSettings', json.encode(Config.Menu))
    end
end

local function cinematicShow(bool)
    if bool then
        DisplayRadar(false)
    else
        DisplayRadar(true)
    end
end

local function refreshHud()
    SendNUIMessage({ action = 'hudtick', show = false })
    Wait(50)
    SendNUIMessage({ action = 'hudtick', show = true })
    TriggerEvent('hud:client:LoadMap')
end

local function resetHud()
    Notify('HUD genstartet', 'success')
    SendNUIMessage({ action = 'car', show = false })
    SendNUIMessage({ action = 'hudtick', show = false })
    Wait(500)
    refreshHud()
end

-- ESX lifecycle
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    playerLoaded = true
    Wait(1500)
    getAccounts()
    loadSettings()
    refreshHud()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    playerLoaded = false
    SendNUIMessage({ action = 'hudtick', show = false })
    SendNUIMessage({ action = 'car', show = false })
end)

RegisterNetEvent('esx:setAccountMoney', function(account)
    if not account then return end
    if account.name == 'money' or account.name == 'cash' then
        cashAmount = account.money or 0
    elseif account.name == 'bank' then
        bankAmount = account.money or 0
    end

    SendNUIMessage({
        action = 'updatemoney',
        cash = cashAmount,
        bank = bankAmount,
        amount = account.money or 0,
        minus = false,
        type = account.name
    })
end)

-- ESX status support
AddEventHandler('esx_status:onTick', function(status)
    for _, v in pairs(status) do
        if v.name == 'hunger' then
            hunger = clamp((v.percent or 0), 0, 100)
        elseif v.name == 'thirst' then
            thirst = clamp((v.percent or 0), 0, 100)
        elseif v.name == 'stress' then
            stress = clamp((v.percent or 0), 0, 100)
        end
    end
end)

RegisterNetEvent('esx_status:update', function(status)
    if type(status) ~= 'table' then return end
    for _, v in pairs(status) do
        if v.name == 'hunger' then
            hunger = clamp((v.percent or 0), 0, 100)
        elseif v.name == 'thirst' then
            thirst = clamp((v.percent or 0), 0, 100)
        elseif v.name == 'stress' then
            stress = clamp((v.percent or 0), 0, 100)
        end
    end
end)

RegisterNetEvent('hud:client:UpdateNeeds', function(newHunger, newThirst)
    hunger = clamp(newHunger, 0, 100)
    thirst = clamp(newThirst, 0, 100)
end)

RegisterNetEvent('hud:client:UpdateStress', function(newStress)
    stress = clamp(newStress, 0, 100)
end)

RegisterNetEvent('pma-voice:radioActive', function(data)
    radioActive = data
end)


RegisterNetEvent('hud:client:ShowAccounts', function(type, amount)
    SendNUIMessage({
        action = 'show',
        type = type,
        amount = amount
    })
end)

-- menu
local function toggleHudMenu()
    if editMode then return end

    if showMenu then
        showMenu = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
    showMenu = true
end

-- HOME-tasten åbner HUD menu (hard-bind VK 36, fallback til RegisterKeyMapping)
local KEY_HOME = 36
local homeKeyBound = pcall(function()
    RegisterRawKeymap('esx_hud_open_menu', function() end, function()
        if editMode then return end
        toggleHudMenu()
    end, KEY_HOME, false)
end)

if not homeKeyBound then
    RegisterCommand('+esx_hud_home', toggleHudMenu, false)
    RegisterCommand('-esx_hud_home', function() end, false)
    RegisterKeyMapping('+esx_hud_home', 'Åbn HUD Menu (HOME)', 'keyboard', 'HOME')
end

RegisterCommand('resethud', function()
    resetHud()
end)

RegisterNUICallback('closeMenu', function(_, cb)
    showMenu = false
    SetNuiFocus(false, false)
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(0)
        if showMenu and not editMode and IsControlJustReleased(0, 322) then -- ESC
            toggleHudMenu()
        end
    end
end)

RegisterNUICallback('restartHud', function(_, cb)
    resetHud()
    cb('ok')
end)

RegisterNUICallback('setHudStyle', function(data, cb)
    local style = tonumber(data and data.style) or 1
    if style ~= 1 and style ~= 2 then style = 1 end

    hudStyle = style
    SetResourceKvp('hudStyle', tostring(style))
    SendNUIMessage({ action = 'setHudStyle', style = style })
    cb('ok')
end)

RegisterNUICallback('setEditMode', function(data, cb)
    editMode = data and data.enabled == true

    if editMode then
        showMenu = false
        DisplayRadar(true)
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end

    SendNUIMessage({ action = 'setEditMode', enabled = editMode })
    cb('ok')
end)

RegisterNUICallback('startEditMode', function(_, cb)
    showMenu = false
    editMode = true
    DisplayRadar(true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ action = 'close' })
    SendNUIMessage({ action = 'setEditMode', enabled = true })
    cb('ok')
end)

RegisterNUICallback('saveHudPositions', function(data, cb)
    if data and data.positions then
        SetResourceKvp('hudPositions', json.encode(data.positions))
    end

    if data and data.minimap then
        minimapUserOffset.x = tonumber(data.minimap.x) or 0.0
        minimapUserOffset.y = tonumber(data.minimap.y) or 0.0
        SetResourceKvp('minimapOffset', json.encode(minimapUserOffset))
    end

    TriggerEvent('hud:client:LoadMap')
    cb('ok')
end)

RegisterNUICallback('previewMinimapOffset', function(data, cb)
    if data and data.minimap then
        minimapUserOffset.x = tonumber(data.minimap.x) or 0.0
        minimapUserOffset.y = tonumber(data.minimap.y) or 0.0
        applyMinimapPosition()
    end
    cb('ok')
end)

RegisterNUICallback('resetStorage', function(_, cb)
    DeleteResourceKvp('hudSettings')
    DeleteResourceKvp('hudStyle')
    DeleteResourceKvp('hudPositions')
    DeleteResourceKvp('minimapOffset')

    hudStyle = Config.DefaultHudStyle or 1
    minimapUserOffset = { x = 0.0, y = 0.0 }

    SendNUIMessage({ action = 'setHudStyle', style = hudStyle })
    SendNUIMessage({ action = 'loadPositions', positions = nil, minimap = minimapUserOffset })
    loadSettings()
    cb('ok')
end)

local function toggleMenuOption(option)
    if not Config.Menu then return end
    Config.Menu[option] = not Config.Menu[option]
    saveSettings()
    SendNUIMessage({ test = true, event = option, toggle = Config.Menu[option] })
end

local nuiToggleMap = {
    showOutMap = 'isOutMapChecked',
    showOutCompass = 'isOutCompassChecked',
    showFollowCompass = 'isCompassFollowChecked',
    openMenuSounds = 'isOpenMenuSoundsChecked',
    resetHudSounds = 'isResetSoundsChecked',
    checklistSounds = 'isListSoundsChecked',
    showMapNotif = 'isMapNotifChecked',
    showFuelAlert = 'isLowFuelChecked',
    showCinematicNotif = 'isCinematicNotifChecked',
    dynamicHealth = 'isDynamicHealthChecked',
    dynamicArmor = 'isDynamicArmorChecked',
    dynamicHunger = 'isDynamicHungerChecked',
    dynamicThirst = 'isDynamicThirstChecked',
    dynamicStress = 'isDynamicStressChecked',
    dynamicOxygen = 'isDynamicOxygenChecked',
    dynamicEngine = 'isDynamicEngineChecked',
    dynamicNitro = 'isDynamicNitroChecked',
    ToggleMapShape = 'isToggleMapShapeChecked',
    changeFPS = 'isChangeFPSChecked',
    ToggleMapBorders = 'isToggleMapBordersChecked',
    HideMap = 'isHideMapChecked',
    changeCompassFPS = 'isChangeCompassFPSChecked',
    showCompassBase = 'isShowCompassChecked',
    showStreetsNames = 'isShowStreetsChecked',
    showPointerIndex = 'isPointerShowChecked',
    showDegreesNum = 'isDegreesShowChecked',
    cinematicMode = 'isCinematicModeChecked'
}

for cbName, option in pairs(nuiToggleMap) do
    RegisterNUICallback(cbName, function(_, cb)
        toggleMenuOption(option)
        if cbName == 'cinematicMode' and Config.Menu then
            cinematicShow(Config.Menu[option])
        end
        cb('ok')
    end)
end

-- Normal minimap lås
-- Disse værdier er låst til normal GTA/FiveM størrelse og bliver genindlæst løbende,
-- så spillere eller andre scripts ikke kan efterlade minimappet i stor/ændret størrelse.
local NORMAL_MINIMAP = {
    minimap = { x = 0.0, y = -0.047, w = 0.1638, h = 0.183 },
    mask    = { x = 0.0, y =  0.0,   w = 0.128,  h = 0.20  },
    blur    = { x = -0.01,y =  0.025, w = 0.262,  h = 0.300 },
}

applyMinimapPosition = function()
    local defaultAspectRatio = 1920 / 1080
    local resolutionX, resolutionY = GetActiveScreenResolution()
    local aspectRatio = resolutionX / resolutionY
    local aspectOffset = 0.0

    if aspectRatio > defaultAspectRatio then
        aspectOffset = ((defaultAspectRatio - aspectRatio) / 3.6) - 0.008
    end

    RequestStreamedTextureDict('squaremap', false)
    local timeout = GetGameTimer() + 1000
    while not HasStreamedTextureDictLoaded('squaremap') and GetGameTimer() < timeout do
        Wait(10)
    end

    SetMinimapClipType(0)
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')

    local userX = minimapUserOffset.x or 0.0
    local userY = minimapUserOffset.y or 0.0

    SetMinimapComponentPosition(
        'minimap', 'L', 'B',
        NORMAL_MINIMAP.minimap.x + aspectOffset + userX,
        NORMAL_MINIMAP.minimap.y + userY,
        NORMAL_MINIMAP.minimap.w,
        NORMAL_MINIMAP.minimap.h
    )
    SetMinimapComponentPosition(
        'minimap_mask', 'L', 'B',
        NORMAL_MINIMAP.mask.x + aspectOffset + userX,
        NORMAL_MINIMAP.mask.y + userY,
        NORMAL_MINIMAP.mask.w,
        NORMAL_MINIMAP.mask.h
    )
    SetMinimapComponentPosition(
        'minimap_blur', 'L', 'B',
        NORMAL_MINIMAP.blur.x + aspectOffset + userX,
        NORMAL_MINIMAP.blur.y + userY,
        NORMAL_MINIMAP.blur.w,
        NORMAL_MINIMAP.blur.h
    )

    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(false, false)
end

local function forceNormalMinimap()
    applyMinimapPosition()
end

RegisterNetEvent('hud:client:LoadMap', function()
    Wait(50)
    forceNormalMinimap()
    SetRadarBigmapEnabled(true, false)
    Wait(50)
    forceNormalMinimap()
end)

CreateThread(function()
    while true do
        Wait(2000)
        forceNormalMinimap()
        sendSafezone()
    end
end)

CreateThread(function()
    Wait(1000)
    playerLoaded = true
    getAccounts()
    loadSettings()
    TriggerEvent('hud:client:LoadMap')
    sendSafezone()
end)

CreateThread(function()
    while true do
        sendSafezone()
        Wait(1500)
    end
end)

-- Main player HUD loop
CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local pause = IsPauseMenuActive()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if config.HideDefaultGtaHud then
            HideHudComponentThisFrame(1)
            HideHudComponentThisFrame(2)
            HideHudComponentThisFrame(3)
            HideHudComponentThisFrame(4)
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
        end

        if config.ShowMinimapOnlyInVehicle then
            DisplayRadar(inVehicle and not pause)
        else
            DisplayRadar(not pause)
        end

        local health = GetEntityHealth(ped) - 100
        local armor = GetPedArmour(ped)
        local stamina = 100 - GetPlayerSprintStaminaRemaining(PlayerId())
        local underwater = GetPlayerUnderwaterTimeRemaining(PlayerId())
        oxygen = clamp(underwater * 10, 0, 100)

        local weapon = GetSelectedPedWeapon(ped)
        local armed = weapon and weapon ~= `WEAPON_UNARMED`

        SendNUIMessage({
            action = 'hudtick',
            show = not pause,
            dynamicHealth = false,
            dynamicArmor = false,
            dynamicHunger = false,
            dynamicThirst = false,
            dynamicStress = false,
            dynamicOxygen = false,
            dynamicEngine = false,
            dynamicNitro = false,
            health = clamp(health, 0, 100),
            playerDead = IsEntityDead(ped),
            armor = clamp(armor, 0, 100),
            thirst = thirst,
            hunger = hunger,
            stress = stress,
            voice = getVoiceLevel(),
            radio = radioActive,
            radioActive = radioActive,
            talking = NetworkIsPlayerTalking(PlayerId()),
            armed = armed,
            oxygen = oxygen,
            parachute = GetPedParachuteState(ped),
            nos = 0,
            cruise = false,
            nitroActive = 0,
            harness = false,
            hp = health,
            speed = 0,
            engine = 0,
            cinematic = false,
            dev = false
        })

        getAccounts()
        SendNUIMessage({
            action = 'showconstant',
            cash = cashAmount,
            bank = bankAmount
        })
    end
end)

-- Vehicle HUD loop
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local inVeh = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped
        local pause = IsPauseMenuActive()

        if inVeh and not pause then
            local speed = math.ceil(GetEntitySpeed(veh) * speedMultiplier)
            local fuel = getFuel(veh)
            local engine = clamp(GetVehicleEngineHealth(veh) / 10, 0, 100)
            local altitude = math.ceil(GetEntityCoords(veh).z)
            local rpm = GetVehicleCurrentRpm(veh) or 0.0
            local direction, street = getStreetInfo(veh)

            SendNUIMessage({
                action = 'car',
                show = true,
                isPaused = 0,
                speed = speed,
                fuel = fuel,
                engine = engine,
                altitude = altitude,
                showAltitude = IsThisModelAHeli(GetEntityModel(veh)) or IsThisModelAPlane(GetEntityModel(veh)),
                showSeatbelt = false,
                seatbelt = seatbeltOn,
                showSquareB = true,
                showCircleB = false,
                rpm = rpm,
                gear = GetVehicleCurrentGear(veh),
                unit = config.UseMPH and 'MPH' or 'KMH',
                direction = direction,
                street = street
            })

            Wait(100)
        else
            SendNUIMessage({
                action = 'car',
                show = false,
                isPaused = pause and 1 or 0
            })
            Wait(500)
        end
    end
end)

-- Keep GTA HUD components hidden every frame
CreateThread(function()
    while true do
        Wait(0)
        if config.HideDefaultGtaHud then
            HideHudComponentThisFrame(1)
            HideHudComponentThisFrame(2)
            HideHudComponentThisFrame(3)
            HideHudComponentThisFrame(4)
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(8)
            HideHudComponentThisFrame(9)
            HideHudComponentThisFrame(13)
            HideHudComponentThisFrame(17)
            HideHudComponentThisFrame(20)
        end
    end
end)




-- FINAL low fuel warning for ox_fuel + native fuel
local lowFuelLimit = 25.0
local lastLowFuelState = nil
local lastFuelValue = -1.0

local function GetHudFuelLevel(vehicle)
    if not vehicle or vehicle == 0 then return 100.0 end

    local stateFuel = Entity(vehicle).state.fuel
    if stateFuel ~= nil then
        local numberFuel = tonumber(stateFuel)
        if numberFuel ~= nil then
            return numberFuel
        end
    end

    local nativeFuel = GetVehicleFuelLevel(vehicle)
    if nativeFuel ~= nil then
        return nativeFuel
    end

    return 100.0
end

local function SetHudFuelLevel(vehicle, amount)
    amount = tonumber(amount) or 0.0
    if not vehicle or vehicle == 0 then return end

    Entity(vehicle).state:set('fuel', amount, true)
    SetVehicleFuelLevel(vehicle, amount)

    -- ox_fuel compatibility, if export exists on your server
    if GetResourceState('ox_fuel') == 'started' then
        pcall(function()
            exports.ox_fuel:setFuel(vehicle, amount)
        end)
    end
end

local function SendLowFuelState(force)
    local ped = PlayerPedId()
    local enabled = false
    local fuel = 100.0

    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        fuel = GetHudFuelLevel(vehicle)
        enabled = fuel <= lowFuelLimit
    end

    if force or enabled ~= lastLowFuelState or math.abs(fuel - lastFuelValue) >= 1.0 then
        lastLowFuelState = enabled
        lastFuelValue = fuel

        SendNUIMessage({
            action = 'lowFuelWarning',
            enabled = enabled,
            fuel = fuel
        })
    end
end

CreateThread(function()
    while true do
        Wait(500)
        SendLowFuelState(false)
    end
end)

RegisterCommand('testfuel', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        print('[HUD] Du sidder ikke i et køretøj')
        return
    end

    SetHudFuelLevel(vehicle, 5.0)
    SendLowFuelState(true)
    print('[HUD] Fuel sat til 5%')
end, false)

RegisterCommand('fillfuel', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        print('[HUD] Du sidder ikke i et køretøj')
        return
    end

    SetHudFuelLevel(vehicle, 100.0)
    SendLowFuelState(true)
    print('[HUD] Fuel sat til 100%')
end, false)

