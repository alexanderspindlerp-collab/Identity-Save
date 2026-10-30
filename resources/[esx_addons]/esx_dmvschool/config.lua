Config                 = {}
Config.DrawDistance    = 10.0
Config.MaxErrors       = 5
Config.SpeedMultiplier = 3.6
Config.SpeedingErrorDelay = 5000 --Min: 5000ms
Config.Locale = GetConvar('esx:locale', 'da')

Config.Prices = {
	dmv         = 500,
	drive       = 2500,
	drive_bike  = 3000,
	drive_truck = 5000
}

Config.VehicleModels = {
	drive       = 'blista',
	drive_bike  = 'sanchez',
	drive_truck = 'mule3'
}

Config.SpeedLimits = {
	residence = 50,
	town      = 80,
	freeway   = 120
}

Config.Zones = {

	DMVSchool = {
		Pos   = {x = 239.471, y = -1380.960, z = 32.741},
		Size  = {x = 1.5, y = 1.5, z = 1.0},
		Color = {r = 204, g = 204, b = 0},
		Type  = 1
	},

	VehicleSpawnPoint = {
		Pos   = {x = 249.409, y = -1407.230, z = 30.4094, h = 317.0},
		Size  = {x = 1.5, y = 1.5, z = 1.0},
		Color = {r = 204, g = 204, b = 0},
		Type  = -1
	}

}

Config.CheckPoints = {
	{
		Pos = {x = 244.04, y = -1402.13, z = 30.59},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			setCurrentZoneType('residence')
			DrawMissionText(TranslateCap('next_point_speed', Config.SpeedLimits['residence']), 5000)
		end
	},

	{
		Pos = {x = 237.03, y = -1344.42, z = 31.88},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText(TranslateCap('go_next_point'), 5000)
		end
	},

	{
		Pos = {x = 222.49, y = -1405.34, z = 29.68},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			setCurrentZoneType('town')
			DrawMissionText(TranslateCap('in_town_speed', Config.SpeedLimits['town']), 5000)
		end
	},

	{
		Pos = {x = 183.44, y = -1394.18, z = 29.23},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText(TranslateCap('go_next_point'), 5000)
		end
	},

	{
		Pos = {x = 217.32, y = -1331.34, z = 29.24},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText(TranslateCap('go_next_point'), 5000)
		end
	},

	{
		Pos = {x = 328.35, y = -1318.71, z = 32.03},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText(TranslateCap('go_next_point'), 5000)
		end
	},

	{
		Pos = {x = 254.75, y = -965.26, z = 29.32},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText('Til venstre kan du se midtbyen', 5000)
		end
	},

	{
		Pos = {x = 396.10, y = -989.04, z = 29.30},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText(TranslateCap('go_next_point'), 5000)
		end
	},

	{
		Pos = {x = 420.00, y = -1613.48, z = 29.18},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText('Bliver dit køretøj beslaglagt kan du få det ud til højre ved impound', 5000)
		end
	},

	{
		Pos = {x = 127.38, y = -1720.75, z = 29.17},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText('Har du brug for en ny frisure kan du tjekke salonen ud til højre', 5000)
		end
	},

	{
		Pos = {x = -362.34, y = -1821.34, z = 22.65},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			setCurrentZoneType('freeway')
			DrawMissionText(TranslateCap('hway_time', Config.SpeedLimits['freeway']), 5000)
			PlaySound(-1, 'RACE_PLACED', 'HUD_AWARDS', false, 0, true)
		end
	},

	{
		Pos = {x = -1037.85, y = -2727.28, z = 20.10},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText('Det her sted husker du nok, det er her vores nyeste borgere kommer fra!', 5000)
		end
	},

	{
		Pos = {x = -505.44, y = -2149.07, z = 8.99},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			setCurrentZoneType('town')
			DrawMissionText(TranslateCap('in_town_speed', Config.SpeedLimits['town']), 5000)
		end
	},

	{
		Pos = {x = -2.63, y = -395.70, z = 39.44},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText('Her er hospitalet, hvis du kommer til skade', 5000)
		end
	},

	{
		Pos = {x = 233.86, y = -1400.41, z = 30.54},
		Action = function(playerPed, vehicle, setCurrentZoneType)
			DrawMissionText('Tillykke, du har gennemført køreprøven!', 5000)
			ESX.Game.DeleteVehicle(vehicle)
		end
	}
}