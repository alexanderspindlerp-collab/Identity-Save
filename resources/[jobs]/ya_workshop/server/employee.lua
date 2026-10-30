local ESX = exports['es_extended']:getSharedObject()

local function formatOrderRow(row)
    local shopDef = row.shop_key and WS.getShopDefinition(row.shop_key)
    return {
        id = row.id,
        orderNumber = row.order_number,
        status = row.status,
        statusLabel = Config.OrderStatuses[row.status] or row.status,
        customerName = row.customer_name,
        vehiclePlate = row.vehicle_plate,
        vehicleLabel = row.vehicle_label,
        totalPrice = row.total_price,
        assignedName = row.assigned_name,
        createdAt = row.created_at_label,
        completedAt = row.completed_at_label,
        shopKey = row.shop_key,
        shopLabel = shopDef and shopDef.label or row.shop_key,
        hasInvoice = row.invoice_id ~= nil,
        invoiceId = row.invoice_id,
        invoiceNumber = row.invoice_number,
        invoiceStatus = row.invoice_status,
        paidAtLabel = row.paid_at_label,
    }
end

local function notifyCompanyTabletRefresh(companyId, tabs)
    tabs = type(tabs) == 'table' and tabs or { 'bestillinger', 'faktura', 'faerdige_ordre', 'oversigt' }
    local members = MySQL.query.await(
        'SELECT identifier FROM ya_workshop_members WHERE company_id = ?',
        { companyId }
    ) or {}

    for i = 1, #members do
        local row = WS.getMemberRow(members[i].identifier)
        if row then
            local xMember = ESX.GetPlayerFromIdentifier(members[i].identifier)
            if xMember and xMember.source then
                for t = 1, #tabs do
                    WS.pushAppData(xMember.source, tabs[t], row)
                end
            end
        end
    end
end

local function notifyCompanyBoostRefresh(companyId, extraSrc)
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
    if extraSrc then
        TriggerClientEvent('ya_workshop:boostableOrdersChanged', extraSrc)
    end
end

local function getInvoiceForOrder(orderId)
    return MySQL.single.await(
        'SELECT id, invoice_number, status FROM ya_workshop_invoices WHERE order_id = ? LIMIT 1',
        { orderId }
    )
end

local function notifyInvoiceCustomer(customerIdentifier, invoiceNumber, total, companyName)
    if not customerIdentifier or customerIdentifier == '' then return end
    local xTarget = ESX.GetPlayerFromIdentifier(customerIdentifier)
    if not xTarget or not xTarget.source then return end
    WS.notify(
        xTarget.source,
        ('Du har modtaget faktura %s på %s DKK fra %s. Betal med /betalfaktura %s'):format(
            invoiceNumber,
            total,
            companyName or 'værkstedet',
            invoiceNumber
        ),
        'inform'
    )
end

