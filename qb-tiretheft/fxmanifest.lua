fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'ILYAS'
description 'QB tire theft with drill, trunk storage, and buyer interaction'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-target',
    'interact',
    'progressbar'
}
