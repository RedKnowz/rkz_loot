local addedTargets = {}
local activeLoots = {}

-- Server tells client whether ped is already looted
RegisterNetEvent("loot:allowTarget", function(netId, alreadyLooted)
    if alreadyLooted then
        -- Remove target if it somehow exists
        if addedTargets[netId] then
            exports.ox_target:removeLocalEntity(netId)
            addedTargets[netId] = nil
        end
        return
    end

    if addedTargets[netId] then return end

    local ped = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ped) then return end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'loot_dead_npc_' .. netId,
            icon = 'fa-solid fa-box-open',
            label = 'Loot Body',
            distance = 2.0,
            onSelect = function()
                startLooting(ped, netId)
            end
        }
    })

    addedTargets[netId] = ped
end)

-- Looting logic
function startLooting(ped, netId)
    if activeLoots[netId] then return end
    activeLoots[netId] = true

    local player = PlayerPedId()

    RequestAnimDict("amb@world_human_bum_wash@male@low@idle_a")
    while not HasAnimDictLoaded("amb@world_human_bum_wash@male@low@idle_a") do
        Wait(10)
    end

    TaskPlayAnim(player, "amb@world_human_bum_wash@male@low@idle_a", "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)

    SetNuiFocus(true, false)
    SendNUIMessage({ action = "startProgress", duration = 3500 })

    local finished = false
    local timeout = GetGameTimer() + 4000

    RegisterNetEvent("loot:progressFinished", function()
        finished = true
    end)

    while not finished and GetGameTimer() < timeout do
        Wait(100)
    end

    SetNuiFocus(false, false)
    ClearPedTasks(player)

    if finished then
        local pedType = GetPedType(ped) or 0
        TriggerServerEvent("loot:requestLoot", netId, pedType)

        -- REMOVE TARGET IMMEDIATELY AFTER LOOTING
        if addedTargets[netId] then
            exports.ox_target:removeLocalEntity(addedTargets[netId])
            addedTargets[netId] = nil
        end
    else
        lib.notify({
            title = 'Loot',
            description = 'Scan interrupted.',
            type = 'error',
            icon = 'ban',
            duration = 4000
        })
    end

    activeLoots[netId] = nil
end

-- NUI callback
RegisterNUICallback("progressComplete", function(_, cb)
    TriggerEvent("loot:progressFinished")
    cb({})
end)

-- Ped scanner
CreateThread(function()
    while true do
        Wait(1000)

        local handle, ped = FindFirstPed()
        local success

        repeat
            if DoesEntityExist(ped)
                and not IsPedAPlayer(ped)
                and IsPedDeadOrDying(ped, true)
            then
                if not NetworkGetEntityIsNetworked(ped) then
                    NetworkRegisterEntityAsNetworked(ped)
                end

                local netId = NetworkGetNetworkIdFromEntity(ped)

                if not addedTargets[netId] then
                    TriggerServerEvent("loot:checkPed", netId)
                end
            end

            success, ped = FindNextPed(handle)
        until not success

        EndFindPed(handle)
    end
end)
