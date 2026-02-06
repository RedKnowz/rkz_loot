local addedTargets = {}
local lootedPeds = {}

RegisterNetEvent("loot:receiveLootStatus", function(netId, alreadyLooted)
    if alreadyLooted or lootedPeds[netId] then return end

    local ped = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(ped) then return end

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'loot_dead_npc_' .. netId,
            icon = 'fa-solid fa-box-open',
            label = 'Loot Body',
            distance = 2.0,
            onSelect = function()
                lootPed(ped)
            end
        }
    })

    addedTargets[netId] = true
end)

RegisterNUICallback("progressComplete", function(_, cb)
    TriggerEvent("loot:progressFinished")
    SetNuiFocus(false, false)
    cb({})
end)

-- UNIVERSAL DISPATCH SUPPORT
function sendDispatchAlert()
    local coords = GetEntityCoords(PlayerPedId())

    -- ps-dispatch
    if GetResourceState('ps-dispatch') == 'started' then
        exports['ps-dispatch']:CustomAlert({
            coords = coords,
            message = "Suspicious activity: possible body looting",
            dispatchCode = "10-37",
            radius = 25,
            job = {"police"}
        })
        return
    end

    -- cd_dispatch
    if GetResourceState('cd_dispatch') == 'started' then
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = {'police'},
            coords = coords,
            title = 'Suspicious Activity',
            message = 'A person is looting a body.',
            flash = 0,
            unique_id = tostring(math.random(1111111,9999999)),
            sound = 1
        })
        return
    end

    -- core-dispatch
    if GetResourceState('core_dispatch') == 'started' then
        TriggerServerEvent('core_dispatch:addCall', '10-37', 'Body Looting', {
            {icon = 'fa-user', info = 'Suspicious individual'},
            {icon = 'fa-location-dot', info = 'Looting a dead body'}
        }, coords, false)
        return
    end

    -- qs-dispatch
    if GetResourceState('qs-dispatch') == 'started' then
        exports['qs-dispatch']:createAlert({
            coords = coords,
            title = "Suspicious Activity",
            message = "Someone is looting a body.",
            job = {"police"},
            code = "10-37"
        })
        return
    end

    -- qbx_dispatch (stock QBX)
    if GetResourceState('qbx_dispatch') == 'started' then
        TriggerServerEvent('qbx_dispatch:server:notify', {
            coords = coords,
            title = 'Suspicious Activity',
            message = 'Someone is looting a body.',
            type = 'police'
        })
        return
    end

    -- Fallback
    print("^3[LOOT] No dispatch system detected, skipping alert.^7")
end

function lootPed(ped)
    if not NetworkGetEntityIsNetworked(ped) then
        NetworkRegisterEntityAsNetworked(ped)
    end

    local netId = NetworkGetNetworkIdFromEntity(ped)
    local pedType = getPedType(ped)
    local player = PlayerPedId()

    RequestAnimDict("amb@world_human_bum_wash@male@low@idle_a")
    while not HasAnimDictLoaded("amb@world_human_bum_wash@male@low@idle_a") do
        Wait(10)
    end

    TaskPlayAnim(player, "amb@world_human_bum_wash@male@low@idle_a", "idle_a",
        8.0, -8.0, -1, 1, 0, false, false, false)

    local finished = false
    local timeout = GetGameTimer() + 4000

    SetNuiFocus(true, false)
    SendNUIMessage({ action = "startProgress", duration = 3500 })

    local function onFinish()
        finished = true
    end

    -- Store handler ID
    local handler = AddEventHandler("loot:progressFinished", onFinish)

    while not finished and GetGameTimer() < timeout do
        Wait(100)
    end

    -- Remove handler safely
    if handler then
        RemoveEventHandler(handler)
        handler = nil
    end

    SetNuiFocus(false, false)
    ClearPedTasks(player)

    if finished then
        lootedPeds[netId] = true
        exports.ox_target:removeLocalEntity(ped, 'loot_dead_npc_' .. netId)
        TriggerServerEvent("loot:giveLoot", netId, pedType)

        -- Dispatch alert
        sendDispatchAlert()
    else
        lib.notify({
            title = 'Loot',
            description = 'Scan interrupted.',
            type = 'error',
            icon = 'ban',
            duration = 4000
        })
    end
end

function getPedType(ped)
    if IsPedAPlayer(ped) then return "player" end
    if IsPedInAnyPoliceVehicle(ped) or GetPedType(ped) == 6 then return "cop" end
    if GetPedRelationshipGroupHash(ped) == GetHashKey("AMBIENT_GANG_LOST") then return "gang" end
    return "civilian"
end

CreateThread(function()
    while true do
        Wait(1000)

        local handle, ped = FindFirstPed()
        local success

        repeat
            if DoesEntityExist(ped) and not IsPedAPlayer(ped) then
                if IsPedDeadOrDying(ped, true) then
                    if not NetworkGetEntityIsNetworked(ped) then
                        NetworkRegisterEntityAsNetworked(ped)
                    end

                    local netId = NetworkGetNetworkIdFromEntity(ped)

                    if not addedTargets[netId] and not lootedPeds[netId] then
                        TriggerServerEvent("loot:checkLooted", netId)
                    end
                end
            end

            success, ped = FindNextPed(handle)
        until not success

        EndFindPed(handle)
    end
end)