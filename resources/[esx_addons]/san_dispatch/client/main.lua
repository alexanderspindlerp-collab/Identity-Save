local reportedCooldowns = {}
local pendingVehicle = nil
local lastVehicle = 0
local lastShotAt = 0
local lastAssaultAt = 0
local lastWeaponScan = 0
local witnessNames = {'Jonas','Thomas','Mikkel','Sara','Emma','Oliver','Julie','Nikolaj','Mathias','Freja','Andreas','Sofie'}

local function dbg(...)
    if Config.Debug then print('[san_dispatch:client]', ...) end
end

local function now()
    return GetGameTimer()
end

local function rndChance(pct)
    pct = tonumber(pct or 0) or 0
    if pct >= 100 then return true end
    if pct <= 0 then return false end
    return math.random(1, 100) <= pct
end

local function isPlayerPed(ped)
    return ped and ped ~= 0 and IsPedAPlayer(ped)
end

local function isNpcPed(ped)
    if not ped or ped == 0 then return false end
    if isPlayerPed(ped) then return false end
    if IsPedDeadOrDying(ped, true) then return false end
    if not DoesEntityExist(ped) then return false end
    return true
end

local function streetName(coords)
    local s1, s2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local a = s1 and GetStreetNameFromHashKey(s1) or ''
    local b = s2 and GetStreetNameFromHashKey(s2) or ''
    if b and b ~= '' then return (a ~= '' and (a .. ' / ' .. b) or b) end
    return a ~= '' and a or 'Ukendt lokation'
end

local function areaKey(coords, typ)
    local g = tonumber(Config.AreaGrid or 180.0) or 180.0
    return ('%s:%s:%s'):format(typ or 'event', math.floor(coords.x / g), math.floor(coords.y / g))
end

local function hasLos(witness, targetPed, targetCoords)
    if not Config.LineOfSight then return true end
    if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
        if HasEntityClearLosToEntity(witness, targetPed, 17) then return true end
    end
    local wc = GetEntityCoords(witness)
    local ray = StartShapeTestLosProbe(wc.x, wc.y, wc.z + 0.7, targetCoords.x, targetCoords.y, targetCoords.z + 0.7, -1, witness, 7)
    local _, hit = GetShapeTestResult(ray)
    return hit == 0
end

