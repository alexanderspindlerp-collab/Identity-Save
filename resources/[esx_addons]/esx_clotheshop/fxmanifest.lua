fx_version 'cerulean'

game 'gta5'

description 'ESX Clotheshop - modern NUI reskin'
version '2.0.0-modern'
legacyversion '1.13.4'

lua54 'yes'

shared_script '@es_extended/imports.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'server/main.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua',
    'client/main.lua'
}

dependencies {
    'es_extended',
    'esx_skin',
    'skinchanger'
}
