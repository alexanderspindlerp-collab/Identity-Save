fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'iddrugnsale'
author 'Yannick'
description 'Narko farm, omdanning og NPC-salg (Hash, Skunk, Kokain)'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/drugs.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'server/drugs.lua',
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

dependencies {
    'es_extended',
    'oxmysql',
    'ox_inventory',
    'ox_lib',
}

-- ya_skilltree er valgfri (gadesalg-bonus uden den)
