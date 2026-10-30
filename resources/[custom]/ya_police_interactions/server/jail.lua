local jailedPlayers = {}

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ya_jail (
        identifier VARCHAR(80) NOT NULL PRIMARY KEY,
        release_at BIGINT NOT NULL,
        reason VARCHAR(255) NULL DEFAULT NULL,
        jailed_by VARCHAR(80) NULL DEFAULT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})
end)

local function releasePlayer(targetId, notify)
    local target = ESX.GetPlayerFromId(targetId)
    if not target then return end

    jailedPlayers[target.identifier] = nil
    MySQL.update.await('DELETE FROM ya_jail WHERE identifier = ?', { target.identifier })
    TriggerClientEvent('ya_police:client:releaseFromJail', targetId, notify ~= false)
end

local function applyJail(targetId, minutes, reason, officerIdentifier)
    local target = ESX.GetPlayerFromId(targetId)
    if not target then return false, 'Spilleren er offline.' end

    minutes = math.floor(tonumber(minutes) or 0)
    local maxMinutes = (Config.Jail and Config.Jail.MaxMinutes) or 120
    if minutes < 1 or minutes > maxMinutes then
        return false, ('Fængsel skal være mellem 1 og %d minutter.'):format(maxMinutes)
    end

    local releaseAt = os.time() + (minutes * 60)
    jailedPlayers[target.identifier] = releaseAt

    MySQL.insert.await([[
        INSERT INTO ya_jail (identifier, release_at, reason, jailed_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE release_at = VALUES(release_at), reason = VALUES(reason), jailed_by = VALUES(jailed_by)
    ]], { target.identifier, releaseAt, reason or '', officerIdentifier or '' })

    TriggerClientEvent('ya_police:client:sendToJail', targetId, minutes, reason or '')
    return true
end

RegisterNetEvent('ya_police:server:jailPlayer', function(targetId, minutes, reason)
    local src = source
    if not isPolice(src) or not targetId then return end

    local officer = ESX.GetPlayerFromId(src)
    local ok, msg = applyJail(tonumber(targetId), minutes, reason, officer and officer.identifier or nil)

    if ok then
        TriggerClientEvent('esx:showNotification', src, 'Personen er sendt i fængsel.')
    elseif msg then
        TriggerClientEvent('esx:showNotification', src, msg)
    end
end)

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if not xPlayer then
        xPlayer = ESX.GetPlayerFromId(playerId)
    end
    if not xPlayer then return end

    local row = MySQL.single.await('SELECT release_at, reason FROM ya_jail WHERE identifier = ? LIMIT 1', { xPlayer.identifier })
    if not row or not row.release_at then return end

    local releaseAt = tonumber(row.release_at) or 0
    local remaining = releaseAt - os.time()

    if remaining <= 0 then
        releasePlayer(playerId, false)
        return
    end

    jailedPlayers[xPlayer.identifier] = releaseAt
    TriggerClientEvent('ya_police:client:resumeJail', playerId, remaining, row.reason or '')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        jailedPlayers[xPlayer.identifier] = nil
    end
end)

CreateThread(function()
    while true do
        Wait(15000)
        local now = os.time()

        for identifier, releaseAt in pairs(jailedPlayers) do
            if releaseAt <= now then
                for _, targetId in ipairs(GetPlayers()) do
                    local tid = tonumber(targetId)
                    local xPlayer = ESX.GetPlayerFromId(tid)
                    if xPlayer and xPlayer.identifier == identifier then
                        releasePlayer(tid, true)
                        break
                    end
                end
                jailedPlayers[identifier] = nil
            end
        end
    end
end)
