if Config.EnableESXService then
	if Config.MaxInService ~= -1 then
		TriggerEvent('esx_service:activateService', 'police', Config.MaxInService)
	end
end

TriggerEvent('esx_phone:registerNumber', 'police', TranslateCap('alert_police'), true, true)
TriggerEvent('esx_society:registerSociety', 'police', TranslateCap('society_police'), 'society_police', 'society_police', 'society_police', {type = 'public'})

RegisterNetEvent('esx_policejob:confiscatePlayerItem')
AddEventHandler('esx_policejob:confiscatePlayerItem', function(target, itemType, itemName, amount)
	local source = source
	local sourceXPlayer = ESX.Player(source)
	local targetXPlayer = ESX.Player(target)
	local job = sourceXPlayer.getJob()
	local sourceXPlayerName = sourceXPlayer.getName()
	local targetXPlayerName = targetXPlayer.getName()
	if not IsPoliceJob(job.name) then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit The Confuscation System!'):format(sourceXPlayer.src))
		return
	end

	if itemType == 'item_standard' then
		local targetItem = targetXPlayer.getInventoryItem(itemName)
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)

		-- does the target player have enough in their inventory?
		if targetItem and targetItem.count >= amount then

			-- can the player carry the said amount of x item?
			if sourceXPlayer.canCarryItem(itemName, amount) then
				targetXPlayer.removeInventoryItem(itemName, amount)
				sourceXPlayer.addInventoryItem   (itemName, amount)
				sourceXPlayer.showNotification(TranslateCap('you_confiscated', amount, sourceItem.label, targetXPlayerName))
				targetXPlayer.showNotification(TranslateCap('got_confiscated', amount, sourceItem.label, sourceXPlayerName))
			else
				sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
			end
		else
			sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
		end

	elseif itemType == 'item_account' then
		local targetAccount = targetXPlayer.getAccount(itemName)

		-- does the target player have enough money?
		if targetAccount.money >= amount then
			targetXPlayer.removeAccountMoney(itemName, amount, "Confiscated")
			sourceXPlayer.addAccountMoney   (itemName, amount, "Confiscated")

			sourceXPlayer.showNotification(TranslateCap('you_confiscated_account', amount, itemName, targetXPlayerName))
			targetXPlayer.showNotification(TranslateCap('got_confiscated_account', amount, itemName, sourceXPlayerName))
		else
			sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
		end

	elseif itemType == 'item_weapon' then
		if amount == nil then amount = 0 end

		-- does the target player have weapon?
		if targetXPlayer.hasWeapon(itemName) then
			targetXPlayer.removeWeapon(itemName)
			sourceXPlayer.addWeapon   (itemName, amount)

			sourceXPlayer.showNotification(TranslateCap('you_confiscated_weapon', ESX.GetWeaponLabel(itemName), targetXPlayerName, amount))
			targetXPlayer.showNotification(TranslateCap('got_confiscated_weapon', ESX.GetWeaponLabel(itemName), amount, sourceXPlayerName))
		else
			sourceXPlayer.showNotification(TranslateCap('quantity_invalid'))
		end
	end
end)

local function YA_IsPoliceJob(jobName)
	return IsPoliceJob(jobName)
end

local YA_POLICE_JOB_IN = "('police','politi','lspd','sheriff')"

RegisterNetEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function(target)
	local xPlayer = ESX.Player(source)

	if YA_IsPoliceJob(xPlayer.getJob().name) then
		TriggerClientEvent('esx_policejob:handcuff', target)
	else
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Handcuffs!'):format(xPlayer.src))
	end
end)

RegisterNetEvent('esx_policejob:drag')
AddEventHandler('esx_policejob:drag', function(target)
	local xPlayer = ESX.Player(source)

	if YA_IsPoliceJob(xPlayer.getJob().name) then
		TriggerClientEvent('esx_policejob:drag', target, source)
	else
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Dragging!'):format(xPlayer.src))
	end
end)

