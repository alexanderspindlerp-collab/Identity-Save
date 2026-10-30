CC = {
    limiterActive = false,
    limitSpeed = 0,
    lastVehicle = nil,

    Reset = function(self, silent)
        if self.lastVehicle and DoesEntityExist(self.lastVehicle) then
            -- Reset vehicle top speed. 999.0 m/s is effectively unlimited.
            SetEntityMaxSpeed(self.lastVehicle, 999.0)
        end

        self.limiterActive = false
        self.limitSpeed = 0
        self.lastVehicle = nil

        if not silent then
            Utils:SetHudState(false, 0)
        else
            if Config.Cruise.Export then
                pcall(function()
                    Config.Cruise.Export(false, 0, Config.Cruise.Unit or 'kmh')
                end)
            end
        end
    end,

    SetLimit = function(self, speed)
        if not Utils:DriverCheck() then
            self:Reset(true)
            return
        end

        local minSpeed = Config.Cruise.MinSpeed or 10
        local maxSpeed = Config.Cruise.MaxSpeed or 250

        speed = math.floor(speed + 0.5)
        if speed < minSpeed then speed = minSpeed end
        if speed > maxSpeed then speed = maxSpeed end

        self.limitSpeed = speed
        self.lastVehicle = Utils.vehicle

        -- This is the important part:
        -- It limits max speed only. It does NOT press throttle / W for the player.
        SetEntityMaxSpeed(Utils.vehicle, Utils:ToGameSpeed(self.limitSpeed))

        if Config.Cruise.Export then
            pcall(function()
                Config.Cruise.Export(true, self.limitSpeed, Config.Cruise.Unit or 'kmh')
            end)
        end
    end,

    ChangeSpeed = function(self, increase)
        if not self.limiterActive then return end
        if not Utils:DriverCheck() then self:Reset(true) return end

        local step = Config.Cruise.Step or 5
        local newSpeed = self.limitSpeed + (increase and step or -step)

        self:SetLimit(newSpeed)
        -- notification removed:format(self.limitSpeed, (Config.Cruise.Unit == 'mph' and 'MPH' or 'KM/T')))
    end,

    Enable = function(self)
        if not Config.Cruise.Enable then return end
        if not Utils:DriverCheck() then return end

        local currentSpeed = Utils:GetSpeed()
        if currentSpeed <= 0 then return end

        self.limiterActive = true
        self:SetLimit(currentSpeed)
        Utils:SetHudState(true, self.limitSpeed)

        CreateThread(function()
            while self.limiterActive do
                if not Utils:DriverCheck() then
                    self:Reset(true)
                    break
                end

                if Utils.vehicle ~= self.lastVehicle then
                    self:Reset(true)
                    break
                end

                -- Brake/handbrake disables the limiter, like many real cars.
                if IsControlJustPressed(0, 72) or IsControlJustPressed(0, 76) then
                    self:Reset(false)
                    break
                end

                -- Keep applying max speed in case another script/handling update resets it.
                SetEntityMaxSpeed(Utils.vehicle, Utils:ToGameSpeed(self.limitSpeed))

                -- Hard safety clamp: if physics/downhill/turbo pushes it over limit, trim it back.
                local maxGameSpeed = Utils:ToGameSpeed(self.limitSpeed)
                local currentGameSpeed = GetEntitySpeed(Utils.vehicle)
                if currentGameSpeed > (maxGameSpeed + 0.35) then
                    local velocity = GetEntityVelocity(Utils.vehicle)
                    local ratio = maxGameSpeed / currentGameSpeed
                    SetEntityVelocity(Utils.vehicle, velocity.x * ratio, velocity.y * ratio, velocity.z * ratio)
                end

                Wait(0)
            end
        end)
    end
}

AddEventHandler('esx:playerPedChanged', function(newPed)
    Utils.ped = newPed
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function()
    Utils.ped = PlayerPedId()
end)

AddEventHandler('esx:enteredVehicle', function(vehicle)
    Utils.vehicle = vehicle
end)

AddEventHandler('esx:exitedVehicle', function()
    CC:Reset(true)
    Utils.vehicle = nil
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CC:Reset(true)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Utils.ped = PlayerPedId()
end)
