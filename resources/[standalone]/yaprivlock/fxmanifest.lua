fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'yaprivlock'
author 'coachn / ChatGPT'
description 'Stable ESX vehicle lock + trunk via ox_target'
version '10.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'ox_inventory'
}