RegisterNetEvent('esx_policejob:putInVehicle')
AddEventHandler('esx_policejob:putInVehicle', function(target)
	local xPlayer = ESX.Player(source)

	if YA_IsPoliceJob(xPlayer.getJob().name) then
		TriggerClientEvent('esx_policejob:putInVehicle', target)
	else
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Garage!'):format(xPlayer.src))
	end
end)

RegisterNetEvent('esx_policejob:OutVehicle')
AddEventHandler('esx_policejob:OutVehicle', function(target)
	local xPlayer = ESX.Player(source)

	if YA_IsPoliceJob(xPlayer.getJob().name) then
		TriggerClientEvent('esx_policejob:OutVehicle', target)
	else
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Exploit Dragging Out Of Vehicle!'):format(xPlayer.src))
	end
end)

RegisterNetEvent('esx_policejob:getStockItem')
AddEventHandler('esx_policejob:getStockItem', function(itemName, count)
	local source = source
	local xPlayer = ESX.Player(source)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		local inventoryItem = inventory.getItem(itemName)

		-- is there enough in the society?
		if count > 0 and inventoryItem.count >= count then

			-- can the player carry the said amount of x item?
			if xPlayer.canCarryItem(itemName, count) then
				inventory.removeItem(itemName, count)
				xPlayer.addInventoryItem(itemName, count)
				xPlayer.showNotification(TranslateCap('have_withdrawn', count, inventoryItem.name))
			else
				xPlayer.showNotification(TranslateCap('quantity_invalid'))
			end
		else
			xPlayer.showNotification(TranslateCap('quantity_invalid'))
		end
	end)
end)

RegisterNetEvent('esx_policejob:putStockItems')
AddEventHandler('esx_policejob:putStockItems', function(itemName, count)
	local xPlayer = ESX.Player(source)
	local sourceItem = xPlayer.getInventoryItem(itemName)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		local inventoryItem = inventory.getItem(itemName)

		-- does the player have enough of the item?
		if sourceItem.count >= count and count > 0 then
			xPlayer.removeInventoryItem(itemName, count)
			inventory.addItem(itemName, count)
			xPlayer.showNotification(TranslateCap('have_deposited', count, inventoryItem.name))
		else
			xPlayer.showNotification(TranslateCap('quantity_invalid'))
		end
	end)
end)

ESX.RegisterServerCallback('esx_policejob:getOtherPlayerData', function(source, cb, target, notify)
	local xPlayer = ESX.Player(target)
	local job = xPlayer.getJob()
	if notify then
		xPlayer.showNotification(TranslateCap('being_searched'))
	end

	if xPlayer then
		local data = {
			name = xPlayer.getName(),
			job = job.label,
			grade = job.grade_label,
			inventory = xPlayer.getInventory(),
			accounts = xPlayer.getAccounts(),
			weapons = xPlayer.getLoadout()
		}

		if Config.EnableESXIdentity then
			data.dob = xPlayer.get('dateofbirth')
			data.height = xPlayer.get('height')

			if xPlayer.get('sex') == 'm' then data.sex = 'male' else data.sex = 'female' end
		end

		TriggerEvent('esx_status:getStatus', target, 'drunk', function(status)
			if status then
				data.drunk = ESX.Math.Round(status.percent)
			end
		end)

		if Config.EnableLicenses then
			TriggerEvent('esx_license:getLicenses', target, function(licenses)
				data.licenses = licenses
				cb(data)
			end)
		else
			cb(data)
		end
	end
end)

local fineList = {}
ESX.RegisterServerCallback('esx_policejob:getFineList', function(source, cb, category)
	if not fineList[category] then
		MySQL.query('SELECT * FROM fine_types WHERE category = ?', {category},
		function(fines)
			fineList[category] = fines

			cb(fines)
		end)
	else
		cb(fineList[category])
	end
end)


