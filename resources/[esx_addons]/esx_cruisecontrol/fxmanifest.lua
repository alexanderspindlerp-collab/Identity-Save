fx_version 'cerulean'
game 'gta5'

description 'ESX Legacy Speed Limiter - no auto acceleration, no seatbelt'

version '1.2-speedlimiter'
legacyversion '1.13.4'

lua54 'yes'

client_scripts {
  '@es_extended/imports.lua',
  '@es_extended/locale.lua',
  'locales/*.lua',
  'config.lua',
  'client/utils.lua',
  'client/cruisecontrol.lua',
  'client/keybind.lua',
  'client/seatbelt.lua'
}

dependencies {
  'es_extended'
}
