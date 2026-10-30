fx_version 'cerulean'
game 'gta5'

name 'ya_test_npc'
author 'Yannick / YA'
description 'Test-borger — ligner en spiller til interaktionstest (politi, stoffer m.m.)'
version '1.8.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/state.lua',
    'client/interactions.lua',
    'client/targets.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'es_extended',
    'ox_target',
    'ox_lib',
    'ya_police_interactions',
}

client_exports {
    'IsTestNpc',
    'GetTestNpcPed',
    'RunPoliceAction',
    'IsTestNpcHandcuffed',
}

server_exports {
    'GetTestNpcNetId',
    'IsTestNpcNetId',
}
