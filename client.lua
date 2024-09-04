local isInsideGarage = false
local currentGarageIndex = nil
local lootedSpots = {}
local garageStates = {}

local function lootGarage(location)
    lootedSpots = {}

    for i, lootSpot in ipairs(Config.LootSpots) do
        exports.qtarget:AddBoxZone("loot_spot_"..i, lootSpot, 1.0, 1.0, {
            name = "loot_spot_"..i,
            heading = 0,
            debugPoly = false,
            minZ = lootSpot.z - 1,
            maxZ = lootSpot.z + 1
        }, {
            options = {
                {
                    icon = "fas fa-box-open",
                    label = "Vykradnúť",
                    action = function(entity)
                        if not lootedSpots[i] then
                            if lib.progressBar({
                                duration = 5000,
                                label = 'Vykrádam spot...',
                                useWhileDead = false,
                                canCancel = true,
                                disable = {
                                    car = true,
                                    move = true,
                                },
                                anim = {
                                    dict = 'mini@repair',
                                    clip = 'fixing_a_ped'
                                },
                            }) then
                                lootedSpots[i] = true
                                TriggerEvent('garage:loot', lootSpot)
                            else
                                lib.notify({
                                    title = 'Vykrádanie zrušené',
                                    description = 'Neuspel si pri vykrádaní.',
                                    type = 'error'
                                })
                            end
                        else
                            lib.notify({
                                title = 'Spot už vykradnutý',
                                description = 'Tento spot už bol vykradnutý.',
                                type = 'error'
                            })
                        end
                    end,
                    canInteract = function()
                        return isInsideGarage and not lootedSpots[i]
                    end,
                },
            },
            distance = 1.5
        })
    end

    exports.qtarget:AddBoxZone("garage_interior_exit_"..location, Config.GarageLocations[location].interior, 1.0, 1.0, {
        name = "garage_interior_exit_"..location,
        heading = 0,
        debugPoly = false,
        minZ = Config.GarageLocations[location].interior.z - 1,
        maxZ = Config.GarageLocations[location].interior.z + 1
    }, {
        options = {
            {
                icon = "fas fa-door-closed",
                label = "Opustiť garáž",
                action = function(entity)
                    TriggerEvent('garage:exit', {location = location})
                end,
                canInteract = function()
                    return isInsideGarage
                end,
            },
        },
        distance = 1.5
    })
end


local function tryLockpickGarage(index)
    if exports.ox_inventory:Search('count', 'lockpick') > 0 then
        if garageStates[index] and garageStates[index] == "open" then
            TriggerEvent('garage:enter', {location = index})
            return
        end

        local success = exports['lockpick']:startLockpick()

        if success then
            currentGarageIndex = index

            local data = exports['cd_dispatch']:GetPlayerInfo()
            TriggerServerEvent('cd_dispatch:AddNotification', {
                job_table = {'police',}, 
                coords = data.coords,
                title = '10-15 - Garážová lúpež',
                message = 'A '..data.sex..' osoba sa pokúša vykradnúť garáž na '..data.street, 
                flash = 0,
                unique_id = data.unique_id,
                sound = 1,
                blip = {
                    sprite = 431, 
                    scale = 1.2, 
                    colour = 3,
                    flashes = false, 
                    text = '911 - Garážová lúpež',
                    time = 5,
                    radius = 0,
                }
            })

            garageStates[index] = "open"
            TriggerEvent('garage:enter', {location = index})

            Citizen.SetTimeout(10 * 60 * 1000, function()
                garageStates[index] = "closed"
            end)
        else
            lib.notify({
                title = 'Lockpick zlyhal',
                description = 'Skús to znova.',
                type = 'error'
            })
        end
    else
        lib.notify({
            title = 'Chýba ti lockpick',
            description = 'Potrebujete lockpick na otvorenie garáže.',
            type = 'error'
        })
    end
end

RegisterNetEvent('garage:enter')
AddEventHandler('garage:enter', function(data)
    isInsideGarage = true
    local instanceName = 'garage_' .. data.location
    TriggerServerEvent("instance:joinInstance", instanceName)

    SetEntityCoords(PlayerPedId(), Config.GarageLocations[data.location].interior)
    lootGarage(data.location)
    lib.notify({
        title = 'Vstúpil si do garáže',
        description = 'Môžeš začať vykrádať spoty.',
        type = 'success'
    })
end)

RegisterNetEvent('garage:exit')
AddEventHandler('garage:exit', function(data)
    isInsideGarage = false
    SetEntityCoords(PlayerPedId(), Config.GarageLocations[data.location].entry)

    TriggerServerEvent("instance:quitInstance")

    lib.notify({
        title = 'Opustil si garáž',
        description = 'Úspešne si opustil garáž.',
        type = 'success'
    })
end)

RegisterNetEvent('garage:loot')
AddEventHandler('garage:loot', function(lootSpot)
    local lootRoll = math.random(1, 100)

    for _, loot in ipairs(Config.LootItems) do
        if lootRoll <= loot.chance then
            local amount = math.random(loot.minAmount, loot.maxAmount)
            TriggerServerEvent('garage:giveLoot', loot.item, amount, currentGarageIndex)
            lib.notify({
                title = 'Získal si loot',
                description = 'Našiel si '..amount..'x '..loot.item..'.',
                type = 'success'
            })
            break
        end
    end
end)

for index, garage in ipairs(Config.GarageLocations) do
    exports.qtarget:AddBoxZone("garage_entry_"..index, garage.entry, 1.0, 1.0, {
        name = "garage_entry_"..index,
        heading = 0,
        debugPoly = false,
        minZ = garage.entry.z - 1,
        maxZ = garage.entry.z + 1
    }, {
        options = {
            {
                icon = "fas fa-door-open",
                label = "Použiť lockpick",
                action = function(entity)
                    tryLockpickGarage(index)
                end,
                canInteract = function()
                    return not isInsideGarage
                end,
            },
        },
        distance = 1.5
    })
end
