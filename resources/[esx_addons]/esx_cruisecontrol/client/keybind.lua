if Config.Cruise.Enable then
    RegisterCommand('+speedlimiter_toggle', function()
        if Utils and Utils.Refresh then
            Utils:Refresh()
        end

        if not Utils or not Utils.vehicle then return end

        if CC and CC.limiterActive then
            CC:Reset(false)
            return
        end

        if CC and CC.Enable then
            CC:Enable()
        end
    end, false)

    RegisterCommand('-speedlimiter_toggle', function() end, false)
    RegisterKeyMapping('+speedlimiter_toggle', 'Fartbegrænser til/fra', 'keyboard', Config.Cruise.Key or 'CAPITAL')

    RegisterCommand('+speedlimiter_increase', function()
        if CC and CC.ChangeSpeed then CC:ChangeSpeed(true) end
    end, false)

    RegisterCommand('-speedlimiter_increase', function() end, false)
    RegisterKeyMapping('+speedlimiter_increase', 'Hæv fartbegrænser', 'keyboard', 'ADD')

    RegisterCommand('+speedlimiter_decrease', function()
        if CC and CC.ChangeSpeed then CC:ChangeSpeed(false) end
    end, false)

    RegisterCommand('-speedlimiter_decrease', function() end, false)
    RegisterKeyMapping('+speedlimiter_decrease', 'Sænk fartbegrænser', 'keyboard', 'SUBTRACT')
end
