--- Server-spawnet test-borger (netværket ped, alle klienter).

local testNpc = {
    entity = nil,
    netId = nil,
    owner = nil,
    model = nil,
    coords = nil,
    heading = 0.0,
    handcuffed = false,
    cuffType = nil,
    draggedBy = nil,
    spawnData = nil,
    gsr = false,
    drunk = false,
    drugs = false,
    dnaId = nil,
    fingerprintId = nil,
}

local function tryNative(fn, ...)
    if type(fn) ~= 'function' then return false end
    return pcall(fn, ...)
end

local function broadcastAttach(netId, spawnData)
    TriggerClientEvent('ya_test_npc:attachPed', -1, netId, spawnData)
end

local function broadcastDetach()
    TriggerClientEvent('ya_test_npc:detached', -1)
end

local function deleteTestNpc()
    local entity = testNpc.entity
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    testNpc.entity = nil
    testNpc.netId = nil
    testNpc.owner = nil
    testNpc.model = nil
    testNpc.coords = nil
    testNpc.heading = 0.0
    testNpc.handcuffed = false
    testNpc.cuffType = nil
    testNpc.draggedBy = nil
    testNpc.dnaId = nil
    testNpc.fingerprintId = nil
    GlobalState.yaTestNpcNetId = nil
    GlobalState.yaTestNpcHandcuffed = nil
    GlobalState.yaTestNpcGsr = nil
end

