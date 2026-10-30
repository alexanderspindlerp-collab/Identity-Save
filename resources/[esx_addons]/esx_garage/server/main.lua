
local function normalizeFuel(vehicleProps)
    if not vehicleProps then return nil end
    local fuel = tonumber(vehicleProps.fuelLevel or vehicleProps.fuel)
    if not fuel then return nil end
    if fuel < 0 then fuel = 0 end
    if fuel > 100 then fuel = 100 end
    vehicleProps.fuelLevel = fuel + 0.0
    vehicleProps.fuel = fuel + 0.0
    return fuel + 0.0
end

local function applyFuelToSpawnedVehicle(vehicle, vehicleProps)
    local fuel = normalizeFuel(vehicleProps)
    if not fuel or not vehicle or vehicle == 0 then return end

    -- SetVehicleFuelLevel er en client-native og må ikke kaldes server-side.
    -- ox_fuel læser statebag'en og sætter fuel korrekt på clienten.
    Entity(vehicle).state:set('fuel', fuel, true)
end


local function ensureImpoundColumns()
    CreateThread(function()
        Wait(1500)
        MySQL.update.await([[ALTER TABLE `owned_vehicles`
            ADD COLUMN IF NOT EXISTS `impound_price` INT NOT NULL DEFAULT 0 AFTER `pound`,
            ADD COLUMN IF NOT EXISTS `impound_type` VARCHAR(32) NOT NULL DEFAULT 'normal' AFTER `impound_price`,
            ADD COLUMN IF NOT EXISTS `impound_locked` TINYINT(1) NOT NULL DEFAULT 0 AFTER `impound_type`,
            ADD COLUMN IF NOT EXISTS `impound_reason` TEXT NULL AFTER `impound_locked`,
            ADD COLUMN IF NOT EXISTS `impound_officer` VARCHAR(128) NULL AFTER `impound_reason`,
            ADD COLUMN IF NOT EXISTS `impound_time` INT NULL AFTER `impound_officer`]])
    end)
end

ensureImpoundColumns()


RegisterNetEvent('esx_garage:setVehicleOut')
AddEventHandler('esx_garage:setVehicleOut', function(vehicleProps, parking)
    normalizeFuel(vehicleProps)
    local source = source
    local xPlayer = ESX.Player(source)

    MySQL.update('UPDATE owned_vehicles SET `stored` = @stored, `parking` = COALESCE(@parking, `parking`), `vehicle` = @vehicle WHERE `plate` = @plate AND `owner` = @identifier', {
        ['@identifier'] = xPlayer.getIdentifier(),
        ['@vehicle'] = json.encode(vehicleProps),
        ['@plate'] = vehicleProps.plate,
        ['@stored'] = false,
        ['@parking'] = parking
    })
end)

RegisterServerEvent('esx_garage:updateOwnedVehicle')
AddEventHandler('esx_garage:updateOwnedVehicle', function(stored, parking, Impound, data, spawn)
    if data and data.vehicleProps then normalizeFuel(data.vehicleProps) end
	local source = source
	local xPlayer  = ESX.Player(source)
		MySQL.update('UPDATE owned_vehicles SET `stored` = @stored, `parking` = @parking, `pound` = @Impound, `vehicle` = @vehicle WHERE `plate` = @plate AND `owner` = @identifier',
		{
			['@identifier'] = xPlayer.getIdentifier(),
			['@vehicle'] 	= json.encode(data.vehicleProps),
			['@plate'] 		= data.vehicleProps.plate,
			['@stored']     = stored,
			['@parking']    = parking,
			['@Impound']    	= Impound
		})

		if stored then
			xPlayer.showNotification(TranslateCap('veh_stored'))
            if GetResourceState('san_mdt') == 'started' and data and data.vehicleProps and data.vehicleProps.plate then
                TriggerEvent('san_mdt:unregisterPoliceGarageVehicle', data.vehicleProps.plate)
            end
		else 
			ESX.OneSync.SpawnVehicle(data.vehicleProps.model, spawn, data.spawnPoint.heading,data.vehicleProps, function(vehicle)
				local vehicle = NetworkGetEntityFromNetworkId(vehicle)
				Wait(300)
				TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
			end)
		end
end)

