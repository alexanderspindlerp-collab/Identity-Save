local ESX = exports['es_extended']:getSharedObject()

-- SAN MDT V29: safe ESX callback wrapper
-- Prevents one bad NUI/client callback from killing ESX callback execution.
local _sanOrigTriggerServerCallback = ESX.TriggerServerCallback
ESX.TriggerServerCallback = function(name, cb, ...)
    if type(cb) == 'function' then
        local safeCb = function(...)
            local ok, err = pcall(cb, ...)
            if not ok then
                print(('^1[san_mdt][CLIENT CALLBACK ERROR]^7 %s: %s'):format(tostring(name), tostring(err)))
            end
        end
        return _sanOrigTriggerServerCallback(name, safeCb, ...)
    end
    return _sanOrigTriggerServerCallback(name, cb, ...)
end

local function sanSafeNuiCb(cb, payload)
    if type(cb) ~= 'function' then return end
    local ok, err = pcall(cb, payload or { ok = true })
    if not ok then
        print(('^1[san_mdt][NUI CB ERROR]^7 %s'):format(tostring(err)))
    end
end


local open = false
local lookMode = false
local lookModeStarted = 0
local PlayerData = {}

local function sendLookMode(active)
    SendNUIMessage({ action = 'lookMode', active = active })
end

local function setMdtFocus(hasFocus)
    SetNuiFocus(hasFocus, hasFocus)
    -- Normal MDT-mode låser spil-input. Look-through-mode sætter KeepInput(true).
    SetNuiFocusKeepInput(false)
end

function setLookMode(active)
    active = active == true
    if not open then
        lookMode = false
        lookModeStarted = 0
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        sendLookMode(false)
        return
    end

    lookMode = active
    lookModeStarted = active and GetGameTimer() or 0
    sendLookMode(active)

    if active then
        -- Look-through: hold NUI/cursor aktiv så MDT kan fange mouse-enter igen,
        -- men lad spil-input passere via KeepInput.
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        -- Normal MDT: cursor/focus tilbage til tablet og spil-input låses af control-loopet.
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
    end
end

local function getPlayerData()
    PlayerData = ESX.GetPlayerData() or PlayerData or {}
    return PlayerData
end

local function canOpenMdt()
    -- Serveren er autoritativ. Klienten må åbne UI, så ESX PlayerData-race ikke blokerer MDT før job er hentet.
    return true
end

function closeMdt()
    if not open then return end
    open = false
    lookMode = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'forceClose' })
    ESX.TriggerServerCallback('san_mdt:writeAuditLog', function() end, { category='System', action='MDT_CLOSED', message='Lukkede MDT' })
end

function openMdt()
    if open then return end
    if not canOpenMdt() then
        ESX.ShowNotification('Du har ikke adgang til MDT.')
        return
    end

    local data = getPlayerData()
    open = true
    lookMode = false
    setMdtFocus(true)

    SendNUIMessage({
        action = 'open',
        name = data.firstName or data.firstname or data.name or GetPlayerName(PlayerId()),
        playerName = data.name or GetPlayerName(PlayerId()),
        job = data.job or {},
        licenseRevocationCooldownHours = tonumber(Config.LicenseRevocationCooldownHours or 48) or 48,
    })

end

local function mdtPostLoginWarmup()
    ESX.TriggerServerCallback('san_mdt:writeAuditLog', function() end, { category='System', action='MDT_OPENED', message='Åbnede MDT' })
    ESX.TriggerServerCallback('san_mdt:getDashboard', function(resp)
        if open then
            SendNUIMessage({ action = 'dashboard', data = resp or {} })
        end
    end)
end

RegisterCommand('mdt', function()
    if open then closeMdt() else openMdt() end
end, false)

-- F6 åbning er slået fra. MDT skal åbnes via F3-menu/eventet san_mdt:open.


RegisterCommand('san_dispatch_calls', function()
    -- F6 må kun åbne dispatch-opkaldslisten, ikke MDT/policejob-menuen.
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'dispatchListToggle' })
end, false)
RegisterKeyMapping('san_dispatch_calls', 'Åbn dispatch-opkaldsliste', 'keyboard', 'F6')

