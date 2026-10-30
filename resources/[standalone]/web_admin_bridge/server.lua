local API_KEY = GetConvar('web_admin_bridge_key', 'CHANGE_ME')
local SERVER_ENDPOINT = GetConvar('web_admin_bridge_server_endpoint', '127.0.0.1:30120')
local PLAYERS_DB_PATH = GetConvar('web_admin_bridge_players_db', '')
local ESX = exports['es_extended']:getSharedObject()

local function sendJson(res, status, data)
    res.writeHead(status, { ['Content-Type'] = 'application/json' })
    return res.send(json.encode(data))
end

local function readBody(req, callback)
    req.setDataHandler(function(body)
        local data = json.decode(body or '{}') or {}
        callback(data)
    end)
end

local function normalizeItems(items)
    if not items then return {} end

    local output = {}

    for _, item in pairs(items) do
        if item and item.name then
            output[#output + 1] = {
                name = item.name,
                label = item.label,
                count = item.count or item.amount or 0,
                amount = item.amount or item.count or 0,
                slot = item.slot,
                metadata = item.metadata
            }
        end
    end

    table.sort(output, function(a, b)
        return tonumber(a.slot or 9999) < tonumber(b.slot or 9999)
    end)

    return output
end

local function findPlayerByIdentifier(identifier)
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local xPlayer = ESX.GetPlayerFromId(src)

        if xPlayer and xPlayer.identifier == identifier then
            return src
        end
    end

    return nil
end

local function findPlayerBySteamHex(steamHex)
    if not steamHex or steamHex == '' then
        return nil
    end

    local wanted = 'steam:' .. string.lower(steamHex)

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)

        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local identifier = GetPlayerIdentifier(src, i)

            if identifier and string.lower(identifier) == wanted then
                return src
            end
        end
    end

    return nil
end

local function getPlayerInventory(identifier)
    local target = findPlayerByIdentifier(identifier)

    if not target then
        return false, {}
    end

    local ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems(target)
    end)

    if ok and items then
        return true, normalizeItems(items)
    end

    return true, {}
end

local function getOxInventoryItems(inventoryId)
    local ok, items = pcall(function()
        return exports.ox_inventory:GetInventoryItems(inventoryId)
    end)

    if ok and items then
        return normalizeItems(items)
    end

    ok, items = pcall(function()
        local inventory = exports.ox_inventory:GetInventory(inventoryId, false)
        return inventory and inventory.items or nil
    end)

    if ok and items then
        return normalizeItems(items)
    end

    return {}
end