RegisterServerEvent('esx_garage:setImpound')
AddEventHandler('esx_garage:setImpound', function(Impound, vehicleProps)
    normalizeFuel(vehicleProps)
	local source = source
	local xPlayer  = ESX.Player(source)

		MySQL.update('UPDATE owned_vehicles SET `stored` = @stored, `pound` = @Impound, `vehicle` = @vehicle WHERE `plate` = @plate AND `owner` = @identifier',
		{
			['@identifier'] = xPlayer.getIdentifier(),
			['@vehicle'] 	= json.encode(vehicleProps),
			['@plate'] 		= vehicleProps.plate,
			['@stored']     = 2,
			['@Impound']    	= Impound
		})

		xPlayer.showNotification(TranslateCap('veh_impounded'))
end)


ESX.RegisterServerCallback('esx_garage:getVehiclesInParking', function(source, cb, parking)
	local xPlayer  = ESX.Player(source)

	MySQL.query('SELECT * FROM `owned_vehicles` WHERE `owner` = @identifier AND `parking` = @parking AND `stored` = 1',
	{
		['@identifier'] 	= xPlayer.getIdentifier(),
		['@parking']     	= parking
	}, function(result)

		local vehicles = {}
		for i = 1, #result, 1 do
			table.insert(vehicles, {
				vehicle 	= json.decode(result[i].vehicle),
				plate 		= result[i].plate
			})
		end

		cb(vehicles)
	end)
end)

ESX.RegisterServerCallback('esx_garage:checkVehicleOwner', function(source, cb, plate)
    local xPlayer = ESX.Player(source)

	MySQL.query('SELECT COUNT(*) as count FROM `owned_vehicles` WHERE `owner` = @identifier AND `plate` = @plate',
	{
		['@identifier'] 	= xPlayer.getIdentifier(),
		['@plate']     		= plate
	}, function(result)

		if tonumber(result[1].count) > 0 then
			return cb(true)
		else
			return cb(false)
		end
	end)
end)

-- Pounds part
ESX.RegisterServerCallback('esx_garage:getVehiclesImpounded', function(source, cb)
	local xPlayer  = ESX.Player(source)

	MySQL.query('SELECT * FROM `owned_vehicles` WHERE `owner` = @identifier AND `stored` = 0',
	{
		['@identifier'] 	= xPlayer.getIdentifier(),
	}, function(result)
		local vehicles = {}
		
		for i = 1, #result, 1 do
			table.insert(vehicles, {
				vehicle 	= json.decode(result[i].vehicle),
				plate 		= result[i].plate
			})
		end

		cb(vehicles)
	end)
end)

ESX.RegisterServerCallback('esx_garage:getVehiclesInPound', function(source, cb, Impound)
	local xPlayer  = ESX.Player(source)

	MySQL.query("SELECT * FROM `owned_vehicles` WHERE `owner` = @identifier AND `pound` = @Impound AND `stored` = 2 AND COALESCE(`impound_type`, 'normal') <> 'permanent'",
	{
		['@identifier'] 	= xPlayer.getIdentifier(),
		['@Impound']     	    = Impound
	}, function(result)
		local vehicles = {}

		for i = 1, #result, 1 do
			table.insert(vehicles, {
				vehicle 	= json.decode(result[i].vehicle),
				plate 		= result[i].plate,
                impound_price = tonumber(result[i].impound_price) or nil,
                impound_type = result[i].impound_type or 'normal',
                impound_locked = tonumber(result[i].impound_locked) or 0,
                impound_reason = result[i].impound_reason,
                impound_officer = result[i].impound_officer,
                impound_time = result[i].impound_time
			})
		end

		cb(vehicles)
	end)
end)

local function getAccountMoneySafe(xPlayer, accountName)
    if not xPlayer or not xPlayer.getAccount then return 0 end
    local ok, account = pcall(function() return xPlayer.getAccount(accountName) end)
    if ok and account and account.money then return tonumber(account.money) or 0 end
    return 0
end

local function getCashMoneySafe(xPlayer)
    if not xPlayer or not xPlayer.getMoney then return 0 end
    local ok, money = pcall(function() return xPlayer.getMoney() end)
    if ok then return tonumber(money) or 0 end
    return 0
end