RegisterCommand('san_dispatch_test', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local witness = { total=3, near=2, clear=2, drivers=1, foot=2, fallback=true }
    sanMdtStartShotWitnessBurst(ped, coords, witness)
    sanMdtSendWeaponSeenDispatch(ped, coords, witness)
    print('[san_mdt:dispatch] test dispatch sent')
end, false)


RegisterNUICallback('setDispatchGps', function(data, cb)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
        sanSafeNuiCb(cb, { ok = true })
    else
        sanSafeNuiCb(cb, { ok = false, message = 'Mangler koordinater.' })
    end
end)

RegisterNUICallback('closeDispatchList', function(_, cb)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    sanSafeNuiCb(cb, { ok = true })
end)

RegisterNetEvent('san_mdt:open', openMdt)
RegisterNetEvent('san_mdt:close', closeMdt)
RegisterNetEvent('san_mdt:toggle', function()
    if open then closeMdt() else openMdt() end
end)
RegisterNetEvent('esx:playerLoaded', function(xPlayer) PlayerData = xPlayer or {} end)
RegisterNetEvent('esx:setJob', function(job)
    PlayerData = PlayerData or {}
    PlayerData.job = job
    if job and (job.name == (Config.PoliceJob or 'police') or (Config.AllowedJobs and Config.AllowedJobs[job.name])) then
        ESX.TriggerServerCallback('san_mdt:writeAuditLog', function() end, { category='Duty', action='DUTY_ON_OR_CHANGED', message='Gik på arbejde/ændrede politijob', metadata={ job=job } })
    else
        ESX.TriggerServerCallback('san_mdt:writeAuditLog', function() end, { category='Duty', action='DUTY_OFF', message='Gik af arbejde', metadata={ job=job } })
    end
    if open then
        ESX.TriggerServerCallback('san_mdt:getPermissionCatalog', function(resp)
            if resp and resp.debug then
                SendNUIMessage({ action = 'permDebug', data = resp.debug })
            end
        end)
        SendNUIMessage({ action = 'jobUpdated', job = job or {} })
        if not canOpenMdt() then closeMdt() end
    elseif not canOpenMdt() then
        -- no-op when MDT closed
    end
end)

CreateThread(function()
    while true do
        if not open then
            Wait(300)
        else
            Wait(0)

            -- ESC skal altid lukke MDT, både i normal mode og look-through mode.
            if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) then
                closeMdt()
            else
                -- Look-through mode: NUI focus er frigivet, så spilleren kan bruge karakteren.
                -- Vi auto-restorer ikke ved mouse-up; den skal blive transparent indtil MDT åbnes/fokuseres igen.
                if lookMode then
                    -- Ingen gameplay controls blokeres her. ESC kan stadig lukke via client-loopet.
                end

                if not lookMode then
                    -- Lås spillet mens MDT bruges, inklusive chat/HUD/radio/menu hotkeys.
                    DisableControlAction(0, 1, true)   -- Look left/right
                    DisableControlAction(0, 2, true)   -- Look up/down
                    DisableControlAction(0, 24, true)  -- Attack
                    DisableControlAction(0, 25, true)  -- Aim/RMB
                    DisableControlAction(0, 30, true)  -- Move left/right
                    DisableControlAction(0, 31, true)  -- Move forward/back
                    DisableControlAction(0, 32, true)
                    DisableControlAction(0, 33, true)
                    DisableControlAction(0, 34, true)
                    DisableControlAction(0, 35, true)
                    DisableControlAction(0, 44, true)
                    DisableControlAction(0, 45, true)
                    DisableControlAction(0, 140, true)
                    DisableControlAction(0, 141, true)
                    DisableControlAction(0, 142, true)
                    DisableControlAction(0, 199, true) -- Pause menu
                    DisableControlAction(0, 200, true) -- ESC/pause alternate
                    DisableControlAction(0, 245, true) -- Chat T
                    DisableControlAction(0, 244, true) -- Interaction/HUD menu M
                    DisableControlAction(0, 288, true) -- F1
                    DisableControlAction(0, 289, true) -- F2
                    DisableControlAction(0, 170, true) -- F3
                    DisableControlAction(0, 166, true) -- F5
                    DisableControlAction(0, 167, true) -- F6
                    DisableControlAction(0, 168, true) -- F7
                    DisableControlAction(0, 169, true) -- F8
                    DisableControlAction(0, 73, true)  -- X
                    DisableControlAction(0, 20, true)  -- Z/player list
                    DisableControlAction(0, 74, true)  -- H
                end
            end
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeMdt()
    cb({ ok = true })
