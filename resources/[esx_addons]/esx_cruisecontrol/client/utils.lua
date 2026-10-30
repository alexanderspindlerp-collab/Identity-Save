Utils = {
    ped = 0,
    vehicle = nil,

    Refresh = function(self)
        self.ped = PlayerPedId()
        self.vehicle = GetVehiclePedIsIn(self.ped, false)

        if self.vehicle == 0 then
            self.vehicle = nil
        end
    end,

    DriverCheck = function(self)
        self:Refresh()

        if not self.vehicle then return false end
        if not DoesEntityExist(self.vehicle) then return false end
        if GetPedInVehicleSeat(self.vehicle, -1) ~= self.ped then return false end

        local class = GetVehicleClass(self.vehicle)

        -- Disable limiter for bicycles, trains, boats, helicopters, planes etc.
        if class == 13 or class == 14 or class == 15 or class == 16 or class == 21 then
            return false
        end

        return true
    end,

    HudCheck = function(self)
        return Config.HudResource and GetResourceState(Config.HudResource) == 'started'
    end,

    SetHudState = function(self, state, speed)
        if Config.Cruise.Export then
            local success, err = pcall(function()
                Config.Cruise.Export(state, speed or 0, Config.Cruise.Unit or 'kmh')
            end)

            if not success and err then
                print(("^5[^3ERROR^5] ^1%s"):format(err))
            end
        end

        if state then
            -- notification removed:format(speed or 0, (Config.Cruise.Unit == 'mph' and 'MPH' or 'KM/T')))
        else
            -- notification removed
        end
    end,

    SpeedMultiplier = function(self)
        return (Config.Cruise.Unit == 'mph') and 2.236936 or 3.6
    end,

    ToGameSpeed = function(self, speed)
        return speed / self:SpeedMultiplier()
    end,

    FromGameSpeed = function(self, speed)
        return math.floor((speed * self:SpeedMultiplier()) + 0.5)
    end,

    GetSpeed = function(self)
        if not self:DriverCheck() then return 0 end
        return self:FromGameSpeed(GetEntitySpeed(self.vehicle))
    end
}
