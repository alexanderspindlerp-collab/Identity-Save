-- Admin: opret og administrer værkstedsfirmaer

local function extractCreateShopPayload(companyId, shopLocations, shopBlips)
    local shopKey = WS.companyShopKey(companyId)
    local filtered, blipMeta = {}, {}

    if type(shopLocations) == 'table' then
        local loc = shopLocations[shopKey] or shopLocations.company_new
        if not loc then
            for _, value in pairs(shopLocations) do
                if type(value) == 'table' and WS.isValidShopCoords(value) then
                    loc = value
                    break
                end
            end
        end
        if WS.isValidShopCoords(loc) then
            filtered[shopKey] = loc
        end
    end

    if type(shopBlips) == 'table' then
        local meta = shopBlips[shopKey] or shopBlips.company_new
        if not meta then
            for _, value in pairs(shopBlips) do
                if type(value) == 'table' then
                    meta = value
                    break
                end
            end
        end
        if meta then
            blipMeta[shopKey] = meta
        end
    end

    return shopKey, filtered, blipMeta
end

RegisterNetEvent('ya_workshop:adminListCompanies', function()
    local src = source
    if not WS.isAdmin(src) then
        WS.notify(src, 'Du har ikke adgang til værksteds-admin.', 'error')
        return
    end
    WS.pushAdminCompanyList(src)
end)

RegisterNetEvent('ya_workshop:adminCreateCompany', function(name, ownerId, companyType, jobName, shopKeys, shopLocations, shopBlips)
    local src = source
    local ok, err = pcall(function()
    if not WS.isAdmin(src) then return end

    name = type(name) == 'string' and name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if #name < Config.Company.MinNameLength or #name > Config.Company.MaxNameLength then
        WS.notify(src, ('Navn skal være mellem %d og %d tegn.'):format(
            Config.Company.MinNameLength, Config.Company.MaxNameLength
        ), 'error')
        return
    end

    companyType = type(companyType) == 'string' and companyType:lower() or 'bennys'
    companyType = WS.normalizeCompanyType(companyType)

    local exists = MySQL.scalar.await(
        'SELECT id FROM ya_workshop_companies WHERE LOWER(name) = LOWER(?) LIMIT 1',
        { name }
    )
    if exists then
        WS.notify(src, 'Det navn er allerede i brug.', 'error')
        return
    end

    if not ownerId or tonumber(ownerId) == nil or tonumber(ownerId) < 1 then
        WS.notify(src, 'Angiv et gyldigt ejer spiller-ID.', 'error')
        return
    end

    local ownerIdentifier, err, xOwner = WS.resolveOwnerIdentifier(ownerId)
    if not ownerIdentifier then
        WS.notify(src, err or 'Ugyldig ejer.', 'error')
        return
    end

    jobName = type(jobName) == 'string' and jobName:gsub('^%s+', ''):gsub('%s+$', '') or nil
    if jobName == '' then jobName = nil end

    local previewKey = 'company_new'
    local previewLoc = type(shopLocations) == 'table' and (shopLocations[previewKey] or shopLocations.company_new) or nil
    if not WS.isValidShopCoords(previewLoc) and type(shopLocations) == 'table' then
        for _, value in pairs(shopLocations) do
            if WS.isValidShopCoords(value) then
                previewLoc = value
                break
            end
        end
    end
    if not WS.isValidShopCoords(previewLoc) then
        WS.notify(src, 'Sæt butik-position med "Brug min position" før oprettelse.', 'error')
        return
    end

    local companyId
    local insertOk, insertResult = pcall(function()
        return MySQL.insert.await(
            'INSERT INTO ya_workshop_companies (name, company_type, job_name, color, owner_identifier, balance) VALUES (?, ?, ?, ?, ?, ?)',
            { name, companyType, jobName, Config.Company.DefaultColor, ownerIdentifier, Config.Company.StartingBalance or 0 }
        )
    end)

    if not insertOk then
        local insertErr = tostring(insertResult or '')
        if insertErr:find('Duplicate', 1, true) or insertErr:find('uniq_workshop_name', 1, true) then
            WS.notify(src, 'Det navn er allerede i brug.', 'error')
        else
            WS.notify(src, 'Kunne ikke oprette værksted. Tjek server-konsollen.', 'error')
            print(('[ya_workshop] adminCreateCompany insert failed: %s'):format(insertErr))
        end
        return
    end

    companyId = insertResult
    if not companyId then
        WS.notify(src, 'Kunne ikke oprette værksted.', 'error')
        return
    end

    local shopKey, filtered, blipMeta = extractCreateShopPayload(companyId, shopLocations, shopBlips)

    if not filtered[shopKey] then
        MySQL.update.await('DELETE FROM ya_workshop_companies WHERE id = ?', { companyId })
        WS.notify(src, 'Sæt butik-position med "Brug min position" før oprettelse.', 'error')
        return
    end

    local okShops, shopErr = WS.setCompanyShops(companyId, { shopKey }, blipMeta)
    if not okShops then
        MySQL.update.await('DELETE FROM ya_workshop_companies WHERE id = ?', { companyId })
        WS.notify(src, shopErr or 'Kunne ikke tilknytte butikker.', 'error')
        return
    end

    if type(shopLocations) == 'table' then
        local okLoc, locErr = WS.applyShopLocations(filtered)
        if not okLoc then
            WS.notify(src, locErr or 'Firma oprettet, men butik-position kunne ikke gemmes.', 'error')
        end
    end

    WS.seedDefaultRoles(companyId)
    local ownerRoleId = WS.getOwnerRoleId(companyId)
    MySQL.insert.await(
        'INSERT INTO ya_workshop_members (company_id, identifier, character_name, role_id) VALUES (?, ?, ?, ?)',
        { companyId, ownerIdentifier, WS.getCharacterName(xOwner), ownerRoleId }
    )

    WS.installWorkshopApp(ownerIdentifier)
    WS.notify(src, ('Værksted "%s" oprettet.'):format(name), 'success')
    WS.broadcastShopLocations()
    WS.refreshTablet(ownerId)
    WS.pushAdminCompanyList(src)
    end)

    if not ok then
        print(('[ya_workshop] adminCreateCompany error: %s'):format(err))
        WS.notify(src, 'Kunne ikke oprette værksted. Tjek server-konsollen.', 'error')
    end
end)

