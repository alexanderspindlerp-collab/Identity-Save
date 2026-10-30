print('[san_mdt] server/main_tail.lua starting...')
local ESX = exports['es_extended']:getSharedObject()
local SanMdt = _G.SanMdt
if not SanMdt then
    print('[san_mdt] FATAL: _G.SanMdt API mangler. server/main.lua skal loades foer main_tail.lua.')
    return
end
local S = SanMdt
local trim, decodeJson, getPlayer, getPlayerByIdentifier, getPlayerSourceSafe = S.trim, S.decodeJson, S.getPlayer, S.getPlayerByIdentifier, S.getPlayerSourceSafe
local hasJobAccess, noAccessResponse, getJob, getOfficerName, getMdtIdentifier = S.hasJobAccess, S.noAccessResponse, S.getJob, S.getOfficerName, S.getMdtIdentifier
local mdtAuditLog, mdtAuditFilterRows, MDT_AUDIT_LOG_CATEGORIES, auditRow = S.mdtAuditLog, S.mdtAuditFilterRows, S.MDT_AUDIT_LOG_CATEGORIES, S.auditRow
local fleetFormatPNumber, fleetGetOfficerPNumber, normalizePersonIdentifier = S.fleetFormatPNumber, S.fleetGetOfficerPNumber, S.normalizePersonIdentifier
local getUserColumns, getUserName, buildUserNameSelect, getEmployeeRole = S.getUserColumns, S.getUserName, S.buildUserNameSelect, S.getEmployeeRole
local canAdminEmployees, canAccessNsk, canManageNsk, canViewMdtLogs, roleHasPermission, canRegisterProfileGang = S.canAdminEmployees, S.canAccessNsk, S.canManageNsk, S.canViewMdtLogs, S.roleHasPermission, S.canRegisterProfileGang
local playerPermissionSet, resolveVehicleModelName, vehicleStatusFromRow, getLinkedReportsForPlate = S.playerPermissionSet, S.resolveVehicleModelName, S.vehicleStatusFromRow, S.getLinkedReportsForPlate
local isOfficerOnDuty, getDashboardPoliceJobNames, isPoliceJobName, getOnlinePlayerByIdentifier = S.isOfficerOnDuty, S.getDashboardPoliceJobNames, S.isPoliceJobName, S.getOnlinePlayerByIdentifier
local invalidatePermissionCache, initials, clearOfficerListCache = S.invalidatePermissionCache, S.initials, S.clearOfficerListCache
local buildPoliceOfficerLookup

local function resolveSenderIdentifier(senderName, senderIdentifier, byIdentifier, byName)
    if senderIdentifier and tostring(senderIdentifier) ~= '' then return tostring(senderIdentifier) end
    local info = senderName and byName[tostring(senderName):lower()] or nil
    return info and info.identifier or ''
end

local function mailParticipantMatches(mail, identifier, senderName)
    if not mail or identifier == '' then return false end
    if tostring(mail.recipient or '') == identifier then return true end
    if mail.sender_identifier and tostring(mail.sender_identifier) == identifier then return true end
    if senderName and mail.sender and tostring(mail.sender):lower() == tostring(senderName):lower() then return true end
    return false
end

local function mailThreadRootId(mail)
    if not mail then return 0 end
    return tonumber(mail.thread_id or mail.id or 0) or 0
end

local function mailReplyIsAllowed(v)
    if v == nil then return true end
    if v == true or v == 1 or v == '1' then return true end
    if v == false or v == 0 or v == '0' then return false end
    return tonumber(v) == 1
end

local function ensureReplySubject(subject)
    subject = trim(subject or '')
    if subject == '' then return 'Svar' end
    if subject:lower():sub(1, 4) == 're: ' then return subject end
    return 'Re: ' .. subject
end

ESX.RegisterServerCallback('san_mdt:sendMail', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen MDT adgang.' }) end
    data = data or {}
    local subject = trim(data.subject)
    local body = trim(data.body)
    local targetType = trim(data.targetType or 'private')
    local recipient = trim(data.to or '')
    local department = trim(data.department or '')
    local summary = trim(data.summary or '')
    local replyToId = tonumber(data.replyToId or data.parentId or 0) or 0
    if body == '' then return cb({ ok=false, message='Udfyld mail-indhold.' }) end

    local senderName = getOfficerName(xPlayer, source)
    local senderIdentifier = getMdtIdentifier(xPlayer)
    local senderBadge = fleetGetOfficerPNumber(xPlayer, source)
    local threadId, parentId = nil, nil
    local byName, byIdentifier = buildPoliceOfficerLookup()

    if replyToId > 0 then
        targetType = 'private'
        local parent = MySQL.single.await('SELECT id, recipient, sender, sender_identifier, subject, thread_id, recipient_type FROM mdt_mail WHERE id = ? LIMIT 1', { replyToId })
        if not parent or tostring(parent.recipient_type or '') ~= 'private' then
            return cb({ ok=false, message='Mail-trÃ¥den blev ikke fundet.' })
        end
        if not mailParticipantMatches(parent, senderIdentifier, senderName) then
            return cb({ ok=false, message='Du kan kun svare pÃ¥ mails du er del af.' })
        end
        threadId = mailThreadRootId(parent)
        local root = MySQL.single.await('SELECT id, reply_allowed FROM mdt_mail WHERE id = ? LIMIT 1', { threadId })
        if not root then return cb({ ok=false, message='Mail-trÃ¥den blev ikke fundet.' }) end
        if not mailReplyIsAllowed(root.reply_allowed) then
            return cb({ ok=false, message='Svar er lukket for denne trÃ¥d. Kontakt Rigspolitiet.' })
        end
        if senderIdentifier == tostring(parent.recipient or '') then
            recipient = resolveSenderIdentifier(parent.sender, parent.sender_identifier, byIdentifier, byName)
        else
            recipient = tostring(parent.recipient or '')
        end
        if recipient == '' then return cb({ ok=false, message='Kunne ikke finde modtager til svar.' }) end
        subject = ensureReplySubject(parent.subject)
        parentId = replyToId
        if senderBadge ~= '' then
            department = ('Privat mail fra %s'):format(senderBadge)
        else
            department = 'Privat mail'
        end
    else
        if subject == '' then return cb({ ok=false, message='Udfyld titel/emne og mail indhold.' }) end
        if targetType == 'frontpage' then
            if not canAdminEmployees(xPlayer) then return cb({ ok=false, message='Kun Rigspolitiet kan sende forsidenyheder.' }) end
            recipient = 'frontpage'
            if department == '' then department = 'Rigspolitiet' end
            if summary == '' then summary = body:sub(1, 180) end
        else
            targetType = 'private'
            if recipient == '' then return cb({ ok=false, message='VÃ¦lg en politi-profil som modtager.' }) end
            if senderBadge ~= '' then
                department = ('Privat mail fra %s'):format(senderBadge)
            elseif department == '' then
                department = 'Privat mail'
            end
        end
    end

    mdtAuditLog(source, 'Administration', 'MAIL_SENT', {
        target_type='mail', target_label=subject, message=replyToId > 0 and 'Svarede i MDT-mailtrÃ¥d' or 'Sendte MDT-mail',
        metadata={ recipient=recipient, type=targetType, subject=subject, department=department, sender_badge=senderBadge, reply_to=replyToId, thread_id=threadId }
    })

    local insertId = MySQL.insert.await([[
        INSERT INTO mdt_mail (recipient, sender, sender_identifier, subject, body, department, summary, recipient_type, parent_id, thread_id, reply_allowed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
    ]], {
        recipient, senderName, senderIdentifier, subject, body, department, summary, targetType,
        parentId, threadId
    })

    local mailRow = nil
    if insertId then
        if not threadId then
            MySQL.update.await('UPDATE mdt_mail SET thread_id = ? WHERE id = ?', { insertId, insertId })
            threadId = insertId
        end
        mailRow = MySQL.single.await([[
            SELECT id, subject, subject AS title, COALESCE(summary, body) AS description, body,
                   department, sender, sender_identifier, created_at, recipient_type, recipient,
                   thread_id, parent_id, reply_allowed, 1 AS unread, 1 AS mail
            FROM mdt_mail
            WHERE id = ?
            LIMIT 1
        ]], { insertId })
        if mailRow and targetType == 'private' and senderBadge ~= '' then
            mailRow.sender_badge = senderBadge
        end
    end
    cb({
        ok=true,
        message = replyToId > 0 and 'Svar sendt.' or (targetType == 'frontpage' and 'Nyhed sendt til forsiden.' or 'Privat mail sendt.'),
        mail = mailRow,
        id = insertId,
        threadId = threadId
    })
end)

ESX.RegisterServerCallback('san_mdt:getMailThread', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen MDT adgang.' }) end
    data = data or {}
    local mailId = tonumber(data.mailId or data.id or 0) or 0
    if mailId <= 0 then return cb({ ok=false, message='Manglende mail-id.' }) end

    local anchor = MySQL.single.await('SELECT id, recipient, sender, sender_identifier, subject, thread_id, recipient_type, reply_allowed FROM mdt_mail WHERE id = ? LIMIT 1', { mailId })
    if not anchor or tostring(anchor.recipient_type or '') ~= 'private' then
        return cb({ ok=false, message='Mail ikke fundet.' })
    end

    local identifier = getMdtIdentifier(xPlayer)
    local senderName = getOfficerName(xPlayer, source)
    if not mailParticipantMatches(anchor, identifier, senderName) then
        return cb({ ok=false, message='Du har ikke adgang til denne mail-trÃ¥d.' })
    end

    local threadId = mailThreadRootId(anchor)
    local root = MySQL.single.await('SELECT id, reply_allowed, subject FROM mdt_mail WHERE id = ? LIMIT 1', { threadId }) or anchor
    local rows = MySQL.query.await([[
        SELECT id, recipient, sender, sender_identifier, subject, body, department, created_at, parent_id, thread_id
        FROM mdt_mail
        WHERE thread_id = ? OR id = ?
        ORDER BY created_at ASC, id ASC
        LIMIT 100
    ]], { threadId, threadId }) or {}

    local byName, byIdentifier = buildPoliceOfficerLookup()
    local messages = {}
    for i = 1, #rows do
        local row = rows[i]
        local info = row.sender_identifier and byIdentifier[row.sender_identifier] or (row.sender and byName[tostring(row.sender):lower()] or nil)
        messages[#messages + 1] = {
            id = row.id,
            recipient = row.recipient,
            sender = row.sender,
            sender_identifier = row.sender_identifier,
            sender_badge = info and info.badge or '',
            sender_name = row.sender,
            subject = row.subject,
            body = row.body,
            department = row.department,
            created_at = row.created_at,
            parent_id = row.parent_id,
            is_mine = (row.sender_identifier and row.sender_identifier == identifier) or (senderName and row.sender and tostring(row.sender):lower() == tostring(senderName):lower()),
        }
    end

    local replyAllowed = mailReplyIsAllowed(root.reply_allowed)
    cb({
        ok = true,
        threadId = threadId,
        mailId = mailId,
        subject = root.subject or anchor.subject,
        replyAllowed = replyAllowed,
        canReply = replyAllowed,
        canManageReplies = canAdminEmployees(xPlayer),
        messages = messages,
        myIdentifier = identifier,
    })
end)

ESX.RegisterServerCallback('san_mdt:setMailReplyAllowed', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, message='Kun Rigspolitiet kan Ã¦ndre svar-indstilling.' }) end
    data = data or {}
    local threadId = tonumber(data.threadId or data.mailId or 0) or 0
    if threadId <= 0 then return cb({ ok=false, message='Manglende trÃ¥d-id.' }) end
    local allowed = data.allowed ~= false and data.allowed ~= 0 and data.allowed ~= '0'
    MySQL.update.await('UPDATE mdt_mail SET reply_allowed = ? WHERE id = ?', { allowed and 1 or 0, threadId })
    mdtAuditLog(source, 'Administration', 'MAIL_REPLY_TOGGLED', {
        target_type='mail', target_id=tostring(threadId), message=allowed and 'Ã…bnede for svar i mail-trÃ¥d' or 'Lukkede for svar i mail-trÃ¥d',
        metadata={ thread_id=threadId, reply_allowed=allowed }
    })
    cb({ ok=true, message=allowed and 'Svar er tilladt i trÃ¥den.' or 'Svar er lukket i trÃ¥den.', replyAllowed=allowed })