ESX.RegisterServerCallback('esx_policejob:getVehicleInfos', function(source, cb, plate)
	local retrivedInfo = {
		plate = plate
	}
	if Config.EnableESXIdentity then
		MySQL.single('SELECT users.firstname, users.lastname FROM owned_vehicles JOIN users ON owned_vehicles.owner = users.identifier WHERE plate = ?', {plate},
		function(result)
			if result then
				retrivedInfo.owner = ('%s %s'):format(result.firstname, result.lastname)
			end
			cb(retrivedInfo)
		end)
	else
		MySQL.scalar('SELECT owner FROM owned_vehicles WHERE plate = ?', {plate},
		function(owner)
			if owner then
				local xPlayer = ESX.Player(owner)
				if xPlayer then
					retrivedInfo.owner = xPlayer.getName()
				end
			end
			cb(retrivedInfo)
		end)
	end
end)

ESX.RegisterServerCallback('esx_policejob:getArmoryWeapons', function(source, cb)
	TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
		local weapons = store.get('weapons')

		if weapons == nil then
			weapons = {}
		end

		cb(weapons)
	end)
end)

ESX.RegisterServerCallback('esx_policejob:addArmoryWeapon', function(source, cb, weaponName, removeWeapon)
	local xPlayer = ESX.Player(source)

	if removeWeapon then
		xPlayer.removeWeapon(weaponName)
	end

	TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
		local weapons = store.get('weapons') or {}
		local foundWeapon = false

		for i=1, #weapons, 1 do
			if weapons[i].name == weaponName then
				weapons[i].count = weapons[i].count + 1
				foundWeapon = true
				break
			end
		end

		if not foundWeapon then
			table.insert(weapons, {
				name  = weaponName,
				count = 1
			})
		end

		store.set('weapons', weapons)
		cb()
		end)
end)

ESX.RegisterServerCallback('esx_policejob:removeArmoryWeapon', function(source, cb, weaponName)
	local xPlayer = ESX.Player(source)
	xPlayer.addWeapon(weaponName, 500)

	TriggerEvent('esx_datastore:getSharedDataStore', 'society_police', function(store)
		local weapons = store.get('weapons') or {}

		local foundWeapon = false

		for i=1, #weapons, 1 do
			if weapons[i].name == weaponName then
				weapons[i].count = (weapons[i].count > 0 and weapons[i].count - 1 or 0)
				foundWeapon = true
				break
			end
		end

		if not foundWeapon then
			table.insert(weapons, {
				name = weaponName,
				count = 0
			})
		end

		store.set('weapons', weapons)
		cb()
	end)
end)

ESX.RegisterServerCallback('esx_policejob:buyWeapon', function(source, cb, weaponName, type, componentNum)
	local xPlayer = ESX.Player(source)
	local authorizedWeapons, selectedWeapon = Config.AuthorizedWeapons[xPlayer.getJob().grade_name]

	for k,v in ipairs(authorizedWeapons) do
		if v.weapon == weaponName then
			selectedWeapon = v
			break
		end
	end

	if not selectedWeapon then
		print(('[^3WARNING^7] Player ^5%s^7 Attempted To Buy Invalid Weapon - ^5%s^7!'):format(source, weaponName))
		cb(false)
	else
		-- Weapon
		if type == 1 then
			if xPlayer.getMoney() >= selectedWeapon.price then
				xPlayer.removeMoney(selectedWeapon.price, "Weapon Bought")
				xPlayer.addWeapon(weaponName, 100)

				cb(true)
			else
				cb(false)
			end

		-- Weapon Component
		elseif type == 2 then
			local price = selectedWeapon.components[componentNum]
			local weaponNum, weapon = ESX.GetWeapon(weaponName)
			local component = weapon.components[componentNum]

			if component then
				if xPlayer.getMoney() >= price then
					xPlayer.removeMoney(price, "Weapon Component Bought")
					xPlayer.addWeaponComponent(weaponName, component.name)

					cb(true)
				else
					cb(false)
				end
			else
				print(('[^3WARNING^7] Player ^5%s^7 Attempted To Buy Invalid Weapon Component - ^5%s^7!'):format(source, componentNum))
				cb(false)
			end
		end
	end
end)


