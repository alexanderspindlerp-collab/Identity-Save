local function trimPlate(plate)
    return (plate or ''):gsub('^%s*(.-)%s*$', '%1')
end

--- GTA native feed (venstre side, badge-ikon)
local function showGtaNativeAlarm(plate, reason, detail, opts)
    opts = type(opts) == 'table' and opts or {}
    local texture = opts.foererret and 'CHAR_DEFAULT' or 'CHAR_CALL911'
    if not HasStreamedTextureDictLoaded(texture) then
        RequestStreamedTextureDict(texture, false)
        local timeout = GetGameTimer() + 2000
        while not HasStreamedTextureDictLoaded(texture) and GetGameTimer() < timeout do
            Wait(0)
        end
    end

    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)

    local displayPlate = trimPlate(plate)
    local body = ('Nummerplade: %s~n~%s'):format(displayPlate, reason or 'ANPG')
    if detail and detail ~= '' then
        body = body .. ('~n~%s'):format(detail)
    end

    AddTextEntry('speedmeterAnpgMsg', body)
    BeginTextCommandThefeedPost('speedmeterAnpgMsg')
    ThefeedSetNextPostBackgroundColor(opts.foererret and 12 or 6)
    local title = opts.foererret and 'Politiet — Førerret' or 'Politiet — Efterlysning'
    EndTextCommandThefeedPostMessagetext(texture, texture, true, 1, 'ANPG', title)
    EndTextCommandThefeedPostTicker(true, true)
end

RegisterNetEvent('speedmeter:anpgHit', function(plate, reason, detail, displayPlate, foererret)
    showGtaNativeAlarm(displayPlate or plate, reason, detail, { foererret = foererret == true })
end)

local radarVisible = false
local radarLocked = false
local lockedData = nil
local lastAnpg = {}
local lastRadarPlateKey = ''
local playerJob = nil

local function compactPlateKey(plate)
    return trimPlate(plate):upper():gsub('%s+', '')
end

local function getFrameworkJob()
    if Config.Framework == 'standalone' then return true end
    if ESX and ESX.GetPlayerData then
        local data = ESX.GetPlayerData()
        if data and data.job then return data.job.name end
    end
    return playerJob
end

RegisterNetEvent('esx:setJob', function(job) playerJob = job and job.name end)

local function isPolice()
    if Config.Framework == 'standalone' then return true end
    local job = getFrameworkJob()
    return job and Config.AllowedJobs[job] == true
end

local function getVehicleClassConfig(vehicle)
    local name = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
    for classId, data in pairs(Config.VehicleClasses) do
        if data.vehicles and data.vehicles[name] then
            return classId, data
        end
    end
    return nil, nil
end

local function getRadarClassConfig(vehicle)
    local classId = Config.DefaultClass or 1
    if vehicle and vehicle ~= 0 then
        local detectedId = getVehicleClassConfig(vehicle)
        if detectedId then classId = detectedId end
    end
    return Config.VehicleClasses[classId] or Config.VehicleClasses[Config.DefaultClass] or { range = 50.0 }
end

local function isPoliceVehicle(vehicle)
    if getVehicleClassConfig(vehicle) then return true end
    return isPolice() and GetVehicleClass(vehicle) == 18
end

local function setRadarVisible(state)
    radarVisible = state
    SendNUIMessage({ action = state and 'show' or 'hide' })
end

local function angleBetween(a, b)
    local dot = a.x * b.x + a.y * b.y
    local magA = math.sqrt(a.x * a.x + a.y * a.y)
    local magB = math.sqrt(b.x * b.x + b.y * b.y)
    if magA == 0 or magB == 0 then return 999.0 end
    local cos = dot / (magA * magB)
    if cos > 1.0 then cos = 1.0 elseif cos < -1.0 then cos = -1.0 end
    return math.deg(math.acos(cos))
end

local function getFrontVehicle(policeVehicle, range, maxAngle)
    if not policeVehicle or policeVehicle == 0 or not DoesEntityExist(policeVehicle) then
        return nil
    end

    range = range or 50.0
    maxAngle = maxAngle or Config.MaxScanAngle or 45.0
    local minDist = Config.MinScanDistance or 0.8

    local start = GetOffsetFromEntityInWorldCoords(policeVehicle, 0.0, 1.2, 0.6)
    local dest = GetOffsetFromEntityInWorldCoords(policeVehicle, 0.0, range, 0.6)
    local handle = StartShapeTestRay(start.x, start.y, start.z, dest.x, dest.y, dest.z, 10, policeVehicle, 0)
    local retval, hit, _, _, entityHit = GetShapeTestResult(handle)
    local attempts = 0
    while retval == 1 and attempts < 5 do
        Wait(0)
        retval, hit, _, _, entityHit = GetShapeTestResult(handle)
        attempts = attempts + 1
    end

    if hit == 1 and entityHit and entityHit ~= 0 and DoesEntityExist(entityHit)
        and IsEntityAVehicle(entityHit) and entityHit ~= policeVehicle then
        local dist = #(GetEntityCoords(entityHit) - GetEntityCoords(policeVehicle))
        if dist >= minDist and dist <= range then
            return entityHit
        end
    end

    local pCoords = GetEntityCoords(policeVehicle)
    local forward = GetEntityForwardVector(policeVehicle)
    local flatForward = vector3(forward.x, forward.y, 0.0)
    local bestVehicle, bestDist = nil, range + 0.01

    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh ~= policeVehicle and DoesEntityExist(veh) then
            local diff = GetEntityCoords(veh) - pCoords
            local flatDiff = vector3(diff.x, diff.y, 0.0)
            local dist = #(diff)
            if dist >= minDist and dist <= range then
                local dot = flatForward.x * flatDiff.x + flatForward.y * flatDiff.y
                if dot > 0.0 and angleBetween(flatForward, flatDiff) <= maxAngle and dist < bestDist then
                    local losOk = (Config.RelaxedLineOfSight ~= false and dist <= 12.0)
                        or HasEntityClearLosToEntity(policeVehicle, veh, 17)
                    if losOk then
                        bestVehicle = veh
                        bestDist = dist
                    end
                end
            end
        end
    end

    return bestVehicle