end)

ESX.RegisterServerCallback('san_mdt:getMailDirectory', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, employees={} }) end
    data = data or {}
    local search = trim(data.search or '')
    local cols = getUserColumns()
    local fields = {'identifier','job','job_grade'}
    for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do if cols[c] then fields[#fields+1]=c end end
    local selectFields = 'u.`'..table.concat(fields,'`,u.`')..'`, m.pnumber AS mdt_pnumber, m.division AS mdt_division'
    local where = 'u.job = ?'
    local params = { Config.PoliceJob or 'police' }
    if search ~= '' then
        where = where .. ' AND (u.identifier LIKE ? OR m.pnumber LIKE ? OR m.mdt_username LIKE ?'
        params[#params+1] = '%'..search..'%'
        params[#params+1] = '%'..search..'%'
        params[#params+1] = '%'..search..'%'
        for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do
            if cols[c] then where = where .. (' OR u.%s LIKE ?'):format(c); params[#params+1] = '%'..search..'%' end
        end
        where = where .. ')'
    end
    local rows = MySQL.query.await(('SELECT %s FROM users u LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier WHERE %s ORDER BY u.job_grade DESC LIMIT 200'):format(selectFields, where), params) or {}
    local out = {}
    for i=1,#rows do
        local division = tostring(rows[i].mdt_division or 'Patrulje')
        local pnumber = tostring(rows[i].mdt_pnumber or rows[i].job_grade or '')
        out[#out+1] = {
            identifier=rows[i].identifier, name=getUserName(rows[i]), pnumber=pnumber,
            division=division, badge=fleetFormatPNumber(pnumber, division)
        }
    end
    cb({ ok=true, employees=out })
end)

ESX.RegisterServerCallback('san_mdt:getSentMailsForProfile', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, mails={} }) end
    data = data or {}
    local identifier = trim(data.identifier or '')
    if identifier == '' then return cb({ ok=false, mails={} }) end
    local rows = MySQL.query.await([[
        SELECT m.id, m.recipient, m.sender, m.subject, m.body, m.department, m.summary, m.recipient_type,
               COALESCE(r.seen_at, m.seen_at) AS seen_at, m.created_at,
               CASE WHEN COALESCE(r.seen_at, m.seen_at) IS NULL THEN 0 ELSE 1 END AS seen
        FROM mdt_mail m
        LEFT JOIN mdt_mail_reads r ON r.mail_id = m.id AND r.identifier = m.recipient
        WHERE m.recipient_type = 'private' AND m.recipient = ?
        ORDER BY m.created_at DESC LIMIT 100
    ]], { identifier }) or {}
    cb({ ok=true, mails=rows })
end)




ESX.RegisterServerCallback('san_mdt:getRecentNewsMails', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, news={} }) end
    data = data or {}
    local limit = tonumber(data.limit or 50) or 50
    if limit < 1 then limit = 50 end
    if limit > 100 then limit = 100 end

    local totalOfficers = MySQL.scalar.await('SELECT COUNT(*) FROM users WHERE job = ?', { Config.PoliceJob or 'police' }) or 0
    local rows = MySQL.query.await([[
        SELECT m.id, m.subject, m.subject AS title, m.body, m.department, m.summary, m.sender,
               m.created_at, m.recipient_type, m.recipient,
               COALESCE(rc.seen_count, 0) AS seen_count,
               ? AS total_count
        FROM mdt_mail m
        LEFT JOIN (
            SELECT mail_id, COUNT(DISTINCT identifier) AS seen_count
            FROM mdt_mail_reads
            GROUP BY mail_id
        ) rc ON rc.mail_id = m.id
        WHERE (m.recipient_type = 'frontpage' OR m.recipient = 'frontpage')
        ORDER BY m.created_at DESC
        LIMIT ?
    ]], { totalOfficers, limit }) or {}
    cb({ ok=true, news=rows })
end)

ESX.RegisterServerCallback('san_mdt:getNewsReadStatus', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, officers={} }) end
    data = data or {}
    local id = tonumber(data.id or 0) or 0
    if id <= 0 then return cb({ ok=false, officers={} }) end

    local cols = getUserColumns()
    local fields = {'identifier','job','job_grade'}
    for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do
        if cols[c] then fields[#fields+1] = c end
    end
    local selectFields = 'u.`' .. table.concat(fields, '`,u.`') .. '`, m.pnumber AS mdt_pnumber, m.division AS mdt_division, r.seen_at AS read_at'
    local rows = MySQL.query.await(('SELECT %s FROM users u LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier LEFT JOIN mdt_mail_reads r ON r.mail_id = ? AND r.identifier = u.identifier WHERE u.job = ? ORDER BY u.job_grade DESC, u.identifier ASC'):format(selectFields), { id, Config.PoliceJob or 'police' }) or {}
    local out = {}
    for i=1,#rows do
        local division = tostring(rows[i].mdt_division or 'Patrulje')
        local pnumber = tostring(rows[i].mdt_pnumber or rows[i].job_grade or '')
        out[#out+1] = {
            identifier = rows[i].identifier,
            name = getUserName(rows[i]),
            pnumber = pnumber,
            division = division,
            badge = fleetFormatPNumber(pnumber, division),
            seen = rows[i].read_at ~= nil,
            seen_at = rows[i].read_at
        }
    end
    cb({ ok=true, officers=out })
end)

