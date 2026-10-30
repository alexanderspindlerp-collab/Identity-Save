local ESX = exports['es_extended']:getSharedObject()

WS = WS or {}

function WS.notify(src, message, ntype)
    TriggerClientEvent('ya_tablet:notify', src, message, ntype or 'info')
end

function WS.getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

function WS.getCharacterName(xPlayer)
    if not xPlayer then return 'Ukendt' end
    if xPlayer.getName then return xPlayer.getName() end
    return xPlayer.name or 'Ukendt'
end

function WS.isAdmin(src)
    if Core and Core.IsPlayerAdmin and Core.IsPlayerAdmin(src) then
        return true
    end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup and xPlayer.getGroup() or 'user'
    for i = 1, #Config.AdminGroups do
        if group == Config.AdminGroups[i] then return true end
    end
    return false
end

function WS.decodePermissions(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return {} end
    return data
end

function WS.encodePermissions(perms)
    return json.encode(perms or {})
end

function WS.refreshTablet(src)
    if GetResourceState('ya_tablet') == 'started' then
        exports.ya_tablet:RefreshPlayer(src)
    end
end

function WS.installWorkshopApp(identifier)
    if GetResourceState('ya_tablet') ~= 'started' then return end
    exports.ya_tablet:InstallAppForIdentifier(identifier, 'workshop')
end

function WS.uninstallWorkshopApp(identifier)
    if not identifier then return end
    MySQL.update.await('DELETE FROM ya_tablet_installed_apps WHERE identifier = ? AND app_id = ?', {
        identifier, 'workshop',
    })
end

function WS.seedDefaultRoles(companyId)
    for i = 1, #Config.DefaultRoles do
        local role = Config.DefaultRoles[i]
        MySQL.insert.await(
            'INSERT INTO ya_workshop_roles (company_id, role_key, name, permissions, is_default, sort_order) VALUES (?, ?, ?, ?, ?, ?)',
            {
                companyId,
                role.key,
                role.name,
                WS.encodePermissions(role.permissions),
                role.isDefault and 1 or 0,
                tonumber(role.sortOrder) or i,
            }
        )
    end
end

function WS.getOwnerRoleId(companyId)
    local row = MySQL.single.await(
        'SELECT id FROM ya_workshop_roles WHERE company_id = ? AND role_key = ? LIMIT 1',
        { companyId, 'owner' }
    )
    return row and row.id or nil
end

function WS.getMemberRow(identifier)
    if not identifier then return nil end
    return MySQL.single.await([[
        SELECT m.*, c.name AS company_name, c.company_type, c.job_name, c.color AS company_color,
               c.locked AS company_locked, c.closed AS company_closed, c.balance AS company_balance,
               r.role_key, r.name AS role_name, r.permissions
        FROM ya_workshop_members m
        JOIN ya_workshop_companies c ON c.id = m.company_id
        JOIN ya_workshop_roles r ON r.id = m.role_id
        WHERE m.identifier = ? AND c.closed = 0
        LIMIT 1
    ]], { identifier })
end

function WS.roleCan(row, permission)
    if not row then return false end
    if row.role_key == 'owner' then return true end
    local perms = WS.decodePermissions(row.permissions)
    return perms[permission] == true
end

function WS.requireMember(src)
    local identifier = WS.getIdentifier(src)
    if not identifier then return nil, 'Ikke logget ind.' end
    local row = WS.getMemberRow(identifier)
    if not row then return nil, 'Du er ikke ansat i et værksted.' end
    if row.company_locked == 1 then return nil, 'Værkstedet er låst (UDE AF DRIFT).' end
    return row, nil
end

function WS.ownerDisplayName(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if xPlayer then return WS.getCharacterName(xPlayer) end
    local row = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', { identifier })
    if row then
        return ((row.firstname or '') .. ' ' .. (row.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    end
    return identifier
end

function WS.resolveOwnerIdentifier(ownerId)
    ownerId = tonumber(ownerId)
    if not ownerId then return nil, 'Ugyldigt spiller-ID.' end
    local xTarget = ESX.GetPlayerFromId(ownerId)
    if not xTarget or not xTarget.identifier then
        return nil, 'Spilleren er ikke online.'
    end
    if WS.getMemberRow(xTarget.identifier) then
        return nil, 'Spilleren er allerede medlem af et værksted.'
    end
    return xTarget.identifier, nil, xTarget
end

function WS.nextOrderNumber()
    return ('WS-%s-%s'):format(os.date('%Y%m'), math.random(100000, 999999))
end

function WS.nextInvoiceNumber()
    return ('WF%s-%s'):format(os.date('%Y%m'), math.random(1000000, 9999999))
end

function WS.calcVat(total)
    total = math.floor(tonumber(total) or 0)
    local rate = tonumber(Config.VatRate) or 0.25
    local subtotal = math.floor(total / (1 + rate) + 0.5)
    local vat = total - subtotal
    return subtotal, vat, total
end

function WS.loadUnlockedGroups(ownerIdentifier, plate, shopKey)
    ownerIdentifier = type(ownerIdentifier) == 'string' and ownerIdentifier or ''
    plate = WS.normalizePlate(plate)
    shopKey = type(shopKey) == 'string' and shopKey or ''
    if ownerIdentifier == '' or plate == '' or shopKey == '' then return {} end

    local rows = MySQL.query.await([[
        SELECT category_key AS categoryKey, group_key AS groupKey
        FROM ya_workshop_unlocks
        WHERE owner_identifier = ? AND vehicle_plate = ? AND shop_key = ?
        ORDER BY id ASC
    ]], { ownerIdentifier, plate, shopKey }) or {}

    return rows
end

function WS.isGroupUnlocked(ownerIdentifier, plate, shopKey, categoryKey, groupKey)
    ownerIdentifier = type(ownerIdentifier) == 'string' and ownerIdentifier or ''
    plate = WS.normalizePlate(plate)
    shopKey = type(shopKey) == 'string' and shopKey or ''
    categoryKey = type(categoryKey) == 'string' and categoryKey or ''
    groupKey = type(groupKey) == 'string' and groupKey or ''
    if ownerIdentifier == '' or plate == '' or shopKey == '' or categoryKey == '' or groupKey == '' then
        return false
    end

    local count = MySQL.scalar.await([[
        SELECT COUNT(*) FROM ya_workshop_unlocks
        WHERE owner_identifier = ? AND vehicle_plate = ? AND shop_key = ?
          AND category_key = ? AND group_key = ?
    ]], { ownerIdentifier, plate, shopKey, categoryKey, groupKey }) or 0

    return (tonumber(count) or 0) > 0
end

function WS.saveUnlockedGroup(ownerIdentifier, plate, shopKey, categoryKey, groupKey)
    ownerIdentifier = type(ownerIdentifier) == 'string' and ownerIdentifier or ''
    plate = WS.normalizePlate(plate)
    shopKey = type(shopKey) == 'string' and shopKey or ''
    categoryKey = type(categoryKey) == 'string' and categoryKey or ''
    groupKey = type(groupKey) == 'string' and groupKey or ''
    if ownerIdentifier == '' or plate == '' or shopKey == '' or categoryKey == '' or groupKey == '' then
        return
    end

    MySQL.insert.await([[
        INSERT IGNORE INTO ya_workshop_unlocks
        (owner_identifier, vehicle_plate, shop_key, category_key, group_key)
        VALUES (?, ?, ?, ?, ?)
    ]], { ownerIdentifier, plate, shopKey, categoryKey, groupKey })
end

function WS.normalizeCompanyType(companyType)
    if companyType == 'police' then
        return 'police'
    end
    if companyType == 'mechanic' or companyType == 'lscustom' then
        return 'lscustom'
    end
    return 'bennys'
end

function WS.isPoliceJobName(jobName)
    if type(jobName) ~= 'string' then return false end
    local jobs = Config.Police and Config.Police.Jobs or { 'police' }
    local lower = jobName:lower()
    for i = 1, #jobs do
        if jobs[i]:lower() == lower then
            return true
        end
    end
    return false
end

function WS.isPolicePlayer(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end
    local job = xPlayer.getJob()
    return job and WS.isPoliceJobName(job.name)
end

function WS.findJobVehicle(owner, plate, jobName)
    if not owner or owner == '' or not jobName then return nil end
    plate = WS.normalizePlate(plate)
    if plate == '' then return nil end
    return MySQL.single.await(
        'SELECT plate, vehicle, job, owner FROM owned_vehicles WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), " ", "") = ? AND job = ? LIMIT 1',
        { owner, plate, jobName }
    )
end

function WS.findPoliceServiceVehicle(owner, plate, jobName)
    plate = WS.normalizePlate(plate)
    if plate == '' then return nil end

    local row = WS.findJobVehicle(owner, plate, jobName)
    if row then return row end

    local jobs = Config.Police and Config.Police.Jobs or { 'police', 'politi', 'lspd', 'sheriff' }
    for i = 1, #jobs do
        row = MySQL.single.await(
            'SELECT plate, vehicle, job, owner FROM owned_vehicles WHERE REPLACE(UPPER(TRIM(plate)), " ", "") = ? AND job = ? LIMIT 1',
            { plate, jobs[i] }
        )
        if row then return row end
    end

    if owner and owner ~= '' then
        row = MySQL.single.await(
            'SELECT plate, vehicle, job, owner FROM owned_vehicles WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), " ", "") = ? AND job IS NOT NULL AND job <> "" LIMIT 1',
            { owner, plate }
        )
        if row then return row end
    end

    return nil
end

function WS.savePoliceServiceVehicleProps(owner, jobName, vehicleProps, serviceRow)
    if type(vehicleProps) ~= 'table' or not vehicleProps.plate then
        return false, 'Ugyldige køretøjsdata.'
    end

    serviceRow = serviceRow or WS.findPoliceServiceVehicle(owner, vehicleProps.plate, jobName)
    if not serviceRow then
        return false, 'Tjenestekøretøj ikke fundet i systemet.'
    end

    vehicleProps.plate = serviceRow.plate or vehicleProps.plate
    local plate = WS.normalizePlate(vehicleProps.plate)
    MySQL.update.await(
        'UPDATE owned_vehicles SET vehicle = ? WHERE REPLACE(UPPER(TRIM(plate)), " ", "") = ? AND job = ?',
        { json.encode(vehicleProps), plate, serviceRow.job or jobName }
    )
    return true
end

function WS.getPoliceCatalog()
    return Config.PoliceCategories or Config.CategoriesByType.police or {}
end

function WS.companyShopKey(companyId)
    companyId = tonumber(companyId)
    if not companyId then return nil end
    return ('company_%d'):format(companyId)
end

function WS.parseCompanyShopKey(shopKey)
    if type(shopKey) ~= 'string' then return nil end
    return tonumber(shopKey:match('^company_(%d+)$'))
end

function WS.isValidShopKey(shopKey, companyId)
    if type(shopKey) ~= 'string' or shopKey == '' then return false end
    if Config.Shops and Config.Shops[shopKey] then return true end
    local ownerId = WS.parseCompanyShopKey(shopKey)
    return ownerId ~= nil and (not companyId or ownerId == tonumber(companyId))
end

function WS.isValidShopCoords(loc)
    if type(loc) ~= 'table' then return false end
    local x, y, z = tonumber(loc.x), tonumber(loc.y), tonumber(loc.z)
    if not x or not y or not z then return false end
    if math.abs(x) < 0.01 and math.abs(y) < 0.01 and math.abs(z) < 0.01 then
        return false
    end
    return true
end

function WS.defaultBlipForType(companyType)
    companyType = WS.normalizeCompanyType(companyType)
    if companyType == 'bennys' then
        return { sprite = 225, color = 3, scale = 0.85, enabled = true }
    end
    return { sprite = 72, color = 5, scale = 0.85, enabled = true }
end

function WS.getCategorySource(companyType)
    local normalized = WS.normalizeCompanyType(companyType)
    if Config.CategoriesByType and Config.CategoriesByType[normalized] then
        return Config.CategoriesByType[normalized]
    end
    return Config.Categories
end

function WS.getCompanyByType(companyType)
    if not companyType then return nil end
    return MySQL.single.await([[
        SELECT * FROM ya_workshop_companies
        WHERE company_type = ? AND closed = 0 AND locked = 0
        ORDER BY id ASC
        LIMIT 1
    ]], { companyType })
end

function WS.getCompanyForShop(shopKey)
    if not WS.isValidShopKey(shopKey) then return nil end
    return MySQL.single.await([[
        SELECT c.* FROM ya_workshop_companies c
        INNER JOIN ya_workshop_company_shops cs ON cs.company_id = c.id
        WHERE cs.shop_key = ? AND c.closed = 0 AND c.locked = 0
        LIMIT 1
    ]], { shopKey })
end

function WS.getCompanyShopKeys(companyId)
    companyId = tonumber(companyId)
    if not companyId then return {} end
    local rows = MySQL.query.await(
        'SELECT shop_key FROM ya_workshop_company_shops WHERE company_id = ? ORDER BY shop_key ASC',
        { companyId }
    ) or {}
    local keys = {}
    for i = 1, #rows do
        keys[#keys + 1] = rows[i].shop_key
    end
    return keys
end

function WS.getShopAssignmentsMap()
    local map = {}
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT cs.shop_key, cs.company_id, cs.blip_sprite, cs.blip_color, cs.blip_scale, cs.blip_enabled,
                   c.name AS company_name
            FROM ya_workshop_company_shops cs
            INNER JOIN ya_workshop_companies c ON c.id = cs.company_id AND c.closed = 0
        ]])
    end)
    if not ok or type(rows) ~= 'table' then
        return map
    end
    for i = 1, #rows do
        map[rows[i].shop_key] = {
            companyId = rows[i].company_id,
            companyName = rows[i].company_name,
            blip = {
                sprite = rows[i].blip_sprite,
                color = rows[i].blip_color,
                scale = rows[i].blip_scale,
                enabled = rows[i].blip_enabled == 1,
            },
        }
    end
    return map
end

function WS.getShopCatalogMeta()
    local assignments = WS.getShopAssignmentsMap()
    local catalog = {}
    for key, shop in pairs(Config.Shops or {}) do
        local assigned = assignments[key]
        local pos, radius, custom = WS.resolveShopLocation(key)
        local defaults = WS.defaultShopBlip(key)
        local blip = assigned and assigned.blip or defaults
        catalog[#catalog + 1] = {
            key = key,
            label = shop.label or key,
            subtitle = shop.subtitle,
            companyType = WS.normalizeCompanyType(shop.companyType),
            assignedCompanyId = assigned and assigned.companyId or nil,
            assignedCompanyName = assigned and assigned.companyName or nil,
            pos = pos and { x = pos.x, y = pos.y, z = pos.z } or nil,
            radius = radius,
            hasCustomLocation = custom,
            blipSprite = tonumber(blip.sprite) or defaults.sprite,
            blipColor = tonumber(blip.color) or defaults.color,
            blipScale = tonumber(blip.scale) or defaults.scale,
            blipEnabled = blip.enabled ~= false,
        }
    end
    table.sort(catalog, function(a, b)
        return (a.label or a.key) < (b.label or b.key)
    end)
    return catalog
end

function WS.resolveShopLocation(shopKey)
    local companyId = WS.parseCompanyShopKey(shopKey)
    if companyId then
        local ok, row = pcall(function()
            return MySQL.single.await(
                'SELECT pos_x, pos_y, pos_z, radius FROM ya_workshop_shop_locations WHERE shop_key = ? LIMIT 1',
                { shopKey }
            )
        end)
        if ok and row then
            return vector3(tonumber(row.pos_x), tonumber(row.pos_y), tonumber(row.pos_z)),
                tonumber(row.radius) or 18.0,
                true
        end
        return nil, 18.0, false
    end

    local config = Config.Shops and Config.Shops[shopKey]
    if not config then return nil, nil, false end

    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT pos_x, pos_y, pos_z, radius FROM ya_workshop_shop_locations WHERE shop_key = ? LIMIT 1',
            { shopKey }
        )
    end)
    if ok and row then
        return vector3(tonumber(row.pos_x), tonumber(row.pos_y), tonumber(row.pos_z)),
            tonumber(row.radius) or (config.radius or 18.0),
            true
    end

    if config.pos then
        return config.pos, tonumber(config.radius) or 18.0, false
    end
    return nil, nil, false
