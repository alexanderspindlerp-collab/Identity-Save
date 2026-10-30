fx_version 'cerulean'

game 'gta5'



name 'ya_tablet'

author 'YA'

description 'Tablet-shell med App Store og app-registrering'

version '1.2.9'

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

    'web/css/gang.css',

    'web/css/gang-skilltree.css',

    'web/lib/leaflet.js',

    'web/lib/leaflet.css',

    'web/js/app.js',

    'web/js/gang-map.js',

    'web/js/gang-skilltree.js',

    'web/img/gangs_admin.png',

    'web/img/*.jpg',

    'web/img/*.png',

    'web/img/*.jpeg',

    'web/img/*.webp'

}



dependencies {

    'es_extended',

    'oxmysql',

    'ox_inventory'

}



client_exports {

    'useTablet',

    'Open',

    'Close'

}



server_exports {

    'RegisterApp',

    'InstallAppForIdentifier',

    'RefreshPlayer'

}

