local ESX = exports['es_extended']:getSharedObject()

TestNpc = _G.TestNpc

local testNpcBlip = nil

local function removeTestNpcBlip()
    if testNpcBlip and DoesBlipExist(testNpcBlip) then
        RemoveBlip(testNpcBlip)
    end
    testNpcBlip = nil
end

local function showTestNpcBlip(ped)
    removeTestNpcBlip()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local seconds = tonumber(Config.ShowBlipSeconds) or 0
    if seconds <= 0 then return end

    testNpcBlip = AddBlipForEntity(ped)
    SetBlipSprite(testNpcBlip, 480)
    SetBlipColour(testNpcBlip, 2)
    SetBlipScale(testNpcBlip, 0.9)
    SetBlipAsShortRange(testNpcBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Test-borger (politi-test)')
    EndTextCommandSetBlipName(testNpcBlip)

    SetTimeout(seconds * 1000, removeTestNpcBlip)
end

local function placePedOnGround(ped)
    if not ped or ped == 0 then return end

    local ok = pcall(function()
        if PlacePedOnGroundProperly then
            PlacePedOnGroundProperly(ped)
        else
            error('native missing')
        end
    end)

    if ok then return end

    local coords = GetEntityCoords(ped)
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
    if found then
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, groundZ + 0.05, false, false, false)
    end
end

local function notify(msg)
    ESX.ShowNotification(msg or '')
end

local function getGroundCoords(baseCoords)
    local x, y, z = baseCoords.x, baseCoords.y, baseCoords.z
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if found then
        z = groundZ
    end
    return vector3(x, y, z)
end

local function getSpawnData(modelName)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local spawn = getGroundCoords(coords + forward * 2.0)

    return {
        model = type(modelName) == 'string' and modelName ~= '' and modelName or Config.DefaultModel,
        coords = { x = spawn.x, y = spawn.y, z = spawn.z },
        heading = heading + 180.0,
    }
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

local function applyOutfit(ped, modelName)
    SetPedDefaultComponentVariation(ped)

    local modelHash = GetEntityModel(ped)
    local isFemale = modelHash == joaat('mp_f_freemode_01')
        or (type(modelName) == 'string' and modelName:lower() == 'mp_f_freemode_01')

    local outfit = isFemale and Config.Outfit.female or Config.Outfit.male
    if type(outfit) ~= 'table' then return end

    for i = 1, #outfit do
        local part = outfit[i]
        SetPedComponentVariation(ped, part.component, part.drawable, part.texture or 0, 0)
    end
end

