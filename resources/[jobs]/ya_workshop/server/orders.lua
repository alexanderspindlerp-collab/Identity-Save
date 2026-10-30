local ESX = exports['es_extended']:getSharedObject()

RegisterNetEvent('ya_workshop:submitOrder', function(shopKey, cart, vehicleData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if type(cart) ~= 'table' or #cart == 0 then
        WS.notify(src, 'Kurven er tom.', 'error')
        return
    end

    if type(vehicleData) ~= 'table' or not vehicleData.plate then
        WS.notify(src, 'Køretøjsdata mangler.', 'error')
        return
    end

    local shop = WS.getShopDefinition(shopKey)
    if not shop then
        WS.notify(src, 'Ugyldig butik.', 'error')
        return
    end

    local company = WS.getCompanyForShop(shopKey)
    if not company then
        WS.notify(src, 'Ingen butik er koblet til et firma her. Kontakt admin.', 'error')
        return
    end

    local identifier = xPlayer.identifier
    local ownedRow = WS.findOwnedVehicle(identifier, vehicleData.plate)
    if not ownedRow then
        WS.notify(src, 'Du ejer ikke dette køretøj i garagen.', 'error')
        return
    end
    local plate = ownedRow.plate or WS.normalizePlate(vehicleData.plate)

    local overrides = WS.loadPriceOverrides(company.id)
    local total = 0
    local validItems = {}
    local newUnlocks = {}

    for i = 1, #cart do
        local line = cart[i]
        if type(line) == 'table' and line.categoryKey and line.groupKey then
            local lineType = line.type == 'unlock' and 'unlock' or 'item'
            local itemKey = lineType == 'unlock' and '_open' or line.itemKey
            if not itemKey then goto continue end

            local entry = WS.findCatalogEntry(line.categoryKey, line.groupKey, itemKey, lineType, company.company_type)
            if entry then
                local price = WS.resolvePrice(overrides, entry.categoryKey, entry.groupKey, entry.itemKey, entry.defaultPrice)
                if lineType == 'unlock' and WS.isGroupUnlocked(identifier, plate, shopKey, entry.categoryKey, entry.groupKey) then
                    price = 0
                end
                local modData = lineType == 'item' and line.mod or nil
                local modJson = modData and json.encode(modData) or nil
                total = total + price
                validItems[#validItems + 1] = {
                    categoryKey = entry.categoryKey,
                    groupKey = entry.groupKey,
                    itemKey = line.variantKey or itemKey,
                    lineType = entry.lineType,
                    label = line.label or entry.label,
                    description = entry.description,
                    price = price,
                    mod = modData,
                    modJson = modJson,
                }
                if lineType == 'unlock' and price > 0 then
                    newUnlocks[#newUnlocks + 1] = {
                        categoryKey = entry.categoryKey,
                        groupKey = entry.groupKey,
                    }
                end
            end
        end
        ::continue::
    end

    if #validItems == 0 then
        WS.notify(src, 'Ingen gyldige dele i kurven.', 'error')
        return
    end

    local customerName = WS.getCharacterName(xPlayer)
    local orderNumber = WS.nextOrderNumber()

    local baselineProps = vehicleData.props
    local targetProps = WS.buildTargetVehicleProps(baselineProps, cart)
    local baselineJson = baselineProps and json.encode(baselineProps) or nil
    local targetJson = json.encode(targetProps)

    local orderId = MySQL.insert.await([[
        INSERT INTO ya_workshop_orders
        (company_id, order_number, status, customer_identifier, customer_name, vehicle_plate, vehicle_model, vehicle_label, vehicle_props, target_vehicle_props, total_price, shop_key)
        VALUES (?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        company.id,
        orderNumber,
        identifier,
        customerName,
        plate,
        vehicleData.model,
        vehicleData.label,
        baselineJson,
        targetJson,
        total,
        shopKey,
    })

    for i = 1, #validItems do
        local item = validItems[i]
        MySQL.insert.await([[
            INSERT INTO ya_workshop_order_items (order_id, category_key, group_key, item_key, line_type, label, description, price, mod_data)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            orderId,
            item.categoryKey,
            item.groupKey,
            item.itemKey,
            item.lineType,
            item.label,
            item.description,
            item.price,
            item.modJson,
        })
    end

    for i = 1, #newUnlocks do
        local unlock = newUnlocks[i]
        WS.saveUnlockedGroup(identifier, plate, shopKey, unlock.categoryKey, unlock.groupKey)
    end

    WS.notify(src, ('Bestilling %s oprettet — %s DKK. Tuning gemmes når mekaniker booster bilen.'):format(orderNumber, total), 'success')
    TriggerClientEvent('ya_workshop:orderPlaced', src, { orderNumber = orderNumber, total = total })

    local members = MySQL.query.await('SELECT identifier FROM ya_workshop_members WHERE company_id = ?', { company.id }) or {}
    for i = 1, #members do
        local xMember = ESX.GetPlayerFromIdentifier(members[i].identifier)
        if xMember and xMember.source then
            WS.notify(xMember.source, ('Ny bestilling %s — %s'):format(orderNumber, vehicleData.plate), 'info')
        end
    end
end)

RegisterNetEvent('ya_workshop:createCall', function(companyType, message)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    message = type(message) == 'string' and message:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if message == '' or #message > 255 then
        WS.notify(src, 'Besked skal udfyldes (max 255 tegn).', 'error')
        return
    end

    companyType = WS.normalizeCompanyType(companyType)
    local company = WS.getCompanyByType(companyType)
    if not company then
        WS.notify(src, 'Intet værksted tilgængeligt.', 'error')
        return
    end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)

    MySQL.insert.await([[
        INSERT INTO ya_workshop_calls (company_id, caller_identifier, caller_name, message, coords_x, coords_y, coords_z, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, 'open')
    ]], {
        company.id,
        xPlayer.identifier,
        WS.getCharacterName(xPlayer),
        message,
        coords.x,
        coords.y,
        coords.z,
    })

    WS.notify(src, 'Opkald sendt til værkstedet.', 'success')

    local members = MySQL.query.await('SELECT identifier FROM ya_workshop_members WHERE company_id = ?', { company.id }) or {}
    for i = 1, #members do
        local xMember = ESX.GetPlayerFromIdentifier(members[i].identifier)
        if xMember and xMember.source then
            WS.notify(xMember.source, 'Nyt opkald modtaget.', 'info')
        end
    end
end)

RegisterNetEvent('ya_workshop:setOrderWaypoint', function(callId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then return end

    callId = tonumber(callId)
    if not callId then return end

    local call = MySQL.single.await(
        'SELECT coords_x, coords_y FROM ya_workshop_calls WHERE id = ? AND company_id = ? LIMIT 1',
        { callId, row.company_id }
    )
    if call and call.coords_x and call.coords_y then
        TriggerClientEvent('ya_workshop:setWaypoint', src, call.coords_x, call.coords_y)
    end
end)
