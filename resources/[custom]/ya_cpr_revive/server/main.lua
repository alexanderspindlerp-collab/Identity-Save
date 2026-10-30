local attempts = {}

local function getAttempts(victimId)
    return attempts[victimId] or 0
end

local function setAttemptsState(victimId, count)
    attempts[victimId] = count
    Player(victimId).state:set('cprAttemptsUsed', count, true)
end

local function clearAttempts(victimId)
    attempts[victimId] = nil
    Player(victimId).state:set('cprAttemptsUsed', 0, true)
end

local function isTargetDead(victimId)
    local player = Player(victimId)
    return player and player.state.isDead == true
end

local function isAmbulanceOnDuty()
    if not Config.BlockWhenAmbulanceOnDuty then
        return false
    end

    for _, jobName in ipairs(Config.AmbulanceJobs) do
        local medics = ESX.GetExtendedPlayers('job', jobName)
        if medics and next(medics) then
            return true
        end
    end

    return false
end

local function canReviverUseCpr(source)
    if Config.AllowedJobs then
        local xPlayer = ESX.GetPlayerFromId(source)
        if not xPlayer then
            return false, 'Du kan ikke give CPR lige nu.'
        end

        local allowed = false
        for _, job in ipairs(Config.AllowedJobs) do
            if xPlayer.job.name == job then
                allowed = true
                break
            end
        end

        if not allowed then
            return false, 'Du har ikke tilladelse til at give CPR.'
        end
    end

    if isAmbulanceOnDuty() then
        return false, 'Ambulancen er på vagt — ring efter dem i stedet.'
    end

    if Player(source).state.isDead then
        return false, 'Du kan ikke give CPR mens du er bevidstløs.'
    end

    return true
end

local function reviveVictim(victimId)
    if not isTargetDead(victimId) then
        return false
    end

    clearAttempts(victimId)
    TriggerClientEvent('esx_ambulancejob:revive', victimId)
    return true
end

lib.callback.register('ya_cpr_revive:canStart', function(source, victimId)
    victimId = tonumber(victimId)
    if not victimId or victimId == source then
        return { ok = false, message = 'Ugyldigt mål.' }
    end

    local ok, message = canReviverUseCpr(source)
    if not ok then
        return { ok = false, message = message }
    end

    if not ESX.GetPlayerFromId(victimId) then
        return { ok = false, message = 'Personen er ikke længere online.' }
    end

    if not isTargetDead(victimId) then
        return { ok = false, message = 'Personen er ikke bevidstløs.' }
    end

    local used = getAttempts(victimId)
    if used >= Config.MaxAttempts then
        return {
            ok = false,
            message = ('Der er brugt alle %d CPR-forsøg på denne person.'):format(Config.MaxAttempts)
        }
    end

    return {
        ok = true,
        attempt = used + 1,
        maxAttempts = Config.MaxAttempts,
        remaining = Config.MaxAttempts - used
    }
end)

lib.callback.register('ya_cpr_revive:finishAttempt', function(source, victimId)
    victimId = tonumber(victimId)
    if not victimId or victimId == source then
        return { ok = false, message = 'Ugyldigt mål.' }
    end

    local ok, message = canReviverUseCpr(source)
    if not ok then
        return { ok = false, message = message }
    end

    if not ESX.GetPlayerFromId(victimId) then
        return { ok = false, message = 'Personen er ikke længere online.' }
    end

    if not isTargetDead(victimId) then
        return { ok = false, message = 'Personen er ikke længere bevidstløs.' }
    end

    local used = getAttempts(victimId)
    if used >= Config.MaxAttempts then
        return {
            ok = false,
            success = false,
            message = ('Alle %d CPR-forsøg er brugt.'):format(Config.MaxAttempts)
        }
    end

    local attempt = used + 1
    setAttemptsState(victimId, attempt)

    local success = false
    if Config.GuaranteedOnLastAttempt and attempt >= Config.MaxAttempts then
        success = true
    else
        success = math.random(100) <= Config.SuccessChance
    end

    if success then
        reviveVictim(victimId)
        return {
            ok = true,
            success = true,
            attempt = attempt,
            maxAttempts = Config.MaxAttempts,
            remaining = 0,
            message = 'CPR lykkedes — personen er ved bevidsthed igen!'
        }
    end

    local remaining = Config.MaxAttempts - attempt
    local failMessage = remaining > 0
        and ('CPR fejlede (%d/%d). %d forsøg tilbage.'):format(attempt, Config.MaxAttempts, remaining)
        or ('CPR fejlede — alle %d forsøg er brugt.'):format(Config.MaxAttempts)

    return {
        ok = true,
        success = false,
        attempt = attempt,
        maxAttempts = Config.MaxAttempts,
        remaining = remaining,
        message = failMessage
    }
end)

AddEventHandler('esx:onPlayerDeath', function()
    clearAttempts(source)
end)

AddEventHandler('esx:playerDropped', function(playerId)
    attempts[playerId] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    for _, playerId in ipairs(GetPlayers()) do
        playerId = tonumber(playerId)
        Player(playerId).state:set('cprAttemptsUsed', getAttempts(playerId), true)
    end
end)
