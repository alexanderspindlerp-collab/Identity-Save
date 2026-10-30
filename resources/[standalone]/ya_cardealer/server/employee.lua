local ESX = exports['es_extended']:getSharedObject()

local NumberCharset, LetterCharset = {}, {}
for i = 48, 57 do NumberCharset[#NumberCharset + 1] = string.char(i) end
for i = 65, 90 do LetterCharset[#LetterCharset + 1] = string.char(i) end

local function randomPart(charset, length)
    local out = {}
    for _ = 1, length do
        out[#out + 1] = charset[math.random(1, #charset)]
    end
    return table.concat(out)
end

local function generatePlate()
    local cfg = Config.Plate or {}
    local letters = tonumber(cfg.Letters) or 3
    local numbers = tonumber(cfg.Numbers) or 3
    local space = cfg.UseSpace ~= false and ' ' or ''
    for _ = 1, 40 do
        local plate = string.upper(randomPart(LetterCharset, letters) .. space .. randomPart(NumberCharset, numbers))
        local taken = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE plate = ? LIMIT 1', { plate })
        if not taken then return plate end
    end
    return ('YA%s'):format(math.random(10000, 99999))
end

local function notify(src, message, ntype)
    TriggerClientEvent('ya_tablet:notify', src, message, ntype or 'info')
end

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function getCharacterName(xPlayer)
    if not xPlayer then return 'Ukendt' end
    if xPlayer.getName then return xPlayer.getName() end
    return xPlayer.name or 'Ukendt'
end

local function decodePermissions(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return {} end
    return data
end

local function getMemberRow(identifier)
    if not identifier then return nil end
    return MySQL.single.await([[
        SELECT m.*, d.name AS dealership_name, d.locked AS dealership_locked, d.closed AS dealership_closed,
               d.balance AS dealership_balance, r.role_key, r.name AS role_name, r.permissions
        FROM ya_cardealer_members m
        JOIN ya_cardealer_dealerships d ON d.id = m.dealership_id
        JOIN ya_cardealer_roles r ON r.id = m.role_id
        WHERE m.identifier = ? AND d.closed = 0
        LIMIT 1
    ]], { identifier })
end

local function requireMember(src)
    local identifier = getIdentifier(src)
    if not identifier then return nil, 'Ikke logget ind.' end
    local row = getMemberRow(identifier)
    if not row then return nil, 'Du er ikke ansat i en bilforhandler.' end
    if row.dealership_locked == 1 then return nil, 'Forhandleren er låst (UDE AF DRIFT).' end
    return row, nil
end

local function roleCan(row, permission)
    if not row then return false end
    if row.role_key == 'owner' then return true end
    local perms = decodePermissions(row.permissions)
    return perms[permission] == true
end

local function vehicleImageUrl(row)
    if row.image_url and row.image_url ~= '' then return row.image_url end
    local base = Config.VehicleImageBase or 'https://docs.fivem.net/vehicles'
    return ('%s/%s.webp'):format(base, row.model)
end

local function calcVat(total)
    total = math.floor(tonumber(total) or 0)
    local rate = tonumber(Config.VatRate) or 0.25
    local subtotal = math.floor(total / (1 + rate) + 0.5)
    local vat = total - subtotal
    return subtotal, vat, total
end

local function nextInvoiceNumber()
    return ('F%s-%s'):format(os.date('%Y%m'), math.random(1000000, 9999999))
end

local function nextTransactionNumber()
    return tostring(math.random(1000000, 9999999))
end

local function getDealershipSpawn(dealershipId)
    local row = MySQL.single.await(
        'SELECT spawn_x, spawn_y, spawn_z, spawn_heading FROM ya_cardealer_dealerships WHERE id = ? LIMIT 1',
        { dealershipId }
    )
    if not row or not row.spawn_x or not row.spawn_y or not row.spawn_z then return nil end
    return {
        x = row.spawn_x,
        y = row.spawn_y,
        z = row.spawn_z,
        h = row.spawn_heading or 0.0,
    }
end

local function spawnSoldVehicleForPlayer(targetSrc, model, plate, spawn)
    if not spawn or not targetSrc then return end
    TriggerClientEvent('ya_cardealer:spawnSoldVehicle', targetSrc, model, plate, spawn.x, spawn.y, spawn.z, spawn.h)
end

local function registerOwnedVehicle(identifier, model, plate)
    if not identifier then return end
    local modelHash = joaat(model)
    local vehicleProps = json.encode({ model = modelHash, plate = plate })
    MySQL.insert.await(
        'INSERT INTO owned_vehicles (owner, plate, vehicle, type, stored) VALUES (?, ?, ?, ?, ?)',
        { identifier, plate, vehicleProps, 'car', 0 }
    )
end

local function formatCatalogRow(row, dealershipId)
    local stockCount = MySQL.scalar.await(
        "SELECT COUNT(*) FROM ya_cardealer_stock WHERE dealership_id = ? AND catalog_id = ? AND status = 'in_stock'",
        { dealershipId, row.catalog_id }
    ) or 0
    return {
        assignmentId = row.assignment_id,
        catalogId = row.catalog_id,
        model = row.model,
        label = row.label,
        manufacturer = row.manufacturer,
        year = row.year,
        importPrice = row.import_price,
        listPrice = row.list_price,
        maxStock = row.max_stock,
        supplierStock = row.supplier_stock,
        inStock = stockCount,
        available = stockCount < row.max_stock and row.supplier_stock > 0,
        image = vehicleImageUrl(row),
    }
end

local function pushAppData(src, tab, row)
    local dealershipId = row.dealership_id
    tab = type(tab) == 'string' and tab or 'oversigt'

    local payload = {
        tab = tab,
        dealership = {
            id = dealershipId,
            name = row.dealership_name,
            locked = row.dealership_locked == 1,
            balance = row.dealership_balance or 0,
        },
        member = {
            name = row.character_name or getCharacterName(ESX.GetPlayerFromId(src)),
            roleName = row.role_name,
        },
        permissions = {
            import = roleCan(row, 'manage_stock'),
            sell = roleCan(row, 'sell_vehicles'),
        },
    }

    if tab == 'oversigt' then
        payload.stats = {
            stockCount = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_cardealer_stock WHERE dealership_id = ? AND status = 'in_stock'",
                { dealershipId }
            ) or 0,
            unpaidCount = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_cardealer_sales_invoices WHERE dealership_id = ? AND status = 'unpaid'",
                { dealershipId }
            ) or 0,
        }
    elseif tab == 'importere' then
        local rows = MySQL.query.await([[
            SELECT dc.id AS assignment_id, c.id AS catalog_id, c.model, c.label, c.manufacturer, c.year,
                   c.supplier_stock, dc.import_price, dc.list_price, dc.max_stock, c.image_url
            FROM ya_cardealer_dealership_catalog dc
            JOIN ya_cardealer_catalog c ON c.id = dc.catalog_id AND c.active = 1
            WHERE dc.dealership_id = ? AND dc.enabled = 1
            ORDER BY c.label ASC
        ]], { dealershipId }) or {}
        payload.imports = {}
        for i = 1, #rows do
            payload.imports[#payload.imports + 1] = formatCatalogRow(rows[i], dealershipId)
        end
    elseif tab == 'lager' then
        payload.stock = MySQL.query.await([[
            SELECT s.id, s.plate, s.import_price AS importPrice, s.list_price AS listPrice,
                   c.label, c.model, c.manufacturer, c.year, c.image_url,
                   DATE_FORMAT(s.created_at, '%d/%m %Y') AS importedAt
            FROM ya_cardealer_stock s
            JOIN ya_cardealer_catalog c ON c.id = s.catalog_id
            WHERE s.dealership_id = ? AND s.status = 'in_stock'
            ORDER BY s.id DESC
        ]], { dealershipId }) or {}
        for i = 1, #payload.stock do
            local item = payload.stock[i]
            item.image = item.image_url and item.image_url ~= '' and item.image_url
                or ('%s/%s.webp'):format(Config.VehicleImageBase or 'https://docs.fivem.net/vehicles', item.model)
            item.image_url = nil
        end
    elseif tab == 'faktura' then
        payload.stats = {
            unpaidCount = MySQL.scalar.await(
                "SELECT COUNT(*) FROM ya_cardealer_sales_invoices WHERE dealership_id = ? AND status = 'unpaid'",
                { dealershipId }
            ) or 0,
        }
        payload.ledger = MySQL.query.await([[
            SELECT id, invoice_type AS type, amount, balance_after AS balanceAfter, description,
                   created_by_name AS createdBy, DATE_FORMAT(created_at, '%d/%m %Y %H:%i') AS createdAt
            FROM ya_cardealer_invoices
            WHERE dealership_id = ?
            ORDER BY id DESC
            LIMIT 30
        ]], { dealershipId }) or {}
        payload.salesInvoices = MySQL.query.await([[
            SELECT id, invoice_number AS invoiceNumber, transaction_number AS transactionNumber,
                   payment_method AS paymentMethod, status, buyer_name AS buyerName,
                   buyer_dob AS buyerDob, buyer_phone AS buyerPhone,
                   vehicle_label AS vehicleLabel, plate, subtotal, vat_amount AS vatAmount, total,
                   sold_by_name AS soldByName,
                   DATE_FORMAT(created_at, '%d. %b %Y') AS createdAtLabel,
                   DATE_FORMAT(paid_at, '%d. %b %Y') AS paidAtLabel
            FROM ya_cardealer_sales_invoices
            WHERE dealership_id = ?
            ORDER BY id DESC
            LIMIT 50
        ]], { dealershipId }) or {}
    end

    TriggerClientEvent('ya_tablet:cardealerAppData', src, payload)
end

local function addInvoice(dealershipId, invoiceType, amount, balanceAfter, description, identifier, name, stockId, catalogId)
    MySQL.insert.await([[
        INSERT INTO ya_cardealer_invoices
        (dealership_id, invoice_type, stock_id, catalog_id, amount, balance_after, description, created_by, created_by_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        dealershipId, invoiceType, stockId, catalogId, amount, balanceAfter, description, identifier, name,
    })
end

RegisterNetEvent('ya_cardealer:getAppData', function(tab)
    local src = source
    local row, err = requireMember(src)
    if not row then
        TriggerClientEvent('ya_tablet:cardealerAppData', src, { error = err })
        return
    end
    pushAppData(src, tab, row)
end)

RegisterNetEvent('ya_cardealer:getDashboard', function()
    local src = source
    local row, err = requireMember(src)
    if not row then
        TriggerClientEvent('ya_tablet:cardealerAppData', src, { error = err })
        return
    end
    pushAppData(src, 'oversigt', row)
end)

RegisterNetEvent('ya_cardealer:importVehicle', function(assignmentId)
    local src = source
    local row, err = requireMember(src)
    if not row then notify(src, err, 'error'); return end
    if not roleCan(row, 'manage_stock') then notify(src, 'Du har ikke adgang til import.', 'error'); return end

    assignmentId = tonumber(assignmentId)
    if not assignmentId then return end

    local assignment = MySQL.single.await([[
        SELECT dc.*, c.label, c.model, c.supplier_stock
        FROM ya_cardealer_dealership_catalog dc
        JOIN ya_cardealer_catalog c ON c.id = dc.catalog_id AND c.active = 1
        WHERE dc.id = ? AND dc.dealership_id = ? AND dc.enabled = 1
        LIMIT 1
    ]], { assignmentId, row.dealership_id })

    if not assignment then
        notify(src, 'Køretøj ikke tilgængeligt for dit firma.', 'error')
        return
    end

    local currentStock = MySQL.scalar.await(
        "SELECT COUNT(*) FROM ya_cardealer_stock WHERE dealership_id = ? AND catalog_id = ? AND status = 'in_stock'",
        { row.dealership_id, assignment.catalog_id }
    ) or 0

    if currentStock >= assignment.max_stock then
        notify(src, 'Maks lager for dette køretøj er nået.', 'error')
        return
    end

    if assignment.supplier_stock <= 0 then
        notify(src, 'Leverandør har ikke flere på lager.', 'error')
        return
    end

    local balance = MySQL.scalar.await('SELECT balance FROM ya_cardealer_dealerships WHERE id = ? LIMIT 1', { row.dealership_id }) or 0
    if balance < assignment.import_price then
        notify(src, 'Firmaets konto har ikke råd til importen.', 'error')
        return
    end

    local plate = generatePlate()
    local newBalance = balance - assignment.import_price
    local identifier = getIdentifier(src)
    local sellerName = getCharacterName(ESX.GetPlayerFromId(src))

    MySQL.update.await('UPDATE ya_cardealer_dealerships SET balance = ? WHERE id = ?', { newBalance, row.dealership_id })
    MySQL.update.await('UPDATE ya_cardealer_catalog SET supplier_stock = supplier_stock - 1 WHERE id = ? AND supplier_stock > 0', { assignment.catalog_id })

    local stockId = MySQL.insert.await([[
        INSERT INTO ya_cardealer_stock
        (dealership_id, catalog_id, plate, import_price, list_price, status, imported_by)
        VALUES (?, ?, ?, ?, ?, 'in_stock', ?)
    ]], {
        row.dealership_id, assignment.catalog_id, plate, assignment.import_price, assignment.list_price, identifier,
    })

    addInvoice(
        row.dealership_id, 'import', -assignment.import_price, newBalance,
        ('Import: %s (%s)'):format(assignment.label, plate),
        identifier, sellerName, stockId, assignment.catalog_id
    )

    notify(src, ('%s importeret til lager (%s).'):format(assignment.label, plate), 'success')
    pushAppData(src, 'importere', row)
end)

RegisterNetEvent('ya_cardealer:sellVehicle', function(data)
    local src = source
    local row, err = requireMember(src)
    if not row then notify(src, err, 'error'); return end
    if not roleCan(row, 'sell_vehicles') then notify(src, 'Du har ikke adgang til salg.', 'error'); return end
    if type(data) ~= 'table' then return end

    local stockId = tonumber(data.stockId)
    local salePrice = math.floor(tonumber(data.salePrice) or 0)
    local paymentMethod = data.paymentMethod == 'cash' and 'cash' or 'invoice'
    local buyerName = type(data.buyerName) == 'string' and data.buyerName:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local buyerDob = type(data.buyerDob) == 'string' and data.buyerDob:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local buyerPhone = type(data.buyerPhone) == 'string' and data.buyerPhone:gsub('^%s+', ''):gsub('%s+$', '') or ''
    local buyerId = tonumber(data.buyerId)

    if not stockId or salePrice <= 0 or buyerName == '' then
        notify(src, 'Udfyld køber og salgspris.', 'error')
        return
    end

    local stock = MySQL.single.await([[
        SELECT s.*, c.label, c.model
        FROM ya_cardealer_stock s
        JOIN ya_cardealer_catalog c ON c.id = s.catalog_id
        WHERE s.id = ? AND s.dealership_id = ? AND s.status = 'in_stock'
        LIMIT 1
    ]], { stockId, row.dealership_id })

    if not stock then
        notify(src, 'Køretøj ikke fundet på lager.', 'error')
        return
    end

    if salePrice < stock.list_price then
        notify(src, ('Salgspris skal mindst være %s DKK.'):format(stock.list_price), 'error')
        return
    end

    local spawn = getDealershipSpawn(row.dealership_id)
    if not spawn then
        notify(src, 'Admin har ikke sat spawn-placering for forhandleren.', 'error')
        return
    end

    local buyerIdentifier = nil
    local xTarget = buyerId and ESX.GetPlayerFromId(buyerId) or nil
    if xTarget and xTarget.identifier then
        buyerIdentifier = xTarget.identifier
    end

    local status = 'unpaid'
    local identifier = getIdentifier(src)
    local sellerName = getCharacterName(ESX.GetPlayerFromId(src))
    local subtotal, vatAmount, total = calcVat(salePrice)
    local invoiceNumber = nextInvoiceNumber()
    local transactionNumber = nextTransactionNumber()
    local balance = MySQL.scalar.await('SELECT balance FROM ya_cardealer_dealerships WHERE id = ? LIMIT 1', { row.dealership_id }) or 0
    local newBalance = balance

    if paymentMethod == 'cash' then
        if not xTarget then
            notify(src, 'Kontant salg kræver køberens server-ID (online).', 'error')
            return
        end
        local buyerCash = xTarget.getMoney and xTarget.getMoney() or 0
        if buyerCash < salePrice then
            notify(src, 'Køberen har ikke nok kontanter.', 'error')
            return
        end
        xTarget.removeMoney(salePrice)
        status = 'paid'
        newBalance = balance + salePrice
        MySQL.update.await('UPDATE ya_cardealer_dealerships SET balance = ? WHERE id = ?', { newBalance, row.dealership_id })
    end

    registerOwnedVehicle(buyerIdentifier, stock.model, stock.plate)

    local salesInvoiceId = MySQL.insert.await([[
        INSERT INTO ya_cardealer_sales_invoices
        (dealership_id, stock_id, invoice_number, transaction_number, payment_method, status,
         buyer_name, buyer_dob, buyer_phone, buyer_identifier, vehicle_label, vehicle_model, plate,
         subtotal, vat_amount, total, sold_by, sold_by_name, paid_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        row.dealership_id, stockId, invoiceNumber, transactionNumber, paymentMethod, status,
        buyerName, buyerDob ~= '' and buyerDob or nil, buyerPhone ~= '' and buyerPhone or nil, buyerIdentifier,
        stock.label, stock.model, stock.plate, subtotal, vatAmount, total, identifier, sellerName,
        status == 'paid' and os.date('%Y-%m-%d %H:%M:%S') or nil,
    })

    MySQL.update.await([[
        UPDATE ya_cardealer_stock
        SET status = 'sold', sold_to = ?, sold_to_name = ?, sale_price = ?, sold_by = ?, sold_at = NOW()
        WHERE id = ?
    ]], { buyerIdentifier, buyerName, salePrice, identifier, stockId })

    addInvoice(
        row.dealership_id,
        paymentMethod == 'cash' and 'sale_cash' or 'sale_invoice',
        paymentMethod == 'cash' and salePrice or 0,
        newBalance,
        ('Salg %s: %s (%s)'):format(paymentMethod == 'cash' and 'kontant' or 'faktura', stock.label, stock.plate),
        identifier, sellerName, stockId, stock.catalog_id
    )

    spawnSoldVehicleForPlayer(src, stock.model, stock.plate, spawn)
    if buyerId and buyerId ~= src then
        spawnSoldVehicleForPlayer(buyerId, stock.model, stock.plate, spawn)
    end

    if paymentMethod == 'cash' then
        notify(src, ('Solgt %s for %s DKK (kontant).'):format(stock.label, salePrice), 'success')
        notify(buyerId, ('Du købte %s (%s).'):format(stock.label, stock.plate), 'success')
    else
        notify(src, ('Faktura %s oprettet — %s DKK (ubetalt).'):format(invoiceNumber, salePrice), 'success')
        if buyerId then
            notify(buyerId, ('Du har modtaget faktura %s på %s DKK.'):format(invoiceNumber, salePrice), 'info')
        end
    end

    pushAppData(src, 'lager', row)
end)

RegisterNetEvent('ya_cardealer:getSalesInvoice', function(invoiceId)
    local src = source
    local row, err = requireMember(src)
    if not row then
        TriggerClientEvent('ya_tablet:cardealerSalesInvoice', src, { error = err })
        return
    end

    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    local invoice = MySQL.single.await([[
        SELECT si.*, d.name AS dealership_name,
               DATE_FORMAT(si.created_at, '%d. %b %Y') AS created_at_label,
               DATE_FORMAT(si.paid_at, '%d. %b %Y') AS paid_at_label
        FROM ya_cardealer_sales_invoices si
        JOIN ya_cardealer_dealerships d ON d.id = si.dealership_id
        WHERE si.id = ? AND si.dealership_id = ?
        LIMIT 1
    ]], { invoiceId, row.dealership_id })

    if not invoice then
        TriggerClientEvent('ya_tablet:cardealerSalesInvoice', src, { error = 'Faktura ikke fundet.' })
        return
    end

    TriggerClientEvent('ya_tablet:cardealerSalesInvoice', src, {
        invoice = {
            id = invoice.id,
            invoiceNumber = invoice.invoice_number,
            transactionNumber = invoice.transaction_number,
            paymentMethod = invoice.payment_method,
            status = invoice.status,
            buyerName = invoice.buyer_name,
            buyerDob = invoice.buyer_dob,
            buyerPhone = invoice.buyer_phone,
            vehicleLabel = invoice.vehicle_label,
            plate = invoice.plate,
            subtotal = invoice.subtotal,
            vatAmount = invoice.vat_amount,
            total = invoice.total,
            soldByName = invoice.sold_by_name,
            dealershipName = invoice.dealership_name,
            companyCvr = Config.CompanyCvr or '12345678',
            vatRate = math.floor((tonumber(Config.VatRate) or 0.25) * 100),
            currency = Config.Currency or 'DKK',
            createdAtLabel = invoice.created_at_label,
            paidAtLabel = invoice.paid_at_label,
        },
    })
end)

-- Fremtidig telefon-app: betal faktura
RegisterNetEvent('ya_cardealer:paySalesInvoice', function(invoiceId)
    local src = source
    invoiceId = tonumber(invoiceId)
    if not invoiceId then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local invoice = MySQL.single.await([[
        SELECT si.*, d.balance AS dealership_balance
        FROM ya_cardealer_sales_invoices si
        JOIN ya_cardealer_dealerships d ON d.id = si.dealership_id
        WHERE si.id = ? AND si.status = 'unpaid'
        LIMIT 1
    ]], { invoiceId })

    if not invoice then
        notify(src, 'Faktura ikke fundet eller allerede betalt.', 'error')
        return
    end

    if invoice.buyer_identifier and invoice.buyer_identifier ~= xPlayer.identifier then
        notify(src, 'Denne faktura tilhører ikke dig.', 'error')
        return
    end

    local cash = xPlayer.getMoney and xPlayer.getMoney() or 0
    if cash < invoice.total then
        notify(src, 'Du har ikke nok kontanter.', 'error')
        return
    end

    xPlayer.removeMoney(invoice.total)
    local newBalance = (invoice.dealership_balance or 0) + invoice.total
    MySQL.update.await('UPDATE ya_cardealer_dealerships SET balance = ? WHERE id = ?', { newBalance, invoice.dealership_id })
    MySQL.update.await("UPDATE ya_cardealer_sales_invoices SET status = 'paid', paid_at = NOW() WHERE id = ?", { invoiceId })

    if not invoice.buyer_identifier then
        MySQL.update.await('UPDATE ya_cardealer_sales_invoices SET buyer_identifier = ? WHERE id = ?', { xPlayer.identifier, invoiceId })
    end

    notify(src, ('Faktura %s betalt (%s DKK).'):format(invoice.invoice_number, invoice.total), 'success')
end)
