fx_version 'cerulean'
game 'gta5'

name 'lex_chopshop'
description ''
author 'Lextr'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'qb-core',
    'ox_lib',
    'ox_inventory'
}