end

function WS.getDynamicShopDefinition(shopKey, companyId)
    companyId = companyId or WS.parseCompanyShopKey(shopKey)
    if not companyId then return nil end

    local company = MySQL.single.await(
        'SELECT id, name, company_type FROM ya_workshop_companies WHERE id = ? LIMIT 1',
        { companyId }
    )
    if not company then return nil end

    local pos, radius, custom = WS.resolveShopLocation(shopKey)
    local companyType = WS.normalizeCompanyType(company.company_type)

    return {
        key = shopKey,
        label = company.name,
        subtitle = WS.companyTypeLabel(companyType),
        companyType = companyType,
        pos = pos,
        radius = radius,
        hasCustomLocation = custom,
        blip = WS.defaultBlipForType(companyType),
    }
end

function WS.getShopDefinition(shopKey)
    local companyId = WS.parseCompanyShopKey(shopKey)
    if companyId then
        return WS.getDynamicShopDefinition(shopKey, companyId)
    end

    local config = Config.Shops and Config.Shops[shopKey]
    if not config then return nil end

    local pos, radius, custom = WS.resolveShopLocation(shopKey)
    return {
        key = shopKey,
        label = config.label or shopKey,
        subtitle = config.subtitle,
        companyType = config.companyType,
        pos = pos,
        radius = radius,
        hasCustomLocation = custom,
        blip = config.blip,
    }
