local showing = false

local function closeCard()
    if not showing then return end
    showing = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

local function resolveItemSlot(data, itemInfo)
    if type(itemInfo) == 'table' and itemInfo.slot then
        return tonumber(itemInfo.slot)
    end
    if type(data) == 'table' and data.slot then
        return tonumber(data.slot)
    end
    return nil
end

RegisterNUICallback('close', function(_, cb)
    closeCard()
    cb(true)
end)

RegisterNetEvent('ya_idcard:client:showCard', function(data)
    showing = true
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'show',
        data = data or {}
    })
end)

RegisterNetEvent('ya_idcard:client:hideCard', function()
    closeCard()
end)

CreateThread(function()
    while true do
        if showing then
            if IsControlJustReleased(0, 38) then -- E
                closeCard()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- ox_inventory kalder: export(data, { name, slot, metadata })
exports('useDriverLicense', function(data, itemInfo)
    TriggerServerEvent('ya_idcard:server:useDriverLicense', resolveItemSlot(data, itemInfo))
end)

exports('useIdCard', function(data, itemInfo)
    TriggerServerEvent('ya_idcard:server:useCard', resolveItemSlot(data, itemInfo))
end)

RegisterCommand('testidcard', function()
    TriggerServerEvent('ya_idcard:server:testCard')
end, false)