local function removeImpoundMoney(xPlayer, amount, method)
    amount = math.floor(tonumber(amount) or 0)
    method = tostring(method or 'bank'):lower()
    if method ~= 'bank' and method ~= 'cash' then method = 'bank' end
    if amount <= 0 then return true, 'free' end
    if not xPlayer then return false, 'missing_player' end

    local bank = getAccountMoneySafe(xPlayer, 'bank')
    local cash = getCashMoneySafe(xPlayer)

    local function payBank()
        if bank >= amount and xPlayer.removeAccountMoney then
            local ok = pcall(function() xPlayer.removeAccountMoney('bank', amount, 'Impound Fee') end)
            if not ok then ok = pcall(function() xPlayer.removeAccountMoney('bank', amount) end) end
            if ok then return true, 'bank' end
        end
        return false
    end

    local function payCash()
        if cash >= amount and xPlayer.removeMoney then
            local ok = pcall(function() xPlayer.removeMoney(amount, 'Impound Fee') end)
            if not ok then ok = pcall(function() xPlayer.removeMoney(amount) end) end
            if ok then return true, 'cash' end
        end
        return false
    end

    if method == 'cash' then
        local ok, account = payCash(); if ok then return true, account end
        return false, 'missing_cash'
    end

    local ok, account = payBank(); if ok then return true, account end
    return false, 'missing_bank'
end

ESX.RegisterServerCallback('esx_garage:checkMoney', function(source, cb, amount)
    local xPlayer = ESX.Player(source)
    amount = math.floor(tonumber(amount) or 0)
    cb((getAccountMoneySafe(xPlayer, 'bank') + getCashMoneySafe(xPlayer)) >= amount)
end)

RegisterServerEvent("esx_garage:payPound")
AddEventHandler("esx_garage:payPound", function(amount)
    local source = source
    local xPlayer = ESX.Player(source)
    amount = math.floor(tonumber(amount) or 0)

    local paid = removeImpoundMoney(xPlayer, amount, 'bank')
    if paid then
        xPlayer.showNotification(TranslateCap('pay_Impound_bill', amount))
    else
        xPlayer.showNotification(TranslateCap('missing_money'))
    end
end)

local function getGaragePlayer(source)
    return ESX.Player(source) or (ESX.GetPlayerFromId and ESX.GetPlayerFromId(source))
end

local registerMdtFleetVehicleIfPoliceGarage

RegisterNetEvent('esx_garage:retrieveAndSpawnVehicle', function(vehicleProps, parking, spawnPoint)
    local source = source
    local xPlayer = getGaragePlayer(source)
    if not xPlayer or not vehicleProps or not vehicleProps.plate or not spawnPoint then return end

    local plate = vehicleProps.plate
    local result = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND plate = ? AND stored = 1', {
        xPlayer.getIdentifier(), plate
    })

    if not result then
        xPlayer.showNotification('Køretøjet er ikke gemt i garagen.')
        return
    end

    local savedProps = json.decode(result.vehicle or '{}') or vehicleProps
    vehicleProps = savedProps
    vehicleProps.plate = savedProps.plate or plate
    normalizeFuel(vehicleProps)
    normalizeFuel(vehicleProps)

    MySQL.update.await('UPDATE owned_vehicles SET stored = 0, parking = COALESCE(?, parking), vehicle = ? WHERE owner = ? AND plate = ?', {
        parking, json.encode(vehicleProps), xPlayer.getIdentifier(), plate
    })

    local spawn = vector3(tonumber(spawnPoint.x), tonumber(spawnPoint.y), tonumber(spawnPoint.z))
    local heading = tonumber(spawnPoint.heading) or 0.0

    ESX.OneSync.SpawnVehicle(vehicleProps.model, spawn, heading, vehicleProps, function(netId)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and vehicle ~= 0 then
            Wait(250)
            applyFuelToSpawnedVehicle(vehicle, vehicleProps)
            TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
            registerMdtFleetVehicleIfPoliceGarage(xPlayer, vehicleProps, source)
        end
    end)
end)