ESX.RegisterServerCallback('san_mdt:markMailSeen', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb(noAccessResponse(source, xPlayer)) end
    data = data or {}
    local id = tonumber(data.id or 0) or 0
    if id <= 0 then return cb({ ok=false }) end

    local identifier = getMdtIdentifier(xPlayer)
    local row = MySQL.single.await('SELECT id, recipient, recipient_type FROM mdt_mail WHERE id = ? LIMIT 1', { id })
    if not row then return cb({ ok=false }) end

    local recipientType = tostring(row.recipient_type or '')
    local recipient = tostring(row.recipient or '')

    -- Frontpage/nyheder skal gemmes pr. betjent, ellers nulstilles de visuelt efter resource restart.
    if recipientType == 'frontpage' or recipient == 'frontpage' then
        MySQL.update.await([[
            INSERT INTO mdt_mail_reads (mail_id, identifier, seen_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON DUPLICATE KEY UPDATE seen_at = COALESCE(seen_at, CURRENT_TIMESTAMP)
        ]], { id, identifier })
        return cb({ ok=true })
    end

    -- Private mails mÃ¥ kun markeres som set af modtageren. Admin-preview i Mail System
    -- mÃ¥ IKKE gÃ¸re betjentens mail set.
    if recipientType == 'private' and recipient ~= identifier then
        return cb({ ok=true, skipped=true })
    end

    MySQL.update.await([[
        INSERT INTO mdt_mail_reads (mail_id, identifier, seen_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON DUPLICATE KEY UPDATE seen_at = COALESCE(seen_at, CURRENT_TIMESTAMP)
    ]], { id, identifier })
    MySQL.update.await('UPDATE mdt_mail SET seen_at = COALESCE(seen_at, CURRENT_TIMESTAMP) WHERE id = ?', { id })
    cb({ ok=true })
end)

ESX.RegisterServerCallback('san_mdt:getAuditLogs', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canViewMdtLogs(xPlayer) and not roleHasPermission(xPlayer, 'admin.logs.view') then return cb({ ok=false, message='Ingen adgang til MDT-Logs.', logs={}, categories={} }) end
    data = data or {}
    local category = trim(data.category or '')
    local officer = trim(data.officer or '')
    local q = trim(data.search or '')
    local limit = tonumber(data.limit or 150) or 150
    if limit < 25 then limit = 25 end
    if limit > 400 then limit = 400 end
    local where, params = {}, {}
    if category ~= '' and category ~= 'Alle' then
        if category == 'Administration' then
            where[#where+1] = "category IN ('Administration','Ansatte','Roller')"
        else
            where[#where+1] = 'category = ?'
            params[#params+1] = category
        end
    end
    if officer ~= '' then where[#where+1] = '(officer_name LIKE ? OR officer_identifier LIKE ? OR officer_badge LIKE ?)'; local qq='% '..officer..' %'; qq='%'..officer..'%'; params[#params+1]=qq; params[#params+1]=qq; params[#params+1]=qq end
    if q ~= '' then where[#where+1] = '(action LIKE ? OR message LIKE ? OR target_label LIKE ? OR target_id LIKE ?)'; local qq='% '..q..' %'; qq='%'..q..'%'; params[#params+1]=qq; params[#params+1]=qq; params[#params+1]=qq; params[#params+1]=qq end
    local sql = 'SELECT * FROM mdt_audit_logs'
    if #where > 0 then sql = sql .. ' WHERE ' .. table.concat(where, ' AND ') end
    sql = sql .. ' ORDER BY created_at DESC, id DESC LIMIT ' .. tostring(limit)
    local rows = MySQL.query.await(sql, params) or {}
    local out = {}
    for i = 1, #rows do out[#out + 1] = auditRow(rows[i]) end
    out = mdtAuditFilterRows(out)
    cb({ ok = true, logs = out, categories = MDT_AUDIT_LOG_CATEGORIES })
end)

ESX.RegisterServerCallback('san_mdt:getOfficerAuditTimeline', function(source, cb, identifier)
    local xPlayer = getPlayer(source)
    if not canViewMdtLogs(xPlayer) and not roleHasPermission(xPlayer, 'admin.logs.view') then return cb({ ok=false, logs={} }) end
    identifier = trim(identifier)
    if identifier == '' then return cb({ ok=false, logs={}, message='Mangler officer identifier.' }) end
    local rows = MySQL.query.await('SELECT * FROM mdt_audit_logs WHERE officer_identifier = ? ORDER BY created_at DESC, id DESC LIMIT 200', { identifier }) or {}
    local out = {}
    for i = 1, #rows do out[#out + 1] = auditRow(rows[i]) end
    out = mdtAuditFilterRows(out)
    cb({ ok = true, logs = out })
end)

ESX.RegisterServerCallback('san_mdt:getFleetUnitLogs', function(source, cb, unitId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, logs={} }) end
    unitId = trim(unitId)
    local rows = MySQL.query.await('SELECT * FROM mdt_audit_logs WHERE target_type = ? AND target_id = ? ORDER BY created_at DESC, id DESC LIMIT 100', { 'fleet_unit', unitId }) or {}
    local out = {}
    for i = 1, #rows do out[#out + 1] = auditRow(rows[i]) end
    out = mdtAuditFilterRows(out)
    cb({ ok = true, logs = out })
end)

ESX.RegisterServerCallback('san_mdt:getOfficerProfile', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen MDT adgang.' }) end

    local ok, resp = pcall(function()
        data = data or {}
        local identifier = trim(data.identifier or '')
        if identifier == '' then return { ok=false, message='Manglende identifier.' } end

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
        local rows = MySQL.query.await(
            ('SELECT %s FROM users u LEFT JOIN mdt_employee_meta m ON m.identifier = u.identifier WHERE u.identifier = ? AND LOWER(u.job) IN (%s) LIMIT 1')
                :format(selectFields, table.concat(placeholders, ',')),
            { identifier, table.unpack(jobParams) }
        ) or {}
        local row = rows[1]

        local target = getOnlinePlayerByIdentifier(identifier)
        local online, onDuty = false, false
        local division, role, pnumber, phone, profileImage, name

        if row then
            division = tostring(row.mdt_division or 'Patrulje')
            role = getEmployeeRole(row.job_grade, nil, division)
            pnumber = tostring(row.mdt_pnumber or row.job_grade or '')
            phone = tostring(row.phone_number or row.phone or '')
            profileImage = tostring(row.mdt_profile_image or '')
            name = getUserName(row)
        elseif target then
            local job = getJob(target) or {}
            if not isPoliceJobName(job.name) then
                return { ok=false, message='Betjent ikke fundet.' }
            end
            local meta = MySQL.single.await('SELECT division, pnumber, profile_image FROM mdt_employee_meta WHERE identifier = ? LIMIT 1', { identifier })
            division = (meta and meta.division and tostring(meta.division) ~= '') and tostring(meta.division) or 'Patrulje'
            role = getEmployeeRole(job.grade, job.grade_label, division)
            pnumber = tostring((meta and meta.pnumber) or job.grade or '')
            phone = ''
            profileImage = tostring((meta and meta.profile_image) or '')
            local src = getPlayerSourceSafe(target)
            name = getOfficerName(target, src)
        else
            return { ok=false, message='Betjent ikke fundet.' }
        end

        if target then
            online = true
            local src = getPlayerSourceSafe(target)
            name = getOfficerName(target, src)
            onDuty = isOfficerOnDuty(target, src)
        end

        local awards = MySQL.query.await([[
            SELECT id, award_key, award_label, note, granted_by, created_at
            FROM mdt_employee_awards
            WHERE identifier = ?
            ORDER BY created_at DESC
        ]], { identifier }) or {}

        return {
            ok = true,
            profile = {
                identifier = identifier,
                name = name,
                role = role,
                division = division,
                pnumber = pnumber,
                badge = fleetFormatPNumber(pnumber, division),
                phone = phone,
                profile_image = profileImage,
                online = online,
                onDuty = onDuty,
                awards = awards,
                canSendMail = hasJobAccess(xPlayer)
            }
        }
    end)

    if ok then
        cb(resp)
    else
        print(('[san_mdt] getOfficerProfile error: %s'):format(tostring(resp)))
        cb({ ok=false, message='Kunne ikke hente betjent-profil.' })
    end
end)

ESX.RegisterServerCallback('san_mdt:grantOfficerAward', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAdminEmployees(xPlayer) then return cb({ ok=false, message='Kun ledelse kan tildele awarder.' }) end
    data = data or {}
    local identifier = trim(data.identifier or '')
    local awardKey = trim(data.award_key or data.awardKey or 'brave')
    local awardLabel = trim(data.award_label or data.awardLabel or awardKey)
    local note = trim(data.note or '')
    if identifier == '' then return cb({ ok=false, message='Manglende identifier.' }) end
    if awardLabel == '' then awardLabel = awardKey end
    local grantedBy = getOfficerName(xPlayer, source)
    local insertId = MySQL.insert.await('INSERT INTO mdt_employee_awards (identifier, award_key, award_label, note, granted_by) VALUES (?, ?, ?, ?, ?)', {
        identifier, awardKey, awardLabel, note, grantedBy
    })
    clearOfficerListCache()
    mdtAuditLog(source, 'Ansatte', 'AWARD_GRANTED', { target_type='employee', target_id=identifier, target_label=awardLabel, message='Tildelte award', metadata={ award_key=awardKey, note=note } })
    cb({ ok=true, message='Award tildelt.', id=insertId })
end)

buildPoliceOfficerLookup = function()
    local byName, byIdentifier = {}, {}
    local cols = getUserColumns()
    local fields = {'identifier','job','job_grade'}
    for _, c in ipairs({'firstname','lastname','first_name','last_name','name'}) do
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

local function enrichPrivateMailRow(mail, byName, byIdentifier, direction)
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

-- === Sigtelser / Charges module ===
local function chargesColumnExists(columnName)
    local rows = MySQL.query.await('SHOW COLUMNS FROM mdt_charges LIKE ?', { columnName }) or {}
    return rows[1] ~= nil
end

local function ensureChargesTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_charges (
        id INT NOT NULL AUTO_INCREMENT,
        paragraph VARCHAR(32) NOT NULL DEFAULT '',
        name VARCHAR(160) NOT NULL DEFAULT '',
        description TEXT NULL,
        category VARCHAR(32) NOT NULL DEFAULT 'green',
        law_group VARCHAR(32) NOT NULL DEFAULT '',
        jail INT NOT NULL DEFAULT 0,
        fine INT NOT NULL DEFAULT 0,
        points INT NOT NULL DEFAULT 0,
        revocation VARCHAR(120) NOT NULL DEFAULT '',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        UNIQUE KEY paragraph_unique (paragraph),
        KEY category_idx (category),
        KEY law_group_idx (law_group)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})

    if not chargesColumnExists('law_group') then
        MySQL.query.await('ALTER TABLE mdt_charges ADD COLUMN law_group VARCHAR(32) NOT NULL DEFAULT "" AFTER category', {})
    end

    local hasUnique = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.statistics
        WHERE table_schema = DATABASE()
          AND table_name = 'mdt_charges'
          AND index_name = 'paragraph_unique'
    ]]) or 0
    if tonumber(hasUnique) == 0 then
        pcall(function()
            MySQL.query.await('ALTER TABLE mdt_charges ADD UNIQUE KEY paragraph_unique (paragraph)', {})
        end)
    end
end

local function upsertDefaultCharge(c)
    MySQL.query.await([[
        INSERT INTO mdt_charges (paragraph, name, description, category, law_group, jail, fine, points, revocation)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            description = VALUES(description),
            category = VALUES(category),
            law_group = VALUES(law_group),
            jail = VALUES(jail),
            fine = VALUES(fine),
            points = VALUES(points),
            revocation = VALUES(revocation),
            updated_at = CURRENT_TIMESTAMP
    ]], {
        c.paragraph,
        c.name,
        c.description,
        c.category,
        c.law_group or '',
        c.jail or 0,
        c.fine or 0,
        c.points or 0,
        c.revocation or ''
    })
end

local function syncChargeCatalog()
    ensureChargesTable()
    local version = Config.ChargeCatalogVersion or 'grundlov-1'
    local stored = GetResourceKvpString('san_mdt_charge_catalog_version') or ''
    if stored == version then return end

    for _, paragraph in ipairs(Config.LegacyChargeParagraphs or {}) do
        MySQL.update.await('DELETE FROM mdt_charges WHERE paragraph = ?', { paragraph })
    end

    for _, c in ipairs(Config.DefaultCharges or {}) do
        upsertDefaultCharge(c)
    end

    SetResourceKvp('san_mdt_charge_catalog_version', version)
end

CreateThread(function()
    Wait(500)
    syncChargeCatalog()
end)

local function getOfficerPerms(xPlayer)
    local permSet = playerPermissionSet(xPlayer)
    local job = getJob(xPlayer) or {}
    local grade = tonumber(job.grade or job.grade_number or 0) or 0
    local gradeName = tostring(job.grade_name or job.name_grade or job.grade_label or ''):lower()
    local isBoss = grade >= 7 or gradeName == 'rigspolitiet' or gradeName == 'boss'
    return {
        add = isBoss or permSet['charges.add'] == true,
        edit = isBoss or permSet['charges.edit'] == true,
        delete = isBoss or permSet['charges.delete'] == true
    }
end

local function cleanCharge(data)
    data = data or {}
    local category = trim(data.category or 'green')
    if category ~= 'green' and category ~= 'yellow' and category ~= 'orange' and category ~= 'red' and category ~= 'blue' then category = 'blue' end
    local lawGroup = trim(data.law_group or '')
    local allowedLawGroups = {
        straffelov = true,
        vaabenlov = true,
        narkoloven = true,
        trafikloven = true,
        erhvervsloven = true,
        luftfartoej = true,
        vagtloven = true
    }
    if lawGroup ~= '' and not allowedLawGroups[lawGroup] then lawGroup = '' end
    return {
        id = tonumber(data.id),
        paragraph = trim(data.paragraph or ''),
        name = trim(data.name or ''),
        description = trim(data.description or ''),
        category = category,
        law_group = lawGroup,
        jail = math.max(0, tonumber(data.jail or 0) or 0),
        fine = math.max(0, tonumber(data.fine or 0) or 0),
        points = math.max(0, tonumber(data.points or 0) or 0),
        revocation = trim(data.revocation or '')
    }
end

ESX.RegisterServerCallback('san_mdt:getCharges', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, charges={} }) end
    ensureChargesTable()
    data = data or {}
    local search = trim(data.search or '')
    local category = trim(data.category or '')
    local where, params = '1=1', {}
    if search ~= '' then
        where = where .. ' AND (paragraph LIKE ? OR name LIKE ? OR description LIKE ? OR category LIKE ?)'
        local q = '%' .. search .. '%'
        params[#params+1] = q
        params[#params+1] = q
        params[#params+1] = q
        params[#params+1] = q
    end
    if category ~= '' then
        where = where .. ' AND (category = ? OR law_group = ?)'
        params[#params+1] = category
        params[#params+1] = category
    end
    local rows = MySQL.query.await(('SELECT id, paragraph, name, description, category, law_group, jail, fine, points, revocation FROM mdt_charges WHERE %s ORDER BY FIELD(law_group, "straffelov", "vaabenlov", "narkoloven", "trafikloven", "erhvervsloven", "luftfartoej", "vagtloven"), CAST(paragraph AS UNSIGNED), paragraph ASC, name ASC LIMIT 500'):format(where), params) or {}
    cb({ ok=true, charges=rows, permissions=getOfficerPerms(xPlayer) })
end)

ESX.RegisterServerCallback('san_mdt:addCharge', function(source, cb, data)
    local xPlayer = getPlayer(source)
    local perms = getOfficerPerms(xPlayer)
    if not perms.add then return cb({ ok=false, message='Du har ikke permission til at tilfÃ¸je sigtelser.' }) end
    ensureChargesTable()
    local c = cleanCharge(data)
    if c.paragraph == '' or c.name == '' then return cb({ ok=false, message='Udfyld paragraf og navn.' }) end
    local id = MySQL.insert.await('INSERT INTO mdt_charges (paragraph, name, description, category, law_group, jail, fine, points, revocation) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { c.paragraph, c.name, c.description, c.category, c.law_group, c.jail, c.fine, c.points, c.revocation })
    cb({ ok=true, id=id, message='Sigtelse tilfÃ¸jet.' })
end)

ESX.RegisterServerCallback('san_mdt:updateCharge', function(source, cb, data)
    local xPlayer = getPlayer(source)
    local perms = getOfficerPerms(xPlayer)
    if not perms.edit then return cb({ ok=false, message='Du har ikke permission til at redigere sigtelser.' }) end
    ensureChargesTable()
    local c = cleanCharge(data)
    if not c.id then return cb({ ok=false, message='Manglende sigtelses-ID.' }) end
    if c.paragraph == '' or c.name == '' then return cb({ ok=false, message='Udfyld paragraf og navn.' }) end
    MySQL.update.await('UPDATE mdt_charges SET paragraph = ?, name = ?, description = ?, category = ?, law_group = ?, jail = ?, fine = ?, points = ?, revocation = ? WHERE id = ?', { c.paragraph, c.name, c.description, c.category, c.law_group, c.jail, c.fine, c.points, c.revocation, c.id })
    cb({ ok=true, message='Sigtelse gemt.' })
end)

ESX.RegisterServerCallback('san_mdt:deleteCharge', function(source, cb, data)
    local xPlayer = getPlayer(source)
    local perms = getOfficerPerms(xPlayer)
    if not perms.delete then return cb({ ok=false, message='Du har ikke permission til at slette sigtelser.' }) end
    local id = tonumber(data and data.id)
    if not id then return cb({ ok=false, message='Manglende sigtelses-ID.' }) end
    MySQL.update.await('DELETE FROM mdt_charges WHERE id = ?', { id })
    cb({ ok=true, message='Sigtelse slettet.' })
end)

-- ===================== TELEFON AFLYTNING (narkosalg) =====================
local function wiretapReady()
    return GetResourceState('narkosalg') == 'started'
end

ESX.RegisterServerCallback('san_mdt:startWiretap', function(source, cb, phoneId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen adgang.' }) end
    if not wiretapReady() then return cb({ ok=false, message='narkosalg er ikke startet.' }) end
    local ok, result = exports.narkosalg:StartWiretap(source, phoneId)
    if not ok then return cb({ ok=false, message=result or 'Kunne ikke starte aflytning.' }) end
    mdtAuditLog(source, 'Aflytning', 'WIRETAP_STARTED', {
        target_type = 'wiretap',
        target_id = tostring(result.phoneId or phoneId or ''),
        target_label = tostring(result.phoneId or phoneId or ''),
        message = ('Startede aflytning pÃ¥ %s'):format(tostring(result.phoneId or phoneId or '?')),
        metadata = { phoneId = result.phoneId, startedAt = result.startedAt }
    })
    cb({
        ok = true,
        phoneId = result.phoneId,
        startedAt = result.startedAt,
        session = result,
        logs = exports.narkosalg:GetWiretapFeed(result.phoneId) or {}
    })
end)

ESX.RegisterServerCallback('san_mdt:stopWiretap', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen adgang.' }) end
    if not wiretapReady() then return cb({ ok=false, message='narkosalg er ikke startet.' }) end
    local ok, result = exports.narkosalg:StopWiretap(source)
    if not ok then return cb({ ok=false, message=result or 'Ingen aktiv aflytning.' }) end
    mdtAuditLog(source, 'Aflytning', 'WIRETAP_STOPPED', {
        target_type = 'wiretap',
        target_id = tostring(result.id or result.phoneId or ''),
        target_label = tostring(result.phoneId or ''),
        message = ('Stoppede aflytning pÃ¥ %s (arkiv: %s)'):format(tostring(result.phoneId or '?'), tostring(result.id or 'arkiv')),
        metadata = result
    })
    cb({ ok=true, archive=result, message=('Aflytning gemt som %s.'):format(result.id or 'arkiv') })
end)

ESX.RegisterServerCallback('san_mdt:getWiretapLive', function(source, cb, phoneId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, logs={} }) end
    if not wiretapReady() then return cb({ ok=false, logs={} }) end
    local session = exports.narkosalg:GetActiveWiretap(source)
    if not session or session.phoneId ~= phoneId then return cb({ ok=false, logs={} }) end
    cb({ ok=true, logs=exports.narkosalg:GetWiretapFeed(phoneId) or {} })
end)

ESX.RegisterServerCallback('san_mdt:getWiretapArchives', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, archives={} }) end
    if not wiretapReady() then return cb({ ok=true, archives={} }) end
    cb({ ok=true, archives=exports.narkosalg:GetWiretapArchives() or {} })
end)

ESX.RegisterServerCallback('san_mdt:getWiretapArchive', function(source, cb, archiveId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false }) end
    if not wiretapReady() then return cb({ ok=false, message='narkosalg er ikke startet.' }) end
    local archive = exports.narkosalg:GetWiretapArchive(tostring(archiveId or ''))
    if not archive then return cb({ ok=false, message='Arkiv findes ikke.' }) end
    cb({ ok=true, archive=archive })
end)

ESX.RegisterServerCallback('san_mdt:getWiretapLock', function(source, cb, phoneId)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false }) end
    if not wiretapReady() then return cb({ ok=true, lock=nil }) end
    cb({ ok=true, lock=exports.narkosalg:GetWiretapLock(phoneId) })
end)

ESX.RegisterServerCallback('san_mdt:grantWiretapAccess', function(source, cb, phoneId, targetIdentifier)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok=false, message='Ingen adgang.' }) end
    if not wiretapReady() then return cb({ ok=false, message='narkosalg er ikke startet.' }) end
    local ok, result = exports.narkosalg:GrantWiretapAccess(source, phoneId, targetIdentifier)
    if not ok then return cb({ ok=false, message=result or 'Kunne ikke give adgang.' }) end
    mdtAuditLog(source, 'Aflytning', 'WIRETAP_ACCESS_GRANTED', {
        target_type = 'wiretap',
        target_id = tostring(phoneId or ''),
        target_label = tostring(targetIdentifier or ''),
        message = ('Gav aflytningsadgang til %s for telefon %s'):format(tostring(targetIdentifier or '?'), tostring(phoneId or '?')),
        metadata = { phoneId = phoneId, targetIdentifier = targetIdentifier, lock = result }
    })
    cb({ ok=true, lock=result })
end)

