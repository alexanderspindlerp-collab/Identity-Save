local CurrentAction     = nil
local CurrentActionMsg  = nil
local CurrentActionData = nil
local Licenses          = {}
local CurrentTest       = nil
local CurrentTestType   = nil
local CurrentVehicle    = nil
local CurrentCheckPoint, DriveErrors = 0, 0
local LastCheckPoint    = -1
local CurrentBlip       = nil
local CurrentZoneType   = nil
local LastVehicleHealth = nil
local failedTest = false

function DrawMissionText(msg, time)
	ClearPrints()
	BeginTextCommandPrint('STRING')
	AddTextComponentSubstringPlayerName(msg)
	EndTextCommandPrint(time, true)
end

function StartTheoryTest()
	CurrentTest = 'theory'

	SendNUIMessage({
		openQuestion = true
	})

	ESX.SetTimeout(200, function()
		SetNuiFocus(true, true)
	end)


end

function StopTheoryTest(success)
	CurrentTest = nil

	SendNUIMessage({
		openQuestion = false
	})

	SetNuiFocus(false)

	if success then
		TriggerServerEvent('esx_dmvschool:addLicense', 'dmv')
		ESX.ShowNotification(TranslateCap('passed_test'))
	else
		ESX.ShowNotification(TranslateCap('failed_test'))
	end
end

function StartDriveTest(type)
	local model = Config.VehicleModels[type]

	if not model then
		print(('[esx_dmvschool] Missing vehicle model for license type: %s'):format(tostring(type)))
		ESX.ShowNotification(TranslateCap('spawn_failed'))
		return
	end

	local spawn = Config.Zones.VehicleSpawnPoint.Pos
	local spawnCoords = vector3(spawn.x, spawn.y, spawn.z)
	local heading = spawn.h or 0.0
	local modelHash = joaat(model)
	local playerPed = PlayerPedId()

	-- OneSync fix:
	-- Nogle servere åbner NUI/menuen mens spilleren ikke er streamet tæt nok på spawnpunktet.
	-- Så fejler ESX/FiveM med: "position is too far away (Out of onesync range)".
	-- Vi flytter derfor spilleren til spawnområdet først og venter på collision, FØR køretøjet oprettes.
	local playerCoords = GetEntityCoords(playerPed)
	if #(playerCoords - spawnCoords) > 45.0 then
		DoScreenFadeOut(250)
		Wait(300)
		SetEntityCoordsNoOffset(playerPed, spawn.x, spawn.y, spawn.z, false, false, false)
		SetEntityHeading(playerPed, heading)
		RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)

		local collisionTimeout = GetGameTimer() + 5000
		while not HasCollisionLoadedAroundEntity(playerPed) and GetGameTimer() < collisionTimeout do
			RequestCollisionAtCoord(spawn.x, spawn.y, spawn.z)
			Wait(50)
		end

		Wait(250)
		DoScreenFadeIn(250)
	end

	if not IsModelInCdimage(modelHash) or not IsModelAVehicle(modelHash) then
		print(('[esx_dmvschool] Invalid vehicle model: %s'):format(tostring(model)))
		ESX.ShowNotification(TranslateCap('spawn_failed'))
		return
	end

	local function setupVehicle(vehicle)
		if not vehicle or not DoesEntityExist(vehicle) then
			ESX.ShowNotification(TranslateCap('spawn_failed'))
			return
		end

		CurrentTest       = 'drive'
		CurrentTestType   = type
		CurrentCheckPoint = 0
		LastCheckPoint    = -1
		CurrentZoneType   = 'residence'
		DriveErrors       = 0
		IsAboveSpeedLimit = false
		CurrentVehicle    = vehicle
		LastVehicleHealth = GetEntityHealth(vehicle)
		failedTest = false

		local playerPed = PlayerPedId()
		SetEntityCoordsNoOffset(vehicle, spawn.x, spawn.y, spawn.z, false, false, false)
		SetEntityHeading(vehicle, heading)
		SetVehicleOnGroundProperly(vehicle)
		SetEntityAsMissionEntity(vehicle, true, true)
		SetVehicleEngineOn(vehicle, true, true, false)
		TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		SetVehicleFuelLevel(vehicle, 100.0)
		if DecorIsRegisteredAsType and DecorIsRegisteredAsType("_FUEL_LEVEL", 1) then
			DecorSetFloat(vehicle, "_FUEL_LEVEL", GetVehicleFuelLevel(vehicle))
		end

		ESX.ShowNotification(('Køreprøve startet: %s'):format(type == 'drive_bike' and 'motorcykel' or type == 'drive_truck' and 'lastbil' or 'bil'))
	end

	-- ESX.Game.SpawnVehicle kan fejle på nogle ESX/FiveM builds uden at give fejl.
	-- Derfor bruger vi native spawn som fallback, så spilleren ikke bare betaler uden prøve.
	RequestModel(modelHash)
	local timeout = GetGameTimer() + 5000
	while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
		Wait(10)
	end

	if not HasModelLoaded(modelHash) then
		ESX.ShowNotification(TranslateCap('spawn_failed'))
		return
	end

	local vehicle = CreateVehicle(modelHash, spawn.x, spawn.y, spawn.z, heading, true, false)
	SetModelAsNoLongerNeeded(modelHash)
	setupVehicle(vehicle)