RegisterNetEvent('esx_garage:retrieveAndSpawnImpoundedVehicle', function(vehicleProps, poundName, spawnPoint, cost, paymentMethod)
    local source = source
    local xPlayer = getGaragePlayer(source)
    if not xPlayer or not vehicleProps or not vehicleProps.plate or not spawnPoint then return end

    cost = tonumber(cost) or 0
    local plate = vehicleProps.plate

    local result = MySQL.single.await([[SELECT vehicle, impound_price, impound_locked, impound_type FROM owned_vehicles WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '') AND stored = 2]], {
        xPlayer.getIdentifier(), plate
    })

    if not result then
        xPlayer.showNotification('Køretøjet er ikke i impound.')
        return
    end

    if tonumber(result.impound_locked) == 1 or result.impound_type == 'locked' then
        xPlayer.showNotification('Køretøjet er låst i impound og kan ikke hentes endnu.')
        return
    end

    if result.impound_type == 'permanent' then
        xPlayer.showNotification('Køretøjet er permanent beslaglagt.')
        return
    end

    local dbPrice = tonumber(result.impound_price) or 0
    cost = math.floor(dbPrice > 0 and dbPrice or (tonumber(cost) or 0))
    if cost < 0 then cost = 0 end

    if cost > 0 then
        local paid, account = removeImpoundMoney(xPlayer, cost, paymentMethod)
        if not paid then
            xPlayer.showNotification(account == 'missing_cash' and 'Du har ikke nok kontanter.' or 'Du har ikke nok penge på kortet.')
            print(('[esx_garage] Impound betaling AFVIST plate=%s cost=%s bank=%s cash=%s'):format(tostring(plate), tostring(cost), tostring(getAccountMoneySafe(xPlayer, 'bank')), tostring(getCashMoneySafe(xPlayer))))
            return
        end

        print(('[esx_garage] Impound betaling OK plate=%s cost=%s account=%s'):format(tostring(plate), tostring(cost), tostring(account)))
        xPlayer.showNotification(TranslateCap('pay_Impound_bill', cost))
    else
        print(('[esx_garage] Impound hentet uden pris plate=%s dbPrice=%s uiCost=%s'):format(tostring(plate), tostring(dbPrice), tostring(cost)))
    end

    local savedProps = json.decode(result.vehicle or '{}') or vehicleProps
    vehicleProps = savedProps
    vehicleProps.plate = savedProps.plate or plate
    normalizeFuel(vehicleProps)

    MySQL.update.await([[UPDATE owned_vehicles SET stored = 0, pound = NULL, impound_price = 0, impound_type = 'normal', impound_locked = 0, impound_reason = NULL, impound_officer = NULL, impound_time = NULL, vehicle = ? WHERE owner = ? AND REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '')]], {
        json.encode(vehicleProps), xPlayer.getIdentifier(), plate
    })

    local spawn = vector3(tonumber(spawnPoint.x), tonumber(spawnPoint.y), tonumber(spawnPoint.z))
    local heading = tonumber(spawnPoint.heading) or 0.0

    ESX.OneSync.SpawnVehicle(vehicleProps.model, spawn, heading, vehicleProps, function(netId)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and vehicle ~= 0 then
            Wait(250)
            applyFuelToSpawnedVehicle(vehicle, vehicleProps)
            TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
            registerMdtFleetVehicleIfPoliceGarage(xPlayer, vehicleProps, source)
        end
    end)
end)


local function trimPlate(plate)
    return ESX.Math and ESX.Math.Trim(plate or '') or tostring(plate or ''):gsub('^%s*(.-)%s*$', '%1')
end

local GarageFleetPoliceModels = {
    police=true, police2=true, police3=true, police4=true, policeold1=true, policeold2=true,
    policet=true, policeb=true, riot=true, riot2=true, fbi=true, fbi2=true, sheriff=true, sheriff2=true, polmav=true
}

local function garageGetJob(xPlayer)
    if not xPlayer then return nil end
    if type(xPlayer.getJob) == 'function' then
        local ok, job = pcall(xPlayer.getJob, xPlayer)
        if ok and job then return job end
    end
    if type(xPlayer.job) == 'function' then
        local ok, job = pcall(xPlayer.job, xPlayer)
        if ok and job then return job end
    end
    if type(xPlayer.job) == 'table' then return xPlayer.job end
    return nil
end


