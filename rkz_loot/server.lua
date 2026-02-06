local lootedPeds = {}

RegisterNetEvent("loot:checkLooted", function(netId)
    local src = source
    local alreadyLooted = lootedPeds[netId] or false
    TriggerClientEvent("loot:receiveLootStatus", src, netId, alreadyLooted)
end)

RegisterNetEvent("loot:giveLoot", function(netId, pedType)
    local src = source

    if lootedPeds[netId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Loot',
            description = 'This body has already been looted.',
            type = 'error'
        })
        return
    end

    lootedPeds[netId] = true

    local lootTable = getLootTable(pedType)
    local loot = getRandomLoot(lootTable)
    if not loot then return end

    local amount = math.random(loot.min, loot.max)
    local success = exports.ox_inventory:AddItem(src, loot.item, amount)

    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Loot',
            description = 'You found ' .. amount .. 'x ' .. loot.item,
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Loot',
            description = 'Failed to add item: ' .. loot.item,
            type = 'error'
        })
    end
end)

function getLootTable(pedType)
    if pedType == "cop" then
        return {
            {item = "pistol_ammo", min = 10, max = 20, chance = 70},
            {item = "kevlar", min = 1, max = 1, chance = 30}
        }
    elseif pedType == "gang" then
        return {
            {item = "lockpick", min = 1, max = 2, chance = 50},
            {item = "joint", min = 1, max = 3, chance = 50}
        }
    else
        return {
             {item = "money", min = 50, max = 200, chance = 60}, 
             {item = "bandage", min = 1, max = 2, chance = 60},
             {item = "ammo-9", min = 5, max = 15, chance = 30},
             {item = "lockpick", min = 1, max = 1, chance = 8},
             {item = "goldbar", min = 1, max = 1, chance = 5},
             {item = "WEAPON_PISTOL", min = 1, max = 1, chance = 1}
        }
    end
end

function getRandomLoot(table)
    local roll = math.random(1, 100)
    local cumulative = 0

    for _, loot in ipairs(table) do
        cumulative = cumulative + loot.chance
        if roll <= cumulative then
            return loot
        end
    end

    return nil
end