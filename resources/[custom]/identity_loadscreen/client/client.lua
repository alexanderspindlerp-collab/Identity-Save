local closed = false

local function closeLoadscreen()
    if closed then return end
    closed = true
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()

    if Config.Fade then
        DoScreenFadeOut(0)
        Wait(1500)
        DoScreenFadeIn(2000)
    end
end

AddEventHandler('playerSpawned', function()
    closeLoadscreen()
end)

RegisterNetEvent('esx:playerLoaded', function()
    closeLoadscreen()
end)

RegisterNetEvent('esx_multicharacter:SetupUI', function()
    closeLoadscreen()
end)