local function getAccountPlaytimeSeconds(steamHex)
    steamHex = tostring(steamHex or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if steamHex == '' then return 0 end

    local total = 0
    local onlineIdentifiers = {}

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local xPlayer = ESX.GetPlayerFromId(src)

        if xPlayer and xPlayer.identifier then
            local ident = xPlayer.identifier:lower()

            if ident:find(':' .. steamHex, 1, true) then
                local seconds = 0
                if type(xPlayer.getPlayTime) == 'function' then
                    seconds = tonumber(xPlayer.getPlayTime()) or 0
                end
                total = total + seconds
                onlineIdentifiers[ident] = true
            end
        end
    end

    local pattern = 'char%:' .. steamHex
    local rows = MySQL.query.await(
        'SELECT identifier, metadata FROM users WHERE LOWER(identifier) LIKE ?',
        { pattern }
    )

    if rows then
        for _, row in ipairs(rows) do
            local ident = tostring(row.identifier or ''):lower()
            if not onlineIdentifiers[ident] then
                local ok, meta = pcall(json.decode, row.metadata or '{}')
                meta = ok and meta or {}
                total = total + (tonumber(meta.lastPlaytime) or 0)
            end
        end
    end

    return total
end

local function fetchCfxPlaytime(steamHex, callback)
    steamHex = tostring(steamHex or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if steamHex == '' or SERVER_ENDPOINT == '' then
        return callback(nil)
    end

    local identifier = 'steam:' .. steamHex
    local url = ('https://lambda.fivem.net/api/ticket/playtimes/%s?identifiers[]=%s'):format(
        SERVER_ENDPOINT,
        identifier
    )

    PerformHttpRequest(url, function(statusCode, body)
        if statusCode ~= 200 then
            return callback(nil)
        end

        local ok, data = pcall(json.decode, body or '[]')
        if not ok or type(data) ~= 'table' then
            return callback(nil)
        end

        for _, row in ipairs(data) do
            if row.id == identifier and tonumber(row.seconds) and tonumber(row.seconds) > 0 then
                return callback(math.floor(tonumber(row.seconds)))
            end
        end

        if data[1] and tonumber(data[1].seconds) and tonumber(data[1].seconds) > 0 then
            return callback(math.floor(tonumber(data[1].seconds)))
        end

        callback(nil)
    end)
end

local function getVehicleInventory(plate)
    plate = tostring(plate or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if plate == '' then
        return {}, {}
    end

    -- ox_inventory bruger typisk glovePLATE og trunkPLATE.
    -- Ekstra navne er med som fallback, hvis resource/versionen bruger andet prefix.
    local glovebox = {}
    local trunk = {}

    for _, id in ipairs({ 'glove' .. plate, 'glovebox' .. plate, 'glove:' .. plate }) do
        glovebox = getOxInventoryItems(id)
        if #glovebox > 0 then break end
    end

    for _, id in ipairs({ 'trunk' .. plate, 'trunk:' .. plate }) do
        trunk = getOxInventoryItems(id)
        if #trunk > 0 then break end
    end

    return glovebox, trunk
end

SetHttpHandler(function(req, res)
    local path = req.path or ''

    if req.method ~= 'POST' then
        return sendJson(res, 405, {
            success = false,
            error = 'Method not allowed. Use POST.'
        })
    end

    if req.headers['x-api-key'] ~= API_KEY then
        return sendJson(res, 403, {
            success = false,
            error = 'Forbidden'
        })
    end

    if path == '/remove-item' or path == '/web_admin_bridge/remove-item' then
        return readBody(req, function(data)
            local identifier = data.identifier
            local item = data.item
            local count = tonumber(data.count) or 1
            local slot = tonumber(data.slot)

            if not identifier or not item then
                return sendJson(res, 400, {
                    success = false,
                    error = 'Missing identifier or item'
                })
            end

            local target = findPlayerByIdentifier(identifier)

            if not target then
                return sendJson(res, 200, {
                    success = false,
                    online = false,
                    error = 'Player not online or identifier mismatch'
                })
            end

            local removed = exports.ox_inventory:RemoveItem(
                target,
                item,
                count,
                nil,
                slot
            )

            return sendJson(res, 200, {
                success = removed == true,
                online = true,
                target = target
            })
        end)
    end

    if path == '/player-inventory' or path == '/web_admin_bridge/player-inventory' then
        return readBody(req, function(data)
            local identifier = data.identifier

            if not identifier then
                return sendJson(res, 400, {
                    success = false,
                    error = 'Missing identifier'
                })
            end

            local online, inventory = getPlayerInventory(identifier)

            return sendJson(res, 200, {
                success = online,
                online = online,
                inventory = inventory
            })
        end)
    end

    if path == '/account-playtime' or path == '/web_admin_bridge/account-playtime' then
        return readBody(req, function(data)
            local steamHex = data.steamHex

            if not steamHex then
                return sendJson(res, 400, {
                    success = false,
                    error = 'Missing steamHex'
                })
            end

            local esxSeconds = getAccountPlaytimeSeconds(steamHex)

            return fetchCfxPlaytime(steamHex, function(cfxSeconds)
                local seconds = esxSeconds

                if cfxSeconds and cfxSeconds > seconds then
                    seconds = cfxSeconds
                end

                return sendJson(res, 200, {
                    success = true,
                    seconds = seconds,
                    esxSeconds = esxSeconds,
                    cfxSeconds = cfxSeconds
                })
            end)
        end)
    end

    if path == '/kick-player' or path == '/web_admin_bridge/kick-player' then
        return readBody(req, function(data)
            local steamHex = data.steamHex
            local reason = data.reason or 'Banned from web panel'

            if not steamHex then
                return sendJson(res, 400, {
                    success = false,
                    error = 'Missing steamHex'
                })
            end

            local target = findPlayerBySteamHex(steamHex)

            if not target then
                return sendJson(res, 200, {
                    success = true,
                    online = false,
                    kicked = false
                })
            end

            DropPlayer(target, reason)

            return sendJson(res, 200, {
                success = true,
                online = true,
                kicked = true,
                target = target
            })
        end)
    end

    if path == '/vehicle-inventory' or path == '/web_admin_bridge/vehicle-inventory' then
        return readBody(req, function(data)
            local plate = data.plate

            if not plate then
                return sendJson(res, 400, {
                    success = false,
                    error = 'Missing plate'
                })
            end

            local glovebox, trunk = getVehicleInventory(plate)

            return sendJson(res, 200, {
                success = true,
                source = 'live',
                plate = plate,
                glovebox = glovebox,
                trunk = trunk
            })
        end)
    end

    return sendJson(res, 404, {
        success = false,
        error = 'Route not found',
        path = path
    })
end)

local STEAM_ID_BASE = 76561197960265728

local function collectPlayerIdentifiers(src)
    local identifiers = {}
    local seen = {}

    local function addIdentifier(identifier)
        if not identifier or identifier == '' or seen[identifier] then
            return
        end

        seen[identifier] = true
        identifiers[#identifiers + 1] = identifier
    end

    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        addIdentifier(GetPlayerIdentifier(src, i))
    end

    for _, typ in ipairs({ 'steam', 'discord', 'license', 'license2', 'fivem' }) do
        local ok, identifier = pcall(function()
            return GetPlayerIdentifierByType(src, typ)
        end)

        if ok then
            addIdentifier(identifier)
        end
    end

    return identifiers
end

local function lowerIdentifier(value)
    return string.lower(value or '')
end

local function steamHexToSteam64(hex)
    if not hex or hex == '' then
        return nil
    end

    hex = lowerIdentifier(hex):gsub('^steam:', '')
    local accountId = tonumber(hex, 16)

    if not accountId then
        return nil
    end

    return tostring(STEAM_ID_BASE + accountId)
end

local function getSteamHexFromIdentifiers(identifiers)
    for _, identifier in ipairs(identifiers) do
        if identifier:sub(1, 6) == 'steam:' then
            return identifier:sub(7)
        end
    end

    return nil
end

local function readPlayersDbFile()
    if PLAYERS_DB_PATH == '' then
        return nil
    end

    local file = io.open(PLAYERS_DB_PATH, 'r')
    if not file then
        return nil
    end

    local content = file:read('*a')
    file:close()

    return json.decode(content)
end

local function isBanExpired(expiration, now)
    if expiration == false or expiration == nil then
        return false
    end

    local expiresAt = tonumber(expiration)
    if not expiresAt then
        return false
    end

    return expiresAt <= now
end

local function isBanRevoked(revocation)
    if type(revocation) ~= 'table' then
        return false
    end

    local timestamp = revocation.timestamp
    return timestamp ~= nil and timestamp ~= false and timestamp ~= 0
end

local function identifiersMatchBan(identifiers, action)
    local lowered = {}

    for _, identifier in ipairs(identifiers) do
        lowered[#lowered + 1] = lowerIdentifier(identifier)
    end

    for _, playerId in ipairs(lowered) do
        for _, banId in ipairs(action.ids or {}) do
            if playerId == lowerIdentifier(banId) then
                return true
            end
        end
    end

    return false
end

local function findActiveBanInPlayersDb(identifiers)
    local database = readPlayersDbFile()
    if not database or not database.actions then
        return nil
    end

    local now = os.time()

    for _, action in ipairs(database.actions) do
        if action.type == 'ban'
            and not isBanRevoked(action.revocation)
            and not isBanExpired(action.expiration, now)
            and identifiersMatchBan(identifiers, action)
        then
            return action
        end
    end

    return nil
end

local function getDiscordIdFromIdentifiers(identifiers)
    for _, identifier in ipairs(identifiers) do
        if identifier:sub(1, 8) == 'discord:' then
            return identifier:sub(9)
        end
    end

    return nil
end

local function escapeHtml(value)
    if value == nil then
        return ''
    end

    value = tostring(value)
    value = value:gsub('&', '&amp;')
    value = value:gsub('<', '&lt;')
    value = value:gsub('>', '&gt;')
    value = value:gsub('"', '&quot;')
    return value
end

local function formatRemainingTime(expiresAtUnix)
    if not expiresAtUnix then
        return nil
    end

    local remaining = math.floor(expiresAtUnix - os.time())
    if remaining <= 0 then
        return 'Udløbet'
    end

    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)

    if days > 0 then
        return ('%d dage %d timer'):format(days, hours)
    end

    if hours > 0 then
        return ('%d timer %d min'):format(hours, minutes)
    end

    return ('%d minutter'):format(minutes)
end

local function formatBanDate(timestamp)
    if not timestamp then
        return nil
    end

    return os.date('%d/%m/%Y %H:%M', timestamp)
end

local TXADMIN_CODE_TAG = '<code style="background-color: hsl(202deg 40% 66% / 35%); padding: 2px 2px; border-radius: 4px;">'
local TXADMIN_CODE_ID_TAG = '<code style="letter-spacing: 2px; background-color: #ff7f5059; padding: 2px 4px; border-radius: 6px;">'
local function applyTxAdminInlineTags(content)
    content = content:gsub('<code>', function()
        return TXADMIN_CODE_TAG
    end)
    content = content:gsub('<codeid>', function()
        return TXADMIN_CODE_ID_TAG
    end)
    content = content:gsub('</codeid>', function()
        return '</code>'
    end)
    return content
end

local function buildBanRejectHtml(ban)
    local title = ban.permanent
        and 'Du er permanent udelukket fra serveren'
        or 'Du er midlertidigt udelukket fra serveren'

    local lines = {}

    if not ban.permanent and ban.expirationLabel then
        lines[#lines + 1] = '<strong>Udløber om:</strong> <span style="background-color: #dc2626; color: #ffffff; padding: 3px 10px; border-radius: 6px; font-weight: 600;">'
            .. escapeHtml(ban.expirationLabel) .. '</span>'
    end

    if ban.banDate then
        lines[#lines + 1] = '<strong>Dato:</strong> ' .. escapeHtml(ban.banDate)
    end

    lines[#lines + 1] = '<strong>Grund:</strong> ' .. escapeHtml(ban.reason or 'Ingen begrundelse angivet')

    if ban.author then
        lines[#lines + 1] = '<strong>Staff:</strong> ' .. escapeHtml(ban.author)
    end

    local customMessage = GetConvar('web_admin_bridge_ban_message', '')
    if customMessage ~= '' then
        lines[#lines + 1] = '<br>' .. escapeHtml(customMessage)
    end

    local content = applyTxAdminInlineTags(table.concat(lines, '<br>'))

    return ('<div style="background-color: rgba(30, 30, 30, 0.5); padding: 20px; border: solid 1.5px #80282B; border-radius: 8px; margin-top: 25px;"><h2 style="color: #ef4444; margin: 0;">%s</h2><br><p style="font-size: 1.25rem; padding: 0px">%s</p></div>'):format(
        escapeHtml(title),
        content
    )
end

local function buildBanPlainMessage(ban)
    local title = ban.permanent and 'Permanent ban' or 'Midlertidigt ban'
    local parts = { title }

    if ban.expirationLabel then
        parts[#parts + 1] = 'Udløber om: ' .. ban.expirationLabel
    end

    parts[#parts + 1] = 'Grund: ' .. (ban.reason or 'Ingen begrundelse')
    parts[#parts + 1] = 'Staff: ' .. (ban.author or 'Staff')

    return table.concat(parts, ' | ')
end

local function normalizeBanDetails(input)
    if not input then
        return nil
    end

    if input.source == 'database' then
        local permanent = input.duration_days == nil and input.expires_at == nil
        local expiresAtUnix = input.expires_at_unix and tonumber(input.expires_at_unix) or nil

        return {
            permanent = permanent,
            reason = input.reason,
            author = input.author_username or 'Staff',
            banId = input.txadmin_action_id or ('WEB-' .. tostring(input.id or '0')),
            expirationLabel = permanent and nil or formatRemainingTime(expiresAtUnix),
            banDate = formatBanDate(input.created_at_unix and tonumber(input.created_at_unix) or nil),
        }
    end

    local action = input.action
    local permanent = action.expiration == false or action.expiration == nil
    local expiresAtUnix = permanent and nil or tonumber(action.expiration)

    return {
        permanent = permanent,
        reason = action.reason,
        author = action.author or 'Staff',
        banId = action.id,
        expirationLabel = permanent and nil or formatRemainingTime(expiresAtUnix),
        banDate = formatBanDate(tonumber(action.timestamp)),
    }
end

local function findActiveBanInDatabase(steam64, discordId)
    if not steam64 and not discordId then
        return nil
    end

    if GetResourceState('oxmysql') ~= 'started' then
        return nil
    end

    local ok, result = pcall(function()
        return MySQL.single.await([[
            SELECT
                b.id,
                b.reason,
                b.author_username,
                b.duration_days,
                b.txadmin_action_id,
                UNIX_TIMESTAMP(b.expires_at) AS expires_at_unix,
                UNIX_TIMESTAMP(b.created_at) AS created_at_unix
            FROM web_player_bans b
            LEFT JOIN web_accounts a ON a.steam_id = b.steam_id
            WHERE b.active = 1
              AND (b.expires_at IS NULL OR b.expires_at > NOW())
              AND (
                (? IS NOT NULL AND b.steam_id = ?)
                OR (? IS NOT NULL AND a.discord_id = ?)
              )
            ORDER BY b.id DESC
            LIMIT 1
        ]], { steam64, steam64, discordId, discordId })
    end)

    if not ok then
        print(('[web_admin_bridge] Ban database lookup failed: %s'):format(result))
        return nil
    end

    if not result then
        return nil
    end

    return normalizeBanDetails({
        source = 'database',
        id = result.id,
        reason = result.reason,
        author_username = result.author_username,
        duration_days = result.duration_days,
        txadmin_action_id = result.txadmin_action_id,
        expires_at_unix = result.expires_at_unix,
        created_at_unix = result.created_at_unix,
    })
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(200)
    end

    pcall(function()
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS web_player_bans (
                id INT AUTO_INCREMENT PRIMARY KEY,
                steam_id VARCHAR(64) NOT NULL,
                author_discord_id VARCHAR(64) NOT NULL,
                author_username VARCHAR(100) NULL,
                reason TEXT NOT NULL,
                duration_days INT NULL,
                expires_at TIMESTAMP NULL,
                active TINYINT(1) NOT NULL DEFAULT 1,
                txadmin_action_id VARCHAR(16) NULL,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                lifted_at TIMESTAMP NULL,
                lifted_by_discord_id VARCHAR(64) NULL,
                INDEX idx_steam_id (steam_id),
                INDEX idx_active (active)
            )
        ]])
    end)

    local activeBans = 0
    local ok, result = pcall(function()
        return MySQL.scalar.await([[
            SELECT COUNT(*) FROM web_player_bans
            WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW())
        ]])
    end)

    if ok and result then
        activeBans = tonumber(result) or 0
    end

    if PLAYERS_DB_PATH == '' then
        print('[web_admin_bridge] playersDB path ikke sat (web_admin_bridge_players_db)')
    else
        local file = io.open(PLAYERS_DB_PATH, 'r')
        print(('[web_admin_bridge] playersDB: %s (%s)'):format(
            PLAYERS_DB_PATH,
            file and 'laesbar' or 'KAN IKKE LAeses - bruger MySQL bans'
        ))
        if file then file:close() end
    end

    print(('[web_admin_bridge] Ban enforcement klar (%d aktive bans i MySQL)'):format(activeBans))
end)

local function resolveActiveBanDetails(src)
    local identifiers = collectPlayerIdentifiers(src)
    local steamHex = getSteamHexFromIdentifiers(identifiers)
    local steam64 = steamHexToSteam64(steamHex)
    local discordId = getDiscordIdFromIdentifiers(identifiers)

    local dbBan = findActiveBanInDatabase(steam64, discordId)
    if dbBan then
        return dbBan
    end

    local fileBan = findActiveBanInPlayersDb(identifiers)
    if fileBan then
        return normalizeBanDetails({ source = 'playersdb', action = fileBan })
    end

    return nil
end

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source

    deferrals.defer()
    Wait(0)
    deferrals.update('Tjekker ban-status...')

    local banDetails = resolveActiveBanDetails(src)
    if banDetails then
        deferrals.done('\n' .. buildBanRejectHtml(banDetails))
        return
    end

    deferrals.done()
end)

AddEventHandler('playerJoining', function()
    local src = source

    CreateThread(function()
        Wait(0)

        local banDetails = resolveActiveBanDetails(src)
        if banDetails then
            DropPlayer(src, buildBanPlainMessage(banDetails))
        end
    end)
end)