end

function StopDriveTest(success)
	if success then
		TriggerServerEvent('esx_dmvschool:addLicense', CurrentTestType)
		ESX.ShowNotification(TranslateCap('passed_test'))
		ESX.ShowNotification(TranslateCap('driving_test_complete'))
	else
		ESX.ShowNotification(TranslateCap('failed_test'))
	end

	CurrentTest     = nil
	CurrentTestType = nil
end

function SetCurrentZoneType(type)
CurrentZoneType = type
end

function BuildDMVCategories(licenses)
	local ownedLicenses = {}

	for i=1, #(licenses or {}), 1 do
		ownedLicenses[licenses[i].type] = true
	end

	local categories = {}

	-- Teori skal kun vises, hvis spilleren IKKE allerede har bestået den.
	if not ownedLicenses['dmv'] then
		categories[#categories+1] = {
			id = 'dmv',
			type = 'theory',
			icon = 'book-open',
			title = 'Teoriprøve',
			description = 'Tag den teoretiske prøve én gang for at låse kørekort kategorierne op.',
			price = Config.Prices['dmv'],
			available = true,
			completed = false
		}
	else
		if not ownedLicenses['drive'] then
			categories[#categories+1] = {
				id = 'drive',
				type = 'drive',
				icon = 'car',
				title = 'Bil Kørekort',
				description = 'Tag kørekort til almindelig bil (B kategori).',
				price = Config.Prices['drive'],
				available = true,
				completed = false
			}
		end

		if not ownedLicenses['drive_bike'] then
			categories[#categories+1] = {
				id = 'drive_bike',
				type = 'drive',
				icon = 'bike',
				title = 'Motorcykel Kørekort',
				description = 'Tag kørekort til motorcykel (A kategori).',
				price = Config.Prices['drive_bike'],
				available = true,
				completed = false
			}
		end

		if not ownedLicenses['drive_truck'] then
			categories[#categories+1] = {
				id = 'drive_truck',
				type = 'drive',
				icon = 'truck',
				title = 'Lastbil Kørekort',
				description = 'Tag kørekort til lastbil (C kategori).',
				price = Config.Prices['drive_truck'],
				available = true,
				completed = false
			}
		end
	end

	return categories, ownedLicenses
end

function OpenDMVSchoolMenu()
	-- Hent licenser direkte fra serveren hver gang menuen åbnes.
	-- Så slipper man for at tage teori igen efter den allerede er bestået.
	ESX.TriggerServerCallback('esx_dmvschool:getLicenses', function(licenses)
		Licenses = licenses or {}
		local categories, ownedLicenses = BuildDMVCategories(Licenses)

		SetNuiFocus(true, true)
		SendNUIMessage({
			action = 'openSchool',
			theoryPassed = ownedLicenses['dmv'] == true,
			categories = categories
		})
	end)
end

RegisterNUICallback('schoolClose', function(data, cb)
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'closeSchool' })
	CurrentAction     = 'dmvschool_menu'
	CurrentActionMsg  = TranslateCap('press_open_menu')
	CurrentActionData = {}
	cb('ok')
end)