end)

RegisterNUICallback('startNarkoWiretap', function(data, cb)
    local phoneId = data and tostring(data.phoneId or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if phoneId == '' then
        cb({ ok = false, message = 'Manglende telefon ID.' })
        return
    end
    ESX.TriggerServerCallback('san_mdt:startWiretap', function(resp)
        cb(resp or { ok = false, message = 'Kunne ikke starte aflytning.' })
    end, phoneId)
end)

RegisterNUICallback('stopNarkoWiretap', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:stopWiretap', function(resp)
        cb(resp or { ok = false, message = 'Kunne ikke stoppe aflytning.' })
    end)
end)

RegisterNUICallback('getWiretapSession', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getWiretapSession', function(resp)
        cb(resp or { ok = false })
    end)
end)

RegisterNUICallback('getWiretapLive', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getWiretapLive', function(resp)
        cb(resp or { ok = false, logs = {} })
    end, data and data.phoneId)
end)

RegisterNUICallback('getWiretapArchives', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getWiretapArchives', function(resp)
        cb(resp or { ok = false, archives = {} })
    end)
end)

RegisterNUICallback('getWiretapArchive', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getWiretapArchive', function(resp)
        cb(resp or { ok = false })
    end, data and data.id)
end)

RegisterNUICallback('lookMode', function(data, cb)
    setLookMode(data and data.active == true)
    cb({ ok = true })
end)

RegisterNUICallback('mdtLookThrough', function(_, cb)
    setLookMode(true)
    cb({ ok = true })
end)

RegisterNUICallback('mdtRestoreFocus', function(_, cb)
    setLookMode(false)
    cb({ ok = true })
end)

RegisterNUICallback('rmbState', function(data, cb)
    setLookMode(data and data.active == true)
    cb({ ok = true })
end)



-- SAN MDT - Flådestyring GPS/live tracking V84 (ESX police vehicles, realtime for all officers)
local lastFleetVehicle = nil
local lastFleetSent = 0
local lastFleetX, lastFleetY, lastFleetSpeed = 0.0, 0.0, -1
local lastFleetData = { ok = true, units = {} }

local function fleetTrim(v)
    return tostring(v or ''):gsub('^%s*(.-)%s*$', '%1')
end

local function fleetJobName()
    local data = getPlayerData() or {}
    local job = data.job or (ESX.PlayerData and ESX.PlayerData.job) or {}
    return tostring(job.name or '')
end

local function isFleetPoliceJob()
    local jobName = fleetJobName()
    if Config and Config.FleetPoliceJobs and Config.FleetPoliceJobs[jobName] then return true end
    return jobName == tostring((Config and Config.PoliceJob) or 'police')
end

local function isFleetEMSJob()
    local jobName = fleetJobName()
    return Config and Config.FleetEMSJobs and Config.FleetEMSJobs[jobName] == true
end

local function isFleetJob()
    return isFleetPoliceJob() or isFleetEMSJob()
end

local function fleetServiceType()
    if isFleetEMSJob() then return 'ems' end
    if isFleetPoliceJob() then return 'police' end
    return nil
end

local function fleetDebug(msg)
    if Config and Config.FleetDebug then
        print(('[san_mdt:fleet] %s'):format(msg))
        if open then SendNUIMessage({ action = 'fleetDebug', data = msg }) end
    end
end

local function modelInWhitelist(modelHash, display, list)
    display = string.lower(tostring(display or ''))
    if not list then return false end
    if display ~= '' and list[display] == true then return true end
    for modelName, enabled in pairs(list) do
        if enabled and GetHashKey(modelName) == modelHash then return true end
    end
    return false
end

local function isAllowedFleetVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local modelHash = GetEntityModel(veh)
    local display = GetDisplayNameFromVehicleModel(modelHash) or ''

    if isFleetEMSJob() then
        return modelInWhitelist(modelHash, display, Config and Config.FleetEMSVehicleModels)
    end

    if isFleetPoliceJob() then
        return modelInWhitelist(modelHash, display, Config and Config.FleetPoliceVehicleModels)
    end

    return false