ESX.RegisterServerCallback('san_mdt:trackVehicle', function(source, cb, plate)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    plate = trim(plate)
    if plate == '' then return cb({ ok = false, message = 'Manglende nummerplade.' }) end

    local row = MySQL.single.await('SELECT stored, parking, pound FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate })
    if not row then return cb({ ok = false, message = 'KÃ¸retÃ¸j ikke fundet i register.' }) end

    if tonumber(row.stored or 0) == 1 then
        local garageKey = tostring(row.parking or '')
        local x, y, label = nil, nil, 'I garage'
        if GetResourceState('esx_garage') == 'started' then
            local ok, garages = pcall(function() return exports.esx_garage:getGarages() end)
            if ok and type(garages) == 'table' and garageKey ~= '' and garages[garageKey] then
                local g = garages[garageKey]
                local ep = g.EntryPoint or g.SpawnPoint
                if ep then
                    x = tonumber(ep.x)
                    y = tonumber(ep.y)
                    label = tostring(g.Label or garageKey)
                end
            end
        end
        local msg = x and ('KÃ¸retÃ¸jet er i garage: %s â€” GPS sat til indgang.'):format(label)
            or ('KÃ¸retÃ¸jet er parkeret i garage%s.'):format(garageKey ~= '' and (' (' .. garageKey .. ')') or '')
        pcall(function()
            MySQL.insert.await('INSERT INTO mdt_vehicle_tracks (plate, officer_name, officer_id, status_note, garage_label) VALUES (?, ?, ?, ?, ?)', {
                plate, getOfficerName(xPlayer, source), getMdtIdentifier(xPlayer), 'I garage', label
            })
        end)
        return cb({ ok = true, tracked = false, inGarage = true, garage = label, x = x, y = y, message = msg })
    end

    if tonumber(row.stored or 0) == 2 or (row.pound and tostring(row.pound) ~= '') then
        return cb({ ok = true, tracked = false, impound = true, message = 'KÃ¸retÃ¸jet er impoundet â€” live GPS er ikke tilgÃ¦ngelig.' })
    end

    pcall(function()
        MySQL.insert.await('INSERT INTO mdt_vehicle_tracks (plate, officer_name, officer_id, status_note) VALUES (?, ?, ?, ?)', {
            plate, getOfficerName(xPlayer, source), getMdtIdentifier(xPlayer), 'Live sporing â€” kÃ¸retÃ¸j ude'
        })
    end)
    cb({ ok = true, tracked = true, message = 'SÃ¸ger efter kÃ¸retÃ¸jet i verden...' })
end)

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS mdt_vehicle_tracks (
        id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        plate VARCHAR(16) NOT NULL,
        officer_name VARCHAR(128) NULL,
        officer_id VARCHAR(80) NULL,
        status_note VARCHAR(255) NULL,
        garage_label VARCHAR(128) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY plate_idx (plate)
    )]])