local function HandleSchoolPurchase(data, cb)
	local licenseType = data.id or data.license or data.typeId
	local testType = data.type or data.testType

	if not licenseType then
		print('[esx_dmvschool] NUI purchase failed: missing license id')
		if cb then cb({ ok = false, error = 'missing_license' }) end
		return
	end

	if licenseType == 'dmv' then
		testType = 'theory'
	elseif not testType then
		testType = 'drive'
	end

	ESX.TriggerServerCallback('esx_dmvschool:canYouPay', function(haveMoney)
		if haveMoney then
			SetNuiFocus(false, false)
			SendNUIMessage({ action = 'closeSchool' })

			CreateThread(function()
				Wait(150)
				if testType == 'theory' or licenseType == 'dmv' then
					StartTheoryTest()
				else
					StartDriveTest(licenseType)
				end
			end)
		else
			ESX.ShowNotification(TranslateCap('not_enough_money'))
			SendNUIMessage({ action = 'schoolPaymentFailed' })
		end

		if cb then cb({ ok = haveMoney }) end
	end, licenseType)
end

RegisterNUICallback('schoolSelect', function(data, cb)
	HandleSchoolPurchase(data or {}, cb)
end)

RegisterNUICallback('confirmPurchase', function(data, cb)
	HandleSchoolPurchase(data or {}, cb)
end)

RegisterNUICallback('selectLicense', function(data, cb)
	HandleSchoolPurchase(data or {}, cb)
end)

RegisterNUICallback('question', function(data, cb)
	SendNUIMessage({
		openSection = 'question'
	})

	cb()
end)

RegisterNUICallback('close', function(data, cb)
	StopTheoryTest(true)
	cb()
end)

RegisterNUICallback('kick', function(data, cb)
	StopTheoryTest(false)
	cb()
end)

AddEventHandler('esx_dmvschool:hasEnteredMarker', function(zone)
	if zone == 'DMVSchool' then
		CurrentAction     = 'dmvschool_menu'
		CurrentActionMsg  = TranslateCap('press_open_menu')
		CurrentActionData = {}
	end
end)

AddEventHandler('esx_dmvschool:hasExitedMarker', function(zone)
	CurrentAction = nil
	ESX.CloseContext()
	SetNuiFocus(false, false)
	SendNUIMessage({ action = 'closeSchool' })
end)

RegisterNetEvent('esx_dmvschool:loadLicenses')
AddEventHandler('esx_dmvschool:loadLicenses', function(licenses)
	Licenses = licenses
end)

-- Create Blips
CreateThread(function()
	local blip = AddBlipForCoord(Config.Zones.DMVSchool.Pos.x, Config.Zones.DMVSchool.Pos.y, Config.Zones.DMVSchool.Pos.z)

	SetBlipSprite (blip, 408)
	SetBlipColour (blip, 0)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.2)
	SetBlipAsShortRange(blip, true)

	BeginTextCommandSetBlipName("STRING")
	AddTextComponentSubstringPlayerName(TranslateCap('driving_school_blip'))
	EndTextCommandSetBlipName(blip)
end)

