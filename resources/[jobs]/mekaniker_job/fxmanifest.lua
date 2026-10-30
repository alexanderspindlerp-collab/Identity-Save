fx_version 'cerulean'
game 'gta5'

name 'mekaniker_job'
description 'Tynd wrapper — ESX mekaniker + ya_workshop'
version '1.0.0'
lua54 'yes'

shared_script 'config.lua'

client_script 'client/main.lua'

dependencies {
    'es_extended',
    'ya_workshop',
}
