local ESX = exports['es_extended']:getSharedObject()

VehicleCatalog = {
    baselineProps = nil,
    activePreview = nil,
}

local WINDOW_TINTS = {
    { index = 0, label = 'Ingen toning' },
    { index = 1, label = 'Pure Black' },
    { index = 2, label = 'Dark Smoke' },
    { index = 3, label = 'Light Smoke' },
    { index = 4, label = 'Limo' },
    { index = 5, label = 'Green' },
}

local function cloneTable(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do
        if type(v) == 'table' then
            copy[k] = cloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function resolveItemImage(template, group)
    local images = Config.ItemImages or {}
    return template.image
        or images[template.key]
        or images[template.icon or '']
        or group.image
end

local function colorLabelPrefix(templateKey)
    if templateKey == 'paint_primary' then return 'Primær · ' end
    if templateKey == 'paint_secondary' then return 'Sekundær · ' end
    return ''
end

local function modLabel(vehicle, modType, modIndex)
    if modIndex == -1 then
        return 'Standard'
    end

    local textLabel = GetModTextLabel(vehicle, modType, modIndex)
    if textLabel and textLabel ~= '' then
        local label = GetLabelText(textLabel)
        if label and label ~= '' and label ~= 'NULL' then
            return label
        end
    end

    return ('Variant %d'):format(modIndex + 1)
end

local function setBestModKitForType(vehicle, modType)
    local numKits = GetNumModKits(vehicle) or 0
    if numKits <= 0 then
        numKits = 1
    end

    local bestKit = 0
    local bestCount = -1
    for kit = 0, numKits - 1 do
        SetVehicleModKit(vehicle, kit)
        local count = GetNumVehicleMods(vehicle, modType)
        if count > bestCount then
            bestCount = count
            bestKit = kit
        end
    end

    SetVehicleModKit(vehicle, bestKit)
    return bestCount, bestKit
end

local function resolveBindingModType(vehicle, binding)
    local modTypes = { binding.modType }
    if binding.altModTypes then
        for i = 1, #binding.altModTypes do
            modTypes[#modTypes + 1] = binding.altModTypes[i]
        end
    end

    for i = 1, #modTypes do
        local modType = modTypes[i]
        local count = setBestModKitForType(vehicle, modType)
        if count > 0 then
            return modType, count
        end
    end

    SetVehicleModKit(vehicle, 0)
    return binding.modType, 0
end

local function buildVehicleModItemsForType(vehicle, template, modType, group)
    local count = setBestModKitForType(vehicle, modType)
    if count <= 0 then return {} end

    local items = {}
    for modIndex = -1, count - 1 do
        items[#items + 1] = {
            key = ('%s_m%d_%d'):format(template.key, modType, modIndex),
            baseKey = template.key,
            label = modLabel(vehicle, modType, modIndex),
            desc = template.desc,
            price = template.price,
            icon = template.icon or template.key,
            image = resolveItemImage(template, group),
            mod = {
                kind = 'vehicleMod',
                modType = modType,
                modIndex = modIndex,
            },
        }
    end

    return items
end

local function buildVehicleModItems(vehicle, template, binding, group)
    if binding.mergeAltModTypes then
        local modTypes = { binding.modType }
        if binding.altModTypes then
            for i = 1, #binding.altModTypes do
                modTypes[#modTypes + 1] = binding.altModTypes[i]
            end
        end

        local items = {}
        for i = 1, #modTypes do
            local variants = buildVehicleModItemsForType(vehicle, template, modTypes[i], group)
            for j = 1, #variants do
                items[#items + 1] = variants[j]
            end
        end
        return items
    end

    local modType, count = resolveBindingModType(vehicle, binding)
    if count <= 0 then return {} end

    local items = {}
    for modIndex = -1, count - 1 do
        items[#items + 1] = {
            key = ('%s_%d'):format(template.key, modIndex),
            baseKey = template.key,
            label = modLabel(vehicle, modType, modIndex),
            desc = template.desc,
            price = template.price,
            icon = template.icon or template.key,
            image = resolveItemImage(template, group),
            mod = {
                kind = 'vehicleMod',
                modType = modType,
                modIndex = modIndex,
            },
        }
    end

    return items
end

local function buildPerformanceItems(vehicle, template, binding, group)
    local modType, count = resolveBindingModType(vehicle, binding)
    if count <= 0 then return {} end

    local items = {}
    for modIndex = 0, count - 1 do
        items[#items + 1] = {
            key = ('%s_%d'):format(template.key, modIndex),
            baseKey = template.key,
            label = ('Level %d'):format(modIndex + 1),
            desc = template.desc,
            price = template.price,
            icon = template.icon or template.key,
            image = resolveItemImage(template, group),
            mod = {
                kind = 'vehicleMod',
                modType = modType,
                modIndex = modIndex,
            },
        }
    end

    return items
end

local function buildColorItems(template, binding)
    local swatches = Config.PaintSwatches or {}
    local items = {}

    for i = 1, #swatches do
        local swatch = swatches[i]
        items[#items + 1] = {
            key = ('%s_%d'):format(template.key, swatch.index),
            baseKey = template.key,
            label = colorLabelPrefix(template.key) .. swatch.label,
            desc = template.desc,
            price = template.price,
            icon = template.icon or template.key,
            color = swatch.hex,
            isColor = true,
            mod = {
                kind = 'color',
                prop = binding.prop,
                index = swatch.index,
            },
        }
    end

    return items
end

local function buildWindowTintItems(template, group)
    local items = {}

    for i = 1, #WINDOW_TINTS do
        local tint = WINDOW_TINTS[i]
        items[#items + 1] = {
            key = ('%s_%d'):format(template.key, tint.index),
            baseKey = template.key,
            label = tint.label,
            desc = template.desc,
            price = template.price,
            icon = template.icon or template.key,
            image = resolveItemImage(template, group),
            mod = {
                kind = 'windowTint',
                index = tint.index,
            },
        }
    end

    return items
end

local function getExtraLabel(vehicle, extraId)
    local model = vehicle and vehicle ~= 0 and GetEntityModel(vehicle) or 0
    local labels = Config.ExtraLabels or {}
    local modelLabels = labels[tostring(model)] or labels[model]
    if modelLabels and modelLabels[tostring(extraId)] then
        return modelLabels[tostring(extraId)]
    end
    local defaults = labels.default or {}
    return defaults[tostring(extraId)] or ('Ekstra %d'):format(extraId)
end

local function getPoliceExtraLabel(vehicle, extraId)
    local labels = Config.Police and Config.Police.ExtraLabels or {}
    local modelHash = GetEntityModel(vehicle)
    local modelLabels = labels[tostring(modelHash)]
    if modelLabels and modelLabels[tostring(extraId)] then
        return modelLabels[tostring(extraId)]
    end
    local defaults = labels.default or {}
    return defaults[tostring(extraId)] or ('Politi-ekstra %d'):format(extraId)
end

local function isPoliceExtraAllowed(extraId)
    local ids = Config.Police and Config.Police.OnlyExtraIds or {}
    for i = 1, #ids do
        if tonumber(ids[i]) == tonumber(extraId) then
            return true
        end
    end
    return false
end

local function buildPoliceExtraItems(vehicle, template, group)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return {} end

    local items = {}
    for extraId = 0, 20 do
        if isPoliceExtraAllowed(extraId) and DoesExtraExist(vehicle, extraId) then
            local label = getPoliceExtraLabel(vehicle, extraId)
            items[#items + 1] = {
                key = ('police_extra_%d_on'):format(extraId),
                baseKey = template.key,
                label = label .. ' · Til',
                desc = 'Politi-udstyr — kun synligt for betjente',
                price = template.price,
                icon = template.icon or template.key,
                image = resolveItemImage(template, group),
                mod = {
                    kind = 'policeExtra',
                    extraId = extraId,
                    enabled = true,
                },
            }
            items[#items + 1] = {
                key = ('police_extra_%d_off'):format(extraId),
                baseKey = template.key,
                label = label .. ' · Fra',
                desc = 'Slå politi-udstyr fra',
                price = template.price,
                icon = template.icon or template.key,
                image = resolveItemImage(template, group),
                mod = {
                    kind = 'policeExtra',
                    extraId = extraId,
                    enabled = false,
                },
            }
        end
    end

    return items
end

local function buildVehicleExtraItems(vehicle, template, group)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return {} end

    local items = {}
    for extraId = 0, 20 do
        if DoesExtraExist(vehicle, extraId) then
            local label = getExtraLabel(vehicle, extraId)
            items[#items + 1] = {
                key = ('extra_%d_on'):format(extraId),
                baseKey = template.key,
                label = label .. ' · Til',
                desc = 'Slå ekstra til på bilen',
                price = template.price,
                icon = template.icon or template.key,
                image = resolveItemImage(template, group),
                mod = {
                    kind = 'extra',
                    extraId = extraId,
                    enabled = true,
                },
            }
            items[#items + 1] = {
                key = ('extra_%d_off'):format(extraId),
                baseKey = template.key,
                label = label .. ' · Fra',
                desc = 'Slå ekstra fra på bilen',
                price = template.price,
                icon = template.icon or template.key,
                image = resolveItemImage(template, group),
                mod = {
                    kind = 'extra',
                    extraId = extraId,
                    enabled = false,
                },
            }
        end
    end

    return items
end

local function buildTurboItems(template, group)
    local items = {
        {
            key = template.key .. '_0',
            baseKey = template.key,
            label = 'Uden turbo',
            desc = template.desc,
            price = 0,
            icon = template.icon or template.key,
            image = resolveItemImage(template, group),
            mod = { kind = 'turbo', enabled = false },
        },
        {
            key = template.key .. '_1',
            baseKey = template.key,
            label = 'Turbo',
            desc = template.desc,
            price = template.price,
            icon = template.icon or template.key,
            image = resolveItemImage(template, group),
            mod = { kind = 'turbo', enabled = true },
        },
    }
    return items
end

local function buildGroupItems(vehicle, group, templates, options)
    options = options or {}
    local built = {}
    local hasPaintColor = false

    for i = 1, #templates do
        local template = templates[i]
        local binding = Config.ItemModBindings and Config.ItemModBindings[template.key]
        local variants = {}

        if binding then
            if binding.kind == 'vehicleMod' then
                variants = buildVehicleModItems(vehicle, template, binding, group)
            elseif binding.kind == 'performance' then
                variants = buildPerformanceItems(vehicle, template, binding, group)
            elseif binding.kind == 'color' then
                variants = buildColorItems(template, binding)
                hasPaintColor = true
            elseif binding.kind == 'windowTint' then
                variants = buildWindowTintItems(template, group)
            elseif binding.kind == 'turbo' then
                variants = buildTurboItems(template, group)
            elseif binding.kind == 'vehicleExtras' then
                if options.policeMode then
                    variants = buildPoliceExtraItems(vehicle, template, group)
                else
                    variants = buildVehicleExtraItems(vehicle, template, group)
                end
            end
        end

        if #variants > 0 then
            for j = 1, #variants do
                if not variants[j].image then
                    variants[j].image = resolveItemImage(template, group)
                end
                built[#built + 1] = variants[j]
            end
        elseif not binding then
            built[#built + 1] = {
                key = template.key,
                baseKey = template.key,
                label = template.label,
                desc = template.desc,
                price = template.price,
                icon = template.icon or template.key,
                image = resolveItemImage(template, group),
            }
        end
    end

    if hasPaintColor then
        built[#built + 1] = {
            key = 'paint_rgb',
            baseKey = 'paint_primary',
            label = 'RGB',
            desc = 'Custom primær eller sekundær lak',
            price = options.policeMode and 0 or 4500,
            image = 'img/groups/rgb.svg',
            isRgb = true,
            mod = {
                kind = 'customColor',
                prop = 'color1',
            },
        }
    end

    return built
end

local MOD_PROP_KEYS = {
    [0] = 'modSpoilers',
    [2] = 'modRearBumper',
    [4] = 'modExhaust',
    [5] = 'modFrame',
    [6] = 'modGrille',
    [7] = 'modHood',
    [10] = 'modRoof',
    [11] = 'modEngine',
    [12] = 'modBrakes',
    [13] = 'modTransmission',
    [15] = 'modSuspension',
    [23] = 'modFrontWheels',
    [27] = 'modTrimA',
    [28] = 'modOrnaments',
    [29] = 'modDashboard',
    [37] = 'modTrunk',
    [38] = 'modHydrolic',
    [43] = 'modAerials',
    [46] = 'modWindows',
    [48] = 'modLivery',
}

local function requestVehicleControl(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if NetworkHasControlOfEntity(vehicle) then return true end
    NetworkRequestControlOfEntity(vehicle)
    local count = 0
    while not NetworkHasControlOfEntity(vehicle) and count < 25 do
        Wait(0)
        NetworkRequestControlOfEntity(vehicle)
        count = count + 1
    end
    return NetworkHasControlOfEntity(vehicle)
end

function VehicleCatalog.mergeModIntoProps(props, modData)
    if not props or type(modData) ~= 'table' then return props end

    if modData.kind == 'color' then
        props[modData.prop] = modData.index
    elseif modData.kind == 'customColor' then
        local prop = modData.prop == 'color2' and 'color2' or 'color1'
        props[prop] = {
            tonumber(modData.r) or 255,
            tonumber(modData.g) or 255,
            tonumber(modData.b) or 255,
        }
    elseif modData.kind == 'vehicleMod' then
        local propKey = MOD_PROP_KEYS[modData.modType]
        if propKey then
            props[propKey] = modData.modIndex
        end
    elseif modData.kind == 'windowTint' then
        props.windowTint = modData.index
    elseif modData.kind == 'turbo' then
        props.modTurbo = modData.enabled == true
    elseif modData.kind == 'extra' then
        props.extras = props.extras or {}
        props.extras[tostring(modData.extraId)] = modData.enabled == true
    elseif modData.kind == 'policeExtra' then
        props.policeExtras = props.policeExtras or {}
        props.policeExtras[tostring(modData.extraId)] = modData.enabled == true
    end

    return props
end

function VehicleCatalog.SetBaseline(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then
        VehicleCatalog.baselineProps = ESX.Game.GetVehicleProperties(vehicle)
    else
        VehicleCatalog.baselineProps = nil
    end
    VehicleCatalog.activePreview = nil
end

function VehicleCatalog.ResetPreview(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if VehicleCatalog.baselineProps then
        requestVehicleControl(vehicle)
        local ok, err = pcall(function()
            ClearVehicleCustomPrimaryColour(vehicle)
            ClearVehicleCustomSecondaryColour(vehicle)
            ESX.Game.SetVehicleProperties(vehicle, VehicleCatalog.baselineProps)
        end)
        if not ok then
            print(('[ya_workshop] ResetPreview fejl: %s'):format(tostring(err)))
        end
    end
    VehicleCatalog.activePreview = nil
end

function VehicleCatalog.ApplyModNative(vehicle, modData)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(modData) ~= 'table' then return end

    SetVehicleModKit(vehicle, 0)

    if modData.kind == 'color' then
        ClearVehicleCustomPrimaryColour(vehicle)
        ClearVehicleCustomSecondaryColour(vehicle)
        local c1, c2 = GetVehicleColours(vehicle)
        if modData.prop == 'color1' then
            SetVehicleColours(vehicle, modData.index, c2)
        elseif modData.prop == 'color2' then
            SetVehicleColours(vehicle, c1, modData.index)
        elseif modData.prop == 'pearlescentColor' then
            local pearl, wheel = GetVehicleExtraColours(vehicle)
            SetVehicleExtraColours(vehicle, modData.index, wheel)
        end
    elseif modData.kind == 'customColor' then
        local r, g, b = tonumber(modData.r) or 255, tonumber(modData.g) or 255, tonumber(modData.b) or 255
        if modData.prop == 'color1' then
            ClearVehicleCustomPrimaryColour(vehicle)
            SetVehicleCustomPrimaryColour(vehicle, r, g, b)
        elseif modData.prop == 'color2' then
            ClearVehicleCustomSecondaryColour(vehicle)
            SetVehicleCustomSecondaryColour(vehicle, r, g, b)
        end
    elseif modData.kind == 'vehicleMod' then
        setBestModKitForType(vehicle, modData.modType)
        SetVehicleMod(vehicle, modData.modType, modData.modIndex, false)
    elseif modData.kind == 'windowTint' then
        SetVehicleWindowTint(vehicle, modData.index)
    elseif modData.kind == 'turbo' then
        ToggleVehicleMod(vehicle, 18, modData.enabled == true)
    elseif modData.kind == 'extra' then
        local extraId = tonumber(modData.extraId)
        if extraId then
            SetVehicleExtra(vehicle, extraId, modData.enabled ~= true)
        end
    elseif modData.kind == 'policeExtra' then
        local extraId = tonumber(modData.extraId)
        if extraId then
            SetVehicleExtra(vehicle, extraId, modData.enabled ~= true)
        end
    end
end

function VehicleCatalog.ResolveModFromItemKey(itemKey)
    if not itemKey then return nil end

    local extraId, extraState = itemKey:match('^police_extra_(%d+)_(on|off)$')
    if extraId then
        return { kind = 'policeExtra', extraId = tonumber(extraId), enabled = extraState == 'on' }
    end

    extraId, extraState = itemKey:match('^extra_(%d+)_(on|off)$')
    if extraId then
        return { kind = 'extra', extraId = tonumber(extraId), enabled = extraState == 'on' }
    end

    local modType, modIndex = itemKey:match('_m(%d+)_(-?%d+)$')
    if modType then
        return {
            kind = 'vehicleMod',
            modType = tonumber(modType),
            modIndex = tonumber(modIndex),
        }
    end

    local base, index = itemKey:match('^(.+)_(-?%d+)$')
    if not base and itemKey == 'paint_rgb' then
        base = 'paint_primary'
        index = 'rgb'
    end
    if not base and itemKey:match('_rgb$') then
        base = itemKey:gsub('_rgb$', '')
        index = 'rgb'
    end
    if not base then return nil end

    index = index == 'rgb' and index or tonumber(index)
    local binding = Config.ItemModBindings and Config.ItemModBindings[base]
    if not binding then return nil end

    if binding.kind == 'color' then
        if index == 'rgb' then
            return { kind = 'customColor', prop = binding.prop }
        end
        return { kind = 'color', prop = binding.prop, index = index }
    elseif binding.kind == 'vehicleMod' or binding.kind == 'performance' then
        return { kind = 'vehicleMod', modType = binding.modType, modIndex = index }
    elseif binding.kind == 'windowTint' then
        return { kind = 'windowTint', index = index }
    elseif binding.kind == 'turbo' then
        return { kind = 'turbo', enabled = index == 1 }
    end

    return nil
end

function VehicleCatalog.Preview(vehicle, modData)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or type(modData) ~= 'table' then return end
    if not VehicleCatalog.baselineProps then
        VehicleCatalog.SetBaseline(vehicle)
    end

    requestVehicleControl(vehicle)

    if modData.kind == 'vehicleMod' then
        setBestModKitForType(vehicle, modData.modType)
    else
        SetVehicleModKit(vehicle, 0)
    end

    if modData.kind == 'color' then
        local c1 = VehicleCatalog.baselineProps.color1 or select(1, GetVehicleColours(vehicle))
        local c2 = VehicleCatalog.baselineProps.color2 or select(2, GetVehicleColours(vehicle))
        if type(c1) == 'table' then c1 = select(1, GetVehicleColours(vehicle)) end
        if type(c2) == 'table' then c2 = select(2, GetVehicleColours(vehicle)) end

        ClearVehicleCustomPrimaryColour(vehicle)
        ClearVehicleCustomSecondaryColour(vehicle)

        local paintIndex = tonumber(modData.index) or 0
        if modData.prop == 'color1' then
            SetVehicleColours(vehicle, paintIndex, tonumber(c2) or 0)
        elseif modData.prop == 'color2' then
            SetVehicleColours(vehicle, tonumber(c1) or 0, paintIndex)
        elseif modData.prop == 'pearlescentColor' then
            local _, wheel = GetVehicleExtraColours(vehicle)
            SetVehicleExtraColours(vehicle, paintIndex, wheel)
        end
    elseif modData.kind == 'customColor' then
        VehicleCatalog.ResetPreview(vehicle)
        VehicleCatalog.ApplyModNative(vehicle, modData)
    else
        VehicleCatalog.ResetPreview(vehicle)
        VehicleCatalog.ApplyModNative(vehicle, modData)
    end

    VehicleCatalog.activePreview = modData
end

function VehicleCatalog.EnrichCategories(categories, vehicle, options)
    options = options or {}
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return categories
    end

    local enriched = cloneTable(categories)

    for i = 1, #enriched do
        local cat = enriched[i]
        local keptGroups = {}

        for g = 1, #(cat.groups or {}) do
            local group = cat.groups[g]
            group.items = buildGroupItems(vehicle, group, group.items or {}, options)
            local applicable = {}
            for j = 1, #(group.items or {}) do
                local item = group.items[j]
                if item.mod or item.isColor or item.isRgb then
                    applicable[#applicable + 1] = item
                end
            end
            group.items = applicable
            group.emptyForVehicle = #applicable == 0
            group.hasVehicleItems = #applicable > 0 or group.alwaysShow == true
            if group.hasVehicleItems then
                keptGroups[#keptGroups + 1] = group
            end
        end

        cat.groups = keptGroups
        cat.hasVehicleItems = #keptGroups > 0
    end

    local filtered = {}
    for i = 1, #enriched do
        if enriched[i].hasVehicleItems then
            filtered[#filtered + 1] = enriched[i]
        end
    end

    return filtered
end
