
local spawnedVehicles = {}

function OpenVehicleSpawnerMenu(type, station, part, partNum)
	local playerCoords = GetEntityCoords(PlayerPedId())
	local elements = {
		{unselectable = true, icon = "fas fa-car", title = TranslateCap('garage_title')},
		{icon = "fas fa-car", title = TranslateCap('garage_storeditem'), action = 'garage'},
		{icon = "fas fa-car", title = TranslateCap('garage_storeitem'), action = 'store_garage'},
		{icon = "fas fa-car", title = TranslateCap('garage_buyitem'), action = 'buy_vehicle'}
	}

	ESX.OpenContext("right", elements, function(menu,element)
		if element.action == "buy_vehicle" then
			local shopElements = {}
			local shopCoords = Config.PoliceStations[station][part][partNum].InsideShop
			local authorizedVehicles = Config.AuthorizedVehicles[type][ESX.PlayerData.job.grade_name]

			if authorizedVehicles then
				if #authorizedVehicles > 0 then
					for k,vehicle in ipairs(authorizedVehicles) do
						if IsModelInCdimage(vehicle.model) then
							local vehicleLabel = GetLabelText(GetDisplayNameFromVehicleModel(vehicle.model))

							shopElements[#shopElements+1] = {
								icon = 'fas fa-car',
								title = ('%s - <span style="color:green;">%s</span>'):format(vehicleLabel, TranslateCap('shop_item', ESX.Math.GroupDigits(vehicle.price))),
								name  = vehicleLabel,
								model = vehicle.model,
								price = vehicle.price,
								props = vehicle.props,
								type  = type
							}
						end
					end

					if #shopElements > 0 then
						OpenShopMenu(shopElements, playerCoords, shopCoords)
					else
						ESX.ShowNotification(TranslateCap('garage_notauthorized'))
					end
				else
					ESX.ShowNotification(TranslateCap('garage_notauthorized'))
				end
			else
				ESX.ShowNotification(TranslateCap('garage_notauthorized'))
			end
		elseif element.action == "garage" then
			local foundSpawn, spawnPoint = GetAvailableVehicleSpawnPoint(station, part, partNum)

			if foundSpawn then
				ESX.CloseContext()

				exports['esx_garage']:OpenJobGarage(type, {
					x = spawnPoint.coords.x,
					y = spawnPoint.coords.y,
					z = spawnPoint.coords.z,
					heading = spawnPoint.heading
				})
			end
		elseif element.action == "store_garage" then
			StoreNearbyVehicle(playerCoords)
		end
	end)
end


function OpenPoliceVehicleBuyMenu(type, station, part, partNum)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local shopElements = {}
    local shopCoords = Config.PoliceStations[station][part][partNum].InsideShop
    local job = ESX.PlayerData.job

    if not job or not IsPoliceJob(job.name) then
        ESX.ShowNotification('Du er ikke politi.')
        return
    end

    local authorizedVehicles = Config.AuthorizedVehicles[type][job.grade_name]

    if authorizedVehicles and #authorizedVehicles > 0 then
        for _, vehicle in ipairs(authorizedVehicles) do
            if IsModelInCdimage(vehicle.model) then
                local vehicleLabel = GetLabelText(GetDisplayNameFromVehicleModel(vehicle.model))

                shopElements[#shopElements + 1] = {
                    icon = 'fas fa-car',
                    title = ('%s - <span style="color:green;">%s</span>'):format(vehicleLabel, TranslateCap('shop_item', ESX.Math.GroupDigits(vehicle.price))),
                    name  = vehicleLabel,
                    model = vehicle.model,
                    price = vehicle.price,
                    props = vehicle.props,
                    type  = type
                }
            end
        end
    end

    if #shopElements > 0 then
        OpenShopMenu(shopElements, playerCoords, shopCoords)
    else
        ESX.ShowNotification(TranslateCap('garage_notauthorized'))
    end
end

local function getNearestPoliceVehicleSpawner()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestStation, closestPart, closestPartNum, closestDistance

    for stationName, station in pairs(Config.PoliceStations) do
        if station.Vehicles then
            for i = 1, #station.Vehicles do
                local distance = #(playerCoords - station.Vehicles[i].Spawner)
                if not closestDistance or distance < closestDistance then
                    closestStation = stationName
                    closestPart = 'Vehicles'
                    closestPartNum = i
                    closestDistance = distance
                end
            end
        end
    end

    if closestStation and closestDistance <= 5.0 then
        return closestStation, closestPart, closestPartNum, closestDistance
    end

    return nil, nil, nil, closestDistance
end

exports('IsNearPoliceVehicleSpawner', function()
    return getNearestPoliceVehicleSpawner() ~= nil
end)