local function setupCivilianPed(ped, spawnData)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    requestEntityControl(ped)

    if type(spawnData) == 'table' then
        local x = tonumber(spawnData.x)
        local y = tonumber(spawnData.y)
        local z = tonumber(spawnData.z)
        local h = tonumber(spawnData.heading)
        if x and y and z then
            SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        end
        if h then
            SetEntityHeading(ped, h)
        end
    end

    placePedOnGround(ped)
    ClearPedTasksImmediately(ped)

    applyOutfit(ped, spawnData and spawnData.model)

    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, joaat('CIVMALE'))
    pcall(function() SetPedCanBeTargetted(ped, true) end)
    pcall(function() SetPedCanBeTargettedByPlayer(ped, PlayerId(), true) end)
    pcall(function() SetPedCanBeDraggedOut(ped, true) end)
    SetPedCanRagdoll(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, true)
    SetPedDiesWhenInjured(ped, not Config.Invincible)
    SetEntityInvincible(ped, Config.Invincible == true)
    SetBlockingOfNonTemporaryEvents(ped, Config.BlockAmbientEvents == true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    FreezeEntityPosition(ped, Config.Freeze == true)

    if Config.Wander then
        TaskWanderStandard(ped, 10.0, 10)
    else
        TaskStandStill(ped, -1)
    end

    return true
end

local function waitForNetworkPed(netId)
    local deadline = GetGameTimer() + 15000

    while GetGameTimer() < deadline do
        if NetworkDoesNetworkIdExist(netId) then
            local ped = NetworkGetEntityFromNetworkId(netId)
            if ped ~= 0 and DoesEntityExist(ped) then
                return ped
            end
        end
        Wait(50)
    end

    return 0
end

local function attachToNetPed(netId, spawnData)
    netId = tonumber(netId)
    if not netId then return end

    CreateThread(function()
        local ped = waitForNetworkPed(netId)
        if ped == 0 then
            notify('Test-borger kunne ikke synkronisere.')
            return
        end

        if not setupCivilianPed(ped, spawnData) then
            notify('Kunne ikke opsætte test-borger.')
            return
        end

        TestNpc.Set(netId, ped, spawnData)
        showTestNpcBlip(ped)

        if type(TestNpc.RegisterTargets) == 'function' then
            TestNpc.RegisterTargets(netId, ped)
        else
            TriggerEvent('ya_test_npc:internal:registerTargets', netId, ped)
        end

        notify(('Test-borger klar (%s). Grøn blip på kortet — brug øjet på ham.'):format(Config.FakeName))
    end)
end

local function clearClientState()
    removeTestNpcBlip()

    if type(TestNpc.UnregisterTargets) == 'function' then
        TestNpc.UnregisterTargets()
    else
        TriggerEvent('ya_test_npc:internal:unregisterTargets')
    end

    if type(TestNpc) ~= 'table' or type(TestNpc.Clear) ~= 'function' then
        return
    end

    TestNpc.Clear()
end

local function requestSpawn(modelName)
    local data = getSpawnData(modelName)
    TriggerServerEvent('ya_test_npc:requestSpawn', data.model, data.coords, data.heading)
end

RegisterNetEvent('ya_test_npc:attachPed', attachToNetPed)
RegisterNetEvent('ya_test_npc:detached', clearClientState)

RegisterNetEvent('ya_test_npc:spawnFailed', function(msg)
    clearClientState()
    notify(msg or 'Test-borger fejlede.')
end)

RegisterNetEvent('ya_test_npc:notify', notify)

RegisterNetEvent('ya_test_npc:playHandshake', function(otherSrc)
    otherSrc = tonumber(otherSrc)
    if not otherSrc then return end

    local playerPed = PlayerPedId()
    local otherPed = GetPlayerPed(GetPlayerFromServerId(otherSrc))
    if otherPed == 0 then return end

    TaskTurnPedToFaceEntity(playerPed, otherPed, 1000)
    Wait(500)
    RequestAnimDict('mp_ped_interaction')
    while not HasAnimDictLoaded('mp_ped_interaction') do Wait(10) end
    TaskPlayAnim(playerPed, 'mp_ped_interaction', 'handshake_guy_a', 8.0, -8.0, 2500, 0, 0, false, false, false)
end)

RegisterCommand(Config.Command or 'testnpc', function(_, args)
    requestSpawn(args[1])
end, false)

local function getTargetPedInFront()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local forward = GetEntityForwardVector(playerPed)
    local targetCoords = coords + forward * 2.0
    return lib.getClosestPed(targetCoords, 2.5)
end

RegisterCommand(Config.DebugCommand or 'testnpcinfo', function()
    local ped = getTargetPedInFront()
    if not ped or ped == 0 then
        notify('Ingen ped foran dig.')
        return
    end

    local isTest = TestNpc.IsEntity(ped)
    local netId = TestNpc.GetEntityNetId(ped)
    local globalNetId = GlobalState.yaTestNpcNetId or 0
    local jobName = ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name or 'ukendt'

    notify(('Ped netId: %s | Global test: %s | Er test-NPC: %s | Dit job: %s'):format(
        netId, globalNetId, isTest and 'JA' or 'NEJ', jobName
    ))
end, false)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearClientState()
end)

AddEventHandler('esx:onPlayerLogout', function()
    clearClientState()
end)
