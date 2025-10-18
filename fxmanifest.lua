fx_version 'cerulean'
game 'gta5'

name "kt_interim job"
author "kitotake"
description 'Système d\'intérim complet avec ox_lib et ox_inventory'
version '1.1.0'

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

-- CORRECTION: Dépendances optionnelles pour les frameworks
dependencies {
    'ox_lib',
    'ox_inventory',
}

-- Dépendances optionnelles (ne cause pas d'erreur si absentes)
optional_dependencies {
    'oxmysql',
    'es_extended',
    'oxmysql'
}

client_export 'IsJobActive'
client_export 'GetActiveJob'
client_export 'CancelJob'

server_export 'GetServerUtils'

server_export'ValidateConstructionJob'
server_export'ValidateCleaningJob'
server_export'ValidateDeliveryJob'
server_export'ValidateShopLogisticsJob'
server_export'ValidateTaxiJob'
server_export'ValidateTruckerJob'
server_export'GetPlayerReputation'
server_export'GetDynamicReward'