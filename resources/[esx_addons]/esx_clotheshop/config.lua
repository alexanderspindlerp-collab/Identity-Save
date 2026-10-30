Config = {}
Config.Locale = GetConvar('esx:locale', 'en')

Config.Price = 250
Config.ChargePerPiece = false

Config.DrawDistance = 10.0
Config.MarkerSize   = {x = 1.5, y = 1.5, z = 1.0}
Config.MarkerColor  = {r = 102, g = 102, b = 204}
Config.MarkerType   = 1

Config.Shops = {
	vector3(72.3, -1399.1, 28.4),
	vector3(-703.8, -152.3, 36.4),
	vector3(-167.9, -299.0, 38.7),
	vector3(428.7, -800.1, 28.5),
	vector3(-829.4, -1073.7, 10.3),
	vector3(-1447.8, -242.5, 48.8),
	vector3(11.6, 6514.2, 30.9),
	vector3(123.6, -219.4, 53.6),
	vector3(1696.3, 4829.3, 41.1),
	vector3(618.1, 2759.6, 41.1),
	vector3(1190.6, 2713.4, 37.2),
	vector3(-1193.4, -772.3, 16.3),
	vector3(-3172.5, 1048.1, 19.9),
	vector3(-1108.4, 2708.9, 18.1)
}

Config.SkinProps = {
	'tshirt','torso', 'decals', 'arms', 'pants',
	'shoes', 'bags', 'chain', 'helmet', 'glasses',
	'watches'
}
-- Modern NUI clothing shop
Config.UseModernUI = true
Config.PayAccount = 'money' -- money / bank
Config.EnableControlsHelp = true

Config.ModernCategories = {
    { id = 'torso', label = 'Tøj', icon = '👕', drawable = 'torso_1', texture = 'torso_2' },
    { id = 'tshirt', label = 'T-Shirt', icon = '👔', drawable = 'tshirt_1', texture = 'tshirt_2' },
    { id = 'arms', label = 'Arme', icon = '💪', drawable = 'arms', texture = 'arms_2' },
    { id = 'pants', label = 'Bukser', icon = '👖', drawable = 'pants_1', texture = 'pants_2' },
    { id = 'shoes', label = 'Sko', icon = '👟', drawable = 'shoes_1', texture = 'shoes_2' },
    { id = 'bags', label = 'Tasker', icon = '🎒', drawable = 'bags_1', texture = 'bags_2' },
    { id = 'chain', label = 'Tilbehør', icon = '🔗', drawable = 'chain_1', texture = 'chain_2' },
    { id = 'helmet', label = 'Hjelme', icon = '🪖', drawable = 'helmet_1', texture = 'helmet_2' },
    { id = 'glasses', label = 'Briller', icon = '👓', drawable = 'glasses_1', texture = 'glasses_2' },
    { id = 'watches', label = 'Ure', icon = '⌚', drawable = 'watches_1', texture = 'watches_2' },
}
