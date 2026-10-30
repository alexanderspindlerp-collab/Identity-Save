local ESX = exports['es_extended']:getSharedObject()

local RegisteredApps = {}

local function logUiDiagnostics()
    local resource = GetCurrentResourceName()
    local basePath = GetResourcePath(resource) or 'unknown'
    local version = GetResourceMetadata(resource, 'version', 0) or 'unknown'
    local content = LoadResourceFile(resource, 'web/js/app.js') or ''

    print(('[ya_tablet] Resource path: %s'):format(basePath))
    print(('[ya_tablet] Version: %s'):format(version))

    if content == '' then
        print('[ya_tablet] ERROR: Could not read web/js/app.js')
        return
    end

    if content:find('Velkommen tilbage', 1, true) then
        print('[ya_tablet] ERROR: OLD UI on disk (Velkommen tilbage). Update files on VPS then: ensure ya_tablet')
    elseif content:find('ipad%-home', 1, false) then
        print('[ya_tablet] OK: New iPad UI loaded from disk.')
    else
        print('[ya_tablet] WARN: Unknown UI in app.js')
    end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    logUiDiagnostics()
end)

local SystemApps = {
    apps = {
        id = 'apps',
        name = 'APPs',
        desc = 'Find og hent apps til din tablet.',
        icon = 'apps',
        color = '#2f6feb',
        systemApp = true,
        adminOnly = false,
        resource = 'ya_tablet',
    },
}

local function isSystemApp(appId)
    return SystemApps[appId] ~= nil
end

local function registerBuiltInApps()
    RegisteredApps.gangs = {
        id = 'gangs',
        name = 'Bande',
        desc = 'Din bande — XP, territorier, medlemmer og beskeder.',
        icon = 'gangs',
        color = '#143d2b',
        defaultInstalled = true,
        adminOnly = false,
        resource = 'ya_gangs',
    }

    RegisteredApps.gangs_admin = {
        id = 'gangs_admin',
        name = 'Bande Admin',
        desc = 'Administrer bander — lås, luk og overvåg.',
        icon = 'gangs_admin',
        color = '#4f46e5',
        defaultInstalled = false,
        adminOnly = true,
        resource = GetCurrentResourceName(),
    }
end

registerBuiltInApps()

local function ensureSystemApps(identifier)
    if not identifier then return end
    for appId in pairs(SystemApps) do
        MySQL.insert.await(
            'INSERT IGNORE INTO ya_tablet_installed_apps (identifier, app_id) VALUES (?, ?)',
            { identifier, appId }
        )
    end
end

local function ensureDefaultApps(identifier)
    if not identifier then return end
    for _, app in pairs(RegisteredApps) do
        if app.defaultInstalled and not app.adminOnly and not isSystemApp(app.id) then
            MySQL.insert.await(
                'INSERT IGNORE INTO ya_tablet_installed_apps (identifier, app_id) VALUES (?, ?)',
                { identifier, app.id }
            )
        end
    end
end

exports('RegisterApp', function(def)
    if type(def) ~= 'table' or not def.id then return false end
    RegisteredApps[def.id] = def
    return true
end)

exports('InstallAppForIdentifier', function(identifier, appId)
    if not identifier or not appId or not RegisteredApps[appId] then return false end
    MySQL.insert.await(
        'INSERT IGNORE INTO ya_tablet_installed_apps (identifier, app_id) VALUES (?, ?)',
        { identifier, appId }
    )
    return true
end)

