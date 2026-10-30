local ESX = exports['es_extended']:getSharedObject()

local function calculateBoostDuration(itemCount)
    local cfg = Config.Boost or {}
    local minMs = cfg.MinDuration or 30000
    local maxMs = cfg.MaxDuration or 45000
    local perItem = cfg.MsPerItem or 3000
    itemCount = math.max(tonumber(itemCount) or 1, 1)
    local duration = minMs + (itemCount - 1) * perItem
    return math.min(math.max(duration, minMs), maxMs)
end

local function getBoostLabel(itemCount)
    local cfg = Config.Boost or {}
    local labels = cfg.Labels or {}
    itemCount = tonumber(itemCount) or 1
    if itemCount >= 5 then return labels.many or 'Færdiggør omfattende tuning...' end
    if itemCount >= 3 then return labels.medium or 'Udfører tuning...' end
    return labels.few or 'Monterer dele...'
end

local function findBoostOrderByPlate(companyId, plate)
    plate = WS.normalizePlate(plate)
    if plate == '' then return nil end

    local rows = MySQL.query.await([[
        SELECT o.*
        FROM ya_workshop_orders o
        WHERE o.company_id = ? AND o.status IN ('in_progress', 'pending')
        ORDER BY FIELD(o.status, 'in_progress', 'pending'), o.id DESC
        LIMIT 30
    ]], { companyId }) or {}

    for i = 1, #rows do
        if WS.normalizePlate(rows[i].vehicle_plate) ~= plate then
            goto continue
        end

        if rows[i].status == 'in_progress' then
            return rows[i]
        end

        if rows[i].status == 'pending' then
            local hasInvoice = MySQL.scalar.await(
                'SELECT id FROM ya_workshop_invoices WHERE order_id = ? LIMIT 1',
                { rows[i].id }
            )
            if hasInvoice then
                return rows[i]
            end
        end

        ::continue::
    end

    return nil
end

local function getBoostablePlateRows(companyId)
    return MySQL.query.await([[
        SELECT o.vehicle_plate
        FROM ya_workshop_orders o
        WHERE o.company_id = ?
          AND (
            o.status = 'in_progress'
            OR (
                o.status = 'pending'
                AND EXISTS (SELECT 1 FROM ya_workshop_invoices i WHERE i.order_id = o.id)
            )
          )
        ORDER BY FIELD(o.status, 'in_progress', 'pending'), o.id DESC
    ]], { companyId }) or {}
end

local function ensureOrderInProgressForBoost(src, row, order)
    if order.status ~= 'pending' then return order end

    local identifier = WS.getIdentifier(src)
    local name = WS.getCharacterName(ESX.GetPlayerFromId(src))
    MySQL.update.await([[
        UPDATE ya_workshop_orders
        SET status = 'in_progress', assigned_to = ?, assigned_name = ?
        WHERE id = ? AND company_id = ? AND status = 'pending'
    ]], { identifier, name, order.id, row.company_id })

    order.status = 'in_progress'
    order.assigned_to = identifier
    order.assigned_name = name
    return order
end

local function getBoostFailureMessage(companyId, plate)
    local rows = MySQL.query.await([[
        SELECT vehicle_plate, status
        FROM ya_workshop_orders
        WHERE company_id = ?
        ORDER BY id DESC
        LIMIT 40
    ]], { companyId }) or {}

    for i = 1, #rows do
        if WS.normalizePlate(rows[i].vehicle_plate) == plate then
            if rows[i].status == 'completed' then
                return 'Bestillingen er allerede færdig (boostet).'
            end
            if rows[i].status == 'pending' then
                return 'Start arbejde i tabletten først — eller send faktura efter arbejdet er startet.'
            end
            if rows[i].status == 'cancelled' then
                return 'Bestillingen er annulleret.'
            end
            break
        end
    end

    return ('Ingen aktiv bestilling for %s. Tryk "Start arbejde" i tabletten først.'):format(plate)
end

local function playerNearVehicle(src, netId, maxDistance)
    netId = tonumber(netId)
    if not netId then return false end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 then return true end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    maxDistance = tonumber(maxDistance) or (Config.Boost and Config.Boost.MaxDistance) or 5.0
    local pedCoords = GetEntityCoords(ped)
    local vehCoords = GetEntityCoords(vehicle)

    if type(pedCoords) == 'vector3' and type(vehCoords) == 'vector3' then
        return #(pedCoords - vehCoords) <= maxDistance
    end

    local px, py, pz = GetEntityCoords(ped)
    local vx, vy, vz = GetEntityCoords(vehicle)
    local dx, dy, dz = px - vx, py - vy, pz - vz
    return (dx * dx + dy * dy + dz * dz) <= (maxDistance * maxDistance)
end

