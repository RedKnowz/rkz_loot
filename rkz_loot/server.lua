local lootedPeds = {}
local cooldowns = {}

local function isOnCooldown(src)
    local now = os.time()
    if cooldowns[src] and cooldowns[src] > now then
        return true
    end
    cooldowns[src] = now + 3
    return false
end

RegisterNetEvent("loot:checkPed", function(netId)
    local src = source
    local ped = NetworkGetEntityFromNetworkId(netId)

    if not DoesEntityExist(ped) then return end
    if not IsPedDeadOrDying(ped, true) then return end

    if lootedPeds[netId] then
        TriggerClientEvent("loot:allowTarget", src, netId, true)
        return
    end

    TriggerClientEvent("loot:allowTarget", src, netId, false)
end)

RegisterNetEvent("loot:requestLoot", function(netId)
    local src = source

    if isOnCooldown(src) then return end

    local ped = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ped) then return end
    if not IsPedDeadOrDying(ped, true) then return end

    if lootedPeds[netId] then return end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local pedCoords = GetEntityCoords(ped)

    if #(playerCoords - pedCoords) > 3.0 then
        print(("SECURITY: %s attempted distance exploit on loot"):format(GetPlayerName(src)))
        return
    end

    lootedPeds[netId] = true

    local pedType = GetPedType(ped)
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

    for _, loot in ipairs(lootTable) do
        exports.ox_inventory:AddItem(src, loot.item, loot.amount)
    end

    TriggerEvent("loot:dispatch", src, pedCoords)
end)

AddEventHandler("loot:dispatch", function(src, coords)
    local dispatch = exports.qbx_core:GetDispatchSystem()

    if dispatch == "qbx" then
        TriggerEvent("qbx_dispatch:server:notify", {
            job = "police",
            coords = coords,
            title = "Body Looting",
            message = "A citizen is looting a dead body."
        })
    end
end)
