Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

Config.DrawDistance = 15.0
Config.InteractionKey = 'F1'
Config.InteractionDistance = 5.0
Config.TextUiPosition = 'right-center'
Config.ShowMarkers = false

-- Admin garage editor (/setgarage)
Config.GarageEditor = {
	Enabled = true,
	AdminGroups = { 'admin', 'superadmin', 'owner' },
	AcePermission = 'command.setgarage',
	DefaultImpound = 'LosSantos',
	DefaultSprite = 357,
	DefaultScale = 0.8,
	DefaultColour = 3,
	RemoveDistance = 25.0,
}


-- YA F3 integration
-- false = garage kan kun åbnes/parkeres via ya_interactions F1 menuen.
Config.EnableBuiltInF3 = false
Config.ShowGaragePrompt = false
Config.GarageActionDuration = 3000

-- Ved server restart: ude-køretøjer (stored=0) sendes til sidste garage — ikke impound
Config.MoveOutVehiclesToImpoundOnStart = false
Config.MoveOutVehiclesToGarageOnStart = true
Config.DefaultRestartGarage = 'VespucciBoulevard'

-- Hvis en garage har SpawnPoints, vælger scriptet automatisk den første ledige plads.
-- Spilleren bliver warped direkte ind på førersædet, når bilen spawner.


Config.Markers = {
	EntryPoint = {
		Type = 21,
		Size = {
			x = 1.0,
			y = 1.0,
			z = 0.5,
		},
		Color = {
			r = 50,
			g = 200,
			b = 50,
		},
	},
	GetOutPoint = {
		Type = 21,
		Size = {
			x = 1.0,
			y = 1.0,
			z = 0.5,
		},
		Color = {
			r = 200,
			g = 51,
			b = 51,
		},
	},
}

Config.Garages = {
	VespucciBoulevard = {
		Label = 'Vespucci Boulevard Garage',
		EntryPoint = { x = -285.2, y = -886.5, z = 31.0 },
		SpawnPoint = { x = -309.12, y = -897.52, z = 30.90, heading = 70.0 },
		SpawnPoints = {
			{ x = -309.12, y = -897.52, z = 30.90, heading = 70.0 },
			{ x = -313.28, y = -897.39, z = 30.90, heading = 70.0 },
			{ x = -316.71, y = -896.11, z = 30.90, heading = 70.0 },
			{ x = -320.87, y = -895.37, z = 30.90, heading = 70.0 },
			{ x = -307.79, y = -883.00, z = 30.90, heading = 250.0 },
			{ x = -303.99, y = -883.57, z = 30.90, heading = 250.0 },
			{ x = -300.28, y = -884.41, z = 30.90, heading = 250.0 },
			{ x = -297.02, y = -885.09, z = 30.90, heading = 250.0 },
		},
		Sprite = 357,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "LosSantos",
	},
	SanAndreasAvenue = {
		Label = 'Midtby Garage / Pillbox Garage',
		EntryPoint = { x = 216.77, y = -788.77, z = 30.82 },
		SpawnPoint = { x = 223.95, y = -781.65, z = 30.58, heading = 250.0 },
		SpawnPoints = {
			{ x = 223.95, y = -781.65, z = 30.58, heading = 250.0 },
			{ x = 222.84, y = -784.21, z = 30.59, heading = 250.0 },
			{ x = 221.77, y = -786.75, z = 30.59, heading = 250.0 },
			{ x = 221.02, y = -789.26, z = 30.59, heading = 250.0 },
			{ x = 220.39, y = -792.06, z = 30.57, heading = 250.0 },
			{ x = 211.60, y = -785.84, z = 30.73, heading = 70.0 },
			{ x = 212.53, y = -783.44, z = 30.72, heading = 70.0 },
			{ x = 213.61, y = -780.96, z = 30.70, heading = 70.0 },
			{ x = 214.26, y = -778.47, z = 30.69, heading = 70.0 },
		},
		Sprite = 357,
		Scale = 0.8,
		Colour = 3,
		ImpoundedName = "LosSantos",
	},
}

Config.JobGarages = {
	MissionRowPolice = {
		Label = 'Mission Row Politi Garage',
		Job = 'police',
		EntryPoint = { x = 453.42, y = -1018.79, z = 28.42 },
		SpawnPoint = { x = 453.42, y = -1018.79, z = 28.42, heading = 297.60 },
		SpawnPoints = {
			{ x = 453.42, y = -1018.79, z = 28.42, heading = 297.60 },
		},
		Sprite = 357,
		Scale = 0.8,
		Colour = 38,
	},
}

Config.Impounds = {
	LosSantos = {
		GetOutPoint = {
			x = 400.7,
			y = -1630.5,
			z = 29.3,
		},
		SpawnPoint = {
			x = 401.9,
			y = -1647.4,
			z = 29.2,
			heading = 323.3,
		},
		Sprite = 524,
		Scale = 0.8,
		Colour = 1,
		Cost = 3000,
	},
	PaletoBay = {
		GetOutPoint = {
			x = -211.4,
			y = 6206.5,
			z = 31.4,
		},
		SpawnPoint = {
			x = -204.6,
			y = 6221.6,
			z = 30.5,
			heading = 227.2,
		},
		Sprite = 524,
		Scale = 0.8,
		Colour = 1,
		Cost = 3000,
	},
	SandyShores = {
		GetOutPoint = {
			x = 1728.2,
			y = 3709.3,
			z = 33.2,
		},
		SpawnPoint = {
			x = 1722.7,
			y = 3713.6,
			z = 33.2,
			heading = 19.9,
		},
		Sprite = 524,
		Scale = 0.8,
		Colour = 1,
		Cost = 3000,
	},
}

exports("getGarages", function()
	return Config.Garages
end)
exports("getImpounds", function()
	return Config.Impounds
end)
exports("getJobGarages", function()
	return Config.JobGarages
end)


-- Hvilke politi-grades må frigive permanent beslaglagte køretøjer.
-- Brug grade_name fra jobs_grades. Eksempler: boss/chief/lieutenant.
Config.PermanentImpoundReturnGrades = {
	rigspolitiet = true,
	['7'] = true
}
-- Kun Rigspolitiet/grade 7 må frigive permanent beslaglagte køretøjer.
Config.PermanentImpoundReturnMinGrade = 7