end)

ESX.RegisterServerCallback('san_mdt:getVehicleDetail', function(source, cb, plate, opts)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false }) end
    plate = trim(plate)
    if plate == '' then return cb({ ok = false, message = 'Manglende nummerplade.' }) end
    opts = type(opts) == 'table' and opts or {}
    local includeReports = opts.includeReports ~= false

    local userSelect = buildUserNameSelect('u')
    local userSelectSql = userSelect ~= '' and (', ' .. userSelect) or ''
    local row = MySQL.single.await(([[
        SELECT ov.plate, ov.owner, ov.vehicle, ov.type, ov.stored, ov.pound, ov.parking,
               ov.impound_type, ov.impound_locked, ov.impound_reason, ov.impound_officer, ov.impound_time%s
        FROM owned_vehicles ov
        LEFT JOIN users u ON u.identifier = ov.owner
        WHERE REPLACE(UPPER(TRIM(ov.plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '') LIMIT 1
    ]]):format(userSelectSql), { plate })
    if not row then return cb({ ok = false, message = 'KÃ¸retÃ¸j ikke fundet.' }) end

    local props = decodeJson(row.vehicle, {})
    local ownerName = getUserName({
        identifier = row.owner,
        name = row.owner_name,
        firstname = row.firstname,
        lastname = row.lastname,
        first_name = row.first_name,
        last_name = row.last_name
    })
    local prof = MySQL.single.await('SELECT profile_image, notes FROM mdt_vehicle_profiles WHERE plate = ? LIMIT 1', { row.plate }) or {}

    local anpgHit, anpgReason, anpgDetail = false, '', ''
    local okAnpg, anpgStatus = pcall(function()
        return exports['san_mdt']:GetAnpgPlateStatus(row.plate)
    end)
    if okAnpg and type(anpgStatus) == 'table' and anpgStatus.hit then
        anpgHit = true
        anpgReason = tostring(anpgStatus.reason or '')
        anpgDetail = tostring(anpgStatus.detail or '')
    end

    local status = vehicleStatusFromRow(row)
    if anpgHit and not string.find(string.lower(status), 'efterlyst', 1, true) then
        status = status .. ' / Efterlyst'
    end

    cb({
        ok = true,
        vehicle = {
            plate = row.plate,
            owner = row.owner,
            ownerName = ownerName,
            model = resolveVehicleModelName(props.modelName or props.vehicleName or props.name or props.model),
            modelHash = props.model,
            type = tostring(row.type or props.type or props.vehicleType or 'Ukendt type'),
            status = status,
            wanted = anpgHit,
            anpgReason = anpgReason,
            anpgDetail = anpgDetail,
            locked = ((tonumber(row.impound_locked or 0) or 0) == 1 or tostring(row.impound_type or '') == 'locked') and 1 or 0,
            impound_type = tostring(row.impound_type or 'normal'),
            reason = row.impound_reason,
            officer = row.impound_officer,
            impound_time = row.impound_time,
            parking = row.parking,
            image = tostring(prof.profile_image or props.image or props.img or ''),
            notes = tostring(prof.notes or ''),
            profile_image = tostring(prof.profile_image or ''),
            reports = includeReports and getLinkedReportsForPlate(row.plate) or nil
        }
    })
end)

ESX.RegisterServerCallback('san_mdt:getVehicleLinkedReports', function(source, cb, plate)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, reports = {} }) end
    plate = trim(plate)
    if plate == '' then return cb({ ok = false, reports = {}, message = 'Manglende nummerplade.' }) end
    cb({ ok = true, reports = getLinkedReportsForPlate(plate) })
end)

ESX.RegisterServerCallback('san_mdt:saveVehicleProfile', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    local plate = trim(data.plate or '')
    if plate == '' then return cb({ ok = false, message = 'Manglende nummerplade.' }) end
    MySQL.insert.await([[INSERT INTO mdt_vehicle_profiles (plate, profile_image, notes)
        VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE profile_image = VALUES(profile_image), notes = VALUES(notes)
    ]], { plate, tostring(data.profile_image or ''), tostring(data.notes or '') })
    mdtAuditLog(source, 'KÃ¸retÃ¸jsregister', 'VEHICLE_PROFILE_SAVED', { target_type = 'vehicle', target_id = plate, message = 'Gemte kÃ¸retÃ¸jsprofil' })
    cb({ ok = true, message = 'KÃ¸retÃ¸jsprofil gemt.' })
end)

ESX.RegisterServerCallback('san_mdt:getVehicleTracks', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, tracks = {} }) end
    local rows = MySQL.query.await('SELECT plate, officer_name, status_note, garage_label, created_at FROM mdt_vehicle_tracks ORDER BY id DESC LIMIT 80', {}) or {}
    cb({ ok = true, tracks = rows })
end)

ESX.RegisterServerCallback('san_mdt:getAssignedFiles', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, files = {} }) end
    local identifier = getMdtIdentifier(xPlayer)
    local officerName = getOfficerName(xPlayer, source)
    local files = {}
    local rows = MySQL.query.await('SELECT id, incident_no, title, officers, created_at, created_by FROM mdt_incidents ORDER BY id DESC LIMIT 250', {}) or {}
    for _, row in ipairs(rows) do
        for _, o in ipairs(decodeJson(row.officers, {})) do
            local oid = tostring(o.identifier or '')
            local oname = tostring(o.name or '')
            if (identifier ~= '' and oid == identifier) or (oname ~= '' and oname:lower() == officerName:lower()) then
                files[#files + 1] = {
                    kind = 'incident',
                    id = tostring(row.incident_no or row.id),
                    title = row.title or 'HÃ¦ndelse',
                    subtitle = 'Tildelt som betjent',
                    date = row.created_at,
                    created_by = row.created_by or ''
                }
                break
            end
        end
    end
    table.sort(files, function(a, b) return tostring(a.date or '') > tostring(b.date or '') end)
    cb({ ok = true, files = files })
