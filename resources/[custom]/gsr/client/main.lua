local activateShootingCheck = false
local playerPed = cache.ped

local CreateThread = CreateThread
local Wait = Wait
local IsPedShooting = IsPedShooting
local IsEntityInWater = IsEntityInWater

local function buildPoliceGroups()
    local groups = {}
    for i = 1, #(Config.PoliceJobs or { 'police' }) do
        groups[Config.PoliceJobs[i]] = 0
    end
    return groups
end

local function notifyGsrResult(positive)
    if positive then
        lib.notify({
            title = 'GSR — Positiv',
            description = 'Der blev fundet krudtslam på personen.',
            type = 'success'
        })
        return
    end

    lib.notify({
        title = 'GSR — Negativ',
        description = 'Der blev ikke fundet krudtslam på personen.',
        type = 'error'
    })
end

local function getTargetServerId(entity)
    if not entity or entity == 0 then return nil end
    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    if playerIndex == -1 then return nil end
    return GetPlayerServerId(playerIndex)
end

local function runGsrTest(targetServerId)
    if not targetServerId then
        lib.notify({
            title = 'GSR',
            description = 'Kunne ikke finde spilleren.',
            type = 'error'
        })
        return
    end

    local status = lib.callback.await('bzn_gsr:server:check:gsr', false, targetServerId)
    notifyGsrResult(status == true)
end

if GetResourceState('ya_police_interactions') ~= 'started' and GetResourceState('ya_police_interactions') ~= 'starting' then
    exports.ox_target:addGlobalPlayer({
        {
            name = 'bzn_gsr_test_player',
            icon = 'fa-regular fa-gun',
            label = 'GSR Test',
            distance = 2.0,
            groups = buildPoliceGroups(),
            canInteract = function(entity, distance)
                return distance < 2.0 and getTargetServerId(entity) ~= nil
            end,
            onSelect = function(data)
                runGsrTest(getTargetServerId(data.entity))
            end
        }
    })
end

lib.onCache('weapon', function(value)
    if value then
        if not Config.IgnoreWeapons[value] then
            activateShootingCheck = true
            return CheckForGunShots()
        end
    end

    activateShootingCheck = false
end)

CheckForGunShots = function()
    CreateThread(function()
        while activateShootingCheck do
            Wait(0)

            if IsPedShooting(playerPed) then
                lib.callback.await('bzn_gsr:server:set:gsr', false)
                Wait(Config.TimeBetweenShots * 1000)
            end
        end
    end)
end

WashingOff = function()
    CreateThread(function()
        if lib.progressBar({
            label = 'Vasker krudtslam af',
            duration = Config.WashingOffTime * 1000,
            position = 'bottom',
            useWhileDead = false,
            canCancel = true
        }) then
            local status = lib.callback.await('bzn_gsr:server:remove:gsr', false)

            if status then
                lib.notify({
                    title = 'GSR',
                    description = 'Krudtslammet er vasket af i vandet.',
                    type = 'success'
                })
            end
        end
    end)
end

if Config.WashOffGsrInWater then
    CreateThread(function()
        local washingOffGsr = false
        local waitTime = 5000

        while true do
            Wait(waitTime)

            if LocalPlayer.state.gsr then
                if not washingOffGsr and IsEntityInWater(playerPed) then
                    washingOffGsr = true
                    waitTime = 500
                    WashingOff()
                end

                if washingOffGsr and not IsEntityInWater(playerPed) then
                    washingOffGsr = false
                    waitTime = 5000
                    lib.cancelProgress()

                    lib.notify({
                        title = 'GSR',
                        description = 'Du forlod vandet for tidligt — krudtslammet er ikke vasket af.',
                        type = 'error'
                    })
                end
            end
        end
    end)
end