local function garageGetPlayerSource(xPlayer, fallbackSrc)
    -- ESX Legacy can expose unknown fields as invalid methods.
    -- Do NOT touch xPlayer.source directly, because it can throw:
    -- "Attempted to call invalid method ... source".
    if tonumber(fallbackSrc) then return tonumber(fallbackSrc) end
    if not xPlayer then return nil end

    local rawSource = nil
    if type(xPlayer) == 'table' then
        rawSource = rawget(xPlayer, 'source') or rawget(xPlayer, 'playerId') or rawget(xPlayer, 'serverId')
    end
    if tonumber(rawSource) then return tonumber(rawSource) end

    if type(xPlayer.getSource) == 'function' then
        local ok, src = pcall(xPlayer.getSource, xPlayer)
        if ok and tonumber(src) then return tonumber(src) end
    end

    return nil
end

local function garagePlayerIsPolice(xPlayer)
    local job = garageGetJob(xPlayer) or {}
    local name = tostring(job.name or ''):lower()
    return name == 'police' or name == 'politi' or name == 'lspd' or name == 'sheriff'
end

local function garageModelName(model)
    if type(model) == 'string' then
        local low = string.lower(model)
        if GarageFleetPoliceModels[low] then return low end
        local asNum = tonumber(model)
        if asNum then model = asNum else return low end
    end
    local hash = tonumber(model) or 0
    for modelName, _ in pairs(GarageFleetPoliceModels) do
        if GetHashKey(modelName) == hash then return modelName end
    end
    if GetDisplayNameFromVehicleModel then
        local ok, name = pcall(GetDisplayNameFromVehicleModel, hash)
        if ok and name then return string.lower(tostring(name)) end
    end
    return tostring(model or ''):lower()
end

registerMdtFleetVehicleIfPoliceGarage = function(xPlayer, vehicleProps, src)
    if not garagePlayerIsPolice(xPlayer) or not vehicleProps then return end
    local plate = trimPlate(vehicleProps.plate or '')
    if plate == '' then return end

    local modelName = garageModelName(vehicleProps.model)
    local allowed = GarageFleetPoliceModels[modelName] == true

    -- Failsafe: hvis det er en politi-betjent der tager et køretøj ud af ESX garagen,
    -- registrerer vi det alligevel til MDT. MDT-serveren afviser stadig ikke-politi jobs.
    -- Det løser custom politi-modeller / hash-modeller som ikke matcher standard GTA modelnavne.
    if allowed or true then
        local officerSource = garageGetPlayerSource(xPlayer, src)
        TriggerEvent('san_mdt:registerPoliceGarageVehicle', plate, vehicleProps.model, officerSource)
        print(('[esx_garage -> san_mdt] fleet garage registered plate=%s model=%s officer=%s'):format(plate, tostring(vehicleProps.model), tostring(officerSource)))
    end
end



local function moveOutVehiclesToGarageOnStart()
    if Config.MoveOutVehiclesToGarageOnStart == false then return end
    if Config.MoveOutVehiclesToImpoundOnStart == true then return end

    CreateThread(function()
        Wait(3000)

        local garageName = Config.DefaultRestartGarage
        if not garageName or not (Config.Garages and Config.Garages[garageName]) then
            for name in pairs(Config.Garages or {}) do
                garageName = name
                break
            end
        end
        garageName = garageName or 'VespucciBoulevard'

        local changed = MySQL.update.await([[UPDATE owned_vehicles
            SET stored = 1,
                parking = COALESCE(NULLIF(parking, ''), ?),
                pound = NULL
            WHERE stored = 0]], {
            garageName
        })

        if changed and changed > 0 then
            print(('[esx_garage] Returnerede %s ude-køretøjer til garage efter restart (standard: %s).'):format(changed, garageName))
        end
    end)
end

local function moveOutVehiclesToImpoundOnStart()
    if Config.MoveOutVehiclesToImpoundOnStart == false then return end

    CreateThread(function()
        Wait(3000)

        local poundName = Config.DefaultRestartImpound or 'LosSantos'
        local reason = Config.RestartImpoundReason or 'Køretøjet var ude ved server restart/crash'

        local changed = MySQL.update.await([[UPDATE owned_vehicles
            SET stored = 2,
                pound = COALESCE(NULLIF(pound, ''), ?),
                impound_price = COALESCE(impound_price, 0),
                impound_reason = COALESCE(impound_reason, ?),
                impound_officer = COALESCE(impound_officer, 'System'),
                impound_time = COALESCE(impound_time, UNIX_TIMESTAMP())
            WHERE stored = 0]], {
            poundName,
            reason
        })

        if changed and changed > 0 then
            print(('[esx_garage] Flyttede %s ude-køretøjer til impound efter restart.'):format(changed))
        end
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    moveOutVehiclesToGarageOnStart()
    moveOutVehiclesToImpoundOnStart()
end)