exports('OpenNearestPoliceVehicleShop', function()
    local station, part, partNum = getNearestPoliceVehicleSpawner()

    if not station then
        ESX.ShowNotification('Du er ikke tæt på politiets garage.')
        return
    end

    OpenPoliceVehicleBuyMenu('car', station, part, partNum)
end)

RegisterNetEvent('esx_policejob:openNearestVehicleShop', function()
    exports['esx_policejob']:OpenNearestPoliceVehicleShop()
end)

function StoreNearbyVehicle(playerCoords)
	local vehicles, plates, index = ESX.Game.GetVehiclesInArea(playerCoords, 30.0), {}, {}

	if next(vehicles) then
		for i = 1, #vehicles do
			local vehicle = vehicles[i]
			
			-- Make sure the vehicle we're saving is empty, or else it won't be deleted
			if GetVehicleNumberOfPassengers(vehicle) == 0 and IsVehicleSeatFree(vehicle, -1) then
				local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
				plates[#plates + 1] = plate
				index[plate] = vehicle
			end
		end
	else
		ESX.ShowNotification(TranslateCap('garage_store_nearby'))
		return
	end

	ESX.TriggerServerCallback('esx_policejob:storeNearbyVehicle', function(plate)
		if plate then
			local vehicleId = index[plate]
			local attempts = 0
			ESX.Game.DeleteVehicle(vehicleId)
			local isBusy = true

			CreateThread(function()
				BeginTextCommandBusyspinnerOn('STRING')
				AddTextComponentSubstringPlayerName(TranslateCap('garage_storing'))
				EndTextCommandBusyspinnerOn(4)

				while isBusy do
					Wait(100)
				end

				BusyspinnerOff()
			end)

			-- Workaround for vehicle not deleting when other players are near it.
			while DoesEntityExist(vehicleId) do
				Wait(500)
				attempts = attempts + 1

				-- Give up
				if attempts > 30 then
					break
				end

				vehicles = ESX.Game.GetVehiclesInArea(playerCoords, 30.0)
				if #vehicles > 0 then
					for i = 1, #vehicles do
						local vehicle = vehicles[i]
						if ESX.Math.Trim(GetVehicleNumberPlateText(vehicle)) == plate then
							ESX.Game.DeleteVehicle(vehicle)
							break
						end
					end
				end
			end

			isBusy = false
			ESX.ShowNotification(TranslateCap('garage_has_stored'))
		else
			ESX.ShowNotification(TranslateCap('garage_has_notstored'))
		end
	end, plates)
end

function GetAvailableVehicleSpawnPoint(station, part, partNum)
	local spawnPoints = Config.PoliceStations[station][part][partNum].SpawnPoints
	local found, foundSpawnPoint = false, nil

	for i=1, #spawnPoints, 1 do
		if ESX.Game.IsSpawnPointClear(spawnPoints[i].coords, spawnPoints[i].radius) then
			found, foundSpawnPoint = true, spawnPoints[i]
			break
		end
	end

	if found then
		return true, foundSpawnPoint
	else
		ESX.ShowNotification(TranslateCap('vehicle_blocked'))
		return false
	end
end

function OpenShopMenu(elements, restoreCoords, shopCoords)
	local playerPed = PlayerPedId()
	isInShopMenu = true
	ESX.OpenContext("right", elements, function(menu,element)
		local elements2 = {
			{unselectable = true, icon = "fas fa-car", title = element.title},
			{icon = "fas fa-eye", title = TranslateCap('view'), value = "view"},
			{icon = "fas fa-check-double", title = TranslateCap('buy_car'), value = "buy"}
		}

		ESX.OpenContext("right", elements2, function(menu2,element2)
			if element2.value == "buy" then
				local newPlate = exports['ya_cardealer']:GeneratePlate()
				local props = element.props or {}
				props.model = joaat(element.model)
				props.plate = newPlate

				ESX.TriggerServerCallback('esx_policejob:buyJobVehicle', function (bought)
					if bought then
						ESX.ShowNotification(TranslateCap('vehicleshop_bought', element.name, ESX.Math.GroupDigits(element.price)))
						isInShopMenu = false
						ESX.CloseContext()
					else
						ESX.ShowNotification(TranslateCap('vehicleshop_money'))
					end
				end, props, element.type)
			elseif element2.value == "view" then
				DeleteSpawnedVehicles()
				WaitForVehicleToLoad(element.model)

				ESX.Game.SpawnLocalVehicle(element.model, shopCoords, 0.0, function(vehicle)
					table.insert(spawnedVehicles, vehicle)
					TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
					FreezeEntityPosition(vehicle, true)
					SetModelAsNoLongerNeeded(element.model)

					if element.props then
						ESX.Game.SetVehicleProperties(vehicle, element.props)
					end
				end)

				local elements3 = {
					{unselectable = true, icon = "fas fa-car", title = element.title},
					{icon = "fas fa-check-double", title = TranslateCap('buy_car'), value = "buy"},
					{icon = "fas fa-eye", title = TranslateCap('stop_view'), value = "stop"}
				}

				ESX.OpenContext("right", elements3, function(menu3,element3)
					if element3.value == 'stop' then
						isInShopMenu = false
						ESX.CloseContext()

						DeleteSpawnedVehicles()
						FreezeEntityPosition(playerPed, false)
						SetEntityVisible(playerPed, true)

						ESX.Game.Teleport(playerPed, restoreCoords)
					elseif element3.value == "buy" then
						local newPlate = exports['ya_cardealer']:GeneratePlate()
						local vehicle  = GetVehiclePedIsIn(playerPed, false)
						local props    = ESX.Game.GetVehicleProperties(vehicle)
						props.plate    = newPlate

						ESX.TriggerServerCallback('esx_policejob:buyJobVehicle', function (bought)
							if bought then
								ESX.ShowNotification(TranslateCap('vehicleshop_bought', element.name, ESX.Math.GroupDigits(element.price)))

								isInShopMenu = false
								ESX.CloseContext()
								DeleteSpawnedVehicles()
								FreezeEntityPosition(playerPed, false)
								SetEntityVisible(playerPed, true)

								ESX.Game.Teleport(playerPed, restoreCoords)
							else
								ESX.ShowNotification(TranslateCap('vehicleshop_money'))
								ESX.CloseContext()
							end
						end, props, element.type)
					end
				end, function()
					isInShopMenu = false
					ESX.CloseContext()

					DeleteSpawnedVehicles()
					FreezeEntityPosition(playerPed, false)
					SetEntityVisible(playerPed, true)

					ESX.Game.Teleport(playerPed, restoreCoords)
				end)
			end
		end)
	end)
end


CreateThread(function()
	while true do
		Wait(0)

		if isInShopMenu then
			DisableControlAction(0, 75, true)  -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle
		else
			Wait(500)
		end
	end
end)

function DeleteSpawnedVehicles()
	while #spawnedVehicles > 0 do
		local vehicle = spawnedVehicles[1]
		ESX.Game.DeleteVehicle(vehicle)
		table.remove(spawnedVehicles, 1)
	end
end

function WaitForVehicleToLoad(modelHash)
	modelHash = (type(modelHash) == 'number' and modelHash or joaat(modelHash))

	if not HasModelLoaded(modelHash) then
		RequestModel(modelHash)

		BeginTextCommandBusyspinnerOn('STRING')
		AddTextComponentSubstringPlayerName(TranslateCap('vehicleshop_awaiting_model'))
		EndTextCommandBusyspinnerOn(4)

		while not HasModelLoaded(modelHash) do
			Wait(0)
			DisableAllControlActions(0)
		end

		BusyspinnerOff()
	end
end

-- YA F3 interaction exports -------------------------------------------------
local function getAuthorizedPoliceVehiclesForNearestShop(type)
    type = type or 'car'

    local station, part, partNum = getNearestPoliceVehicleSpawner()
    if not station then
        return nil, 'not_near'
    end

    local job = ESX.PlayerData and ESX.PlayerData.job
    if not job or not IsPoliceJob(job.name) then
        return nil, 'not_police'
    end

    local authorizedVehicles = Config.AuthorizedVehicles[type] and Config.AuthorizedVehicles[type][job.grade_name]
    if not authorizedVehicles or #authorizedVehicles == 0 then
        return {}, nil
    end

    local vehicles = {}
    for _, vehicle in ipairs(authorizedVehicles) do
        if IsModelInCdimage(vehicle.model) then
            local label = GetLabelText(GetDisplayNameFromVehicleModel(vehicle.model))
            if label == 'NULL' then label = vehicle.model end

            vehicles[#vehicles + 1] = {
                name = label,
                model = vehicle.model,
                price = vehicle.price or 0,
                props = vehicle.props or {},
                type = type
            }
        end
    end

    return vehicles, nil, station, part, partNum
end

exports('GetNearestPoliceVehicleShopOptions', function()
    local vehicles, reason = getAuthorizedPoliceVehiclesForNearestShop('car')

    if reason == 'not_near' then
        ESX.ShowNotification('Du er ikke tæt på politiets garage.')
    elseif reason == 'not_police' then
        ESX.ShowNotification('Du er ikke politi.')
    end

    return vehicles or {}
end)

exports('BuyNearestPoliceVehicle', function(model)
    local vehicles = getAuthorizedPoliceVehiclesForNearestShop('car')
    if not vehicles or #vehicles == 0 then
        ESX.ShowNotification(TranslateCap('garage_notauthorized'))
        return
    end

    local selected
    for i = 1, #vehicles do
        if tostring(vehicles[i].model) == tostring(model) then
            selected = vehicles[i]
            break
        end
    end

    if not selected then
        ESX.ShowNotification(TranslateCap('garage_notauthorized'))
        return
    end

    local newPlate = exports['ya_cardealer']:GeneratePlate()
    local props = selected.props or {}
    props.model = joaat(selected.model)
    props.plate = newPlate

    ESX.TriggerServerCallback('esx_policejob:buyJobVehicle', function(bought)
        if bought then
            ESX.ShowNotification(TranslateCap('vehicleshop_bought', selected.name, ESX.Math.GroupDigits(selected.price)))
        else
            ESX.ShowNotification(TranslateCap('vehicleshop_money'))
        end
    end, props, selected.type or 'car')
end)

exports('OpenNearestPoliceJobGarage', function()
    local station, part, partNum = getNearestPoliceVehicleSpawner()

    if not station then
        ESX.ShowNotification('Du er ikke tæt på politiets garage.')
        return
    end

    local foundSpawn, spawnPoint = GetAvailableVehicleSpawnPoint(station, part, partNum)
    if not foundSpawn then
        ESX.ShowNotification(TranslateCap('vehicle_blocked'))
        return
    end

    exports['esx_garage']:OpenJobGarage('car', {
        x = spawnPoint.coords.x,
        y = spawnPoint.coords.y,
        z = spawnPoint.coords.z,
        heading = spawnPoint.heading
    })
end)



local function getPoliceGarageSpawnPoint(station, part, partNum)
    local spawnPoints = Config.PoliceStations[station][part][partNum].SpawnPoints or {}

    for i = 1, #spawnPoints do
        if ESX.Game.IsSpawnPointClear(spawnPoints[i].coords, spawnPoints[i].radius or 3.0) then
            return spawnPoints[i], true
        end
    end

    -- UI'et skal stadig kunne åbne, selv hvis spawnpointet lige nu er blokeret.
    -- Når spilleren trykker Retrieve, tjekker esx_garage igen og viser besked hvis den er blokeret.
    return spawnPoints[1], false
end

exports('OpenNearestPoliceGarageUI', function()
    local station, part, partNum = getNearestPoliceVehicleSpawner()

    if not station then
        ESX.ShowNotification('Du er ikke tæt på politiets garage.')
        return
    end

    local spawnPoint = getPoliceGarageSpawnPoint(station, part, partNum)
    if not spawnPoint then
        ESX.ShowNotification(TranslateCap('vehicle_blocked'))
        return
    end

    local shopVehicles = exports['esx_policejob']:GetNearestPoliceVehicleShopOptions() or {}

    exports['esx_garage']:OpenPoliceGarage('car', {
        x = spawnPoint.coords.x,
        y = spawnPoint.coords.y,
        z = spawnPoint.coords.z,
        heading = spawnPoint.heading
    }, shopVehicles)
end)

RegisterNetEvent('esx_policejob:openNearestPoliceGarageUI', function()
    exports['esx_policejob']:OpenNearestPoliceGarageUI()
end)

exports('StoreCurrentPoliceVehicle', function()
    local playerPed = PlayerPedId()

    if not IsPedInAnyVehicle(playerPed, false) then
        ESX.ShowNotification('Du skal sidde i et køretøj for at parkere.')
        return
    end

    if not getNearestPoliceVehicleSpawner() then
        ESX.ShowNotification('Du er ikke tæt på politiets garage.')
        return
    end

    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
    local props = ESX.Game.GetVehicleProperties(vehicle)
    if GetResourceState('ya_workshop') == 'started' then
        props = exports.ya_workshop:CapturePoliceVehicleProps(vehicle, props)
    end

    ESX.TriggerServerCallback('esx_policejob:storeNearbyVehicle', function(storedPlate)
        if storedPlate then
            TaskLeaveVehicle(playerPed, vehicle, 0)
            Wait(750)
            ESX.Game.DeleteVehicle(vehicle)
            ESX.ShowNotification(TranslateCap('garage_has_stored'))
        else
            ESX.ShowNotification(TranslateCap('garage_has_notstored'))
        end
    end, {
        plates = { plate },
        propsByPlate = { [plate] = props },
    })
end)

RegisterNetEvent('esx_policejob:storeCurrentPoliceVehicle', function()
    exports['esx_policejob']:StoreCurrentPoliceVehicle()
end)

RegisterNetEvent('esx_policejob:client:protectJobVehicle', function(netId)
    netId = tonumber(netId)
    if not netId then return end

    CreateThread(function()
        local deadline = GetGameTimer() + 10000
        while GetGameTimer() < deadline do
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
                SetEntityAsMissionEntity(vehicle, true, true)
                SetVehicleHasBeenOwnedByPlayer(vehicle, true)
                SetVehicleNeedsToBeHotwired(vehicle, false)
                return
            end
            Wait(100)
        end
    end)
end)
