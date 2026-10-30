fx_version 'cerulean'
game 'gta5'

name 'ya_cardealer'
author 'YA'
description 'Firma-baseret bilforhandler via tablet (erstatter esx_vehicleshop)'
version '1.2.0'
lua54 'yes'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/plates.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/employee.lua',
}

dependencies {
    'es_extended',
    'oxmysql',
    'ya_tablet',
}

client_exports {
    'GeneratePlate',
}

server_exports {
    'GetDealershipForIdentifier',
    'InstallAppForIdentifier',
}