end

function WS.getBlipCatalog()
    local named = {}
    for i = 1, #(Config.BlipSprites or {}) do
        local entry = Config.BlipSprites[i]
        if entry.id then
            named[entry.id] = entry.label or ('Blip #%d'):format(entry.id)
        end
    end

    local catalog = {}
    for id = 1, 921 do
        catalog[#catalog + 1] = {
            id = id,
            label = named[id] or ('Blip #%d'):format(id),
        }
    end
    return catalog
end

function WS.defaultShopBlip(shopKey)
    local companyId = WS.parseCompanyShopKey(shopKey)
    if companyId then
        local companyType = MySQL.scalar.await(
            'SELECT company_type FROM ya_workshop_companies WHERE id = ? LIMIT 1',
            { companyId }
        )
        return WS.defaultBlipForType(companyType)
    end

    local config = Config.Shops and Config.Shops[shopKey]
    local blip = config and config.blip or {}
    return {
        sprite = tonumber(blip.sprite) or 72,
        color = tonumber(blip.color) or 3,
        scale = tonumber(blip.scale) or 0.85,
        enabled = true,
    }
end

function WS.getCompanyShopMeta(companyId)
    companyId = tonumber(companyId)
    local map = {}
    if not companyId then return map end

    local rows = MySQL.query.await([[
        SELECT shop_key, blip_sprite, blip_color, blip_scale, blip_enabled
        FROM ya_workshop_company_shops
        WHERE company_id = ?
    ]], { companyId }) or {}

    for i = 1, #rows do
        local defaults = WS.defaultShopBlip(rows[i].shop_key)
        map[rows[i].shop_key] = {
            sprite = tonumber(rows[i].blip_sprite) or defaults.sprite,
            color = tonumber(rows[i].blip_color) or defaults.color,
            scale = tonumber(rows[i].blip_scale) or defaults.scale,
            enabled = rows[i].blip_enabled == 1,
        }
    end
    return map
