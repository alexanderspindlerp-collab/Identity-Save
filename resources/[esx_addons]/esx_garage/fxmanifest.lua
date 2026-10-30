fx_version 'cerulean'
game 'gta5'

author 'ESX-Framework'
description 'Allows Players to Store & Retrieve their vehicles'

version '1.3.0'
legacyversion '1.13.4'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua'
}

server_scripts { '@es_extended/locale.lua', 'locales/*.lua', '@oxmysql/lib/MySQL.lua', 'config.lua', 'server/main.lua', 'server/garage_editor.lua', 'server/tablet.lua' }

client_scripts { '@es_extended/locale.lua', 'locales/*.lua', 'config.lua', 'client/garage_editor.lua', 'client/main.lua' }

ui_page 'nui/ui.html'

files {'nui/ui.html', 'nui/js/*.js', 'nui/css/*.css', 'nui/img/*.png'}

dependency 'ox_lib'
