fx_version 'cerulean'
game 'gta5'
description 'Provides a way for players to RP as paramedics (heal/revive players)'
version '1.0.2'
legacyversion '1.13.4'
lua54 'yes'

shared_scripts {
	'@es_extended/imports.lua',
	'@es_extended/locale.lua',
	'locales/*.lua',
	'config.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/*.lua'
}

client_scripts {
	'client/deathcam.lua',
	'client/main.lua',
	'client/job.lua',
	'client/vehicle.lua'
}

dependencies {
	'oxmysql',
	'es_extended',
	'esx_context',
	'esx_skin',
	'esx_vehicleshop'
}