RegisterNetEvent('esx_garage:syncOutVehicleFuel', function(vehicleProps)
    local source = source
    local xPlayer = getGaragePlayer(source)
    if not xPlayer or not vehicleProps or not vehicleProps.plate then return end

    normalizeFuel(vehicleProps)

    local plate = trimPlate(vehicleProps.plate)
    if plate == '' then return end

    local result = MySQL.single.await('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND TRIM(plate) = ? AND stored = 0 LIMIT 1', {
        xPlayer.getIdentifier(),
        plate
    })

    if not result then return end

    local savedProps = json.decode(result.vehicle or '{}') or {}
    savedProps.fuelLevel = vehicleProps.fuelLevel
    savedProps.fuel = vehicleProps.fuel

    MySQL.update.await('UPDATE owned_vehicles SET vehicle = ? WHERE owner = ? AND TRIM(plate) = ? AND stored = 0', {
        json.encode(savedProps),
        xPlayer.getIdentifier(),
        plate
    })
end)

local function getPlayerJob(xPlayer)
    if not xPlayer then return nil end

    if type(xPlayer.getJob) == 'function' then
        local ok, job = pcall(function() return xPlayer.getJob() end)
        if ok and job then return job end
    end

    if type(xPlayer.job) == 'function' then
        local ok, job = pcall(function() return xPlayer.job() end)
        if ok and job then return job end
    elseif type(xPlayer.job) == 'table' then
        return xPlayer.job
    end

    return nil
end

local function isPolicePlayer(xPlayer)
    local job = getPlayerJob(xPlayer)
    return job and job.name == 'police'
end



local function canReturnPermanentImpound(xPlayer)
    if not isPolicePlayer(xPlayer) then return false end

    local job = getPlayerJob(xPlayer) or {}
    local gradeName = job.grade_name or job.gradeName or ''
    local grade = tonumber(job.grade or 0) or 0

    local allowed = Config.PermanentImpoundReturnGrades or { boss = true, chief = true, lieutenant = true }

    if allowed[gradeName] == true then return true end
    if allowed[tostring(grade)] == true then return true end

    local minGrade = tonumber(Config.PermanentImpoundReturnMinGrade or -1)
    if minGrade >= 0 and grade >= minGrade then return true end

    return false
end

ESX.RegisterServerCallback('esx_garage:getPermanentImpoundedVehicles', function(source, cb)
    local xPlayer = getGaragePlayer(source)
    if not canReturnPermanentImpound(xPlayer) then
        if xPlayer then xPlayer.showNotification('Du har ikke adgang til permanent beslaglagte køretøjer.') end
        cb({})
        return
    end

    MySQL.query([[SELECT owner, plate, vehicle, impound_reason, impound_officer, impound_time
        FROM owned_vehicles
        WHERE stored = 2 AND impound_type = 'permanent'
        ORDER BY impound_time DESC]], {}, function(result)
        local vehicles = {}
        for i = 1, #result do
            local props = json.decode(result[i].vehicle or '{}') or {}
            vehicles[#vehicles + 1] = {
                owner = result[i].owner,
                plate = result[i].plate,
                vehicle = props,
                model = props.model,
                impound_reason = result[i].impound_reason,
                impound_officer = result[i].impound_officer,
                impound_time = result[i].impound_time
            }
        end
        cb(vehicles)
    end)
end)