end

local function fleetVehicleId(veh)
    local plate = fleetTrim(GetVehicleNumberPlateText(veh) or '')
    if plate ~= '' then return plate end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    return ('NET-%s'):format(netId or 0)
end

local function leaveFleetVehicle()
    -- V9: En politibil skal blive på flådestyring/map, selvom betjenten går ud af bilen.
    -- Serveren holder bilen aktiv så længe køretøjet stadig findes i verden og er registreret fra politi-garagen.
    if lastFleetVehicle then
        TriggerServerEvent('san_mdt:fleetLeave', lastFleetVehicle)
        fleetDebug('left vehicle but keeping fleet unit '..tostring(lastFleetVehicle))
        lastFleetVehicle = nil
        lastFleetSpeed = -1
    end
end

CreateThread(function()
    while true do
        Wait(tonumber(Config and Config.FleetClientPingInterval or 250) or 250)
        if not isFleetJob() then
            leaveFleetVehicle()
        else
            local ped = PlayerPedId()
            local veh = IsPedInAnyVehicle(ped, false) and GetVehiclePedIsIn(ped, false) or 0
            if veh ~= 0 and isAllowedFleetVehicle(veh) then
                local coords = GetEntityCoords(veh)
                local unitId = fleetVehicleId(veh)
                local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)) or 'Køretøj'
                local speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5)
                local now = GetGameTimer()
                local moved = #(coords - vector3(lastFleetX or 0.0, lastFleetY or 0.0, coords.z)) > 0.15
                if unitId ~= lastFleetVehicle or moved or speed ~= lastFleetSpeed or (now - lastFleetSent) > 600 then
                    if lastFleetVehicle and lastFleetVehicle ~= unitId then
                        TriggerServerEvent('san_mdt:fleetLeave', lastFleetVehicle)
                    end
                    lastFleetVehicle = unitId
                    lastFleetX, lastFleetY, lastFleetSpeed, lastFleetSent = coords.x, coords.y, speed, now
                    TriggerServerEvent('san_mdt:fleetPing', {
                        id = unitId,
                        plate = fleetTrim(GetVehicleNumberPlateText(veh) or unitId),
                        model = model,
                        x = coords.x,
                        y = coords.y,
                        z = coords.z,
                        heading = GetEntityHeading(veh),
                        speed = speed,
                        status = 'Online',
                        service = fleetServiceType() or 'police',
                        siren = IsVehicleSirenOn(veh) or IsVehicleSirenAudioOn(veh),
                        netId = NetworkGetNetworkIdFromEntity(veh),
                        vehicleClass = GetVehicleClass(veh)
                    })
                end
            else
                leaveFleetVehicle()
            end
        end
    end
end)

RegisterNetEvent('san_mdt:fleetData', function(resp)
    lastFleetData = resp or { ok = true, units = {} }
    if open then SendNUIMessage({ action = 'fleetData', data = lastFleetData }) end
end)

RegisterNUICallback('getFleetData', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getFleetData', function(resp)
        lastFleetData = resp or { ok = false, units = {} }
        cb(lastFleetData)
    end)
end)

RegisterNUICallback('toggleFleetUnit', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:toggleFleetUnit', function(resp)
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    end, data and data.unitId or '')
end)

RegisterNUICallback('updateFleetUnitSettings', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:updateFleetUnitSettings', function(resp)
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    end, data or {})
end)

RegisterNUICallback('getProfiles', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getProfiles', function(resp) cb(resp or { ok = false, profiles = {} }) end, data and data.search or '')
end)

RegisterNUICallback('getKrimDna', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getKrimDna', function(resp) cb(resp or { ok = false, rows = {} }) end, data or {})
end)

RegisterNUICallback('getKrimFingerprints', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getKrimFingerprints', function(resp) cb(resp or { ok = false, rows = {} }) end, data or {})
end)

RegisterNUICallback('getProfile', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getProfile', function(resp) cb(resp or { ok = false }) end, data and data.identifier or '')
end)

RegisterNUICallback('saveProfile', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveProfile', function(resp) cb(resp or { ok = false, message = 'Kunne ikke gemme profil.' }) end, data or {})
end)