ESX.RegisterServerCallback('esx_policejob:getOwnedJobVehicleModels', function(source, cb, type)
    local xPlayer = ESX.Player(source)
    local job = xPlayer.getJob()

    MySQL.query(('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND job IN %s AND type = ?'):format(YA_POLICE_JOB_IN), {
        xPlayer.getIdentifier(), type or 'car'
    }, function(result)
        local models = {}

        for i = 1, #(result or {}) do
            local props = json.decode(result[i].vehicle or '{}')
            if props and props.model then
                models[#models + 1] = props.model
            end
        end

        cb(models)
    end)
end)

ESX.RegisterServerCallback('esx_policejob:buyJobVehicle', function(source, cb, vehicleProps, type)
    local xPlayer = ESX.Player(source)
    local job = xPlayer.getJob()
    local price = getPriceFromHash(vehicleProps.model, job.grade_name, type)

    if price == 0 then
        print(('[^3WARNING^7] Player ^5%s^7 Attempted To Buy Invalid Vehicle - ^5%s^7!'):format(source, vehicleProps.model))
        cb(false)
        return
    end

    local ownedVehicles = MySQL.query.await(('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND job IN %s AND type = ?'):format(YA_POLICE_JOB_IN), {
        xPlayer.getIdentifier(), type or 'car'
    }) or {}

    for i = 1, #ownedVehicles do
        local props = json.decode(ownedVehicles[i].vehicle or '{}')
        if props and tostring(props.model) == tostring(vehicleProps.model) then
            xPlayer.showNotification('Du ejer allerede dette tjenestekøretøj.')
            cb(false)
            return
        end
    end

    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price, "Job Vehicle Bought")

        MySQL.insert('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (?, ?, ?, ?, ?, ?)', {
            xPlayer.getIdentifier(), json.encode(vehicleProps), vehicleProps.plate, type or 'car', PoliceJobs.canonical, true
        }, function()
            cb(true)
        end)
    else
        cb(false)
    end
end)


RegisterNetEvent('esx_policejob:setJobVehicleState', function(plate, stored)
    local source = source
    local xPlayer = ESX.Player(source)
    local job = xPlayer.getJob()

    MySQL.update(('UPDATE owned_vehicles SET `stored` = ? WHERE owner = ? AND plate = ? AND job IN %s'):format(YA_POLICE_JOB_IN), {
        stored and true or false,
        xPlayer.getIdentifier(),
        plate,
    })
end)

ESX.RegisterServerCallback('esx_policejob:retrieveJobVehicles', function(source, cb, type)
    local xPlayer = ESX.Player(source)
    local job = xPlayer.getJob()

    MySQL.query(('SELECT * FROM owned_vehicles WHERE owner = ? AND job IN %s AND type = ? AND `stored` = ?'):format(YA_POLICE_JOB_IN), {
        xPlayer.getIdentifier(), type or 'car', true
    }, function(result)
        cb(result or {})
    end)
end)

ESX.RegisterServerCallback('esx_policejob:storeNearbyVehicle', function(source, cb, payload)
	local xPlayer = ESX.Player(source)
	local job = xPlayer.getJob()
	local identifier = xPlayer.getIdentifier()

	local plates = payload
	local propsByPlate = {}
	if type(payload) == 'table' and payload.plates then
		plates = payload.plates
		propsByPlate = payload.propsByPlate or {}
	end

	local plate = MySQL.scalar.await(('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate IN (?) AND job IN %s'):format(YA_POLICE_JOB_IN), {identifier, plates})

	if plate then
		local vehicleJson = nil
		if propsByPlate[plate] then
			vehicleJson = json.encode(propsByPlate[plate])
		end

		if vehicleJson then
			MySQL.update(('UPDATE owned_vehicles SET `stored` = true, vehicle = ? WHERE owner = ? AND plate = ? AND job IN %s'):format(YA_POLICE_JOB_IN), {vehicleJson, identifier, plate},
			function(rowsChanged)
				if rowsChanged == 0 then cb(false) else cb(plate) end
			end)
		else
			MySQL.update(('UPDATE owned_vehicles SET `stored` = true WHERE owner = ? AND plate = ? AND job IN %s'):format(YA_POLICE_JOB_IN), {identifier, plate},
			function(rowsChanged)
				if rowsChanged == 0 then cb(false) else cb(plate) end
			end)
		end
	else
		cb(false)
	end
end)