end)

-- === NSK / Bandeintelligens ===
local function ensureNskTables()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nsk_gangs (
        id INT NOT NULL AUTO_INCREMENT,
        name VARCHAR(80) NOT NULL,
        tag VARCHAR(32) NULL,
        color VARCHAR(16) NOT NULL DEFAULT '#ff3048',
        threat_level VARCHAR(24) NOT NULL DEFAULT 'medium',
        status VARCHAR(24) NOT NULL DEFAULT 'active',
        notes TEXT NULL,
        created_by VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nsk_gang_members (
        id INT NOT NULL AUTO_INCREMENT,
        gang_id INT NOT NULL,
        identifier VARCHAR(80) NOT NULL,
        person_name VARCHAR(120) NULL,
        role VARCHAR(48) NOT NULL DEFAULT 'Medlem',
        notes TEXT NULL,
        active TINYINT(1) NOT NULL DEFAULT 1,
        registered_by VARCHAR(80) NULL,
        registered_by_name VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY gang_idx (gang_id),
        KEY identifier_idx (identifier)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nsk_territories (
        id INT NOT NULL AUTO_INCREMENT,
        gang_id INT NOT NULL,
        name VARCHAR(80) NOT NULL,
        color VARCHAR(16) NULL,
        center_x DOUBLE NOT NULL DEFAULT 0,
        center_y DOUBLE NOT NULL DEFAULT 0,
        radius DOUBLE NOT NULL DEFAULT 120,
        vertices_json LONGTEXT NULL,
        notes TEXT NULL,
        created_by VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY gang_idx (gang_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nsk_observations (
        id INT NOT NULL AUTO_INCREMENT,
        target_type VARCHAR(16) NOT NULL DEFAULT 'gang',
        gang_id INT NULL,
        identifier VARCHAR(80) NULL,
        person_name VARCHAR(120) NULL,
        subject VARCHAR(120) NOT NULL,
        body TEXT NULL,
        priority VARCHAR(16) NOT NULL DEFAULT 'normal',
        created_by VARCHAR(80) NULL,
        created_by_name VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY gang_idx (gang_id),
        KEY identifier_idx (identifier),
        KEY target_type_idx (target_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS nsk_gang_links (
        id INT NOT NULL AUTO_INCREMENT,
        gang_a_id INT NOT NULL,
        gang_b_id INT NOT NULL,
        relation_type VARCHAR(24) NOT NULL DEFAULT 'unknown',
        notes TEXT NULL,
        created_by VARCHAR(80) NULL,
        created_by_name VARCHAR(80) NULL,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (id),
        KEY gang_a_idx (gang_a_id),
        KEY gang_b_idx (gang_b_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]], {})
    pcall(function()
        MySQL.query.await('ALTER TABLE nsk_gang_members ADD COLUMN board_tier VARCHAR(24) NOT NULL DEFAULT \'unknown\' AFTER role', {})
    end)
    pcall(function()
        MySQL.query.await('ALTER TABLE nsk_gang_members ADD COLUMN board_rank INT NOT NULL DEFAULT 0 AFTER board_tier', {})
    end)
end

CreateThread(function()
    Wait(2600)
    pcall(ensureNskTables)
end)

function getProfileGangInfo(identifier)
    identifier = normalizePersonIdentifier(identifier)
    if identifier == '' then return nil end
    ensureNskTables()
    local row = MySQL.single.await([[
        SELECT m.id, m.gang_id, m.role, m.notes, m.created_at, g.name, g.tag, g.color, g.threat_level, g.status
        FROM nsk_gang_members m
        INNER JOIN nsk_gangs g ON g.id = m.gang_id
        WHERE m.identifier = ? AND m.active = 1
        LIMIT 1
    ]], { identifier })
    if not row then return nil end
    return {
        member_id = row.id,
        gang_id = row.gang_id,
        name = row.name,
        tag = row.tag,
        color = row.color,
        role = row.role,
        threat_level = row.threat_level,
        status = row.status,
        notes = row.notes,
        registered_at = row.created_at,
    }
end

local function decodeVertices(raw)
    if type(raw) == 'table' then return raw end
    if not raw or raw == '' then return nil end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return nil
end

local function serializeNskGang(row)
    if not row then return nil end
    return {
        id = row.id,
        name = row.name,
        tag = row.tag,
        color = row.color or '#ff3048',
        threat_level = row.threat_level or 'medium',
        status = row.status or 'active',
        notes = row.notes or '',
        member_count = tonumber(row.member_count or 0) or 0,
        territory_count = tonumber(row.territory_count or 0) or 0,
        created_at = row.created_at,
    }
end

ESX.RegisterServerCallback('san_mdt:getNskOverview', function(source, cb)
    local xPlayer = getPlayer(source)
    if not canAccessNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til NSK.' }) end
    ensureNskTables()
    local gangs = MySQL.query.await([[
        SELECT g.*,
            (SELECT COUNT(*) FROM nsk_gang_members m WHERE m.gang_id = g.id AND m.active = 1) AS member_count,
            (SELECT COUNT(*) FROM nsk_territories t WHERE t.gang_id = g.id) AS territory_count
        FROM nsk_gangs g
        ORDER BY g.name ASC
    ]], {}) or {}
    local members = MySQL.query.await([[
        SELECT m.id, m.gang_id, m.identifier, m.person_name, m.role, m.board_tier, m.board_rank, m.notes, m.created_at,
               g.name AS gang_name, g.color AS gang_color
        FROM nsk_gang_members m
        INNER JOIN nsk_gangs g ON g.id = m.gang_id
        WHERE m.active = 1
        ORDER BY m.board_tier ASC, m.board_rank ASC, m.created_at DESC
        LIMIT 250
    ]], {}) or {}
    local territories = MySQL.query.await([[
        SELECT t.*, g.name AS gang_name, g.color AS gang_color
        FROM nsk_territories t
        INNER JOIN nsk_gangs g ON g.id = t.gang_id
        ORDER BY t.id DESC
    ]], {}) or {}
    local outGangs, outTerritories = {}, {}
    for _, row in ipairs(gangs) do outGangs[#outGangs + 1] = serializeNskGang(row) end
    for _, row in ipairs(territories) do
        outTerritories[#outTerritories + 1] = {
            id = row.id,
            gang_id = row.gang_id,
            gang_name = row.gang_name,
            gang_color = row.gang_color,
            name = row.name,
            color = row.color or row.gang_color,
            center_x = tonumber(row.center_x or 0),
            center_y = tonumber(row.center_y or 0),
            radius = tonumber(row.radius or 120),
            vertices = decodeVertices(row.vertices_json),
            notes = row.notes or '',
        }
    end
    cb({
        ok = true,
        can_manage = canManageNsk(xPlayer),
        gangs = outGangs,
        members = members,
        territories = outTerritories,
    })
end)

ESX.RegisterServerCallback('san_mdt:getFleetGangTerritories', function(source, cb)
    local xPlayer = getPlayer(source)
    if not hasJobAccess(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til MDT.' }) end
    local job = getJob(xPlayer)
    if not job or not isPoliceJobName(job.name) then
        return cb({ ok = false, message = 'Kun politi kan se bande territorier pÃ¥ flÃ¥dekortet.' })
    end
    ensureNskTables()
    local rows = MySQL.query.await([[
        SELECT t.id, t.gang_id, t.name, t.color, t.center_x, t.center_y, t.radius, t.vertices_json,
               g.name AS gang_name, g.color AS gang_color
        FROM nsk_territories t
        INNER JOIN nsk_gangs g ON g.id = t.gang_id
        ORDER BY g.name ASC, t.name ASC
    ]], {}) or {}
    local out = {}
    for _, row in ipairs(rows) do
        out[#out + 1] = {
            id = row.id,
            gang_id = row.gang_id,
            gang_name = row.gang_name,
            gang_color = row.gang_color,
            name = row.name,
            color = row.color or row.gang_color,
            center_x = tonumber(row.center_x or 0),
            center_y = tonumber(row.center_y or 0),
            radius = tonumber(row.radius or 120),
            vertices = decodeVertices(row.vertices_json),
        }
    end
    cb({ ok = true, territories = out })
end)

ESX.RegisterServerCallback('san_mdt:getNskGangBoard', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAccessNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til NSK.' }) end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or data.gangId)
    if not gangId then return cb({ ok = false, message = 'Manglende bande.' }) end
    ensureNskTables()
    local gangRow = MySQL.single.await([[
        SELECT g.*,
            (SELECT COUNT(*) FROM nsk_gang_members m WHERE m.gang_id = g.id AND m.active = 1) AS member_count,
            (SELECT COUNT(*) FROM nsk_territories t WHERE t.gang_id = g.id) AS territory_count
        FROM nsk_gangs g WHERE g.id = ? LIMIT 1
    ]], { gangId })
    if not gangRow then return cb({ ok = false, message = 'Bande ikke fundet.' }) end
    local members = MySQL.query.await([[
        SELECT m.id, m.gang_id, m.identifier, m.person_name, m.role, m.board_tier, m.board_rank, m.notes, m.created_at
        FROM nsk_gang_members m
        WHERE m.gang_id = ? AND m.active = 1
        ORDER BY m.board_tier ASC, m.board_rank ASC, m.created_at ASC
    ]], { gangId }) or {}
    local territories = MySQL.query.await([[
        SELECT t.id, t.name, t.color, t.center_x, t.center_y, t.radius, t.vertices_json, t.notes
        FROM nsk_territories t WHERE t.gang_id = ? ORDER BY t.name ASC
    ]], { gangId }) or {}
    local outTerritories = {}
    for _, row in ipairs(territories) do
        outTerritories[#outTerritories + 1] = {
            id = row.id,
            name = row.name,
            color = row.color,
            center_x = tonumber(row.center_x or 0),
            center_y = tonumber(row.center_y or 0),
            radius = tonumber(row.radius or 120),
            vertices = decodeVertices(row.vertices_json),
            notes = row.notes or '',
        }
    end
    cb({
        ok = true,
        can_manage = canManageNsk(xPlayer),
        gang = serializeNskGang(gangRow),
        members = members,
        territories = outTerritories,
    })
end)

ESX.RegisterServerCallback('san_mdt:saveNskGangBoardLayout', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til at redigere rangliste.' }) end
    data = type(data) == 'table' and data or {}
    local gangId = tonumber(data.gang_id or data.gangId)
    if not gangId then return cb({ ok = false, message = 'Manglende bande.' }) end
    ensureNskTables()
    local layout = type(data.members) == 'table' and data.members or {}
    for _, row in ipairs(layout) do
        local memberId = tonumber(row.id or row.member_id)
        local tier = trim(row.board_tier or row.tier or 'unknown')
        local rank = tonumber(row.board_rank or row.rank or 0) or 0
        if memberId then
            MySQL.update.await('UPDATE nsk_gang_members SET board_tier = ?, board_rank = ? WHERE id = ? AND gang_id = ? AND active = 1', {
                tier ~= '' and tier or 'unknown', rank, memberId, gangId
            })
        end
    end
    mdtAuditLog(source, 'NSK', 'GANG_BOARD_UPDATED', {
        target_type = 'gang', target_id = tostring(gangId), message = 'Opdaterede bande rangliste',
        metadata = { member_count = #layout }
    })
    cb({ ok = true, message = 'Rangliste gemt.' })
end)

ESX.RegisterServerCallback('san_mdt:saveNskGang', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local name = trim(data.name or '')
    if name == '' then return cb({ ok = false, message = 'Bandenavn mangler.' }) end
    local id = tonumber(data.id)
    local color = trim(data.color or '#ff3048')
    local tag = trim(data.tag or '')
    local threat = trim(data.threat_level or 'medium')
    local status = trim(data.status or 'active')
    local notes = trim(data.notes or '')
    local officer = getMdtIdentifier(xPlayer)
    if id then
        MySQL.update.await('UPDATE nsk_gangs SET name = ?, tag = ?, color = ?, threat_level = ?, status = ?, notes = ? WHERE id = ?', {
            name, tag, color, threat, status, notes, id
        })
        mdtAuditLog(source, 'NSK', 'GANG_UPDATED', { target_type = 'gang', target_id = tostring(id), target_label = name, message = 'Opdaterede bande' })
        return cb({ ok = true, message = 'Bande opdateret.', id = id })
    end
    local newId = MySQL.insert.await('INSERT INTO nsk_gangs (name, tag, color, threat_level, status, notes, created_by) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        name, tag, color, threat, status, notes, officer
    })
    mdtAuditLog(source, 'NSK', 'GANG_CREATED', { target_type = 'gang', target_id = tostring(newId), target_label = name, message = 'Oprettede bande' })
    cb({ ok = true, message = 'Bande oprettet.', id = newId })
end)

ESX.RegisterServerCallback('san_mdt:saveNskTerritory', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local gangId = tonumber(data.gang_id or data.gangId)
    local name = trim(data.name or '')
    if not gangId or name == '' then return cb({ ok = false, message = 'Bande og navn krÃ¦ves.' }) end
    local centerX = tonumber(data.center_x or data.x or 0) or 0
    local centerY = tonumber(data.center_y or data.y or 0) or 0
    local radius = math.max(20, tonumber(data.radius or 120) or 120)
    local color = trim(data.color or '')
    local notes = trim(data.notes or '')
    local vertices = type(data.vertices) == 'table' and json.encode(data.vertices) or nil
    local id = tonumber(data.id)
    local officer = getMdtIdentifier(xPlayer)
    if id then
        MySQL.update.await('UPDATE nsk_territories SET gang_id = ?, name = ?, color = ?, center_x = ?, center_y = ?, radius = ?, vertices_json = ?, notes = ? WHERE id = ?', {
            gangId, name, color, centerX, centerY, radius, vertices, notes, id
        })
        return cb({ ok = true, message = 'Territorium opdateret.', id = id })
    end
    local newId = MySQL.insert.await('INSERT INTO nsk_territories (gang_id, name, color, center_x, center_y, radius, vertices_json, notes, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        gangId, name, color, centerX, centerY, radius, vertices, notes, officer
    })
    mdtAuditLog(source, 'NSK', 'TERRITORY_CREATED', { target_type = 'territory', target_id = tostring(newId), target_label = name, message = 'Oprettede territorium' })
    cb({ ok = true, message = 'Territorium oprettet.', id = newId })
end)

ESX.RegisterServerCallback('san_mdt:deleteNskTerritory', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    local id = tonumber(data.id)
    if not id then return cb({ ok = false, message = 'Manglende territorium.' }) end
    MySQL.update.await('DELETE FROM nsk_territories WHERE id = ?', { id })
    cb({ ok = true, message = 'Territorium slettet.' })
end)

ESX.RegisterServerCallback('san_mdt:registerNskGangMember', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canRegisterProfileGang(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til banderegistrering.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local gangId = tonumber(data.gang_id or data.gangId)
    local identifier = normalizePersonIdentifier(data.identifier)
    local personName = trim(data.person_name or data.name or '')
    local role = trim(data.role or 'Medlem')
    local notes = trim(data.notes or '')
    if not gangId or identifier == '' then return cb({ ok = false, message = 'Bande og borger krÃ¦ves.' }) end
    MySQL.update.await('UPDATE nsk_gang_members SET active = 0 WHERE identifier = ? AND active = 1', { identifier })
    local officerIdent = getMdtIdentifier(xPlayer)
    local officerName = getOfficerName(xPlayer, source)
    local boardTier = trim(data.board_tier or data.boardTier or '')
    if boardTier == '' then
        local roleLower = role:lower()
        if roleLower:find('leder') or roleLower:find('boss') then boardTier = 'boss'
        elseif roleLower:find('nÃ¦st') or roleLower:find('underboss') or roleLower:find('vice') then boardTier = 'underboss'
        elseif roleLower:find('capo') or roleLower:find('sergent') or roleLower:find('sergeant') then boardTier = 'capo'
        elseif roleLower:find('prospect') or roleLower:find('hangaround') then boardTier = 'prospect'
        elseif roleLower:find('soldat') or roleLower:find('medlem') then boardTier = 'soldier'
        else boardTier = 'unknown' end
    end
    local memberId = MySQL.insert.await([[
        INSERT INTO nsk_gang_members (gang_id, identifier, person_name, role, board_tier, board_rank, notes, active, registered_by, registered_by_name)
        VALUES (?, ?, ?, ?, ?, 0, ?, 1, ?, ?)
    ]], { gangId, identifier, personName, role, boardTier, notes, officerIdent, officerName })
    mdtAuditLog(source, 'NSK', 'GANG_MEMBER_REGISTERED', {
        target_type = 'profile', target_id = identifier, target_label = personName,
        message = ('Registrerede bandemedlem: %s'):format(role),
        metadata = { gang_id = gangId, member_id = memberId }
    })
    cb({ ok = true, message = 'Bandemedlem registreret.', gang = getProfileGangInfo(identifier) })
end)

ESX.RegisterServerCallback('san_mdt:removeNskGangMember', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canRegisterProfileGang(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    local identifier = normalizePersonIdentifier(data.identifier)
    if identifier == '' then return cb({ ok = false, message = 'Manglende borger.' }) end
    ensureNskTables()
    MySQL.update.await('UPDATE nsk_gang_members SET active = 0 WHERE identifier = ? AND active = 1', { identifier })
    mdtAuditLog(source, 'NSK', 'GANG_MEMBER_REMOVED', { target_type = 'profile', target_id = identifier, message = 'Fjernede banderegistrering' })
    cb({ ok = true, message = 'Banderegistrering fjernet.' })
end)

ESX.RegisterServerCallback('san_mdt:getNskObservations', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAccessNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til NSK.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local where, params = { '1=1' }, {}
    local targetType = trim(data.target_type or data.targetType or '')
    local gangId = tonumber(data.gang_id or data.gangId)
    local identifier = normalizePersonIdentifier(data.identifier)
    local search = trim(data.search or '')
    if targetType == 'gang' then
        where[#where + 1] = "o.target_type = 'gang'"
        if gangId then where[#where + 1] = 'o.gang_id = ?'; params[#params + 1] = gangId end
    elseif targetType == 'person' then
        where[#where + 1] = "o.target_type = 'person'"
        if identifier ~= '' then where[#where + 1] = 'o.identifier = ?'; params[#params + 1] = identifier end
    elseif gangId then
        where[#where + 1] = '(o.gang_id = ? OR (o.target_type = \'person\' AND o.identifier IN (SELECT identifier FROM nsk_gang_members WHERE gang_id = ? AND active = 1)))'
        params[#params + 1] = gangId
        params[#params + 1] = gangId
    end
    if search ~= '' then
        where[#where + 1] = '(o.subject LIKE ? OR o.body LIKE ? OR o.person_name LIKE ? OR g.name LIKE ?)'
        local q = '%' .. search .. '%'
        params[#params + 1] = q; params[#params + 1] = q; params[#params + 1] = q; params[#params + 1] = q
    end
    local rows = MySQL.query.await(([[
        SELECT o.*, g.name AS gang_name, g.color AS gang_color
        FROM nsk_observations o
        LEFT JOIN nsk_gangs g ON g.id = o.gang_id
        WHERE %s
        ORDER BY o.created_at DESC, o.id DESC
        LIMIT 200
    ]]):format(table.concat(where, ' AND ')), params) or {}
    local gangs = MySQL.query.await('SELECT id, name, tag, color FROM nsk_gangs ORDER BY name ASC', {}) or {}
    cb({ ok = true, can_manage = canManageNsk(xPlayer), observations = rows, gangs = gangs })
end)

ESX.RegisterServerCallback('san_mdt:saveNskObservation', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local targetType = trim(data.target_type or data.targetType or 'gang'):lower()
    if targetType ~= 'gang' and targetType ~= 'person' then targetType = 'gang' end
    local subject = trim(data.subject or '')
    local body = trim(data.body or data.notes or '')
    local priority = trim(data.priority or 'normal')
    if subject == '' then return cb({ ok = false, message = 'Emne mangler.' }) end
    local gangId = tonumber(data.gang_id or data.gangId)
    local identifier = normalizePersonIdentifier(data.identifier)
    local personName = trim(data.person_name or data.personName or '')
    if targetType == 'gang' and not gangId then return cb({ ok = false, message = 'VÃ¦lg en bande.' }) end
    if targetType == 'person' and identifier == '' then return cb({ ok = false, message = 'VÃ¦lg en person fra sÃ¸gningen.' }) end
    if targetType == 'person' and personName == '' then
        local row = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', { identifier })
        if row then
            personName = trim((row.firstname or '') .. ' ' .. (row.lastname or ''))
        end
    end
    local officerIdent = getMdtIdentifier(xPlayer)
    local officerName = getOfficerName(xPlayer, source)
    local id = tonumber(data.id)
    if id then
        MySQL.update.await([[
            UPDATE nsk_observations SET target_type = ?, gang_id = ?, identifier = ?, person_name = ?, subject = ?, body = ?, priority = ?
            WHERE id = ?
        ]], { targetType, gangId, identifier ~= '' and identifier or nil, personName, subject, body, priority, id })
        mdtAuditLog(source, 'NSK', 'OBSERVATION_UPDATED', { target_type = 'observation', target_id = tostring(id), target_label = subject, message = 'Opdaterede NSK-observation' })
        return cb({ ok = true, message = 'Observation opdateret.', id = id })
    end
    local newId = MySQL.insert.await([[
        INSERT INTO nsk_observations (target_type, gang_id, identifier, person_name, subject, body, priority, created_by, created_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { targetType, gangId, identifier ~= '' and identifier or nil, personName, subject, body, priority, officerIdent, officerName })
    mdtAuditLog(source, 'NSK', 'OBSERVATION_CREATED', {
        target_type = targetType == 'person' and 'profile' or 'gang',
        target_id = targetType == 'person' and identifier or tostring(gangId or ''),
        target_label = subject,
        message = 'Oprettede NSK-observation',
        metadata = { observation_id = newId, priority = priority }
    })
    cb({ ok = true, message = 'Observation registreret.', id = newId })
end)

ESX.RegisterServerCallback('san_mdt:deleteNskObservation', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    local id = tonumber(data.id)
    if not id then return cb({ ok = false, message = 'Manglende observation.' }) end
    ensureNskTables()
    MySQL.update.await('DELETE FROM nsk_observations WHERE id = ?', { id })
    mdtAuditLog(source, 'NSK', 'OBSERVATION_DELETED', { target_type = 'observation', target_id = tostring(id), message = 'Slettede NSK-observation' })
    cb({ ok = true, message = 'Observation slettet.' })
end)

ESX.RegisterServerCallback('san_mdt:getNskConnections', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAccessNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til NSK.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local gangId = tonumber(data.gang_id or data.gangId)
    local where, params = {}, {}
    if gangId then
        where[#where + 1] = '(l.gang_a_id = ? OR l.gang_b_id = ?)'
        params[#params + 1] = gangId
        params[#params + 1] = gangId
    end
    local sql = [[
        SELECT l.*,
            ga.name AS gang_a_name, ga.tag AS gang_a_tag, ga.color AS gang_a_color,
            gb.name AS gang_b_name, gb.tag AS gang_b_tag, gb.color AS gang_b_color
        FROM nsk_gang_links l
        INNER JOIN nsk_gangs ga ON ga.id = l.gang_a_id
        INNER JOIN nsk_gangs gb ON gb.id = l.gang_b_id
    ]]
    if #where > 0 then sql = sql .. ' WHERE ' .. table.concat(where, ' AND ') end
    sql = sql .. ' ORDER BY l.updated_at DESC, l.id DESC LIMIT 200'
    local rows = MySQL.query.await(sql, params) or {}
    local gangs = MySQL.query.await('SELECT id, name, tag, color FROM nsk_gangs ORDER BY name ASC', {}) or {}
    cb({ ok = true, can_manage = canManageNsk(xPlayer), connections = rows, gangs = gangs })
end)

ESX.RegisterServerCallback('san_mdt:saveNskConnection', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    ensureNskTables()
    local gangA = tonumber(data.gang_a_id or data.gangAId)
    local gangB = tonumber(data.gang_b_id or data.gangBId)
    if not gangA or not gangB or gangA == gangB then return cb({ ok = false, message = 'VÃ¦lg to forskellige bander.' }) end
    if gangA > gangB then gangA, gangB = gangB, gangA end
    local relation = trim(data.relation_type or data.relationType or 'unknown'):lower()
    local allowed = { ally = true, rival = true, neutral = true, unknown = true, supplier = true, conflict = true }
    if not allowed[relation] then relation = 'unknown' end
    local notes = trim(data.notes or '')
    local officerIdent = getMdtIdentifier(xPlayer)
    local officerName = getOfficerName(xPlayer, source)
    local id = tonumber(data.id)
    if id then
        MySQL.update.await('UPDATE nsk_gang_links SET gang_a_id = ?, gang_b_id = ?, relation_type = ?, notes = ? WHERE id = ?', {
            gangA, gangB, relation, notes, id
        })
        mdtAuditLog(source, 'NSK', 'LINK_UPDATED', { target_type = 'gang_link', target_id = tostring(id), message = 'Opdaterede bandeforbindelse', metadata = { relation = relation } })
        return cb({ ok = true, message = 'Forbindelse opdateret.', id = id })
    end
    local existing = MySQL.single.await('SELECT id FROM nsk_gang_links WHERE gang_a_id = ? AND gang_b_id = ? LIMIT 1', { gangA, gangB })
    if existing and existing.id then
        MySQL.update.await('UPDATE nsk_gang_links SET relation_type = ?, notes = ?, created_by = ?, created_by_name = ? WHERE id = ?', {
            relation, notes, officerIdent, officerName, existing.id
        })
        mdtAuditLog(source, 'NSK', 'LINK_UPDATED', { target_type = 'gang_link', target_id = tostring(existing.id), message = 'Opdaterede bandeforbindelse', metadata = { relation = relation } })
        return cb({ ok = true, message = 'Forbindelse opdateret.', id = existing.id })
    end
    local newId = MySQL.insert.await([[
        INSERT INTO nsk_gang_links (gang_a_id, gang_b_id, relation_type, notes, created_by, created_by_name)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { gangA, gangB, relation, notes, officerIdent, officerName })
    mdtAuditLog(source, 'NSK', 'LINK_CREATED', {
        target_type = 'gang_link', target_id = tostring(newId),
        message = 'Registrerede bandeforbindelse',
        metadata = { gang_a = gangA, gang_b = gangB, relation = relation }
    })
    cb({ ok = true, message = 'Forbindelse registreret.', id = newId })
end)

ESX.RegisterServerCallback('san_mdt:deleteNskConnection', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canManageNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang.' }) end
    data = type(data) == 'table' and data or {}
    local id = tonumber(data.id)
    if not id then return cb({ ok = false, message = 'Manglende forbindelse.' }) end
    ensureNskTables()
    MySQL.update.await('DELETE FROM nsk_gang_links WHERE id = ?', { id })
    mdtAuditLog(source, 'NSK', 'LINK_DELETED', { target_type = 'gang_link', target_id = tostring(id), message = 'Slettede bandeforbindelse' })
    cb({ ok = true, message = 'Forbindelse slettet.' })
end)

ESX.RegisterServerCallback('san_mdt:getNskActivityLog', function(source, cb, data)
    local xPlayer = getPlayer(source)
    if not canAccessNsk(xPlayer) then return cb({ ok = false, message = 'Ingen adgang til NSK.' }) end
    data = type(data) == 'table' and data or {}
    local search = trim(data.search or '')
    local officer = trim(data.officer or '')
    local limit = tonumber(data.limit or 200) or 200
    if limit > 300 then limit = 300 end
    local where, params = { "category = 'NSK'" }, {}
    if officer ~= '' then
        where[#where + 1] = '(officer_name LIKE ? OR officer_identifier LIKE ? OR officer_badge LIKE ?)'
        local q = '%' .. officer .. '%'
        params[#params + 1] = q; params[#params + 1] = q; params[#params + 1] = q
    end
    if search ~= '' then
        where[#where + 1] = '(action LIKE ? OR message LIKE ? OR target_label LIKE ? OR target_id LIKE ?)'
        local q = '%' .. search .. '%'
        params[#params + 1] = q; params[#params + 1] = q; params[#params + 1] = q; params[#params + 1] = q
    end
    local sql = 'SELECT * FROM mdt_audit_logs WHERE ' .. table.concat(where, ' AND ') .. ' ORDER BY created_at DESC, id DESC LIMIT ' .. tostring(limit)
    local rows = MySQL.query.await(sql, params) or {}
    local out = {}
    for i = 1, #rows do out[#out + 1] = auditRow(rows[i]) end
    cb({ ok = true, logs = out })
end)

_G.SanMdtTailLoaded = true
print('[san_mdt] server/main_tail.lua loaded (mail/charges/wiretap/NSK callbacks ready)')
