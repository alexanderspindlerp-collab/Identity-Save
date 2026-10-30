local function targetSelect(fn)
    return function(data)
        YAPolice.WithTarget(data.entity, function(serverId, entity)
            fn(serverId, entity)
        end)
    end
end

local function buildOptions()
    local g = YAPolice.PoliceGroups

    return {
        {
            name = 'ya_police_badge',
            icon = 'fa-solid fa-id-badge',
            label = 'Vis Skilt',
            distance = 2.5,
            groups = g,
            onSelect = targetSelect(YAPolice.ShowBadgeToTarget),
        },
        {
            name = 'ya_police_search',
            icon = 'fa-solid fa-magnifying-glass',
            label = 'Visitér',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.SearchPlayer),
        },
        {
            name = 'ya_police_cuff_soft_front',
            icon = 'fa-solid fa-link',
            label = 'Håndjern foran [Blød]',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(function(serverId) YAPolice.Handcuff(serverId, 'soft_front') end),
        },
        {
            name = 'ya_police_cuff_hard_back',
            icon = 'fa-solid fa-handcuffs',
            label = 'Håndjern bagved [Hård]',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(function(serverId) YAPolice.Handcuff(serverId, 'hard_back') end),
        },
        {
            name = 'ya_police_cuff_soft_back',
            icon = 'fa-solid fa-link',
            label = 'Håndjern bagved [Blød]',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(function(serverId) YAPolice.Handcuff(serverId, 'soft_back') end),
        },
        {
            name = 'ya_police_escort',
            icon = 'fa-solid fa-person-walking-arrow-right',
            label = 'Escortér',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(function(serverId) YAPolice.Escort(serverId) end),
        },
        {
            name = 'ya_police_put_vehicle',
            icon = 'fa-solid fa-car-side',
            label = 'Sæt i bil',
            distance = 2.5,
            groups = g,
            canInteract = function(entity)
                return YAPolice.IsTargetHandcuffed(entity)
            end,
            onSelect = targetSelect(YAPolice.PutInVehicle),
        },
        {
            name = 'ya_police_out_vehicle',
            icon = 'fa-solid fa-door-open',
            label = 'Tag ud af bil',
            distance = 2.5,
            groups = g,
            onSelect = targetSelect(YAPolice.OutVehicle),
        },
        {
            name = 'ya_police_gsr',
            icon = 'fa-solid fa-vial',
            label = 'GSR Test',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.GsrTest),
        },
        {
            name = 'ya_police_alcohol',
            icon = 'fa-solid fa-wine-bottle',
            label = 'Alkoholtest',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.AlcoholTest),
        },
        {
            name = 'ya_police_drug',
            icon = 'fa-solid fa-capsules',
            label = 'Narkotest',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.DrugTest),
        },
        {
            name = 'ya_police_dna',
            icon = 'fa-solid fa-dna',
            label = 'DNA Prøve',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.DnaSample),
        },
        {
            name = 'ya_police_fingerprint',
            icon = 'fa-solid fa-fingerprint',
            label = 'Fingeraftryk',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.StartFingerprint),
        },
        {
            name = 'ya_police_jail',
            icon = 'fa-solid fa-building-lock',
            label = 'Fængsl person',
            distance = 2.0,
            groups = g,
            onSelect = targetSelect(YAPolice.JailPlayer),
        },
    }
end

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    exports.ox_target:addGlobalPlayer(buildOptions())
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_target') ~= 'started' then return end

    local names = {}
    for _, opt in ipairs(buildOptions()) do
        names[#names + 1] = opt.name
    end

    pcall(function()
        exports.ox_target:removeGlobalPlayer(names)
    end)
end)
