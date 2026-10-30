local isBusy = false

local function getTargetServerId(entity)
    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    if playerIndex == -1 then
        return nil
    end

    return GetPlayerServerId(playerIndex)
end

local function isDeadPlayer(entity)
    local serverId = getTargetServerId(entity)
    if not serverId then
        return false
    end

    return Player(serverId).state.isDead == true
end

local function getAttemptsUsed(entity)
    local serverId = getTargetServerId(entity)
    if not serverId then
        return Config.MaxAttempts
    end

    return Player(serverId).state.cprAttemptsUsed or 0
end

local function performCpr(victimServerId)
    if isBusy then
        return
    end

    local start = lib.callback.await('ya_cpr_revive:canStart', false, victimServerId)
    if not start or not start.ok then
        lib.notify({
            title = 'CPR',
            description = start and start.message or 'Kan ikke starte CPR.',
            type = 'error'
        })
        return
    end

    isBusy = true

    local completed = lib.progressBar({
        duration = Config.CprDuration,
        label = ('Giver CPR (%d/%d)'):format(start.attempt, start.maxAttempts),
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true
        },
        anim = {
            dict = Config.Anim.dict,
            clip = Config.Anim.clip,
            flag = Config.Anim.flag
        }
    })

    ClearPedTasks(cache.ped)
    isBusy = false

    if not completed then
        lib.notify({
            title = 'CPR',
            description = 'Du stoppede CPR.',
            type = 'inform'
        })
        return
    end

    local result = lib.callback.await('ya_cpr_revive:finishAttempt', false, victimServerId)
    if not result then
        lib.notify({
            title = 'CPR',
            description = 'Noget gik galt.',
            type = 'error'
        })
        return
    end

    lib.notify({
        title = 'CPR',
        description = result.message or 'Forsøg afsluttet.',
        type = result.success and 'success' or 'error'
    })
end

exports.ox_target:addGlobalPlayer({
    {
        name = 'ya_cpr_revive',
        icon = 'fa-solid fa-heart-pulse',
        label = 'Giv CPR',
        distance = Config.MaxDistance,
        canInteract = function(entity, distance)
            if isBusy or entity == cache.ped then
                return false
            end

            if distance > Config.MaxDistance then
                return false
            end

            if not isDeadPlayer(entity) then
                return false
            end

            return getAttemptsUsed(entity) < Config.MaxAttempts
        end,
        onSelect = function(data)
            local victimServerId = getTargetServerId(data.entity)
            if not victimServerId then
                return
            end

            performCpr(victimServerId)
        end
    }
})
