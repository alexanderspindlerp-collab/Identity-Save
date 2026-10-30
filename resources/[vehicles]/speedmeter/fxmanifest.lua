fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'coachn / ChatGPT'
description 'Dansk politi speedradar + ANPG (san_mdt)'
version '2.0.0'

dependency 'san_mdt'

shared_scripts {
    '@es_extended/imports.lua',
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}
