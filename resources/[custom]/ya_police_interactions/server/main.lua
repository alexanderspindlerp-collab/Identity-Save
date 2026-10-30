local PoliceJobs = {}

for i = 1, #(Config.PoliceJobs or {}) do
    PoliceJobs[Config.PoliceJobs[i]] = true
end

local function isPolice(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local job = xPlayer.getJob()
    return job and job.name and PoliceJobs[job.name] == true
end

local function randomHex(len)
    local chars = '0123456789ABCDEF'
    local out = {}
    for _ = 1, len do
        local idx = math.random(1, #chars)
        out[#out + 1] = chars:sub(idx, idx)
    end
    return table.concat(out)
end

local function ensureForensicsColumns()
    local cols = MySQL.query.await('SHOW COLUMNS FROM mdt_civilian_profiles', {}) or {}
    local have = {}
    for i = 1, #cols do
        have[cols[i].Field] = true
    end

    local alters = {
        { 'dna_id', 'VARCHAR(32) NULL DEFAULT NULL' },
        { 'fingerprint_id', 'VARCHAR(32) NULL DEFAULT NULL' },
        { 'dna_collected_at', 'TIMESTAMP NULL DEFAULT NULL' },
        { 'fingerprint_collected_at', 'TIMESTAMP NULL DEFAULT NULL' },
    }

    for i = 1, #alters do
        local name, def = alters[i][1], alters[i][2]
        if not have[name] then
            MySQL.query.await(('ALTER TABLE mdt_civilian_profiles ADD COLUMN %s %s'):format(name, def), {})
        end
    end
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_civilian_profiles (
        identifier VARCHAR(80) NOT NULL PRIMARY KEY,
        profile_image TEXT NULL,
        notes LONGTEXT NULL,
        license_points INT NOT NULL DEFAULT 0,
        license_revoked TINYINT(1) NOT NULL DEFAULT 0,
        license_revocation_note VARCHAR(255) NULL,
        license_revoked_at TIMESTAMP NULL DEFAULT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})

    ensureForensicsColumns()
end)

RegisterNetEvent('ya_police:server:meAction', function(message)
    local src = source
    if not message or message == '' then return end

    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local coords = GetEntityCoords(ped)
    local name = GetPlayerName(src) or 'Ukendt'

    for _, targetId in ipairs(GetPlayers()) do
        local tid = tonumber(targetId)
        local tped = GetPlayerPed(tid)
        if tped ~= 0 and #(coords - GetEntityCoords(tped)) <= 20.0 then
            TriggerClientEvent('ya_police:client:meMessage', tid, name, message)
        end
    end
end)

lib.callback.register('ya_police:server:getBadgeData', function(source)
    if not isPolice(source) then return nil end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return nil end

    local meta = MySQL.single.await(
        'SELECT pnumber, profile_image FROM mdt_employee_meta WHERE identifier = ? LIMIT 1',
        { xPlayer.identifier }
    ) or {}

    local pnumber = meta.pnumber and tostring(meta.pnumber) or ''
    if pnumber == '' then
        local job = xPlayer.getJob()
        pnumber = tostring(job.grade or source)
    end

    return {
        pnumber = pnumber,
        photo = meta.profile_image or '',
    }
end)

lib.callback.register('ya_police:server:collectDna', function(source, targetId)
    if not isPolice(source) or not targetId then return { ok = false } end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then return { ok = false } end

    local row = MySQL.single.await(
        'SELECT dna_id FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1',
        { target.identifier }
    )

    local dnaId = row and row.dna_id
    if not dnaId or dnaId == '' then
        dnaId = ('DNA-%s'):format(randomHex(8))
        MySQL.insert.await([[
            INSERT INTO mdt_civilian_profiles (identifier, dna_id, dna_collected_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE dna_id = VALUES(dna_id), dna_collected_at = NOW()
        ]], { target.identifier, dnaId })
    end

    return { ok = true, dnaId = dnaId, name = target.getName() }
end)

lib.callback.register('ya_police:server:getForensics', function(source, targetId)
    if not isPolice(source) or not targetId then return nil end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then return nil end

    local row = MySQL.single.await(
        'SELECT dna_id, fingerprint_id, dna_collected_at, fingerprint_collected_at FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1',
        { target.identifier }
    ) or {}

    return {
        name = target.getName(),
        dnaId = row.dna_id,
        fingerprintId = row.fingerprint_id,
        dnaAt = row.dna_collected_at,
        fingerprintAt = row.fingerprint_collected_at,
    }
end)

lib.callback.register('ya_police:server:startFingerprint', function(source, targetId)
    if not isPolice(source) or not targetId or source == targetId then
        return { ok = false }
    end

    if not ESX.GetPlayerFromId(targetId) then
        return { ok = false }
    end

    TriggerClientEvent('ya_police:client:fingerprintScan', targetId, source)
    return { ok = true }
end)

lib.callback.register('ya_police:server:completeFingerprint', function(source, officerId)
    local target = ESX.GetPlayerFromId(source)
    if not target or not isPolice(officerId) then
        return { ok = false }
    end

    local row = MySQL.single.await(
        'SELECT fingerprint_id FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1',
        { target.identifier }
    )

    local fpId = row and row.fingerprint_id
    if not fpId or fpId == '' then
        fpId = ('FP-%s'):format(randomHex(8))
        MySQL.insert.await([[
            INSERT INTO mdt_civilian_profiles (identifier, fingerprint_id, fingerprint_collected_at)
            VALUES (?, ?, NOW())
            ON DUPLICATE KEY UPDATE fingerprint_id = VALUES(fingerprint_id), fingerprint_collected_at = NOW()
        ]], { target.identifier, fpId })
    end

    TriggerClientEvent('ya_police:client:fingerprintResult', officerId, {
        ok = true,
        fingerprintId = fpId,
        name = target.getName(),
    })

    return { ok = true, fingerprintId = fpId }
end)

lib.callback.register('ya_police:server:alcoholTest', function(source, targetId)
    if not isPolice(source) or not targetId then return { positive = false, level = 0, promille = 0.0 } end

    local positive = false
    local level = 0
    local scale = Config.DrunkPromilleScale or 500000
    local legal = Config.DrunkLegalPromille or 0.50

    if GetResourceState('esx_status') == 'started' then
        local p = promise.new()
        TriggerEvent('esx_status:getStatus', targetId, 'drunk', function(status)
            if status then
                level = status.val or 0
                local promille = level / scale
                positive = promille >= legal
            end
            p:resolve(true)
        end)
        Citizen.Await(p)
    end

    local promille = level / scale
    return { positive = positive, level = level, promille = promille }
end)

RegisterNetEvent('ya_police:server:showBadge', function(targetId)
    local src = source
    if not isPolice(src) or not targetId then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local meta = MySQL.single.await(
        'SELECT pnumber, profile_image FROM mdt_employee_meta WHERE identifier = ? LIMIT 1',
        { xPlayer.identifier }
    ) or {}

    local pnumber = meta.pnumber and tostring(meta.pnumber) or ''
    if pnumber == '' then
        local job = xPlayer.getJob()
        pnumber = tostring(job.grade or src)
    end

    TriggerClientEvent('ya_police:client:showBadge', targetId, {
        pnumber = pnumber,
        photo = meta.profile_image or '',
    })
end)

RegisterNetEvent('ya_police:server:uncuffProp', function()
    local src = source
    Player(src).state:set('handcuffed', false, true)
    TriggerClientEvent('ya_police:client:syncCuffProp', -1, src, false)
end)

RegisterNetEvent('ya_police:server:craftJoint', function(looseName, jointName)
    local src = source
    looseName = type(looseName) == 'string' and looseName or 'hash_loose'
    jointName = type(jointName) == 'string' and jointName or 'joint_hash'

    if GetResourceState('ox_inventory') ~= 'started' then return end

    local paper = exports.ox_inventory:Search(src, 'count', 'rolling_paper') or 0
    local loose = exports.ox_inventory:Search(src, 'count', looseName) or 0

    if paper < 1 or loose < 1 then
        TriggerClientEvent('esx:showNotification', src, 'Du mangler rullepapir eller stof.')
        return
    end

    if not exports.ox_inventory:CanCarryItem(src, jointName, 1) then
        TriggerClientEvent('esx:showNotification', src, 'Du har ikke plads til jointen.')
        return
    end

    exports.ox_inventory:RemoveItem(src, 'rolling_paper', 1)
    exports.ox_inventory:RemoveItem(src, looseName, 1)
    exports.ox_inventory:AddItem(src, jointName, 1)
    TriggerClientEvent('esx:showNotification', src, 'Joint rullet.')
end)

RegisterNetEvent('ya_police:server:handcuff', function(targetId, cuffStyle)
    local src = source
    if not isPolice(src) or not targetId then return end

    if Player(targetId).state.handcuffed then
        TriggerClientEvent('esx_policejob:handcuff', targetId)
        Player(targetId).state:set('handcuffed', false, true)
        Player(targetId).state:set('cuffStyle', nil, true)
        TriggerClientEvent('ya_police:client:syncCuffProp', -1, targetId, false)
        return
    end

    if cuffStyle == 'soft' then cuffStyle = 'soft_back' end
    if cuffStyle == 'hard' then cuffStyle = 'hard_back' end
    if not Config.CuffStyles[cuffStyle] then cuffStyle = 'hard_back' end

    local style = Config.CuffStyles[cuffStyle]
    local duration = style.copAnim.duration or 3000

    TriggerClientEvent('ya_police:client:cuffAnim', targetId, cuffStyle, src)
    TriggerClientEvent('ya_police:client:copCuffAnim', src, cuffStyle)

    SetTimeout(duration, function()
        TriggerClientEvent('esx_policejob:handcuff', targetId, cuffStyle)
        Player(targetId).state:set('handcuffed', true, true)
        Player(targetId).state:set('cuffStyle', cuffStyle, true)
        TriggerClientEvent('ya_police:client:syncCuffProp', -1, targetId, cuffStyle)
    end)
end)