exports('RefreshPlayer', function(src)
    src = tonumber(src)
    if not src then return end
    local payload = buildBootstrap(src)
    if payload then
        TriggerClientEvent('ya_tablet:sync', src, payload)
    end
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ya_tablet_installed_apps` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `identifier` VARCHAR(80) NOT NULL,
          `app_id` VARCHAR(32) NOT NULL,
          `installed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uniq_install` (`identifier`, `app_id`),
          KEY `identifier_idx` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])

    pcall(function()
        MySQL.query.await("UPDATE ya_tablet_installed_apps SET app_id = 'gangs' WHERE app_id = 'orga'")
        MySQL.query.await("UPDATE ya_tablet_installed_apps SET app_id = 'gangs_admin' WHERE app_id = 'admin'")
    end)

    print('[ya_tablet] Database ready.')
    print('[ya_tablet] UI v1.2.9 (Garage-app). Run: ensure ya_tablet')
end)

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function getCharacterName(xPlayer)
    if not xPlayer then return 'Ukendt' end
    if xPlayer.getName then return xPlayer.getName() end
    return xPlayer.name or 'Ukendt'
end

local function isAdmin(src)
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

local function hasTablet(src)
    if GetResourceState('ox_inventory') ~= 'started' then return true end
    local count = exports.ox_inventory:GetItemCount(src, Config.ItemName)
    return (count or 0) > 0
end

local function getInstalledApps(identifier)
    local rows = MySQL.query.await(
        'SELECT app_id FROM ya_tablet_installed_apps WHERE identifier = ?',
        { identifier }
    ) or {}
    local installed = {}
    for i = 1, #rows do
        installed[rows[i].app_id] = true
    end
    return installed
end

local function ensureAdminApps(identifier, src)
    if not identifier or not isAdmin(src) then return end
    for _, app in pairs(RegisteredApps) do
        if app.adminOnly then
            MySQL.insert.await(
                'INSERT IGNORE INTO ya_tablet_installed_apps (identifier, app_id) VALUES (?, ?)',
                { identifier, app.id }
            )
        end
    end
end

local function getAppList(src)
    local identifier = getIdentifier(src)
    if identifier then
        ensureSystemApps(identifier)
        ensureDefaultApps(identifier)
        ensureAdminApps(identifier, src)
    end

    local installed = getInstalledApps(identifier)
    local storeApps = {}

    for _, app in pairs(RegisteredApps) do
        if not isSystemApp(app.id) and (not app.adminOnly or isAdmin(src)) then
            storeApps[#storeApps + 1] = {
                id = app.id,
                name = app.name,
                desc = app.desc,
                icon = app.icon,
                color = app.color,
                image = app.image,
                installed = installed[app.id] == true,
                adminOnly = app.adminOnly == true,
                resource = app.resource,
            }
        end
    end

    table.sort(storeApps, function(a, b)
        return (a.name or '') < (b.name or '')
    end)

    local homeApps = {}
    for _, app in pairs(SystemApps) do
        homeApps[#homeApps + 1] = {
            id = app.id,
            name = app.name,
            desc = app.desc,
            icon = app.icon,
            color = app.color,
            image = app.image,
            installed = true,
            systemApp = true,
            adminOnly = app.adminOnly == true,
            resource = app.resource,
        }
    end

    table.sort(homeApps, function(a, b)
        if a.id == 'apps' then return true end
        if b.id == 'apps' then return false end
        return (a.name or '') < (b.name or '')
    end)

    for i = 1, #storeApps do
        if storeApps[i].installed then
            homeApps[#homeApps + 1] = storeApps[i]
        end
    end

    -- Sikr at admins altid ser Admin-appen på forsiden
    if isAdmin(src) and RegisteredApps.gangs_admin then
        local hasAdmin = false
        for i = 1, #homeApps do
            if homeApps[i].id == 'gangs_admin' then
                hasAdmin = true
                break
            end
        end
        if not hasAdmin then
            local app = RegisteredApps.gangs_admin
            homeApps[#homeApps + 1] = {
                id = app.id,
                name = app.name,
                desc = app.desc,
                icon = app.icon,
                color = app.color,
                image = app.image,
                installed = true,
                adminOnly = true,
                resource = app.resource,
            }
        end
    end

    return storeApps, homeApps
end

function buildBootstrap(src)
    local identifier = getIdentifier(src)
    if not identifier then return nil end

    local storeApps, homeApps = getAppList(src)
    local payload = {
        playerName = getCharacterName(ESX.GetPlayerFromId(src)),
        isAdmin = isAdmin(src),
        apps = storeApps,
        homeApps = homeApps,
        uiVersion = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or 'unknown',
    }

    if GetResourceState('ya_gangs') == 'started' then
        local ok, gangData = pcall(function()
            return exports.ya_gangs:GetTabletData(src)
        end)
        if ok and type(gangData) == 'table' then
            for key, value in pairs(gangData) do
                payload[key] = value
            end
        end
    end

    return payload
end

local function notify(src, msg)
    TriggerClientEvent('ya_tablet:notify', src, msg)
end

RegisterNetEvent('ya_tablet:requestSync', function()
    local src = source
    local payload = buildBootstrap(src)
    if payload then
        TriggerClientEvent('ya_tablet:sync', src, payload)
    end
end)

ESX.RegisterServerCallback('ya_tablet:getBootstrap', function(source, cb)
    cb(buildBootstrap(source) or {})
end)

RegisterNetEvent('ya_tablet:requestOpen', function()
    local src = source
    if not hasTablet(src) then
        notify(src, 'Du skal have en tablet på dig.')
        return
    end

    local payload = buildBootstrap(src)
    if not payload then
        notify(src, 'Kunne ikke åbne tabletten.')
        return
    end

    TriggerClientEvent('ya_tablet:openUI', src, payload)
end)

RegisterNetEvent('ya_tablet:installApp', function(appId)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier or not appId or isSystemApp(appId) or not RegisteredApps[appId] then return end

    local app = RegisteredApps[appId]
    if app.adminOnly and not isAdmin(src) then
        notify(src, 'Du har ikke adgang til denne app.')
        return
    end

    MySQL.insert.await(
        'INSERT IGNORE INTO ya_tablet_installed_apps (identifier, app_id) VALUES (?, ?)',
        { identifier, appId }
    )
    notify(src, ('%s er installeret.'):format(app.name))
    TriggerClientEvent('ya_tablet:sync', src, buildBootstrap(src))
end)