local function createWorkshopInvoice(companyId, orderId, customerIdentifier, customerName, description, totalPrice, createdBy, createdByName)
    totalPrice = math.floor(tonumber(totalPrice) or 0)
    if totalPrice <= 0 then return nil, 'Beløbet skal være større end 0.' end

    local subtotal, vatAmount, total = WS.calcVat(totalPrice)
    local invoiceNumber = WS.nextInvoiceNumber()
    local invoiceId = MySQL.insert.await([[
        INSERT INTO ya_workshop_invoices
        (company_id, order_id, invoice_number, status, customer_identifier, customer_name, description, subtotal, vat_amount, total, created_by, created_by_name)
        VALUES (?, ?, ?, 'unpaid', ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        companyId,
        orderId,
        invoiceNumber,
        customerIdentifier,
        customerName,
        description,
        subtotal,
        vatAmount,
        total,
        createdBy,
        createdByName,
    })

    return invoiceId, invoiceNumber, total
end

local function removePlayerMoney(xPlayer, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false, 'Ugyldigt beløb.' end

    local cash = xPlayer.getMoney and xPlayer.getMoney() or 0
    if cash >= amount then
        xPlayer.removeMoney(amount)
        return true, 'money'
    end

    local bank = xPlayer.getAccount and xPlayer.getAccount('bank') and xPlayer.getAccount('bank').money or 0
    if bank >= amount then
        xPlayer.removeAccountMoney('bank', amount, 'Workshop invoice')
        return true, 'bank'
    end

    return false, 'Du har ikke nok penge (kontant eller bank).'
end

local function payWorkshopInvoiceForPlayer(src, invoiceRef)
    invoiceRef = type(invoiceRef) == 'string' and invoiceRef:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if invoiceRef == '' then
        WS.notify(src, 'Angiv et fakturanummer.', 'error')
        return false
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end

    local invoice = MySQL.single.await([[
        SELECT i.*, c.name AS company_name, c.balance AS company_balance
        FROM ya_workshop_invoices i
        JOIN ya_workshop_companies c ON c.id = i.company_id
        WHERE (i.invoice_number = ? OR i.id = ?) AND i.status = 'unpaid'
        LIMIT 1
    ]], { invoiceRef, tonumber(invoiceRef) or -1 })

    if not invoice then
        WS.notify(src, 'Faktura ikke fundet eller allerede betalt.', 'error')
        return false
    end

    if invoice.customer_identifier and invoice.customer_identifier ~= xPlayer.identifier then
        WS.notify(src, 'Denne faktura tilhører ikke dig.', 'error')
        return false
    end

    local paid, err = removePlayerMoney(xPlayer, invoice.total)
    if not paid then
        WS.notify(src, err, 'error')
        return false
    end

    local newBalance = (invoice.company_balance or 0) + invoice.total
    MySQL.update.await('UPDATE ya_workshop_companies SET balance = ? WHERE id = ?', { newBalance, invoice.company_id })
    MySQL.update.await(
        "UPDATE ya_workshop_invoices SET status = 'paid', paid_at = NOW(), customer_identifier = COALESCE(customer_identifier, ?) WHERE id = ?",
        { xPlayer.identifier, invoice.id }
    )

    WS.notify(src, ('Faktura %s betalt (%s DKK).'):format(invoice.invoice_number, invoice.total), 'success')

    if invoice.order_id then
        local orderStatus = MySQL.scalar.await(
            'SELECT status FROM ya_workshop_orders WHERE id = ? LIMIT 1',
            { invoice.order_id }
        )
        if orderStatus and orderStatus ~= 'completed' then
            WS.notify(src, 'Betaling modtaget — mekanikeren skal stadig booste bilen for at færdiggøre tuning.', 'inform')
        end
    end

    notifyCompanyTabletRefresh(invoice.company_id, { 'bestillinger', 'faktura', 'faerdige_ordre', 'oversigt' })
    notifyCompanyBoostRefresh(invoice.company_id)
    return true
end

local function formatOrderDetail(orderId, companyId)
    local order = MySQL.single.await([[
        SELECT o.*, DATE_FORMAT(o.created_at, '%d/%m %Y %H:%i') AS created_at_label
        FROM ya_workshop_orders o
        WHERE o.id = ? AND o.company_id = ?
        LIMIT 1
    ]], { orderId, companyId })
    if not order then return nil end

    local items = MySQL.query.await(
        'SELECT category_key AS categoryKey, group_key AS groupKey, item_key AS itemKey, line_type AS lineType, label, description, price FROM ya_workshop_order_items WHERE order_id = ? ORDER BY id ASC',
        { orderId }
    ) or {}

    local invoice = getInvoiceForOrder(orderId)
    local shopDef = order.shop_key and WS.getShopDefinition(order.shop_key)

    return {
        id = order.id,
        orderNumber = order.order_number,
        status = order.status,
        statusLabel = Config.OrderStatuses[order.status] or order.status,
        customerName = order.customer_name,
        customerIdentifier = order.customer_identifier,
        vehiclePlate = order.vehicle_plate,
        vehicleLabel = order.vehicle_label,
        totalPrice = order.total_price,
        notes = order.notes,
        assignedName = order.assigned_name,
        createdAt = order.created_at_label,
        shopKey = order.shop_key,
        shopLabel = shopDef and shopDef.label or order.shop_key,
        items = items,
        hasInvoice = invoice ~= nil,
        invoiceId = invoice and invoice.id,
        invoiceNumber = invoice and invoice.invoice_number,
        invoiceStatus = invoice and invoice.status,
    }
end

function WS.pushAppData(src, tab, row)
    local companyId = row.company_id
    tab = type(tab) == 'string' and tab or 'oversigt'

    local payload = {
        tab = tab,
        company = {
            id = companyId,
            name = row.company_name,
            type = row.company_type,
            color = row.company_color,
            locked = row.company_locked == 1,
            balance = row.company_balance or 0,
            shopKeys = WS.getCompanyShopKeys(companyId),
            shopLabels = (function()
                local keys = WS.getCompanyShopKeys(companyId)
                local labels = {}
                for i = 1, #keys do
                    local def = WS.getShopDefinition(keys[i])
                    labels[#labels + 1] = def and def.label or keys[i]
                end
                return labels
            end)(),
        },
        member = {
            name = row.character_name or WS.getCharacterName(ESX.GetPlayerFromId(src)),
            roleName = row.role_name,
        },
        permissions = {
            orders = WS.roleCan(row, 'manage_orders'),
            members = WS.roleCan(row, 'manage_members'),
            roles = WS.roleCan(row, 'manage_roles'),
            prices = WS.roleCan(row, 'manage_prices'),
            invoices = WS.roleCan(row, 'send_invoices'),
            calls = WS.roleCan(row, 'view_calls'),
            acceptCalls = WS.roleCan(row, 'accept_calls'),
        },
        permissionsCatalog = Config.PermissionsCatalog,
    }

    if tab == 'oversigt' then
        payload.stats = {
            pendingOrders = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_workshop_orders WHERE company_id = ? AND status = 'pending'",
                { companyId }
            ) or 0,
            activeOrders = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_workshop_orders WHERE company_id = ? AND status = 'in_progress'",
                { companyId }
            ) or 0,
            openCalls = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_workshop_calls WHERE company_id = ? AND status = 'open'",
                { companyId }
            ) or 0,
            unpaidInvoices = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_workshop_invoices WHERE company_id = ? AND status = 'unpaid'",
                { companyId }
            ) or 0,
            finishedOrders = MySQL.scalar.await([[
                SELECT COUNT(*)
                FROM ya_workshop_orders o
                INNER JOIN ya_workshop_invoices i ON i.order_id = o.id AND i.status = 'paid'
                WHERE o.company_id = ? AND o.status = 'completed'
            ]], { companyId }) or 0,
        }
    elseif tab == 'bestillinger' then
        local rows = MySQL.query.await([[
            SELECT o.id, o.order_number, o.status, o.customer_name, o.vehicle_plate, o.vehicle_label,
                   o.total_price, o.assigned_name, o.shop_key,
                   DATE_FORMAT(o.created_at, '%d/%m %Y %H:%i') AS created_at_label,
                   i.id AS invoice_id, i.invoice_number, i.status AS invoice_status
            FROM ya_workshop_orders o
            LEFT JOIN ya_workshop_invoices i ON i.order_id = o.id
            WHERE o.company_id = ?
              AND NOT (o.status = 'completed' AND i.status = 'paid')
            ORDER BY FIELD(o.status, 'pending', 'in_progress', 'completed', 'cancelled'), o.id DESC
            LIMIT 60
        ]], { companyId }) or {}
        payload.orders = {}
        for i = 1, #rows do
            payload.orders[#payload.orders + 1] = formatOrderRow(rows[i])
        end
    elseif tab == 'faerdige_ordre' then
        local rows = MySQL.query.await([[
            SELECT o.id, o.order_number, o.status, o.customer_name, o.vehicle_plate, o.vehicle_label,
                   o.total_price, o.assigned_name, o.shop_key,
                   DATE_FORMAT(o.created_at, '%d/%m %Y %H:%i') AS created_at_label,
                   DATE_FORMAT(o.completed_at, '%d/%m %Y %H:%i') AS completed_at_label,
                   i.id AS invoice_id, i.invoice_number, i.status AS invoice_status, i.total AS invoice_total,
                   DATE_FORMAT(i.paid_at, '%d/%m %Y %H:%i') AS paid_at_label
            FROM ya_workshop_orders o
            INNER JOIN ya_workshop_invoices i ON i.order_id = o.id AND i.status = 'paid'
            WHERE o.company_id = ? AND o.status = 'completed'
            ORDER BY i.paid_at DESC, o.id DESC
            LIMIT 60
        ]], { companyId }) or {}
        payload.finishedOrders = {}
        for i = 1, #rows do
            payload.finishedOrders[#payload.finishedOrders + 1] = formatOrderRow(rows[i])
        end
        payload.finishedCount = #payload.finishedOrders
    elseif tab == 'opkald' then
        local rows = MySQL.query.await([[
            SELECT id, caller_name AS callerName, message, coords_x AS x, coords_y AS y, coords_z AS z,
                   status, accepted_name AS acceptedName,
                   DATE_FORMAT(created_at, '%d/%m %Y %H:%i') AS createdAt
            FROM ya_workshop_calls
            WHERE company_id = ? AND status <> 'closed'
            ORDER BY FIELD(status, 'open', 'accepted'), id DESC
            LIMIT 40
        ]], { companyId }) or {}
        for i = 1, #rows do
            rows[i].statusLabel = Config.CallStatuses[rows[i].status] or rows[i].status
        end
        payload.calls = rows
    elseif tab == 'faktura' then
        payload.invoiceStats = {
            unpaidTotal = MySQL.scalar.await(
                "SELECT COALESCE(SUM(total), 0) FROM ya_workshop_invoices WHERE company_id = ? AND status = 'unpaid'",
                { companyId }
            ) or 0,
            unpaidCount = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_workshop_invoices WHERE company_id = ? AND status = 'unpaid'",
                { companyId }
            ) or 0,
            paidCount = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_workshop_invoices WHERE company_id = ? AND status = 'paid'",
                { companyId }
            ) or 0,
        }
        payload.invoices = MySQL.query.await([[
            SELECT id, invoice_number AS invoiceNumber, status, customer_name AS customerName,
                   description, subtotal, vat_amount AS vatAmount, total, order_id AS orderId,
                   DATE_FORMAT(created_at, '%d. %b %Y') AS createdAtLabel,
                   DATE_FORMAT(paid_at, '%d. %b %Y') AS paidAtLabel
            FROM ya_workshop_invoices
            WHERE company_id = ?
            ORDER BY id DESC
            LIMIT 50
        ]], { companyId }) or {}
        payload.ordersWithoutInvoice = MySQL.query.await([[
            SELECT o.id, o.order_number AS orderNumber, o.customer_name AS customerName,
                   o.vehicle_plate AS vehiclePlate, o.vehicle_label AS vehicleLabel, o.total_price AS totalPrice,
                   DATE_FORMAT(o.created_at, '%d/%m %Y %H:%i') AS createdAt
            FROM ya_workshop_orders o
            LEFT JOIN ya_workshop_invoices i ON i.order_id = o.id
            WHERE o.company_id = ? AND i.id IS NULL AND o.status IN ('in_progress', 'completed')
            ORDER BY o.id DESC
            LIMIT 25
        ]], { companyId }) or {}
    elseif tab == 'prisliste' then
        payload.priceList = WS.buildPriceList(companyId)
    elseif tab == 'ansatte' then
        payload.roles = MySQL.query.await(
            'SELECT id, role_key AS roleKey, name, permissions, is_default AS isDefault, sort_order AS sortOrder FROM ya_workshop_roles WHERE company_id = ? ORDER BY sort_order ASC',
            { companyId }
        ) or {}
        for i = 1, #payload.roles do
            payload.roles[i].permissions = WS.decodePermissions(payload.roles[i].permissions)
            payload.roles[i].isTopRank = payload.roles[i].roleKey == 'owner'
        end
        payload.members = MySQL.query.await([[
            SELECT m.id, m.identifier, m.character_name AS name, m.role_id AS roleId, r.name AS roleName
            FROM ya_workshop_members m
            JOIN ya_workshop_roles r ON r.id = m.role_id
            WHERE m.company_id = ?
            ORDER BY m.joined_at ASC
        ]], { companyId }) or {}
    end

    TriggerClientEvent('ya_tablet:workshopAppData', src, payload)