RegisterNUICallback('updateProfileLicense', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:updateProfileLicense', function(resp) cb(resp or { ok = false, message = 'Kunne ikke opdatere licens.' }) end, data or {})
end)

RegisterNUICallback('previewIncidentLicenseSanction', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:previewIncidentLicenseSanction', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('applyIncidentLicenseSanction', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:applyIncidentLicenseSanction', function(resp) cb(resp or { ok = false, message = 'Kunne ikke udføre kørekortssanktion.' }) end, data or {})
end)

RegisterNUICallback('getNskOverview', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getNskOverview', function(resp) cb(resp or { ok = false }) end)
end)
RegisterNUICallback('getNskGangBoard', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getNskGangBoard', function(resp) cb(resp or { ok = false }) end, data or {})
end)
RegisterNUICallback('saveNskGangBoardLayout', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveNskGangBoardLayout', function(resp) cb(resp or { ok = false }) end, data or {})
end)
RegisterNUICallback('getFleetGangTerritories', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getFleetGangTerritories', function(resp) cb(resp or { ok = false, territories = {} }) end)
end)

RegisterNUICallback('saveNskGang', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveNskGang', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('saveNskTerritory', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveNskTerritory', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('deleteNskTerritory', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:deleteNskTerritory', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('registerNskGangMember', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:registerNskGangMember', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('removeNskGangMember', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:removeNskGangMember', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('getNskObservations', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getNskObservations', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('saveNskObservation', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveNskObservation', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('deleteNskObservation', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:deleteNskObservation', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('getNskConnections', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getNskConnections', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('saveNskConnection', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveNskConnection', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('deleteNskConnection', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:deleteNskConnection', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('getNskActivityLog', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getNskActivityLog', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('getWiretapLock', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getWiretapLock', function(resp) cb(resp or { ok = false }) end, data and data.phoneId)
end)

RegisterNUICallback('grantWiretapAccess', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:grantWiretapAccess', function(resp) cb(resp or { ok = false, message = 'Kunne ikke give adgang.' }) end, data and data.phoneId, data and data.targetIdentifier)
end)

local function sanMdtNormPlate(p)
    return string.gsub(string.upper(tostring(p or '')), '%s+', '')
end

RegisterNUICallback('getVehicleDetail', function(data, cb)
    data = data or {}
    ESX.TriggerServerCallback('san_mdt:getVehicleDetail', function(resp) cb(resp or { ok = false }) end, data.plate, {
        includeReports = data.includeReports
    })
end)

RegisterNUICallback('getVehicleLinkedReports', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getVehicleLinkedReports', function(resp) cb(resp or { ok = false, reports = {} }) end, data and data.plate)
end)

RegisterNUICallback('saveVehicleProfile', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveVehicleProfile', function(resp) cb(resp or { ok = false, message = 'Kunne ikke gemme.' }) end, data or {})
end)

RegisterNUICallback('getVehicleTracks', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getVehicleTracks', function(resp) cb(resp or { ok = false, tracks = {} }) end)
end)

RegisterNUICallback('getAssignedFiles', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getAssignedFiles', function(resp) cb(resp or { ok = false, files = {} }) end)
end)

RegisterNUICallback('trackVehicle', function(data, cb)
    local plate = data and tostring(data.plate or '') or ''
    if plate == '' then
        cb({ ok = false, message = 'Manglende nummerplade.' })
        return
    end
    ESX.TriggerServerCallback('san_mdt:trackVehicle', function(resp)
        resp = resp or { ok = false, message = 'Kunne ikke spore køretøj.' }
        if resp.x and resp.y then
            SetNewWaypoint(tonumber(resp.x) + 0.0, tonumber(resp.y) + 0.0)
        end
        if resp.tracked then
            local target = sanMdtNormPlate(plate)
            local found = false
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if DoesEntityExist(veh) then
                    local p = sanMdtNormPlate(GetVehicleNumberPlateText(veh))
                    if p == target then
                        local c = GetEntityCoords(veh)
                        SetNewWaypoint(c.x, c.y)
                        resp.ok = true
                        resp.found = true
                        resp.message = 'Køretøj fundet i verden — GPS sat.'
                        break
                    end
                end
            end
            if not resp.found then
                resp.ok = false
                resp.message = 'Køretøjet er ude men ikke spawned i verden lige nu.'
            end
        end
        cb(resp)
    end, plate)
end)

RegisterNUICallback('getVehicles', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getVehicles', function(resp) cb(resp or { ok = false, vehicles = {} }) end, data and data.search or '')
end)

RegisterNUICallback('refreshPermanentVehicles', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getPermanentVehicles', function(data) cb(data or {}) end)
end)

RegisterNUICallback('returnPermanentVehicle', function(data, cb)
    local plate = data and data.plate or ''
    local price = tonumber(data and data.price) or 0
    ESX.TriggerServerCallback('san_mdt:returnPermanentVehicle', function(resp)
        cb(resp or { ok = false, message = 'Ukendt fejl ved frigivelse.' })
    end, plate, price)
end)


RegisterNUICallback('openEvidenceLocker', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:prepareEvidenceLocker', function(resp)
        resp = resp or { ok = false, message = 'Ukendt fejl ved evidence locker.' }
        cb(resp)
        if resp.ok and resp.stashId then
            -- Luk ikke MDT helt. Vi slipper kun NUI focus, åbner evidence locker,
            -- og giver MDT focus tilbage når inventory er lukket, så hændelsen stadig står åben.
            SetTimeout(120, function()
                if open then
                    -- V26: do not enter lookMode. Only release focus for inventory.
                    SetNuiFocus(false, false)
                    SetNuiFocusKeepInput(false)
                end

                local opened = false
                if GetResourceState('ox_inventory') == 'started' then
                    local ok = pcall(function()
                        exports.ox_inventory:openInventory('stash', resp.stashId)
                    end)
                    opened = ok
                    if not ok then
                        ok = pcall(function()
                            exports.ox_inventory:openInventory('stash', { id = resp.stashId })
                        end)
                        opened = ok
                    end
                end

                if not opened and ESX and ESX.ShowNotification then
                    ESX.ShowNotification('Kunne ikke åbne ox_inventory stash. Tjek client console.')
                end

                CreateThread(function()
                    local waited = 0
                    local seenOpen = false
                    while open and waited < 120000 do
                        Wait(250)
                        waited = waited + 250
                        local invOpen = LocalPlayer and LocalPlayer.state and LocalPlayer.state.invOpen
                        if invOpen then seenOpen = true end
                        if seenOpen and not invOpen then break end
                        if not seenOpen and waited > 2500 then break end
                    end
                    if open then
                        lookMode = false
                        setMdtFocus(true)
                        sendLookMode(false)
                    end
                end)
            end)
        end
    end, data or {})
end)

RegisterNUICallback('getIncidents', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getIncidents', function(resp) cb(resp or { ok = false, incidents = {} }) end, data and data.search or '')
end)

RegisterNUICallback('createIncident', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:createIncident', function(resp) cb(resp or { ok = false }) end)
end)

RegisterNUICallback('saveIncident', function(data, cb)
    local responded = false
    SetTimeout(12000, function()
        if responded then return end
        responded = true
        cb({ ok = false, message = 'Serveren svarede ikke på gem hændelse inden timeout. Tjek server console.' })
    end)
    ESX.TriggerServerCallback('san_mdt:saveIncident', function(resp)
        if responded then return end
        responded = true
        cb(resp or { ok = false, message = 'Ukendt fejl' })
    end, data and data.incident or {})
end)

RegisterNUICallback('syncReportAnpg', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:syncReportAnpg', function(resp)
        cb(resp or { ok = false })
    end, data and data.report or {})
end)

RegisterNUICallback('syncAllReportsAnpg', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:syncAllReportsAnpg', function(resp)
        cb(resp or { ok = false })
    end, data or {})
end)

RegisterNUICallback('flagPlateAnpg', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:flagPlateAnpg', function(resp)
        cb(resp or { ok = false })
    end, data or {})
end)

RegisterNUICallback('flagPersonAnpg', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:flagPersonAnpg', function(resp)
        cb(resp or { ok = false })
    end, data or {})
end)

RegisterNUICallback('issueIncidentFine', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:issueIncidentFine', function(resp)
        cb(resp or { ok = false, message = 'Ukendt fejl ved udstedelse af bøde.' })
    end, data or {})
end)

