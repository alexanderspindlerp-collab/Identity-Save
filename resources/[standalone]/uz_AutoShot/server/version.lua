local ResourceName    = GetCurrentResourceName()
local CURRENT_VERSION = GetResourceMetadata(ResourceName, 'version')
local VERSION_URL     = 'https://uz-scripts.com/api/versions/uz-autoshot'

local function CheckVersion()
    Wait(1400)
    if ResourceName ~= 'uz_AutoShot' then
        print('^1[ERROR] Resource folder must be named ^3"uz_AutoShot"^1! (Current: ^3"' .. ResourceName .. '"^1) Restart the server after renaming.^0')
        StopResource(ResourceName)
        return
    end
    PerformHttpRequest(VERSION_URL, function(statusCode, body)
        if statusCode == 200 and body then
            local latest  = string.gsub(body, '%s+', '')
            local current = 'v' .. CURRENT_VERSION

            if latest and latest ~= '' then
                if latest ~= current then
                    print(('^3[uz_AutoShot] New version available: %s (Current: %s) — https://discord.uz-scripts.com/^0'):format(latest, current))
                else
                    print(('^2[uz_AutoShot] Up to date (%s)^0'):format(current))
                end
            else
                print('^1[uz_AutoShot] Could not retrieve version information!^0')
            end
        else
            print('^1[uz_AutoShot] Version check connection error!^0')
        end
    end, 'GET', '', { ['User-Agent'] = 'FiveM Version Check' })
end

CreateThread(CheckVersion)
