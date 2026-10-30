YAPolice = YAPolice or {}

local PoliceJobs = {}
for i = 1, #(Config.PoliceJobs or {}) do
    PoliceJobs[Config.PoliceJobs[i]] = true
end

YAPolice.PoliceGroups = {}
for job, _ in pairs(PoliceJobs) do
    YAPolice.PoliceGroups[job] = 0
end

function YAPolice.IsPolice()
    local job = ESX.PlayerData and ESX.PlayerData.job
    return job and job.name and PoliceJobs[job.name] == true
end

function YAPolice.GetTargetServerId(entity)
    if not entity or entity == 0 then return nil end
    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
    if playerIndex == -1 then return nil end
    return GetPlayerServerId(playerIndex)
end

function YAPolice.WithTarget(entity, cb)
    if not YAPolice.IsPolice() then return end
    local serverId = YAPolice.GetTargetServerId(entity)
    if not serverId or serverId == 0 then
        ESX.ShowNotification('Ingen spiller i nærheden.')
        return
    end
    cb(serverId, entity)
end

function YAPolice.LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

function YAPolice.PlayAnim(ped, anim, duration)
    if not anim or not anim.dict or not anim.clip then return end
    if not YAPolice.LoadAnimDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, duration or -1, anim.flag or 0, 0, false, false, false)
end

function YAPolice.AttachProp(ped, model, bone, offset, rotation)
    local hash = type(model) == 'string' and joaat(model) or model
    lib.requestModel(hash)
    local obj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        obj, ped, GetPedBoneIndex(ped, bone or 60309),
        offset.x or 0.0, offset.y or 0.0, offset.z or 0.0,
        rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
    return obj
end

function YAPolice.GetCuffStyle(cuffStyle)
    return Config.CuffStyles[cuffStyle] or Config.CuffStyles.hard_back
end

function YAPolice.IsTargetHandcuffed(entity)
    local serverId = YAPolice.GetTargetServerId(entity)
    if not serverId then return false end
    local player = GetPlayerFromServerId(serverId)
    if player ~= -1 then
        local ped = GetPlayerPed(player)
        if ped and ped ~= 0 and Entity(ped).state.handcuffed then
            return Entity(ped).state.handcuffed == true
        end
    end
    return LocalPlayer.state.handcuffed == true and serverId == cache.serverId
end

RegisterNetEvent('ya_police:client:meMessage', function(name, message)
    TriggerEvent('chat:addMessage', {
        template = '<div style="margin: 0.05vw;"><b style="color:#c9a227;">* {0}</b> {1}</div>',
        args = { name, message },
    })
end)

local cuffProps = {}

RegisterNetEvent('ya_police:client:syncCuffProp', function(serverId, cuffStyle)
    if not cuffStyle or not Config.CuffStyles[cuffStyle] then
        if cuffProps[serverId] and DoesEntityExist(cuffProps[serverId]) then
            DeleteEntity(cuffProps[serverId])
            cuffProps[serverId] = nil
        end
        return
    end

    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end
    local ped = GetPlayerPed(player)

    if cuffProps[serverId] and DoesEntityExist(cuffProps[serverId]) then
        DeleteEntity(cuffProps[serverId])
        cuffProps[serverId] = nil
    end

    local prop = YAPolice.GetCuffStyle(cuffStyle).prop
    cuffProps[serverId] = YAPolice.AttachProp(
        ped,
        prop.model,
        prop.bone,
        prop.offset,
        prop.rotation
    )
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(cuffProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
end)