RegisterNUICallback('deleteIncident', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:deleteIncident', function(resp)
        cb(resp or { ok = false, message = 'Kunne ikke slette hændelsen.' })
    end, data and data.id)
end)


RegisterNUICallback('getEmployees', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getEmployees', function(resp) cb(resp or { ok = false, employees = {} }) end, data and data.search or '')
end)
RegisterNUICallback('updateEmployee', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:updateEmployee', function(resp) cb(resp or { ok = false }) end, data or {})
end)
RegisterNUICallback('getRoles', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getRoles', function(resp) cb(resp or { ok = true, roles = {} }) end)
end)
RegisterNUICallback('getPermissionCatalog', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getPermissionCatalog', function(resp) cb(resp or { ok = true, catalog = {} }) end)
end)
RegisterNUICallback('getPermissionDebug', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getPermissionDebug', function(resp) cb(resp or { ok = false }) end)
end)
RegisterNUICallback('saveRole', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:saveRole', function(resp) cb(resp or { ok = false }) end, data or {})
end)
RegisterNUICallback('deleteRole', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:deleteRole', function(resp) cb(resp or { ok = false }) end, data and data.name or '')
end)
RegisterNUICallback('sendMail', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:sendMail', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('getDashboard', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getDashboard', function(resp) cb(resp or {}) end)
end)

