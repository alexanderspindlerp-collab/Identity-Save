local ESX = exports['es_extended']:getSharedObject()
local uiOpen = false
local pendingCategory = nil

local function closeUI()
    if not uiOpen then
        SetNuiFocus(false, false)
        return
    end
    uiOpen = false
    pendingCategory = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openUI(categoryId)
    if uiOpen then
        closeUI()
        Wait(100)
    end

    pendingCategory = categoryId or Config.DefaultCategory or 'criminal'

    CreateThread(function()
        Wait(50)
        TriggerServerEvent('ya_skilltree:requestOpen')
    end)
end

RegisterNetEvent('ya_skilltree:openUI', function(payload)
    if type(payload) ~= 'table' then return end

    uiOpen = true
    SetNuiFocus(true, true)

    payload.startCategory = pendingCategory or Config.DefaultCategory or 'criminal'
    pendingCategory = nil

    SendNUIMessage({
        action = 'open',
        data = payload
    })
end)

RegisterNetEvent('ya_skilltree:sync', function(payload)
    if not uiOpen or type(payload) ~= 'table' then return end
    SendNUIMessage({
        action = 'sync',
        data = payload
    })
end)

RegisterNetEvent('ya_skilltree:notify', function(message)
    ESX.ShowNotification(message or '')
end)

RegisterNetEvent('ya_skilltree:openFailed', function(message)
    pendingCategory = nil
    ESX.ShowNotification(message or 'Kunne ikke åbne skilltree.')
end)

RegisterNetEvent(Config.OpenEvent or 'ya_skilltree:open', function(categoryId)
    openUI(categoryId)
end)

exports('Open', openUI)
exports('Close', closeUI)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb('ok')
end)

RegisterNUICallback('unlock', function(data, cb)
    if data and data.id then
        TriggerServerEvent('ya_skilltree:unlock', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('refund', function(data, cb)
    if data and data.id then
        TriggerServerEvent('ya_skilltree:refund', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('resetBranch', function(data, cb)
    if data and data.branch then
        TriggerServerEvent('ya_skilltree:resetBranch', data.branch)
    end
    cb('ok')
end)

CreateThread(function()
    while true do
        if uiOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                closeUI()
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)
