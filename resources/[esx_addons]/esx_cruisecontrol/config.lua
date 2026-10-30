Config = {
    Locale = GetConvar('esx:locale', 'en'),

    -- Change this if your HUD resource has another name
    HudResource = 'esx_hud',

    Cruise = {
        Enable = true,
        Key = 'CAPITAL', -- CAPS LOCK

        -- This version is a SPEED LIMITER, not auto cruise control.
        -- kmh = Danish km/t. Use 'mph' only if your HUD/server uses MPH.
        Unit = 'kmh',
        Step = 5,
        MinSpeed = 10,
        MaxSpeed = 250,

        -- HUD sync.
        -- state = true/false
        -- speed = selected limiter speed, e.g. 80
        -- unit = 'kmh' or 'mph'
        Export = function(state, speed, unit)
            TriggerEvent('esx_hud:setSpeedLimiter', state == true)
        end,
    },

    Seatbelt = {
        Enable = false,
    }
}
