local GsrData = {}

lib.callback.register('bzn_gsr:server:check:gsr', function(_, targetId)
    targetId = tonumber(targetId)
    if not targetId then
        return false
    end

    return Player(targetId).state.gsr == true
end)

lib.callback.register('bzn_gsr:server:set:gsr', function(source)
    GsrData[source] = os.time(os.date('!*t')) + (Config.GsrTime * 60)
    Player(source).state:set('gsr', true, true)
end)

lib.callback.register('bzn_gsr:server:remove:gsr', function(source)
    if GsrData[source] then
        GsrData[source] = nil
        Player(source).state:set('gsr', false, true)
        return true
    end

    return false
end)

local function removeExpiredGsr()
    local now = os.time(os.date('!*t'))

    for playerId, expiresAt in pairs(GsrData) do
        if expiresAt <= now then
            GsrData[playerId] = nil
            Player(playerId).state:set('gsr', false, true)
        end
    end

    SetTimeout(Config.GsrAutoRemoveCheck * 60 * 1000, removeExpiredGsr)
end

SetTimeout(Config.GsrAutoRemoveCheck * 60 * 1000, removeExpiredGsr)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    for playerId in pairs(GsrData) do
        GsrData[playerId] = nil
        Player(playerId).state:set('gsr', false, true)
    end
end)

AddEventHandler('esx:playerDropped', function(playerId)
    GsrData[playerId] = nil
end)