end

function WS.cleanupCompanyWorld(companyId)
    companyId = tonumber(companyId)
    if not companyId then return end

    local shopRows = MySQL.query.await(
        'SELECT shop_key FROM ya_workshop_company_shops WHERE company_id = ?',
        { companyId }
    ) or {}

    for i = 1, #shopRows do
        MySQL.update.await(
            'DELETE FROM ya_workshop_shop_locations WHERE shop_key = ?',
            { shopRows[i].shop_key }
        )
    end

    MySQL.update.await('DELETE FROM ya_workshop_company_shops WHERE company_id = ?', { companyId })
    MySQL.update.await('DELETE FROM ya_workshop_prices WHERE company_id = ?', { companyId })
    MySQL.update.await(
        "UPDATE ya_workshop_orders SET status = 'cancelled' WHERE company_id = ? AND status IN ('pending', 'in_progress')",
        { companyId }
    )
    MySQL.update.await(
        "UPDATE ya_workshop_calls SET status = 'closed', closed_at = NOW() WHERE company_id = ? AND status = 'open'",
        { companyId }
    )

    WS.broadcastShopLocations()
end
function WS.buildShopLocationsPayload()
    local rows = MySQL.query.await([[
        SELECT cs.shop_key, cs.blip_sprite, cs.blip_color, cs.blip_scale, cs.blip_enabled,
               c.id AS company_id, c.name AS company_name, c.locked, c.closed
        FROM ya_workshop_company_shops cs
        INNER JOIN ya_workshop_companies c ON c.id = cs.company_id
        WHERE c.closed = 0 AND c.locked = 0
    ]]) or {}

    local payload = {}
    for i = 1, #rows do
        local row = rows[i]
        local def = WS.getShopDefinition(row.shop_key)
        if def and def.pos then
            local defaults = WS.defaultShopBlip(row.shop_key)
            local blipEnabled = row.blip_enabled == 1
            payload[row.shop_key] = {
                key = row.shop_key,
                label = row.company_name,
                companyName = row.company_name,
                shopLabel = def.label,
                pos = { x = def.pos.x, y = def.pos.y, z = def.pos.z },
                radius = def.radius or (Config.ShopZone and Config.ShopZone.DefaultRadius) or 22.0,
                blip = blipEnabled and {
                    sprite = tonumber(row.blip_sprite) or defaults.sprite,
                    color = tonumber(row.blip_color) or defaults.color,
                    scale = tonumber(row.blip_scale) or defaults.scale,
                    name = row.company_name,
                } or nil,
            }
        end
    end
    return payload
end

function WS.broadcastShopLocations()
    TriggerClientEvent('ya_workshop:syncShopLocations', -1, WS.buildShopLocationsPayload())
end

