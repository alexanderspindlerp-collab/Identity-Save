local ESX = nil

CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

local function getUnixTime()
    return os.time()
end

local function sanitizeText(value, fallback, maxLen)
    value = tostring(value or fallback or '')
    value = value:gsub('[\r\n\t]', ' ')
    if maxLen and #value > maxLen then
        value = value:sub(1, maxLen)
    end
    return value
end

local sessions = {}

local function getOfficerName(src)
    local officerName = GetPlayerName(src) or ('ID ' .. src)

    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            if xPlayer.getName then
                local name = xPlayer.getName()
                if name and name ~= '' then officerName = name end
            end

            if officerName == GetPlayerName(src) or officerName == ('ID ' .. src) then
                local firstName, lastName
                if xPlayer.get then
                    firstName = xPlayer.get('firstName') or xPlayer.get('firstname')
                    lastName = xPlayer.get('lastName') or xPlayer.get('lastname')
                end
                if (not firstName or not lastName) and xPlayer.getMeta then
                    firstName = firstName or xPlayer.getMeta('firstName') or xPlayer.getMeta('firstname')
                    lastName = lastName or xPlayer.getMeta('lastName') or xPlayer.getMeta('lastname')
                end
                if firstName or lastName then
                    officerName = ('%s %s'):format(firstName or '', lastName or ''):gsub('^%s*(.-)%s*$', '%1')
                end
            end
        end
    end

    return sanitizeText(officerName, 'Ukendt', 40)
end

local function cleanReading(r)
    if type(r) ~= 'table' then return nil end
    local speed = math.floor(tonumber(r.speed) or 0)
    if speed < 1 then return nil end

    return {
        timestamp = tonumber(r.timestamp) or getUnixTime(),
        plate = sanitizeText(r.plate, 'UKENDT', 12),
        speed = speed,
        distance = math.floor(tonumber(r.distance) or 0)
    }
end

RegisterNetEvent('speedradar:server:placeEquipment', function()
    local src = source
    local itemName = Config.ItemName or 'fartkontrol_udstyr'
    local count = exports.ox_inventory:GetItemCount(src, itemName)

    if not count or count < 1 then
        TriggerClientEvent('speedradar:client:placeFailed', src, 'Du har ikke Fartkontrols Udstyr på dig.')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, itemName, 1)
    if not removed then
        TriggerClientEvent('speedradar:client:placeFailed', src, 'Kunne ikke fjerne itemet fra inventory.')
        return
    end

    sessions[src] = {
        officer = getOfficerName(src),
        created = getUnixTime(),
        readings = {}
    }

    TriggerClientEvent('speedradar:client:placeEquipment', src)
end)

RegisterNetEvent('speedradar:server:returnEquipment', function()
    local src = source
    local itemName = Config.ItemName or 'fartkontrol_udstyr'
    exports.ox_inventory:AddItem(src, itemName, 1)
end)

RegisterNetEvent('speedradar:server:saveReading', function(reading)
    local src = source
    local clean = cleanReading(reading)
    if not clean then return end

    sessions[src] = sessions[src] or {
        officer = getOfficerName(src),
        created = getUnixTime(),
        readings = {}
    }

    table.insert(sessions[src].readings, 1, clean)
    while #sessions[src].readings > (Config.MaxPrintReadings or 12) do
        table.remove(sessions[src].readings)
    end
end)

RegisterNetEvent('speedradar:server:createPrintout', function()
    local src = source
    local session = sessions[src]
    local readings = session and session.readings or {}

    if type(readings) ~= 'table' or #readings < 1 then
        TriggerClientEvent('speedradar:client:printFailed', src, 'Der er ingen målinger at udskrive. Gem en måling med venstreklik først.')
        return
    end

    local clean = {}
    local max = math.min(#readings, Config.MaxPrintReadings or 12)

    -- Vend rækkefølgen, så ældste måling står øverst på udskriften.
    for i = max, 1, -1 do
        local r = cleanReading(readings[i])
        if r then clean[#clean + 1] = r end
    end

    if #clean < 1 then
        TriggerClientEvent('speedradar:client:printFailed', src, 'Der er ingen gyldige målinger at udskrive.')
        return
    end

    local officerName = session and session.officer or getOfficerName(src)
    local created = getUnixTime()
    local metadata = {
        label = 'Fartkontrol Udskrift',
        description = ('Udskrift med %s fartmåling(er). Brug itemet for at se hele rapporten.'):format(#clean),
        officer = officerName,
        created = created,
        readings = clean,
        measurements = clean,
        printData = {
            officer = officerName,
            created = created,
            readings = clean,
            measurements = clean
        }
    }

    local added = exports.ox_inventory:AddItem(src, Config.PrintItemName or 'fartkontrol_udskrift', 1, metadata)
    if added then
        TriggerClientEvent('speedradar:client:printCreated', src)
    else
        TriggerClientEvent('speedradar:client:printFailed', src, 'Kunne ikke give Fartkontrol Udskrift. Har du plads i inventory?')
    end
end)


RegisterNetEvent('speedradar:server:openPrintout', function(slot)
    local src = source
    slot = tonumber(slot)

    if not slot then
        TriggerClientEvent('speedradar:client:openPrintout', src, {})
        return
    end

    local item = exports.ox_inventory:GetSlot(src, slot)
    local metadata = item and item.metadata or {}

    -- Sikrer kompatibilitet mellem gamle/nye udskrifter.
    if metadata.printData then
        metadata.officer = metadata.officer or metadata.printData.officer
        metadata.created = metadata.created or metadata.printData.created
        metadata.readings = metadata.readings or metadata.printData.readings or metadata.printData.measurements
        metadata.measurements = metadata.measurements or metadata.printData.measurements or metadata.printData.readings
    end

    metadata.readings = metadata.readings or metadata.measurements or {}
    TriggerClientEvent('speedradar:client:openPrintout', src, metadata)
end)


local function destroyPrintout(src, slot)
    slot = tonumber(slot)

    if not slot then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fartkontrol Udskrift',
            description = 'Kunne ikke finde udskriften i inventory.',
            type = 'error'
        })
        return
    end

    local itemName = Config.PrintItemName or 'fartkontrol_udskrift'
    local item = exports.ox_inventory:GetSlot(src, slot)

    if not item or item.name ~= itemName then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fartkontrol Udskrift',
            description = 'Denne udskrift findes ikke længere.',
            type = 'error'
        })
        return
    end

    -- Fjern altid fra den valgte slot. Metadata skal IKKE matches her,
    -- fordi udskrifter har unik metadata og nested tabeller.
    local removed, reason = exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)

    if removed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fartkontrol Udskrift',
            description = 'Du ødelagde udskriften.',
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fartkontrol Udskrift',
            description = ('Kunne ikke ødelægge udskriften%s'):format(reason and (': ' .. tostring(reason)) or '.'),
            type = 'error'
        })
    end
end

RegisterNetEvent('speedradar:server:destroyPrintout', function(slot)
    destroyPrintout(source, slot)
end)

-- Alias til ox_inventory item-button, som kalder denne event direkte fra client.
RegisterNetEvent('speedradar:destroyPrintout', function(slot)
    destroyPrintout(source, slot)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
