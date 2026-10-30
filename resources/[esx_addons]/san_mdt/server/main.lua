local ESX = exports['es_extended']:getSharedObject()


-- SAN MDT STEAM PRIMARY GUARD
-- This build is made for servers that want ESX/users.identifier to be steam:xxxxx.
local function mdtRequiredIdentifierType()
    return tostring((Config and Config.MdtIdentifierType) or 'steam'):lower()
end

local function mdtGetIdentifierByType(src, typ)
    typ = tostring(typ or ''):lower()
    if typ == '' then return nil end
    local ok, id = pcall(function() return GetPlayerIdentifierByType(src, typ) end)
    if ok and id and tostring(id) ~= '' then return tostring(id) end
    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        if tostring(identifier):sub(1, #typ + 1) == (typ .. ':') then return tostring(identifier) end
    end
    return nil
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    if not (Config and Config.RequireSteamIdentifier) then return end
    local src = source
    deferrals.defer()
    Wait(0)

    local attempts = tonumber(Config.SteamConnectAttempts) or 50
    local delay = tonumber(Config.SteamConnectRetryMs) or 100

    for i = 1, attempts do
        local steam = mdtGetIdentifierByType(src, 'steam')
        if steam then
            deferrals.done()
            return
        end
        deferrals.update(('Tjekker Steam-forbindelse... (%s/%s)'):format(i, attempts))
        Wait(delay)
    end

    deferrals.done((Config and Config.SteamMissingKickMessage) or 'Steam skal være åbent før FiveM.')
end)

-- SAN MDT CLEAN ACCESS CORE
-- Robust ESX Legacy / multicharacter support. Never call ESX.Player() unless it exists.
-- If ESX cannot provide xPlayer/job because identifier config is wrong, MDT falls back to users.job by license/steam identifiers.

local function trim(s)
    return tostring(s or ''):gsub('^%s*(.-)%s*$', '%1')
end

local function decodeJson(v, fallback)
    if type(v) == 'table' then return v end
    if not v or v == '' then return fallback or {} end
    local ok, data = pcall(json.decode, v)
    if ok and data then return data end
    return fallback or {}
end

local function normalizePersonIdentifier(value)
    if type(value) == 'table' then
        if type(value.identifier) == 'string' then return trim(value.identifier) end
        if type(value[1]) == 'string' then return trim(value[1]) end
        return ''
    end
    return trim(value)
end

local function getPersonMdtCharges(criminal)
    if type(criminal) ~= 'table' then return {} end
    if type(criminal.mdtCharges) == 'table' then return criminal.mdtCharges end
    return {}
end

local function calcPersonPenalties(criminal)
    local arr = getPersonMdtCharges(criminal)
    local jail, fine, points = 0, 0, 0
    for _, ch in ipairs(arr) do
        local n = math.max(1, tonumber(ch.count) or 1)
        jail = jail + (tonumber(ch.jail) or 0) * n
        fine = fine + (tonumber(ch.fine) or 0) * n
        points = points + (tonumber(ch.points) or 0) * n
    end
    local red = type(criminal.chargeReduction) == 'table' and criminal.chargeReduction or {}
    return {
        jail = math.max(0, jail - (tonumber(red.jail) or 0)),
        fine = math.max(0, fine - (tonumber(red.fine) or 0)),
        points = math.max(0, points - (tonumber(red.points) or 0)),
    }
end