-- Display markers
CreateThread(function()
	while true do
		local sleep = 1500
		local playerPed = PlayerPedId()
		local coords = GetEntityCoords(playerPed)

		for k,v in pairs(Config.Zones) do
			local Pos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
			if(v.Type ~= -1 and #(coords - Pos) < Config.DrawDistance) then
				sleep = 0
				DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
			end
		end

		if CurrentTest == 'theory' then
			
			sleep = 0
			DisableControlAction(0, 1, true) -- LookLeftRight
			DisableControlAction(0, 2, true) -- LookUpDown
			DisablePlayerFiring(playerPed, true) -- Disable weapon firing
			DisableControlAction(0, 142, true) -- MeleeAttackAlternate
			DisableControlAction(0, 106, true) -- VehicleMouseControlOverride
		end

		if CurrentTest == 'drive' then
			sleep = 0
			local nextCheckPoint = CurrentCheckPoint + 1

			if Config.CheckPoints[nextCheckPoint] == nil then
				if DoesBlipExist(CurrentBlip) then
					RemoveBlip(CurrentBlip)
				end

				CurrentTest = nil
				StopDriveTest(DriveErrors < Config.MaxErrors)
			else
				if CurrentCheckPoint ~= LastCheckPoint then
					if DoesBlipExist(CurrentBlip) then
						RemoveBlip(CurrentBlip)
					end

					CurrentBlip = AddBlipForCoord(Config.CheckPoints[nextCheckPoint].Pos.x, Config.CheckPoints[nextCheckPoint].Pos.y, Config.CheckPoints[nextCheckPoint].Pos.z)
					SetBlipRoute(CurrentBlip, 1)

					LastCheckPoint = CurrentCheckPoint
				end
            
				local Pos = vector3(Config.CheckPoints[nextCheckPoint].Pos.x,Config.CheckPoints[nextCheckPoint].Pos.y,Config.CheckPoints[nextCheckPoint].Pos.z)
				local distance = #(coords - Pos)
            
				if distance <= Config.DrawDistance then
					DrawMarker(1, Config.CheckPoints[nextCheckPoint].Pos.x, Config.CheckPoints[nextCheckPoint].Pos.y, Config.CheckPoints[nextCheckPoint].Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, 1.5, 1.5, 1.5, 102, 204, 102, 100, false, true, 2, false, false, false, false)
				end

				if distance <= 3.0 then
					Config.CheckPoints[nextCheckPoint].Action(playerPed, CurrentVehicle, SetCurrentZoneType)
					CurrentCheckPoint = CurrentCheckPoint + 1
				end
			end
		end

		if CurrentAction then
			sleep = 0
			ESX.ShowHelpNotification(CurrentActionMsg)

			if (IsControlJustReleased(0, 38)) and (CurrentAction == 'dmvschool_menu') then
				OpenDMVSchoolMenu()
				CurrentAction = nil
			end
		end
		
		local isInMarker  = false
		local currentZone = nil

		for k,v in pairs(Config.Zones) do
			local Pos = vector3(v.Pos.x, v.Pos.y, v.Pos.z)
			if(#(coords - Pos) < v.Size.x) then
				sleep = 0
				isInMarker  = true
				currentZone = k
			end
		end

		if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
			HasAlreadyEnteredMarker = true
			LastZone                = currentZone
			TriggerEvent('esx_dmvschool:hasEnteredMarker', currentZone)
		end

		if not isInMarker and HasAlreadyEnteredMarker then
			HasAlreadyEnteredMarker = false
			TriggerEvent('esx_dmvschool:hasExitedMarker', LastZone)
		end
		Wait(sleep)
	end
end)


function TestFailedGoToLastCheckPoint()
	CurrentCheckPoint = #Config.CheckPoints - 1
	failedTest = true
end

-- Speed / Damage control
CreateThread(function()
	while true do
		local sleep = 1500
		if CurrentTest == 'drive' then
			sleep = 0
			local playerPed = PlayerPedId()
			
			if IsPedInAnyVehicle(playerPed, false) then
				local vehicle = GetVehiclePedIsIn(playerPed, false)
				local speed = GetEntitySpeed(vehicle) * Config.SpeedMultiplier
				local health = GetEntityHealth(vehicle)

				-- Speed check
				for k, v in pairs(Config.SpeedLimits) do

					if CurrentZoneType == k and speed > v then
						DriveErrors += 1

						if DriveErrors <= Config.MaxErrors then
							ESX.ShowNotification(TranslateCap('driving_too_fast', v))
							ESX.ShowNotification(TranslateCap('errors', DriveErrors, Config.MaxErrors))
						end

						sleep = (Config.SpeedingErrorDelay < 5000) and 5000 or Config.SpeedingErrorDelay
					end
				end

				-- Vehicle damage check
				if health < LastVehicleHealth then
					DriveErrors += 1
					if DriveErrors <= Config.MaxErrors then
						ESX.ShowNotification(TranslateCap('you_damaged_veh'))
						ESX.ShowNotification(TranslateCap('errors', DriveErrors, Config.MaxErrors))
					end
					
					LastVehicleHealth = health
					sleep = 1500
				end

				if DriveErrors > Config.MaxErrors then
					ESX.ShowNotification(TranslateCap('test_failed_go_to_start_point'))
					if not failedTest then
						TestFailedGoToLastCheckPoint()
					end
					sleep = 5000
				end
			end
		end
		Wait(sleep)
	end
end)