function WS.setShopLocation(shopKey, x, y, z, radius)
    if not WS.isValidShopKey(shopKey) then
        return false, 'Ugyldig butik.'
    end

    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    radius = tonumber(radius)
    if not x or not y or not z then
        return false, 'Ugyldige koordinater.'
    end

    if not radius or radius < 3.0 or radius > 80.0 then
        local _, defaultRadius = WS.resolveShopLocation(shopKey)
        local config = Config.Shops and Config.Shops[shopKey]
        radius = defaultRadius or (config and config.radius) or 18.0
    end

    MySQL.insert.await([[
        INSERT INTO ya_workshop_shop_locations (shop_key, pos_x, pos_y, pos_z, radius)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            pos_x = VALUES(pos_x),
            pos_y = VALUES(pos_y),
            pos_z = VALUES(pos_z),
            radius = VALUES(radius)
    ]], { shopKey, x, y, z, radius })

    WS.broadcastShopLocations()
    return true
end

function WS.applyShopLocations(locations)
    if type(locations) ~= 'table' then return true end

    for shopKey, data in pairs(locations) do
        if type(data) == 'table' and WS.isValidShopKey(shopKey) then
            local ok, err = WS.setShopLocation(shopKey, data.x, data.y, data.z, data.radius)
            if not ok then return false, err end
        end
    end
    return true
end

