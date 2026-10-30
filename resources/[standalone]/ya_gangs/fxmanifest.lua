fx_version 'cerulean'
game 'gta5'

name 'ya_gangs'
author 'YA'
description 'Bande-system — orgs, territorier, turf og tablet-app'
version '1.0.0'
lua54 'yes'

shared_scripts {
    'config.lua'
}

ui_page 'web/turf-hud.html'

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'web/turf-hud.html',
    'web/css/turf-hud.css',
    'web/css/gang.css',
    'web/js/turf-hud.js',
    'web/lib/leaflet.js',
    'web/lib/leaflet.css',
    'web/js/gang-map.js',
    'web/js/gang-app.js'
}

dependencies {
    'es_extended',
    'oxmysql',
    'ya_tablet'
}

client_exports {
    'ReportTurfSale'
}

server_exports {
    'GetPlayerOrg',
    'AddOrgXP',
    'IsOrgLocked',
    'RegisterTurfSale',
    'GetTabletData'
}
