fx_version 'cerulean'
game 'gta5'

author 'YA'
description 'Standalone F1 interaction menu'
version '2.0.5'
lua54 'yes'

ui_page 'web/ui.html'

files {
    'web/ui.html',
    'web/css/app.css',
    'web/js/app.js'
}

client_scripts {
    'config.lua',
    'client/main.lua'
}


dependencies {
    'es_extended',
    'ya_skilltree'
}
