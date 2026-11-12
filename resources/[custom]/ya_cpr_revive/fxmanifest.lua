fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ya_cpr_revive'
description 'CPR genoplivning af døde spillere via ox_target (5 forsøg)'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'ox_lib',
    'ox_target',
    'es_extended',
    'esx_ambulancejob'
}