RegisterNetEvent('esx_garage:returnPermanentImpoundedVehicle', function(plate, price)
    local source = source
    local xPlayer = getGaragePlayer(source)
    if not canReturnPermanentImpound(xPlayer) then
        if xPlayer then xPlayer.showNotification('Du har ikke adgang til at frigive permanent beslaglagte køretøjer.') end
        return
    end

    plate = trimPlate(plate)
    price = math.floor(tonumber(price) or 0)
    if price < 0 then price = 0 end
    if price > 1000000 then price = 1000000 end

    local changed = MySQL.update.await([[UPDATE owned_vehicles
        SET stored = 2,
            pound = COALESCE(NULLIF(pound, ''), ?),
            impound_price = ?,
            impound_type = 'normal',
            impound_locked = 0,
            impound_reason = COALESCE(impound_reason, 'Frigivet fra permanent beslaglæggelse'),
            impound_officer = ?,
            impound_time = UNIX_TIMESTAMP()
        WHERE REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '') AND stored = 2 AND impound_type = 'permanent']], {
        Config.DefaultPoliceImpound or Config.DefaultRestartImpound or 'LosSantos',
        price,
        xPlayer.getName and xPlayer.getName() or GetPlayerName(source) or 'Ukendt betjent',
        plate
    })

    if changed and changed > 0 then
        xPlayer.showNotification(('Køretøjet %s er frigivet til impound. Pris: %s DKK'):format(plate, price))
    else
        xPlayer.showNotification('Kunne ikke finde permanent beslaglagt køretøj med den nummerplade.')
    end
end)

RegisterNetEvent('esx_garage:policeImpoundVehicle', function(netId, vehicleProps, price, reason, impoundType)
    normalizeFuel(vehicleProps)
    local source = source
    local xPlayer = getGaragePlayer(source)

    if not isPolicePlayer(xPlayer) then
        if xPlayer then xPlayer.showNotification('Du er ikke betjent.') end
        return
    end

    if not vehicleProps or not vehicleProps.plate then
        xPlayer.showNotification('Kunne ikke finde nummerpladen på køretøjet.')
        return
    end

    local plate = trimPlate(vehicleProps.plate)
    price = tonumber(price) or 0
    price = math.floor(price)

    if price < 0 then price = 0 end
    if price > 1000000 then price = 1000000 end

    impoundType = tostring(impoundType or 'normal')
    if impoundType ~= 'normal' and impoundType ~= 'locked' and impoundType ~= 'permanent' then
        impoundType = 'normal'
    end

    reason = tostring(reason or ''):sub(1, 500)
    if reason == '' then reason = 'Ingen beskrivelse angivet' end

    local officerName = xPlayer.getName and xPlayer.getName() or GetPlayerName(source) or 'Ukendt betjent'
    local poundName = Config.DefaultPoliceImpound or 'LosSantos'
    local exists = MySQL.single.await([[SELECT owner FROM owned_vehicles WHERE REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '') LIMIT 1]], { plate })

    if not exists then
        xPlayer.showNotification('Køretøjet er ikke registreret i owned_vehicles.')
        return
    end

    local changed = 0

    local requestedType = impoundType
    local locked = requestedType == 'locked' and 1 or 0
    local dbImpoundType = requestedType
    if requestedType == 'locked' then dbImpoundType = 'normal' end

    if requestedType == 'permanent' then
        -- Permanent beslaglæggelse gemmes stadig i owned_vehicles, så MDT senere kan vise
        -- en mappe/liste over permanent beslaglagte køretøjer. Den kan ikke hentes ud.
        price = 0
        locked = 1
    end

    changed = MySQL.update.await([[UPDATE owned_vehicles
        SET stored = 2,
            pound = ?,
            vehicle = ?,
            impound_price = ?,
            impound_type = ?,
            impound_locked = ?,
            impound_reason = ?,
            impound_officer = ?,
            impound_time = UNIX_TIMESTAMP()
        WHERE REPLACE(UPPER(TRIM(plate)), ' ', '') = REPLACE(UPPER(TRIM(?)), ' ', '')]], {
        poundName,
        json.encode(vehicleProps),
        price,
        dbImpoundType,
        locked,
        reason,
        officerName,
        plate
    })

    if changed and changed > 0 then
        if requestedType == 'permanent' then
            xPlayer.showNotification(('Køretøjet %s er permanent beslaglagt.'):format(plate))
        elseif requestedType == 'locked' then
            xPlayer.showNotification(('Køretøjet %s er låst i impound. Pris: %s DKK'):format(plate, price))
        else
            xPlayer.showNotification(('Køretøjet %s er beslaglagt. Pris: %s DKK'):format(plate, price))
        end

        TriggerClientEvent('esx_garage:deleteImpoundedVehicle', source, netId)
    else
        xPlayer.showNotification('Kunne ikke beslaglægge køretøjet.')
    end
end)
