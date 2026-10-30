--- Politifunktioner på test-borgeren (som ya_police_interactions)

TestNpc = _G.TestNpc

local ESX = exports['es_extended']:getSharedObject()

local dragThreadActive = false
local dragCopSrc = nil
local handcuffThreadActive = false
local cuffProp = nil

local HARD_CUFF_PROP = `p_cs_cuffs_02_s`
local SOFT_CUFF_PROP = `p_cs_cuffs_02_s`

local function timings()
    return Config.Timings or {}
end

local function isTestNpcHandcuffed()
    if GlobalState.yaTestNpcHandcuffed then return true end

    local ped = TestNpc.GetPed()
    if ped ~= 0 then
        local ok, state = pcall(function()
            return Entity(ped).state.handcuffed == true
        end)
        if ok and state then return true end
    end

    return TestNpc.handcuffed == true
end

local function loadAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > t then return false end
        Wait(10)
    end
    return true
end

local function playAnim(ped, dict, clip, duration, flag)
    if not loadAnim(dict) then return end
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, duration or -1, flag or 0, 0, false, false, false)
end

local function isSoftCuff(cuffType)
    return cuffType == 'soft' or cuffType == 'soft_front' or cuffType == 'soft_back'
end

local function attachCuffProp(ped, cuffType)
    if cuffProp and DoesEntityExist(cuffProp) then
        DeleteEntity(cuffProp)
        cuffProp = nil
    end
    if not ped or ped == 0 then return end

    local model = isSoftCuff(cuffType) and SOFT_CUFF_PROP or HARD_CUFF_PROP
    lib.requestModel(model)
    cuffProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    AttachEntityToEntity(cuffProp, ped, GetPedBoneIndex(ped, 57005), 0.04, 0.06, 0.0, 75.0, 0.0, 76.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function removeCuffProp()
    if cuffProp and DoesEntityExist(cuffProp) then
        DeleteEntity(cuffProp)
    end
    cuffProp = nil
end

local function playCopCuffAnim(cuffType)
    local playerPed = PlayerPedId()
    if isSoftCuff(cuffType) then
        playAnim(playerPed, 'mp_arresting', 'a_uncuff', 2800, 0)
        Wait(2800)
    else
        playAnim(playerPed, 'mp_arrest_paired', 'cop_p2_back_left', 3500, 0)
        Wait(3500)
    end
    ClearPedTasks(playerPed)
end

local function requestEntityControl(entity, attempts)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if NetworkHasControlOfEntity(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    local maxAttempts = attempts or 80
    local count = 0
    while not NetworkHasControlOfEntity(entity) and count < maxAttempts do
        Wait(10)
        NetworkRequestControlOfEntity(entity)
        count = count + 1
    end

    return NetworkHasControlOfEntity(entity)
end

local function stopDragLoop()
    dragThreadActive = false
    dragCopSrc = nil
end

local function stopHandcuffLoop()
    handcuffThreadActive = false
end

local function startHandcuffLoop(cuffType)
    if handcuffThreadActive then return end
    handcuffThreadActive = true

    CreateThread(function()
        local animDict = isSoftCuff(cuffType) and 'anim@move_m@prisoner_cuffed' or 'mp_arresting'
        local animClip = 'idle'

        while handcuffThreadActive and TestNpc.handcuffed do
            local ped = TestNpc.GetPed()
            if ped == 0 or not DoesEntityExist(ped) then break end

            requestEntityControl(ped, 20)

            if not IsEntityPlayingAnim(ped, animDict, animClip, 3) then
                playAnim(ped, animDict, animClip, -1, 49)
            end

            SetEnableHandcuffs(ped, true)
            FreezeEntityPosition(ped, true)
            Wait(400)
        end

        handcuffThreadActive = false
    end)
end

local function applyHandcuffVisual(ped, enabled, cuffType)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    TestNpc.handcuffed = enabled == true
    TestNpc.cuffType = enabled and cuffType or nil
    requestEntityControl(ped)

    if enabled then
        ClearPedTasksImmediately(ped)
        local animDict = isSoftCuff(cuffType) and 'anim@move_m@prisoner_cuffed' or 'mp_arresting'
        playAnim(ped, animDict, 'idle', -1, 49)
        SetEnableHandcuffs(ped, true)
        FreezeEntityPosition(ped, true)
        attachCuffProp(ped, cuffType)
        startHandcuffLoop(cuffType)
    else
        stopHandcuffLoop()
        stopDragLoop()
        removeCuffProp()
        ClearPedTasksImmediately(ped)
        SetEnableHandcuffs(ped, false)
        DetachEntity(ped, true, false)
        if Config.Freeze ~= true then
            FreezeEntityPosition(ped, false)
        end
        if Config.Wander then
            TaskWanderStandard(ped, 10.0, 10)
        else
            TaskStandStill(ped, -1)
        end
    end
end

local function startDragLoop(copSrc)
    dragCopSrc = tonumber(copSrc)
    if dragThreadActive or not dragCopSrc then return end
    dragThreadActive = true

    CreateThread(function()
        local wasAttached = false

        while dragThreadActive and dragCopSrc do
            local testPed = TestNpc.GetPed()
            if testPed == 0 or not DoesEntityExist(testPed) then break end

            local cop = GetPlayerPed(GetPlayerFromServerId(dragCopSrc))
            if cop ~= 0 and DoesEntityExist(cop) and IsPedOnFoot(cop) then
                requestEntityControl(testPed, 20)
                if not wasAttached then
                    AttachEntityToEntity(testPed, cop, 11816, 0.30, 0.50, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    wasAttached = true
                end
                Wait(50)
            else
                wasAttached = false
                DetachEntity(testPed, true, false)
                Wait(250)
            end
        end

        dragThreadActive = false
        dragCopSrc = nil
        local testPed = TestNpc.GetPed()
        if testPed ~= 0 and DoesEntityExist(testPed) then
            DetachEntity(testPed, true, false)
        end
    end)
end

local function doProgress(label, durationMs, onDone)
    local ok = lib.progressBar({
        label = label,
        duration = durationMs,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if ok and onDone then onDone() end
    return ok
end

local function meAction(text)
    if text and text ~= '' then
        TriggerServerEvent('ya_police:server:meAction', text)
    end
end

local function openSearchMenu()
    if GetResourceState('ox_inventory') == 'started' then
        TriggerServerEvent('ya_test_npc:openSearch')
        return
    end
    ESX.ShowNotification('Test-borger: Ingen ulovlige genstande.')
end

local function showBadge()
    if GetResourceState('ya_police_interactions') ~= 'started' then
        ESX.ShowNotification('Vis Skilt kræver ya_police_interactions.')
        return
    end

    local badge = lib.callback.await('ya_police:server:getBadgeData', false)
    if not badge then
        ESX.ShowNotification('Kunne ikke hente politiskilt.')
        return
    end

    TriggerEvent('ya_police:client:showBadge', badge)
    ESX.ShowNotification('Du viste dit politiskilt for test-borgeren.')
end

local function putInClosestVehicle()
    if not isTestNpcHandcuffed() then
        ESX.ShowNotification('Personen skal i håndjern først.')
        return
    end

    doProgress('Sætter person i køretøj...', timings().SeatbeltMs or 2000, function()
        meAction('Putter sele på personen')

        local playerPed = PlayerPedId()
        playAnim(playerPed, 'mp_common', 'givetake1_a', 1500, 0)

        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle == 0 then
            vehicle = ESX.Game.GetClosestVehicle(GetEntityCoords(playerPed))
        end
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
            ESX.ShowNotification('Intet køretøj i nærheden.')
            return
        end

        local vehicleNetId = TestNpc.GetEntityNetId(vehicle)
        if vehicleNetId == 0 then
            ESX.ShowNotification('Køretøjet er ikke synkroniseret endnu — prøv igen.')
            return
        end

        TriggerServerEvent('ya_test_npc:putInVehicle', vehicleNetId)
    end)
end

local function outOfVehicle()
    doProgress('Tager person ud af køretøj...', timings().SeatbeltMs or 2000, function()
        if isTestNpcHandcuffed() then
            meAction('Tager sele af personen')
        end
        playAnim(PlayerPedId(), 'mp_common', 'givetake2_a', 1500, 0)
        TriggerServerEvent('ya_test_npc:outVehicle')
    end)
end

local function runGsrTest()
    doProgress('GSR-test i gang...', timings().GsrTestMs or 15000, function()
        playAnim(PlayerPedId(), 'amb@medic@standing@kneel@base', 'base', timings().GsrTestMs or 15000, 49)
        local positive = lib.callback.await('ya_test_npc:checkGsr', false)
        ClearPedTasks(PlayerPedId())
        if positive then
            ESX.ShowNotification('GSR — ~g~Positiv~s~: Krudtslam fundet.')
        else
            ESX.ShowNotification('GSR — ~r~Negativ~s~: Intet krudtslam fundet.')
        end
    end)
end

local function runAlcoholTest()
    doProgress('Alkoholtest i gang...', timings().AlcoholTestMs or 8000, function()
        local result = lib.callback.await('ya_test_npc:alcoholTest', false)
        local promille = result.promille or 0
        ESX.ShowNotification(('Alkoholtest — ~y~%.2f‰~s~'):format(promille))
        if result.positive then
            ESX.ShowNotification('~r~Påvirket~s~ over lovlig grænse (0.50‰).')
        else
            ESX.ShowNotification('~g~Under~s~ lovlig grænse (0.50‰).')
        end
    end)
end

local function runDrugTest()
    doProgress('Narkotest i gang...', timings().DrugTestMs or 10000, function()
        local result = lib.callback.await('ya_test_npc:drugTest', false)
        if result.positive then
            ESX.ShowNotification('Narkotest — ~g~Positiv~s~: Stoffer i blodet.')
        else
            ESX.ShowNotification('Narkotest — ~r~Negativ~s~: Intet i blodet.')
        end
    end)
end

local function runDnaSample()
    doProgress('Indsamler DNA-prøve...', timings().DnaSampleMs or 12000, function()
        playAnim(PlayerPedId(), 'amb@medic@standing@kneel@base', 'base', timings().DnaSampleMs or 12000, 49)
        local result = lib.callback.await('ya_test_npc:collectDna', false)
        ClearPedTasks(PlayerPedId())
        if not result or not result.ok then
            ESX.ShowNotification('DNA-prøve mislykkedes.')
            return
        end
        ESX.ShowNotification('DNA-prøve indsamlet.')
        ESX.ShowNotification(('DNA Reference: ~b~%s~s~'):format(result.dnaId))
        ESX.ShowNotification('Registreret i kriminalteknisk database.')
    end)
end

local function runFingerprint()
    local pads = timings().FingerprintPads or 3
    local holdMs = timings().FingerprintHoldMs or 10000

    CreateThread(function()
        for i = 1, pads do
            local ok = doProgress(('Scanner finger %d/%d...'):format(i, pads), holdMs)
            if not ok then
                ESX.ShowNotification('Fingeraftryksscanning afbrudt.')
                return
            end
        end

        local result = lib.callback.await('ya_test_npc:collectFingerprint', false)
        if not result or not result.ok then
            ESX.ShowNotification('Fingeraftryk mislykkedes.')
            return
        end

        ESX.ShowNotification(('Fingeraftryk taget: ~b~%s~s~'):format(result.fingerprintId))
        ESX.ShowNotification('Gemt i fingeraftryksdatabase.')
    end)
end

local function openKrimDna()
    local data = lib.callback.await('ya_test_npc:getForensics', false)
    if not data then return end

    lib.alertDialog({
        header = ('DNA Database — %s'):format(data.name or 'Test Borger'),
        content = data.dnaId
            and ('DNA-ID: %s'):format(data.dnaId)
            or 'Ingen DNA registreret på test-borgeren.',
        centered = true,
    })
end

local function openKrimFingerprint()
    local data = lib.callback.await('ya_test_npc:getForensics', false)
    if not data then return end

    lib.alertDialog({
        header = ('Fingeraftryksdatabase — %s'):format(data.name or 'Test Borger'),
        content = data.fingerprintId
            and ('Fingeraftryk-ID: %s'):format(data.fingerprintId)
            or 'Ingen fingeraftryk registreret på test-borgeren.',
        centered = true,
    })
end

local function openKrimReports()
    if GetResourceState('san_mdt') == 'started' then
        TriggerEvent('san_mdt:open')
    end
    ESX.ShowNotification('Åbner MDT — se rapporter under Hændelser.')
end

function RunPoliceAction(action, extra)
    action = type(action) == 'string' and action:lower() or ''

    if action == 'badge' then
        showBadge()
    elseif action == 'search' then
        openSearchMenu()
    elseif action == 'cuff_hard_back' or action == 'cuff_hard' then
        CreateThread(function()
            playCopCuffAnim('hard')
            TriggerServerEvent('ya_test_npc:toggleHandcuff', 'hard_back')
        end)
    elseif action == 'cuff_soft_back' or action == 'cuff_soft' then
        CreateThread(function()
            playCopCuffAnim('soft')
            TriggerServerEvent('ya_test_npc:toggleHandcuff', 'soft_back')
        end)
    elseif action == 'cuff_soft_front' then
        CreateThread(function()
            playCopCuffAnim('soft')
            TriggerServerEvent('ya_test_npc:toggleHandcuff', 'soft_front')
        end)
    elseif action == 'escort' then
        playAnim(PlayerPedId(), 'amb@code_human_wander_drinking@male@base', 'static', -1, 49)
        TriggerServerEvent('ya_test_npc:toggleDrag')
    elseif action == 'put_vehicle' then
        putInClosestVehicle()
    elseif action == 'out_vehicle' then
        outOfVehicle()
    elseif action == 'gsr' then
        runGsrTest()
    elseif action == 'alcohol' then
        runAlcoholTest()
    elseif action == 'drug' then
        runDrugTest()
    elseif action == 'dna' then
        runDnaSample()
    elseif action == 'fingerprint' then
        runFingerprint()
    elseif action == 'jail' then
        ESX.ShowNotification('Test: Fængsling simuleret — brug på rigtig spiller in-game.')
    else
        ESX.ShowNotification('Ukendt test-handling.')
    end
end

exports('RunPoliceAction', RunPoliceAction)
exports('IsTestNpcHandcuffed', isTestNpcHandcuffed)

RegisterNetEvent('ya_test_npc:syncHandcuff', function(netId, enabled, cuffType)
    netId = tonumber(netId)
    local ped = TestNpc.ResolvePed(netId)
    if ped == 0 then return end
    applyHandcuffVisual(ped, enabled, cuffType)
end)

RegisterNetEvent('ya_test_npc:syncDrag', function(netId, copSrc)
    netId = tonumber(netId)
    local ped = TestNpc.ResolvePed(netId)
    if ped == 0 then return end

    stopDragLoop()
    Wait(50)

    TestNpc.draggedBy = copSrc and tonumber(copSrc) or nil
    if not copSrc then return end
    if not TestNpc.handcuffed then return end

    startDragLoop(copSrc)
end)

RegisterNetEvent('ya_test_npc:syncPutInVehicle', function(netId, vehicleNetId)
    netId = tonumber(netId)
    vehicleNetId = tonumber(vehicleNetId)
    if not vehicleNetId then return end

    local ped = TestNpc.ResolvePed(netId)
    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if ped == 0 or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    stopDragLoop()
    requestEntityControl(ped)
    DetachEntity(ped, true, false)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)

    local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
    for seat = maxSeats - 1, 0, -1 do
        if IsVehicleSeatFree(vehicle, seat) then
            TaskWarpPedIntoVehicle(ped, vehicle, seat)
            if TestNpc.handcuffed then
                SetEnableHandcuffs(ped, true)
            end
            return
        end
    end

    ESX.ShowNotification('Ingen ledige sæder.')
end)

RegisterNetEvent('ya_test_npc:syncOutVehicle', function(netId)
    netId = tonumber(netId)
    local ped = TestNpc.ResolvePed(netId)
    if ped == 0 or not IsPedInAnyVehicle(ped, false) then return end

    requestEntityControl(ped)
    TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
    Wait(800)
    if TestNpc.handcuffed then
        applyHandcuffVisual(ped, true, TestNpc.cuffType or 'hard')
    end
end)

RegisterNetEvent('ya_test_npc:openSearchClient', function()
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:openInventory('stash', 'ya_test_npc_search')
    end
end)

RegisterCommand(Config.GsrToggleCommand or 'testnpcgsr', function()
    TriggerServerEvent('ya_test_npc:toggleGsr')
end, false)

RegisterCommand(Config.DrunkToggleCommand or 'testnpcdrunk', function()
    TriggerServerEvent('ya_test_npc:toggleDrunk')
end, false)

RegisterCommand(Config.DrugToggleCommand or 'testnpcdrugs', function()
    TriggerServerEvent('ya_test_npc:toggleDrugs')
end, false)

RegisterCommand(Config.DeleteCommand or 'delselvnpc', function()
    TriggerServerEvent('ya_test_npc:delete')
    if TestNpc.UnregisterTargets then TestNpc.UnregisterTargets() end
    TestNpc.Clear()
    stopHandcuffLoop()
    stopDragLoop()
    removeCuffProp()
    ESX.ShowNotification('Test-borger fjernet.')
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeCuffProp()
end)
