--- ox_target direkte på test-NPC (matcher ya_police_interactions)

TestNpc = _G.TestNpc

local ESX = exports['es_extended']:getSharedObject()

TestNpc.targetNetId = TestNpc.targetNetId or 0
TestNpc.targetPed = TestNpc.targetPed or 0
TestNpc.usesEntityTarget = false
TestNpc.usesLocalTarget = false

local TARGET_NAMES = {
    'ya_test_npc_badge',
    'ya_test_npc_search',
    'ya_test_npc_cuff_soft_front',
    'ya_test_npc_cuff_hard_back',
    'ya_test_npc_cuff_soft_back',
    'ya_test_npc_escort',
    'ya_test_npc_put_vehicle',
    'ya_test_npc_out_vehicle',
    'ya_test_npc_gsr',
    'ya_test_npc_alcohol',
    'ya_test_npc_drug',
    'ya_test_npc_dna',
    'ya_test_npc_fingerprint',
    'ya_test_npc_jail',
}

local function isPlayerPolice()
    if Config.AllowAnyoneForTesting then return true end

    local job = ESX.PlayerData and ESX.PlayerData.job
    if not job or not job.name then return false end

    for i = 1, #(Config.PoliceJobs or {}) do
        if job.name == Config.PoliceJobs[i] then return true end
    end

    return false
end

local function policeOnly(action)
    if not isPlayerPolice() then
        ESX.ShowNotification('Kun politi kan bruge dette på test-borgeren.')
        return
    end
    RunPoliceAction(action)
end

local function buildTargetOptions()
    return {
        {
            name = 'ya_test_npc_badge',
            icon = 'fa-solid fa-id-badge',
            label = 'Vis Skilt',
            distance = 3.0,
            onSelect = function() policeOnly('badge') end,
        },
        {
            name = 'ya_test_npc_search',
            icon = 'fa-solid fa-magnifying-glass',
            label = 'Visitér',
            distance = 3.0,
            onSelect = function() policeOnly('search') end,
        },
        {
            name = 'ya_test_npc_cuff_soft_front',
            icon = 'fa-solid fa-link',
            label = 'Håndjern foran [Blød]',
            distance = 3.0,
            onSelect = function() policeOnly('cuff_soft_front') end,
        },
        {
            name = 'ya_test_npc_cuff_hard_back',
            icon = 'fa-solid fa-handcuffs',
            label = 'Håndjern bagved [Hård]',
            distance = 3.0,
            onSelect = function() policeOnly('cuff_hard_back') end,
        },
        {
            name = 'ya_test_npc_cuff_soft_back',
            icon = 'fa-solid fa-link',
            label = 'Håndjern bagved [Blød]',
            distance = 3.0,
            onSelect = function() policeOnly('cuff_soft_back') end,
        },
        {
            name = 'ya_test_npc_escort',
            icon = 'fa-solid fa-person-walking-arrow-right',
            label = 'Escortér',
            distance = 3.0,
            onSelect = function() policeOnly('escort') end,
        },
        {
            name = 'ya_test_npc_put_vehicle',
            icon = 'fa-solid fa-car-side',
            label = 'Sæt i bil',
            distance = 3.0,
            canInteract = function()
                return exports.ya_test_npc:IsTestNpcHandcuffed()
            end,
            onSelect = function() policeOnly('put_vehicle') end,
        },
        {
            name = 'ya_test_npc_out_vehicle',
            icon = 'fa-solid fa-door-open',
            label = 'Tag ud af bil',
            distance = 3.0,
            onSelect = function() policeOnly('out_vehicle') end,
        },
        {
            name = 'ya_test_npc_gsr',
            icon = 'fa-solid fa-vial',
            label = 'GSR Test',
            distance = 3.0,
            onSelect = function() policeOnly('gsr') end,
        },
        {
            name = 'ya_test_npc_alcohol',
            icon = 'fa-solid fa-wine-bottle',
            label = 'Alkoholtest',
            distance = 3.0,
            onSelect = function() policeOnly('alcohol') end,
        },
        {
            name = 'ya_test_npc_drug',
            icon = 'fa-solid fa-capsules',
            label = 'Narkotest',
            distance = 3.0,
            onSelect = function() policeOnly('drug') end,
        },
        {
            name = 'ya_test_npc_dna',
            icon = 'fa-solid fa-dna',
            label = 'DNA Prøve',
            distance = 3.0,
            onSelect = function() policeOnly('dna') end,
        },
        {
            name = 'ya_test_npc_fingerprint',
            icon = 'fa-solid fa-fingerprint',
            label = 'Fingeraftryk',
            distance = 3.0,
            onSelect = function() policeOnly('fingerprint') end,
        },
        {
            name = 'ya_test_npc_jail',
            icon = 'fa-solid fa-building-lock',
            label = 'Fængsl person',
            distance = 3.0,
            onSelect = function() policeOnly('jail') end,
        },
    }
