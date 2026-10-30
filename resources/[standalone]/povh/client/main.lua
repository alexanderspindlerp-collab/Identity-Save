local ESX = exports['es_extended']:getSharedObject()

local mapBlips = {}
local lastFleetData = { ok = true, units = {} }

local function trim(v)
    return tostring(v or ''):gsub('^%s*(.-)%s*$', '%1')
end

local function jobName()
    local data = ESX.GetPlayerData and ESX.GetPlayerData() or ESX.PlayerData or {}
    local job = data.job or {}
    return tostring(job.name or '')
end

local function viewerService()
    local name = jobName()
    if Config.EMSJobs and Config.EMSJobs[name] then return 'ems' end
    if Config.PoliceJobs and Config.PoliceJobs[name] then return 'police' end
    return nil
end

local function canSeeUnit(unit)
    local myService = viewerService()
    if not myService then return false end
    local unitService = POVH.unitService(unit, Config)
    if not unitService then return false end
    if Config.CrossServiceView then return true end
    return unitService == myService
end

local function clearMapBlips(activeIds)
    for id, blip in pairs(mapBlips) do
        if not activeIds[id] and DoesBlipExist(blip) then
            RemoveBlip(blip)
            mapBlips[id] = nil
        end
    end
end

local function updateNativeBlips(units)
    if Config.EnableNativeBlips ~= true then
        clearMapBlips({})
        return
    end

    local activeIds = {}
    for _, unit in ipairs(POVH.filterFleetUnits(units, Config)) do
        if canSeeUnit(unit) then
            local id = trim(unit.id or unit.plate or unit.source or '')
            local x, y, z = tonumber(unit.x), tonumber(unit.y), tonumber(unit.z) or 0.0
            if id ~= '' and x and y then
                activeIds[id] = true
                local blip = mapBlips[id]
                if not blip or not DoesBlipExist(blip) then
                    blip = AddBlipForCoord(x + 0.0, y + 0.0, z + 0.0)
                    mapBlips[id] = blip
                    local isEms = POVH.unitService(unit, Config) == 'ems'
                    SetBlipSprite(blip, tonumber(isEms and Config.EMSBlipSprite or Config.PoliceBlipSprite) or 56)
                    SetBlipScale(blip, tonumber(Config.BlipScale or 0.62) or 0.62)
                    SetBlipAsShortRange(blip, false)
                    SetBlipHighDetail(blip, true)
                    BeginTextCommandSetBlipName('STRING')
                    AddTextComponentString(trim(unit.callsign or unit.plate or 'Patrulje'))
                    EndTextCommandSetBlipName(blip)
                else
                    SetBlipCoords(blip, x + 0.0, y + 0.0, z + 0.0)
                end

                local isEms = POVH.unitService(unit, Config) == 'ems'
                SetBlipColour(blip, tonumber(isEms and Config.EMSBlipColor or Config.PoliceBlipColor) or 3)
                SetBlipFlashes(blip, (Config.EmergencyFlashOnSiren == true and unit.siren == true) or false)
                if unit.heading then
                    SetBlipRotation(blip, math.floor(tonumber(unit.heading) or 0))
                end
            end
        end
    end
    clearMapBlips(activeIds)
end

RegisterNetEvent('san_mdt:fleetData', function(resp)
    lastFleetData = resp or { ok = true, units = {} }
    updateNativeBlips(lastFleetData.units or {})
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearMapBlips({})
end)

exports('IsEmergencyUnit', function(unit)
    return POVH.isEmergencyUnit(unit, Config)
end)

exports('IsEmergencyModel', function(modelName)
    local model = string.lower(tostring(modelName or ''))
    return POVH.modelInList(nil, model, Config.PoliceVehicleModels)
        or POVH.modelInList(nil, model, Config.EMSVehicleModels)
end)
