fx_version 'cerulean'
game 'gta5'

name 'speedradar'
author 'ChatGPT'
description 'Fartkontrols Udstyr til ox_inventory + ox_target + ESX'
version '14.0.0'

lua54 'yes'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'stream/*.ydr',
    'stream/*.ytd',
    'stream/*.ytyp'
}

data_file 'DLC_ITYP_REQUEST' 'stream/*.ytyp'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'ox_inventory',
    'ox_target'
}
