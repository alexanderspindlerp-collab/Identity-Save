local ESX = exports['es_extended']:getSharedObject()

local policeTunerOpen = false

local function getVehicleData()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return nil end

    local props = ESX.Game.GetVehicleProperties(veh)
    return {
        entity = veh,
        plate = props.plate,
        model = props.model,
        label = GetLabelText(GetDisplayNameFromVehicleModel(props.model)),
        props = props,
    }, veh
end

function OpenPoliceTuner()
    local vehicle, veh = getVehicleData()
    if not vehicle or not veh or veh == 0 then
        ESX.ShowNotification('Stig ind i dit tjenestekøretøj som fører.')
        return
    end

    ESX.TriggerServerCallback('ya_workshop:canTunePoliceVehicle', function(canTune, msg)
        if not canTune then
            ESX.ShowNotification(msg or 'Du kan ikke tune denne bil.')
            return
        end

        ESX.TriggerServerCallback('ya_workshop:getPoliceTunerData', function(data)
            if not data or data.error then
                ESX.ShowNotification(data and data.error or 'Kunne ikke åbne AutoShop.')
                return
            end

            exports.ya_workshop:OpenTunerMenu('police_autoshop', {
                policeMode = true,
                shopData = data,
                vehicle = vehicle,
                vehicleEntity = veh,
            })
        end, vehicle.plate)
    end, vehicle.plate)
end

exports('OpenPoliceTuner', OpenPoliceTuner)

RegisterNetEvent('ya_workshop:openPoliceTuner', function()
    OpenPoliceTuner()
end)
