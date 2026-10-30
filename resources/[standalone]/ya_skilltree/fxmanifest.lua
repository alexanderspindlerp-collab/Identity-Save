fx_version 'cerulean'
game 'gta5'

name 'ya_skilltree'
author 'YA'
description 'Unikt skilltree — dyrkning, produktion og salg'
version '1.0.0'
lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/style.css',
    'web/js/app.js'
}

dependencies {
    'es_extended',
    'oxmysql'
}

client_exports {
    'Open',
    'Close'
}

server_exports {
    'GetUnlockedSkills',
    'HasSkill',
    'GetCategoryEffects',
    'GetCriminalBonuses',
    'AwardPoints',
    'AddPoints'
}
