local ESX = exports['es_extended']:getSharedObject()

local function hasJob()
    local data = ESX.GetPlayerData()
    local job = data and data.job
    if not job or not job.name then return false end
    local name = string.lower(job.name)
    for i = 1, #Config.JobNames do
        if name == Config.JobNames[i] then return true end
    end
    return false
end

RegisterCommand('mekanikeropkald', function(_, args)
    local message = table.concat(args or {}, ' ')
    if message == '' then
        ESX.ShowNotification('Brug: /mekanikeropkald [besked]')
        return
    end
    TriggerServerEvent('ya_workshop:createCall', Config.CompanyType, message)
end, false)

RegisterCommand('mekanikertablet', function()
    if not hasJob() and not exports.ya_workshop:IsWorkshopEmployee() then
        ESX.ShowNotification('Du er ikke mekaniker.')
        return
    end
    exports.ya_workshop:OpenWorkTablet()
end, false)