local function finalizeServerPed(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false
    end

    tryNative(SetEntityOrphanMode, entity, 2)

    pcall(function()
        Entity(entity).state:set('yaTestNpc', true, true)
    end)

    return true
end

local function normalizeModelName(modelName)
    if type(modelName) ~= 'string' then return Config.DefaultModel end
    modelName = modelName:lower():gsub('%s+', '')
    if modelName == '' then return Config.DefaultModel end
    return modelName
end

local function isModelBlocked(modelName)
    modelName = normalizeModelName(modelName)
    local blocked = Config.BlockedModels or {}
    for i = 1, #blocked do
        if normalizeModelName(blocked[i]) == modelName then
            return true
        end
    end
    return false
end

local function resolveSpawnModel(modelName)
    modelName = normalizeModelName(modelName)

    if isModelBlocked(modelName) then
        return nil, 'Politi-/tjeneste-peds er blokeret på serveren. Brug fx mp_m_freemode_01.'
    end

    local allowed = Config.AllowedModels
    if type(allowed) == 'table' and #allowed > 0 then
        for i = 1, #allowed do
            if normalizeModelName(allowed[i]) == modelName then
                return modelName
            end
        end
        return nil, ('Model "%s" er ikke tilladt. Brug fx %s.'):format(modelName, Config.DefaultModel)
    end

    return modelName
end

local function isPolicePlayer(src)
    if Config.AllowAnyoneForTesting then
        return true
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job or not xPlayer.job.name then
        return false
    end

    for i = 1, #(Config.PoliceJobs or {}) do
        if xPlayer.job.name == Config.PoliceJobs[i] then
            return true
        end
    end

    return false
end

local function syncHandcuffState()
    if not testNpc.entity or not DoesEntityExist(testNpc.entity) then
        return
    end

    pcall(function()
        Entity(testNpc.entity).state:set('handcuffed', testNpc.handcuffed == true, true)
    end)

    GlobalState.yaTestNpcHandcuffed = testNpc.handcuffed == true
end

local function syncGsrState()
    if testNpc.entity and DoesEntityExist(testNpc.entity) then
        pcall(function()
            Entity(testNpc.entity).state:set('gsr', testNpc.gsr == true, true)
        end)
    end

    GlobalState.yaTestNpcGsr = testNpc.gsr == true
end

local function spawnTestNpcForPlayer(src, modelName, coords, heading)
    deleteTestNpc()
    broadcastDetach()

    local resolvedModel, modelErr = resolveSpawnModel(modelName)
    if not resolvedModel then
        TriggerClientEvent('ya_test_npc:spawnFailed', src, modelErr)
        return false
    end

    modelName = resolvedModel
    local model = joaat(modelName)
    local x = tonumber(coords.x) or 0.0
    local y = tonumber(coords.y) or 0.0
    local z = tonumber(coords.z) or 0.0
    heading = tonumber(heading) or 0.0

    local entity = CreatePed(0, model, x, y, z, heading, true, true)
    local attempts = 0

    while (not entity or entity == 0 or not DoesEntityExist(entity)) and attempts < 200 do
        Wait(0)
        attempts = attempts + 1
    end

    if not entity or entity == 0 or not DoesEntityExist(entity) then
        TriggerClientEvent('ya_test_npc:spawnFailed', src, 'Server kunne ikke oprette test-borger.')
        return false
    end

    if not finalizeServerPed(entity) then
        DeleteEntity(entity)
        TriggerClientEvent('ya_test_npc:spawnFailed', src, 'Server kunne ikke låse test-borger.')
        return false
    end

    local netId = 0
    local netDeadline = GetGameTimer() + 5000

    while GetGameTimer() < netDeadline do
        if DoesEntityExist(entity) then
            local isNetworked = not NetworkGetEntityIsNetworked or NetworkGetEntityIsNetworked(entity)
            if isNetworked then
                netId = NetworkGetNetworkIdFromEntity(entity)
                if type(netId) == 'number' and netId > 0 then
                    break
                end
            end
        end
        Wait(0)
    end

    if not netId or netId == 0 then
        DeleteEntity(entity)
        TriggerClientEvent('ya_test_npc:spawnFailed', src, 'Test-borger kunne ikke netværkssynkronisere.')
        return false
    end

    local spawnData = { x = x, y = y, z = z, heading = heading, model = modelName }

    testNpc.entity = entity
    testNpc.netId = netId
    testNpc.owner = src
    testNpc.model = modelName
    testNpc.coords = vector3(x, y, z)
    testNpc.heading = heading
    testNpc.handcuffed = false
    testNpc.draggedBy = nil
    testNpc.spawnData = nil
    testNpc.gsr = Config.DefaultTestGsr == true
    testNpc.drunk = Config.DefaultTestDrunk == true
    testNpc.drugs = Config.DefaultTestDrugs == true
    testNpc.cuffType = nil
    testNpc.drunk = false
    testNpc.drugs = false
    testNpc.dnaId = nil
    testNpc.fingerprintId = nil

    testNpc.spawnData = spawnData

    GlobalState.yaTestNpcNetId = netId
    GlobalState.yaTestNpcHandcuffed = false
    syncHandcuffState()
    syncGsrState()

    broadcastAttach(netId, spawnData)
    TriggerClientEvent('ya_test_npc:notify', src, ('Test-borger spawnet (%s). Brug øjet som på en spiller.'):format(Config.FakeName))
    return true
end

local function syncTestNpcToClient(clientId)
    if not testNpc.netId or not testNpc.spawnData then return end

    TriggerClientEvent('ya_test_npc:attachPed', clientId, testNpc.netId, testNpc.spawnData)
    TriggerClientEvent('ya_test_npc:syncHandcuff', clientId, testNpc.netId, testNpc.handcuffed, testNpc.cuffType)

    if testNpc.draggedBy then
        TriggerClientEvent('ya_test_npc:syncDrag', clientId, testNpc.netId, testNpc.draggedBy)
    end
end

RegisterNetEvent('ya_test_npc:requestSync', function()
    syncTestNpcToClient(source)
end)

RegisterNetEvent('ya_test_npc:requestSpawn', function(modelName, coords, heading)
    local src = source
    if type(coords) ~= 'table' then return end
    spawnTestNpcForPlayer(src, modelName, coords, heading)
end)

RegisterNetEvent('ya_test_npc:delete', function()
    deleteTestNpc()
    broadcastDetach()
end)

RegisterNetEvent('ya_test_npc:serverAction', function(action, targetSrc)
    local src = source
    targetSrc = tonumber(targetSrc)
    if not targetSrc then return end

    if action == 'handshake' then
        TriggerClientEvent('ya_test_npc:playHandshake', src, targetSrc)
        TriggerClientEvent('ya_test_npc:playHandshake', targetSrc, src)
    end
end)

RegisterNetEvent('ya_test_npc:toggleHandcuff', function(cuffType)
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end

    cuffType = tostring(cuffType or 'hard_back')
    if cuffType:find('soft') then cuffType = cuffType == 'soft_front' and 'soft_front' or 'soft_back' end
    if cuffType == 'hard' then cuffType = 'hard_back' end

    if testNpc.handcuffed then
        testNpc.handcuffed = false
        testNpc.cuffType = nil
    else
        testNpc.handcuffed = true
        testNpc.cuffType = cuffType
    end

    syncHandcuffState()
    TriggerClientEvent('ya_test_npc:syncHandcuff', -1, testNpc.netId, testNpc.handcuffed, testNpc.cuffType)
end)

RegisterNetEvent('ya_test_npc:toggleDrag', function()
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end

    if testNpc.draggedBy == src then
        testNpc.draggedBy = nil
    else
        testNpc.draggedBy = src
    end

    TriggerClientEvent('ya_test_npc:syncDrag', -1, testNpc.netId, testNpc.draggedBy)
end)

RegisterNetEvent('ya_test_npc:putInVehicle', function(vehicleNetId)
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end
    TriggerClientEvent('ya_test_npc:syncPutInVehicle', -1, testNpc.netId, tonumber(vehicleNetId))
end)

RegisterNetEvent('ya_test_npc:outVehicle', function()
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end
    TriggerClientEvent('ya_test_npc:syncOutVehicle', -1, testNpc.netId)
end)

CreateThread(function()
    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:RegisterStash('ya_test_npc_search', 'Test-borger (tom)', 20, 50000, false)
    end
end)

RegisterNetEvent('ya_test_npc:openSearch', function()
    local src = source
    if not isPolicePlayer(src) then return end
    if GetResourceState('ox_inventory') ~= 'started' then
        TriggerClientEvent('ya_test_npc:notify', src, 'Test-borger: Ingen ulovlige genstande.')
        return
    end
    TriggerClientEvent('ya_test_npc:openSearchClient', src)
end)

AddEventHandler('playerDropped', function()
    if testNpc.draggedBy == source then
        testNpc.draggedBy = nil
        if testNpc.netId then
            TriggerClientEvent('ya_test_npc:syncDrag', -1, testNpc.netId, nil)
        end
    end

    if testNpc.owner == source then
        deleteTestNpc()
        broadcastDetach()
    end
end)

CreateThread(function()
    while true do
        Wait(2000)

        if not testNpc.entity then goto continue end

        if not DoesEntityExist(testNpc.entity) then
            local owner = testNpc.owner
            local model = testNpc.model
            local coords = testNpc.coords
            local heading = testNpc.heading

            testNpc.entity = nil
            testNpc.netId = nil
            broadcastDetach()

            if owner and Config.AutoRespawn and model and coords then
                spawnTestNpcForPlayer(owner, model, { x = coords.x, y = coords.y, z = coords.z }, heading)
            elseif owner then
                TriggerClientEvent('ya_test_npc:spawnFailed', owner, 'Test-borger forsvandt — kør /testnpc igen.')
            end
        end

        ::continue::
    end
end)

exports('GetTestNpcNetId', function()
    return testNpc.netId
end)

exports('IsTestNpcNetId', function(netId)
    return testNpc.netId ~= nil and testNpc.netId == tonumber(netId)
end)

exports('GetTestNpcGsr', function()
    return testNpc.gsr == true
end)

lib.callback.register('ya_test_npc:checkGsr', function(source)
    if not isPolicePlayer(source) or not testNpc.netId then
        return false
    end

    return testNpc.gsr == true
end)

RegisterNetEvent('ya_test_npc:toggleGsr', function()
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end

    testNpc.gsr = not testNpc.gsr
    syncGsrState()

    TriggerClientEvent('ya_test_npc:notify', src, ('Test-borger GSR: %s'):format(testNpc.gsr and 'POSITIV' or 'NEGATIV'))
end)

RegisterNetEvent('ya_test_npc:toggleDrunk', function()
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end

    testNpc.drunk = not testNpc.drunk
    TriggerClientEvent('ya_test_npc:notify', src, ('Test-borger alkohol: %s'):format(testNpc.drunk and 'PÅVIRKET' or 'IKKE PÅVIRKET'))
end)

RegisterNetEvent('ya_test_npc:toggleDrugs', function()
    local src = source
    if not isPolicePlayer(src) or not testNpc.netId then return end

    testNpc.drugs = not testNpc.drugs
    TriggerClientEvent('ya_test_npc:notify', src, ('Test-borger stoffer: %s'):format(testNpc.drugs and 'POSITIV' or 'NEGATIV'))
end)

local function randomHex(len)
    local chars = '0123456789ABCDEF'
    local out = {}
    for _ = 1, len do
        local idx = math.random(1, #chars)
        out[#out + 1] = chars:sub(idx, idx)
    end
    return table.concat(out)
end

lib.callback.register('ya_test_npc:collectDna', function(source)
    if not isPolicePlayer(source) or not testNpc.netId then return { ok = false } end

    if not testNpc.dnaId or testNpc.dnaId == '' then
        testNpc.dnaId = ('DNA-%s'):format(randomHex(8))
    end

    return { ok = true, dnaId = testNpc.dnaId, name = Config.FakeName or 'Test Borger' }
end)

lib.callback.register('ya_test_npc:collectFingerprint', function(source)
    if not isPolicePlayer(source) or not testNpc.netId then return { ok = false } end

    if not testNpc.fingerprintId or testNpc.fingerprintId == '' then
        testNpc.fingerprintId = ('FP-%s'):format(randomHex(8))
    end

    return { ok = true, fingerprintId = testNpc.fingerprintId, name = Config.FakeName or 'Test Borger' }
end)

lib.callback.register('ya_test_npc:getForensics', function(source)
    if not isPolicePlayer(source) or not testNpc.netId then return nil end

    return {
        name = Config.FakeName or 'Test Borger',
        dnaId = testNpc.dnaId,
        fingerprintId = testNpc.fingerprintId,
    }
end)

lib.callback.register('ya_test_npc:alcoholTest', function(source)
    if not isPolicePlayer(source) or not testNpc.netId then return { positive = false, promille = 0.0 } end
    if testNpc.drunk then
        return { positive = true, promille = 1.25 }
    end
    return { positive = false, promille = 0.08 }
end)

lib.callback.register('ya_test_npc:drugTest', function(source)
    if not isPolicePlayer(source) or not testNpc.netId then return { positive = false } end
    return { positive = testNpc.drugs == true }
end)

AddEventHandler('esx:playerLoaded', function(playerId)
    syncTestNpcToClient(playerId)
end)
