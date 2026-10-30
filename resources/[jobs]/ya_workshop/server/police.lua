local ESX = exports['es_extended']:getSharedObject()

ESX.RegisterServerCallback('ya_workshop:canTunePoliceVehicle', function(source, cb, plate)
    if not WS.isPolicePlayer(source) then
        cb(false, 'Kun politiet kan bruge AutoShop.')
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    local job = xPlayer.getJob()
    local row = WS.findPoliceServiceVehicle(xPlayer.identifier, plate, job.name)
    if not row then
        cb(false, 'Dette køretøj er ikke registreret som tjenestekøretøj. Hent det fra politigaragen først.')
        return
    end

    cb(true)
end)

ESX.RegisterServerCallback('ya_workshop:getPoliceTunerData', function(source, cb, plate)
    if not WS.isPolicePlayer(source) then
        cb({ error = 'Kun politiet kan bruge AutoShop.' })
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    local job = xPlayer.getJob()
    local row = WS.findPoliceServiceVehicle(xPlayer.identifier, plate, job.name)
    if not row then
        cb({ error = 'Tjenestekøretøj ikke fundet. Hent bilen fra garagen først.' })
        return
    end

    cb({
        shopKey = 'police_autoshop',
        shopLabel = 'Politi AutoShop',
        companyName = job.label or 'Politi',
        branding = 'police',
        brandingLabel = 'Politi AutoShop',
        categories = WS.getPoliceCatalog(),
        unlockedGroups = {},
        policeMode = true,
    })
end)

RegisterNetEvent('ya_workshop:submitPoliceTune', function(cart, vehicleData)
    local src = source
    if not WS.isPolicePlayer(src) then return end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    if type(cart) ~= 'table' or next(cart) == nil then
        WS.notify(src, 'Ingen ændringer valgt.', 'error')
        TriggerClientEvent('ya_workshop:client:policeTuneFailed', src)
        return
    end

    if type(vehicleData) ~= 'table' or not vehicleData.plate then
        WS.notify(src, 'Køretøjsdata mangler.', 'error')
        TriggerClientEvent('ya_workshop:client:policeTuneFailed', src)
        return
    end

    local job = xPlayer.getJob()
    local row = WS.findPoliceServiceVehicle(xPlayer.identifier, vehicleData.plate, job.name)
    if not row then
        WS.notify(src, 'Du ejer ikke dette tjenestekøretøj.', 'error')
        TriggerClientEvent('ya_workshop:client:policeTuneFailed', src)
        return
    end

    local stored = row.vehicle and json.decode(row.vehicle) or {}
    local baselineProps = vehicleData.props or stored
    local targetProps = WS.buildTargetVehicleProps(baselineProps, cart)
    targetProps.plate = row.plate or vehicleData.plate
    if stored.model then
        targetProps.model = stored.model
    elseif vehicleData.model then
        targetProps.model = vehicleData.model
    end

    if targetProps.extras and targetProps.policeExtras then
        for id, enabled in pairs(targetProps.policeExtras) do
            targetProps.extras[id] = nil
        end
    end

    local ok, err = WS.savePoliceServiceVehicleProps(xPlayer.identifier, job.name, targetProps, row)
    if not ok then
        WS.notify(src, err or 'Kunne ikke gemme.', 'error')
        TriggerClientEvent('ya_workshop:client:policeTuneFailed', src)
        return
    end

    TriggerClientEvent('ya_workshop:client:policeTuneSaved', src, targetProps)
    WS.notify(src, 'Tjenestekøretøj opdateret — gratis.', 'success')
end)

RegisterNetEvent('ya_workshop:server:syncPoliceVehicleExtras', function(netId, policeExtras)
    local src = source
    if type(netId) ~= 'number' or type(policeExtras) ~= 'table' then return end
    TriggerClientEvent('ya_workshop:client:applyPoliceExtras', -1, netId, policeExtras)
end)
