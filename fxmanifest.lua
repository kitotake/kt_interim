fx_version 'cerulean'
game 'gta5'

name "kt_interim job"
author "kitotake"
description 'Système d\'intérim complet avec ox_lib et ox_inventory'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config_global.lua',
}

client_scripts {
    'client/utils.lua',
    'client/main.lua',
    'client/jobs.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/main.lua',
    'server/jobs.lua'
}


dependencies {
    'ox_lib',
    'ox_inventory',
    'oxmysql'
}

client_export 'IsJobActive'
client_export 'GetActiveJob'
client_export 'CancelJob'