ESX.RegisterServerCallback('ya_workshop:getBoostJobInfo', function(source, cb, plate)
    local row, err = WS.requireMember(source)
    if not row then
        cb({ ok = false, message = err or 'Ingen adgang.' })
        return
    end
    if not WS.roleCan(row, 'manage_orders') then
        cb({ ok = false, message = 'Ingen adgang.' })
        return
    end

    plate = WS.normalizePlate(plate)
    if plate == '' then
        cb({ ok = false, message = 'Ugyldig nummerplade.' })
        return
    end

    local order = findBoostOrderByPlate(row.company_id, plate)
    if not order then
        cb({ ok = false, message = getBoostFailureMessage(row.company_id, plate) })
        return
    end

    local itemCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM ya_workshop_order_items WHERE order_id = ? AND line_type = ?',
        { order.id, 'item' }
    ) or 0
    itemCount = math.max(tonumber(itemCount) or 0, 1)

    cb({
        ok = true,
        duration = calculateBoostDuration(itemCount),
        label = getBoostLabel(itemCount),
        itemCount = itemCount,
        orderNumber = order.order_number,
    })
end)

ESX.RegisterServerCallback('ya_workshop:getBoostablePlates', function(source, cb)
    local row, err = WS.requireMember(source)
    if not row then cb({}); return end
    if not WS.roleCan(row, 'manage_orders') then cb({}); return end

    local rows = getBoostablePlateRows(row.company_id)

    local plates = {}
    for i = 1, #rows do
        plates[#plates + 1] = WS.normalizePlate(rows[i].vehicle_plate)
    end
    cb(plates)
end)

ESX.RegisterServerCallback('ya_workshop:getMechanicBoostState', function(source, cb)
    local row = WS.getMemberRow(WS.getIdentifier(source))
    if not row then
        cb({ isEmployee = false, canManageOrders = false, plates = {} })
        return
    end

    if not WS.roleCan(row, 'manage_orders') then
        cb({ isEmployee = true, canManageOrders = false, plates = {} })
        return
    end

    local rows = getBoostablePlateRows(row.company_id)

    local plates = {}
    for i = 1, #rows do
        plates[#plates + 1] = WS.normalizePlate(rows[i].vehicle_plate)
    end

    cb({
        isEmployee = true,
        canManageOrders = true,
        plates = plates,
    })
end)

local function notifyCompanyBoostable(companyId)
    local members = MySQL.query.await(
        'SELECT identifier FROM ya_workshop_members WHERE company_id = ?',
        { companyId }
    ) or {}

    for i = 1, #members do
        local xMember = ESX.GetPlayerFromIdentifier(members[i].identifier)
        if xMember and xMember.source then
            TriggerClientEvent('ya_workshop:boostableOrdersChanged', xMember.source)
        end
    end
end

RegisterNetEvent('ya_workshop:boostVehicle', function(netId, plate)
    local src = source

    local function boostReply(success, message)
        WS.notify(src, message, success and 'success' or 'error')
        TriggerClientEvent('ya_workshop:boostResult', src, success, message)
    end

    local row, err = WS.requireMember(src)
    if not row then boostReply(false, err or 'Ingen adgang.'); return end
    if not WS.roleCan(row, 'manage_orders') then boostReply(false, 'Ingen adgang.'); return end

    plate = WS.normalizePlate(plate)
    if plate == '' then
        boostReply(false, 'Ugyldig nummerplade.')
        return
    end

    if not playerNearVehicle(src, netId, Config.Boost and Config.Boost.MaxDistance) then
        boostReply(false, 'Du er for langt væk fra bilen.')
        return
    end

    local order = findBoostOrderByPlate(row.company_id, plate)

    if not order then
        boostReply(false, getBoostFailureMessage(row.company_id, plate))
        return
    end

    order = ensureOrderInProgressForBoost(src, row, order)

    local propsJson = order.target_vehicle_props
    local props

    if propsJson and propsJson ~= '' then
        props = json.decode(propsJson)
    end

    if type(props) ~= 'table' then
        local baseline = order.vehicle_props and json.decode(order.vehicle_props) or nil
        local items = MySQL.query.await(
            'SELECT mod_data FROM ya_workshop_order_items WHERE order_id = ? AND line_type = ? ORDER BY id ASC',
            { order.id, 'item' }
        ) or {}
        props = WS.buildTargetFromOrderItems(baseline, items)
    end

    if type(props) ~= 'table' then
        boostReply(false, 'Ugyldige tuning-data.')
        return
    end

    props.plate = order.vehicle_plate or props.plate

    local ok, saveErr = WS.saveOwnedVehicleProps(order.customer_identifier, props)
    if not ok then
        boostReply(false, saveErr or 'Kunne ikke gemme i garagen.')
        return
    end

    MySQL.update.await([[
        UPDATE ya_workshop_orders
        SET status = 'completed', completed_at = NOW()
        WHERE id = ? AND company_id = ?
    ]], { order.id, row.company_id })

    netId = tonumber(netId)
    if netId then
        TriggerClientEvent('ya_workshop:applyVehicleProps', -1, netId, props)
    end

    local successMsg = ('Boost færdig — %s gemt i garagen.'):format(order.order_number)
    boostReply(true, successMsg)

    local xCustomer = ESX.GetPlayerFromIdentifier(order.customer_identifier)
    if xCustomer and xCustomer.source then
        WS.notify(xCustomer.source, ('Din tuning på %s er færdig!'):format(plate), 'success')
    end

    notifyCompanyBoostable(row.company_id)
    WS.pushAppData(src, 'bestillinger', row)
end)
