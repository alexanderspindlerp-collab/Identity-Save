local showingBadge = false

RegisterNetEvent('ya_police:client:showBadge', function(data)
    showingBadge = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'showBadge', data = data or {} })
end)

local function closeBadge()
    if not showingBadge then return end
    showingBadge = false
    SendNUIMessage({ action = 'hideBadge' })
end

RegisterNUICallback('closeBadge', function(_, cb)
    closeBadge()
    cb(true)
end)

CreateThread(function()
    while true do
        if showingBadge then
            if IsControlJustReleased(0, 38) or IsControlJustReleased(0, 177) then
                closeBadge()
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

function YAPolice.ShowBadgeToTarget(serverId)
    TriggerServerEvent('ya_police:server:showBadge', serverId)
end