RegisterNetEvent('ya_workshop:adminGetCompany', function(companyId)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId = tonumber(companyId)
    if not companyId then return end
    WS.pushAdminCompanyDetail(src, companyId)
end)

RegisterNetEvent('ya_workshop:adminUpdateCompany', function(companyId, patch)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId = tonumber(companyId)
    if not companyId or type(patch) ~= 'table' then return end

    local row = MySQL.single.await('SELECT id, closed FROM ya_workshop_companies WHERE id = ? LIMIT 1', { companyId })
    if not row then WS.notify(src, 'Værksted ikke fundet.', 'error'); return end
    if row.closed == 1 then WS.notify(src, 'Værkstedet er lukket.', 'error'); return end

    local updates = {}
    local params = {}

    if type(patch.name) == 'string' then
        local newName = patch.name:gsub('^%s+', ''):gsub('%s+$', '')
        if #newName < Config.Company.MinNameLength or #newName > Config.Company.MaxNameLength then
            WS.notify(src, 'Ugyldigt navn.', 'error')
            return
        end
        updates[#updates + 1] = 'name = ?'
        params[#params + 1] = newName
    end

    if type(patch.color) == 'string' and patch.color:match('^#%x%x%x%x%x%x$') then
        updates[#updates + 1] = 'color = ?'
        params[#params + 1] = patch.color
    end

    if type(patch.jobName) == 'string' then
        updates[#updates + 1] = 'job_name = ?'
        params[#params + 1] = patch.jobName ~= '' and patch.jobName or nil
    end

    if type(patch.companyType) == 'string' then
        local t = WS.normalizeCompanyType(patch.companyType:lower())
        updates[#updates + 1] = 'company_type = ?'
        params[#params + 1] = t
    end

    local shopUpdated = false
    if patch.shopKeys ~= nil or patch.shopLocations ~= nil or patch.shopBlips ~= nil then
        local keys = patch.shopKeys or WS.getCompanyShopKeys(companyId)
        if #keys == 0 then
            keys = { WS.companyShopKey(companyId) }
        end
        local okShops, shopErr = WS.setCompanyShops(companyId, keys, patch.shopBlips)
        if not okShops then
            WS.notify(src, shopErr or 'Kunne ikke opdatere butikker.', 'error')
            return
        end
        shopUpdated = true
    end

    if type(patch.shopLocations) == 'table' then
        local allowed = {}
        local keys = patch.shopKeys or WS.getCompanyShopKeys(companyId)
        if #keys == 0 then
            keys = { WS.companyShopKey(companyId) }
        end
        for i = 1, #keys do allowed[keys[i]] = true end

        local filtered = {}
        for shopKey, data in pairs(patch.shopLocations) do
            local resolvedKey = shopKey == 'company_new' and WS.companyShopKey(companyId) or shopKey
            if allowed[resolvedKey] and type(data) == 'table' then
                filtered[resolvedKey] = data
            end
        end

        local okLoc, locErr = WS.applyShopLocations(filtered)
        if not okLoc then
            WS.notify(src, locErr or 'Kunne ikke gemme butik-positioner.', 'error')
            return
        end
        shopUpdated = true
    end

    if #updates == 0 and not shopUpdated then
        WS.notify(src, 'Intet at opdatere.', 'error')
        return
    end

    if #updates > 0 then
        params[#params + 1] = companyId
        MySQL.update.await('UPDATE ya_workshop_companies SET ' .. table.concat(updates, ', ') .. ' WHERE id = ?', params)
    end
    WS.notify(src, 'Værksted opdateret.', 'success')
    WS.pushAdminCompanyDetail(src, companyId)
    WS.pushAdminCompanyList(src)
end)

RegisterNetEvent('ya_workshop:adminSetLocked', function(companyId, locked)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId = tonumber(companyId)
    if not companyId then return end
    MySQL.update.await('UPDATE ya_workshop_companies SET locked = ? WHERE id = ?', { locked and 1 or 0, companyId })
    WS.notify(src, locked and 'Værksted låst.' or 'Værksted låst op.', 'success')
    WS.pushAdminCompanyDetail(src, companyId)
    WS.pushAdminCompanyList(src)
end)

RegisterNetEvent('ya_workshop:adminCloseCompany', function(companyId)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId = tonumber(companyId)
    if not companyId then return end

    local members = MySQL.query.await('SELECT identifier FROM ya_workshop_members WHERE company_id = ?', { companyId }) or {}
    WS.cleanupCompanyWorld(companyId)
    MySQL.update.await('UPDATE ya_workshop_companies SET closed = 1, locked = 1 WHERE id = ?', { companyId })
    MySQL.update.await('DELETE FROM ya_workshop_members WHERE company_id = ?', { companyId })

    for i = 1, #members do
        WS.uninstallWorkshopApp(members[i].identifier)
    end

    WS.notify(src, 'Værksted lukket og medlemmer fjernet.', 'success')
    WS.pushAdminCompanyList(src)
end)

RegisterNetEvent('ya_workshop:adminSetOwner', function(companyId, ownerId)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId = tonumber(companyId)
    if not companyId then return end

    local ownerIdentifier, err, xOwner = WS.resolveOwnerIdentifier(ownerId)
    if not ownerIdentifier then
        WS.notify(src, err or 'Ugyldig ejer.', 'error')
        return
    end

    local existing = MySQL.single.await(
        'SELECT id FROM ya_workshop_members WHERE identifier = ? AND company_id <> ? LIMIT 1',
        { ownerIdentifier, companyId }
    )
    if existing then
        WS.notify(src, 'Spilleren er medlem af et andet værksted.', 'error')
        return
    end

    MySQL.update.await('UPDATE ya_workshop_companies SET owner_identifier = ? WHERE id = ?', { ownerIdentifier, companyId })

    local ownerRoleId = WS.getOwnerRoleId(companyId)
    local member = MySQL.single.await('SELECT id FROM ya_workshop_members WHERE company_id = ? AND identifier = ? LIMIT 1', {
        companyId, ownerIdentifier,
    })

    if member then
        MySQL.update.await('UPDATE ya_workshop_members SET role_id = ? WHERE id = ?', { ownerRoleId, member.id })
    else
        MySQL.insert.await(
            'INSERT INTO ya_workshop_members (company_id, identifier, character_name, role_id) VALUES (?, ?, ?, ?)',
            { companyId, ownerIdentifier, WS.getCharacterName(xOwner), ownerRoleId }
        )
    end

    WS.installWorkshopApp(ownerIdentifier)
    WS.notify(src, 'Ejer opdateret.', 'success')
    WS.refreshTablet(ownerId)
    WS.pushAdminCompanyDetail(src, companyId)
end)

RegisterNetEvent('ya_workshop:adminSetMemberRole', function(companyId, memberId, roleId)
    local src = source
    if not WS.isAdmin(src) then return end
    if WS.setMemberRole(companyId, memberId, roleId) then
        WS.notify(src, 'Rolle opdateret.', 'success')
        WS.pushAdminCompanyDetail(src, tonumber(companyId))
    end
end)

RegisterNetEvent('ya_workshop:adminKickMember', function(companyId, memberId)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId, memberId = tonumber(companyId), tonumber(memberId)
    if not companyId or not memberId then return end

    local member = MySQL.single.await(
        'SELECT identifier FROM ya_workshop_members WHERE id = ? AND company_id = ? LIMIT 1',
        { memberId, companyId }
    )
    if not member then return end

    MySQL.update.await('DELETE FROM ya_workshop_members WHERE id = ? AND company_id = ?', { memberId, companyId })
    WS.uninstallWorkshopApp(member.identifier)
    WS.notify(src, 'Medarbejder fjernet.', 'success')
    WS.pushAdminCompanyDetail(src, companyId)
end)

RegisterNetEvent('ya_workshop:adminAddMember', function(companyId, targetId)
    local src = source
    if not WS.isAdmin(src) then return end
    local ok, err = WS.addMemberToCompany(companyId, targetId)
    if ok then
        WS.notify(src, 'Medarbejder tilføjet.', 'success')
        WS.pushAdminCompanyDetail(src, tonumber(companyId))
    else
        WS.notify(src, err or 'Kunne ikke tilføje medarbejder.', 'error')
    end
end)

RegisterNetEvent('ya_workshop:adminUpsertRole', function(companyId, roleId, name, permissions)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId, roleId = tonumber(companyId), tonumber(roleId)
    if not companyId then return end

    name = type(name) == 'string' and name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if name == '' then WS.notify(src, 'Rollenavn påkrævet.', 'error'); return end

    permissions = type(permissions) == 'table' and permissions or {}

    if roleId then
        local role = MySQL.single.await(
            'SELECT role_key FROM ya_workshop_roles WHERE id = ? AND company_id = ? LIMIT 1',
            { roleId, companyId }
        )
        if not role or role.role_key == 'owner' then
            WS.notify(src, 'Kan ikke redigere ejer-rollen.', 'error')
            return
        end
        MySQL.update.await(
            'UPDATE ya_workshop_roles SET name = ?, permissions = ? WHERE id = ? AND company_id = ?',
            { name, WS.encodePermissions(permissions), roleId, companyId }
        )
    else
        local sortOrder = MySQL.scalar.await(
            'SELECT COALESCE(MAX(sort_order), 0) + 1 FROM ya_workshop_roles WHERE company_id = ?',
            { companyId }
        ) or 99
        local roleKey = ('custom_%s'):format(math.random(1000, 9999))
        MySQL.insert.await(
            'INSERT INTO ya_workshop_roles (company_id, role_key, name, permissions, is_default, sort_order) VALUES (?, ?, ?, ?, 0, ?)',
            { companyId, roleKey, name, WS.encodePermissions(permissions), sortOrder }
        )
    end

    WS.notify(src, 'Rolle gemt.', 'success')
    WS.pushAdminCompanyDetail(src, companyId)
end)

RegisterNetEvent('ya_workshop:adminDeleteRole', function(companyId, roleId)
    local src = source
    if not WS.isAdmin(src) then return end
    companyId, roleId = tonumber(companyId), tonumber(roleId)
    if not companyId or not roleId then return end

    local role = MySQL.single.await(
        'SELECT role_key, is_default FROM ya_workshop_roles WHERE id = ? AND company_id = ? LIMIT 1',
        { roleId, companyId }
    )
    if not role or role.role_key == 'owner' then
        WS.notify(src, 'Kan ikke slette denne rolle.', 'error')
        return
    end

    local defaultRole = MySQL.single.await(
        'SELECT id FROM ya_workshop_roles WHERE company_id = ? AND is_default = 1 ORDER BY sort_order ASC LIMIT 1',
        { companyId }
    )
    if not defaultRole then return end

    MySQL.update.await('UPDATE ya_workshop_members SET role_id = ? WHERE role_id = ? AND company_id = ?', {
        defaultRole.id, roleId, companyId,
    })
    MySQL.update.await('DELETE FROM ya_workshop_roles WHERE id = ? AND company_id = ?', { roleId, companyId })
    WS.notify(src, 'Rolle slettet.', 'success')
    WS.pushAdminCompanyDetail(src, companyId)
end)

RegisterNetEvent('ya_workshop:adminSetShopLocation', function(shopKey, x, y, z, radius)
    local src = source
    if not WS.isAdmin(src) then return end
    if type(shopKey) ~= 'string' then return end

    local ok, err = WS.setShopLocation(shopKey, x, y, z, radius)
    if not ok then
        WS.notify(src, err or 'Kunne ikke gemme position.', 'error')
        return
    end

    WS.notify(src, 'Butik-position gemt.', 'success')
    WS.pushAdminCompanyList(src)
end)