RegisterNUICallback('getMailDirectory', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getMailDirectory', function(resp) cb(resp or { ok=false, employees={} }) end, data or {})
end)

RegisterNUICallback('getSentMailsForProfile', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getSentMailsForProfile', function(resp) cb(resp or { ok=false, mails={} }) end, data or {})
end)

RegisterNUICallback('markMailSeen', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:markMailSeen', function(resp) cb(resp or { ok=false }) end, data or {})
end)

RegisterNUICallback('getMailThread', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getMailThread', function(resp) cb(resp or { ok=false }) end, data or {})
end)

RegisterNUICallback('setMailReplyAllowed', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:setMailReplyAllowed', function(resp) cb(resp or { ok=false }) end, data or {})
end)

RegisterNUICallback('getAuditLogs', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getAuditLogs', function(resp) cb(resp or { ok=false, logs={} }) end, data or {})
end)

RegisterNUICallback('getOfficerAuditTimeline', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getOfficerAuditTimeline', function(resp) cb(resp or { ok=false, logs={} }) end, data and data.identifier or '')
end)

RegisterNUICallback('getFleetUnitLogs', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getFleetUnitLogs', function(resp) cb(resp or { ok=false, logs={} }) end, data and data.unitId or '')
end)

RegisterNUICallback('writeAuditLog', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:writeAuditLog', function(resp) cb(resp or { ok=false }) end, data or {})
end)

RegisterNUICallback('getSelfProfile', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getSelfProfile', function(resp) cb(resp or { ok = false }) end)
end)

RegisterNUICallback('resolveVehicleModels', function(data, cb)
    local models = {}
    for _, raw in ipairs((data and data.hashes) or {}) do
        local hash = tonumber(raw)
        if hash then
            local key = tostring(hash)
            local display = GetDisplayNameFromVehicleModel(hash)
            if display and display ~= '' and display ~= 'CARNOTFOUND' then
                local label = GetLabelText(display)
                if label and label ~= '' and label ~= 'NULL' then
                    models[key] = label
                else
                    models[key] = display
                end
            end
        end
    end
    cb({ ok = true, models = models })
end)

RegisterNUICallback('getOfficerProfile', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getOfficerProfile', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('grantOfficerAward', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:grantOfficerAward', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('getMdtSession', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getMdtSession', function(resp) cb(resp or { ok=false, loggedIn=false }) end)
end)

RegisterNUICallback('loginMdt', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:loginMdt', function(resp)
        if resp and resp.ok then
            mdtPostLoginWarmup()
        end
        cb(resp or { ok=false, message='Kunne ikke logge ind.' })
    end, data or {})
end)

RegisterNUICallback('mdtAuthenticated', function(_, cb)
    mdtPostLoginWarmup()
    cb({ ok = true })
end)

RegisterNUICallback('logoutMdt', function(data, cb)
    cb({ ok=true, closeMdt=true })
    TriggerServerEvent('san_mdt:logoutMdtHard', 'Gik af arbejde / MDT logout')
    SetTimeout(25, function()
        closeMdt()
    end)
end)

