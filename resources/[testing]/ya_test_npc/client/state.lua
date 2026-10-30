_G.TestNpc = _G.TestNpc or {}

TestNpc = _G.TestNpc

TestNpc.netId = TestNpc.netId or 0
TestNpc.ped = 0
TestNpc.spawnData = nil
TestNpc.handcuffed = false
TestNpc.draggedBy = nil

local function entityExists(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity)
end

local function isEntityNetworked(entity)
    if not entityExists(entity) then
        return false
    end

    if NetworkGetEntityIsNetworked then
        return NetworkGetEntityIsNetworked(entity)
    end

    return true
end

function TestNpc.GetEntityNetId(entity)
    if not isEntityNetworked(entity) then
        return 0
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if type(netId) == 'number' and netId > 0 then
        return netId
    end

    return 0
end

local function entityHasTestNpcState(entity)
    if not entityExists(entity) then
        return false
    end

    local ok, isTest = pcall(function()
        return Entity(entity).state.yaTestNpc == true
    end)

    return ok and isTest == true
end

function TestNpc.IsEntity(entity)
    if not entityExists(entity) then
        return false
    end

    if entityHasTestNpcState(entity) then
        return true
    end

    if TestNpc.ped ~= 0 and entity == TestNpc.ped then
        return true
    end

    if not isEntityNetworked(entity) then
        return false
    end

    local entityNetId = TestNpc.GetEntityNetId(entity)
    if entityNetId == 0 then
        return false
    end

    local globalNetId = GlobalState.yaTestNpcNetId
    if globalNetId and globalNetId > 0 and entityNetId == globalNetId then
        return true
    end

    if TestNpc.netId ~= 0 and entityNetId == TestNpc.netId then
        return true
    end

    return false
end

function TestNpc.GetPed()
    if TestNpc.ped ~= 0 and entityExists(TestNpc.ped) and TestNpc.IsEntity(TestNpc.ped) then
        return TestNpc.ped
    end

    if TestNpc.netId ~= 0 and NetworkDoesNetworkIdExist(TestNpc.netId) then
        local ped = NetworkGetEntityFromNetworkId(TestNpc.netId)
        if entityExists(ped) then
            TestNpc.ped = ped
            return ped
        end
    end

    TestNpc.ped = 0
    return 0
end

function TestNpc.ResolvePed(netId)
    netId = tonumber(netId)
    if not netId then return 0 end

    local ped = TestNpc.GetPed()
    if ped ~= 0 and TestNpc.GetEntityNetId(ped) == netId then
        return ped
    end

    if NetworkDoesNetworkIdExist(netId) then
        ped = NetworkGetEntityFromNetworkId(netId)
        if entityExists(ped) and (entityHasTestNpcState(ped) or TestNpc.netId == netId) then
            TestNpc.Set(netId, ped, TestNpc.spawnData)
            return ped
        end
    end

    return 0
end

function TestNpc.Clear()
    TestNpc.netId = 0
    TestNpc.ped = 0
    TestNpc.spawnData = nil
    TestNpc.handcuffed = false
    TestNpc.draggedBy = nil
end

function TestNpc.Set(netId, ped, spawnData)
    TestNpc.netId = tonumber(netId) or 0
    TestNpc.ped = ped or 0
    if spawnData then
        TestNpc.spawnData = spawnData
    end
end

exports('IsTestNpc', function(entity)
    return TestNpc.IsEntity(entity)
end)

exports('GetTestNpcPed', function()
    return TestNpc.GetPed()
end)

_G.TestNpc = TestNpc