local function collectWitnesses(coords, radius, targetPed)
    local playerPed = PlayerPedId()
    local pool = GetGamePool('CPed')
    local candidates = {}
    for i=1, #pool do
        local ped = pool[i]
        if isNpcPed(ped) and ped ~= playerPed then
            local pc = GetEntityCoords(ped)
            local dist = #(pc - coords)
            if dist <= radius and hasLos(ped, targetPed or playerPed, coords) then
                candidates[#candidates+1] = { ped = ped, dist = dist }
            end
        end
    end
    table.sort(candidates, function(a,b) return a.dist < b.dist end)
    local max = math.min(Config.MaxWitnesses or 5, #candidates)
    local result = {}
    for i=1, max do result[#result+1] = candidates[i] end
    return result
end

local function witnessStatements(eventType, witnesses, street, vehicleInfo)
    local statements = {}
    local max = math.min(Config.MaxWitnesses or 5, #witnesses)
    for i=1, max do
        local name = witnessNames[math.random(1, #witnessNames)]
        local text
        if eventType == 'shots_fired' then
            text = ('%s fortæller at der blev skudt i området ved %s.'):format(name, street)
        elseif eventType == 'assault' then
            text = ('%s fortæller at en person overfaldt en borger ved %s.'):format(name, street)
        elseif eventType == 'vehicle_theft' then
            text = ('%s fortæller at en person forsøgte at stjæle et køretøj ved %s.'):format(name, street)
        elseif eventType == 'carjacking' then
            text = ('%s fortæller at en fører blev tvunget ud af sit køretøj ved %s.'):format(name, street)
        elseif eventType == 'explosion' then
            text = ('%s fortæller at der var en eksplosion i området ved %s.'):format(name, street)
        elseif eventType == 'drug_sale' then
            text = ('%s fortæller at en person forsøgte at sælge stoffer på gaden ved %s.'):format(name, street)
        else
            text = ('%s fortæller at en person gik rundt med synligt våben ved %s.'):format(name, street)
        end
        statements[#statements+1] = text
    end
    return statements
end

local function signalement(eventType, weaponName, vehicle)
    local ped = PlayerPedId()
    local inVeh = IsPedInAnyVehicle(ped, false)
    local data = {
        gender = IsPedMale(ped) and 'Mand' or 'Kvinde',
        mask = GetPedDrawableVariation(ped, 1) > 0 and 'Mulig maske' or 'Ingen tydelig maske',
        hat = GetPedPropIndex(ped, 0) ~= -1 and 'Hovedbeklædning' or 'Ingen tydelig hovedbeklædning',
        glasses = GetPedPropIndex(ped, 1) ~= -1 and 'Briller' or 'Ingen tydelige briller',
        weapon = weaponName or 'Ukendt',
        movement = inVeh and 'I køretøj' or 'Til fods'
    }
    return data
end

local function vehicleData(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    local model = GetEntityModel(vehicle)
    return {
        type = GetVehicleClass(vehicle),
        model = GetDisplayNameFromVehicleModel(model),
        name = GetLabelText(GetDisplayNameFromVehicleModel(model)),
        plate = (GetVehicleNumberPlateText(vehicle) or ''):gsub('^%s*(.-)%s*$', '%1'),
        color1 = select(1, GetVehicleColours(vehicle))
    }
end

local function canReport(eventType, coords)
    local key = areaKey(coords, eventType)
    local cd = tonumber((Config.Cooldown or {})[eventType] or 60000) or 60000
    local n = now()
    if reportedCooldowns[key] and (n - reportedCooldowns[key]) < cd then
        dbg('cooldown', eventType, key)
        return false
    end
    reportedCooldowns[key] = n
    return true
end

local function sendDispatch(eventType, opts)
    opts = opts or {}
    local ped = PlayerPedId()
    local coords = opts.coords or GetEntityCoords(ped)
    local radius = opts.radius or Config.WitnessRadius or 65.0
    local witnesses = opts.witnesses or collectWitnesses(coords, radius, opts.targetPed or ped)

    if Config.RequireWitness and #witnesses <= 0 and not opts.allowNoWitness then
        dbg('no witnesses', eventType)
        return false
    end

    local chance = opts.chance or ((Config.Chance or {})[eventType] or 100)
    if not rndChance(chance) then
        dbg('chance failed', eventType, chance)
        return false
    end

    if not canReport(eventType, coords) then return false end

    local street = streetName(coords)
    local statements = witnessStatements(eventType, witnesses, street, opts.vehicle)
    local witnessCount = math.max(1, math.min(Config.MaxWitnesses or 5, #witnesses))
    local title = 'Mistænkelig aktivitet'
    local priority = 3

    if eventType == 'weapon_seen' or eventType == 'longgun_seen' then
        title = 'Mistænkelig person med våben'; priority = eventType == 'longgun_seen' and 2 or 3
    elseif eventType == 'shots_fired' then
        title = 'Igangværende skyderi'; priority = 1
    elseif eventType == 'assault' then
        title = 'Vold mod borger'; priority = 2
    elseif eventType == 'vehicle_theft' then
        title = 'Igangværende biltyveri'; priority = 2
    elseif eventType == 'carjacking' then
        title = 'Carjacking'; priority = 1
    elseif eventType == 'explosion' then
        title = 'Eksplosion'; priority = 1
    elseif eventType == 'drug_sale' then
        title = 'Anmeldelse: stofsalg'; priority = 2
    end

    local weaponHash = GetSelectedPedWeapon(ped)
    local weaponName = opts.weaponName or tostring(weaponHash)
    local veh = opts.vehicle or GetVehiclePedIsIn(ped, false)
    local meta = {
        witnesses = { total = witnessCount },
        witnessStatements = statements,
        signalement = signalement(eventType, weaponName, veh),
        vehicle = vehicleData(veh),
        photo = nil,
        noPhotoText = 'Intet foto modtaget fra vidne'
    }

    local desc
    if eventType == 'shots_fired' then
        desc = ('Borger anmelder skud i området · Vidner: %s'):format(witnessCount)
    elseif eventType == 'assault' then
        desc = ('Borger anmelder vold mod en NPC/borger · Vidner: %s'):format(witnessCount)
    elseif eventType == 'vehicle_theft' then
        desc = ('Borger anmelder igangværende biltyveri · Vidner: %s'):format(witnessCount)
    elseif eventType == 'carjacking' then
        desc = ('Borger anmelder carjacking · Vidner: %s'):format(witnessCount)
    elseif eventType == 'explosion' then
        desc = ('Borger anmelder eksplosion · Vidner: %s'):format(witnessCount)
    elseif eventType == 'drug_sale' then
        desc = ('Borger anmelder stofsalg på gaden · Vidner: %s'):format(witnessCount)
    else
        desc = ('Borger har set en person med synligt våben · Vidner: %s'):format(witnessCount)
    end

    TriggerServerEvent('san_dispatch:report', {
        type = eventType,
        title = title,
        description = desc,
        street = street,
        x = coords.x, y = coords.y, z = coords.z,
        priority = priority,
        witnessCount = witnessCount,
        metadata = meta
    })

    dbg('sent', eventType, title, street, 'witnesses='..witnessCount)
    return true
end

-- Weapon seen: low chance, slow scan.
CreateThread(function()
    math.randomseed(GetGameTimer())
    while true do
        Wait(Config.Tick.weapon or 2500)
        local ped = PlayerPedId()
        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
            local weapon = GetSelectedPedWeapon(ped)
            if weapon and not Config.IgnoredWeapons[weapon] and weapon ~= `WEAPON_UNARMED` then
                local group = GetWeapontypeGroup(weapon)
                local typ = Config.LongGunGroups[group] and 'longgun_seen' or 'weapon_seen'
                sendDispatch(typ, { radius = Config.WitnessRadius, chance = Config.Chance[typ], weaponName = tostring(weapon) })
            end
        end
    end
end)

-- Shots fired: direct and reliable. Does not trigger on reload because IsPedShooting must be true.
CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        if IsPedShooting(ped) then
            local t = now()
            if t - lastShotAt > 1200 then
                lastShotAt = t
                sendDispatch('shots_fired', { radius = Config.ShotWitnessRadius, chance = Config.Chance.shots_fired })
            end
        end
    end
end)

-- Assault: aggressive fallback because GTA damage events can be unreliable on local NPCs.
CreateThread(function()
    while true do
        Wait(Config.Tick.assault or 120)
        local ped = PlayerPedId()
        local armedMelee = IsPedInMeleeCombat(ped) or IsControlPressed(0, 140) or IsControlPressed(0, 141) or IsControlPressed(0, 142)
        if armedMelee and (now() - lastAssaultAt) > 2500 then
            local pcoords = GetEntityCoords(ped)
            local victim = 0
            local best = 3.0
            for _, npc in ipairs(GetGamePool('CPed')) do
                if isNpcPed(npc) then
                    local d = #(GetEntityCoords(npc) - pcoords)
                    if d < best and (IsPedInMeleeCombat(npc) or IsPedRagdoll(npc) or HasEntityBeenDamagedByEntity(npc, ped, true)) then
                        victim = npc; best = d
                    end
                end
            end
            if victim ~= 0 then
                lastAssaultAt = now()
                sendDispatch('assault', { coords = GetEntityCoords(victim), radius = Config.AssaultWitnessRadius, targetPed = victim, chance = Config.Chance.assault, allowNoWitness = true, witnesses = collectWitnesses(GetEntityCoords(victim), Config.AssaultWitnessRadius, victim) })
                ClearEntityLastDamageEntity(victim)
            end
        end
    end
end)

-- Vehicle theft / carjacking.
CreateThread(function()
    while true do
        Wait(Config.Tick.vehicle or 250)
        local ped = PlayerPedId()
        local trying = GetVehiclePedIsTryingToEnter(ped)
        if trying and trying ~= 0 and DoesEntityExist(trying) then
            local driver = GetPedInVehicleSeat(trying, -1)
            pendingVehicle = {
                vehicle = trying,
                at = now(),
                hadNpcDriver = driver ~= 0 and not IsPedAPlayer(driver),
                coords = GetEntityCoords(trying)
            }
        end

        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and veh ~= lastVehicle then
            lastVehicle = veh
            local pv = pendingVehicle
            if pv and pv.vehicle == veh and (now() - pv.at) < 12000 then
                local typ = pv.hadNpcDriver and 'carjacking' or 'vehicle_theft'
                sendDispatch(typ, { coords = GetEntityCoords(veh), radius = Config.VehicleWitnessRadius, vehicle = veh, chance = Config.Chance[typ] })
                pendingVehicle = nil
            end
        elseif veh == 0 then
            lastVehicle = 0
        end
    end
end)

-- Game event backup.
AddEventHandler('gameEventTriggered', function(name, args)
    local ped = PlayerPedId()
    if name == 'CEventNetworkEntityDamage' then
        local victim = args and args[1]
        local attacker = args and args[2]
        if attacker == ped and isNpcPed(victim) and (now() - lastAssaultAt) > 1800 then
            lastAssaultAt = now()
            sendDispatch('assault', { coords = GetEntityCoords(victim), radius = Config.AssaultWitnessRadius, targetPed = victim, chance = Config.Chance.assault, allowNoWitness = true })
        end
    elseif name == 'CEventExplosionHeard' or name == 'CEventShockingExplosion' then
        sendDispatch('explosion', { radius = Config.ShotWitnessRadius, chance = Config.Chance.explosion })
    elseif name == 'CEventGunShot' or name == 'CEventShockingGunshotFired' then
        if now() - lastShotAt > 1200 then
            lastShotAt = now()
            sendDispatch('shots_fired', { radius = Config.ShotWitnessRadius, chance = Config.Chance.shots_fired })
        end
    end
end)

if Config.EnableTestCommands then
    RegisterCommand('testdispatch', function()
        sendDispatch('shots_fired', { chance = 100, allowNoWitness = true, witnesses = {{ped=PlayerPedId(), dist=1.0}} })
    end)

    RegisterCommand('testallevents', function()
        local types = {'weapon_seen','shots_fired','assault','vehicle_theft','carjacking','explosion'}
        CreateThread(function()
            for _, typ in ipairs(types) do
                sendDispatch(typ, { chance = 100, allowNoWitness = true, witnesses = {{ped=PlayerPedId(), dist=1.0}} })
                Wait(900)
            end
        end)
    end)

    RegisterCommand('dispatchstatus', function()
        print('[san_dispatch] clean v120 kører. MDT event: '..tostring(Config.MdtEvent))
        print('[san_dispatch] Hvis /testdispatch virker men events ikke gør: tjek NPC-vidner, job/duty og cooldown.')
    end)
end
