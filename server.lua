ESX = exports["es_extended"]:getSharedObject()
local lastHeistTimes = {}

local garageCooldowns = {}
local garageStates = {}
local instances = {}
local instanceIndex = 0

RegisterNetEvent('garage:attemptLoot')
AddEventHandler('garage:attemptLoot', function(location)
    local player = source
    local xPlayer = ESX.GetPlayerFromId(player)

    if xPlayer and exports.ox_inventory:RemoveItem(player, Config.RequiredItem, 1) then
        TriggerClientEvent('garage:loot', player, location)
    else
        TriggerClientEvent('esx:showNotification', player, 'Nemáš lockpick!')
    end
end)


RegisterNetEvent('garage:giveLoot')
AddEventHandler('garage:giveLoot', function(item, amount)
    local player = source
    local playerCoords = GetEntityCoords(GetPlayerPed(player))
    local isAllowed = false
    local currentTime = os.time()

    if lastHeistTimes[player] and currentTime - lastHeistTimes[player] < 5 then
        DropPlayer(player, 'Příliš rýchle opakované vykrádanie. Pokus sa znova.')
        return
    end

    for _, lootSpot in ipairs(Config.LootSpots) do
        local distance = #(playerCoords - lootSpot)
        if distance <= 10.0 then
            isAllowed = true
            break
        end
    end

    if not isAllowed then
        DropPlayer(player, 'Připoj se znovu.')
        return
    end

    exports.ox_inventory:AddItem(player, item, amount)
    lastHeistTimes[player] = currentTime
end)


RegisterNetEvent("instance:addEntityToPlayerInstance")
AddEventHandler("instance:addEntityToPlayerInstance", function(entity)
    local _source = source
    SetEntityRoutingBucket(entity, GetPlayerRoutingBucket(_source))
end)

AddEventHandler("entityCreating", function(entity)
    local entityOwner = NetworkGetEntityOwner(entity)
    local entityOwnerBucket = GetPlayerRoutingBucket(entityOwner)

    if entityOwnerBucket ~= 0 then
        SetEntityRoutingBucket(entity, entityOwnerBucket)
    end
end)

RegisterNetEvent("instance:joinInstance")
AddEventHandler("instance:joinInstance", function(instance)
    local _source = source
    print(GetPlayerName(_source) .. ' is joining instance [' .. instance .. ']')
    playerJoinInstance(_source, instance)
end)

RegisterNetEvent("instance:quitInstance")
AddEventHandler("instance:quitInstance", function()
    local _source = source
    playerQuitInstance(_source)
end)

function getPlayerInstance(player)
    local playerRoutingBucket = GetPlayerRoutingBucket(player)

    if playerRoutingBucket == 0 then
        return ""
    end

    return instances[tostring(playerRoutingBucket)]
end

function getInstances()
    return instances
end

function playerJoinInstance(player, instanceName)
    local playerRoutingBucket = GetPlayerRoutingBucket(player)

    if instanceName == "" then
        if playerRoutingBucket ~= 0 then
            playerQuitInstance(player)
        end
        return
    end

    local instanceId = createInstanceIfNotExists(instanceName)

    playerRoutingBucket = GetPlayerRoutingBucket(player)
    if playerRoutingBucket == instanceId then
        return
    elseif playerRoutingBucket ~= 0 then
        playerQuitInstance(player)
    end

    SetPlayerRoutingBucket(player, instanceId)
    TriggerClientEvent("instance:onEnter", player, instanceName)

    if instanceId ~= 0 then
        SetRoutingBucketPopulationEnabled(instanceId, false)
    end
end

function playerQuitInstance(player)
    if GetPlayerRoutingBucket(player) ~= 0 then
        TriggerClientEvent("instance:onLeave", player)
    end

    SetPlayerRoutingBucket(player, 0)
end

AddEventHandler("playerDropped", function()
    local _source = source
    playerQuitInstance(_source)
end)

function getInstancePostalCode(instanceName)
    if string.starts(instanceName, "property-") then
        local propertyInfo = instanceName:sub(10)
        local propertyInfoSplit = {}

        for part in propertyInfo:gmatch("([^-]+)") do
            table.insert(propertyInfoSplit, part)
        end

        local propertyId = propertyInfoSplit[1]
        local roomId = propertyInfoSplit[3]

        local propertyDetails = exports.base_property:getPropertyData(propertyId)
        if propertyDetails then
            local coords = propertyDetails.coords
            local postalData = exports.nearest_postal:getNearestPostal(vec3(coords.x, coords.y, coords.z))
            return postalData, propertyDetails, roomId
        end
    elseif string.starts(instanceName, "house_") then
        local houseId = instanceName:sub(7)
        local houseDetails = exports.household:getHouseDetails(houseId)
        if houseDetails then
            local coords = houseDetails.coords
            local postalData = exports.nearest_postal:getNearestPostal(vec3(coords.x, coords.y, coords.z))
            return postalData, houseDetails
        end
    end

    return instanceName
end

function createInstanceIfNotExists(instanceName)
    for i, instance in pairs(instances) do
        if instance == instanceName then
            return tonumber(i)
        end
    end

    instanceIndex = instanceIndex + 1
    instances[tostring(instanceIndex)] = instanceName
    return instanceIndex
end

function string.starts(String, Start)
    return string.sub(String, 1, string.len(Start)) == Start
end