local function mdtIdentifiers(src)
    local ids = { all = {} }
    for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
        ids.all[#ids.all + 1] = identifier
        local typ = tostring(identifier):match('^([^:]+):')
        if typ and not ids[typ] then ids[typ] = identifier end
    end
    ids.license = ids.license or GetPlayerIdentifierByType(src, 'license')
    ids.steam = ids.steam or GetPlayerIdentifierByType(src, 'steam')
    ids.discord = ids.discord or GetPlayerIdentifierByType(src, 'discord')
    return ids
end

local function mdtPrimaryIdentifier(src, xPlayer)
    local required = mdtRequiredIdentifierType()
    local requiredId = mdtGetIdentifierByType(src, required)
    if requiredId then return requiredId end

    -- In Steam-primary mode we must NOT silently fall back to license,
    -- otherwise MDT/garage/profiles will store mixed identifiers.
    if Config and Config.RequireSteamIdentifier and required == 'steam' then
        return ''
    end

    local ok, identifier = pcall(function()
        if xPlayer then
            if type(xPlayer.getIdentifier) == 'function' then return xPlayer.getIdentifier() end
            if xPlayer.identifier then return xPlayer.identifier end
        end
    end)
    if ok and identifier and tostring(identifier) ~= '' then return tostring(identifier) end
    local ids = mdtIdentifiers(src)
    return tostring(ids[required] or ids.license or ids.steam or ids.discord or ('source:' .. tostring(src)))
end

local function mdtFindUserRowBySource(src, xPlayer)
    if not MySQL or not MySQL.single or not MySQL.single.await then return nil end
    local ids = mdtIdentifiers(src)
    local required = mdtRequiredIdentifierType()
    local candidates = {}
    local function add(v)
        v = tostring(v or '')
        if v ~= '' then candidates[#candidates + 1] = v end
    end

    -- ESX multicharacter stores identifiers as char1:steam:xxxx / char2:steam:xxxx.
    -- Earlier builds only searched exact steam:xxxx, so DB job became ukendt even though Steam existed.
    if Config and Config.RequireSteamIdentifier and required == 'steam' then
        local steam = ids.steam or mdtGetIdentifierByType(src, 'steam') -- normally steam:110000...
        local steamHex = nil
        if steam and steam ~= '' then
            steamHex = tostring(steam):gsub('^steam:', '') -- database may store char1:110000... without steam: prefix
        end

        add(steam)
        add(steamHex)

        if steam and steam ~= '' then
            for slot = 1, 10 do
                add(('char%s:%s'):format(slot, steam))
                if steamHex and steamHex ~= '' then add(('char%s:%s'):format(slot, steamHex)) end
            end

            -- ESX multichar can store several Steam formats:
            -- steam:HEX, HEX, char1:steam:HEX, char1:HEX
            local ok, row = pcall(function()
                -- Robust ESX multichar + Steam matching.
                -- Common DB formats seen on this server:
                --   char1:11000012f6f89f7
                --   char1:steam:11000012f6f89f7
                --   steam:11000012f6f89f7
                --   11000012f6f89f7
                return MySQL.single.await([[
                    SELECT identifier, firstname, lastname, job, job_grade
                    FROM users
                    WHERE identifier = ?
                       OR identifier = ?
                       OR identifier LIKE ?
                       OR identifier LIKE ?
                       OR identifier LIKE ?
                       OR identifier LIKE ?
                       OR identifier LIKE ?
                    ORDER BY
                        CASE
                            WHEN identifier LIKE 'char1:%' THEN 0
                            WHEN identifier LIKE 'char2:%' THEN 1
                            ELSE 2
                        END, identifier ASC
                    LIMIT 1
                ]], {
                    steam,
                    steamHex,
                    'char%:' .. steam,
                    'char%:' .. steamHex,
                    '%:' .. steam,
                    '%:' .. steamHex,
                    '%' .. steamHex
                })
            end)
            if ok and row then return row end
        end
    else
        add(mdtPrimaryIdentifier(src, xPlayer)); add(ids[required]); add(ids.license); add(ids.steam); add(ids.discord)
        for _, id in ipairs(ids.all or {}) do add(id) end
        for _, base in ipairs({ids.license, ids.steam}) do
            if base and base ~= '' then
                for slot = 1, 10 do add(('char%s:%s'):format(slot, base)) end
            end
        end
    end

    local seen = {}
    for _, id in ipairs(candidates) do
        if not seen[id] then
            seen[id] = true
            local ok, row = pcall(function() return MySQL.single.await('SELECT identifier, firstname, lastname, job, job_grade FROM users WHERE identifier = ? LIMIT 1', { id }) end)
            if ok and row then return row end
        end
    end

    -- V2 ACCESS HARD FALLBACK:
    -- Some ESX multicharacter setups store users.identifier as char1:HEX (no steam: prefix),
    -- while FiveM returns steam:HEX. If exact candidates above miss, search by the raw Steam hex.
    -- This is intentionally scoped to the connected player's own Steam hex only.
    local steam = ids.steam or mdtGetIdentifierByType(src, 'steam')
    local steamHex = steam and tostring(steam):gsub('^steam:', '') or nil
    if steamHex and steamHex ~= '' then
        local ok, row = pcall(function()
            return MySQL.single.await([[
                SELECT identifier, firstname, lastname, job, job_grade
                FROM users
                WHERE identifier = ?
                   OR identifier = ?
                   OR identifier LIKE ?
                   OR identifier LIKE ?
                   OR identifier LIKE ?
                ORDER BY
                    CASE
                        WHEN identifier LIKE 'char1:%' THEN 0
                        WHEN identifier LIKE 'char2:%' THEN 1
                        WHEN identifier LIKE 'char3:%' THEN 2
                        ELSE 9
                    END, identifier ASC
                LIMIT 1
            ]], { steam, steamHex, 'char%:' .. steamHex, 'char%:steam:' .. steamHex, '%' .. steamHex .. '%' })
        end)
        if ok and row then return row end
    end

    return nil
end

local function getPlayer(src)
    local xPlayer = nil
    if ESX and type(ESX.GetPlayerFromId) == 'function' then
        local ok, res = pcall(function() return ESX.GetPlayerFromId(src) end)
        if ok then xPlayer = res end
    end
    if not xPlayer and ESX and type(ESX.Player) == 'function' then
        local ok, res = pcall(function() return ESX.Player(src) end)
        if ok then xPlayer = res end
    end
    if type(xPlayer) ~= 'table' then xPlayer = {} end
    xPlayer.__mdtSource = tonumber(src)
    xPlayer.__mdtIdentifier = mdtPrimaryIdentifier(src, xPlayer)
    local row = mdtFindUserRowBySource(src, xPlayer)
    if row then
        xPlayer.__mdtUserRow = row
        xPlayer.__mdtDbJob = row.job
        xPlayer.__mdtIdentifier = row.identifier or xPlayer.__mdtIdentifier
    end
    return xPlayer
end

local function getPlayerByIdentifier(identifier)
    identifier = trim(identifier)
    if identifier == '' then return nil end
    if ESX and type(ESX.GetPlayerFromIdentifier) == 'function' then
        local ok, res = pcall(function() return ESX.GetPlayerFromIdentifier(identifier) end)
        if ok and res then return res end
    end
    if ESX and type(ESX.Player) == 'function' then
        local ok, res = pcall(function() return ESX.Player(identifier) end)
        if ok and res then return res end
    end
    if ESX and type(ESX.GetExtendedPlayers) == 'function' then
        local ok, players = pcall(function() return ESX.GetExtendedPlayers() end)
        if ok and type(players) == 'table' then
            for _, xp in pairs(players) do
                local id = ''
                if type(xp.getIdentifier) == 'function' then
                    local okId, got = pcall(function() return xp.getIdentifier() end)
                    if okId and got then id = tostring(got) end
                elseif xp.identifier then
                    id = tostring(xp.identifier)
                end
                if id ~= '' and id == identifier then return xp end
            end
        end
    end
    return nil
end

local function notifyPlayerByIdentifier(identifier, message)
    message = tostring(message or '')
    if message == '' then return end
    local xTarget = getPlayerByIdentifier(identifier)
    if xTarget and type(xTarget.showNotification) == 'function' then
        pcall(function() xTarget.showNotification(message) end)
        return
    end
    if ESX and type(ESX.GetPlayerIdFromIdentifier) == 'function' then
        local ok, src = pcall(function() return ESX.GetPlayerIdFromIdentifier(identifier) end)
        if ok and tonumber(src) and tonumber(src) > 0 then
            TriggerClientEvent('esx:showNotification', tonumber(src), message)
        end
    end
end

local function getPlayerSourceSafe(xPlayer, fallback)
    local fb = tonumber(fallback)
    if fb and fb > 0 then return fb end
    if type(xPlayer) == 'table' then
        local raw = rawget(xPlayer, '__mdtSource') or rawget(xPlayer, 'source') or rawget(xPlayer, 'playerId') or rawget(xPlayer, 'id')
        if tonumber(raw) and tonumber(raw) > 0 then return tonumber(raw) end
        if type(xPlayer.source) == 'number' and xPlayer.source > 0 then return xPlayer.source end
    end
    return nil
end
_G.getPlayerSourceSafe = _G.getPlayerSourceSafe or getPlayerSourceSafe

local syncJobGradeFromDb
local normalizePoliceJobGrade

local function policeJobNameMatches(jobName)
    jobName = tostring(jobName or ''):lower()
    return jobName == tostring(Config.PoliceJob or 'police'):lower() or jobName == 'police' or jobName == 'politi' or jobName == 'lspd' or jobName == 'sheriff'
end
local isPoliceJobName = policeJobNameMatches
_G.isPoliceJobName = policeJobNameMatches

local function getJob(xPlayer)
    if not xPlayer then return nil end
    if xPlayer.__mdtJob then
        return normalizePoliceJobGrade and normalizePoliceJobGrade(xPlayer.__mdtJob) or xPlayer.__mdtJob
    end
    local job = nil
    if type(xPlayer.getJob) == 'function' then
        local ok, res = pcall(function() return xPlayer.getJob() end)
        if ok and type(res) == 'table' and res.name then job = res end
        if not job then
            ok, res = pcall(function() return xPlayer.getJob(xPlayer) end)
            if ok and type(res) == 'table' and res.name then job = res end
        end
    end
    if not job and type(xPlayer.job) == 'function' then
        local ok, res = pcall(function() return xPlayer.job() end)
        if ok and type(res) == 'table' and res.name then job = res end
        if not job then
            ok, res = pcall(function() return xPlayer.job(xPlayer) end)
            if ok and type(res) == 'table' and res.name then job = res end
        end
    end
    if not job and type(xPlayer.job) == 'table' and xPlayer.job.name then job = xPlayer.job end
    if job and syncJobGradeFromDb then return syncJobGradeFromDb(xPlayer, job) end
    if xPlayer.__mdtDbJob and tostring(xPlayer.__mdtDbJob) ~= '' then
        local fallback = {
            name = tostring(xPlayer.__mdtDbJob),
            label = tostring(xPlayer.__mdtDbJob),
            grade = tonumber((xPlayer.__mdtUserRow or {}).job_grade or 0) or 0,
            grade_label = tostring((xPlayer.__mdtUserRow or {}).job_grade or ''),
        }
        return normalizePoliceJobGrade and normalizePoliceJobGrade(fallback) or fallback
    end
    local src = getPlayerSourceSafe(xPlayer)
    if src and Player then
        local ok, st = pcall(function() return Player(src).state end)
        if ok and st then
            local sj = st.job or st.esx_job or st.jobName
            if type(sj) == 'table' and sj.name and syncJobGradeFromDb then return syncJobGradeFromDb(xPlayer, sj) end
            if type(sj) == 'string' and sj ~= '' then return { name = sj, label = sj, grade = 0, grade_label = '' } end
        end
    end
    return nil
end

local function hasJobAccess(xPlayer)
    local job = getJob(xPlayer)
    local name = tostring(job and job.name or ''):lower()
    return name ~= '' and Config and Config.AllowedJobs and Config.AllowedJobs[name] == true
end

local function noAccessResponse(src, xPlayer)
    local job = getJob(xPlayer)
    local jobName = tostring(job and job.name or 'ukendt')
    local steam = mdtGetIdentifierByType(src, 'steam')
    if Config and Config.RequireSteamIdentifier and not steam then
        return { ok=false, message='Ingen Steam identifier. Ã…bn Steam, luk FiveM helt, start FiveM igen og join serveren.' }
    end
    local ids = mdtIdentifiers(src)
    local row = xPlayer and xPlayer.__mdtUserRow or nil
    print(('[san_mdt][ACCESS] denied src=%s steam=%s license=%s matchedIdentifier=%s dbJob=%s job=%s'):format(tostring(src), tostring(ids.steam), tostring(ids.license), tostring(row and row.identifier), tostring(row and row.job), tostring(jobName)))
    return { ok=false, message=('Ingen adgang. Dit job blev lÃ¦st som: %s'):format(jobName) }
end




RegisterCommand('mdtdebug', function(src)
    if src == 0 then
        print('[san_mdt] /mdtdebug skal kÃ¸res af en spiller in-game.')
        return
    end
    local ids = mdtIdentifiers(src)
    local xPlayer = getPlayer(src)
    local job = getJob(xPlayer)
    local row = xPlayer and xPlayer.__mdtUserRow or nil
    print(('[san_mdt:debug] src=%s name=%s steam=%s license=%s primary=%s job=%s dbIdentifier=%s dbJob=%s access=%s'):format(
        tostring(src), tostring(GetPlayerName(src)), tostring(ids.steam), tostring(ids.license), tostring(xPlayer and xPlayer.__mdtIdentifier), tostring(job and job.name), tostring(row and row.identifier), tostring(row and row.job), tostring(hasJobAccess(xPlayer))
    ))
end, false)

ESX.RegisterCommand('mdt', 'user', function(xPlayer)
    if not hasJobAccess(xPlayer) then
        xPlayer.showNotification('Du har ikke adgang til MDT.')
        return
    end
    xPlayer.triggerEvent('san_mdt:toggle')
end, false, {
    help = 'Åbn eller luk Mobile Data Terminal (MDT)',
    arguments = {},
})

local function safePlayerName(src, fallback)
    src = tonumber(src)
    if not src or src <= 0 then return fallback or 'Ukendt' end
    local ok, name = pcall(function() return GetPlayerName(src) end)
    if ok and name and tostring(name) ~= '' then return tostring(name) end
    return fallback or 'Ukendt'
end

local function getCharacterNameFromPlayer(xPlayer)
    if not xPlayer then return nil end
    local row = xPlayer.__mdtUserRow
    if row then
        local first = row.firstname or row.first_name or ''
        local last = row.lastname or row.last_name or ''
        local full = trim((first .. ' ' .. last))
        if full ~= '' then return full end
        if row.name and tostring(row.name) ~= '' then return tostring(row.name) end
    end
    if type(xPlayer.get) == 'function' then
        local okFn, fn = pcall(function() return xPlayer.get('firstName') end)
        local okLn, ln = pcall(function() return xPlayer.get('lastName') end)
        if okFn or okLn then
            local full = trim(tostring((okFn and fn) or '') .. ' ' .. tostring((okLn and ln) or ''))
            if full ~= '' then return full end
        end
    end
    return nil
end

local function getOfficerName(xPlayer, src)
    local charName = getCharacterNameFromPlayer(xPlayer)
    if charName and charName ~= '' then return charName end

    src = tonumber(src) or getPlayerSourceSafe(xPlayer)
    local steamName = (src and src > 0) and safePlayerName(src, nil) or nil

    if xPlayer and type(xPlayer.getName) == 'function' then
        local ok, name = pcall(function() return xPlayer.getName() end)
        if ok and name and tostring(name) ~= '' then
            name = tostring(name)
            if not steamName or name:lower() ~= tostring(steamName):lower() then
                return name
            end
        end
    end

    if steamName and steamName ~= '' then return steamName end
    if xPlayer then
        local id = tostring(getMdtIdentifier(xPlayer) or xPlayer.identifier or '')
        if id ~= '' then return id end
    end
    return 'Ukendt'
end

local function getMdtIdentifier(xPlayer)
    if xPlayer and xPlayer.__mdtIdentifier and tostring(xPlayer.__mdtIdentifier) ~= '' then return tostring(xPlayer.__mdtIdentifier) end
    if xPlayer and type(xPlayer.getIdentifier) == 'function' then local ok, id = pcall(function() return xPlayer.getIdentifier() end); if ok and id then return tostring(id) end end
    return tostring((xPlayer and xPlayer.identifier) or '')
end

-- SAN MDT Audit/Logs V1 - central server-side immutable activity log
local MDT_LOG_CATEGORIES = {
    DISPATCH='Dispatch', INCIDENT='HÃ¦ndelser', REPORT='Rapporter', PROFILE='Profiler', FLEET='Patruljer', VEHICLE='KÃ¸retÃ¸jer', DUTY='Duty', SEARCH='SÃ¸gninger', ADMIN='Administration', ROLE='Roller', EMPLOYEE='Ansatte', EVIDENCE='Beviser', CHARGE='Sigtelser', SYSTEM='System'
}

local function mdtAuditEnsureTable()
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_audit_logs` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `category` VARCHAR(64) NOT NULL DEFAULT 'System',
            `action` VARCHAR(96) NOT NULL DEFAULT '',
            `officer_identifier` VARCHAR(128) DEFAULT '',
            `officer_name` VARCHAR(128) DEFAULT '',
            `officer_badge` VARCHAR(32) DEFAULT '',
            `target_type` VARCHAR(64) DEFAULT '',
            `target_id` VARCHAR(128) DEFAULT '',
            `target_label` VARCHAR(255) DEFAULT '',
            `message` TEXT NULL,
            `metadata` LONGTEXT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `category_idx` (`category`),
            KEY `action_idx` (`action`),
            KEY `officer_identifier_idx` (`officer_identifier`),
            KEY `target_idx` (`target_type`, `target_id`),
            KEY `created_at_idx` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
end
CreateThread(function() Wait(1500); mdtAuditEnsureTable() end)

local function mdtGetBadge(xPlayer, src)
    local ok, val = pcall(function()
        if type(fleetGetOfficerPNumber) == 'function' then return fleetGetOfficerPNumber(xPlayer, src) end
        return nil
    end)
    if ok and val and tostring(val) ~= '' then return tostring(val) end
    local job = getJob(xPlayer) or {}
    return tostring(job.grade_label or job.grade or src or '')
end

-- Kun disse handlinger vises i MDT-Logs nÃ¥r Config.MDTAuditImportantOnly = true
local MDT_AUDIT_IMPORTANT_ACTIONS = {
    WIRETAP_STARTED = true,
    WIRETAP_STOPPED = true,
    WIRETAP_ACCESS_GRANTED = true,
    INCIDENT_DELETED = true,
    INCIDENT_FINE_ISSUED = true,
    EMPLOYEE_FIRED = true,
    EMPLOYEE_UPDATED = true,
    EMPLOYEE_PERMISSIONS_SAVED = true,
    ROLE_SAVED = true,
    ROLE_DELETED = true,
    VEHICLE_RELEASED = true,
}

local MDT_AUDIT_LOG_CATEGORIES = { 'Alle', 'Aflytning', 'Administration', 'HÃ¦ndelser', 'KÃ¸retÃ¸jer' }

local function mdtAuditIsImportant(action)
    return MDT_AUDIT_IMPORTANT_ACTIONS[tostring(action or '')] == true
end

local function mdtAuditShouldLog(action)
    if Config.MDTAuditImportantOnly == false then return true end
    return mdtAuditIsImportant(action)
end

local function mdtAuditFilterRows(rows)
    if Config.MDTAuditImportantOnly == false then return rows end
    local out = {}
    for i = 1, #rows do
        if mdtAuditIsImportant(rows[i].action) then out[#out + 1] = rows[i] end
    end
    return out
end

local function mdtAuditLog(src, category, action, opts)
    opts = opts or {}
    action = tostring(action or '')
    if action == '' then action = 'MDT_ACTION' end
    if not mdtAuditShouldLog(action) then return end
    local xPlayer = getPlayer(src)
    local identifier = tostring(opts.identifier or (xPlayer and xPlayer.identifier) or src or '')
    local officer = tostring(opts.officer or (xPlayer and getOfficerName(xPlayer, src)) or safePlayerName(src, 'System'))
    local badge = tostring(opts.badge or mdtGetBadge(xPlayer, src) or '')
    category = tostring(category or 'System')
    local metadata = opts.metadata or {}
    metadata.source = src
    local ok, err = pcall(function()
        MySQL.insert.await([[INSERT INTO mdt_audit_logs
            (category, action, officer_identifier, officer_name, officer_badge, target_type, target_id, target_label, message, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
            category, action, identifier, officer, badge,
            tostring(opts.target_type or ''), tostring(opts.target_id or ''), tostring(opts.target_label or ''),
            tostring(opts.message or ''), json.encode(metadata)
        })
    end)
    if not ok then print(('[san_mdt:audit] insert failed: %s'):format(tostring(err))) end
end

exports('AuditLog', function(src, category, action, opts) mdtAuditLog(src, category, action, opts or {}) end)

local MDT_MAP_FILES = {
    'nui/img/dlk-satellite-map.jpg',
    'nui/img/dlk-master-4096x6144.png',
    'nui/img/satellite-map.png',
}

exports('GetMapImageSources', function()
    local resource = GetCurrentResourceName()
    local sources = {}
    for i = 1, #MDT_MAP_FILES do
        local file = MDT_MAP_FILES[i]
        sources[#sources + 1] = ('https://cfx-nui-%s/%s'):format(resource, file)
        sources[#sources + 1] = ('nui://%s/%s'):format(resource, file)
    end
    return sources
end)

local function canViewMdtLogs(xPlayer)
    local job = getJob(xPlayer)
    if not job then return false end
    local isPolice = (job.name == (Config.PoliceJob or 'police') or job.name == 'police' or job.name == 'politi' or job.name == 'lspd' or job.name == 'sheriff')
    local grade = tonumber(job.grade or job.grade_number or 0) or 0
    local gradeName = tostring(job.grade_name or job.name_grade or job.grade_label or ''):lower()
    return isPolice and (grade >= 7 or gradeName == 'rigspolitiet' or gradeName == 'boss')
end

local function auditDisplayCategory(action, category)
    action = tostring(action or '')
    if action:find('^WIRETAP_') then return 'Aflytning' end
    if action:find('^EMPLOYEE_') or action:find('^ROLE_') then return 'Administration' end
    if action == 'INCIDENT_DELETED' then return 'HÃ¦ndelser' end
    if action == 'VEHICLE_RELEASED' then return 'KÃ¸retÃ¸jer' end
    return category or 'System'
end

local function auditRow(r)
    local action = r.action or ''
    return {
        id = r.id,
        category = auditDisplayCategory(action, r.category or 'System'),
        action = action,
        officer_identifier = r.officer_identifier or '',
        officer_name = r.officer_name or 'Ukendt',
        officer_badge = r.officer_badge or '',
        target_type = r.target_type or '',
        target_id = r.target_id or '',
        target_label = r.target_label or '',
        message = r.message or '',
        metadata = decodeJson(r.metadata, {}),
        created_at = r.created_at
    }
end

local function tableContains(list, value)
    if type(list) ~= 'table' then return false end
    for _, v in ipairs(list) do
        if tostring(v) == tostring(value) then return true end
    end
    return false
end

local function normalizePermissions(perms)
    local out, seen = {}, {}
    if type(perms) == 'string' then perms = decodeJson(perms, {}) end
    if type(perms) ~= 'table' then return out end
    for k, v in pairs(perms) do
        local candidates = {}
        if type(k) == 'string' and (v == true or v == 1 or tostring(v) == 'true' or tostring(v) == '1') then
            candidates[#candidates+1] = k
        end
        if type(v) == 'string' then
            candidates[#candidates+1] = v
        elseif type(v) == 'table' then
            for kk, vv in pairs(v) do
                if type(kk) == 'string' and (vv == true or vv == 1 or tostring(vv) == 'true' or tostring(vv) == '1') then candidates[#candidates+1] = kk end
                if type(vv) == 'string' then candidates[#candidates+1] = vv end
            end
        end
        for _, perm in ipairs(candidates) do
            perm = trim(perm)
            if perm ~= '' and not seen[perm] then seen[perm] = true; out[#out+1] = perm end
        end
    end
    return out
end

local function permListHas(perms, permission)
    local normalized = normalizePermissions(perms)
    for _, p in ipairs(normalized) do
        if tostring(p) == tostring(permission) then return true end
    end
    return false
end

-- Must be defined before getRoleNameCandidates (Lua local scope).
local function getIdentifier(xPlayer)
    if xPlayer and xPlayer.__mdtIdentifier and tostring(xPlayer.__mdtIdentifier) ~= '' then return tostring(xPlayer.__mdtIdentifier) end
    if xPlayer and type(xPlayer.getIdentifier) == 'function' then
        local ok, id = pcall(function() return xPlayer.getIdentifier() end)
        if ok and id and tostring(id) ~= '' then return tostring(id) end
    end
    if xPlayer and xPlayer.identifier and tostring(xPlayer.identifier) ~= '' then return tostring(xPlayer.identifier) end
    return ''
end

local KNOWN_MDT_ROLE_NAMES = {
    ['rigspolitiet'] = true, ['inspektør'] = true, ['nsk chef'] = true, ['nsk afdeling'] = true,
    ['kommissær'] = true, ['assistent 1. grad'] = true, ['assistent'] = true, ['betjent'] = true,
    ['elev'] = true, ['receptionist'] = true, ['rengøring'] = true, ['suspenderet'] = true,
    ['nsk_chef'] = true, ['nsk_afdeling'] = true,
}

local permissionCache = {}

local function invalidatePermissionCache(identifier)
    identifier = trim(identifier or '')
    if identifier ~= '' then permissionCache[identifier] = nil end
end

local function invalidatePermissionCacheForSource(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    permissionCache['src:' .. tostring(src)] = nil
    local xPlayer = getPlayer(src)
    if xPlayer then invalidatePermissionCache(getIdentifier(xPlayer)) end
end

local MDT_GRADE_TO_ROLE = {
    [0] = 'Elev', [1] = 'Betjent', [2] = 'Assistent', [3] = 'Assistent 1. Grad',
    [4] = 'Kommissær', [5] = 'NSK Chef', [6] = 'Inspektør', [7] = 'Rigspolitiet',
}
local MDT_GRADE_TO_NAME = {
    [0] = 'elev', [1] = 'betjent', [2] = 'assistent', [3] = 'assistent_1_grad',
    [4] = 'kommissaer', [5] = 'nsk_chef', [6] = 'inspektoer', [7] = 'rigspolitiet',
}

normalizePoliceJobGrade = function(job)
    if not job or not policeJobNameMatches(job.name) then return job end
    local grade = tonumber(job.grade or job.grade_number or job.job_grade or 0) or 0
    job.grade = grade
    job.grade_number = grade
    if MDT_GRADE_TO_ROLE[grade] then
        local label = MDT_GRADE_TO_ROLE[grade]
        local name = MDT_GRADE_TO_NAME[grade]
        if not job.grade_label or trim(job.grade_label) == '' or trim(job.grade_label) == tostring(grade) then
            job.grade_label = label
        end
        if not job.grade_name or trim(job.grade_name) == '' then
            job.grade_name = name
        end
    end
    return job
end

syncJobGradeFromDb = function(xPlayer, job)
    if not job or not xPlayer then return job end
    local row = xPlayer.__mdtUserRow
    if not row then return normalizePoliceJobGrade(job) end
    local dbJob = tostring(row.job or ''):lower()
    local liveJob = tostring(job.name or ''):lower()
    if dbJob == '' or liveJob == '' or dbJob ~= liveJob then return normalizePoliceJobGrade(job) end
    local dbGrade = tonumber(row.job_grade)
    if dbGrade == nil then return normalizePoliceJobGrade(job) end
    local liveGrade = tonumber(job.grade or job.grade_number or job.job_grade or 0) or 0
    if dbGrade ~= liveGrade then
        job.grade = dbGrade
        job.grade_number = dbGrade
    end
    return normalizePoliceJobGrade(job)
end

local function clearPermissionCache()
    permissionCache = {}
end

AddEventHandler('esx:setJob', function(src, job, lastJob)
    src = tonumber(src)
    if not src or src <= 0 then return end
    invalidatePermissionCacheForSource(src)
    if mdtOfficerListCache then
        mdtOfficerListCache.at = 0
        mdtOfficerListCache.grouped = nil
        mdtOfficerListCache.count = 0
    end
    local xPlayer = ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) or nil
    if xPlayer then
        xPlayer.__mdtUserRow = nil
        xPlayer.__mdtDbJob = nil
    end
end)

local function getRoleNameCandidates(xPlayer)
    local job = getJob(xPlayer)
    local roleMap = {[0]='Elev',[1]='Betjent',[2]='Assistent',[3]='Assistent 1. Grad',[4]='Kommissær',[5]='NSK Chef',[6]='Inspektør',[7]='Rigspolitiet'}
    local candidates, seen = {}, {}
    local function add(v)
        v = trim(v)
        if v ~= '' and not seen[v:lower()] then seen[v:lower()] = true; candidates[#candidates+1] = v end
    end
    if job then
        local grade = tonumber(job.grade or job.grade_number or job.job_grade or 0) or 0
        add(job.grade_name); add(job.grade_label); add(job.name_grade); add(job.label); add(roleMap[grade])
    end
    local ident = getIdentifier(xPlayer)
    if ident ~= '' then
        local meta = MySQL.single.await('SELECT division FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { ident })
        if meta then
            local div = trim(meta.division or '')
            local divLower = div:lower()
            if div ~= '' and KNOWN_MDT_ROLE_NAMES[divLower] then add(div) end
            if divLower == 'nsk' then add('NSK Afdeling') end
        end
    end
    return candidates
end

-- Impound-release permissions are intentionally strict. Only these two unlock permissions grant release.
local function permissionAliases(permission)
    local p = tostring(permission or '')
    if p == 'vehicles.impound.locked.release' then return { 'vehicles.impound.locked.release' } end
    if p == 'vehicles.impound.permanent.release' then return { 'vehicles.impound.permanent.release' } end
    return { p }
end

local function collectRolePermissionsForPlayer(xPlayer)
    local roleNames = getRoleNameCandidates(xPlayer)
    local merged, seen, debugRoles = {}, {}, {}
    for _, roleName in ipairs(roleNames) do
        local row = MySQL.single.await('SELECT permissions FROM mdt_roles WHERE LOWER(name) = LOWER(?) LIMIT 1', { roleName })
        local perms = {}
        if row and row.permissions then perms = normalizePermissions(row.permissions) end
        debugRoles[#debugRoles+1] = { name = roleName, found = row ~= nil, permissions = perms }
        for _, perm in ipairs(perms) do
            if not seen[perm] then seen[perm] = true; merged[#merged+1] = perm end
        end
    end
    return merged, debugRoles, roleNames
end



local function collectEmployeePermissions(identifier)
    identifier = trim(identifier or '')
    if identifier == '' then return {} end
    local rows = MySQL.query.await('SELECT permission FROM mdt_employee_permissions WHERE identifier = ?', { identifier }) or {}
    local out = {}
    for i=1,#rows do
        local perm = trim(rows[i].permission or '')
        if perm ~= '' then out[#out+1] = perm end
    end
    return out
end

local function collectPermissionsForPlayer(xPlayer)
    local rolePerms, debugRoles, roleNames = collectRolePermissionsForPlayer(xPlayer)
    local merged, seen = {}, {}
    for _, perm in ipairs(rolePerms or {}) do
        if not seen[perm] then seen[perm] = true; merged[#merged+1] = perm end
    end
    local identifier = getIdentifier(xPlayer)
    local employeePerms = collectEmployeePermissions(identifier)
    for _, perm in ipairs(employeePerms or {}) do
        if not seen[perm] then seen[perm] = true; merged[#merged+1] = perm end
    end
    return merged, debugRoles, roleNames, employeePerms
end

local function getCachedPermissionsForPlayer(xPlayer)
    local identifier = getIdentifier(xPlayer)
    local cacheKey = identifier ~= '' and identifier or ('src:' .. tostring(xPlayer and xPlayer.source or '?'))
    local cached = permissionCache[cacheKey]
    if cached then return cached.merged, cached.debugRoles, cached.roleNames, cached.employeePerms end
    local merged, debugRoles, roleNames, employeePerms = collectPermissionsForPlayer(xPlayer)
    permissionCache[cacheKey] = {
        merged = merged,
        debugRoles = debugRoles,
        roleNames = roleNames,
        employeePerms = employeePerms,
    }
    return merged, debugRoles, roleNames, employeePerms
end

local function playerPermissionSet(xPlayer)
    local perms = getCachedPermissionsForPlayer(xPlayer)
    local set = {}
    for _, p in ipairs(perms or {}) do set[p] = true end
    return set
end

local function playerHasPermissionKey(xPlayer, permission)
    local set = playerPermissionSet(xPlayer)
    for _, alias in ipairs(permissionAliases(permission)) do
        if set[alias] then return true end
    end
    return false
end

local function roleHasPermission(xPlayer, permission)
    local job = getJob(xPlayer)
    if not job or not job.name then return false end
    local isPolice = job.name == Config.PoliceJob or job.name == 'police' or job.name == 'politi' or job.name == 'lspd' or job.name == 'sheriff'
    if not isPolice then return false end

    local grade = tonumber(job.grade or job.grade_number or job.job_grade or 0) or 0
    local gradeName = tostring(job.grade_name or job.name_grade or job.grade_label or ''):lower()
    -- Rigspolitiet can always manage roles, but impound unlock still goes through explicit permission cards.
    if (permission == 'admin.roles' or permission == 'admin.roles.manage') and (grade >= 7 or gradeName == 'rigspolitiet' or gradeName == 'boss') then
        return true
    end

    local ok, allowed = pcall(function()
        return playerHasPermissionKey(xPlayer, permission)
    end)
    if not ok then
        print(('[san_mdt][PERM] permission check failed for %s: %s'):format(tostring(permission), tostring(allowed)))
        return false
    end
    return allowed == true
end

local function canReturnLockedImpound(xPlayer)
    return roleHasPermission(xPlayer, Config.VehicleImpoundReleaseLockedPermission or 'vehicles.impound.locked.release')
end

local function canReturnPermanentImpound(xPlayer)
    return roleHasPermission(xPlayer, Config.VehicleImpoundReleasePermanentPermission or 'vehicles.impound.permanent.release')
end

local function canReturnPermanent(xPlayer)
    -- Legacy helper: true if player can release either locked normal impound or permanent police storage.
    return canReturnLockedImpound(xPlayer) or canReturnPermanentImpound(xPlayer)
end

local function playerHasNskRole(xPlayer)
    for _, name in ipairs(getRoleNameCandidates(xPlayer)) do
        local lower = trim(name):lower()
        for _, auto in ipairs(Config.NskAutoRoles or { 'NSK Chef', 'NSK Afdeling' }) do
            if lower == trim(auto):lower() then return true end
        end
    end
    local ident = getIdentifier(xPlayer)
    if ident ~= '' then
        local meta = MySQL.single.await('SELECT division FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { ident })
        local div = trim(meta and meta.division or ''):lower()
        for _, d in ipairs(Config.NskAutoDivisions or { 'NSK' }) do
            if div == trim(d):lower() then return true end
        end
    end
    return false
end

local function canAccessNsk(xPlayer)
    if not xPlayer or not hasJobAccess(xPlayer) then return false end
    if roleHasPermission(xPlayer, Config.NskViewPermission or 'nsk.view') then return true end
    if roleHasPermission(xPlayer, Config.NskManagePermission or 'nsk.manage') then return true end
    return playerHasNskRole(xPlayer)
end

local function canManageNsk(xPlayer)
    if not canAccessNsk(xPlayer) then return false end
    if roleHasPermission(xPlayer, Config.NskManagePermission or 'nsk.manage') then return true end
    for _, name in ipairs(getRoleNameCandidates(xPlayer)) do
        local lower = trim(name):lower()
        if lower == 'nsk chef' or lower == 'nsk afdeling' then return true end
    end
    local ident = getIdentifier(xPlayer)
    if ident ~= '' then
        local meta = MySQL.single.await('SELECT division FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { ident })
        if trim(meta and meta.division or ''):lower() == 'nsk' then return true end
    end
    return false
end

local function canViewProfileGang(xPlayer)
    if not xPlayer or not hasJobAccess(xPlayer) then return false end
    if canAccessNsk(xPlayer) then return true end
    return roleHasPermission(xPlayer, Config.NskGangViewPermission or 'profiles.gang.view')
end

local function canRegisterProfileGang(xPlayer)
    return canManageNsk(xPlayer) or roleHasPermission(xPlayer, 'profiles.gang.register')
end

local function getPermissionCatalog()
    return {
        { key='vehicles.impound.locked.release', label='Frigiv lÃ¥st impound', category='KÃ¸retÃ¸jspermissions', description='Giver adgang til at frigive normal impound med lÃ¥s.' },
        { key='vehicles.impound.permanent.release', label='Frigiv politiopbevaring', category='KÃ¸retÃ¸jspermissions', description='Giver adgang til at frigive permanent impound / politiopbevaring.' },
        { key='vehicles.view', label='Se kÃ¸retÃ¸jer', category='KÃ¸retÃ¸jspermissions', description='Kan sÃ¸ge og Ã¥bne kÃ¸retÃ¸jsregister.' },
        { key='vehicles.manage', label='Administrer kÃ¸retÃ¸jer', category='KÃ¸retÃ¸jspermissions', description='Kan administrere kÃ¸retÃ¸jsdata i MDT.' },
        { key='incidents.create', label='Opret hÃ¦ndelser', category='HÃ¦ndelser', description='Kan oprette hÃ¦ndelser.' },
        { key='incidents.edit', label='Rediger hÃ¦ndelser', category='HÃ¦ndelser', description='Kan redigere hÃ¦ndelser.' },
        { key='incidents.delete', label='Slet hÃ¦ndelser', category='HÃ¦ndelser', description='Kan slette hÃ¦ndelser.' },
        { key='incidents.issue_fine', label='Udsted bÃ¸der', category='HÃ¦ndelser', description='Kan udstede bÃ¸der/fakturaer fra hÃ¦ndelser.' },
        { key='profiles.licenses.manage', label='Administrer licenser', category='Profiler', description='Kan tilfÃ¸je/fjerne kÃ¸rekort og andre licenser i MDT.' },
        { key='charges.add', label='TilfÃ¸j sigtelser', category='Sigtelser', description='Kan oprette sigtelser.' },
        { key='charges.edit', label='Rediger sigtelser', category='Sigtelser', description='Kan redigere sigtelser.' },
        { key='charges.delete', label='Slet sigtelser', category='Sigtelser', description='Kan slette sigtelser.' },
        { key='evidence.locker', label='Evidence locker', category='Beviser', description='Kan Ã¥bne evidence locker.' },
        { key='employees.hire', label='AnsÃ¦t', category='Ansatte', description='Kan ansÃ¦tte medarbejdere.' },
        { key='employees.fire', label='Afsked', category='Ansatte', description='Kan afskedige medarbejdere.' },
        { key='employees.rank', label='Rang/rolle', category='Ansatte', description='Kan Ã¦ndre ansattes rang.' },
        { key='administration.view', label='Se Administration', category='Administration', description='Kan Ã¥bne Administration dropdown i MDT.' },
        { key='admin.roles.manage', label='Administrer permissions', category='Administration', description='Kun Rigspolitiet bÃ¸r have denne. Giver adgang til at Ã¦ndre rolle-permissions.' },
        { key='admin.logs.view', label='Se MDT-Logs', category='Administration', description='Kan se alle centrale MDT audit logs.' },
        { key='mail.send', label='Send mail', category='Administration', description='Kan sende MDT-mail.' },
        { key='mdt.view', label='Ã…bn MDT', category='Basis', description='Basisadgang til MDT.' },
        { key='nsk.view', label='Se NSK', category='NSK', description='Kan Ã¥bne NSK-afdelingen og se bandeoverblik.' },
        { key='nsk.manage', label='Administrer NSK', category='NSK', description='Kan oprette bander, territorier og registrere medlemmer.' },
        { key='profiles.gang.view', label='Se bandemarkering', category='NSK', description='Kan se rÃ¸d bande-boks pÃ¥ profiler.' },
        { key='profiles.gang.register', label='Banderegistrering', category='NSK', description='Kan registrere/fjerne bandemedlemmer pÃ¥ profiler.' }
    }
end

local function buildPermissionDebug(xPlayer)
    local job = getJob(xPlayer) or {}
    local perms, roleDebug, candidates, employeePerms = {}, {}, {}, {}
    local ok, err = pcall(function()
        perms, roleDebug, candidates, employeePerms = getCachedPermissionsForPlayer(xPlayer)
    end)
    local permSet = playerPermissionSet(xPlayer)
    local grade = tonumber(job.grade or job.grade_number or job.job_grade or 0) or 0
    local gradeName = tostring(job.grade_name or job.name_grade or job.grade_label or ''):lower()
    local isBoss = grade >= 7 or gradeName == 'rigspolitiet' or gradeName == 'boss'
    local isPolice = isPoliceJobName(job.name)
    local canDelete = isPolice and (grade >= (Config.DeleteIncidentMinGrade or 4) or permSet['incidents.delete'] == true)
    local checks = {
        lockedRelease = permSet['vehicles.impound.locked.release'] == true,
        permanentRelease = permSet['vehicles.impound.permanent.release'] == true,
        administrationView = isBoss or permSet['administration.view'] == true or permSet['admin.roles.manage'] == true or permSet['admin.roles'] == true,
        rolesManage = isBoss or permSet['admin.roles.manage'] == true or permSet['admin.roles'] == true,
        nskView = canAccessNsk(xPlayer),
        nskManage = canManageNsk(xPlayer),
        gangView = canViewProfileGang(xPlayer),
        deleteIncident = canDelete,
        editLockedIncident = canDelete or permSet['incidents.edit'] == true,
        employeeAdmin = isPolice and (isBoss or permSet['administration.view'] == true or permSet['admin.roles.manage'] == true),
        evidenceLocker = permSet['evidence.locker'] == true or (isPolice and (grade >= (Config.EvidenceLockerMinGrade or 7) or isBoss)),
        chargesAdd = isBoss or permSet['charges.add'] == true,
        chargesEdit = isBoss or permSet['charges.edit'] == true,
        chargesDelete = isBoss or permSet['charges.delete'] == true,
    }
    local division = 'Patrulje'
    local ident = getIdentifier(xPlayer)
    if ident ~= '' then
        local meta = MySQL.single.await('SELECT division FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { ident })
        if meta and meta.division and trim(meta.division) ~= '' then division = trim(meta.division) end
    end
    return {
        ok = ok,
        error = ok and nil or tostring(err),
        job = job,
        candidates = candidates,
        roles = roleDebug,
        permissions = perms,
        employeePermissions = employeePerms,
        division = division,
        checks = checks,
        catalog = getPermissionCatalog()
    }
end

local function canDeleteIncident(xPlayer)
    local job = getJob(xPlayer)
    if not job or not job.name or not isPoliceJobName(job.name) then return false end
    local grade = tonumber(job.grade or job.grade_number or job.job_grade or 0) or 0
    if grade >= (Config.DeleteIncidentMinGrade or 4) then return true end
    return roleHasPermission(xPlayer, 'incidents.delete')
end

local function canEditLockedIncident(xPlayer)
    return canDeleteIncident(xPlayer) or roleHasPermission(xPlayer, 'incidents.edit')
end

local POLICE_FINE_JOBS = { police = true, politi = true, lspd = true, sheriff = true }

local function isPoliceFineJob(xPlayer)
    local job = getJob(xPlayer) or {}
    local name = tostring(job.name or ''):lower()
    if POLICE_FINE_JOBS[name] then return true end
    return name == tostring(Config.PoliceJob or 'police'):lower()
end

local function canIssueIncidentFine(xPlayer)
    if not xPlayer or not isPoliceFineJob(xPlayer) then return false end
    if roleHasPermission(xPlayer, 'incidents.issue_fine') then return true end
    return roleHasPermission(xPlayer, 'incidents.edit') or hasJobAccess(xPlayer)
end

local function canManageProfileLicenses(xPlayer)
    if not xPlayer or not isPoliceFineJob(xPlayer) then return false end
    if roleHasPermission(xPlayer, Config.LicenseManagePermission or 'profiles.licenses.manage') then return true end
    return roleHasPermission(xPlayer, 'incidents.edit')
end

local function getMdtLicenseCatalog()
    if type(Config.MDTLicenseTypes) == 'table' and #Config.MDTLicenseTypes > 0 then
        return Config.MDTLicenseTypes
    end
    return {
        { type = 'drive', label = 'Personbil (B)', category = 'B' },
        { type = 'drive_bike', label = 'Motorcykel (A)', category = 'A' },
        { type = 'drive_truck', label = 'StÃ¸rre kÃ¸retÃ¸j (C)', category = 'C' },
    }
end

local function getUserLicenseRows(identifier)
    identifier = trim(identifier)
    if identifier == '' then return {} end
    local hide = Config.MDTHideLicenseTypes or { dmv = true }
    local rows = MySQL.query.await([[
        SELECT ul.type, COALESCE(l.label, ul.type) AS label
        FROM user_licenses ul
        LEFT JOIN licenses l ON l.type = ul.type
        WHERE ul.owner = ?
        ORDER BY ul.type ASC
    ]], { identifier }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        if hide[tostring(row.type or '')] ~= true then
            out[#out + 1] = row
        end
    end
    return out
end

local function chargeRevocationActive(rev)
    rev = trim(rev):lower()
    if rev == '' then return false end
    for _, skip in ipairs({ 'ingen', 'nej', 'no', 'none', '0', 'false', 'n/a', 'na' }) do
        if rev == skip then return false end
    end
    return true
end

local function ensureLicenseHistoryTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_license_history (
        id INT NOT NULL AUTO_INCREMENT,
        identifier VARCHAR(80) NOT NULL,
        event_type VARCHAR(24) NOT NULL DEFAULT 'points',
        points_delta INT NOT NULL DEFAULT 0,
        points_after INT NOT NULL DEFAULT 0,
        incident_id INT NULL,
        incident_no VARCHAR(32) NULL,
        charge_paragraph VARCHAR(32) NULL,
        charge_name VARCHAR(160) NULL,
        reason VARCHAR(255) NULL,
        licenses_removed VARCHAR(255) NULL,
        officer_name VARCHAR(80) NULL,
        officer_identifier VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY identifier_idx (identifier),
        KEY incident_idx (incident_id),
        KEY created_at_idx (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
end

CreateThread(function()
    Wait(2400)
    pcall(ensureLicenseHistoryTable)
    pcall(ensureLicenseProfileColumns)
end)

local function getLicenseRevocationCooldownHours()
    return math.max(0, tonumber(Config.LicenseRevocationCooldownHours or 48) or 48)
end

local function ensureLicenseProfileColumns()
    local cols = {}
    local rows = MySQL.query.await('SHOW COLUMNS FROM mdt_civilian_profiles', {}) or {}
    for i = 1, #rows do cols[rows[i].Field] = true end
    if not cols.license_revoked_at then
        MySQL.query.await('ALTER TABLE mdt_civilian_profiles ADD COLUMN license_revoked_at TIMESTAMP NULL DEFAULT NULL', {})
    end
end

local function parseDbTimestamp(value)
    local raw = tostring(value or '')
    local y, m, d, H, M, S = raw:match('(%d+)-(%d+)-(%d+)%s+(%d+):(%d+):(%d+)')
    if not y then return nil end
    return os.time({
        year = tonumber(y), month = tonumber(m), day = tonumber(d),
        hour = tonumber(H), min = tonumber(M), sec = tonumber(S)
    })
end

local function getLicenseRestoreInfo(identifier)
    ensureLicenseProfileColumns()
    identifier = normalizePersonIdentifier(identifier)
    local hours = getLicenseRevocationCooldownHours()
    if identifier == '' then
        return { revoked = false, can_restore = true, hours = hours, remaining_seconds = 0 }
    end
    local row = MySQL.single.await(
        'SELECT license_revoked, license_revoked_at, license_points FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1',
        { identifier }
    ) or {}
    local revoked = tonumber(row.license_revoked or 0) == 1
    local points = math.max(0, tonumber(row.license_points or 0) or 0)
    local revokedAt = row.license_revoked_at
    local canRestore = true
    local remainingSec = 0
    local eligibleAt = nil
    if revoked and hours > 0 and revokedAt then
        local revokedUnix = parseDbTimestamp(revokedAt)
        if revokedUnix then
            eligibleAt = os.date('%Y-%m-%d %H:%M:%S', revokedUnix + (hours * 3600))
            remainingSec = math.max(0, (revokedUnix + (hours * 3600)) - os.time())
            canRestore = remainingSec <= 0
        end
    end
    return {
        revoked = revoked,
        can_restore = canRestore,
        hours = hours,
        revoked_at = revokedAt,
        eligible_at = eligibleAt,
        remaining_seconds = remainingSec,
        license_points = points,
    }
end

local function resetLicenseClipsOnRestore(identifier, licenseType, officerName, officerIdent)
    ensureLicenseProfileColumns()
    ensureLicenseHistoryTable()
    identifier = normalizePersonIdentifier(identifier)
    if identifier == '' then return end
    MySQL.insert.await([[
        INSERT INTO mdt_civilian_profiles (identifier, license_points, license_revoked, license_revocation_note, license_revoked_at)
        VALUES (?, 0, 0, '', NULL)
        ON DUPLICATE KEY UPDATE
            license_points = 0,
            license_revoked = 0,
            license_revocation_note = '',
            license_revoked_at = NULL
    ]], { identifier })
    MySQL.insert.await([[
        INSERT INTO mdt_license_history
        (identifier, event_type, points_delta, points_after, reason, officer_name, officer_identifier)
        VALUES (?, 'license_restored', 0, 0, ?, ?, ?)
    ]], {
        identifier,
        ('KÃ¸rekort genudstedt (%s). Aktive klip nulstillet.'):format(trim(licenseType or 'drive')),
        trim(officerName or ''),
        trim(officerIdent or ''),
    })
end

local function getLicenseHistory(identifier, limit)
    identifier = trim(identifier)
    if identifier == '' then return {} end
    ensureLicenseHistoryTable()
    limit = tonumber(limit) or 50
    return MySQL.query.await([[
        SELECT id, event_type, points_delta, points_after, incident_id, incident_no,
               charge_paragraph, charge_name, reason, licenses_removed, officer_name, created_at
        FROM mdt_license_history
        WHERE identifier = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], { identifier, limit }) or {}
end

local function getLicenseRevokeTypes()
    if type(Config.LicenseRevokeTypes) == 'table' and #Config.LicenseRevokeTypes > 0 then
        return Config.LicenseRevokeTypes
    end
    return { 'drive', 'drive_bike', 'drive_truck' }
end

local function isLicenseRevokeType(licenseType)
    licenseType = trim(licenseType)
    for _, ltype in ipairs(getLicenseRevokeTypes()) do
        if licenseType == trim(ltype) then return true end
    end
    return false
end

local function removeUserLicenseTypes(identifier, types)
    identifier = trim(identifier)
    if identifier == '' or type(types) ~= 'table' then return {} end
    local removed = {}
    for _, ltype in ipairs(types) do
        ltype = trim(ltype)
        if ltype ~= '' then
            local n = MySQL.update.await('DELETE FROM user_licenses WHERE owner = ? AND type = ?', { identifier, ltype })
            if (tonumber(n) or 0) > 0 then removed[#removed + 1] = ltype end
        end
    end
    return removed
end

local function buildPersonLicenseSanctionPlan(criminal)
    local penalties = calcPersonPenalties(criminal)
    local charges = getPersonMdtCharges(criminal)
    local details, revocationNotes = {}, {}
    local hasRevocation = false

    for _, ch in ipairs(charges) do
        local n = math.max(1, tonumber(ch.count) or 1)
        local pts = math.max(0, (tonumber(ch.points) or 0) * n)
        local rev = tostring(ch.revocation or '')
        local revActive = chargeRevocationActive(rev)
        if pts > 0 or revActive then
            details[#details + 1] = {
                paragraph = trim(ch.paragraph or ''),
                name = trim(ch.name or ''),
                points = pts,
                revocation = revActive and rev or '',
            }
        end
        if revActive then
            hasRevocation = true
            revocationNotes[#revocationNotes + 1] = rev
        end
    end

    return {
        points = math.max(0, penalties.points),
        hasRevocation = hasRevocation,
        revocationNotes = revocationNotes,
        charges = details,
        applicable = penalties.points > 0 or hasRevocation,
    }
end

local function licenseSanctionAlreadyApplied(incidentId, identifier)
    ensureLicenseHistoryTable()
    local id = tonumber(incidentId)
    local ident = normalizePersonIdentifier(identifier)
    if not id or ident == '' then return false end
    return MySQL.scalar.await(
        'SELECT 1 FROM mdt_license_history WHERE incident_id = ? AND identifier = ? LIMIT 1',
        { id, ident }
    ) ~= nil
end

local function getCurrentLicensePoints(identifier)
    identifier = normalizePersonIdentifier(identifier)
    if identifier == '' then return 0, false, '' end
    local civ = MySQL.single.await('SELECT license_points, license_revoked, license_revocation_note FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1', { identifier }) or {}
    return math.max(0, tonumber(civ.license_points or 0) or 0), tonumber(civ.license_revoked or 0) == 1, tostring(civ.license_revocation_note or '')
end

local function refreshPlayerLicenseItems(identifier)
    identifier = normalizePersonIdentifier(identifier)
    if identifier == '' then return end
    local xTarget = getPlayerByIdentifier(identifier)
    if not xTarget then return end
    local src = getPlayerSourceSafe(xTarget)
    if not src or src <= 0 then return end
    pcall(function()
        if GetResourceState('ya_idcard') == 'started' then
            exports['ya_idcard']:RefreshIdCard(src)
        end
    end)
end

local function applyIncidentLicenseSanctionInternal(source, incidentId, personIndex, xPlayer)
    ensureLicenseHistoryTable()
    local row = MySQL.single.await('SELECT id, incident_no, criminals FROM mdt_incidents WHERE id = ? LIMIT 1', { incidentId })
    if not row then return { ok = false, message = 'HÃ¦ndelsen findes ikke.' } end

    local criminals = decodeJson(row.criminals, {})
    local criminal = criminals[personIndex + 1]
    if type(criminal) ~= 'table' then
        return { ok = false, message = 'Personen findes ikke pÃ¥ hÃ¦ndelsen.' }
    end

    local identifier = normalizePersonIdentifier(criminal.identifier)
    if identifier == '' then
        return { ok = false, message = 'Personen mangler identifier. TilfÃ¸j via profil-sÃ¸gning.' }
    end

    if licenseSanctionAlreadyApplied(incidentId, identifier) then
        return { ok = false, message = 'KÃ¸rekortssanktion er allerede registreret for denne person pÃ¥ hÃ¦ndelsen.' }
    end

    local plan = buildPersonLicenseSanctionPlan(criminal)
    if not plan.applicable then
        return { ok = false, message = 'Ingen klip eller frakendelse i personens sigtelser.' }
    end

    local currentPoints, alreadyRevoked = getCurrentLicensePoints(identifier)
    local newPoints = math.min(currentPoints + plan.points, tonumber(Config.LicenseMaxActivePoints or 3) or 3)
    local maxPoints = tonumber(Config.LicenseMaxActivePoints or 3) or 3
    local willRevoke = plan.hasRevocation or (Config.LicenseAutoRevokeAtMaxPoints ~= false and newPoints >= maxPoints and plan.points > 0)
    local revokeReason = ''
    if plan.hasRevocation and #plan.revocationNotes > 0 then
        revokeReason = table.concat(plan.revocationNotes, ' Â· ')
    elseif willRevoke and plan.points > 0 then
        revokeReason = ('Automatisk frakendelse ved %d aktive klip'):format(newPoints)
    end

    local officerName = getOfficerName(xPlayer, source)
    local officerIdent = getMdtIdentifier(xPlayer)
    local incidentNo = trim(row.incident_no or '') ~= '' and trim(row.incident_no) or ('#' .. tostring(incidentId))
    local removedTypes = {}

    for _, ch in ipairs(plan.charges) do
        if ch.points > 0 then
            MySQL.insert.await([[
                INSERT INTO mdt_license_history
                (identifier, event_type, points_delta, points_after, incident_id, incident_no, charge_paragraph, charge_name, reason, officer_name, officer_identifier)
                VALUES (?, 'points', ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                identifier, ch.points, newPoints, incidentId, incidentNo, ch.paragraph, ch.name,
                ('%d klip for Â§ %s %s'):format(ch.points, ch.paragraph ~= '' and ch.paragraph or '?', ch.name ~= '' and ch.name or 'Sigtelse'),
                officerName, officerIdent
            })
        end
        if chargeRevocationActive(ch.revocation) then
            MySQL.insert.await([[
                INSERT INTO mdt_license_history
                (identifier, event_type, points_delta, points_after, incident_id, incident_no, charge_paragraph, charge_name, reason, officer_name, officer_identifier)
                VALUES (?, 'revocation', 0, ?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                identifier, newPoints, incidentId, incidentNo, ch.paragraph, ch.name, ch.revocation,
                officerName, officerIdent
            })
        end
    end

    if willRevoke then
        removedTypes = removeUserLicenseTypes(identifier, getLicenseRevokeTypes())
        if #removedTypes > 0 then
            MySQL.insert.await([[
                INSERT INTO mdt_license_history
                (identifier, event_type, points_delta, points_after, incident_id, incident_no, reason, licenses_removed, officer_name, officer_identifier)
                VALUES (?, 'license_removed', 0, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                identifier, newPoints, incidentId, incidentNo, revokeReason, table.concat(removedTypes, ', '),
                officerName, officerIdent
            })
        end
    end

    ensureLicenseProfileColumns()
    MySQL.insert.await([[
        INSERT INTO mdt_civilian_profiles (identifier, license_points, license_revoked, license_revocation_note, license_revoked_at)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            license_points = ?,
            license_revoked = GREATEST(license_revoked, ?),
            license_revocation_note = IF(? <> '', ?, license_revocation_note),
            license_revoked_at = IF(? = 1, NOW(), license_revoked_at)
    ]], {
        identifier, newPoints, willRevoke and 1 or 0, revokeReason, willRevoke and os.date('%Y-%m-%d %H:%M:%S') or nil,
        newPoints, willRevoke and 1 or 0, revokeReason, revokeReason,
        willRevoke and 1 or 0,
    })

    criminal.licenseSanction = {
        applied_at = os.date('%Y-%m-%d %H:%M:%S'),
        incident_id = incidentId,
        incident_no = incidentNo,
        points = plan.points,
        points_after = newPoints,
        revoked = willRevoke,
        reason = revokeReason,
        removed = removedTypes,
    }
    criminal.chargeFlags = type(criminal.chargeFlags) == 'table' and criminal.chargeFlags or {}
    criminal.chargeFlags.handled = true

    MySQL.update.await('UPDATE mdt_incidents SET criminals = ?, last_edited_by = ? WHERE id = ?', {
        json.encode(criminals), officerName, incidentId
    })

    refreshPlayerLicenseItems(identifier)

    if willRevoke then
        local cooldownHours = getLicenseRevocationCooldownHours()
        notifyPlayerByIdentifier(identifier, ('Dit kÃ¸rekort er frataget. Du kan tidligst fÃ¥ et nyt kÃ¸rekort igen efter %d timer.'):format(cooldownHours))
    end

    mdtAuditLog(source, 'Profiler', 'LICENSE_SANCTION_APPLIED', {
        target_type = 'profile',
        target_id = identifier,
        target_label = incidentNo,
        message = ('KÃ¸rekortssanktion: %d klip%s'):format(plan.points, willRevoke and ' + frakendelse' or ''),
        metadata = { incident_id = incidentId, points = plan.points, revoked = willRevoke, removed = removedTypes }
    })

    local cooldownHours = getLicenseRevocationCooldownHours()
    return {
        ok = true,
        message = willRevoke
            and ('KÃ¸rekortssanktion registreret. %d klip. KÃ¸rekort frataget. Borgeren kan fÃ¥ nyt kÃ¸rekort efter %d timer.'):format(plan.points, cooldownHours)
            or ('KÃ¸rekortssanktion registreret. %d klip tildelt.'):format(plan.points),
        sanction = criminal.licenseSanction,
        personIndex = personIndex,
        points_after = newPoints,
        revoked = willRevoke,
    }
end

local cachedUserColumns = nil
local function getUserColumns()
    if cachedUserColumns then return cachedUserColumns end
    local cols = {}
    local rows = MySQL.query.await("SHOW COLUMNS FROM users", {}) or {}
    for i = 1, #rows do cols[rows[i].Field] = true end
    cachedUserColumns = cols
    return cols
end

local function buildUserNameSelect(alias)
    alias = alias or 'u'
    local userCols = getUserColumns()
    local parts = {}
    if userCols['name'] then parts[#parts + 1] = alias .. '.name AS owner_name' end
    if userCols['firstname'] then parts[#parts + 1] = alias .. '.firstname AS firstname' end
    if userCols['lastname'] then parts[#parts + 1] = alias .. '.lastname AS lastname' end
    if userCols['first_name'] then parts[#parts + 1] = alias .. '.first_name AS first_name' end
    if userCols['last_name'] then parts[#parts + 1] = alias .. '.last_name AS last_name' end
    return table.concat(parts, ', ')
end

local function getUserName(row)
    if row.name and row.name ~= '' then return row.name end
    local first = row.firstname or row.first_name or ''
    local last = row.lastname or row.last_name or ''
    local full = trim((first .. ' ' .. last))
    if full ~= '' then return full end
    return row.identifier or 'Ukendt'
end

local function initials(name)
    local out = ''
    for part in tostring(name or ''):gmatch('%S+') do
        out = out .. part:sub(1,1):upper()
        if #out >= 2 then break end
    end
    return out ~= '' and out or '--'
end


local function newIncidentNumber()
    local letters = Config.IncidentPrefixLetters or 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local prefix = ''
    for i = 1, 3 do
        local n = math.random(1, #letters)
        prefix = prefix .. letters:sub(n, n)
    end
    return prefix .. tostring(math.random(100000, 999999))
end


local function mdtGetTableColumns(tableName)
    local cols = {}
    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName), {}) or {}
    end)
    if ok and rows then
        for i = 1, #rows do cols[rows[i].Field] = true end
    end
    return cols
end

local function ensureOwnedVehicleImpoundColumns()
    local cols = mdtGetTableColumns('owned_vehicles')
    local toAdd = {
        impound_price = 'INT NOT NULL DEFAULT 0',
        impound_type = "VARCHAR(32) NOT NULL DEFAULT 'normal'",
        impound_locked = 'TINYINT(1) NOT NULL DEFAULT 0',
        impound_reason = 'TEXT NULL',
        impound_officer = 'VARCHAR(128) NULL',
        impound_time = 'INT NULL'
    }
    for name, definition in pairs(toAdd) do
        if not cols[name] then
            pcall(function()
                MySQL.query.await(('ALTER TABLE `owned_vehicles` ADD COLUMN `%s` %s'):format(name, definition), {})
            end)
        end
    end
end


local PoliceGrades = {
    {grade = 0, name = 'elev', label = 'Elev', salary = 20},
    {grade = 1, name = 'betjent', label = 'Betjent', salary = 40},
    {grade = 2, name = 'assistent', label = 'Assistent', salary = 60},
    {grade = 3, name = 'assistent_1_grad', label = 'Assistent 1. Grad', salary = 80},
    {grade = 4, name = 'kommissaer', label = 'Kommissær', salary = 100},
    {grade = 5, name = 'nsk_chef', label = 'NSK Chef', salary = 120},
    {grade = 6, name = 'inspektoer', label = 'Inspektør', salary = 140},
    {grade = 7, name = 'rigspolitiet', label = 'Rigspolitiet', salary = 160}
}

local function ensurePoliceGrades()
    local jobName = Config.PoliceJob or 'police'
    pcall(function()
        local jobExists = MySQL.scalar.await('SELECT COUNT(*) FROM jobs WHERE name = ?', { jobName }) or 0
        if tonumber(jobExists) < 1 then
            MySQL.insert.await('INSERT INTO jobs (name, label) VALUES (?, ?)', { jobName, 'Politi' })
        end
    end)

    for _, g in ipairs(PoliceGrades) do
        pcall(function()
            local exists = MySQL.scalar.await('SELECT COUNT(*) FROM job_grades WHERE job_name = ? AND grade = ?', { jobName, g.grade }) or 0
            if tonumber(exists) > 0 then
                MySQL.update.await('UPDATE job_grades SET name = ?, label = ?, salary = ? WHERE job_name = ? AND grade = ?', { g.name, g.label, g.salary, jobName, g.grade })
            else
                MySQL.insert.await('INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, ?, ?, ?)', { jobName, g.grade, g.name, g.label, g.salary, '{}', '{}' })
            end
        end)
    end

    -- Newer ESX can refresh jobs without full server restart. If unavailable, a full restart after SQL still works.
    pcall(function()
        if ESX.RefreshJobs then ESX.RefreshJobs() end
    end)
end

local function getOnlinePlayerByIdentifier(identifier)
    identifier = trim(identifier)
    if identifier == '' then return nil end
    local players = ESX.GetExtendedPlayers and ESX.GetExtendedPlayers() or {}
    for _, xp in pairs(players) do
        local id = xp.identifier or (xp.getIdentifier and xp.getIdentifier()) or ''
        if id == identifier then return xp end
    end
    -- fallback for older ESX
    for _, sid in ipairs(GetPlayers()) do
        local xp = getPlayer(tonumber(sid))
        if xp then
            local id = xp.identifier or (xp.getIdentifier and xp.getIdentifier()) or ''
            if id == identifier then return xp end
        end
    end
    return nil
end

local function applyPoliceGrade(identifier, grade)
    identifier = trim(identifier)
    grade = tonumber(grade) or 0
    if grade < 0 then grade = 0 end
    if grade > 7 then grade = 7 end

    ensurePoliceGrades()

    local target = getOnlinePlayerByIdentifier(identifier)
    if target and target.setJob then
        local ok, err = pcall(function()
            target.setJob(Config.PoliceJob or 'police', grade)
        end)
        if ok then
            return true, true
        else
            print(('[san_mdt] target.setJob failed for %s grade %s: %s'):format(identifier, grade, tostring(err)))
        end
    end

    MySQL.update.await('UPDATE users SET job = ?, job_grade = ? WHERE identifier = ?', { Config.PoliceJob or 'police', grade, identifier })
    return true, false
end

local function getRolePermissions(roleName)
    roleName = trim(roleName)
    if roleName == '' then return {} end
    local row = MySQL.single.await('SELECT permissions FROM mdt_roles WHERE LOWER(name) = LOWER(?) LIMIT 1', { roleName })
    if not row or not row.permissions then return {} end
    return normalizePermissions(row.permissions)
end

local function safeLockerId(value)
    value = trim(value)
    value = value:gsub('[^%w%-_]', '_')
    if value == '' then value = tostring(os.time()) end
    return value
end

CreateThread(function()
    math.randomseed(os.time())
    ensureOwnedVehicleImpoundColumns()
    ensurePoliceGrades()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mdt_incidents (
            id INT NOT NULL AUTO_INCREMENT,
            incident_no VARCHAR(16) NOT NULL UNIQUE,
            title VARCHAR(255) DEFAULT '',
            description LONGTEXT DEFAULT NULL,
            status VARCHAR(64) DEFAULT 'Aktiv',
            location VARCHAR(255) DEFAULT '',
            objects LONGTEXT DEFAULT NULL,
            criminals LONGTEXT DEFAULT NULL,
            tags LONGTEXT DEFAULT NULL,
            evidence LONGTEXT DEFAULT NULL,
            officers LONGTEXT DEFAULT NULL,
            civilians LONGTEXT DEFAULT NULL,
            vehicles LONGTEXT DEFAULT NULL,
            references_json LONGTEXT DEFAULT NULL,
            created_by VARCHAR(128) DEFAULT '',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            locked TINYINT(1) DEFAULT 0,
            PRIMARY KEY (id),
            KEY incident_no_idx (incident_no),
            KEY created_at_idx (created_at)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])



    -- Migration for older san_mdt builds that created mdt_incidents with case_no instead of incident_no.
    -- CREATE TABLE IF NOT EXISTS does not alter existing tables, so we add missing columns safely here.
    local function hasColumn(columns, name)
        return columns[name] == true
    end

    local function reloadIncidentColumns()
        local cols = {}
        local rows = MySQL.query.await('SHOW COLUMNS FROM mdt_incidents', {}) or {}
        for i = 1, #rows do cols[rows[i].Field] = true end
        return cols
    end

    local cols = reloadIncidentColumns()

    if not hasColumn(cols, 'incident_no') then
        MySQL.query.await('ALTER TABLE mdt_incidents ADD COLUMN incident_no VARCHAR(16) NULL', {})
        cols = reloadIncidentColumns()
        if hasColumn(cols, 'case_no') then
            MySQL.update.await("UPDATE mdt_incidents SET incident_no = case_no WHERE (incident_no IS NULL OR incident_no = '') AND case_no IS NOT NULL AND case_no <> ''", {})
        end
        MySQL.update.await("UPDATE mdt_incidents SET incident_no = CONCAT('OLD', LPAD(id, 6, '0')) WHERE incident_no IS NULL OR incident_no = ''", {})
    end

    local missingIncidentColumns = {
        objects = 'LONGTEXT DEFAULT NULL',
        criminals = 'LONGTEXT DEFAULT NULL',
        references_json = 'LONGTEXT DEFAULT NULL',
        locked = 'TINYINT(1) DEFAULT 0',
        last_edited_by = "VARCHAR(128) DEFAULT ''",
        location = "VARCHAR(255) DEFAULT ''",
        created_by = "VARCHAR(128) DEFAULT ''",
        status = "VARCHAR(64) DEFAULT 'Aktiv'",
        description = 'LONGTEXT DEFAULT NULL',
        tags = 'LONGTEXT DEFAULT NULL',
        evidence = 'LONGTEXT DEFAULT NULL',
        officers = 'LONGTEXT DEFAULT NULL',
        civilians = 'LONGTEXT DEFAULT NULL',
        vehicles = 'LONGTEXT DEFAULT NULL'
    }

    cols = reloadIncidentColumns()
    for name, definition in pairs(missingIncidentColumns) do
        if not hasColumn(cols, name) then
            MySQL.query.await(('ALTER TABLE mdt_incidents ADD COLUMN %s %s'):format(name, definition), {})
        end
    end

    -- If older table has case_no as UNIQUE NOT NULL, keep it in sync to avoid Duplicate entry '' for key 'case_no'.
    cols = reloadIncidentColumns()
    if hasColumn(cols, 'case_no') then
        pcall(function()
            MySQL.update.await("UPDATE mdt_incidents SET case_no = incident_no WHERE (case_no IS NULL OR case_no = '') AND incident_no IS NOT NULL AND incident_no <> ''", {})
        end)
    end

    pcall(function()
        MySQL.query.await('ALTER TABLE mdt_incidents ADD INDEX incident_no_idx (incident_no)', {})
    end)

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mdt_news (
            id INT NOT NULL AUTO_INCREMENT,
            title VARCHAR(255) NOT NULL DEFAULT '',
            description TEXT NULL,
            important TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mdt_bolos (
            id INT NOT NULL AUTO_INCREMENT,
            title VARCHAR(255) NOT NULL DEFAULT '',
            description TEXT NULL,
            plate VARCHAR(32) DEFAULT '',
            active TINYINT(1) DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS mdt_warrants (
            id INT NOT NULL AUTO_INCREMENT,
            name VARCHAR(128) NOT NULL DEFAULT '',
            description TEXT NULL,
            active TINYINT(1) DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

end)



local cachedTableColumns = {}
local function getTableColumns(tableName)
    tableName = tostring(tableName or '')
    if tableName == '' then return {} end
    if cachedTableColumns[tableName] then return cachedTableColumns[tableName] end
    local cols = {}
    local ok, rows = pcall(function()
        return MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(tableName), {}) or {}
    end)
    if ok and rows then
        for i = 1, #rows do cols[rows[i].Field] = true end
    end
    cachedTableColumns[tableName] = cols
    return cols
end

local function ensureOwnedVehicleImpoundColumns_LateUnused()
    local cols = getTableColumns('owned_vehicles')
    local toAdd = {
        impound_price = 'INT NOT NULL DEFAULT 0',
        impound_type = "VARCHAR(32) NOT NULL DEFAULT 'normal'",
        impound_locked = 'TINYINT(1) NOT NULL DEFAULT 0',
        impound_reason = 'TEXT NULL',
        impound_officer = 'VARCHAR(128) NULL',
        impound_time = 'INT NULL'
    }
    for name, definition in pairs(toAdd) do
        if not cols[name] then
            pcall(function()
                MySQL.query.await(('ALTER TABLE `owned_vehicles` ADD COLUMN `%s` %s'):format(name, definition), {})
            end)
        end
    end
end



local function incidentRow(row)
    if not row then return nil end
    return {
        id = row.id,
        incident_no = row.incident_no,
        title = row.title or '',
        description = row.description or '',
        status = row.status or 'Aktiv',
        location = row.location or '',
        objects = decodeJson(row.objects, {}),
        criminals = decodeJson(row.criminals, {}),
        tags = decodeJson(row.tags, {}),
        evidence = decodeJson(row.evidence, {}),
        officers = decodeJson(row.officers, {}),
        civilians = decodeJson(row.civilians, {}),
        vehicles = decodeJson(row.vehicles, {}),
        references = decodeJson(row.references_json, {}),
        created_by = row.created_by or '',
        created_at = row.created_at,
        updated_at = row.updated_at,
        last_edited_by = row.last_edited_by or '',
        last_edited_at = row.updated_at,
        locked = tonumber(row.locked or 0) == 1
    }
end

-- === BÃ¸der / fakturaer fra hÃ¦ndelser (esx_billing) ===
local function ensureIncidentInvoicesTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_incident_invoices (
        id INT NOT NULL AUTO_INCREMENT,
        incident_id INT NOT NULL,
        incident_no VARCHAR(32) NOT NULL DEFAULT '',
        identifier VARCHAR(60) NOT NULL,
        billing_id INT NULL,
        amount INT NOT NULL DEFAULT 0,
        label VARCHAR(255) NOT NULL DEFAULT '',
        issued_by VARCHAR(80) NOT NULL DEFAULT '',
        issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY uniq_incident_person (incident_id, identifier),
        KEY incident_id_idx (incident_id),
        KEY identifier_idx (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
end

CreateThread(function()
    Wait(2200)
    pcall(ensureIncidentInvoicesTable)
end)

local function billingEntryExists(billingId)
    billingId = tonumber(billingId)
    if not billingId then return false end
    return MySQL.scalar.await('SELECT 1 FROM billing WHERE id = ? LIMIT 1', { billingId }) ~= nil
end

local function invoiceRowToMeta(row)
    if not row then return nil end
    local billingId = tonumber(row.billing_id)
    return {
        id = row.id,
        billing_id = billingId,
        amount = tonumber(row.amount) or 0,
        label = row.label or '',
        issued_by = row.issued_by or '',
        issued_at = row.issued_at,
        paid = billingId and not billingEntryExists(billingId) or false
    }
end

local function attachInvoicesToIncident(incident)
    if not incident or not incident.id then return incident end
    ensureIncidentInvoicesTable()
    local rows = MySQL.query.await(
        'SELECT id, incident_id, identifier, billing_id, amount, label, issued_by, issued_at FROM mdt_incident_invoices WHERE incident_id = ?',
        { tonumber(incident.id) }
    ) or {}
    local byIdent = {}
    for _, row in ipairs(rows) do
        byIdent[trim(row.identifier or '')] = invoiceRowToMeta(row)
    end
    for _, criminal in ipairs(incident.criminals or {}) do
        local ident = trim(criminal.identifier or '')
        if ident ~= '' and byIdent[ident] then
            criminal.invoice = byIdent[ident]
        end
    end
    return incident
end

local function enrichIncidentsWithInvoices(incidents)
    if type(incidents) ~= 'table' or #incidents == 0 then return incidents end
    ensureIncidentInvoicesTable()
    local ids, idSet = {}, {}
    for _, inc in ipairs(incidents) do
        local id = tonumber(inc and inc.id)
        if id and not idSet[id] then
            idSet[id] = true
            ids[#ids + 1] = id
        end
    end
    if #ids == 0 then return incidents end
    local placeholders = {}
    for i = 1, #ids do placeholders[i] = '?' end
    local rows = MySQL.query.await(
        ('SELECT id, incident_id, identifier, billing_id, amount, label, issued_by, issued_at FROM mdt_incident_invoices WHERE incident_id IN (%s)'):format(table.concat(placeholders, ',')),
        ids
    ) or {}
    local byIncident = {}
    for _, row in ipairs(rows) do
        local incId = tonumber(row.incident_id)
        if incId then
            byIncident[incId] = byIncident[incId] or {}
            byIncident[incId][trim(row.identifier or '')] = invoiceRowToMeta(row)
        end
    end
    for _, inc in ipairs(incidents) do
        local map = byIncident[tonumber(inc.id)]
        if map then
            for _, criminal in ipairs(inc.criminals or {}) do
                local ident = trim(criminal.identifier or '')
                if ident ~= '' and map[ident] then
                    criminal.invoice = map[ident]
                end
            end
        end
    end
    return incidents
end

local function mdtIssueSocietyBill(targetIdentifier, senderIdentifier, society, label, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return nil, 'BelÃ¸bet skal vÃ¦re over 0.' end
    society = trim(society or Config.FineSociety or 'society_police')
    if society == '' then society = 'society_police' end
    local billingId = MySQL.insert.await(
        'INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)',
        { targetIdentifier, senderIdentifier, 'society', society, label, amount }
    )
    notifyPlayerByIdentifier(targetIdentifier, 'Du har modtaget en bÃ¸de/faktura fra politiet.')
    return billingId, nil
end

ESX.RegisterServerCallback('san_mdt:issueIncidentFine', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canIssueIncidentFine(xPlayer) then
        return cb({ ok = false, message = 'Du har ikke tilladelse til at udstede bÃ¸der.' })
    end
    data = type(data) == 'table' and data or {}
    local incidentId = tonumber(data.incidentId or data.incident_id)
    local personIndex = tonumber(data.personIndex or data.person_index)
    if not incidentId or personIndex == nil then
        return cb({ ok = false, message = 'Manglende hÃ¦ndelse eller person.' })
    end

    local ok, resp = pcall(function()
        ensureIncidentInvoicesTable()
        local row = MySQL.single.await('SELECT id, incident_no, criminals FROM mdt_incidents WHERE id = ? LIMIT 1', { incidentId })
        if not row then return { ok = false, message = 'HÃ¦ndelsen findes ikke.' } end

        local criminals = decodeJson(row.criminals, {})
        local criminal = criminals[personIndex + 1]
        if type(criminal) ~= 'table' then
            return { ok = false, message = 'Personen findes ikke pÃ¥ hÃ¦ndelsen.' }
        end

        local identifier = trim(criminal.identifier or '')
        if identifier == '' and Config.FineRequireIdentifier ~= false then
            return { ok = false, message = 'Personen mangler identifier. TilfÃ¸j personen via profil-sÃ¸gning.' }
        end
        if identifier == '' then
            return { ok = false, message = 'Personen mangler identifier.' }
        end

        local existing = MySQL.single.await(
            'SELECT id FROM mdt_incident_invoices WHERE incident_id = ? AND identifier = ? LIMIT 1',
            { incidentId, identifier }
        )
        if existing then
            return { ok = false, message = 'Der er allerede udstedt en bÃ¸de til denne person pÃ¥ hÃ¦ndelsen.' }
        end

        local penalties = calcPersonPenalties(criminal)
        if penalties.fine <= 0 then
            return { ok = false, message = 'Der er ingen bÃ¸de at udstede (0 kr.).' }
        end

        local chargeCount = 0
        for _, ch in ipairs(getPersonMdtCharges(criminal)) do
            chargeCount = chargeCount + math.max(1, tonumber(ch.count) or 1)
        end

        local incidentNo = trim(row.incident_no or '') ~= '' and trim(row.incident_no) or ('#' .. tostring(incidentId))
        local personName = trim(criminal.name or '') ~= '' and trim(criminal.name) or 'Ukendt'
        local label = ('BÃ¸de â€” %s â€” %s (%d sigt.)'):format(incidentNo, personName, chargeCount)
        local officerIdent = getMdtIdentifier(xPlayer)
        local officerName = getOfficerName(xPlayer, source)

        local billingId, billErr = mdtIssueSocietyBill(identifier, officerIdent, Config.FineSociety, label, penalties.fine)
        if not billingId then
            return { ok = false, message = billErr or 'Kunne ikke oprette faktura.' }
        end

        local invoiceId = MySQL.insert.await(
            'INSERT INTO mdt_incident_invoices (incident_id, incident_no, identifier, billing_id, amount, label, issued_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { incidentId, incidentNo, identifier, billingId, penalties.fine, label, officerName }
        )

        criminal.invoice = {
            id = invoiceId,
            billing_id = billingId,
            amount = penalties.fine,
            label = label,
            issued_by = officerName,
            issued_at = os.date('%Y-%m-%d %H:%M:%S'),
            paid = false
        }
        criminal.chargeFlags = type(criminal.chargeFlags) == 'table' and criminal.chargeFlags or {}
        criminal.chargeFlags.handled = true

        MySQL.update.await('UPDATE mdt_incidents SET criminals = ?, last_edited_by = ? WHERE id = ?', {
            json.encode(criminals),
            officerName,
            incidentId
        })

        mdtAuditLog(source, 'HÃ¦ndelser', 'INCIDENT_FINE_ISSUED', {
            target_type = 'incident',
            target_id = tostring(incidentId),
            target_label = incidentNo,
            message = ('Udstedte bÃ¸de pÃ¥ %s kr. til %s'):format(penalties.fine, personName),
            metadata = { identifier = identifier, amount = penalties.fine, billing_id = billingId, person = personName }
        })

        return {
            ok = true,
            message = ('BÃ¸de pÃ¥ %s kr. sendt til %s.'):format(penalties.fine, personName),
            invoice = criminal.invoice,
            personIndex = personIndex
        }
    end)

    if ok then
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    else
        print(('[san_mdt] issueIncidentFine error: %s'):format(tostring(resp)))
        cb({ ok = false, message = 'Serverfejl ved udstedelse af bÃ¸de. Se server console.' })
    end
end)

-- COACHN V20: robust dashboard loader.
-- Tidligere kunne hele forsiden blive blank hvis Ã©n SQL tabel/kolonne manglede.
local function mdtSafeScalar(query, params, fallback)
    local ok, res = pcall(function() return MySQL.scalar.await(query, params or {}) end)
    if ok and res ~= nil then return res end
    print(('[san_mdt] dashboard scalar failed: %s'):format(tostring(query)))
    return fallback
end

local function mdtSafeQuery(query, params)
    local ok, res = pcall(function() return MySQL.query.await(query, params or {}) end)
    if ok and type(res) == 'table' then return res end
    print(('[san_mdt] dashboard query failed: %s'):format(tostring(query)))
    return {}
end

local function mdtEnsureCoreTables()
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_news` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `title` VARCHAR(255) NOT NULL DEFAULT '',
          `description` TEXT NULL,
          `important` TINYINT(1) DEFAULT 0,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_bolos` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `title` VARCHAR(255) NOT NULL DEFAULT '',
          `description` TEXT NULL,
          `plate` VARCHAR(32) DEFAULT '',
          `active` TINYINT(1) DEFAULT 1,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_warrants` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `name` VARCHAR(128) NOT NULL DEFAULT '',
          `description` TEXT NULL,
          `active` TINYINT(1) DEFAULT 1,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_mail` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `recipient` VARCHAR(128) NOT NULL DEFAULT '',
          `sender` VARCHAR(128) NOT NULL DEFAULT '',
          `subject` VARCHAR(255) NOT NULL DEFAULT '',
          `body` LONGTEXT NULL,
          `department` VARCHAR(128) NULL,
          `summary` VARCHAR(255) NULL,
          `recipient_type` VARCHAR(32) NOT NULL DEFAULT 'private',
          `seen_at` TIMESTAMP NULL DEFAULT NULL,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `recipient_idx` (`recipient`),
          KEY `recipient_type_idx` (`recipient_type`),
          KEY `created_at_idx` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_mail_reads` (
          `mail_id` INT NOT NULL,
          `identifier` VARCHAR(128) NOT NULL,
          `seen_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`mail_id`, `identifier`),
          INDEX `idx_identifier_seen` (`identifier`, `seen_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
end
CreateThread(function() Wait(2000); mdtEnsureCoreTables() end)

local mdtDashboardStatsCache = { at = 0, stats = nil }
local mdtOfficerListCache = { at = 0, grouped = nil, count = 0 }
local DASHBOARD_STATS_TTL = 15
local DASHBOARD_OFFICERS_TTL = 8
-- Forward refs: dashboard callbacks are registered above duty/admin helpers.
local isOfficerOnDuty
local canAdminEmployees

local MDT_BADGE_PREFIX_BY_DIVISION = {
    Patrulje = 'B', ['FÃ¦rdsel'] = 'F', ['Efterforskning'] = 'E', NSK = 'E', AKS = 'B', PET = 'E',
    ['Hundepatrulje'] = 'B', Helikopter = 'B', Civil = 'E', ['Intern Affairs'] = 'E', Ledelse = 'E',
}

local function policeBadgePrefix(division)
    division = tostring(division or ''):gsub('^%s*(.-)%s*$', '%1')
    if MDT_BADGE_PREFIX_BY_DIVISION[division] then return MDT_BADGE_PREFIX_BY_DIVISION[division] end
    local low = division:lower()
    if low:find('fÃ¦rd') or low:find('faerd') or low:find('trafik') then return 'F' end
    if low:find('efter') or low:find('nsk') or low:find('pet') or low:find('civil') or low:find('led') then return 'E' end
    return 'B'
end

local function normalizePnumberDigits(v)
    local raw = tostring(v or ''):gsub('^%s*(.-)%s*$', '%1')
    if raw == '' then return '' end
    raw = raw:gsub('^[A-Z]%-?', ''):gsub('^P%-?', '')
    local digits = raw:gsub('%D', ''):sub(-4)
    if digits == '' then return '' end
    return string.rep('0', math.max(0, 4 - #digits)) .. digits
end

local function parseStoredBadgePrefix(v)
    local raw = tostring(v or ''):gsub('^%s*(.-)%s*$', '%1'):upper()
    local prefix = raw:match('^([BFE])')
    if prefix then return prefix end
    return ''
end

local function normalizeBadgePrefix(v, division)
    local prefix = parseStoredBadgePrefix(v)
    if prefix ~= '' then return prefix end
    prefix = tostring(v or ''):upper():match('^([BFE])') or ''
    if prefix == 'B' or prefix == 'F' or prefix == 'E' then return prefix end
    return policeBadgePrefix(division)
end

local function buildPoliceBadge(prefix, digits, division)
    local d = normalizePnumberDigits(digits)
    if d == '' then return '' end
    return normalizeBadgePrefix(prefix, division) .. d
end

local function fleetFormatPNumber(v, division)
    local digits = normalizePnumberDigits(v)
    if digits == '' then return '' end
    local prefix = parseStoredBadgePrefix(v)
    if prefix == '' then prefix = policeBadgePrefix(division) end
    return prefix .. digits
end

local function getDashboardStatsCached()
    local now = os.clock()
    if mdtDashboardStatsCache.stats and (now - mdtDashboardStatsCache.at) < DASHBOARD_STATS_TTL then
        return mdtDashboardStatsCache.stats
    end
    local stats = {
        permanentVehicles = mdtSafeScalar("SELECT COUNT(*) FROM owned_vehicles WHERE COALESCE(impound_type, 'normal') = 'permanent'", {}, 0) or 0,
        lockedVehicles = mdtSafeScalar("SELECT COUNT(*) FROM owned_vehicles WHERE (COALESCE(impound_locked, 0) = 1 OR COALESCE(impound_type, 'normal') = 'locked') AND COALESCE(impound_type, 'normal') <> 'permanent'", {}, 0) or 0,
        incidents = mdtSafeScalar("SELECT COUNT(*) FROM mdt_incidents", {}, 0) or 0,
    }
    mdtDashboardStatsCache = { at = now, stats = stats }
    return stats
end

local DASHBOARD_ROLE_ORDER = {
    'Rigspolitiet', 'Inspektør', 'NSK Chef', 'NSK Afdeling', 'Kommissær',
    'Assistent 1. Grad', 'Assistent', 'Betjent', 'Elev', 'Receptionist', 'Rengøring', 'Suspenderet'
}

local function mdtEnsureAwardsTable()
    pcall(function()
        MySQL.query.await([[CREATE TABLE IF NOT EXISTS `mdt_employee_awards` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `identifier` VARCHAR(128) NOT NULL,
          `award_key` VARCHAR(64) NOT NULL DEFAULT 'brave',
          `award_label` VARCHAR(128) NOT NULL DEFAULT '',
          `note` TEXT NULL,
          `granted_by` VARCHAR(128) NULL,
          `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `identifier_idx` (`identifier`),
          KEY `award_key_idx` (`award_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    end)
end
CreateThread(function() Wait(2200); mdtEnsureAwardsTable() end)

local function dashboardEmployeeRole(jobGrade, gradeLabel, division)
    local n = tonumber(jobGrade or 0) or 0
    local map = {[0]='Elev',[1]='Betjent',[2]='Assistent',[3]='Assistent 1. Grad',[4]='Kommissær',[5]='NSK Chef',[6]='Inspektør',[7]='Rigspolitiet'}
    if trim(division or ''):lower() == 'nsk' and n <= 5 then return 'NSK Afdeling' end
    if map[n] then return map[n] end
    if gradeLabel and trim(gradeLabel) ~= '' then return trim(gradeLabel) end
    return 'Betjent'
end

local function getDashboardPoliceJobNames()
    local names, seen = {}, {}
    local function add(name)
        name = tostring(name or ''):lower()
        if name ~= '' and not seen[name] then seen[name] = true; names[#names + 1] = name end
    end
    add(Config.PoliceJob or 'police')
    add('police'); add('politi'); add('lspd'); add('sheriff')
    if type(Config.FleetPoliceJobs) == 'table' then
        for jobName, enabled in pairs(Config.FleetPoliceJobs) do
            if enabled then add(jobName) end
        end
    end
    return names
end

local function getDashboardOfficersGrouped()
    local now = os.clock()
    if mdtOfficerListCache.grouped and (now - mdtOfficerListCache.at) < DASHBOARD_OFFICERS_TTL then
        return mdtOfficerListCache.grouped, mdtOfficerListCache.count, mdtOfficerListCache.roleOrder or DASHBOARD_ROLE_ORDER
    end

    local onlineMap = {}
    local players = ESX.GetExtendedPlayers and ESX.GetExtendedPlayers() or {}
    for _, xp in pairs(players) do
        local j = getJob(xp)
        if j and isPoliceJobName(j.name) then
            local ident = getMdtIdentifier(xp)
            local src = getPlayerSourceSafe(xp)
            local hydrated = (src and src > 0) and getPlayer(src) or xp
            onlineMap[ident] = {
                online = true,
                onDuty = isOfficerOnDuty and isOfficerOnDuty(xp, src) or false,
                name = getOfficerName(hydrated, src),
                badge = mdtGetBadge(xp, src),
                grade = j.grade or 0
            }
        end
    end

    local cols = getUserColumns()
    local fields = { 'u.identifier', 'u.job', 'u.job_grade' }
    for _, c in ipairs({ 'firstname', 'lastname', 'first_name', 'last_name', 'name', 'phone_number', 'phone' }) do
        if cols[c] then fields[#fields + 1] = 'u.' .. c end
    end
    local selectFields = table.concat(fields, ', ') .. ', m.division AS mdt_division, m.pnumber AS mdt_pnumber, m.profile_image AS mdt_profile_image'
    local jobNames = getDashboardPoliceJobNames()
    local placeholders, jobParams = {}, {}
    for _, jobName in ipairs(jobNames) do
        placeholders[#placeholders + 1] = '?'
        jobParams[#jobParams + 1] = jobName
    end
    local rows = mdtSafeQuery(
        ('SELECT %s FROM users u LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier WHERE LOWER(u.job) IN (%s) ORDER BY u.job_grade DESC')
            :format(selectFields, table.concat(placeholders, ',')),
        jobParams
    )

    local grouped, officerCount, seenIdents = {}, 0, {}
    for _, r in ipairs(rows) do
        local ident = tostring(r.identifier or '')
        if ident == '' or seenIdents[ident] then goto continue end
        seenIdents[ident] = true
        local division = tostring(r.mdt_division or 'Patrulje')
        local role = dashboardEmployeeRole(r.job_grade, nil, division)
        local online = onlineMap[ident]
        grouped[role] = grouped[role] or {}
        officerCount = officerCount + 1
        local dbName = getUserName(r)
        local name = dbName
        if dbName == '' or dbName == 'Ukendt' or dbName == ident then
            name = (online and online.name) or dbName
        end
        grouped[role][#grouped[role] + 1] = {
            identifier = ident,
            name = name,
            initials = initials(name),
            role = role,
            division = division,
            pnumber = tostring(r.mdt_pnumber or r.job_grade or ''),
            badge = (online and online.badge) or fleetFormatPNumber(r.mdt_pnumber or r.job_grade, division),
            phone = tostring(r.phone_number or r.phone or ''),
            profile_image = tostring(r.mdt_profile_image or ''),
            online = online and true or false,
            onDuty = online and online.onDuty or false
        }
        ::continue::
    end

    -- Fallback: vis online betjente selv hvis de ikke findes i users-query endnu.
    for ident, online in pairs(onlineMap) do
        if not seenIdents[ident] then
            seenIdents[ident] = true
            local xp = getOnlinePlayerByIdentifier(ident)
            local job = xp and getJob(xp) or {}
            local division = 'Patrulje'
            if xp then
                local meta = MySQL.single.await('SELECT division, pnumber FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { ident })
                if meta and meta.division and tostring(meta.division) ~= '' then division = tostring(meta.division) end
            end
            local role = dashboardEmployeeRole(job.grade, job.grade_label or job.grade_name, division)
            grouped[role] = grouped[role] or {}
            officerCount = officerCount + 1
            grouped[role][#grouped[role] + 1] = {
                identifier = ident,
                name = online.name or 'Ukendt betjent',
                initials = initials(online.name or '??'),
                role = role,
                division = division,
                pnumber = tostring(online.grade or ''),
                badge = online.badge or fleetFormatPNumber(online.grade, division),
                phone = '',
                profile_image = '',
                online = true,
                onDuty = online.onDuty or false
            }
        end
    end

    for _, list in pairs(grouped) do
        table.sort(list, function(a, b) return tostring(a.name or '') < tostring(b.name or '') end)
    end

    mdtOfficerListCache = { at = now, grouped = grouped, count = officerCount, roleOrder = DASHBOARD_ROLE_ORDER }
    return grouped, officerCount, DASHBOARD_ROLE_ORDER
end

ESX.RegisterServerCallback('san_mdt:getDashboard', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ news = {}, bolos = {}, wanted = {}, officers = {}, officerCount = 0, stats = {} }) end

    local stats = getDashboardStatsCached()

    local news = mdtSafeQuery('SELECT id, title, description, important, created_at, 0 AS mail FROM mdt_news ORDER BY created_at DESC LIMIT 10', {})
    local viewerIdentifier = getMdtIdentifier(xPlayer)
    local mailNews = mdtSafeQuery([[
        SELECT m.id, m.subject, m.subject AS title, COALESCE(m.summary, m.body) AS description, m.body,
               m.department, m.sender, m.created_at, m.recipient_type, r.seen_at,
               CASE WHEN r.seen_at IS NULL THEN 1 ELSE 0 END AS unread,
               1 AS mail
        FROM mdt_mail m
        LEFT JOIN mdt_mail_reads r ON r.mail_id = m.id AND r.identifier = ?
        WHERE m.recipient_type = 'frontpage' OR m.recipient = 'frontpage' OR m.recipient_type = 'news'
        ORDER BY m.created_at DESC LIMIT 10
    ]], { viewerIdentifier })
    for _, m in ipairs(mailNews) do news[#news+1] = m end
    table.sort(news, function(a,b) return tostring(a.created_at or '') > tostring(b.created_at or '') end)
    while #news > 10 do table.remove(news) end

    local bolos = mdtSafeQuery('SELECT id, title, description, plate, created_at FROM mdt_bolos WHERE active = 1 ORDER BY created_at DESC LIMIT 10', {})
    local wanted = mdtSafeQuery('SELECT id, name, description, created_at FROM mdt_warrants WHERE active = 1 ORDER BY created_at DESC LIMIT 10', {})

    local grouped, officerCount, roleOrder = {}, 0, DASHBOARD_ROLE_ORDER
    local okOfficers, g, c, r = pcall(getDashboardOfficersGrouped)
    if okOfficers then
        grouped = g or {}
        officerCount = c or 0
        roleOrder = r or DASHBOARD_ROLE_ORDER
    else
        print(('[san_mdt] getDashboardOfficersGrouped failed: %s'):format(tostring(g)))
    end

    cb({
        ok = true,
        job = getJob(xPlayer),
        name = getOfficerName(xPlayer, source),
        stats = stats,
        permissions = { returnPermanent = canReturnPermanent(xPlayer), returnLocked = canReturnLockedImpound(xPlayer), returnPermanentImpound = canReturnPermanentImpound(xPlayer), deleteIncident = canDeleteIncident(xPlayer), debug = buildPermissionDebug(xPlayer) },
        news = news,
        bolos = bolos,
        wanted = wanted,
        officers = grouped,
        officerCount = officerCount,
        roleOrder = roleOrder or DASHBOARD_ROLE_ORDER,
        canSendMail = hasJobAccess(xPlayer),
        canSendNews = canAdminEmployees and canAdminEmployees(xPlayer) or false
    })
end)

ESX.RegisterServerCallback('san_mdt:getIncidents', function(source, cb, search)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, incidents = {} }) end
    search = trim(search)
    local rows
    if search ~= '' then
        mdtAuditLog(source, 'SÃ¸gninger', 'INCIDENT_SEARCH', { target_type='incident', target_label=search, message='SÃ¸gte i hÃ¦ndelser', metadata={ search=search } })
        local q = '%' .. search .. '%'
        rows = MySQL.query.await([[SELECT * FROM mdt_incidents
            WHERE incident_no LIKE ? OR title LIKE ? OR status LIKE ?
            ORDER BY created_at DESC LIMIT 50]], { q, q, q }) or {}
    else
        rows = MySQL.query.await('SELECT * FROM mdt_incidents ORDER BY created_at DESC LIMIT 25', {}) or {}
    end
    local out = {}
    for i = 1, #rows do out[#out + 1] = incidentRow(rows[i]) end
    enrichIncidentsWithInvoices(out)
    cb({ ok = true, incidents = out, canDelete = canDeleteIncident(xPlayer) })
end)

ESX.RegisterServerCallback('san_mdt:createIncident', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    local officer = getOfficerName(xPlayer, source)
    cb({
        ok = true,
        draft = true,
        incident = {
            id = nil,
            incident_no = 'KLADDE',
            title = 'Ny hÃ¦ndelse',
            description = '',
            status = 'Aktiv',
            location = '',
            objects = {}, criminals = {}, tags = {}, evidence = {}, officers = { { name = officer } }, civilians = {}, vehicles = {}, references = {},
            created_by = officer,
            created_at = nil,
            updated_at = nil,
            locked = false,
            draft = true
        }
    })
end)

ESX.RegisterServerCallback('san_mdt:saveIncident', function(source, cb, incident)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    if type(incident) ~= 'table' then return cb({ ok = false, message = 'Manglende hÃ¦ndelse.' }) end

    local locked = incident.locked and 1 or 0
    local title = trim(incident.title)
    if title == '' then title = 'Ny hÃ¦ndelse' end

    local function uniqueIncidentNo()
        local no, tries = newIncidentNumber(), 0
        while tries < 20 do
            local exists = MySQL.scalar.await('SELECT id FROM mdt_incidents WHERE incident_no = ?', { no })
            if not exists then return no end
            no = newIncidentNumber(); tries = tries + 1
        end
        return newIncidentNumber()
    end

    local ok, result = pcall(function()
        if incident.id then
            local existing = MySQL.single.await('SELECT locked, incident_no, title FROM mdt_incidents WHERE id = ?', { tonumber(incident.id) })
            if not existing then return { ok = false, message = 'HÃ¦ndelsen findes ikke.' } end
            if tonumber(existing.locked or 0) == 1 and not canEditLockedIncident(xPlayer) then
                return { ok = false, message = 'Rapporten er gemt/lÃ¥st og kan ikke redigeres.' }
            end
            MySQL.update.await([[UPDATE mdt_incidents SET
                title = ?, description = ?, status = ?, location = ?, objects = ?, criminals = ?, tags = ?, evidence = ?, officers = ?, civilians = ?, vehicles = ?, references_json = ?, locked = ?, last_edited_by = ?
                WHERE id = ?]], {
                title, tostring(incident.description or ''), trim(incident.status or 'Aktiv'), trim(incident.location),
                json.encode(incident.objects or {}), json.encode(incident.criminals or {}), json.encode(incident.tags or {}), json.encode(incident.evidence or {}),
                json.encode(incident.officers or {}), json.encode(incident.civilians or {}), json.encode(incident.vehicles or {}), json.encode(incident.references or {}),
                locked, getOfficerName(xPlayer, source), tonumber(incident.id)
            })
            local row = MySQL.single.await('SELECT * FROM mdt_incidents WHERE id = ?', { tonumber(incident.id) })
            mdtAuditLog(source, 'HÃ¦ndelser', 'INCIDENT_UPDATED', { target_type='incident', target_id=tostring(incident.id), target_label=(row and (row.incident_no or row.title)) or title, message='Redigerede hÃ¦ndelse', metadata={ title=title, locked=locked } })
            return { ok = true, message = 'HÃ¦ndelse gemt.', incident = attachInvoicesToIncident(incidentRow(row)), canDelete = canDeleteIncident(xPlayer) }
        else
            local no = uniqueIncidentNo()
            local officer = getOfficerName(xPlayer, source)
            local createdBy = trim(incident.created_by)
            if createdBy == '' then createdBy = officer end
            local cols = getTableColumns('mdt_incidents')
            local fields = { 'incident_no', 'title', 'description', 'status', 'location', 'objects', 'criminals', 'tags', 'evidence', 'officers', 'civilians', 'vehicles', 'references_json', 'created_by', 'last_edited_by', 'locked' }
            local values = {
                no, title, tostring(incident.description or ''), trim(incident.status or 'Aktiv'), trim(incident.location),
                json.encode(incident.objects or {}), json.encode(incident.criminals or {}), json.encode(incident.tags or {}), json.encode(incident.evidence or {}),
                json.encode(incident.officers or { { name = officer } }), json.encode(incident.civilians or {}), json.encode(incident.vehicles or {}), json.encode(incident.references or {}),
                createdBy, officer, locked
            }
            if cols.case_no then
                table.insert(fields, 2, 'case_no')
                table.insert(values, 2, no)
            end
            local placeholders = {}
            for i = 1, #fields do placeholders[#placeholders + 1] = '?' end
            local id = MySQL.insert.await(('INSERT INTO mdt_incidents (`%s`) VALUES (%s)'):format(table.concat(fields, '`, `'), table.concat(placeholders, ', ')), values)
            local row = MySQL.single.await('SELECT * FROM mdt_incidents WHERE id = ?', { id })
            mdtAuditLog(source, 'HÃ¦ndelser', 'INCIDENT_CREATED', { target_type='incident', target_id=tostring(id), target_label=(row and (row.incident_no or row.title)) or no, message='Oprettede hÃ¦ndelse', metadata={ title=title, locked=locked } })
            return { ok = true, message = 'HÃ¦ndelse gemt.', incident = attachInvoicesToIncident(incidentRow(row)), canDelete = canDeleteIncident(xPlayer) }
        end
    end)

    if ok then
        cb(result or { ok = false, message = 'Ukendt fejl.' })
        if result and result.ok and type(incident) == 'table' then
            -- ANPG styres udelukkende via MDT-rapporter (ikke hændelser).
        end
    else
        print(('[san_mdt] saveIncident error: %s'):format(result))
        cb({ ok = false, message = 'Databasefejl ved gem af hÃ¦ndelse. Se server console.' })
    end
end)

ESX.RegisterServerCallback('san_mdt:deleteIncident', function(source, cb, id)
    local xPlayer = getPlayer(source)
    if not canDeleteIncident(xPlayer) then return cb({ ok = false, message = 'Du har ikke tilladelse til at slette rapporter.' }) end
    id = tonumber(id)
    if not id then return cb({ ok = false, message = 'Manglende hÃ¦ndelses-id.' }) end

    local ok, resp = pcall(function()
        local row = MySQL.single.await('SELECT locked FROM mdt_incidents WHERE id = ?', { id })
        if not row then return { ok = false, message = 'HÃ¦ndelsen findes ikke.' } end
        if tonumber(row.locked or 0) == 1 then return { ok = false, message = 'Gemte/lÃ¥ste rapporter kan ikke slettes.' } end
        local oldIncidentForLog = MySQL.single.await('SELECT incident_no, title FROM mdt_incidents WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM mdt_incidents WHERE id = ?', { id })
    mdtAuditLog(source, 'HÃ¦ndelser', 'INCIDENT_DELETED', { target_type='incident', target_id=tostring(id), target_label=(oldIncidentForLog and (oldIncidentForLog.incident_no or oldIncidentForLog.title)) or tostring(id), message='Slettede hÃ¦ndelse' })
        return { ok = true, message = 'HÃ¦ndelse slettet.' }
    end)

    if ok then
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    else
        print(('[san_mdt] deleteIncident error: %s'):format(resp))
        cb({ ok = false, message = 'Databasefejl ved sletning. Se server console.' })
    end
end)


RegisterNetEvent('san_mdt:deleteIncidentEvent', function(id)
    local src = source
    local xPlayer = getPlayer(src)
    if not canDeleteIncident(xPlayer) then
        TriggerClientEvent('esx:showNotification', src, 'Du har ikke tilladelse til at slette rapporter.')
        return
    end

    id = tonumber(id)
    if not id then
        TriggerClientEvent('esx:showNotification', src, 'Manglende hÃ¦ndelses-id.')
        return
    end

    local ok, err = pcall(function()
        local row = MySQL.single.await('SELECT locked FROM mdt_incidents WHERE id = ?', { id })
        if not row then
            TriggerClientEvent('esx:showNotification', src, 'HÃ¦ndelsen findes ikke.')
            return
        end
        if tonumber(row.locked or 0) == 1 then
            TriggerClientEvent('esx:showNotification', src, 'Gemte/lÃ¥ste rapporter kan ikke slettes.')
            return
        end
        MySQL.update.await('DELETE FROM mdt_incidents WHERE id = ?', { id })
        TriggerClientEvent('esx:showNotification', src, 'HÃ¦ndelsen er slettet.')
    end)

    if not ok then
        print(('[san_mdt] deleteIncidentEvent error: %s'):format(err))
        TriggerClientEvent('esx:showNotification', src, 'Databasefejl ved sletning. Se server console.')
    end
end)

ESX.RegisterServerCallback('san_mdt:getProfiles', function(source, cb, search)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, profiles = {} }) end
    search = trim(search)
    if search == '' then return cb({ ok = true, profiles = {} }) end
    mdtAuditLog(source, 'SÃ¸gninger', 'PROFILE_SEARCH', { target_type='profile', target_label=search, message='SÃ¸gte i profiler', metadata={ search=search } })

    local cols = getUserColumns()
    local fields = { 'identifier' }
    for _, c in ipairs({ 'firstname', 'lastname', 'first_name', 'last_name', 'name', 'dateofbirth', 'dob', 'phone_number', 'phone', 'sex', 'job' }) do
        if cols[c] then fields[#fields + 1] = c end
    end

    local where = { 'identifier LIKE ?' }
    local params = { '%' .. search .. '%' }
    for _, c in ipairs({ 'firstname', 'lastname', 'first_name', 'last_name', 'name', 'phone_number', 'phone', 'dateofbirth', 'dob' }) do
        if cols[c] then where[#where + 1] = c .. ' LIKE ?'; params[#params + 1] = '%' .. search .. '%' end
    end

    local rows = MySQL.query.await(('SELECT %s FROM users WHERE %s LIMIT 30'):format(table.concat(fields, ', '), table.concat(where, ' OR ')), params) or {}
    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        local ident = trim(r.identifier or '')
        local item = {
            identifier = ident,
            name = getUserName(r),
            dob = r.dateofbirth or r.dob or '',
            phone = r.phone_number or r.phone or '',
            sex = r.sex or '',
            job = r.job or '',
            profile_image = '',
            gang = nil,
        }
        if ident ~= '' then
            local civ = MySQL.single.await('SELECT profile_image FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1', { ident })
            if civ and civ.profile_image then item.profile_image = tostring(civ.profile_image) end
            if canViewProfileGang(xPlayer) then
                item.gang = getProfileGangInfo(ident)
            end
        end
        out[#out + 1] = item
    end
    cb({ ok = true, profiles = out })
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_civilian_profiles (
        identifier VARCHAR(80) NOT NULL PRIMARY KEY,
        profile_image TEXT NULL,
        notes LONGTEXT NULL,
        license_points INT NOT NULL DEFAULT 0,
        license_revoked TINYINT NOT NULL DEFAULT 0,
        license_revocation_note VARCHAR(255) NULL,
        license_revoked_at TIMESTAMP NULL DEFAULT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
    pcall(ensureLicenseProfileColumns)
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_vehicle_profiles (
        plate VARCHAR(16) NOT NULL PRIMARY KEY,
        profile_image TEXT NULL,
        notes LONGTEXT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )]])
end)

local vehicleModelCache = {}

local function resolveVehicleModelName(model)
    if model == nil then return 'Ukendt model' end
    if type(model) == 'string' then
        local s = trim(model)
        if s ~= '' and not s:match('^%-?%d+$') then
            if #s > 1 then
                return (s:sub(1, 1):upper() .. s:sub(2):lower()):gsub('_', ' ')
            end
            return s
        end
    end
    local hash = tonumber(model)
    if not hash or hash == 0 then return tostring(model or 'Ukendt model') end
    if vehicleModelCache[hash] then return vehicleModelCache[hash] end
    local resolved = tostring(hash)
    local ok, name = pcall(function()
        if type(GetDisplayNameFromVehicleModel) ~= 'function' then return nil end
        local display = GetDisplayNameFromVehicleModel(hash)
        if not display or display == '' or display == 'CARNOTFOUND' then return nil end
        local label = GetLabelText(display)
        if label and label ~= '' and label ~= 'NULL' then return label end
        return display
    end)
    if ok and name and name ~= '' then resolved = name end
    vehicleModelCache[hash] = resolved
    return resolved
end

local function vehicleStatusFromRow(r)
    local status = 'Ude'
    if tonumber(r.stored or 0) == 1 then status = 'I garage' end
    if tonumber(r.stored or 0) == 2 or (r.pound and tostring(r.pound) ~= '') then status = 'Impound' end
    if tostring(r.impound_type or '') == 'permanent' then status = 'Permanent beslaglagt' end
    if tonumber(r.impound_locked or 0) == 1 or tostring(r.impound_type or '') == 'locked' then status = status .. ' / LÃ¥st' end
    return status
end

local function getLinkedReportsForPlate(plate)
    plate = trim(plate):upper()
    if plate == '' then return {} end
    local plateCompact = plate:gsub('%s+', '')
    local likePlate = '%' .. plate .. '%'
    local likeCompact = '%' .. plateCompact .. '%'
    local rows = MySQL.query.await([[
        SELECT id, incident_no, title, status, created_at, created_by
        FROM mdt_incidents
        WHERE UPPER(vehicles) LIKE ? OR REPLACE(UPPER(vehicles), ' ', '') LIKE ?
        ORDER BY id DESC
        LIMIT 15
    ]], { likePlate, likeCompact }) or {}
    local reports = {}
    for _, row in ipairs(rows) do
        reports[#reports + 1] = {
            id = row.incident_no or row.id,
            incident_no = row.incident_no,
            title = row.title or 'HÃ¦ndelse',
            status = row.status or 'Aktiv',
            date = row.created_at,
            officer = row.created_by or ''
        }
    end
    return reports
end

local function isPublicBill(row)
    local target = tostring(row.target or ''):lower()
    local sender = tostring(row.sender or ''):lower()
    local label = tostring(row.label or ''):lower()
    local ttype = tostring(row.target_type or ''):lower()
    if target:find('mechanic') or sender:find('mechanic') or label:find('mekanik') then return false end
    if ttype == 'society' or sender:find('police') or sender:find('society') or target:find('police') then return true end
    if label:find('bÃ¸de') or label:find('bode') or label:find('faktura') or label:find('advokat') then return true end
    return false
end

local function getUnpaidBills(identifier)
    local rows = MySQL.query.await('SELECT label, amount, sender, target, target_type FROM billing WHERE identifier = ? ORDER BY id DESC LIMIT 40', { identifier }) or {}
    local total, list = 0, {}
    for _, r in ipairs(rows) do
        if isPublicBill(r) then
            local amt = tonumber(r.amount) or 0
            total = total + amt
            list[#list + 1] = { label = r.label, amount = amt, sender = r.sender }
        end
    end
    return total, list
end

ESX.RegisterServerCallback('san_mdt:previewIncidentLicenseSanction', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageProfileLicenses(xPlayer) then
        return cb({ ok = false, message = 'Du har ikke tilladelse til kÃ¸rekortssanktioner.' })
    end
    data = type(data) == 'table' and data or {}
    local incidentId = tonumber(data.incidentId or data.incident_id)
    local personIndex = tonumber(data.personIndex or data.person_index)
    if not incidentId or personIndex == nil then
        return cb({ ok = false, message = 'Manglende hÃ¦ndelse eller person.' })
    end

    local row = MySQL.single.await('SELECT id, incident_no, criminals FROM mdt_incidents WHERE id = ? LIMIT 1', { incidentId })
    if not row then return cb({ ok = false, message = 'HÃ¦ndelsen findes ikke.' }) end

    local criminal = decodeJson(row.criminals, {})[personIndex + 1]
    if type(criminal) ~= 'table' then
        return cb({ ok = false, message = 'Personen findes ikke pÃ¥ hÃ¦ndelsen.' })
    end
    local identifier = normalizePersonIdentifier(criminal.identifier)
    if identifier == '' then
        return cb({ ok = false, message = 'Personen mangler identifier.' })
    end

    local plan = buildPersonLicenseSanctionPlan(criminal)
    if not plan.applicable then
        return cb({ ok = false, message = 'Ingen klip eller frakendelse i sigtelserne.' })
    end
    if licenseSanctionAlreadyApplied(incidentId, identifier) then
        return cb({ ok = false, message = 'KÃ¸rekortssanktion er allerede udfÃ¸rt pÃ¥ denne hÃ¦ndelse.' })
    end

    local currentPoints = getCurrentLicensePoints(identifier)
    local newPoints = math.min(currentPoints + plan.points, tonumber(Config.LicenseMaxActivePoints or 3) or 3)
    local maxPoints = tonumber(Config.LicenseMaxActivePoints or 3) or 3
    local willRevoke = plan.hasRevocation or (Config.LicenseAutoRevokeAtMaxPoints ~= false and newPoints >= maxPoints and plan.points > 0)

    local cooldownHours = getLicenseRevocationCooldownHours()
    cb({
        ok = true,
        preview = {
            person_name = trim(criminal.name or '') ~= '' and trim(criminal.name) or 'Ukendt',
            incident_no = trim(row.incident_no or '') ~= '' and trim(row.incident_no) or ('#' .. tostring(incidentId)),
            points = plan.points,
            current_points = currentPoints,
            new_points = newPoints,
            max_points = maxPoints,
            will_revoke = willRevoke,
            revocation_notes = plan.revocationNotes,
            charges = plan.charges,
            licenses_to_remove = willRevoke and getLicenseRevokeTypes() or {},
            cooldown_hours = cooldownHours,
        }
    })
end)

ESX.RegisterServerCallback('san_mdt:applyIncidentLicenseSanction', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageProfileLicenses(xPlayer) then
        return cb({ ok = false, message = 'Du har ikke tilladelse til kÃ¸rekortssanktioner.' })
    end
    data = type(data) == 'table' and data or {}
    if data.confirmed ~= true then
        return cb({ ok = false, message = 'BekrÃ¦ft kÃ¸rekortssanktionen fÃ¸rst.' })
    end
    local incidentId = tonumber(data.incidentId or data.incident_id)
    local personIndex = tonumber(data.personIndex or data.person_index)
    if not incidentId or personIndex == nil then
        return cb({ ok = false, message = 'Manglende hÃ¦ndelse eller person.' })
    end

    local ok, resp = pcall(function()
        return applyIncidentLicenseSanctionInternal(source, incidentId, personIndex, xPlayer)
    end)
    if ok then
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    else
        print(('[san_mdt] applyIncidentLicenseSanction error: %s'):format(tostring(resp)))
        cb({ ok = false, message = 'Serverfejl ved kÃ¸rekortssanktion.' })
    end
end)

ESX.RegisterServerCallback('san_mdt:getProfile', function(source, cb, identifier)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false }) end
    identifier = trim(identifier)
    if identifier == '' then return cb({ ok = false }) end

    local rows = MySQL.query.await('SELECT * FROM users WHERE identifier = ? LIMIT 1', { identifier }) or {}
    local row = rows[1]
    if not row then return cb({ ok = false }) end
    local metaRows = MySQL.query.await('SELECT division, pnumber, profile_image FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { identifier }) or {}
    local meta = metaRows[1] or {}
    local civ = MySQL.single.await('SELECT * FROM mdt_civilian_profiles WHERE identifier = ? LIMIT 1', { identifier }) or {}
    local unpaidTotal, unpaidBills = getUnpaidBills(identifier)
    local licenseRows = getUserLicenseRows(identifier)
    local hasDrive = false
    for _, lic in ipairs(licenseRows) do
        if tostring(lic.type or '') == 'drive' then hasDrive = true break end
    end

    local vehicles = {}
    local vehRows = MySQL.query.await('SELECT plate, vehicle, stored, pound, impound_type, impound_locked FROM owned_vehicles WHERE owner = ? ORDER BY plate ASC', { identifier }) or {}
    for i = 1, #vehRows do
        local vr = vehRows[i]
        local props = decodeJson(vr.vehicle, {})
        local status = 'Ude'
        if tonumber(vr.stored or 0) == 1 then status = 'I garage' end
        if tonumber(vr.stored or 0) == 2 or (vr.pound and vr.pound ~= '') then status = 'Impound' end
        if tostring(vr.impound_type or '') == 'permanent' then status = 'Permanent beslaglagt' end
        if tonumber(vr.impound_locked or 0) == 1 or tostring(vr.impound_type or '') == 'locked' then status = status .. ' / LÃ¥st' end
        vehicles[#vehicles + 1] = { plate = vr.plate, model = resolveVehicleModelName(props.modelName or props.model or props.vehicleName or ''), status = status }
    end

    local points = tonumber(civ.license_points or 0) or 0
    local revoked = tonumber(civ.license_revoked or 0) == 1
    local licenseHistory = getLicenseHistory(identifier, 40)
    local restoreInfo = getLicenseRestoreInfo(identifier)

    cb({
        ok = true,
        profile = {
            identifier = row.identifier,
            name = getUserName(row),
            dob = row.dateofbirth or row.dob or '',
            phone = row.phone_number or row.phone or '',
            sex = row.sex or '',
            job = row.job or '',
            bank = row.bank or row.accounts or '',
            vehicles = vehicles,
            division = tostring(meta.division or ''),
            pnumber = tostring(meta.pnumber or ''),
            profile_image = tostring(civ.profile_image or meta.profile_image or ''),
            notes = tostring(civ.notes or ''),
            license_points = points,
            license_revoked = revoked,
            license_revocation_note = tostring(civ.license_revocation_note or ''),
            license_revoked_at = restoreInfo.revoked_at,
            license_can_restore = restoreInfo.can_restore,
            license_restore_at = restoreInfo.eligible_at,
            license_restore_remaining_seconds = restoreInfo.remaining_seconds,
            license_cooldown_hours = restoreInfo.hours,
            license_history = licenseHistory,
            license_max_points = tonumber(Config.LicenseMaxActivePoints or 3) or 3,
            has_drive_license = hasDrive,
            licenses = licenseRows,
            license_catalog = getMdtLicenseCatalog(),
            can_manage_licenses = canManageProfileLicenses(xPlayer),
            can_view_gang = canViewProfileGang(xPlayer),
            can_register_gang = canRegisterProfileGang(xPlayer),
            gang = canViewProfileGang(xPlayer) and getProfileGangInfo(identifier) or nil,
            unpaid = unpaidTotal,
            unpaid_formatted = (unpaidTotal > 0 and (tostring(unpaidTotal) .. ' kr.')) or '0 kr.',
            unpaid_bills = unpaidBills
        }
    })
end)

ESX.RegisterServerCallback('san_mdt:updateProfileLicense', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageProfileLicenses(xPlayer) then
        return cb({ ok = false, message = 'Du har ikke tilladelse til at administrere licenser.' })
    end
    data = type(data) == 'table' and data or {}
    local identifier = normalizePersonIdentifier(data.identifier)
    local licenseType = trim(data.licenseType or data.type or '')
    local action = trim(data.action or 'remove'):lower()
    if identifier == '' or licenseType == '' then
        return cb({ ok = false, message = 'Manglende borger eller licenstype.' })
    end

    local allowed = false
    for _, lic in ipairs(getMdtLicenseCatalog()) do
        if tostring(lic.type) == licenseType then allowed = true break end
    end
    if not allowed then
        return cb({ ok = false, message = 'Ukendt licenstype.' })
    end

    local ok, resp = pcall(function()
        if action == 'add' then
            local exists = MySQL.scalar.await('SELECT 1 FROM user_licenses WHERE owner = ? AND type = ? LIMIT 1', { identifier, licenseType })
            if exists then
                return { ok = false, message = 'Personen har allerede denne licens.' }
            end
            local preRestoreInfo = isLicenseRevokeType(licenseType) and getLicenseRestoreInfo(identifier) or nil
            if preRestoreInfo and preRestoreInfo.revoked and not preRestoreInfo.can_restore then
                local remain = math.max(0, tonumber(preRestoreInfo.remaining_seconds or 0) or 0)
                local hoursLeft = math.floor(remain / 3600)
                local minsLeft = math.ceil((remain % 3600) / 60)
                if minsLeft >= 60 then hoursLeft = hoursLeft + 1; minsLeft = 0 end
                return {
                    ok = false,
                    message = ('KÃ¸rekort kan tidligst genudstedes efter %d timer. Ca. %d t %d min tilbage.'):format(
                        preRestoreInfo.hours, hoursLeft, minsLeft
                    ),
                }
            end
            MySQL.insert.await('INSERT INTO user_licenses (type, owner) VALUES (?, ?)', { licenseType, identifier })
            local shouldReset = preRestoreInfo and (
                preRestoreInfo.revoked or (tonumber(preRestoreInfo.license_points or 0) or 0) > 0
            )
            if shouldReset then
                resetLicenseClipsOnRestore(identifier, licenseType, getOfficerName(xPlayer, source), getMdtIdentifier(xPlayer))
            end
            refreshPlayerLicenseItems(identifier)
            if isLicenseRevokeType(licenseType) then
                notifyPlayerByIdentifier(identifier, 'Du har fÃ¥et kÃ¸rekort igen. Aktive klip er nulstillet.')
            end
            mdtAuditLog(source, 'Profiler', 'LICENSE_ADDED', {
                target_type = 'profile',
                target_id = identifier,
                message = ('TilfÃ¸jede licens: %s'):format(licenseType),
                metadata = { licenseType = licenseType, clips_reset = shouldReset }
            })
            local msg = shouldReset and 'Licens tilfÃ¸jet. Aktive klip er nulstillet.' or 'Licens tilfÃ¸jet.'
            return { ok = true, message = msg, licenses = getUserLicenseRows(identifier), clips_reset = shouldReset }
        end

        local removed = MySQL.update.await('DELETE FROM user_licenses WHERE owner = ? AND type = ?', { identifier, licenseType })
        if (tonumber(removed) or 0) < 1 then
            return { ok = false, message = 'Personen har ikke denne licens.' }
        end
        refreshPlayerLicenseItems(identifier)
        mdtAuditLog(source, 'Profiler', 'LICENSE_REMOVED', {
            target_type = 'profile',
            target_id = identifier,
            message = ('Fjernede licens: %s'):format(licenseType),
            metadata = { licenseType = licenseType }
        })
        return { ok = true, message = 'Licens fjernet.', licenses = getUserLicenseRows(identifier) }
    end)

    if ok then
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    else
        print(('[san_mdt] updateProfileLicense error: %s'):format(tostring(resp)))
        cb({ ok = false, message = 'Databasefejl ved licensÃ¦ndring.' })
    end
end)

ESX.RegisterServerCallback('san_mdt:saveProfile', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    local identifier = trim(data.identifier or '')
    if identifier == '' then return cb({ ok = false, message = 'Manglende identifier.' }) end
    MySQL.insert.await([[INSERT INTO mdt_civilian_profiles (identifier, profile_image, notes)
        VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE profile_image = VALUES(profile_image), notes = VALUES(notes)
    ]], { identifier, tostring(data.profile_image or ''), tostring(data.notes or '') })
    mdtAuditLog(source, 'Profiler', 'PROFILE_SAVED', { target_type = 'profile', target_id = identifier, message = 'Gemte borgerprofil' })
    cb({ ok = true, message = 'Profil gemt.' })
end)




-- SAN MDT - FlÃ¥destyring
local activeFleetUnits = activeFleetUnits or {}
local broadcastFleet
local registeredPoliceGarageVehicles = registeredPoliceGarageVehicles or {}

-- SAN MDT DUTY/PATROL/DISPATCH CORE V1
-- In-memory live state: resets on resource/server restart, clears on disconnect.
local activeDutyOfficers = activeDutyOfficers or {}
local officerPatrolIndex = officerPatrolIndex or {}
local activeDispatchJobs = activeDispatchJobs or {}
local dispatchCounter = dispatchCounter or 0

local function mdtNow() return os.time() end
local function mdtOfficerKey(xPlayer, src)
    local id = (xPlayer and xPlayer.__mdtIdentifier) or (xPlayer and xPlayer.identifier) or nil
    if not id or tostring(id) == '' then id = tostring(src or '') end
    return tostring(id)
end
local function mdtOfficerPayload(xPlayer, src)
    local job = getJob(xPlayer) or {}
    return {
        identifier = mdtOfficerKey(xPlayer, src),
        source = tonumber(src) or 0,
        name = getOfficerName(xPlayer, src),
        badge = mdtGetPNumberForLogin(xPlayer, src),
        job = tostring(job.name or ''),
        since = mdtNow()
    }
end
isOfficerOnDuty = function(xPlayer, src)
    local key = mdtOfficerKey(xPlayer, src)
    return activeDutyOfficers[key] ~= nil
end
local function dispatchResponderListText(job)
    local out = {}
    if job and job.responders then
        for _, r in pairs(job.responders) do
            out[#out+1] = tostring(r.callsign or r.unitId or 'Patrulje')
        end
    end
    table.sort(out)
    return table.concat(out, ', ')
end

local function setOfficerOffDuty(xPlayer, src, reason)
    local key = mdtOfficerKey(xPlayer, src)
    activeDutyOfficers[key] = nil
    local currentUnit = officerPatrolIndex[key]
    officerPatrolIndex[key] = nil
    if currentUnit and activeFleetUnits[currentUnit] and activeFleetUnits[currentUnit].joined then
        activeFleetUnits[currentUnit].joined[key] = nil
    end
    for _, job in pairs(activeDispatchJobs) do
        if job.responders and currentUnit then job.responders[currentUnit] = nil end
        if job.assignedOfficer == key then
            job.assignedOfficer = nil
            job.assignedOfficerName = nil
        end
        job.responderCount = job.responders and (function(t) local c=0; for _ in pairs(t) do c=c+1 end; return c end)(job.responders) or 0
        job.assignedCallsign = dispatchResponderListText(job)
        if job.responderCount == 0 and tostring(job.status or '') == 'Tildelt' then job.status = 'Ny' end
    end
    if type(mdtAuditLog) == 'function' then
        mdtAuditLog(src, 'Duty', 'DUTY_OFF', { message = reason or 'Gik af arbejde' })
    end
    if type(broadcastFleet) == 'function' then broadcastFleet() end
end

-- SAN MDT V2 LOGIN / SESSION CORE
-- Sessionen er separat fra duty. Man skal vÃ¦re logget ind i MDT for at kunne gÃ¥ pÃ¥ arbejde/patrulje/dispatch.
local mdtSessions = {}

local function mdtSessionKey(xPlayer, src)
    local id = getMdtIdentifier and getMdtIdentifier(xPlayer) or ''
    if not id or id == '' then id = tostring(src or '') end
    return tostring(id)
end

function mdtGetPNumberForLogin(xPlayer, src)
    local identifier = getMdtIdentifier and getMdtIdentifier(xPlayer) or ''
    local pnumber, division = '', 'Patrulje'
    if identifier ~= '' and MySQL and MySQL.single and MySQL.single.await then
        local ok, row = pcall(function()
            return MySQL.single.await('SELECT pnumber, division FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { identifier })
        end)
        if ok and row then
            if row.pnumber and tostring(row.pnumber) ~= '' then pnumber = tostring(row.pnumber) end
            if row.division and tostring(row.division) ~= '' then division = tostring(row.division) end
        end
    end
    if pnumber == '' then
        local job = getJob(xPlayer) or {}
        pnumber = tostring(job.grade or job.grade_number or src or '')
    end
    return fleetFormatPNumber(pnumber, division)
end

local function mdtIsSessionActive(xPlayer, src)
    if not (Config and Config.MDTRequireLogin) then return true end
    local key = mdtSessionKey(xPlayer, src)
    return mdtSessions[key] == true
end

local function mdtSetSession(xPlayer, src, active)
    local key = mdtSessionKey(xPlayer, src)
    if active then mdtSessions[key] = true else mdtSessions[key] = nil end
end

local function normalizeMdtUsername(v)
    v = trim(v or ''):lower()
    v = v:gsub('%s+', '')
    if v:sub(1, 2) == 'p-' then v = v:sub(3) end
    return v
end

local function mdtLoginMatches(xPlayer, src, username, code)
    local rawUsername = trim(username or '')
    local usernameNorm = normalizeMdtUsername(rawUsername)
    code = trim(code or '')
    if usernameNorm == '' or code == '' then return false, 'Udfyld brugernavn og kode.' end

    local identifier = getMdtIdentifier and getMdtIdentifier(xPlayer) or (xPlayer and xPlayer.identifier) or ''
    local meta = nil
    if identifier ~= '' then
        local ok, row = pcall(function()
            return MySQL.single.await('SELECT pnumber, division, mdt_username, mdt_password FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { identifier })
        end)
        if ok then meta = row end
    end

    local division = tostring((meta and meta.division) or 'Patrulje')
    local pnumRaw = trim((meta and meta.pnumber) or '')
    if pnumRaw == '' then
        local job = getJob(xPlayer) or {}
        pnumRaw = tostring(job.grade or job.grade_number or src or '')
    end
    local pnumDigits = normalizePnumberDigits(pnumRaw)
    local pnumFmt = fleetFormatPNumber(pnumRaw, division)
    local savedUser = trim((meta and meta.mdt_username) or '')
    local savedPass = trim((meta and meta.mdt_password) or '')

    local allowedUsers = {}
    local function add(v)
        v = normalizeMdtUsername(v)
        if v ~= '' then allowedUsers[v] = true end
    end
    add(pnumRaw)
    add(pnumDigits)
    add(pnumFmt)
    add('P-' .. pnumDigits)
    add('P-' .. pnumRaw)
    add(savedUser)
    add(getOfficerName(xPlayer, src))
    add(identifier)

    -- Hvis Rigspolitiet har sat en personlig kode under Ansatte, skal den bruges.
    if savedPass ~= '' then
        if not allowedUsers[usernameNorm] then return false, 'Forkert brugernavn.' end
        if code ~= savedPass then return false, 'Forkert adgangskode.' end
        return true
    end

    -- Fallback til gammel global kode, sÃ¥ eksisterende installationer ikke lÃ¥ses ude.
    if code ~= tostring((Config and Config.MDTLoginCode) or '1234') then return false, 'Forkert MDT-kode.' end
    if allowedUsers[usernameNorm] then return true end
    if Config and Config.MDTLoginUsername and usernameNorm == normalizeMdtUsername(Config.MDTLoginUsername) then return true end
    return false, 'Forkert brugernavn eller kode.'
end

ESX.RegisterServerCallback('san_mdt:getMdtSession', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    cb({ ok=true, loggedIn=mdtIsSessionActive(xPlayer, source), pnumber=mdtGetPNumberForLogin(xPlayer, source), name=getOfficerName(xPlayer, source) })
end)

ESX.RegisterServerCallback('san_mdt:loginMdt', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    local ok, msg = mdtLoginMatches(xPlayer, source, data and data.username or '', data and data.code or '')
    if not ok then return cb({ ok=false, message=msg }) end
    mdtSetSession(xPlayer, source, true)
    mdtAuditLog(source, 'System', 'MDT_LOGIN', { message='Loggede ind i MDT' })
    cb({ ok=true, loggedIn=true, message='Logget ind.' })
end)

RegisterNetEvent('san_mdt:logoutMdtHard', function(reason)
    local src = source
    local xPlayer = getPlayer(src)
    if xPlayer then
        setOfficerOffDuty(xPlayer, src, reason or 'Gik af arbejde / MDT logout')
        mdtSetSession(xPlayer, src, false)
    end
end)

ESX.RegisterServerCallback('san_mdt:logoutMdt', function(source, cb, reason)
    local xPlayer = getPlayer(source)
    if xPlayer and hasJobAccess(xPlayer) then
        setOfficerOffDuty(xPlayer, source, reason or 'Gik af arbejde / MDT logout')
        mdtSetSession(xPlayer, source, false)
        mdtAuditLog(source, 'System', 'MDT_LOGOUT', { message='Loggede ud af MDT' })
    end
    cb({ ok=true, loggedIn=false, onDuty=false, closeMdt=true })
end)

local function activeDutyList()
    local arr = {}
    for _, o in pairs(activeDutyOfficers) do arr[#arr+1] = o end
    table.sort(arr, function(a,b) return tostring(a.badge or a.name or '') < tostring(b.badge or b.name or '') end)
    return arr
end
local function dispatchList()
    local arr = {}
    for _, d in pairs(activeDispatchJobs) do arr[#arr+1] = d end
    table.sort(arr, function(a,b) return tonumber(a.createdAt or 0) > tonumber(b.createdAt or 0) end)
    return arr
end


-- SAN performance fix:
-- Base64-fotos i dispatch metadata kan vÃ¦re 1-2 MB. Hvis de sendes med fleetData hver gang,
-- giver FiveM "large event" og server hitch/lag. Fleet/list/notifications fÃ¥r derfor en let kopi
-- uden foto-data. De detaljerede tekstfelter beholdes.
local function sanMdtStripDispatchPhotos(obj, depth)
    if type(obj) ~= 'table' then return obj end
    depth = tonumber(depth or 0) or 0
    if depth > 8 then return nil end
    local out = {}
    for k, v in pairs(obj) do
        local key = tostring(k)
        if key == 'photo' or key == 'image' or key == 'screenshot' or key == 'base64' then
            -- drop
        elseif type(v) == 'string' and #v > 200000 and v:find('data:image', 1, true) then
            -- drop giant image string
        elseif type(v) == 'table' then
            out[k] = sanMdtStripDispatchPhotos(v, depth + 1)
        else
            out[k] = v
        end
    end
    return out
end

local function sanMdtLightDispatch(job)
    return sanMdtStripDispatchPhotos(job or {}, 0)
end

local function sanMdtLightDispatchList()
    local arr = {}
    for _, d in pairs(activeDispatchJobs) do arr[#arr+1] = sanMdtLightDispatch(d) end
    table.sort(arr, function(a,b) return tonumber(a.createdAt or 0) > tonumber(b.createdAt or 0) end)
    return arr
end

local function dispatchDistance(a, b)
    if not a or not b then return 999999.0 end
    local ax, ay = tonumber(a.x) or 0.0, tonumber(a.y) or 0.0
    local bx, by = tonumber(b.x) or 0.0, tonumber(b.y) or 0.0
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function dispatchNormalizeType(v, title)
    local t = tostring(v or ''):lower():gsub('%s+', '_'):gsub('-', '_')
    local ttl = tostring(title or ''):lower()
    if t:find('weapon', 1, true) or t:find('vÃ¥ben', 1, true) or ttl:find('vÃ¥ben', 1, true) then
        return 'weapon_seen'
    end
    if t:find('shot', 1, true) or t:find('skud', 1, true) or ttl:find('skud', 1, true) or ttl:find('shot', 1, true) or ttl:find('skyderi', 1, true) then
        return 'shots_fired'
    end
    if t:find('theft', 1, true) or t:find('stolen', 1, true) or t:find('tyveri', 1, true) or ttl:find('stj', 1, true) or ttl:find('tyveri', 1, true) then
        return 'vehicle_theft'
    end
    if t:find('assault', 1, true) or t:find('vold', 1, true) or t:find('overfald', 1, true) or ttl:find('vold', 1, true) or ttl:find('overfald', 1, true) then
        return 'violent_assault'
    end
    if t:find('explosion', 1, true) or t:find('eksplosion', 1, true) or ttl:find('explosion', 1, true) or ttl:find('eksplosion', 1, true) then
        return 'explosion'
    end
    return t ~= '' and t or 'dispatch'
end

local function dispatchMergeSettings(dtype)
    dtype = dispatchNormalizeType(dtype)

    -- V98: hellere merge samme episode for meget end lave 5 rÃ¸de kort oveni hinanden.
    if dtype == 'shots_fired' then
        return tonumber((Config and Config.DispatchShotsMergeRadius) or 350.0) or 350.0, tonumber((Config and Config.DispatchShotsMergeSeconds) or 900) or 900
    end
    if dtype == 'vehicle_theft' then
        return tonumber((Config and Config.DispatchTheftMergeRadius) or 220.0) or 220.0, tonumber((Config and Config.DispatchTheftMergeSeconds) or 480) or 480
    end
    if dtype == 'explosion' then
        return tonumber((Config and Config.DispatchExplosionMergeRadius) or 450.0) or 450.0, tonumber((Config and Config.DispatchExplosionMergeSeconds) or 900) or 900
    end

    return tonumber((Config and Config.DispatchMergeRadius) or 160.0) or 160.0, tonumber((Config and Config.DispatchMergeSeconds) or 300) or 300
end


local function sanMdtDispatchAddWitnessStatement(job, statement)
    if type(job) ~= 'table' then return end
    statement = tostring(statement or ''):gsub('^Vidneudsagn:%s*', '')
    if statement == '' then return end
    job.metadata = job.metadata or {}
    job.metadata.witnessStatements = type(job.metadata.witnessStatements) == 'table' and job.metadata.witnessStatements or {}
    local maxW = tonumber((Config and Config.DispatchMaxWitnessStatements) or 5) or 5
    for _, v in ipairs(job.metadata.witnessStatements) do
        if tostring(v) == statement then return end
    end
    if #job.metadata.witnessStatements < maxW then
        job.metadata.witnessStatements[#job.metadata.witnessStatements + 1] = statement
    else
        job.metadata.witnessStatements[math.random(1, maxW)] = statement
    end
    job.metadata.witnessStatement = table.concat(job.metadata.witnessStatements, '\n')
end

local function sanMdtDispatchImportWitnessStatements(job, md)
    if type(job) ~= 'table' or type(md) ~= 'table' then return end
    if type(md.witnessStatements) == 'table' then
        for _, st in ipairs(md.witnessStatements) do sanMdtDispatchAddWitnessStatement(job, st) end
    end
    if md.witnessStatement then sanMdtDispatchAddWitnessStatement(job, md.witnessStatement) end
end

local function dispatchFindAreaMatch(data)
    local dtype = dispatchNormalizeType(data.type, data.title)
    data.type = dtype
    local now = mdtNow()
    local radius, ttl = dispatchMergeSettings(dtype)
    local best, bestDist = nil, 999999.0

    for _, job in pairs(activeDispatchJobs) do
        local jtype = dispatchNormalizeType(job.type, job.title)
        local status = tostring(job.status or '')
        if jtype == dtype and status ~= 'Afsluttet' and status ~= 'Afsluttet.' then
            local age = now - tonumber(job.lastUpdateAt or job.createdAt or now)
            local dist = dispatchDistance(job, data)
            if age <= ttl and dist <= radius and dist < bestDist then
                best, bestDist = job, dist
            end
        end
    end

    return best, bestDist
end

local function mdtCreateDispatchJob(src, data, creatorLabel)
    data = data or {}

    -- SAN FIX: samme type i samme omrÃ¥de skal MERGES, sÃ¥ man ikke fÃ¥r 10 ens dispatches.
    local allowMerge = data.noMerge ~= true
    local merge, mergeDistance = nil, nil
    if allowMerge then merge, mergeDistance = dispatchFindAreaMatch(data) end
    if merge then
        merge.count = tonumber(merge.count or 1) + 1
        merge.shotCount = merge.type == 'shots_fired' and merge.count or merge.shotCount
        merge.lastUpdateAt = mdtNow()
        merge.lastActivity = merge.lastUpdateAt
        merge.lastX = tonumber(data.x) or merge.lastX or merge.x
        merge.lastY = tonumber(data.y) or merge.lastY or merge.y
        merge.lastZ = tonumber(data.z) or merge.lastZ or merge.z
        merge.street = tostring(data.street or data.location or merge.street or 'Ukendt lokation')
        merge.description = tostring(data.description or merge.description or '')
        merge.priority = math.min(tonumber(merge.priority or 2) or 2, tonumber(data.priority or 2) or 2)
        if type(data.metadata) == 'table' then
            merge.metadata = merge.metadata or {}
            if type(data.metadata.suspect) == 'table' then
                merge.metadata.suspect = merge.metadata.suspect or {}
                for k,v in pairs(data.metadata.suspect) do if v ~= nil and v ~= '' then merge.metadata.suspect[k] = v end end
                merge.suspect = merge.metadata.suspect
            end
            if type(data.metadata.vehicle) == 'table' then
                merge.metadata.vehicle = merge.metadata.vehicle or {}
                for k,v in pairs(data.metadata.vehicle) do if v ~= nil and v ~= '' then merge.metadata.vehicle[k] = v end end
                merge.vehicle = merge.metadata.vehicle
            end
            if type(data.metadata.witnesses) == 'table' then merge.metadata.witnesses = data.metadata.witnesses; merge.witnesses = data.metadata.witnesses end
            sanMdtDispatchImportWitnessStatements(merge, data.metadata)
        end
        merge.witnessCount = math.min(5, (tonumber(merge.witnessCount or 0) or 0) + math.max(1, tonumber(data.witnessCount or 1) or 1))
        if type(merge.metadata) == 'table' and type(merge.metadata.witnesses) == 'table' then merge.metadata.witnesses.total = merge.witnessCount; merge.witnesses = merge.metadata.witnesses end
        merge.status = merge.status or 'Ny'
        merge.areaMerged = true
        merge.mergeDistance = math.floor((tonumber(mergeDistance) or 0.0) + 0.5)
        merge.activityState = (tonumber(merge.count or 1) >= 15 and 'Kritisk') or (tonumber(merge.count or 1) >= 6 and 'Intensiveret') or 'Aktiv'
        merge.pulse = (merge.pulse or 0) + 1
        -- Performance: auto-merge spam logges ikke med fuld dispatch metadata.
        print(('[san_mdt:dispatch] merged %s -> %s x%s dist=%sm'):format(tostring(data.type), tostring(merge.id), tostring(merge.count), tostring(merge.mergeDistance)))
        if type(broadcastFleet) == 'function' then broadcastFleet() end
        -- V96: vigtigt: samme opkald skal stadig give ny notifikation og live update, ikke bare vÃ¦re stille.
        for _, sid in ipairs(GetPlayers()) do
            local xP = getPlayer(tonumber(sid))
            if xP and hasJobAccess(xP) and isOfficerOnDuty(xP, tonumber(sid)) then
                TriggerClientEvent('san_mdt:dispatchNotify', tonumber(sid), sanMdtLightDispatch(merge))
            end
        end
        return merge
    end

    dispatchCounter = dispatchCounter + 1
    local id = ('D-%04d'):format(dispatchCounter)
    data.type = dispatchNormalizeType(data.type, data.title)
    activeDispatchJobs[id] = {
        id=id,
        title=tostring(data.title or 'Opkald'),
        type=tostring(data.type or 'dispatch'),
        description=tostring(data.description or ''),
        street=tostring(data.street or data.location or 'Ukendt lokation'),
        x=tonumber(data.x) or 0,
        y=tonumber(data.y) or 0,
        z=tonumber(data.z) or 0,
        status='Ny',
        createdAt=mdtNow(),
        lastUpdateAt=mdtNow(),
        count=1,
        shotCount=(dispatchNormalizeType(data.type, data.title) == 'shots_fired') and 1 or nil,
        priority=tonumber(data.priority or 2) or 2,
        activityState='Aktiv',
        pulse=1,
        responders={},
        responderCount=0,
        assignedUnit=nil,
        assignedCallsign=nil,
        assignedOfficer=nil,
        assignedOfficerName=nil,
        source=tonumber(src) or 0,
        creator=creatorLabel or 'System',
        metadata=(type(data.metadata) == 'table' and data.metadata or {}),
        suspect=(type(data.suspect) == 'table' and data.suspect or (type(data.metadata) == 'table' and data.metadata.suspect or nil)),
        vehicle=(type(data.vehicle) == 'table' and data.vehicle or (type(data.metadata) == 'table' and data.metadata.vehicle or nil)),
        witnesses=(type(data.witnesses) == 'table' and data.witnesses or (type(data.metadata) == 'table' and data.metadata.witnesses or nil)),
        witnessCount=tonumber(data.witnessCount or (type(data.metadata) == 'table' and data.metadata.witnesses and data.metadata.witnesses.total) or 0) or 0
    }
    activeDispatchJobs[id].witnessCount = math.min(5, tonumber(activeDispatchJobs[id].witnessCount or 0) or 0)
    if type(activeDispatchJobs[id].metadata) == 'table' then
        sanMdtDispatchImportWitnessStatements(activeDispatchJobs[id], activeDispatchJobs[id].metadata)
        if type(activeDispatchJobs[id].metadata.witnesses) == 'table' then activeDispatchJobs[id].metadata.witnesses.total = activeDispatchJobs[id].witnessCount; activeDispatchJobs[id].witnesses = activeDispatchJobs[id].metadata.witnesses end
    end
    print(('[san_mdt:dispatch] created %s type=%s x=%.1f y=%.1f'):format(tostring(id), tostring(activeDispatchJobs[id].type), tonumber(activeDispatchJobs[id].x) or 0, tonumber(activeDispatchJobs[id].y) or 0))
    if creatorLabel ~= 'Auto' and type(mdtAuditLog) == 'function' and src and tonumber(src) and tonumber(src) > 0 then
        mdtAuditLog(src, 'Dispatch', 'DISPATCH_CREATED', { target_type='dispatch', target_id=id, target_label=activeDispatchJobs[id].title, message='Oprettede dispatch-opgave', metadata=sanMdtLightDispatch(activeDispatchJobs[id]) })
    end
    if type(broadcastFleet) == 'function' then broadcastFleet() end
    local notified = 0
    for _, sid in ipairs(GetPlayers()) do
        local xP = getPlayer(tonumber(sid))
        if xP and hasJobAccess(xP) and isOfficerOnDuty(xP, tonumber(sid)) then
            TriggerClientEvent('san_mdt:dispatchNotify', tonumber(sid), sanMdtLightDispatch(activeDispatchJobs[id]))
            notified = notified + 1
        end
    end
    if notified <= 0 then print(('[san_mdt:dispatch] %s created but no on-duty officers to notify'):format(tostring(id))) end
    return activeDispatchJobs[id]
end

local function fleetDebug(msg) if Config and Config.FleetDebug then print(('[san_mdt:fleet] %s'):format(tostring(msg))) end end


local function fleetTrimPlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end


local function fleetRandomDigits(n)
    local out = ''
    for i = 1, n do out = out .. tostring(math.random(0, 9)) end
    return out
end

local function fleetDefaultCategory(model, vehicleClass)
    local cls = tonumber(vehicleClass or -1) or -1
    local m = tostring(model or ''):lower()
    if cls == 8 or m:find('bike') or m:find('motor') then return 'motorcykel' end
    if m:find('unmarked') or m:find('civil') or m:find('uc') then return 'civil' end
    return 'patrulje'
end

local function fleetDefaultCallsign(category)
    category = tostring(category or 'patrulje'):lower()
    if category == 'motorcykel' or category == 'mc' then return ('Charlie %s-%s'):format(fleetRandomDigits(2), fleetRandomDigits(2)) end
    if category == 'civil' then return ('Echo %s'):format(fleetRandomDigits(2)) end
    return ('Bravo %s-%s'):format(fleetRandomDigits(2), fleetRandomDigits(2))
end


local function fleetGetOfficerPNumber(xPlayer, source)
    local identifier = getMdtIdentifier(xPlayer)
    local pnumber, division = '', 'Patrulje'
    if identifier and identifier ~= '' then
        local rows = MySQL.query.await('SELECT pnumber, division FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { identifier }) or {}
        if rows[1] then
            if rows[1].pnumber and tostring(rows[1].pnumber) ~= '' then pnumber = tostring(rows[1].pnumber) end
            if rows[1].division and tostring(rows[1].division) ~= '' then division = tostring(rows[1].division) end
        end
    end
    if pnumber == '' then
        local job = getJob(xPlayer) or {}
        pnumber = tostring(job.grade or job.grade_number or source or '')
    end
    return fleetFormatPNumber(pnumber, division)
end

local function fleetEnsureUnitMeta(unit, model, vehicleClass)
    unit.category = unit.category or fleetDefaultCategory(model or unit.model, vehicleClass or unit.vehicleClass)
    unit.callsign = unit.callsign or fleetDefaultCallsign(unit.category)
    unit.joined = unit.joined or {}
    unit.taskCount = tonumber(unit.taskCount or 0) or 0
    return unit
end

local function isRegisteredPoliceGarageVehicle(plate)
    if not (Config and Config.FleetRequireGarageSpawn == true) then return true end
    local key = fleetTrimPlate(plate)
    local row = registeredPoliceGarageVehicles[key]
    if not row then return false end
    local ttl = tonumber(Config.FleetGarageSpawnTTL or 28800) or 28800
    if os.time() - (tonumber(row.time) or 0) > ttl then
        registeredPoliceGarageVehicles[key] = nil
        return false
    end
    return true
end

RegisterNetEvent('san_mdt:registerPoliceGarageVehicle', function(plate, model, src)
    local eventSource = source
    local ownerSource = tonumber(src) or tonumber(eventSource)
    local xPlayer = ownerSource and getPlayer(ownerSource) or nil
    if (not xPlayer or not hasJobAccess(xPlayer)) and tonumber(eventSource) and tonumber(eventSource) > 0 then xPlayer = getPlayer(tonumber(eventSource)) end
    ownerSource = getPlayerSourceSafe(xPlayer, ownerSource or eventSource)
    if not xPlayer or not hasJobAccess(xPlayer) then fleetDebug(('reject garage register no access eventSource=%s ownerSource=%s plate=%s'):format(tostring(eventSource), tostring(ownerSource), tostring(plate))); return end
    local job = getJob(xPlayer) or {}
    local jobName = tostring(job.name or '')
    local service = fleetJobService(jobName)
    if not service then fleetDebug(('reject garage register non fleet job=%s'):format(jobName)); return end

    local key = fleetTrimPlate(plate)
    if key == '' then return end
    registeredPoliceGarageVehicles[key] = { plate = plate, model = model, source = ownerSource, time = os.time() }
    fleetDebug(('garage registered %s src=%s model=%s'):format(key, tostring(ownerSource), tostring(model)))
    broadcastFleet()
end)


RegisterNetEvent('san_mdt:unregisterPoliceGarageVehicle', function(plate)
    local raw = tostring(plate or '')
    local key = fleetTrimPlate(raw)
    if key ~= '' then
        registeredPoliceGarageVehicles[key] = nil
        activeFleetUnits[key] = nil
        activeFleetUnits[raw] = nil
        fleetDebug(('garage stored/unregistered %s'):format(key))
        broadcastFleet()
    end
end)

local function cleanFleetUnits()
    local now = os.time()
    for src, unit in pairs(activeFleetUnits) do
        if not unit.lastSeen or (now - unit.lastSeen) > (tonumber(Config and Config.FleetUnitTimeout or 300) or 300) then
            activeFleetUnits[src] = nil
        end
    end
end

local function fleetSnapshot()
    cleanFleetUnits()
    local units = {}
    for _, unit in pairs(activeFleetUnits) do units[#units + 1] = unit end
    table.sort(units, function(a,b) return tostring(a.callsign or '') < tostring(b.callsign or '') end)
    return { ok = true, units = units, officers = activeDutyList(), dispatches = sanMdtLightDispatchList(), serverTime = os.time() }
end

function broadcastFleet()
    local snapshot = fleetSnapshot()
    if GetResourceState('povh') == 'started' then
        snapshot.units = exports.povh:FilterFleetUnits(snapshot.units)
    end
    TriggerClientEvent('san_mdt:fleetData', -1, snapshot)
end


local function fleetModelService(modelHash, veh)
    if GetResourceState('povh') == 'started' then
        return exports.povh:ModelService(modelHash, nil)
    end
    if Config and Config.FleetEMSVehicleModels then
        for modelName, enabled in pairs(Config.FleetEMSVehicleModels) do
            if enabled and GetHashKey(modelName) == modelHash then return 'ems' end
        end
    end
    if Config and Config.FleetPoliceVehicleModels then
        for modelName, enabled in pairs(Config.FleetPoliceVehicleModels) do
            if enabled and GetHashKey(modelName) == modelHash then return 'police' end
        end
    end
    return nil
end

function fleetJobService(jobName)
    jobName = tostring(jobName or '')
    if Config and Config.FleetEMSJobs and Config.FleetEMSJobs[jobName] then return 'ems' end
    if Config and Config.FleetPoliceJobs and Config.FleetPoliceJobs[jobName] then return 'police' end
    return nil
end

local function fleetModelAllowed(modelHash, veh)
    if Config and Config.FleetAllowAnyPoliceVehicle == true then return true end
    return fleetModelService(modelHash, veh) ~= nil
end

local function fleetPlayerService(xPlayer)
    local job = getJob(xPlayer) or {}
    return fleetJobService(job.name or '')
end

local function fleetSameServiceOrDeny(xPlayer, unit)
    local myService = fleetPlayerService(xPlayer)
    local unitService = tostring(unit and (unit.service or unit.kind) or 'police'):lower()
    if myService and unitService ~= '' and unitService ~= myService then
        if myService == 'police' then return false, 'Politi kan kun se EMS-kÃ¸retÃ¸jer. Du kan ikke tilgÃ¥ eller tilmelde dig EMS-enheder.' end
        if myService == 'ems' then return false, 'EMS kan kun se politi-kÃ¸retÃ¸jer. Du kan ikke tilgÃ¥ eller tilmelde dig politi-enheder.' end
        return false, 'Du kan ikke tilgÃ¥ denne enhed.'
    end
    return true
end

local function fleetServerScanVehicles()
    -- V9: Scan ogsÃ¥ nÃ¥r FleetRequireGarageSpawn=true, men med hÃ¥rd filter:
    -- kun nummerplader der er registreret fra politi-garagen mÃ¥ holdes aktive.
    if not (Config and Config.FleetServerScanVehicles) then return end
    local ok, vehicles = pcall(GetAllVehicles)
    if not ok or not vehicles then return end
    local now = os.time()
    for _, veh in ipairs(vehicles) do
        pcall(function()
            if veh and veh ~= 0 and DoesEntityExist(veh) then
                local modelHash = GetEntityModel(veh)
                local service = fleetModelService(modelHash, veh)
                if service then
                    local plate = tostring(GetVehicleNumberPlateText(veh) or ''):gsub('^%s*(.-)%s*$', '%1')
                    local regKey = fleetTrimPlate(plate)
                    if plate ~= '' and isRegisteredPoliceGarageVehicle(plate) then
                        local coords = GetEntityCoords(veh)
                        local unitKey = regKey ~= '' and regKey or plate
                        local current = activeFleetUnits[unitKey] or activeFleetUnits[plate] or {}
                        current = fleetEnsureUnitMeta(current, tostring(modelHash), GetVehicleClass(veh))
                        activeFleetUnits[unitKey] = {
                            id = unitKey,
                            source = current.source or 0,
                            driver = current.driver or 'Ingen chauffÃ¸r',
                            callsign = current.callsign,
                            category = current.category,
                            taskCount = current.taskCount or 0,
                            plate = plate,
                            model = current.model or tostring(modelHash),
                            service = current.service or service or 'police',
                            siren = IsVehicleSirenOn(veh) or IsVehicleSirenAudioOn(veh),
                            x = coords.x or 0,
                            y = coords.y or 0,
                            z = coords.z or 0,
                            heading = GetEntityHeading(veh) or 0,
                            speed = math.floor((GetEntitySpeed(veh) or 0.0) * 3.6 + 0.5),
                            status = current.status or 'Online',
                            joined = current.joined or {},
                            lastSeen = now
                        }
                    end
                end
            end
        end)
    end
end

CreateThread(function()
    while true do
        Wait(tonumber(Config and Config.FleetServerScanInterval or 750) or 750)
        fleetServerScanVehicles()
        broadcastFleet()
    end
end)

RegisterNetEvent('san_mdt:fleetPing', function(data)
    local src = source
    local xPlayer = getPlayer(src)
    if not hasJobAccess(xPlayer) then fleetDebug(('reject no access src=%s'):format(src)); return end
    local job = getJob(xPlayer) or {}
    local jobName = job.name or ''
    local service = fleetJobService(jobName) or tostring(data.service or '')
    if service ~= 'police' and service ~= 'ems' then fleetDebug(('reject non fleet job=%s src=%s'):format(jobName, src)); return end
    data = data or {}
    local unitId = trim(data.id or data.plate or '')
    local plate = trim(data.plate or unitId)
    local normalizedPlate = fleetTrimPlate(plate)
    if normalizedPlate ~= '' then unitId = normalizedPlate end
    if unitId == '' then unitId = ('SRC-%s'):format(src) end
    if not isRegisteredPoliceGarageVehicle(plate) then
        fleetDebug(('reject not garage registered plate=%s src=%s'):format(plate, src))
        return
    end
    if GetResourceState('povh') == 'started' and not exports.povh:ValidateFleetPing(data, jobName) then
        fleetDebug(('reject non emergency vehicle model=%s src=%s'):format(tostring(data.model), src))
        return
    end
    local name = getOfficerName(xPlayer, src)
    activeFleetUnits[unitId] = fleetEnsureUnitMeta(activeFleetUnits[unitId] or {}, tostring(data.model or 'KÃ¸retÃ¸j'), tonumber(data.vehicleClass))
    local current = activeFleetUnits[unitId]
    local joined = current.joined or {}
    activeFleetUnits[unitId] = {
        id = unitId,
        source = src,
        driver = name,
        callsign = current.callsign,
        category = current.category,
        taskCount = current.taskCount or 0,
        plate = plate,
        model = tostring(data.model or 'KÃ¸retÃ¸j'),
        service = service,
        siren = data.siren == true,
        x = tonumber(data.x) or 0,
        y = tonumber(data.y) or 0,
        z = tonumber(data.z) or 0,
        heading = tonumber(data.heading) or 0,
        speed = tonumber(data.speed) or 0,
        status = tostring(data.status or 'Online'),
        joined = joined,
        lastSeen = os.time()
    }
    fleetDebug(('ping %s %s %.1f %.1f %skm/t'):format(src, unitId, activeFleetUnits[unitId].x, activeFleetUnits[unitId].y, activeFleetUnits[unitId].speed))
    broadcastFleet()
end)

RegisterNetEvent('san_mdt:fleetLeave', function(plate)
    -- V9: NÃ¥r betjenten gÃ¥r ud, skal politibilen stadig vÃ¦re pÃ¥ flÃ¥destyring.
    -- Den forsvinder fÃ¸rst, nÃ¥r bilen ikke lÃ¦ngere findes i verden / bliver sat i garage / despawner.
    local raw = tostring(plate or '')
    local key = fleetTrimPlate(raw)
    local unit = activeFleetUnits[key] or activeFleetUnits[raw]
    if unit then
        unit.driver = unit.driver or 'Ingen chauffÃ¸r'
        unit.speed = 0
        unit.status = unit.status or 'Online'
        unit.lastSeen = os.time()
        fleetDebug(('left vehicle kept active %s'):format(key ~= '' and key or raw))
        broadcastFleet()
    end
end)



RegisterNetEvent('san_mdt:setDutyOffFast', function()
    local src = source
    local xPlayer = getPlayer(src)
    if not hasJobAccess(xPlayer) then return end

    -- Async/off-duty cleanup. Do not block the NUI close flow.
    setOfficerOffDuty(xPlayer, src, 'Gik af arbejde via MDT')
    mdtSetSession(xPlayer, src, false)
end)

ESX.RegisterServerCallback('san_mdt:getDutyStatus', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    cb({ ok=true, onDuty=isOfficerOnDuty(xPlayer, source), officer=activeDutyOfficers[mdtOfficerKey(xPlayer, source)], patrol=officerPatrolIndex[mdtOfficerKey(xPlayer, source)] })
end)

ESX.RegisterServerCallback('san_mdt:setDutyStatus', function(source, cb, onDuty)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    -- SAN FIX: Login/session mÃ¥ ikke blokere 'GÃ¥ pÃ¥ arbejde'. MDT-login er udfaset i NUI, sÃ¥ duty-knappen skal virke direkte.
    if onDuty then mdtSetSession(xPlayer, source, true) end
    local key = mdtOfficerKey(xPlayer, source)
    if onDuty then
        activeDutyOfficers[key] = mdtOfficerPayload(xPlayer, source)
        mdtAuditLog(source, 'Duty', 'DUTY_ON', { message='Gik pÃ¥ arbejde via MDT' })
        broadcastFleet()
        return cb({ ok=true, onDuty=true, officer=activeDutyOfficers[key] })
    end
    setOfficerOffDuty(xPlayer, source, 'Gik af arbejde via MDT')
    cb({ ok=true, onDuty=false, closeMdt=true })
end)

ESX.RegisterServerCallback('san_mdt:createDispatchJob', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    local job = mdtCreateDispatchJob(source, data or {}, GetPlayerName(source) or 'MDT')
    cb({ ok=true, job=job })
end)

RegisterNetEvent('san_mdt:autoDispatchCall', function(data)
    local src = source
    data = data or {}
    -- Midlertidigt: alle kan trigge test-opkald. Senere filtrerer vi politi/EMS fra egne skud.
    mdtCreateDispatchJob(src, data, 'Auto')
end)


RegisterCommand('mdttestdispatch', function(source)
    if source <= 0 then print('Brug kommandoen ingame som spiller.'); return end
    local ped = GetPlayerPed(source)
    local c = GetEntityCoords(ped)
    mdtCreateDispatchJob(source, {
        type='shots_fired', title='TEST dispatch', description='Manuel test fra /mdttestdispatch',
        street='Test lokation', x=c.x, y=c.y, z=c.z, priority=1,
        witnessCount=1, metadata={ witnessStatements={'TEST: MDT-notifikation og dispatch-listen virker.'}, witnesses={total=1} }
    }, 'Test')
end, false)


ESX.RegisterServerCallback('san_mdt:getDispatchDetails', function(source, cb, dispatchId)
    local xP = getPlayer(source)
    if not xP or not hasJobAccess(xP) or not isOfficerOnDuty(xP, source) then
        return cb({ ok=false, message='Du er ikke pÃ¥ arbejde.' })
    end
    local job = activeDispatchJobs[tostring(dispatchId or '')]
    if not job then return cb({ ok=false, message='Dispatch findes ikke.' }) end
    cb({ ok=true, dispatch=job })
end)

ESX.RegisterServerCallback('san_mdt:acceptDispatchJob', function(source, cb, dispatchId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    if not isOfficerOnDuty(xPlayer, source) then return cb({ ok=false, message='Du skal vÃ¦re pÃ¥ arbejde for at tage opgaven.' }) end
    local key = mdtOfficerKey(xPlayer, source)
    local unitId = officerPatrolIndex[key]
    if not unitId or not activeFleetUnits[unitId] then return cb({ ok=false, message='Du skal vÃ¦re tilmeldt en patrulje for at acceptere opgaven.' }) end
    local job = activeDispatchJobs[tostring(dispatchId or '')]
    if not job then return cb({ ok=false, message='Opgaven findes ikke lÃ¦ngere.' }) end
    local unit = activeFleetUnits[unitId]
    job.responders = job.responders or {}
    if not job.responders[unitId] then
        job.responders[unitId] = {
            unitId = unitId,
            callsign = unit.callsign or unit.plate or unitId,
            officer = key,
            officerName = GetPlayerName(source) or 'Ukendt',
            joinedAt = mdtNow()
        }
        unit.activeDispatches = unit.activeDispatches or {}
        unit.activeDispatches[job.id] = true
        unit.taskCount = tonumber(unit.taskCount or 0) + 1
    end
    job.status = 'Tildelt'
    job.responderCount = 0
    for _ in pairs(job.responders) do job.responderCount = job.responderCount + 1 end
    job.assignedUnit = unitId -- backwards compatible for old UI
    job.assignedCallsign = dispatchResponderListText(job)
    job.assignedOfficer = key
    job.assignedOfficerName = GetPlayerName(source) or 'Ukendt'
    unit.status = 'PÃ… OPGAVE'
    mdtAuditLog(source, 'Dispatch', 'DISPATCH_ACCEPTED', { target_type='dispatch', target_id=job.id, target_label=job.title, message=(unit.callsign or 'Patruljen') .. ' responder pÃ¥ opgaven', metadata={ dispatch=job, unit=unit } })
    mdtAuditLog(source, 'Patruljer', 'FLEET_TASK_ACCEPTED', { target_type='fleet_unit', target_id=unitId, target_label=unit.callsign or unit.plate or unitId, message='Patruljen tog opgave: '..tostring(job.title or job.id), metadata={ dispatch=job } })
    broadcastFleet()
    cb({ ok=true, job=job, message=(unit.callsign or 'Patruljen') .. ' er sat PÃ… OPGAVE.' })
end)

ESX.RegisterServerCallback('san_mdt:finishDispatchJob', function(source, cb, dispatchId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    local job = activeDispatchJobs[tostring(dispatchId or '')]
    if not job then return cb({ ok=false, message='Opgaven findes ikke lÃ¦ngere.' }) end

    -- Any responding patrol can close the incident globally.
    if job.responders then
        for unitId, _ in pairs(job.responders) do
            local unit = activeFleetUnits[unitId]
            if unit then
                if unit.activeDispatches then unit.activeDispatches[job.id] = nil end
                unit.taskCount = math.max(0, tonumber(unit.taskCount or 0) - 1)
                if unit.taskCount == 0 then unit.status = 'Online' end
                mdtAuditLog(source, 'Patruljer', 'FLEET_TASK_FINISHED', { target_type='fleet_unit', target_id=unitId, target_label=unit.callsign or unit.plate or unitId, message='Patruljen afsluttede opgave: '..tostring(job.title or job.id), metadata={ dispatch=job } })
            end
        end
    elseif job.assignedUnit and activeFleetUnits[job.assignedUnit] then
        local unit = activeFleetUnits[job.assignedUnit]
        unit.taskCount = math.max(0, tonumber(unit.taskCount or 0) - 1)
        if unit.taskCount == 0 then unit.status = 'Online' end
    end
    job.status = 'Afsluttet'
    job.finishedAt = mdtNow()
    mdtAuditLog(source, 'Dispatch', 'DISPATCH_FINISHED', { target_type='dispatch', target_id=job.id, target_label=job.title, message='Afsluttede dispatch-opgave', metadata=job })
    activeDispatchJobs[job.id] = nil
    broadcastFleet()
    cb({ ok=true, message='Opgave afsluttet.' })
end)

ESX.RegisterServerCallback('san_mdt:getFleetData', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, units = {} }) end
    local snap = fleetSnapshot()
    if GetResourceState('povh') == 'started' then
        snap.units = exports.povh:FilterFleetUnits(snap.units)
    end
    snap.viewerService = fleetPlayerService(xPlayer) or 'police'
    snap.selfIdentifier = getMdtIdentifier(xPlayer)
    snap.selfOnDuty = isOfficerOnDuty(xPlayer, source)
    snap.selfOfficer = activeDutyOfficers[mdtOfficerKey(xPlayer, source)] or mdtOfficerPayload(xPlayer, source)
    snap.crossServiceView = Config and Config.FleetCrossServiceView == true
    cb(snap)
end)

ESX.RegisterServerCallback('san_mdt:toggleFleetUnit', function(source, cb, unitId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    unitId = tostring(unitId or '')
    local unit = activeFleetUnits[unitId]
    if not unit then return cb({ ok=false, message='KÃ¸retÃ¸jet er ikke lÃ¦ngere aktivt.' }) end
    local sameService, serviceMsg = fleetSameServiceOrDeny(xPlayer, unit)
    if not sameService then return cb({ ok=false, message=serviceMsg }) end
    unit.joined = unit.joined or {}
    local identifier = getMdtIdentifier(xPlayer); if identifier == '' then identifier = tostring(source) end
    if not isOfficerOnDuty(xPlayer, source) then
        return cb({ ok=false, message='Du skal gÃ¥ pÃ¥ arbejde under Min Profil fÃ¸r du kan tilmelde dig en patrulje.' })
    end
    if unit.joined[identifier] then
        unit.joined[identifier] = nil
        officerPatrolIndex[identifier] = nil
        mdtAuditLog(source, 'Patruljer', 'FLEET_LEFT', { target_type='fleet_unit', target_id=unitId, target_label=unit.callsign or unit.plate or unitId, message='Frakoblede sig patrulje/enhed', metadata={ unit=unit } })
    else
        local currentPatrol = officerPatrolIndex[identifier]
        if currentPatrol and currentPatrol ~= unitId and activeFleetUnits[currentPatrol] then
            return cb({ ok=false, message='Du skal forlade din nuvÃ¦rende patrulje fÃ¸rst.' })
        end
        local badge = fleetGetOfficerPNumber(xPlayer, source)
        unit.joined[identifier] = { name = getOfficerName(xPlayer, source), badge = badge, source = source }
        officerPatrolIndex[identifier] = unitId
        mdtAuditLog(source, 'Patruljer', 'FLEET_JOINED', { target_type='fleet_unit', target_id=unitId, target_label=unit.callsign or unit.plate or unitId, message='Tilmeldte sig patrulje/enhed', metadata={ unit=unit } })
    end
    broadcastFleet()
    cb({ ok=true, unit=unit })
end)

ESX.RegisterServerCallback('san_mdt:updateFleetUnitSettings', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    data = data or {}
    local unitId = tostring(data.unitId or '')
    local unit = activeFleetUnits[unitId]
    if not unit then return cb({ ok=false, message='KÃ¸retÃ¸jet er ikke lÃ¦ngere aktivt.' }) end
    local sameService, serviceMsg = fleetSameServiceOrDeny(xPlayer, unit)
    if not sameService then return cb({ ok=false, message=serviceMsg }) end
    local category = tostring(data.category or unit.category or 'patrulje'):lower()
    if category ~= 'patrulje' and category ~= 'motorcykel' and category ~= 'civil' then category = 'patrulje' end
    local callsign = trim(data.callsign or '')
    unit.category = category
    if callsign ~= '' then unit.callsign = callsign else unit.callsign = fleetDefaultCallsign(category) end
    unit.status = tostring(data.status or unit.status or 'Online')
    unit.taskCount = tonumber(data.taskCount or unit.taskCount or 0) or 0
    mdtAuditLog(source, 'Patruljer', 'FLEET_SETTINGS_UPDATED', { target_type='fleet_unit', target_id=unitId, target_label=unit.callsign or unit.plate or unitId, message='Ã†ndrede patruljeindstillinger', metadata={ category=category, callsign=unit.callsign, status=unit.status } })
    broadcastFleet()
    cb({ ok=true, unit=unit })
end)

AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = getPlayer(src)
    if xPlayer then invalidatePermissionCache(getIdentifier(xPlayer)) end
    setOfficerOffDuty(xPlayer, src, 'Loggede ud / disconnect')
    if xPlayer then mdtSetSession(xPlayer, src, false) end
    local changed = false
    for _, unit in pairs(activeFleetUnits) do
        if unit.source == src then
            unit.source = 0
            unit.driver = 'Ingen chauffÃ¸r'
            changed = true
        end
    end
    if changed then broadcastFleet() end
end)

ESX.RegisterServerCallback('san_mdt:getVehicles', function(source, cb, search)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, vehicles = {} }) end
    search = trim(search)
    if search == '' then return cb({ ok = true, vehicles = {} }) end

    local userCols = getUserColumns()
    local userNameSelect = buildUserNameSelect('u')
    local selectName = userNameSelect ~= '' and ("u.identifier AS owner_identifier, " .. userNameSelect) or "u.identifier AS owner_identifier"
    if userCols['phone_number'] then selectName = selectName .. ", u.phone_number AS phone_number" end
    if userCols['phone'] then selectName = selectName .. ", u.phone AS phone" end
    if userCols['dateofbirth'] then selectName = selectName .. ", u.dateofbirth AS dateofbirth" end
    if userCols['dob'] then selectName = selectName .. ", u.dob AS dob" end

    local vehCols = getTableColumns('owned_vehicles')
    local typeSelect = vehCols['type'] and 'ov.type' or "NULL AS type"
    local storedSelect = vehCols['stored'] and 'ov.stored' or '0 AS stored'
    local poundSelect = vehCols['pound'] and 'ov.pound' or "NULL AS pound"
    local parkingSelect = vehCols['parking'] and 'ov.parking' or "NULL AS parking"
    local q = '%' .. search .. '%'
    local where = { 'ov.plate LIKE ?', 'ov.owner LIKE ?', 'ov.vehicle LIKE ?' }
    local params = { q, q, q }
    for _, c in ipairs({ 'name', 'firstname', 'lastname', 'first_name', 'last_name', 'phone_number', 'phone', 'dateofbirth', 'dob' }) do
        if userCols[c] then
            where[#where + 1] = ('u.%s LIKE ?'):format(c)
            params[#params + 1] = q
        end
    end

    local rows = MySQL.query.await(([[
        SELECT ov.plate, ov.owner, ov.vehicle, %s, %s, %s, %s, ov.impound_type, ov.impound_locked, ov.impound_reason, ov.impound_officer, ov.impound_time, %s
        FROM owned_vehicles ov
        LEFT JOIN users u ON u.identifier = ov.owner
        WHERE %s
        ORDER BY ov.plate ASC
        LIMIT 35
    ]]):format(typeSelect, storedSelect, poundSelect, parkingSelect, selectName, table.concat(where, ' OR ')), params) or {}

    local vehicles = {}
    for i = 1, #rows do
        local r = rows[i]
        local props = decodeJson(r.vehicle, {})
        local ownerName = getUserName({
            identifier = r.owner,
            name = r.owner_name,
            firstname = r.firstname,
            lastname = r.lastname,
            first_name = r.first_name,
            last_name = r.last_name
        })
        local status = 'Ude'
        if tonumber(r.stored or 0) == 1 then status = 'I garage' end
        if tonumber(r.stored or 0) == 2 or (r.pound and r.pound ~= '') then status = 'Impound' end
        if tostring(r.impound_type or '') == 'permanent' then status = 'Permanent beslaglagt' end
        if tonumber(r.impound_locked or 0) == 1 or tostring(r.impound_type or '') == 'locked' then status = status .. ' / LÃ¥st' end
        vehicles[#vehicles + 1] = {
            plate = r.plate,
            owner = r.owner,
            ownerName = ownerName,
            model = resolveVehicleModelName(props.modelName or props.vehicleName or props.name or props.model),
            modelHash = props.model,
            type = tostring(r.type or props.type or props.vehicleType or 'Ukendt type'),
            status = status,
            locked = ((tonumber(r.impound_locked or 0) or 0) == 1 or tostring(r.impound_type or '') == 'locked') and 1 or 0,
            impound_type = tostring(r.impound_type or 'normal'),
            reason = r.impound_reason,
            officer = r.impound_officer,
            impound_time = r.impound_time,
            image = props.image or props.img or props.thumbnail or ''
        }
    end
    cb({ ok = true, vehicles = vehicles, canReturn = canReturnPermanent(xPlayer), canReturnLocked = canReturnLockedImpound(xPlayer), canReturnPermanent = canReturnPermanentImpound(xPlayer) })
end)

ESX.RegisterServerCallback('san_mdt:getPermanentVehicles', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ vehicles = {}, canReturn = false }) end
    local vehCols = getTableColumns('owned_vehicles')
    local typeSelect = vehCols['type'] and 'type' or 'NULL AS type'
    local storedSelect = vehCols['stored'] and 'stored' or '0 AS stored'
    local poundSelect = vehCols['pound'] and 'pound' or 'NULL AS pound'
    local rows = MySQL.query.await(([[SELECT plate, owner, vehicle, %s, impound_reason, impound_officer, impound_time, impound_type, impound_locked, %s, %s
        FROM owned_vehicles
        WHERE COALESCE(impound_type, 'normal') IN ('permanent','locked') OR COALESCE(impound_locked, 0) = 1
        ORDER BY COALESCE(impound_time, 0) DESC, plate ASC]]):format(typeSelect, storedSelect, poundSelect), {}) or {}
    local vehicles = {}
    for i = 1, #rows do
        local props = {}
        pcall(function() props = json.decode(rows[i].vehicle or '{}') or {} end)
        local status = 'LÃ¥st'
        if tostring(rows[i].impound_type or '') == 'permanent' then status = 'Permanent beslaglagt' end
        if (tonumber(rows[i].impound_locked or 0) == 1 or tostring(rows[i].impound_type or '') == 'locked') and status ~= 'LÃ¥st' then status = status .. ' / LÃ¥st' end
        vehicles[#vehicles + 1] = {
            plate = rows[i].plate, owner = rows[i].owner,
            model = props.modelName or props.vehicleName or props.name or props.model or 'Ukendt model',
            type = rows[i].type or props.type or props.vehicleType or 'Ukendt type',
            reason = rows[i].impound_reason, officer = rows[i].impound_officer, time = rows[i].impound_time,
            status = status, locked = ((tonumber(rows[i].impound_locked or 0) or 0) == 1 or tostring(rows[i].impound_type or '') == 'locked') and 1 or 0
        }
    end
    cb({ vehicles = vehicles, canReturn = canReturnPermanent(xPlayer), canReturnLocked = canReturnLockedImpound(xPlayer), canReturnPermanent = canReturnPermanentImpound(xPlayer) })
end)

ESX.RegisterServerCallback('san_mdt:returnPermanentVehicle', function(source, cb, plate, price)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then
        return cb({ ok = false, message = 'Ingen MDT adgang.' })
    end

    plate = trim(plate)
    price = tonumber(price) or 0
    if price < 0 then price = 0 end
    if price > Config.MaxReturnPrice then price = Config.MaxReturnPrice end
    if plate == '' then return cb({ ok = false, message = 'Manglende nummerplade.' }) end

    local ok, resp = pcall(function()
        ensureOwnedVehicleImpoundColumns()
        local impoundName = Config.DefaultImpound or 'LosSantos'
        local officer = getOfficerName(xPlayer, source)

        local exists = MySQL.single.await([[SELECT plate, impound_type, impound_locked, stored FROM owned_vehicles WHERE REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '') LIMIT 1]], { plate })
        if not exists then
            return { ok = false, message = ('KÃ¸retÃ¸jet %s blev ikke fundet i owned_vehicles.'):format(plate) }
        end
        local permanent = tostring(exists.impound_type or 'normal') == 'permanent'
        local locked = tonumber(exists.impound_locked or 0) == 1 or tostring(exists.impound_type or '') == 'locked'
        if not permanent and not locked then
            return { ok = false, message = ('KÃ¸retÃ¸jet %s er normal impound uden lÃ¥s og skal hentes af ejeren via kaution.'):format(plate) }
        end
        if permanent and not canReturnPermanentImpound(xPlayer) then
            return { ok = false, message = 'KrÃ¦ver permission: vehicles.impound.permanent.release' }
        end
        if locked and not permanent and not canReturnLockedImpound(xPlayer) then
            return { ok = false, message = 'KrÃ¦ver permission: vehicles.impound.locked.release' }
        end

        local changed = MySQL.update.await([[UPDATE owned_vehicles SET
            stored = 2,
            pound = ?,
            impound_price = ?,
            impound_type = 'normal',
            impound_locked = 0,
            impound_reason = 'Frigivet fra lÃ¥st/permanent impound',
            impound_officer = ?,
            impound_time = UNIX_TIMESTAMP()
            WHERE REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '')
              AND (COALESCE(impound_type, 'normal') IN ('permanent','locked') OR COALESCE(impound_locked, 0) = 1)
        ]], { impoundName, price, officer, plate }) or 0

        if changed < 1 then
            return { ok = false, message = 'Database blev ikke opdateret. Tjek nummerplade/status.' }
        end

        return {
            ok = true,
            message = ('KÃ¸retÃ¸jet %s er frigivet til %s impound. Kaution: %s DKK'):format(plate, impoundName, price),
            plate = plate,
            price = price,
            pound = impoundName
        }
    end)

    if ok then
        if resp and resp.ok then
            mdtAuditLog(source, 'KÃ¸retÃ¸jer', 'VEHICLE_RELEASED', {
                target_type = 'vehicle',
                target_id = plate,
                target_label = plate,
                message = resp.message or ('Frigav kÃ¸retÃ¸j %s'):format(plate),
                metadata = { price = price, pound = resp.pound }
            })
        end
        cb(resp or { ok = false, message = 'Ukendt fejl.' })
    else
        print(('[san_mdt] returnPermanentVehicle error for %s: %s'):format(plate, resp))
        cb({ ok = false, message = 'Databasefejl ved frigivelse. Se server console.' })
    end
end)


RegisterNetEvent('san_mdt:returnPermanentVehicleEvent', function(plate, price)
    local source = source
    local xPlayer = getPlayer(source)
    if not canReturnPermanent(xPlayer) then
        if xPlayer and xPlayer.showNotification then xPlayer.showNotification('Du har ikke permission til at frigive lÃ¥ste/permanente impounds.') end
        return
    end

    plate = trim(plate)
    price = tonumber(price) or 0
    if price < 0 then price = 0 end
    if price > (Config.MaxReturnPrice or 1000000) then price = Config.MaxReturnPrice or 1000000 end
    if plate == '' then
        if xPlayer and xPlayer.showNotification then xPlayer.showNotification('Manglende nummerplade.') end
        return
    end

    CreateThread(function()
        local ok, err = pcall(function()
            ensureOwnedVehicleImpoundColumns()
            local impoundName = Config.DefaultImpound or 'LosSantos'
            local officer = getOfficerName(xPlayer, source)
            local changed = MySQL.update.await([[UPDATE owned_vehicles SET
                stored = 2,
                pound = ?,
                impound_price = ?,
                impound_type = 'normal',
                impound_locked = 0,
                impound_reason = 'Frigivet fra lÃ¥st/permanent impound',
                impound_officer = ?,
                impound_time = UNIX_TIMESTAMP()
                WHERE REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '')
                  AND (COALESCE(impound_type, 'normal') IN ('permanent','locked') OR COALESCE(impound_locked, 0) = 1)
            ]], { impoundName, price, officer, plate }) or 0

            if changed > 0 then
                if xPlayer and xPlayer.showNotification then
                    xPlayer.showNotification(('KÃ¸retÃ¸jet %s er frigivet til normal impound. Kaution: %s DKK'):format(plate, price))
                end
            else
                if xPlayer and xPlayer.showNotification then
                    xPlayer.showNotification(('Kunne ikke finde lÃ¥st/permanent impound-kÃ¸retÃ¸j: %s'):format(plate))
                end
            end
        end)
        if not ok then
            print(('[san_mdt] returnPermanentVehicleEvent error for %s: %s'):format(tostring(plate), tostring(err)))
            if xPlayer and xPlayer.showNotification then xPlayer.showNotification('Databasefejl ved frigivelse. Tjek server console.') end
        end
    end)
end)


CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_employee_meta (
        identifier VARCHAR(64) NOT NULL,
        division VARCHAR(80) NOT NULL DEFAULT 'Patrulje',
        pnumber VARCHAR(32) NULL,
        profile_image TEXT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    
    pcall(function() MySQL.query.await('ALTER TABLE mdt_employee_meta ADD COLUMN profile_image TEXT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_employee_meta ADD COLUMN mdt_username VARCHAR(32) NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_employee_meta ADD COLUMN mdt_password VARCHAR(255) NULL', {}) end)
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_roles (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(80) NOT NULL UNIQUE,
        permissions LONGTEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_employee_permissions (
        identifier VARCHAR(80) NOT NULL,
        permission VARCHAR(64) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(identifier, permission)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_mail (
        id INT NOT NULL AUTO_INCREMENT,
        recipient VARCHAR(128) NOT NULL DEFAULT 'all',
        sender VARCHAR(128) NOT NULL DEFAULT '',
        subject VARCHAR(255) NOT NULL DEFAULT '',
        body LONGTEXT NULL,
        department VARCHAR(128) NULL,
        summary VARCHAR(255) NULL,
        recipient_type VARCHAR(32) NOT NULL DEFAULT 'private',
        seen_at TIMESTAMP NULL DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN department VARCHAR(128) NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN summary VARCHAR(255) NULL', {}) end)
    pcall(function() MySQL.query.await("ALTER TABLE mdt_mail ADD COLUMN recipient_type VARCHAR(32) NOT NULL DEFAULT 'private'", {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN seen_at TIMESTAMP NULL DEFAULT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN thread_id INT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN parent_id INT NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN sender_identifier VARCHAR(80) NULL', {}) end)
    pcall(function() MySQL.query.await('ALTER TABLE mdt_mail ADD COLUMN reply_allowed TINYINT(1) NOT NULL DEFAULT 1', {}) end)
    pcall(function() MySQL.update.await('UPDATE mdt_mail SET thread_id = id WHERE thread_id IS NULL', {}) end)
    pcall(function() MySQL.update.await('UPDATE mdt_mail SET reply_allowed = 1 WHERE reply_allowed IS NULL', {}) end)
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_mail_reads (
        mail_id INT NOT NULL,
        identifier VARCHAR(128) NOT NULL,
        seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (mail_id, identifier),
        INDEX idx_identifier_seen (identifier, seen_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
end)

local RoleGradeMap = {
    ['Elev'] = 0,
    ['Betjent'] = 1,
    ['Assistent'] = 2,
    ['Assistent 1. Grad'] = 3,
    ['Kommissær'] = 4,
    ['NSK Chef'] = 5,
    ['NSK Afdeling'] = 4,
    ['Inspektør'] = 6,
    ['Rigspolitiet'] = 7,
    ['Receptionist'] = 0,
    ['Rengøring'] = 0,
    ['Suspenderet'] = 0
}
canAdminEmployees = function(xPlayer)
    local job = getJob(xPlayer)
    if not job then return false end
    if not isPoliceJobName(job.name) then return false end
    local grade = tonumber(job.grade or job.grade_number or 0) or 0
    local gradeName = tostring(job.grade_name or job.name_grade or job.grade_label or ''):lower()
    if grade >= 7 or gradeName == 'rigspolitiet' or gradeName == 'boss' then return true end
    return roleHasPermission(xPlayer, 'administration.view') or roleHasPermission(xPlayer, 'admin.roles.manage')
end
local function getEmployeeRole(jobGrade, gradeLabel, division)
    local n = tonumber(jobGrade or 0) or 0
    local map = {[0]='Elev',[1]='Betjent',[2]='Assistent',[3]='Assistent 1. Grad',[4]='Kommissær',[5]='NSK Chef',[6]='Inspektør',[7]='Rigspolitiet'}
    if trim(division or ''):lower() == 'nsk' and n <= 5 then return 'NSK Afdeling' end
    if map[n] then return map[n] end
    if gradeLabel and gradeLabel ~= '' then return gradeLabel end
    return 'Grade '..n
end

local function canUseEvidenceLocker(xPlayer)
    if roleHasPermission(xPlayer, Config.EvidenceLockerPermission or 'evidence.locker') then return true end
    local job = getJob(xPlayer)
    if not job or not isPoliceJobName(job.name) then return false end
    local grade = tonumber(job.grade or job.grade_number or 0) or 0
    local gradeName = tostring(job.grade_name or job.name_grade or job.grade_label or ''):lower()
    return grade >= (Config.EvidenceLockerMinGrade or 7) or gradeName == 'rigspolitiet' or gradeName == 'boss'
end

ESX.RegisterServerCallback('san_mdt:prepareEvidenceLocker', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Du har ikke adgang til MDT.' }) end
    if not canUseEvidenceLocker(xPlayer) then return cb({ ok=false, message='Du har ikke permission til evidence locker.' }) end
    if GetResourceState('ox_inventory') ~= 'started' then
        return cb({ ok=false, message='ox_inventory er ikke startet pÃ¥ serveren.' })
    end

    data = data or {}
    local incidentId = tonumber(data.incidentId)
    local incidentNo = trim(data.incidentNo or '')
    if not incidentId and incidentNo == '' then
        return cb({ ok=false, message='Gem eller vÃ¦lg en hÃ¦ndelse fÃ¸r du Ã¥bner evidence locker.' })
    end

    local labelNo = incidentNo ~= '' and incidentNo or tostring(incidentId)
    local stashId = 'mdt_evidence_' .. safeLockerId(labelNo)
    local label = 'Evidence Locker #' .. labelNo
    local slots = tonumber(Config.EvidenceLockerSlots or 80) or 80
    local weight = tonumber(Config.EvidenceLockerWeight or 500000) or 500000

    local ok, err = pcall(function()
        exports.ox_inventory:RegisterStash(stashId, label, slots, weight, false)
    end)
    if not ok then
        print(('[san_mdt] RegisterStash error: %s'):format(tostring(err)))
        return cb({ ok=false, message='Kunne ikke registrere evidence locker. Tjek ox_inventory/server console.' })
    end

    cb({ ok=true, stashId=stashId, label=label, message='Evidence locker Ã¥bnes.' })
end)


ESX.RegisterServerCallback('san_mdt:getEmployees', function(source, cb, search)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, employees={} }) end
    search = trim(search)
    local cols = getUserColumns()
    local fields = {'identifier','job','job_grade'}
    for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do if cols[c] then fields[#fields+1]=c end end
    local where = "job = ?"
    local params = { Config.PoliceJob or 'police' }
    if search ~= '' then
        where = where .. " AND (identifier LIKE ?"
        params[#params+1] = '%'..search..'%'
        for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do
            if cols[c] then where = where .. (" OR %s LIKE ?"):format(c); params[#params+1] = '%'..search..'%' end
        end
        where = where .. ")"
    end
    local selectFields = 'u.`'..table.concat(fields,'`,u.`')..'`, m.division AS mdt_division, m.pnumber AS mdt_pnumber, m.profile_image AS mdt_profile_image, m.mdt_username AS mdt_username, m.mdt_password AS mdt_password'
    local sql = ('SELECT %s FROM users u LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier WHERE %s ORDER BY u.job_grade DESC LIMIT 80'):format(selectFields, where:gsub('job = %?', 'u.job = ?'):gsub('identifier LIKE %?', 'u.identifier LIKE ?'))
    for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do
        sql = sql:gsub(' OR '..c..' LIKE %?', ' OR u.'..c..' LIKE ?')
    end
    local rows = MySQL.query.await(sql, params) or {}
    local out = {}
    for i=1,#rows do
        local r=rows[i]
        local directPerms = collectEmployeePermissions(r.identifier)
        local division = tostring(r.mdt_division or 'Patrulje')
        local pnumber = tostring(r.mdt_pnumber or r.job_grade or '')
        local badge = fleetFormatPNumber(pnumber, division)
        out[#out+1] = {
            identifier=r.identifier, name=getUserName(r), pnumber=pnumber, badge=badge,
            role=getEmployeeRole(r.job_grade, nil, division), division=division, permissions=directPerms,
            profile_image=tostring(r.mdt_profile_image or ''), mdt_username=tostring(r.mdt_username or badge), mdt_password=tostring(r.mdt_password or '')
        }
    end
    cb({ ok=true, employees=out, canEdit=canAdminEmployees(xPlayer) })
end)

ESX.RegisterServerCallback('san_mdt:updateEmployee', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, message='Kun Rigspolitiet kan Ã¦ndre ansatte.' }) end

    local ok, resp = pcall(function()
        data = data or {}
        local identifier = trim(data.identifier)
        if identifier == '' then return { ok=false, message='Manglende identifier.' } end

        if data.fire then
            local target = getOnlinePlayerByIdentifier(identifier)
            if target and target.setJob then
                pcall(function() target.setJob('unemployed', 0) end)
            else
                MySQL.update.await("UPDATE users SET job = 'unemployed', job_grade = 0 WHERE identifier = ?", { identifier })
            end
            invalidatePermissionCache(identifier)
            mdtAuditLog(source, 'Ansatte', 'EMPLOYEE_FIRED', { target_type='employee', target_id=identifier, message='Afskedigede medarbejder' })
            return { ok=true, message='Medarbejder afskediget. Rollen er Ã¦ndret ingame hvis spilleren er online.' }
        end

        local role = tostring(data.role or '')
        local grade = RoleGradeMap[role] or tonumber(data.pnumber) or 0
        grade = tonumber(grade) or 0
        if grade < 0 then grade = 0 end
        if grade > 7 then grade = 7 end

        local division = trim(data.division or 'Patrulje')
        if division == '' then division = 'Patrulje' end
        local badgePrefix = normalizeBadgePrefix(trim(data.badge_prefix or data.badgePrefix or ''), division)
        local pnumberDigits = normalizePnumberDigits(trim(data.pnumber or tostring(grade)))
        local pnumber = buildPoliceBadge(badgePrefix, pnumberDigits, division)
        local profileImage = trim(data.profile_image or data.profileImage or '')
        local mdtPassword = trim(data.mdt_password or data.mdtPassword or '')
        local mdtUsername = pnumber ~= '' and pnumber or fleetFormatPNumber(pnumberDigits, division)
        MySQL.update.await('INSERT INTO mdt_employee_meta (identifier, division, pnumber, profile_image, mdt_username, mdt_password) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE division = VALUES(division), pnumber = VALUES(pnumber), profile_image = VALUES(profile_image), mdt_username = VALUES(mdt_username), mdt_password = VALUES(mdt_password)', { identifier, division, pnumber, profileImage, mdtUsername, mdtPassword })

        local _, online = applyPoliceGrade(identifier, grade)
        invalidatePermissionCache(identifier)
        mdtOfficerListCache = { at = 0, grouped = nil, count = 0 }
        mdtAuditLog(source, 'Ansatte', 'EMPLOYEE_UPDATED', { target_type='employee', target_id=identifier, target_label=role, message='Opdaterede medarbejder', metadata={ role=role, grade=grade, division=division, pnumber=pnumber, profile_image=profileImage, mdt_username=mdtUsername } })
        return {
            ok=true,
            message = online and 'Medarbejder opdateret. Rollen er Ã¦ndret ingame med det samme.' or 'Medarbejder opdateret i databasen. Spilleren fÃ¥r rollen ved nÃ¦ste login.'
        }
    end)

    if ok then
        cb(resp or { ok=false, message='Ukendt fejl.' })
    else
        print(('[san_mdt] updateEmployee error: %s'):format(tostring(resp)))
        cb({ ok=false, message='Database/serverfejl ved opdatering af medarbejder. Se server console.' })
    end
end)


ESX.RegisterServerCallback('san_mdt:saveEmployeePermissions', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) and not roleHasPermission(xPlayer, 'admin.roles.manage') then
        return cb({ ok=false, message='Du har ikke adgang til at Ã¦ndre permissions.' })
    end
    data = data or {}
    local identifier = trim(data.identifier or '')
    if identifier == '' then return cb({ ok=false, message='Manglende identifier.' }) end
    local clean, seen = {}, {}
    for _, perm in ipairs(data.permissions or {}) do
        perm = trim(perm)
        if perm ~= '' and not seen[perm] then seen[perm] = true; clean[#clean+1] = perm end
    end
    MySQL.update.await('DELETE FROM mdt_employee_permissions WHERE identifier = ?', { identifier })
    for _, perm in ipairs(clean) do
        MySQL.insert.await('INSERT IGNORE INTO mdt_employee_permissions (identifier, permission) VALUES (?, ?)', { identifier, perm })
    end
    invalidatePermissionCache(identifier)
    mdtAuditLog(source, 'Ansatte', 'EMPLOYEE_PERMISSIONS_SAVED', { target_type='employee', target_id=identifier, message='Gemte direkte medarbejder-permissions', metadata={ permissions=clean } })
    cb({ ok=true, message='Permissions gemt.', permissions=clean })
end)

ESX.RegisterServerCallback('san_mdt:getRoles', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, roles={}, message='Ingen MDT adgang.' }) end
    if not canAdminEmployees(xPlayer) and not roleHasPermission(xPlayer, 'admin.roles.manage') then
        return cb({ ok=false, roles={}, message='Ingen adgang til rolle-administration.' })
    end
    local ok, resp = pcall(function()
        local rows = MySQL.query.await('SELECT name, permissions FROM mdt_roles ORDER BY name ASC', {}) or {}
        local roles, seen = {}, {}
        local defaults = {'Rigspolitiet','Inspektør','NSK Chef','NSK Afdeling','Kommissær','Assistent 1. Grad','Assistent','Betjent','Elev','Receptionist','Rengøring','Suspenderet'}
        for _, name in ipairs(defaults) do
            roles[#roles+1] = { name=name, permissions={} }
            seen[name:lower()] = #roles
        end
        for i=1,#rows do
            local name = tostring(rows[i].name or '')
            if name ~= '' then
                local key = name:lower()
                local obj = { name=name, permissions=normalizePermissions(rows[i].permissions) }
                if seen[key] then roles[seen[key]] = obj else roles[#roles+1] = obj end
            end
        end
        return { ok=true, roles=roles }
    end)
    cb(ok and resp or { ok=false, roles={}, message='Kunne ikke hente roller.' })
end)

ESX.RegisterServerCallback('san_mdt:saveRole', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, message='Kun Rigspolitiet kan administrere roller.' }) end
    local name = trim(data and data.name)
    if name == '' then return cb({ ok=false, message='Mangler rollenavn.' }) end
    local allowed = {}
    for _, p in ipairs(getPermissionCatalog()) do allowed[p.key] = true end
    local clean, seen = {}, {}
    for _, perm in ipairs((data and data.permissions) or {}) do
        perm = trim(perm)
        if allowed[perm] and not seen[perm] then seen[perm] = true; clean[#clean+1] = perm end
    end
    local permissions = json.encode(clean)
    MySQL.update.await('INSERT INTO mdt_roles (name, permissions) VALUES (?, ?) ON DUPLICATE KEY UPDATE permissions = VALUES(permissions)', { name, permissions })
    clearPermissionCache()
    print(('[san_mdt][PERM] Rolle %s gemt med permissions: %s'):format(name, table.concat(clean, ', ')))
    mdtAuditLog(source, 'Roller', 'ROLE_SAVED', { target_type='role', target_id=name, target_label=name, message='Gemte rolle permissions', metadata={ permissions=clean } })
    cb({ ok=true, message='Rolle gemt og permissions opdateret for alle med rollen.' })
end)

ESX.RegisterServerCallback('san_mdt:deleteRole', function(source, cb, name)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, message='Kun Rigspolitiet kan fjerne roller.' }) end
    name = trim(name)
    if name ~= '' then MySQL.update.await('DELETE FROM mdt_roles WHERE name = ?', { name }); clearPermissionCache(); mdtAuditLog(source, 'Roller', 'ROLE_DELETED', { target_type='role', target_id=name, target_label=name, message='Fjernede rolle' }) end
    cb({ ok=true, message='Rolle fjernet.' })
end)


ESX.RegisterServerCallback('san_mdt:getPermissionDebug', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen MDT adgang.' }) end
    cb(buildPermissionDebug(xPlayer))
end)

ESX.RegisterServerCallback('san_mdt:getPermissionCatalog', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, catalog={} }) end
    cb({ ok=true, catalog=getPermissionCatalog(), debug=buildPermissionDebug(xPlayer) })
end)

-- Shared API for server/main_tail.lua + server/login_callbacks.lua (separate chunks avoid Lua 200-local limit)
_G.SanMdt = {
    trim = trim,
    decodeJson = decodeJson,
    getPlayer = getPlayer,
    getPlayerByIdentifier = getPlayerByIdentifier,
    getPlayerSourceSafe = getPlayerSourceSafe,
    hasJobAccess = hasJobAccess,
    noAccessResponse = noAccessResponse,
    getJob = getJob,
    getOfficerName = getOfficerName,
    getMdtIdentifier = getMdtIdentifier,
    mdtAuditLog = mdtAuditLog,
    mdtAuditFilterRows = mdtAuditFilterRows,
    MDT_AUDIT_LOG_CATEGORIES = MDT_AUDIT_LOG_CATEGORIES,
    auditRow = auditRow,
    fleetFormatPNumber = fleetFormatPNumber,
    fleetGetOfficerPNumber = fleetGetOfficerPNumber,
    normalizePersonIdentifier = normalizePersonIdentifier,
    getUserColumns = getUserColumns,
    getUserName = getUserName,
    buildUserNameSelect = buildUserNameSelect,
    getEmployeeRole = getEmployeeRole,
    canAdminEmployees = canAdminEmployees,
    canAccessNsk = canAccessNsk,
    canManageNsk = canManageNsk,
    canViewMdtLogs = canViewMdtLogs,
    canRegisterProfileGang = canRegisterProfileGang,
    roleHasPermission = roleHasPermission,
    playerPermissionSet = playerPermissionSet,
    resolveVehicleModelName = resolveVehicleModelName,
    vehicleStatusFromRow = vehicleStatusFromRow,
    getLinkedReportsForPlate = getLinkedReportsForPlate,
    isOfficerOnDuty = isOfficerOnDuty,
    getDashboardPoliceJobNames = getDashboardPoliceJobNames,
    isPoliceJobName = isPoliceJobName,
    getOnlinePlayerByIdentifier = getOnlinePlayerByIdentifier,
    invalidatePermissionCache = invalidatePermissionCache,
    initials = initials,
    clearOfficerListCache = function()
        mdtOfficerListCache.at = 0
        mdtOfficerListCache.grouped = nil
        mdtOfficerListCache.count = 0
    end,
}
print('[san_mdt] server/main.lua loaded (SanMdt API ready)')

do
    local function buildSelfProfileOfficerLookup()
        local byName, byIdentifier = {}, {}
        local cols = getUserColumns()
        local fields = { 'identifier', 'job', 'job_grade' }
        for _, c in ipairs({ 'firstname', 'lastname', 'first_name', 'last_name', 'name' }) do
            if cols[c] then fields[#fields + 1] = c end
        end
        local selectFields = 'u.`' .. table.concat(fields, '`,u.`') .. '`, m.pnumber AS mdt_pnumber, m.division AS mdt_division'
        local rows = MySQL.query.await(('SELECT %s FROM users u LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier WHERE u.job = ?'):format(selectFields), { Config.PoliceJob or 'police' }) or {}
        for i = 1, #rows do
            local r = rows[i]
            local name = getUserName(r)
            local div = tostring(r.mdt_division or 'Patrulje')
            local pnum = tostring(r.mdt_pnumber or r.job_grade or '')
            local info = {
                identifier = r.identifier,
                name = name,
                badge = fleetFormatPNumber(pnum, div),
                role = getEmployeeRole(r.job_grade, nil, div),
                division = div,
            }
            if name ~= '' then byName[tostring(name):lower()] = info end
            if r.identifier and r.identifier ~= '' then byIdentifier[r.identifier] = info end
        end
        return byName, byIdentifier
    end

    local function enrichSelfProfileMailRow(mail, byName, byIdentifier, direction)
        mail.mail_direction = direction or 'received'
        local dept = tostring(mail.department or '')
        local badge = dept:match('Privat mail fra%s+([A-Z]%d%d%d%d)')
        if badge then mail.sender_badge = badge end
        local senderInfo = mail.sender and byName[tostring(mail.sender):lower()] or nil
        if senderInfo then
            if not mail.sender_badge or mail.sender_badge == '' then mail.sender_badge = senderInfo.badge end
            mail.sender_role = senderInfo.role
        end
        if direction == 'sent' then
            local recipInfo = mail.recipient and byIdentifier[mail.recipient] or nil
            if recipInfo then
                mail.recipient_name = recipInfo.name
                mail.recipient_badge = recipInfo.badge
                mail.recipient_role = recipInfo.role
            else
                mail.recipient_name = mail.recipient or 'Ukendt'
            end
            mail.recipient_seen = tonumber(mail.recipient_seen or 0) or 0
        else
            mail.unread = tonumber(mail.unread or 0) or 0
        end
        return mail
    end

    ESX.RegisterServerCallback('san_mdt:getSelfProfile', function(source, cb)
        local xPlayer = getPlayer(source)
        if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
        local ok, resp = pcall(function()
            local job = getJob(xPlayer) or {}
            local identifier = getMdtIdentifier(xPlayer)
            local meta = nil
            if identifier ~= '' then
                local rows = MySQL.query.await('SELECT division, pnumber, profile_image FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { identifier }) or {}
                meta = rows[1]
            end
            local role = getEmployeeRole(job.grade, job.grade_label)
            local division = tostring((meta and meta.division) or 'Patrulje')
            local pnumber = tostring((meta and meta.pnumber) or job.grade or '')
            local senderName = getOfficerName(xPlayer, source)
            local byName, byIdentifier = buildSelfProfileOfficerLookup()
            local mails = MySQL.query.await([[
                SELECT m.id, m.sender, m.sender_identifier, m.subject, m.body, m.department, m.recipient_type,
                       m.thread_id, m.parent_id, m.created_at,
                       COALESCE(r.seen_at, m.seen_at) AS seen_at,
                       CASE WHEN COALESCE(r.seen_at, m.seen_at) IS NULL THEN 1 ELSE 0 END AS unread,
                       (SELECT COUNT(*) FROM mdt_mail t WHERE COALESCE(t.thread_id, t.id) = COALESCE(m.thread_id, m.id)) AS thread_count
                FROM mdt_mail m
                LEFT JOIN mdt_mail_reads r ON r.mail_id = m.id AND r.identifier = ?
                WHERE m.recipient_type = 'private' AND m.recipient = ?
                ORDER BY m.created_at DESC LIMIT 20
            ]], { identifier, identifier }) or {}
            for i = 1, #mails do
                mails[i] = enrichSelfProfileMailRow(mails[i], byName, byIdentifier, 'received')
            end
            local sentMails = MySQL.query.await([[
                SELECT m.id, m.sender, m.sender_identifier, m.recipient, m.subject, m.body, m.department, m.recipient_type,
                       m.thread_id, m.parent_id, m.created_at,
                       CASE WHEN COALESCE(r.seen_at, m.seen_at) IS NULL THEN 0 ELSE 1 END AS recipient_seen,
                       COALESCE(r.seen_at, m.seen_at) AS recipient_seen_at,
                       (SELECT COUNT(*) FROM mdt_mail t WHERE COALESCE(t.thread_id, t.id) = COALESCE(m.thread_id, m.id)) AS thread_count
                FROM mdt_mail m
                LEFT JOIN mdt_mail_reads r ON r.mail_id = m.id AND r.identifier = m.recipient
                WHERE m.recipient_type = 'private' AND (m.sender = ? OR m.sender_identifier = ?)
                ORDER BY m.created_at DESC LIMIT 20
            ]], { senderName, identifier }) or {}
            for i = 1, #sentMails do
                sentMails[i] = enrichSelfProfileMailRow(sentMails[i], byName, byIdentifier, 'sent')
            end
            return {
                ok = true,
                profile = {
                    identifier = identifier,
                    name = senderName,
                    role = role,
                    division = division,
                    pnumber = pnumber,
                    badge = fleetFormatPNumber(pnumber, division),
                    job = job.name or '',
                    profile_image = tostring((meta and meta.profile_image) or ''),
                    mails = mails,
                    sentMails = sentMails,
                    unread = (function()
                        local n = 0
                        for _, m in ipairs(mails) do
                            if tonumber(m.unread or 0) == 1 then n = n + 1 end
                        end
                        return n
                    end)(),
                },
            }
        end)
        if ok then
            cb(resp)
        else
            print(('[san_mdt] getSelfProfile error: %s'):format(tostring(resp)))
            cb({ ok = false, message = 'Kunne ikke hente Min Profil. Se server console.' })
        end
    end)

    local function wiretapReady()
        return GetResourceState('narkosalg') == 'started'
    end

    ESX.RegisterServerCallback('san_mdt:getWiretapSession', function(source, cb)
        local xPlayer = getPlayer(source)
        if not hasJobAccess(xPlayer) then return cb({ ok = false }) end
        if not wiretapReady() then return cb({ ok = true, session = nil }) end
        local session = exports.narkosalg:GetActiveWiretap(source)
        if not session then return cb({ ok = true, session = nil }) end
        cb({
            ok = true,
            session = session,
            logs = exports.narkosalg:GetWiretapFeed(session.phoneId) or {},
        })
    end)

    ESX.RegisterServerCallback('san_mdt:writeAuditLog', function(source, cb, data)
        local xPlayer = getPlayer(source)
        if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
        data = data or {}
        mdtAuditLog(source, trim(data.category or 'System'), trim(data.action or 'MDT_ACTION'), {
            target_type = trim(data.target_type or ''),
            target_id = trim(data.target_id or ''),
            target_label = trim(data.target_label or ''),
            message = trim(data.message or ''),
            metadata = data.metadata or {},
        })
        cb({ ok = true })
    end)

    print('[san_mdt] login callbacks registered (getSelfProfile/writeAuditLog/getWiretapSession)')
end

local function krimUserNameExpr(alias)
    alias = alias or 'u'
    return ("TRIM(CONCAT(COALESCE(%s.firstname,''), ' ', COALESCE(%s.lastname,'')))"):format(alias, alias)
end

ESX.RegisterServerCallback('san_mdt:getKrimDna', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, rows = {} }) end

    local search = type(data) == 'table' and trim(data.search or '') or ''
    local like = '%' .. search:lower() .. '%'
    local nameExpr = krimUserNameExpr('u')

    local rows = MySQL.query.await(([[
        SELECT p.identifier, p.dna_id, p.dna_collected_at, %s AS name
        FROM mdt_civilian_profiles p
        LEFT JOIN users u ON u.identifier = p.identifier
        WHERE p.dna_id IS NOT NULL AND p.dna_id <> ''
        AND (? = '' OR LOWER(p.dna_id) LIKE ? OR LOWER(p.identifier) LIKE ? OR LOWER(%s) LIKE ?)
        ORDER BY p.dna_collected_at DESC
        LIMIT 100
    ]]):format(nameExpr, nameExpr), { search, like, like, like }) or {}

    cb({ ok = true, rows = rows })
end)

ESX.RegisterServerCallback('san_mdt:getKrimFingerprints', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, rows = {} }) end

    local search = type(data) == 'table' and trim(data.search or '') or ''
    local like = '%' .. search:lower() .. '%'
    local nameExpr = krimUserNameExpr('u')

    local rows = MySQL.query.await(([[
        SELECT p.identifier, p.fingerprint_id, p.fingerprint_collected_at, %s AS name
        FROM mdt_civilian_profiles p
        LEFT JOIN users u ON u.identifier = p.identifier
        WHERE p.fingerprint_id IS NOT NULL AND p.fingerprint_id <> ''
        AND (? = '' OR LOWER(p.fingerprint_id) LIKE ? OR LOWER(p.identifier) LIKE ? OR LOWER(%s) LIKE ?)
        ORDER BY p.fingerprint_collected_at DESC
        LIMIT 100
    ]]):format(nameExpr, nameExpr), { search, like, like, like }) or {}

    cb({ ok = true, rows = rows })
end)

local function loadSanMdtServerChunk(relPath, label)
    local src = LoadResourceFile(GetCurrentResourceName(), relPath)
    if not src or src == '' then
        print(('[san_mdt] WARN: %s mangler'):format(relPath))
        return false
    end
    local fn, err = load(src, ('@san_mdt/%s'):format(relPath), 't', _G)
    if not fn then
        print(('[san_mdt] FATAL: kunne ikke compile %s: %s'):format(label or relPath, tostring(err)))
        return false
    end
    local ok, runErr = pcall(fn)
    if not ok then
        print(('[san_mdt] FATAL: %s runtime error: %s'):format(label or relPath, tostring(runErr)))
        return false
    end
    return true
end

loadSanMdtServerChunk('server/anpg_sync.lua', 'anpg_sync')

local tailSource = LoadResourceFile(GetCurrentResourceName(), 'server/main_tail.lua')
if tailSource and tailSource ~= '' and not _G.SanMdtTailLoaded then
    local tailFn, tailErr = load(tailSource, '@san_mdt/server/main_tail.lua', 't', _G)
    if not tailFn then
        print(('[san_mdt] FATAL: kunne ikke compile main_tail.lua: %s'):format(tostring(tailErr)))
    else
        local ok, runErr = pcall(tailFn)
        if not ok then
            print(('[san_mdt] FATAL: main_tail.lua runtime error: %s'):format(tostring(runErr)))
        end
    end
elseif not _G.SanMdtTailLoaded then
    print('[san_mdt] WARN: server/main_tail.lua mangler - mail/charges/NSK callbacks er ikke tilgaengelige')
end