end

local function isValidScanPlate(plate)
    plate = trimPlate(plate)
    return plate ~= '' and plate ~= '--------' and plate:gsub('%s', '') ~= ''
end

local function speedOf(vehicle)
    local mult = Config.UseKmh and 3.6 or 2.236936
    return math.floor(GetEntitySpeed(vehicle) * mult + 0.5)
end

local function runAnpg(vehicle, plate)
    local key = compactPlateKey(plate)
    if key == '' then return end

    local now = GetGameTimer()
    local plateChanged = key ~= lastRadarPlateKey
    lastRadarPlateKey = key

    if not plateChanged and lastAnpg[key] and (now - lastAnpg[key]) < Config.AnpgInterval then
        return
    end
    lastAnpg[key] = now

    local driverServerId = nil
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        local driver = GetPedInVehicleSeat(vehicle, -1)
        if driver and driver ~= 0 and IsPedAPlayer(driver) then
            local idx = NetworkGetPlayerIndexFromPed(driver)
            if idx and idx ~= -1 then driverServerId = GetPlayerServerId(idx) end
        end
    end

    CreateThread(function()
        pcall(function()
            local vehicleClass = 0
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                vehicleClass = GetVehicleClass(vehicle)
            end
            lib.callback.await('speedmeter:checkAnpg', false, trimPlate(plate), driverServerId, vehicleClass)
        end)
    end)
end

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and isPolice() and isPoliceVehicle(vehicle) then
            if not radarVisible then
                setRadarVisible(true)
            end
        elseif radarVisible then
            setRadarVisible(false)
            radarLocked = false
            lockedData = nil
        end
    end
end)

CreateThread(function()
    while true do
        Wait(radarVisible and Config.ScanInterval or 500)
        if not radarVisible then goto continue end

        local ped = PlayerPedId()
        local policeVehicle = GetVehiclePedIsIn(ped, false)
        local classConfig = getRadarClassConfig(policeVehicle)
        local data = {
            plate = '--------',
            targetSpeed = 0,
            patrolSpeed = policeVehicle ~= 0 and speedOf(policeVehicle) or 0,
            locked = radarLocked,
            recording = false
        }

        if radarLocked and lockedData then
            data.plate = lockedData.plate
            data.targetSpeed = lockedData.targetSpeed
            if isValidScanPlate(lockedData.plate) then
                runAnpg(nil, lockedData.plate)
            end
        else
            local target = getFrontVehicle(policeVehicle, classConfig.range or 50.0, Config.MaxScanAngle)
            if target then
                local plate = trimPlate(GetVehicleNumberPlateText(target))
                data.plate = plate ~= '' and plate or '--------'
                data.targetSpeed = speedOf(target)
                if isValidScanPlate(plate) then
                    runAnpg(target, plate)
                end
            else
                lastRadarPlateKey = ''
            end
        end

        SendNUIMessage({ action = 'update', data = data })
        ::continue::
    end
end)

RegisterCommand(Config.OpenCommand, function()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    if vehicle ~= 0 and isPolice() and isPoliceVehicle(vehicle) then
        setRadarVisible(not radarVisible)
    end
end)

RegisterCommand('anpgnotifytest', function()
    showGtaNativeAlarm('YVW 422', 'Efterlyst nummerplade', 'Test — native GTA notify')
end, false)

RegisterCommand('radar_lock', function()
    if not radarVisible then return end
    radarLocked = not radarLocked
    if radarLocked then
        local policeVehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        local classConfig = getRadarClassConfig(policeVehicle)
        local target = getFrontVehicle(policeVehicle, classConfig.range or 50.0, Config.MaxScanAngle)
        if target then
            lockedData = {
                plate = trimPlate(GetVehicleNumberPlateText(target)),
                targetSpeed = speedOf(target)
            }
        else
            radarLocked = false
        end
    else
        lockedData = nil
    end
end)
RegisterKeyMapping('radar_lock', 'Speedradar: Lås/nulstil fart', 'keyboard', Config.LockKey)

RegisterCommand('radar_reset', function()
    radarLocked = false
    lockedData = nil
end)
RegisterKeyMapping('radar_reset', 'Speedradar: Fjern lås', 'keyboard', Config.ResetKey)

RegisterKeyMapping(Config.OpenCommand, 'Speedradar: Åbn/luk', 'keyboard', Config.ToggleKey)
