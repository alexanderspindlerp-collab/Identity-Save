fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'San MDT'
description 'Job MDT base for ESX - police first build'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
    'config.charges.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/css/app.css',
    'nui/js/app.js',
    'nui/img/*.png',
    'nui/img/*.jpg',
    'nui/img/*.jpeg',
    'nui/img/*.webp',
    'nui/img/dlk_tiles/*.png'
}

server_exports {
    'AuditLog',
    'GetMapImageSources',
    'CheckAnpgPlate',
    'SyncAnpgFromIncident',
    'SyncAllReportsAnpg',
    'FlagPlateAnpg',
    'FlagPersonAnpg',
    'GetAnpgPlateStatus',
}

-- screenshot-basic er valgfrit. Hvis det er startet, kan dispatch-detaljer vise vidnefoto.
