local lootedPeds = {}
local cooldowns = {}

-- Anti-spam cooldown
local function isOnCooldown(src)
    local now = os.time()
    if cooldowns[src] and cooldowns[src] > now then
        return true
    end
    cooldowns[src] = now + 3
    return false
end

-- Server-safe ped death check
local function isPedDeadServer(ped)
    if not ped or ped == 0 then return false end
    if not DoesEntityExist(ped) then return false end
    return GetEntityHealth(ped) <= 0
end

-- Server checks if ped can be targeted
RegisterNetEvent("loot:checkPed", function(netId)
    local src = source
    local ped = NetworkGetEntityFromNetworkId(netId)

    if not isPedDeadServer(ped) then return end

    if lootedPeds[netId] then
        TriggerClientEvent("loot:allowTarget", src, netId, true)
        return
    end

    TriggerClientEvent("loot:allowTarget", src, netId, false)
end)

-- Client requests loot (pedType sent from client)
RegisterNetEvent("loot:requestLoot", function(netId, pedType)
    local src = source

    if isOnCooldown(src) then return end

    local ped = NetworkGetEntityFromNetworkId(netId)
    if not isPedDeadServer(ped) then return end

    -- Prevent double looting
    if lootedPeds[netId] then return end

    -- Validate pedType (anti-spoof)
    pedType = tonumber(pedType)
    if not pedType or pedType < 0 or pedType > 28 then
        print(("SECURITY: %s sent invalid pedType"):format(GetPlayerName(src)))
        return
    end

    -- Distance validation
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local pedCoords = GetEntityCoords(ped)

    if #(playerCoords - pedCoords) > 3.0 then
        print(("SECURITY: %s attempted distance exploit on loot"):format(GetPlayerName(src)))
        return
    end

    -- Mark ped as looted
    lootedPeds[netId] = true

    -- Loot tables
    local lootTable = {}

    if pedType == 6 then
        lootTable = {
            { item = "pistol_ammo", amount = 1 },
            { item = "bandage", amount = 1 }
        }
    elseif pedType == 4 then
        lootTable = {
            { item = "lockpick", amount = 1 }
        }
    else
        lootTable = {
            { item = "money", amount = math.random(20, 80) }
        }
    end

    -- Give loot
    for _, loot in ipairs(lootTable) do
        exports.ox_inventory:AddItem(src, loot.item, loot.amount)
    end

    -- Dispatch alert
    TriggerEvent("loot:dispatch", src, pedCoords)
end)

-- Dispatch (safe version)
AddEventHandler("loot:dispatch", function(src, coords)
    TriggerEvent("qbx_dispatch:server:notify", {
        job = "police",
        coords = coords,
        title = "Body Looting",
        message = "A citizen is looting a dead body."
    })
end)
