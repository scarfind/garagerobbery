fx_version 'cerulean'
game 'gta5'

description 'Vykradanie garazi'
author 'scarfind'
lua54 'yes'

shared_script {
    'config.lua',
    '@ox_lib/init.lua'
}

escrow_ignore {
    'config.lua'
} 

client_script 'client.lua'
server_script 'server.lua'