end

function TestNpc.UnregisterTargets()
    if GetResourceState('ox_target') ~= 'started' then
        TestNpc.targetNetId = 0
        TestNpc.targetPed = 0
        TestNpc.usesEntityTarget = false
        TestNpc.usesLocalTarget = false
        return
    end

    if TestNpc.usesEntityTarget and TestNpc.targetNetId and TestNpc.targetNetId > 0 then
        pcall(function()
            exports.ox_target:removeEntity(TestNpc.targetNetId, TARGET_NAMES)
        end)
    end

    if TestNpc.usesLocalTarget and TestNpc.targetPed and TestNpc.targetPed ~= 0 then
        pcall(function()
            exports.ox_target:removeLocalEntity(TestNpc.targetPed, TARGET_NAMES)
        end)
    end

    TestNpc.targetNetId = 0
    TestNpc.targetPed = 0
    TestNpc.usesEntityTarget = false
    TestNpc.usesLocalTarget = false
end

function TestNpc.RegisterTargets(netId, ped)
    if GetResourceState('ox_target') ~= 'started' then return false end

    netId = tonumber(netId)
    ped = ped or 0

    if not netId or netId == 0 or ped == 0 or not DoesEntityExist(ped) then return false end

    TestNpc.UnregisterTargets()

    TestNpc.targetNetId = netId
    TestNpc.targetPed = ped

    local options = buildTargetOptions()
    local deadline = GetGameTimer() + 10000

    while GetGameTimer() < deadline do
        if NetworkDoesNetworkIdExist(netId) then
            exports.ox_target:addEntity(netId, options)
            TestNpc.usesEntityTarget = true
            ESX.ShowNotification('Test-borger: Politimenu klar (som rigtig spiller).')
            return true
        end
        Wait(100)
    end

    exports.ox_target:addLocalEntity(ped, options)
    TestNpc.usesLocalTarget = true
    ESX.ShowNotification('Test-borger: Politimenu klar (lokal fallback).')
    return true
end

_G.TestNpc = TestNpc

AddEventHandler('ya_test_npc:internal:registerTargets', function(netId, ped)
    TestNpc.RegisterTargets(netId, ped)
end)

AddEventHandler('ya_test_npc:internal:unregisterTargets', function()
    TestNpc.UnregisterTargets()
end)

RegisterCommand('testnpctarget', function()
    local ped = TestNpc.GetPed()
    local netId = TestNpc.netId

    if ped == 0 or not netId or netId == 0 then
        ESX.ShowNotification('Ingen test-borger aktiv — kør /testnpc først.')
        return
    end

    TestNpc.RegisterTargets(netId, ped)
end, false)

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    TriggerServerEvent('ya_test_npc:requestSync')
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'ox_target' and resourceName ~= GetCurrentResourceName() then return end

    SetTimeout(1500, function()
        local ped = TestNpc.GetPed()
        if ped ~= 0 and TestNpc.netId and TestNpc.netId > 0 then
            TestNpc.RegisterTargets(TestNpc.netId, ped)
        end
    end)
end)