RegisterNUICallback('getCharges', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getCharges', function(resp) cb(resp or { ok = false, charges = {} }) end, data or {})
end)

RegisterNUICallback('addCharge', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:addCharge', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('updateCharge', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:updateCharge', function(resp) cb(resp or { ok = false }) end, data or {})
end)

RegisterNUICallback('deleteCharge', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:deleteCharge', function(resp) cb(resp or { ok = false }) end, data or {})
end)


RegisterCommand('mdtpermdebug', function()
    ESX.TriggerServerCallback('san_mdt:getPermissionDebug', function(resp)
        print('^2[san_mdt][PERM DEBUG]^7 ' .. json.encode(resp or {}))
        SendNUIMessage({ action = 'permDebug', data = resp or {} })
    end)
end, false)

-- SAN MDT DUTY / DISPATCH NUI callbacks V1
RegisterNUICallback('getDutyStatus', function(_, cb)
    ESX.TriggerServerCallback('san_mdt:getDutyStatus', function(resp)
        cb(resp or { ok=false, message='Kunne ikke hente tjenestestatus.' })
    end)
end)

RegisterNUICallback('setDutyStatus', function(data, cb)
    local wantsOnDuty = data and data.onDuty == true

    -- HARD FREEZE FIX:
    -- Going OFF duty must never wait for SQL/audit/fleet callbacks before NUI gets a response.
    -- We answer NUI instantly, close focus, and let the server clean duty/patrol/dispatch async.
    if not wantsOnDuty then
        cb({ ok=true, onDuty=false, closeMdt=true, message='Du er gået af arbejde.' })
        TriggerServerEvent('san_mdt:logoutMdtHard', 'Gik af arbejde via MDT')
        SetTimeout(25, function()
            closeMdt()
        end)
        return
    end

    ESX.TriggerServerCallback('san_mdt:setDutyStatus', function(resp)
        resp = resp or { ok=false, message='Kunne ikke opdatere tjenestestatus.' }
        cb(resp)
        if resp.ok and resp.onDuty then
            ESX.ShowNotification('Du er nu på arbejde i MDT.')
        end
    end, true)
end)


RegisterNUICallback('getDispatchDetails', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:getDispatchDetails', function(resp)
        cb(resp or { ok=false, message='Kunne ikke hente dispatch-detaljer.' })
    end, data and data.id or '')
end)

RegisterNUICallback('createDispatchJob', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:createDispatchJob', function(resp)
        cb(resp or { ok=false, message='Kunne ikke oprette opgaven.' })
    end, data or {})
end)

RegisterNUICallback('acceptDispatchJob', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:acceptDispatchJob', function(resp)
        cb(resp or { ok=false, message='Kunne ikke acceptere opgaven.' })
    end, data and data.id or '')
end)

RegisterNUICallback('finishDispatchJob', function(data, cb)
    ESX.TriggerServerCallback('san_mdt:finishDispatchJob', function(resp)
        cb(resp or { ok=false, message='Kunne ikke afslutte opgaven.' })
    end, data and data.id or '')
end)


-- SAN MDT Dispatch auto calls / notifications V94

RegisterNetEvent('san_mdt:dispatchNotify', function(call)
    call = call or {}
    local title = tostring(call.title or 'Nyt opkald')
    local street = tostring(call.street or call.description or 'Ukendt lokation')
    local count = tonumber(call.count or call.shotCount or 1) or 1
    local label = title
    if count > 1 then label = ('%s x%s'):format(title, count) end
    local msg = ('%s\n%s'):format(label, street)

    -- SAN Dispatch: kun vores NUI top-højre notifikation vises.
    -- ESX/GTA native notifications er bevidst fjernet, men lyden beholdes.
    pcall(function() PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false) end)

    SendNUIMessage({ action = 'dispatchNotify', data = call })
    print(('[san_mdt:dispatchNotify] %s | %s | x%s'):format(title, street, tostring(count)))
end)


-- Auto NPC/witness dispatch er flyttet ud i separat resource: san_dispatch.
-- san_mdt modtager stadig opkald via server-eventet san_mdt:autoDispatchCall
-- og viser dem i MDT/dispatch-listen.

print('[san_mdt] client/main.lua loaded (/mdt + san_mdt:open ready)')