end

RegisterNetEvent('ya_workshop:getAppData', function(tab)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then
        TriggerClientEvent('ya_tablet:workshopAppData', src, { error = err })
        return
    end
    WS.pushAppData(src, tab, row)
end)

RegisterNetEvent('ya_workshop:getOrderDetail', function(orderId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then
        TriggerClientEvent('ya_tablet:workshopOrderDetail', src, { error = err })
        return
    end
    orderId = tonumber(orderId)
    local detail = orderId and formatOrderDetail(orderId, row.company_id) or nil
    if not detail then
        TriggerClientEvent('ya_tablet:workshopOrderDetail', src, { error = 'Bestilling ikke fundet.' })
        return
    end
    TriggerClientEvent('ya_tablet:workshopOrderDetail', src, {
        order = detail,
        canManageOrders = WS.roleCan(row, 'manage_orders'),
        canSendInvoices = WS.roleCan(row, 'send_invoices'),
    })
end)

RegisterNetEvent('ya_workshop:updateOrderStatus', function(orderId, status)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_orders') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    orderId = tonumber(orderId)
    status = type(status) == 'string' and status or ''
    if not orderId or not Config.OrderStatuses[status] then return end

    if status == 'completed' then
        WS.notify(src, 'Brug Boost bil ved køretøjet for at gemme tuning.', 'error')
        return
    end

    local previousStatus = MySQL.scalar.await(
        'SELECT status FROM ya_workshop_orders WHERE id = ? AND company_id = ?',
        { orderId, row.company_id }
    )
    if not previousStatus then
        WS.notify(src, 'Bestilling ikke fundet.', 'error')
        return
    end

    if previousStatus == 'completed' then
        WS.notify(src, 'Færdige bestillinger kan ikke ændres.', 'error')
        return
    end

    if previousStatus == 'cancelled' then
        WS.notify(src, 'Annullerede bestillinger kan ikke genåbnes.', 'error')
        return
    end

    local identifier = WS.getIdentifier(src)
    local name = WS.getCharacterName(ESX.GetPlayerFromId(src))
    local updates = { 'status = ?' }
    local params = { status }

    if status == 'in_progress' then
        updates[#updates + 1] = 'assigned_to = ?'
        updates[#updates + 1] = 'assigned_name = ?'
        params[#params + 1] = identifier
        params[#params + 1] = name
    elseif status == 'pending' or status == 'cancelled' then
        updates[#updates + 1] = 'assigned_to = NULL'
        updates[#updates + 1] = 'assigned_name = NULL'
        if status == 'pending' then
            updates[#updates + 1] = 'completed_at = NULL'
        end
    end

    params[#params + 1] = orderId
    params[#params + 1] = row.company_id

    local ok, err = pcall(function()
        MySQL.update.await(
            'UPDATE ya_workshop_orders SET ' .. table.concat(updates, ', ') .. ' WHERE id = ? AND company_id = ?',
            params
        )
    end)
    if not ok then
        print(('[ya_workshop] updateOrderStatus failed: %s'):format(tostring(err)))
        WS.notify(src, 'Kunne ikke opdatere bestilling.', 'error')
        return
    end

    if previousStatus == 'in_progress' or status == 'in_progress' then
        notifyCompanyBoostRefresh(row.company_id, src)
    end

    WS.notify(src, ('Bestilling sat til: %s'):format(Config.OrderStatuses[status]), 'success')
    WS.pushAppData(src, 'bestillinger', row)
end)

RegisterNetEvent('ya_workshop:deleteOrder', function(orderId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_orders') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    orderId = tonumber(orderId)
    if not orderId then return end

    local order = MySQL.single.await(
        'SELECT id, status, customer_identifier FROM ya_workshop_orders WHERE id = ? AND company_id = ?',
        { orderId, row.company_id }
    )
    if not order then
        WS.notify(src, 'Bestilling ikke fundet.', 'error')
        return
    end

    local invoices = MySQL.query.await(
        'SELECT id, invoice_number, status, customer_identifier FROM ya_workshop_invoices WHERE order_id = ?',
        { orderId }
    ) or {}

    for i = 1, #invoices do
        if invoices[i].status == 'paid' then
            WS.notify(src, 'Kan ikke slette: fakturaen er allerede betalt.', 'error')
            return
        end
    end

    for i = 1, #invoices do
        MySQL.update.await('DELETE FROM ya_workshop_invoices WHERE id = ? AND company_id = ?', { invoices[i].id, row.company_id })
        local customerId = invoices[i].customer_identifier or order.customer_identifier
        if customerId then
            local xCustomer = ESX.GetPlayerFromIdentifier(customerId)
            if xCustomer and xCustomer.source then
                WS.notify(
                    xCustomer.source,
                    ('Faktura %s er annulleret — bestillingen er slettet.'):format(invoices[i].invoice_number),
                    'inform'
                )
            end
        end
    end

    MySQL.update.await('DELETE FROM ya_workshop_order_items WHERE order_id = ?', { orderId })
    MySQL.update.await('DELETE FROM ya_workshop_orders WHERE id = ? AND company_id = ?', { orderId, row.company_id })

    if order.status == 'in_progress' then
        notifyCompanyBoostRefresh(row.company_id, src)
    end

    WS.notify(src, (#invoices > 0 and 'Bestilling og tilhørende faktura(er) slettet.' or 'Bestilling slettet.'), 'success')
    WS.pushAppData(src, 'bestillinger', row)
    if #invoices > 0 then
        WS.pushAppData(src, 'faktura', row)
    end
end)

RegisterNetEvent('ya_workshop:sendOrderInvoice', function(orderId, refreshTab)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'send_invoices') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    orderId = tonumber(orderId)
    if not orderId then return end

    local order = MySQL.single.await(
        'SELECT * FROM ya_workshop_orders WHERE id = ? AND company_id = ? LIMIT 1',
        { orderId, row.company_id }
    )
    if not order then WS.notify(src, 'Bestilling ikke fundet.', 'error'); return end

    if order.status == 'pending' then
        WS.notify(src, 'Start arbejde først — send faktura når tuning er i gang eller færdig.', 'error')
        return
    end

    if order.status == 'cancelled' then
        WS.notify(src, 'Annullerede bestillinger kan ikke faktureres.', 'error')
        return
    end

    if getInvoiceForOrder(orderId) then
        WS.notify(src, 'Faktura findes allerede for denne bestilling.', 'error')
        return
    end

    local identifier = WS.getIdentifier(src)
    local name = WS.getCharacterName(ESX.GetPlayerFromId(src))
    local description = ('Værksted: %s (%s)'):format(order.vehicle_label or 'Køretøj', order.vehicle_plate or '')
    local _, invoiceNumber, total = createWorkshopInvoice(
        row.company_id,
        orderId,
        order.customer_identifier,
        order.customer_name,
        description,
        order.total_price,
        identifier,
        name
    )

    if not invoiceNumber then
        WS.notify(src, 'Kunne ikke oprette faktura.', 'error')
        return
    end

    notifyInvoiceCustomer(order.customer_identifier, invoiceNumber, total, row.company_name)
    WS.notify(src, ('Faktura %s sendt til %s (%s DKK).'):format(invoiceNumber, order.customer_name or 'kunden', total), 'success')
    WS.pushAppData(src, type(refreshTab) == 'string' and refreshTab or 'faktura', row)
end)

RegisterNetEvent('ya_workshop:sendManualInvoice', function(data)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'send_invoices') then WS.notify(src, 'Ingen adgang.', 'error'); return end
    if type(data) ~= 'table' then return end

    local orderId = tonumber(data.orderId)
    local customerIdentifier = type(data.customerIdentifier) == 'string' and data.customerIdentifier or nil
    local customerName = type(data.customerName) == 'string' and data.customerName:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local description = type(data.description) == 'string' and data.description:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local amount = math.floor(tonumber(data.amount) or 0)

    if orderId then
        local order = MySQL.single.await(
            'SELECT * FROM ya_workshop_orders WHERE id = ? AND company_id = ? LIMIT 1',
            { orderId, row.company_id }
        )
        if not order then WS.notify(src, 'Bestilling ikke fundet.', 'error'); return end
        if getInvoiceForOrder(orderId) then WS.notify(src, 'Faktura findes allerede for denne bestilling.', 'error'); return end

        customerIdentifier = order.customer_identifier
        customerName = order.customer_name
        amount = order.total_price
        if description == '' then
            description = ('Værksted: %s (%s)'):format(order.vehicle_label or 'Køretøj', order.vehicle_plate or '')
        end
    else
        if customerName == '' then WS.notify(src, 'Angiv kundens navn.', 'error'); return end
        if description == '' then description = 'Værkstedsydelse' end
    end

    local identifier = WS.getIdentifier(src)
    local name = WS.getCharacterName(ESX.GetPlayerFromId(src))
    local _, invoiceNumber, total = createWorkshopInvoice(
        row.company_id,
        orderId,
        customerIdentifier,
        customerName,
        description,
        amount,
        identifier,
        name
    )

    if not invoiceNumber then
        WS.notify(src, 'Kunne ikke oprette faktura — tjek beløb.', 'error')
        return
    end

    notifyInvoiceCustomer(customerIdentifier, invoiceNumber, total, row.company_name)
    WS.notify(src, ('Faktura %s sendt til %s (%s DKK).'):format(invoiceNumber, customerName, total), 'success')
    WS.pushAppData(src, 'faktura', row)
end)

RegisterNetEvent('ya_workshop:searchInvoiceCustomers', function(query)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then return end
    if not WS.roleCan(row, 'send_invoices') then return end

    query = type(query) == 'string' and query:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local needle = string.lower(query)
    local seen = {}
    local customers = {}

    local function pushCustomer(identifier, name, serverId, sourceLabel)
        if not name or name == '' or seen[identifier or name] then return end
        seen[identifier or name] = true
        customers[#customers + 1] = {
            identifier = identifier,
            name = name,
            serverId = serverId,
            online = serverId ~= nil,
            sourceLabel = sourceLabel,
        }
    end

    if needle ~= '' then
        local players = ESX.GetExtendedPlayers()
        for i = 1, #players do
            local xPlayer = players[i]
            local charName = WS.getCharacterName(xPlayer)
            if string.find(string.lower(charName), needle, 1, true) then
                pushCustomer(xPlayer.identifier, charName, xPlayer.source, 'Online')
            end
        end

        local rows = MySQL.query.await([[
            SELECT DISTINCT customer_identifier AS identifier, customer_name AS name
            FROM ya_workshop_orders
            WHERE company_id = ? AND customer_name LIKE ?
            ORDER BY customer_name ASC
            LIMIT 12
        ]], { row.company_id, '%' .. query .. '%' }) or {}

        for i = 1, #rows do
            pushCustomer(rows[i].identifier, rows[i].name, nil, 'Tidligere kunde')
        end
    end

    TriggerClientEvent('ya_tablet:workshopInvoiceSearch', src, { customers = customers, query = query })
end)

RegisterNetEvent('ya_workshop:getInvoiceDetail', function(invoiceId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then
        TriggerClientEvent('ya_tablet:workshopInvoiceDetail', src, { error = err })
        return
    end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    local invoice = MySQL.single.await([[
        SELECT i.*, c.name AS company_name,
               DATE_FORMAT(i.created_at, '%d. %b %Y') AS created_at_label,
               DATE_FORMAT(i.paid_at, '%d. %b %Y') AS paid_at_label
        FROM ya_workshop_invoices i
        JOIN ya_workshop_companies c ON c.id = i.company_id
        WHERE i.id = ? AND i.company_id = ?
        LIMIT 1
    ]], { invoiceId, row.company_id })

    if not invoice then
        TriggerClientEvent('ya_tablet:workshopInvoiceDetail', src, { error = 'Faktura ikke fundet.' })
        return
    end

    local items = {}
    if invoice.order_id then
        items = MySQL.query.await([[
            SELECT label, description, price, line_type AS lineType
            FROM ya_workshop_order_items
            WHERE order_id = ?
            ORDER BY id ASC
        ]], { invoice.order_id }) or {}
    end

    TriggerClientEvent('ya_tablet:workshopInvoiceDetail', src, {
        invoice = {
            id = invoice.id,
            invoiceNumber = invoice.invoice_number,
            status = invoice.status,
            customerName = invoice.customer_name,
            description = invoice.description,
            subtotal = invoice.subtotal,
            vatAmount = invoice.vat_amount,
            total = invoice.total,
            orderId = invoice.order_id,
            companyName = invoice.company_name,
            companyCvr = Config.CompanyCvr or '12345678',
            vatRate = math.floor((tonumber(Config.VatRate) or 0.25) * 100),
            currency = Config.Currency or 'DKK',
            createdByName = invoice.created_by_name,
            createdAtLabel = invoice.created_at_label,
            paidAtLabel = invoice.paid_at_label,
            items = items,
        },
    })
end)

RegisterNetEvent('ya_workshop:payInvoice', function(invoiceRef)
    payWorkshopInvoiceForPlayer(source, invoiceRef)
end)

RegisterCommand('betalfaktura', function(source, args)
    if source == 0 then return end
    local ref = args[1]
    if not ref then
        WS.notify(source, 'Brug: /betalfaktura [fakturanummer]', 'error')
        return
    end
    payWorkshopInvoiceForPlayer(source, ref)
end, false)

RegisterNetEvent('ya_workshop:acceptCall', function(callId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'accept_calls') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    callId = tonumber(callId)
    if not callId then return end

    local identifier = WS.getIdentifier(src)
    local name = WS.getCharacterName(ESX.GetPlayerFromId(src))

    MySQL.update.await([[
        UPDATE ya_workshop_calls
        SET status = 'accepted', accepted_by = ?, accepted_name = ?
        WHERE id = ? AND company_id = ? AND status = 'open'
    ]], { identifier, name, callId, row.company_id })

    WS.notify(src, 'Opkald taget.', 'success')
    WS.pushAppData(src, 'opkald', row)
end)

RegisterNetEvent('ya_workshop:closeCall', function(callId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'view_calls') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    callId = tonumber(callId)
    if not callId then return end

    MySQL.update.await([[
        UPDATE ya_workshop_calls SET status = 'closed', closed_at = NOW()
        WHERE id = ? AND company_id = ?
    ]], { callId, row.company_id })

    WS.notify(src, 'Opkald lukket.', 'success')
    WS.pushAppData(src, 'opkald', row)
end)

-- Medarbejder-side: roller og medlemmer (som bande/cardealer)
RegisterNetEvent('ya_workshop:employeeInvite', function(targetId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_members') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    local ok, addErr = WS.addMemberToCompany(row.company_id, targetId)
    if ok then
        WS.notify(src, 'Medarbejder tilføjet.', 'success')
        WS.pushAppData(src, 'ansatte', row)
    else
        WS.notify(src, addErr or 'Kunne ikke tilføje medarbejder.', 'error')
    end
end)

RegisterNetEvent('ya_workshop:employeeSetMemberRole', function(memberId, roleId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_members') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    if WS.setMemberRole(row.company_id, memberId, roleId) then
        WS.notify(src, 'Rolle opdateret.', 'success')
        WS.pushAppData(src, 'ansatte', row)
    end
end)

RegisterNetEvent('ya_workshop:employeeKickMember', function(memberId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_members') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    memberId = tonumber(memberId)
    if not memberId then return end

    local member = MySQL.single.await(
        'SELECT identifier, role_id FROM ya_workshop_members WHERE id = ? AND company_id = ? LIMIT 1',
        { memberId, row.company_id }
    )
    if not member then return end

    local ownerRole = MySQL.single.await(
        'SELECT id FROM ya_workshop_roles WHERE company_id = ? AND role_key = ? LIMIT 1',
        { row.company_id, 'owner' }
    )
    if ownerRole and member.role_id == ownerRole.id then
        WS.notify(src, 'Kan ikke fjerne ejeren.', 'error')
        return
    end

    MySQL.update.await('DELETE FROM ya_workshop_members WHERE id = ? AND company_id = ?', { memberId, row.company_id })
    WS.uninstallWorkshopApp(member.identifier)
    WS.notify(src, 'Medarbejder fjernet.', 'success')
    WS.pushAppData(src, 'ansatte', row)
end)

local function upsertRoleForCompany(companyId, roleId, name, permissions)
    companyId, roleId = tonumber(companyId), tonumber(roleId)
    if not companyId then return false, 'Ugyldigt firma.' end

    name = type(name) == 'string' and name:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if name == '' then return false, 'Rollenavn påkrævet.' end

    permissions = type(permissions) == 'table' and permissions or {}

    if roleId then
        local role = MySQL.single.await(
            'SELECT role_key FROM ya_workshop_roles WHERE id = ? AND company_id = ? LIMIT 1',
            { roleId, companyId }
        )
        if not role or role.role_key == 'owner' then
            return false, 'Kan ikke redigere ejer-rollen.'
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
    return true
end

local function deleteRoleForCompany(companyId, roleId)
    companyId, roleId = tonumber(companyId), tonumber(roleId)
    if not companyId or not roleId then return false, 'Ugyldige data.' end

    local role = MySQL.single.await(
        'SELECT role_key FROM ya_workshop_roles WHERE id = ? AND company_id = ? LIMIT 1',
        { roleId, companyId }
    )
    if not role or role.role_key == 'owner' then
        return false, 'Kan ikke slette denne rolle.'
    end

    local defaultRole = MySQL.single.await(
        'SELECT id FROM ya_workshop_roles WHERE company_id = ? AND is_default = 1 ORDER BY sort_order ASC LIMIT 1',
        { companyId }
    )
    if not defaultRole then return false, 'Ingen standardrolle.' end

    MySQL.update.await('UPDATE ya_workshop_members SET role_id = ? WHERE role_id = ? AND company_id = ?', {
        defaultRole.id, roleId, companyId,
    })
    MySQL.update.await('DELETE FROM ya_workshop_roles WHERE id = ? AND company_id = ?', { roleId, companyId })
    return true
end

RegisterNetEvent('ya_workshop:employeeUpsertRole', function(roleId, name, permissions)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_roles') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    local ok, roleErr = upsertRoleForCompany(row.company_id, roleId, name, permissions)
    if ok then
        WS.notify(src, 'Rolle gemt.', 'success')
        WS.pushAppData(src, 'ansatte', row)
    else
        WS.notify(src, roleErr or 'Kunne ikke gemme rolle.', 'error')
    end
end)

RegisterNetEvent('ya_workshop:employeeDeleteRole', function(roleId)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_roles') then WS.notify(src, 'Ingen adgang.', 'error'); return end

    local ok, roleErr = deleteRoleForCompany(row.company_id, roleId)
    if ok then
        WS.notify(src, 'Rolle slettet.', 'success')
        WS.pushAppData(src, 'ansatte', row)
    else
        WS.notify(src, roleErr or 'Kunne ikke slette rolle.', 'error')
    end
end)

RegisterNetEvent('ya_workshop:savePrice', function(categoryKey, groupKey, itemKey, price)
    local src = source
    local row, err = WS.requireMember(src)
    if not row then WS.notify(src, err, 'error'); return end
    if not WS.roleCan(row, 'manage_prices') then WS.notify(src, 'Ingen adgang til prisliste.', 'error'); return end

    local ok = WS.savePriceOverride(row.company_id, categoryKey, groupKey, itemKey, price)
    if ok then
        WS.notify(src, 'Pris opdateret.', 'success')
        WS.pushAppData(src, 'prisliste', row)
    else
        WS.notify(src, 'Ugyldig prislinje.', 'error')
    end
end)