function getPriceFromHash(vehicleHash, jobGrade, type)
   local vehicles = Config.AuthorizedVehicles[type]?[jobGrade] or {}

	for i = 1, #vehicles do
		local vehicle = vehicles[i]
		if GetHashKey(vehicle.model) == vehicleHash then
			return vehicle.price
		end
	end

	return 0
end

ESX.RegisterServerCallback('esx_policejob:getStockItems', function(source, cb)
	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_police', function(inventory)
		cb(inventory.items)
	end)
end)

ESX.RegisterServerCallback('esx_policejob:getPlayerInventory', function(source, cb)
	local xPlayer = ESX.Player(source)
	local items   = xPlayer.getInventory(false)

	cb({items = items})
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		TriggerEvent('esx_phone:removeNumber', 'police')
	end
end)

local function getPolicePlayer(source)
    return ESX.Player(source) or (ESX.GetPlayerFromId and ESX.GetPlayerFromId(source))
end

RegisterNetEvent('esx_policejob:retrieveAndSpawnJobVehicle', function(vehicleProps, type, spawnPoint)
    local source = source
    local xPlayer = getPolicePlayer(source)
    if not xPlayer or not vehicleProps or not vehicleProps.plate or not spawnPoint then return end

    local job = xPlayer.getJob()
    local plate = vehicleProps.plate

    local result = MySQL.single.await(('SELECT vehicle FROM owned_vehicles WHERE owner = ? AND plate = ? AND job IN %s AND type = ? AND stored = 1'):format(YA_POLICE_JOB_IN), {
        xPlayer.getIdentifier(), plate, type or 'car'
    })

    if not result then
        xPlayer.showNotification('Tjenestekøretøjet er ikke gemt i garagen.')
        return
    end

    local savedProps = json.decode(result.vehicle or '{}') or vehicleProps
    if savedProps.model then
        vehicleProps.model = savedProps.model
    end
    vehicleProps.plate = savedProps.plate or plate

    local targetProps = vehicleProps
    if savedProps and savedProps.plate then
        targetProps = savedProps
        if vehicleProps.model then targetProps.model = vehicleProps.model end
    end

    MySQL.update.await(('UPDATE owned_vehicles SET stored = 0, vehicle = ? WHERE owner = ? AND plate = ? AND job IN %s'):format(YA_POLICE_JOB_IN), {
        json.encode(targetProps), xPlayer.getIdentifier(), plate
    })

    local spawn = vector3(tonumber(spawnPoint.x), tonumber(spawnPoint.y), tonumber(spawnPoint.z))
    local heading = tonumber(spawnPoint.heading) or 0.0

    ESX.OneSync.SpawnVehicle(targetProps.model, spawn, heading, targetProps, function(netId)
        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle and vehicle ~= 0 then
            Wait(250)
            TaskWarpPedIntoVehicle(GetPlayerPed(source), vehicle, -1)
            Entity(vehicle).state:set('yaJobVehicle', true, true)
            TriggerClientEvent('esx_policejob:client:protectJobVehicle', source, netId)
            if targetProps.policeExtras then
                TriggerClientEvent('ya_workshop:client:applyPoliceExtras', -1, netId, targetProps.policeExtras)
            end
        end
    end)
end)