function WS.setCompanyShops(companyId, shopKeys, shopMeta)
    companyId = tonumber(companyId)
    if not companyId then return false, 'Ugyldigt firma.' end
    shopMeta = type(shopMeta) == 'table' and shopMeta or {}

    local validKeys = {}
    local seen = {}
    if type(shopKeys) == 'table' then
        for i = 1, #shopKeys do
            local key = shopKeys[i]
            if type(key) == 'string' and WS.isValidShopKey(key, companyId) and not seen[key] then
                seen[key] = true
                validKeys[#validKeys + 1] = key
            end
        end
    end

    if #validKeys == 0 then
        local primary = WS.companyShopKey(companyId)
        if primary then
            validKeys[#validKeys + 1] = primary
            seen[primary] = true
        end
    end

    for i = 1, #validKeys do
        local key = validKeys[i]
        local existing = MySQL.single.await(
            'SELECT company_id FROM ya_workshop_company_shops WHERE shop_key = ? LIMIT 1',
            { key }
        )
        if existing and tonumber(existing.company_id) ~= companyId then
            local otherName = MySQL.scalar.await(
                'SELECT name FROM ya_workshop_companies WHERE id = ? LIMIT 1',
                { existing.company_id }
            )
            local shopLabel = (WS.getShopDefinition(key) or {}).label or key
            return false, ('"%s" tilhører allerede %s.'):format(shopLabel, otherName or 'et andet firma')
        end
    end

    local oldShops = MySQL.query.await(
        'SELECT shop_key FROM ya_workshop_company_shops WHERE company_id = ?',
        { companyId }
    ) or {}
    for i = 1, #oldShops do
        if not seen[oldShops[i].shop_key] then
            MySQL.update.await(
                'DELETE FROM ya_workshop_shop_locations WHERE shop_key = ?',
                { oldShops[i].shop_key }
            )
        end
    end

    MySQL.update.await('DELETE FROM ya_workshop_company_shops WHERE company_id = ?', { companyId })
    for i = 1, #validKeys do
        local key = validKeys[i]
        local defaults = WS.defaultShopBlip(key)
        local meta = type(shopMeta[key]) == 'table' and shopMeta[key] or {}
        local sprite = tonumber(meta.blipSprite or meta.sprite) or defaults.sprite
        local color = tonumber(meta.blipColor or meta.color) or defaults.color
        local scale = tonumber(meta.blipScale or meta.scale) or defaults.scale
        local enabled = meta.blipEnabled
        if enabled == nil then enabled = meta.enabled end
        if enabled == nil then enabled = true end

        MySQL.insert.await([[
            INSERT INTO ya_workshop_company_shops
                (company_id, shop_key, blip_sprite, blip_color, blip_scale, blip_enabled)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            companyId,
            key,
            sprite,
            color,
            scale,
            enabled and 1 or 0,
        })
    end

    WS.broadcastShopLocations()
    return true
end

function WS.loadPriceOverrides(companyId)
    local map = {}
    if not companyId then return map end
    local rows = MySQL.query.await(
        'SELECT category_key, group_key, item_key, price FROM ya_workshop_prices WHERE company_id = ?',
        { companyId }
    ) or {}
    for i = 1, #rows do
        local row = rows[i]
        map[('%s:%s:%s'):format(row.category_key, row.group_key, row.item_key)] = tonumber(row.price) or 0
    end
    return map
end

function WS.resolvePrice(overrides, categoryKey, groupKey, itemKey, defaultPrice)
    if overrides then
        local key = ('%s:%s:%s'):format(categoryKey, groupKey, itemKey)
        if overrides[key] ~= nil then return overrides[key] end
    end
    return tonumber(defaultPrice) or 0
end

function WS.catalogBaseItemKey(itemKey)
    if not itemKey or itemKey == '_open' then return itemKey end
    if itemKey:match('^extra_%d+_(on|off)$') then
        return 'vehicle_extras'
    end
    if itemKey == 'paint_rgb' then
        return 'paint_primary'
    end
    if itemKey:match('_rgb$') then
        return itemKey:gsub('_rgb$', '')
    end
    return itemKey:match('^(.+)_%-?%d+$') or itemKey
end

function WS.findCatalogEntry(categoryKey, groupKey, itemKey, lineType, companyType)
    lineType = lineType or 'item'
    local sources = {
        WS.getCategorySource(companyType),
        Config.Categories,
    }
    local seen = {}

    for s = 1, #sources do
        local source = sources[s]
        if source and not seen[source] then
            seen[source] = true
            for c = 1, #source do
                local cat = source[c]
                if cat.key == categoryKey then
                    for g = 1, #(cat.groups or {}) do
                        local group = cat.groups[g]
                        if group.key == groupKey then
                            if lineType == 'unlock' or itemKey == '_open' then
                                return {
                                    categoryKey = cat.key,
                                    groupKey = group.key,
                                    itemKey = '_open',
                                    lineType = 'unlock',
                                    label = group.label .. ' — åbning',
                                    description = group.desc,
                                    defaultPrice = tonumber(group.openPrice) or 0,
                                }
                            end
                            local lookupKeys = { itemKey, WS.catalogBaseItemKey(itemKey) }
                            for k = 1, #lookupKeys do
                                local lookupKey = lookupKeys[k]
                                for j = 1, #(group.items or {}) do
                                    local item = group.items[j]
                                    if item.key == lookupKey then
                                        return {
                                            categoryKey = cat.key,
                                            groupKey = group.key,
                                            itemKey = item.key,
                                            lineType = 'item',
                                            label = item.label,
                                            description = item.desc,
                                            defaultPrice = tonumber(item.price) or 0,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

function WS.getShopCatalog(companyId)
    local overrides = WS.loadPriceOverrides(companyId)
    local companyType = 'bennys'
    if companyId then
        companyType = MySQL.scalar.await(
            'SELECT company_type FROM ya_workshop_companies WHERE id = ? LIMIT 1',
            { companyId }
        ) or 'bennys'
    end
    local source = WS.getCategorySource(companyType)
    local categories = {}

    for i = 1, #source do
        local cat = source[i]
        local groups = {}

        for g = 1, #(cat.groups or {}) do
            local group = cat.groups[g]
            local items = {}

            for j = 1, #(group.items or {}) do
                local item = group.items[j]
                items[#items + 1] = {
                    key = item.key,
                    label = item.label,
                    desc = item.desc,
                    price = WS.resolvePrice(overrides, cat.key, group.key, item.key, item.price),
                }
            end

            groups[#groups + 1] = {
                key = group.key,
                label = group.label,
                desc = group.desc,
                icon = group.icon,
                image = group.image,
                openPrice = WS.resolvePrice(overrides, cat.key, group.key, '_open', group.openPrice),
                items = items,
            }
        end

        categories[#categories + 1] = {
            key = cat.key,
            label = cat.label,
            desc = cat.desc,
            icon = cat.icon,
            image = cat.image,
            groups = groups,
        }
    end

    return categories
end

function WS.buildPriceList(companyId)
    local overrides = WS.loadPriceOverrides(companyId)
    local companyType = 'bennys'
    if companyId then
        companyType = MySQL.scalar.await(
            'SELECT company_type FROM ya_workshop_companies WHERE id = ? LIMIT 1',
            { companyId }
        ) or 'bennys'
    end
    local source = WS.getCategorySource(companyType)
    local rows = {}

    for i = 1, #source do
        local cat = source[i]
        for g = 1, #(cat.groups or {}) do
            local group = cat.groups[g]
            rows[#rows + 1] = {
                categoryKey = cat.key,
                categoryLabel = cat.label,
                groupKey = group.key,
                groupLabel = group.label,
                itemKey = '_open',
                itemLabel = 'Åbningspris',
                price = WS.resolvePrice(overrides, cat.key, group.key, '_open', group.openPrice),
                isOpenPrice = true,
            }
            for j = 1, #(group.items or {}) do
                local item = group.items[j]
                rows[#rows + 1] = {
                    categoryKey = cat.key,
                    categoryLabel = cat.label,
                    groupKey = group.key,
                    groupLabel = group.label,
                    itemKey = item.key,
                    itemLabel = item.label,
                    price = WS.resolvePrice(overrides, cat.key, group.key, item.key, item.price),
                    isOpenPrice = false,
                }
            end
        end
    end

    return rows
end

function WS.savePriceOverride(companyId, categoryKey, groupKey, itemKey, price)
    companyId = tonumber(companyId)
    price = math.floor(tonumber(price) or 0)
    if not companyId or not categoryKey or not groupKey or not itemKey then return false end

    local entry = WS.findCatalogEntry(
        categoryKey, groupKey, itemKey == '_open' and '_open' or itemKey,
        itemKey == '_open' and 'unlock' or 'item',
        MySQL.scalar.await('SELECT company_type FROM ya_workshop_companies WHERE id = ? LIMIT 1', { companyId })
    )
    if not entry then return false end

    MySQL.insert.await([[
        INSERT INTO ya_workshop_prices (company_id, category_key, group_key, item_key, price)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE price = VALUES(price)
    ]], { companyId, categoryKey, groupKey, itemKey, price })
    return true
end

function WS.buildAdminCompanyDetail(companyId)
    local company = MySQL.single.await('SELECT * FROM ya_workshop_companies WHERE id = ? LIMIT 1', { companyId })
    if not company then return nil end

    local roles = MySQL.query.await(
        'SELECT id, role_key, name, permissions, is_default, sort_order FROM ya_workshop_roles WHERE company_id = ? ORDER BY sort_order ASC',
        { companyId }
    ) or {}

    for i = 1, #roles do
        roles[i].permissions = WS.decodePermissions(roles[i].permissions)
        roles[i].isTopRank = roles[i].role_key == 'owner'
    end

    local members = MySQL.query.await([[
        SELECT m.id, m.identifier, m.character_name AS name, m.role_id AS roleId, r.name AS roleName
        FROM ya_workshop_members m
        JOIN ya_workshop_roles r ON r.id = m.role_id
        WHERE m.company_id = ?
        ORDER BY m.joined_at ASC
    ]], { companyId }) or {}

    local orderCount = MySQL.scalar.await(
        "SELECT COUNT(*) FROM ya_workshop_orders WHERE company_id = ? AND status IN ('pending', 'in_progress')",
        { companyId }
    ) or 0

    local shopKeys = WS.getCompanyShopKeys(companyId)
    if #shopKeys == 0 then
        shopKeys = { WS.companyShopKey(companyId) }
    end
    local shopLabels = {}
    local shopCatalog = {}
    for i = 1, #shopKeys do
        local def = WS.getShopDefinition(shopKeys[i])
        shopLabels[#shopLabels + 1] = def and def.label or shopKeys[i]
        if def then
            local defaults = WS.defaultShopBlip(shopKeys[i])
            shopCatalog[#shopCatalog + 1] = {
                key = def.key,
                label = def.label,
                subtitle = def.subtitle,
                pos = def.pos and { x = def.pos.x, y = def.pos.y, z = def.pos.z } or nil,
                radius = def.radius,
                hasCustomLocation = def.hasCustomLocation,
                blipSprite = defaults.sprite,
                blipColor = defaults.color,
                blipScale = defaults.scale,
                blipEnabled = defaults.enabled ~= false,
            }
        end
    end

    local shopMeta = WS.getCompanyShopMeta(companyId)
    for i = 1, #shopCatalog do
        local meta = shopMeta[shopCatalog[i].key]
        if meta then
            shopCatalog[i].blipSprite = meta.sprite
            shopCatalog[i].blipColor = meta.color
            shopCatalog[i].blipScale = meta.scale
            shopCatalog[i].blipEnabled = meta.enabled
        end
    end

    return {
        id = company.id,
        name = company.name,
        companyType = WS.normalizeCompanyType(company.company_type),
        branding = WS.normalizeCompanyType(company.company_type),
        brandingLabel = WS.companyTypeLabel(company.company_type),
        jobName = company.job_name,
        color = company.color,
        balance = company.balance or 0,
        locked = company.locked == 1,
        closed = company.closed == 1,
        ownerIdentifier = company.owner_identifier,
        ownerName = WS.ownerDisplayName(company.owner_identifier),
        shopKeys = shopKeys,
        shopLabels = shopLabels,
        shopCatalog = shopCatalog,
        blipCatalog = WS.getBlipCatalog(),
        blipColors = Config.BlipColors or {},
        memberCount = #members,
        activeOrders = orderCount,
        members = members,
        roles = roles,
        permissionsCatalog = Config.PermissionsCatalog,
    }
end

function WS.companyTypeLabel(companyType)
    companyType = WS.normalizeCompanyType(companyType)
    if companyType == 'bennys' then return "Benny's" end
    return 'LS Customs'
end

function WS.pushAdminCompanyList(src)
    local ok, err = pcall(function()
        local rows = MySQL.query.await([[
            SELECT c.id, c.name, c.company_type, c.color, c.locked, c.closed, c.owner_identifier,
                   (SELECT COUNT(*) FROM ya_workshop_members m WHERE m.company_id = c.id) AS member_count,
                   (SELECT COUNT(*) FROM ya_workshop_orders o WHERE o.company_id = c.id AND o.status IN ('pending', 'in_progress')) AS order_count
            FROM ya_workshop_companies c
            ORDER BY c.name ASC
        ]]) or {}

        local shopsByCompany = {}
        local shopOk, shopRows = pcall(function()
            return MySQL.query.await([[
                SELECT cs.company_id, cs.shop_key
                FROM ya_workshop_company_shops cs
                ORDER BY cs.shop_key ASC
            ]])
        end)
        if shopOk and type(shopRows) == 'table' then
            for i = 1, #shopRows do
                local companyId = shopRows[i].company_id
                local def = WS.getShopDefinition(shopRows[i].shop_key)
                shopsByCompany[companyId] = shopsByCompany[companyId] or {}
                shopsByCompany[companyId][#shopsByCompany[companyId] + 1] = def and def.label or shopRows[i].shop_key
            end
        end

        for i = 1, #rows do
            rows[i].ownerName = WS.ownerDisplayName(rows[i].owner_identifier)
            rows[i].companyTypeLabel = WS.companyTypeLabel(rows[i].company_type)
            local labels = shopsByCompany[rows[i].id] or {}
            rows[i].shopLabels = labels
            rows[i].shopSummary = #labels > 0 and table.concat(labels, ', ') or 'Ingen butikker'
        end

        TriggerClientEvent('ya_tablet:adminWorkshops', src, {
            rows = rows,
            shopCatalog = WS.getShopCatalogMeta(),
            blipCatalog = WS.getBlipCatalog(),
            blipColors = Config.BlipColors or {},
        })
    end)

    if not ok then
        print(('[ya_workshop] pushAdminCompanyList fejl: %s'):format(err))
        TriggerClientEvent('ya_tablet:adminWorkshops', src, {
            rows = {},
            shopCatalog = WS.getShopCatalogMeta(),
            blipCatalog = WS.getBlipCatalog(),
            blipColors = Config.BlipColors or {},
        })
        WS.notify(src, 'Kunne ikke hente værkstedsliste. Genstart ya_workshop og tjek server-konsollen.', 'error')
    end
end

function WS.pushAdminCompanyDetail(src, companyId)
    local detail = WS.buildAdminCompanyDetail(companyId)
    if detail then
        TriggerClientEvent('ya_tablet:adminWorkshopDetail', src, detail)
    end
end

function WS.addMemberToCompany(companyId, targetId)
    companyId, targetId = tonumber(companyId), tonumber(targetId)
    if not companyId or not targetId then return false, 'Ugyldige data.' end

    local company = MySQL.single.await('SELECT id, closed FROM ya_workshop_companies WHERE id = ? LIMIT 1', { companyId })
    if not company or company.closed == 1 then
        return false, 'Værksted ikke fundet.'
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM ya_workshop_members WHERE company_id = ?', { companyId }) or 0
    if count >= Config.Company.MaxMembers then
        return false, 'Maks antal medarbejdere nået.'
    end

    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget or not xTarget.identifier then
        return false, 'Spilleren er ikke online.'
    end

    if WS.getMemberRow(xTarget.identifier) then
        return false, 'Spilleren er allerede medlem af et værksted.'
    end

    local defaultRole = MySQL.single.await(
        'SELECT id FROM ya_workshop_roles WHERE company_id = ? AND is_default = 1 ORDER BY sort_order ASC LIMIT 1',
        { companyId }
    )
    if not defaultRole then
        return false, 'Ingen standardrolle fundet.'
    end

    MySQL.insert.await(
        'INSERT INTO ya_workshop_members (company_id, identifier, character_name, role_id) VALUES (?, ?, ?, ?)',
        { companyId, xTarget.identifier, WS.getCharacterName(xTarget), defaultRole.id }
    )

    WS.installWorkshopApp(xTarget.identifier)
    WS.refreshTablet(targetId)
    return true, nil, xTarget
end

function WS.setMemberRole(companyId, memberId, roleId)
    companyId, memberId, roleId = tonumber(companyId), tonumber(memberId), tonumber(roleId)
    if not companyId or not memberId or not roleId then return false end

    local role = MySQL.single.await(
        'SELECT id FROM ya_workshop_roles WHERE id = ? AND company_id = ? LIMIT 1',
        { roleId, companyId }
    )
    if not role then return false end

    MySQL.update.await(
        'UPDATE ya_workshop_members SET role_id = ? WHERE id = ? AND company_id = ?',
        { roleId, memberId, companyId }
    )
    return true
end

MySQL.ready(function()
    for _, file in ipairs({ 'sql/install.sql', 'sql/migrate_1.8.1.sql', 'sql/migrate_1.8.3.sql', 'sql/migrate_1.8.4.sql', 'sql/migrate_1.8.5.sql', 'sql/migrate_1.8.6.sql', 'sql/migrate_1.8.7.sql' }) do
        local sql = LoadResourceFile(GetCurrentResourceName(), file)
        if sql and sql ~= '' then
            for statement in sql:gmatch('[^;]+') do
                local trimmed = statement:gsub('^%s+', ''):gsub('%s+$', '')
                if trimmed ~= '' then
                    MySQL.query.await(trimmed)
                end
            end
        end
    end
    print('[ya_workshop] Database ready.')
    pcall(function()
        MySQL.update.await([[
            DELETE cs FROM ya_workshop_company_shops cs
            INNER JOIN ya_workshop_companies c ON c.id = cs.company_id
            WHERE c.closed = 1
        ]])
        MySQL.update.await([[
            DELETE sl FROM ya_workshop_shop_locations sl
            LEFT JOIN ya_workshop_company_shops cs ON cs.shop_key = sl.shop_key
            WHERE cs.shop_key IS NULL
        ]])
    end)
    WS.broadcastShopLocations()
end)

exports('GetCompanyForIdentifier', function(identifier)
    return WS.getMemberRow(identifier)
end)

exports('InstallAppForIdentifier', WS.installWorkshopApp)

exports('GetShopCatalog', WS.getShopCatalog)

CreateThread(function()
    while GetResourceState('ya_tablet') ~= 'started' do
        Wait(1000)
    end
    Wait(300)

    local ok, err = pcall(function()
        exports.ya_tablet:RegisterApp({
            id = 'workshop',
            name = 'Arbejdstablet',
            desc = 'Bestillinger, opkald, fakturaer og medarbejdere.',
            icon = 'workshop',
            color = '#14b8a6',
            defaultInstalled = false,
            adminOnly = false,
            resource = 'ya_workshop',
        })
    end)

    if ok then
        print('[ya_workshop] Tablet-app registreret.')
    else
        print(('[ya_workshop] Kunne ikke registrere tablet-app: %s'):format(err))
    end
end)

RegisterNetEvent('ya_workshop:requestCatalog', function()
    local src = source
    TriggerClientEvent('ya_workshop:receiveCatalog', src, WS.getShopCatalog())
end)

ESX.RegisterServerCallback('ya_workshop:isEmployee', function(source, cb)
    local identifier = WS.getIdentifier(source)
    cb(WS.getMemberRow(identifier) ~= nil)
end)

ESX.RegisterServerCallback('ya_workshop:canTuneVehicle', function(source, cb, plate)
    local identifier = WS.getIdentifier(source)
    if not identifier then
        cb(false, 'Ikke logget ind.')
        return
    end
    if WS.findOwnedVehicle(identifier, plate) then
        cb(true)
        return
    end
    cb(false, 'Du ejer ikke denne bil i garagen. Kun egne køretøjer kan tunes her.')
end)

ESX.RegisterServerCallback('ya_workshop:getShopLocations', function(source, cb)
    cb(WS.buildShopLocationsPayload())
end)

ESX.RegisterServerCallback('ya_workshop:getCompanyForShop', function(source, cb, shopKey, plate)
    local def = WS.getShopDefinition(shopKey)
    if not def then cb(nil); return end
    local company = WS.getCompanyForShop(shopKey)
    if not company then
        cb({ error = 'Ingen butik er koblet til et firma her. Admin skal tilknytte butikken under Værksteder.' })
        return
    end
    local branding = WS.normalizeCompanyType(company.company_type)
    local identifier = WS.getIdentifier(source)
    cb({
        shopKey = shopKey,
        shopLabel = def.label,
        companyId = company.id,
        companyName = company.name,
        branding = branding,
        brandingLabel = WS.companyTypeLabel(branding),
        categories = WS.getShopCatalog(company.id),
        unlockedGroups = WS.loadUnlockedGroups(identifier, plate, shopKey),
    })
end)
