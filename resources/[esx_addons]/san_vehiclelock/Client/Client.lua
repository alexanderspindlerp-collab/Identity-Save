ESX = nil

Citizen.CreateThread(function ()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        Citizen.Wait(0)
    end
end)

LockedVehicles = {}

function checkIfVehicleAlreadyLocked(car)
    for k, v in pairs(LockedVehicles) do
        if car == v then
            return true
        end
    end
end

function lockVehicleOrAddIt(vehicle, shouldLock)
    local vehicle = vehicle
    local shouldLock = shouldLock

    table.insert(LockedVehicles, vehicle)
    TriggerServerEvent("mlrp_locknpccars:syncCars", vehicle)

    if shouldLock then
        local math = math.random(0, 100)

        if math > 34 then
            SetVehicleDoorsLocked(vehicle, 2)
        end
    end
end

function getAllCarsAndCheckPlate(plate, vehicle)
    local _plate = plate
    local _vehicle = vehicle
    local isAOwnedCar = false
    ESX.TriggerServerCallback('mlrp_locknpccars:getV', function(vehicles)
        if vehicles then
            for k, v in pairs(vehicles) do
				if string.match(_plate, v.plate) then
					isAOwnedCar = true
                end
            end
            if isAOwnedCar then
                lockVehicleOrAddIt(_vehicle, false)
                return true
            else
                lockVehicleOrAddIt(_vehicle, true)
                return false
            end
        else
        end
    end, source)
end

wait = 100
Citizen.CreateThread(function()
	while true do
        Citizen.Wait(wait)
        wait = 100
        local ped = PlayerPedId()
        local pco = GetEntityCoords(ped)
        local vehicle = GetClosestVehicle(pco, 5.0, 0, 71)
        if DoesEntityExist(vehicle) and IsEntityAVehicle(vehicle) then
            if not IsPedAPlayer(GetPedInVehicleSeat(vehicle, -1)) then
                if GetPedInVehicleSeat(vehicle, -1) ~= 0 then
                    if not checkIfVehicleAlreadyLocked(vehicle) then
                        local plate = tostring(GetVehicleNumberPlateText(vehicle))
                        getAllCarsAndCheckPlate(plate, vehicle)
                    end
                else
                    if not checkIfVehicleAlreadyLocked(vehicle) then
                        local plate = tostring(GetVehicleNumberPlateText(vehicle))
                        getAllCarsAndCheckPlate(plate, vehicle)
                    end                
                end
            end
        end
    end
end)

RegisterNetEvent('mlrp_locknpccars:addCarSync')
AddEventHandler('mlrp_locknpccars:addCarSync', function(cars)
    for k, v in pairs(cars) do
        if not checkIfVehicleAlreadyLocked(v) then
            table.insert(LockedVehicles, v)
        end
    end
end)



--[[
- Created by zImSkillz
- Created at 21:22 GMT+1
- DD/MM/YYYY
- 26.11.2022
]]--
