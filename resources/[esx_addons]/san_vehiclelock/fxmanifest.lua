fx_version 'adamant'

game 'gta5'

description 'NPC Car Lock System von ModernLifeRP'

author 'zImSkillz'

lua54 'yes'
version '1.0.0'

shared_scripts { 
	'@es_extended/imports.lua',
	'@es_extended/locale.lua'
}


server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'Server/Server.lua'
}

client_scripts {
	'Client/Client.lua'
}

dependencies {
	'es_extended'
}

--[[
- Created by zImSkillz
- Created at 21:22 GMT+1
- DD/MM/YYYY
- 26.11.2022
]]--