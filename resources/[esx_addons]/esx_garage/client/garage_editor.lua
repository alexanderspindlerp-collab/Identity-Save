local dynamicGarageNames = {}
local garageBlips = {}
local impoundBlips = {}
local editorPreview = false

local function trim(v)
    return tostring(v or ''):gsub('^%s*(.-)%s*$', '%1')
end

local function playerPlacement()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local coords = GetEntityCoords(veh)
        return {
            x = coords.x + 0.0,
            y = coords.y + 0.0,
            z = coords.z + 0.0,
            heading = GetEntityHeading(veh) + 0.0,
        }, true
    end

    local coords = GetEntityCoords(ped)
    return {
        x = coords.x + 0.0,
        y = coords.y + 0.0,
        z = coords.z + 0.0,
        heading = GetEntityHeading(ped) + 0.0,
    }, false
end

local function removeDynamicGaragesFromConfig()
    for i = 1, #dynamicGarageNames do
        Config.Garages[dynamicGarageNames[i]] = nil
    end
end

function RefreshGarageBlips()
    for _, blip in pairs(garageBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    garageBlips = {}

    for name, garage in pairs(Config.Garages or {}) do
        if garage and garage.EntryPoint then
            local blip = AddBlipForCoord(garage.EntryPoint.x, garage.EntryPoint.y, garage.EntryPoint.z)
            SetBlipSprite(blip, garage.Sprite or 357)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, garage.Scale or 0.8)
            SetBlipColour(blip, garage.Colour or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(garage.Label or TranslateCap('parking_blip_name'))
            EndTextCommandSetBlipName(blip)
            garageBlips[name] = blip
        end
    end
end

local function refreshImpoundBlips()
    for _, blip in pairs(impoundBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    impoundBlips = {}

    for name, impound in pairs(Config.Impounds or {}) do
        if impound and impound.GetOutPoint then
            local blip = AddBlipForCoord(impound.GetOutPoint.x, impound.GetOutPoint.y, impound.GetOutPoint.z)
            SetBlipSprite(blip, impound.Sprite or 524)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, impound.Scale or 0.8)
            SetBlipColour(blip, impound.Colour or 1)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(TranslateCap('Impound_blip_name'))
            EndTextCommandSetBlipName(blip)
            impoundBlips[name] = blip
        end
    end
end

local function applyDynamicGarages(garages, names)
    removeDynamicGaragesFromConfig()
    dynamicGarageNames = names or {}

    for name, garage in pairs(garages or {}) do
        Config.Garages[name] = garage
    end

    RefreshGarageBlips()
end

RegisterNetEvent('esx_garage:syncDynamicGarages', function(garages, names)
    applyDynamicGarages(garages, names)
end)

local function getNearestDynamicGarage(maxDistance)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestName, closestGarage, closestDistance

    for i = 1, #dynamicGarageNames do
        local name = dynamicGarageNames[i]
        local garage = Config.Garages[name]
        if garage and garage.EntryPoint then
            local entry = vector3(garage.EntryPoint.x, garage.EntryPoint.y, garage.EntryPoint.z)
            local distance = #(playerCoords - entry)
            if (not closestDistance or distance < closestDistance) and (not maxDistance or distance <= maxDistance) then
                closestName = name
                closestGarage = garage
                closestDistance = distance
            end
        end
    end

    return closestName, closestGarage, closestDistance
end

local function promptCreateGarage()
    local placement = select(1, playerPlacement())
    local input = lib.inputDialog('Opret garage', {
        { type = 'input', label = 'Navn (ID)', placeholder = 'MidtbyGarage', required = false },
        { type = 'input', label = 'Visningsnavn', placeholder = 'Midtby Garage', required = true },
    })
    if not input then return end

    TriggerServerEvent('esx_garage:editorCreateGarage', {
        name = trim(input[1]),
        label = trim(input[2]),
        entry = { x = placement.x, y = placement.y, z = placement.z },
        spawn = { x = placement.x, y = placement.y, z = placement.z, heading = placement.heading },
    })
end

local function promptUpdateEntry()
    local maxDistance = (Config.GarageEditor and Config.GarageEditor.RemoveDistance) or 25.0
    local name = getNearestDynamicGarage(maxDistance)
    if not name then
        lib.notify({ title = 'Garage editor', description = 'Ingen dynamisk garage i nærheden.', type = 'error' })
        return
    end

    local placement = select(1, playerPlacement())
    TriggerServerEvent('esx_garage:editorUpdateEntry', name, { x = placement.x, y = placement.y, z = placement.z })
end

local function promptUpdateSpawn(selectedName)
    local name = selectedName
    if not name then
        local maxDistance = (Config.GarageEditor and Config.GarageEditor.RemoveDistance) or 25.0
        name = getNearestDynamicGarage(maxDistance)
    end
    if not name then
        lib.notify({ title = 'Garage editor', description = 'Ingen dynamisk garage i nærheden.', type = 'error' })
        return
    end

    local placement = select(1, playerPlacement())
    TriggerServerEvent('esx_garage:editorUpdateSpawn', name, {
        x = placement.x,
        y = placement.y,
        z = placement.z,
        heading = placement.heading,
    })
end

local function promptAddSpawnPoint()
    local maxDistance = (Config.GarageEditor and Config.GarageEditor.RemoveDistance) or 25.0
    local name = getNearestDynamicGarage(maxDistance)
    if not name then
        lib.notify({ title = 'Garage editor', description = 'Ingen dynamisk garage i nærheden.', type = 'error' })
        return
    end

    local placement = select(1, playerPlacement())
    TriggerServerEvent('esx_garage:editorAddSpawnPoint', name, {
        x = placement.x,
        y = placement.y,
        z = placement.z,
        heading = placement.heading,
    })
end

local function promptRemoveGarage()
    local maxDistance = (Config.GarageEditor and Config.GarageEditor.RemoveDistance) or 25.0
    local name, garage, distance = getNearestDynamicGarage(maxDistance)
    if not name then
        lib.notify({ title = 'Garage editor', description = 'Ingen dynamisk garage i nærheden.', type = 'error' })
        return
    end

    local confirm = lib.alertDialog({
        header = 'Fjern garage',
        content = ('Er du sikker på at du vil fjerne "%s" (%s)?'):format(garage.Label or name, name),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end

    TriggerServerEvent('esx_garage:editorRemoveGarage', name)
end

local function openGarageEditorMenu()
    lib.registerContext({
        id = 'esx_garage_editor_menu',
        title = 'Garage editor',
        options = {
            {
                title = 'Opret garage her',
                description = 'Placer indgang + første spawn på din position',
                icon = 'plus',
                onSelect = promptCreateGarage,
            },
            {
                title = 'Flyt indgang hertil',
                description = 'Opdaterer nærmeste dynamiske garage',
                icon = 'location-dot',
                onSelect = promptUpdateEntry,
            },
            {
                title = 'Sæt spawn hertil',
                description = 'Opdaterer hoved-spawn for nærmeste garage',
                icon = 'car',
                onSelect = function()
                    promptUpdateSpawn(nil)
                end,
            },
            {
                title = 'Tilføj ekstra spawn',
                description = 'Tilføjer endnu et spawn-punkt til nærmeste garage',
                icon = 'square-plus',
                onSelect = promptAddSpawnPoint,
            },
            {
                title = 'Fjern nærmeste garage',
                description = 'Sletter kun garager oprettet via /setgarage',
                icon = 'trash',
                onSelect = promptRemoveGarage,
            },
            {
                title = 'Vis placeringer',
                description = 'Viser midlertidige markører for alle dynamiske garager',
                icon = 'eye',
                onSelect = function()
                    editorPreview = not editorPreview
                    lib.notify({
                        title = 'Garage editor',
                        description = editorPreview and 'Viser garage-markører.' or 'Skjuler garage-markører.',
                        type = 'inform',
                    })
                end,
            },
        },
    })
    lib.showContext('esx_garage_editor_menu')
end

CreateThread(function()
    while true do
        if editorPreview then
            for i = 1, #dynamicGarageNames do
                local garage = Config.Garages[dynamicGarageNames[i]]
                if garage and garage.EntryPoint then
                    DrawMarker(1, garage.EntryPoint.x, garage.EntryPoint.y, garage.EntryPoint.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.0, 50, 200, 50, 160, false, true, 2, false, false, false, false)
                end
                if garage and garage.SpawnPoint then
                    DrawMarker(1, garage.SpawnPoint.x, garage.SpawnPoint.y, garage.SpawnPoint.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 50, 120, 255, 160, false, true, 2, false, false, false, false)
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterCommand('setgarage', function(_, args)
    if Config.GarageEditor and Config.GarageEditor.Enabled == false then
        lib.notify({ title = 'Garage editor', description = 'Editoren er slået fra.', type = 'error' })
        return
    end

    local ok, message = lib.callback.await('esx_garage:canEditGarages', false)
    if not ok then
        lib.notify({ title = 'Garage editor', description = message or 'Ingen adgang.', type = 'error' })
        return
    end

    local action = trim(args[1] or ''):lower()
    if action == 'add' or action == 'opret' then
        promptCreateGarage()
    elseif action == 'remove' or action == 'fjern' then
        promptRemoveGarage()
    elseif action == 'spawn' then
        promptUpdateSpawn(trim(args[2]) ~= '' and trim(args[2]) or nil)
    elseif action == 'entry' or action == 'indgang' then
        promptUpdateEntry()
    else
        openGarageEditorMenu()
    end
end, false)

TriggerEvent('chat:addSuggestion', '/setgarage', 'Placer eller fjern garager (admin)', {
    { name = 'handling', help = 'add | remove | spawn | entry | (tom = menu)' },
    { name = 'garageId', help = 'Valgfri garage-ID ved spawn' },
})

exports('RefreshGarageBlips', RefreshGarageBlips)

CreateThread(function()
    Wait(1500)
    RefreshGarageBlips()
    refreshImpoundBlips()
end)
