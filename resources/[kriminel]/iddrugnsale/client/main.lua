local State = {
    farms = {},
    process = {},
    dealers = {},
    prices = {},
}

local spawnedDealers = {}
local dealerTargets = {}
local farmZones = {}
local processZones = {}
local interactionThreadRunning = false
local markerThreadRunning = false
local interactKeybind = nil
local activeInteract = nil
local nuiOpen = false
local currentSellTarget = nil
local interacting = false
local soldNpcNetIds = {}
local soldNpcPeds = {}
local sellInProgress = false
local openSellMenu
local runFarmAction
local runProcessAction
local runNpcSellAction
local triggerActiveInteract
local worldPromptVisible = false
local npcOxTargetRegistered = false

local function notify(msg, ntype)
    lib.notify({ description = msg, type = ntype or 'inform' })
end

local function awaitServer(name, ...)
    local ok, response = pcall(lib.callback.await, name, false, ...)
    if not ok or type(response) ~= 'table' then
        return {
            ok = false,
            message = 'Server svarede ikke — prøv igen om et øjeblik.',
        }
    end
    return response
end

local function textUiOptions(icon)
    return {
        position = Config.TextUI.position or 'right-center',
        icon = icon or 'hand',
        iconColor = Config.TextUI.iconColor or '#00f8b9',
    }
end

local function isSellTargetKeyHeld()
    if Config.SellRequiresTargetKey == false then return true end

    local key = Config.SellTargetKey or 19
    EnableControlAction(0, key, true)
    return IsControlPressed(0, key) or IsDisabledControlPressed(0, key)
end

local function usesOxTargetForSell()
    return GetResourceState('ox_target') == 'started'
end

local function hideWorldPrompt()
    if not worldPromptVisible then return end
    SendNUIMessage({ action = 'worldPrompt', show = false })
    worldPromptVisible = false
end

local function showPrompt(text, icon)
    hideWorldPrompt()
    lib.showTextUI(text, textUiOptions(icon))
end

local function getNpcPromptCoords(ped)
    if not ped or not DoesEntityExist(ped) then return nil end

    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.35)
    if head and head.x ~= 0.0 and head.y ~= 0.0 then
        return head
    end

    local coords = GetEntityCoords(ped)
    return vector3(coords.x, coords.y, coords.z + 1.05)
end

local function getNpcNetId(ped)
    if not ped or not DoesEntityExist(ped) then return nil end
    if NetworkGetEntityIsNetworked and not NetworkGetEntityIsNetworked(ped) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(ped)
    if netId and netId > 0 then return netId end
    return nil
end

local function buildNpcTarget(ped, pedCoords)
    return {
        ped = ped,
        netId = getNpcNetId(ped),
        model = GetEntityModel(ped),
        x = pedCoords.x,
        y = pedCoords.y,
        z = pedCoords.z,
    }
end

local function isNpcAlreadySold(target)
    if not target then return false end
    if target.ped and soldNpcPeds[target.ped] then return true end
    if target.netId and soldNpcNetIds[target.netId] then return true end

    if target.model and target.x and target.y and target.z then
        local posKey = ('pos:%s:%d:%d:%d'):format(
            target.model,
            math.floor(target.x * 2),
            math.floor(target.y * 2),
            math.floor(target.z * 2)
        )
        if soldNpcNetIds[posKey] then return true end
    end

    return false
end

local function markNpcAsSold(target)
    if not target then return end
    if target.netId then
        soldNpcNetIds[target.netId] = true
    end
    if target.ped and DoesEntityExist(target.ped) then
        soldNpcPeds[target.ped] = true
    end
    if target.model and target.x and target.y and target.z then
        local posKey = ('pos:%s:%d:%d:%d'):format(
            target.model,
            math.floor(target.x * 2),
            math.floor(target.y * 2),
            math.floor(target.z * 2)
        )
        soldNpcNetIds[posKey] = true
    end
end

local function updateWorldPrompt(ped, text, showKey)
    local anchor = getNpcPromptCoords(ped)
    if not anchor then
        hideWorldPrompt()
        return
    end

    lib.hideTextUI()

    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(anchor.x, anchor.y, anchor.z)
    if not onScreen or sx < 0.01 or sx > 0.99 or sy < 0.01 or sy > 0.99 then
        hideWorldPrompt()
        return
    end

    SendNUIMessage({
        action = 'worldPrompt',
        show = true,
        text = text or 'Sælg Stoffer',
        showKey = showKey ~= false,
        x = sx * 100.0,
        y = sy * 100.0,
    })
    worldPromptVisible = true
end

local function hideAllPrompts()
    lib.hideTextUI()
    hideWorldPrompt()
end

local function isSpotEnabled(value)
    return value == 1 or value == true or value == '1'
end

local function isMarkerVisible(value)
    return value == 1 or value == true or value == '1'
end

local function loadModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return false end
        Wait(0)
    end
    return hash
end

local function playProgress(label, duration, anim)
    if anim and anim.dict then
        lib.requestAnimDict(anim.dict)
    end

    return lib.progressCircle({
        duration = duration,
        position = 'bottom',
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim and { dict = anim.dict, clip = anim.clip, flag = 49 } or nil,
    })
end

local function isNpcSellable(ped)
    if not ped or ped == cache.ped then return false end
    if not DoesEntityExist(ped) then return false end
    if IsPedAPlayer(ped) then return false end
    if GetResourceState('ya_test_npc') == 'started' and exports.ya_test_npc:IsTestNpc(ped) then return false end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false end
    if not IsPedHuman(ped) then return false end
    return true
end

local function resolveNpcPed(target)
    if not target then return nil end

    if target.ped and DoesEntityExist(target.ped) then
        return target.ped
    end

    if target.netId and target.netId > 0 then
        local ped = NetworkGetEntityFromNetworkId(target.netId)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            return ped
        end
    end

    if target.x and target.y and target.z then
        local coords = vector3(target.x, target.y, target.z)
        local ped = lib.getClosestPed(coords, 2.5)
        if isNpcSellable(ped) then
            return ped
        end
    end

    return nil
end

local function requestEntityControl(entity, timeout)
    if not entity or not DoesEntityExist(entity) then return false end

    timeout = timeout or 2000
    local endTime = GetGameTimer() + timeout
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < endTime do
        NetworkRequestControlOfEntity(entity)
        Wait(0)
    end

    return NetworkHasControlOfEntity(entity)
end

local function propVec3(tbl)
    if not tbl then return vec3(0.0, 0.0, 0.0) end
    return vec3(tbl.x or 0.0, tbl.y or 0.0, tbl.z or 0.0)
end

local function attachHandProp(ped, propCfg, fallbacks)
    if not propCfg then return nil end

    local models = {}
    if propCfg.model then models[#models + 1] = propCfg.model end
    for i = 1, #(fallbacks or {}) do
        models[#models + 1] = fallbacks[i]
    end

    for i = 1, #models do
        local modelName = models[i]
        local ok, hash = pcall(lib.requestModel, modelName)
        if ok and hash then
            local coords = GetEntityCoords(ped)
            local prop = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, false, false, false)
            if prop and prop ~= 0 then
                SetEntityCollision(prop, false, false)
                local pos = propCfg.pos or {}
                local rot = propCfg.rot or {}
                AttachEntityToEntity(
                    prop,
                    ped,
                    GetPedBoneIndex(ped, propCfg.bone or 60309),
                    pos.x or 0.1, pos.y or 0.02, pos.z or 0.0,
                    rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                    true, true, false, true, 0, true
                )
                SetModelAsNoLongerNeeded(hash)
                return prop
            end
        end
    end

    return nil
end

local function resolvePropModel(propCfg, fallbacks)
    if not propCfg or not propCfg.model then return nil end

    local models = { propCfg.model }
    for i = 1, #(fallbacks or {}) do
        models[#models + 1] = fallbacks[i]
    end

    for i = 1, #models do
        local ok = pcall(lib.requestModel, models[i])
        if ok then return models[i] end
    end

    return nil
end

local function buildProgressProp(propCfg)
    local model = resolvePropModel(propCfg, { 'prop_mp_drug_pack_red', 'bkr_prop_weed_01_small_01c', 'prop_meth_bag_01' })
    if not model then return nil end

    return {
        model = model,
        bone = propCfg.bone or 60309,
        pos = propVec3(propCfg.pos),
        rot = propVec3(propCfg.rot),
    }
end

local function prepareNpcForDeal(npc)
    if not npc or not DoesEntityExist(npc) then return false end

    requestEntityControl(npc, 3000)
    SetEntityAsMissionEntity(npc, true, true)
    SetPedKeepTask(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetPedCanPlayAmbientAnims(npc, false)
    SetPedCanRagdollFromPlayerImpact(npc, false)
    TaskStandStill(npc, 15000)
    return true
end

local function releaseNpcAfterDeal(npc)
    if not npc or not DoesEntityExist(npc) then return end

    SetBlockingOfNonTemporaryEvents(npc, false)
    SetPedKeepTask(npc, false)
    SetPedCanPlayAmbientAnims(npc, true)
    SetPedCanRagdollFromPlayerImpact(npc, true)
    FreezeEntityPosition(npc, false)
    ClearPedTasks(npc)
    SetEntityAsMissionEntity(npc, false, true)
end

local function cleanupStreetDeal(player, npc, props)
    for i = 1, #props do
        if props[i] and DoesEntityExist(props[i]) then
            DeleteEntity(props[i])
        end
    end

    ClearPedSecondaryTask(player)
    releaseNpcAfterDeal(npc)
end

local function playStreetDeal(target, label, onComplete)
    local cfg = Config.SellDeal or {}
    local anim = cfg.anim or {}
    local player = cache.ped
    local npc = resolveNpcPed(target)

    if not npc or not isNpcSellable(npc) then
        onComplete(false)
        return
    end

    if type(target) == 'table' then
        target.ped = npc
    end
    if currentSellTarget then
        currentSellTarget.ped = npc
    end

    local duration = tonumber(Config.SellDealDuration) or 4000
    local npcCoords = GetEntityCoords(npc)
    if #(GetEntityCoords(player) - npcCoords) > (Config.DealerInteractDistance or 4.0) + 1.5 then
        onComplete(false)
        return
    end

    CreateThread(function()
        if not prepareNpcForDeal(npc) then
            onComplete(false)
            return
        end

        TaskTurnPedToFaceEntity(player, npc, 1000)
        TaskTurnPedToFaceEntity(npc, player, 1000)
        Wait(1000)

        if not DoesEntityExist(npc) then
            onComplete(false)
            return
        end

        if anim.dict then
            lib.requestAnimDict(anim.dict)
        end

        if anim.dict and anim.npcClip then
            TaskPlayAnim(npc, anim.dict, anim.npcClip, 8.0, -8.0, duration, anim.flag or 49, 0.0, false, false, false)
        end

        Wait(450)

        if not DoesEntityExist(npc) then
            cleanupStreetDeal(player, npc, {})
            onComplete(false)
            return
        end

        local props = {}
        local npcProp = attachHandProp(npc, cfg.npcProp, { 'prop_cash_note_01', 'bkr_prop_money_unsorted_01' })
        if npcProp then props[#props + 1] = npcProp end

        local progressProp = buildProgressProp(cfg.playerProp)
        local success = lib.progressCircle({
            duration = duration,
            position = 'bottom',
            label = ('Sælger %s...'):format(label or 'stof'),
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = anim.dict and anim.playerClip and {
                dict = anim.dict,
                clip = anim.playerClip,
                flag = anim.flag or 49,
            } or nil,
            prop = progressProp,
        }) == true

        cleanupStreetDeal(player, npc, props)
        onComplete(success)
    end)
end

local function clearDealers()
    for id, ped in pairs(spawnedDealers) do
        if dealerTargets[id] and GetResourceState('ox_target') == 'started' then
            pcall(function() exports.ox_target:removeLocalEntity(ped) end)
        end
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    spawnedDealers = {}
    dealerTargets = {}
end

local function normalizeDrugKey(key)
    if type(key) ~= 'string' then return nil end
    key = key:lower()
    if Config.Drugs[key] then return key end

    local legacy = {
        hash_rav = 'hash',
        skunk_rav = 'skunk',
        kokain_rav = 'kokain',
    }

    return legacy[key]
end

local function spotCoords(row)
    return vector3(tonumber(row.x) or 0.0, tonumber(row.y) or 0.0, tonumber(row.z) or 0.0)
end

local function clearFarmZones()
    farmZones = {}
end

local function clearProcessZones()
    processZones = {}
end

local function findNearestSellNpc(playerCoords, maxDist)
    if Config.SellToAllNpcs == false then
        return nil
    end

    local ped, pedCoords = lib.getClosestPed(playerCoords, maxDist)
    if not isNpcSellable(ped) then
        return nil
    end

    local dist = #(playerCoords - pedCoords)
    return buildNpcTarget(ped, pedCoords), dist
end

local function hasSellableBags()
    for drugKey, drug in pairs(Config.Drugs) do
        local sellItem = drug.sellItem
        if sellItem and (exports.ox_inventory:GetItemCount(sellItem) or 0) > 0 then
            return true
        end
    end
    return false
end

local function hasLooseDrugGrams()
    for _, slot in pairs(exports.ox_inventory:GetPlayerItems() or {}) do
        if not slot or not slot.name or not slot.metadata then goto continue end

        for _, drug in pairs(Config.Drugs) do
            local looseItem = drug.looseItem or drug.productItem
            if slot.name == looseItem then
                local grams = math.floor(tonumber(slot.metadata.grams) or 0)
                if grams > 0 then
                    return true
                end
            end
        end

        ::continue::
    end
    return false
end

local function shouldDrawMarker(showMarkerFlag, currentDistance)
    if not isMarkerVisible(showMarkerFlag) then
        return false
    end

    if Config.AlwaysShowNearbyMarker and currentDistance <= (Config.NearbyMarkerDistance or 10.0) then
        return true
    end

    return currentDistance <= (Config.FarmMarkerDistance or 25.0)
end

local function spotVector(row)
    return vector3(tonumber(row.x) or 0.0, tonumber(row.y) or 0.0, tonumber(row.z) or 0.0)
end

runFarmAction = function(farm)
    if not farm or not farm.id then
        notify('Farm-data mangler — genindlæs iddrugnsale.', 'error')
        return
    end

    local farmId = tonumber(farm.id) or farm.id
    local drug = Config.Drugs[normalizeDrugKey(farm.drug_key)]
    local rewardLabel = farm.reward_label or (drug and drug.label) or 'stof'

    local check = awaitServer('iddrugnsale:canFarm', farmId)
    if not check.ok then
        notify(check.message or 'Kan ikke høste her.', 'error')
        return
    end

    if playProgress('Høster ' .. rewardLabel, Config.FarmDuration, Config.FarmAnim) then
        local result = awaitServer('iddrugnsale:collectFarm', farmId)
        notify(result.message or 'Høst fejlede.', result.ok and 'success' or 'error')
    else
        notify('Høst afbrudt.', 'error')
    end
end

runProcessAction = function(point)
    if not point or not point.id then
        notify('Omdanning-data mangler — genindlæs iddrugnsale.', 'error')
        return
    end

    local processId = tonumber(point.id) or point.id
    local inputLabel = point.input_label or point.label or 'stof'
    local outputLabel = point.output_label or point.label or 'stof'

    local check = awaitServer('iddrugnsale:canProcess', processId)
    if not check.ok then
        notify(check.message or 'Kan ikke omdanne her.', 'error')
        return
    end

    local duration = tonumber(point.duration) or Config.DefaultProcess.duration
    if playProgress(('Omdanner %s → %s'):format(inputLabel, outputLabel), duration, Config.ProcessAnim) then
        local result = awaitServer('iddrugnsale:processDrug', processId)
        notify(result.message or 'Omdanning fejlede.', result.ok and 'success' or 'error')
    else
        notify('Omdanning afbrudt.', 'error')
    end
end

runNpcSellAction = function(target)
    if isNpcAlreadySold(target) then
        notify('Du har allerede solgt til denne mand', 'error')
        return
    end

    if not hasSellableBags() then
        if hasLooseDrugGrams() then
            notify('Pak stoffet i en pølsemandspose først — løse gram kan ikke sælges.', 'error')
        else
            notify('Du har intet at sælge. Pak stoffet i poser først.', 'error')
        end
        return
    end

    openSellMenu(target)
end

local function setupNpcOxTarget()
    if not usesOxTargetForSell() or npcOxTargetRegistered then return end

    exports.ox_target:addGlobalPed({
        {
            name = 'iddrugnsale_sell_drug',
            icon = 'fa-solid fa-hand-holding-dollar',
            label = 'Sælg Stoffer',
            distance = Config.DealerInteractDistance or 4.0,
            canInteract = function(entity)
                if not isNpcSellable(entity) then return false end
                if not hasSellableBags() then return false end

                local coords = GetEntityCoords(entity)
                return not isNpcAlreadySold(buildNpcTarget(entity, coords))
            end,
            onSelect = function(data)
                local ped = data.entity
                if not ped or not DoesEntityExist(ped) then return end
                runNpcSellAction(buildNpcTarget(ped, GetEntityCoords(ped)))
            end,
        },
    })

    npcOxTargetRegistered = true
end

local function clearNpcOxTarget()
    if not npcOxTargetRegistered or GetResourceState('ox_target') ~= 'started' then return end

    pcall(function()
        exports.ox_target:removeGlobalPed('iddrugnsale_sell_drug')
    end)

    npcOxTargetRegistered = false
end

triggerActiveInteract = function()
    if nuiOpen or IsNuiFocused() then return end
    if not activeInteract then return end
    if interacting then return end

    interacting = true
    local kind = activeInteract.kind
    local data = activeInteract.data

    CreateThread(function()
        local ok, err = pcall(function()
            if kind == 'farm' then
                runFarmAction(data)
            elseif kind == 'process' then
                runProcessAction(data)
            elseif kind == 'npc' then
                runNpcSellAction(data)
            end
        end)

        if not ok then
            notify(('Interaktion fejlede: %s'):format(err), 'error')
        end

        interacting = false
    end)
end

local function ensureInteractKeybind()
    if interactKeybind then return end

    interactKeybind = lib.addKeybind({
        name = 'iddrugnsale_interact',
        description = 'Interager med farm/omdan/dealer (iddrugnsale)',
        defaultKey = 'E',
        onPressed = function()
            if nuiOpen or IsNuiFocused() then return end
            if not activeInteract or interacting then return end

            if activeInteract.kind == 'npc' then
                if not isSellTargetKeyHeld() or isNpcAlreadySold(activeInteract.data) then
                    return
                end
            end

            triggerActiveInteract()
        end,
    })
end

local function startMarkerThread()
    if markerThreadRunning then return end
    markerThreadRunning = true

    CreateThread(function()
        while true do
            local sleep = 500
            local coords = GetEntityCoords(cache.ped)

            for _, farm in ipairs(State.farms or {}) do
                if isSpotEnabled(farm.enabled) and normalizeDrugKey(farm.drug_key) then
                    local pos = spotCoords(farm)
                    local dist = #(coords - pos)
                    if shouldDrawMarker(farm.show_marker, dist) then
                        sleep = 0
                        local active = isSpotEnabled(farm.enabled)
                        local r, g, b, a = active and 0 or 120, active and 248 or 20, active and 185 or 20, active and 160 or 120
                        DrawMarker(1, pos.x, pos.y, pos.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.5, r, g, b, a, false, false, 2, false, nil, nil, false)
                    end
                end
            end

            for _, point in ipairs(State.process or {}) do
                if isSpotEnabled(point.enabled) and normalizeDrugKey(point.drug_key) then
                    local pos = spotCoords(point)
                    local dist = #(coords - pos)
                    if shouldDrawMarker(point.show_marker, dist) then
                        sleep = 0
                        local active = isSpotEnabled(point.enabled)
                        local r, g, b, a = active and 0 or 120, active and 248 or 20, active and 185 or 20, active and 160 or 120
                        DrawMarker(27, pos.x, pos.y, pos.z - 0.9, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.8, r, g, b, a, false, false, 2, false, nil, nil, false)
                    end
                end
            end

            for _, dealer in ipairs(State.dealers or {}) do
                if isSpotEnabled(dealer.enabled) and Config.SellToAllNpcs == false then
                    local pos = spotCoords(dealer)
                    local dist = #(coords - pos)
                    if dist <= (Config.NearbyMarkerDistance or 10.0) then
                        sleep = 0
                        DrawMarker(27, pos.x, pos.y, pos.z - 0.95, 0, 0, 0, 0, 0, 0, 0.8, 0.8, 0.6, 0, 248, 185, 120, false, false, 2, false, nil, nil, false)
                    end
                end
            end

            Wait(sleep)
        end
    end)
end

local function startInteractionThread()
    if interactionThreadRunning then return end
    interactionThreadRunning = true
    ensureInteractKeybind()

    CreateThread(function()
        local showingPrompt = false
        local lastPrompt = nil

        while true do
            local sleep = 500
            local coords = GetEntityCoords(cache.ped)
            local closest = nil
            local closestKind = nil
            local closestDist = Config.InteractDistance + 0.01

            if not nuiOpen and not IsNuiFocused() then
                for _, farm in ipairs(State.farms or {}) do
                    if isSpotEnabled(farm.enabled) and normalizeDrugKey(farm.drug_key) then
                        local dist = #(coords - spotCoords(farm))
                        if dist < closestDist then
                            closest = farm
                            closestKind = 'farm'
                            closestDist = dist
                        end
                    end
                end

                for _, point in ipairs(State.process or {}) do
                    if isSpotEnabled(point.enabled) and normalizeDrugKey(point.drug_key) then
                        local dist = #(coords - spotCoords(point))
                        if dist < closestDist then
                            closest = point
                            closestKind = 'process'
                            closestDist = dist
                        end
                    end
                end

                local npcTarget, npcDist = findNearestSellNpc(coords, Config.DealerInteractDistance or 4.0)
                if npcTarget and hasSellableBags() and isSellTargetKeyHeld() and npcDist < closestDist then
                    closest = npcTarget
                    closestKind = 'npc'
                    closestDist = npcDist
                end
            end

            if closest then
                sleep = 0
                local prompt

                if closestKind == 'farm' then
                    local drug = Config.Drugs[normalizeDrugKey(closest.drug_key)]
                    local rewardLabel = closest.reward_label or (drug and drug.label) or 'stof'
                    prompt = ('[E] %s — Høst %s (%.1fm)'):format(closest.label or 'Farm', rewardLabel, closestDist)
                elseif closestKind == 'npc' then
                    if isNpcAlreadySold(closest) then
                        prompt = 'Du har allerede solgt til denne mand'
                    else
                        prompt = ('[ALT+E] Sælg Stoffer (%.1fm)'):format(closestDist)
                    end
                else
                    local inputLabel = closest.input_label or closest.label or 'stof'
                    prompt = ('[E] %s — Omdan %s (%.1fm)'):format(closest.label or 'Omdan', inputLabel, closestDist)
                end

                activeInteract = { kind = closestKind, data = closest }

                if closestKind == 'npc' then
                    if not usesOxTargetForSell() then
                        updateWorldPrompt(
                            closest.ped,
                            prompt,
                            not isNpcAlreadySold(closest)
                        )
                    else
                        hideWorldPrompt()
                    end
                    showingPrompt = not usesOxTargetForSell()
                    lastPrompt = prompt
                elseif not showingPrompt or lastPrompt ~= prompt then
                    showPrompt(
                        prompt,
                        closestKind == 'farm' and 'seedling' or 'flask'
                    )
                    showingPrompt = true
                    lastPrompt = prompt
                end
            else
                activeInteract = nil
                if showingPrompt or worldPromptVisible then
                    hideAllPrompts()
                    showingPrompt = false
                    lastPrompt = nil
                end
            end

            Wait(sleep)
        end
    end)
end

local sellKeyThreadRunning = false

local function startSellKeyThread()
    if sellKeyThreadRunning then return end
    sellKeyThreadRunning = true

    CreateThread(function()
        local lastConfirm = 0

        while nuiOpen and currentSellTarget do
            Wait(0)

            DisableControlAction(0, 191, true) -- Enter
            DisableControlAction(0, 201, true) -- Accept
            DisableControlAction(0, 322, true) -- Esc

            if IsDisabledControlJustPressed(0, 322) then
                closeNui()
            end

            local now = GetGameTimer()
            if now - lastConfirm > 400 then
                if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
                    lastConfirm = now
                    SendNUIMessage({ action = 'confirmSell' })
                end
            end
        end

        sellKeyThreadRunning = false
    end)
end

openSellMenu = function(target)
    hideAllPrompts()
    currentSellTarget = target
    local result = awaitServer('iddrugnsale:getInventoryDrugs', target)
    if not result.ok then
        notify(result.message, 'error')
        return
    end

    if not result.items or #result.items == 0 then
        notify('Du skal pakke stoffet i en pølsemandspose først — løse gram kan ikke sælges.', 'error')
        return
    end

    nuiOpen = true
    if interactKeybind then interactKeybind:disable(true) end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openSell',
        target = target,
        dealerLabel = result.dealerLabel or 'Lokal borger',
        items = result.items,
        npcBagCount = result.npcBagCount,
        maxNpcBuy = result.maxNpcBuy,
        skillBonuses = result.skillBonuses,
    })
    startSellKeyThread()
end

local function closeNui()
    nuiOpen = false
    currentSellTarget = nil
    if interactKeybind then interactKeybind:disable(false) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function spawnDealers()
    clearDealers()
    for _, dealer in ipairs(State.dealers) do
        if isSpotEnabled(dealer.enabled) then
            local hash = loadModel(dealer.model or Config.DefaultDealer.model)
            if hash then
                local ped = CreatePed(4, hash, dealer.x, dealer.y, dealer.z - 1.0, dealer.heading or 0.0, false, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                FreezeEntityPosition(ped, true)
                spawnedDealers[dealer.id] = ped
            end
        end
    end
end

local function setupDealerFallback()
    -- Dealere bruger altid [E] + TextUI (kun synlig for spilleren selv).
end

local function refreshWorld()
    hideAllPrompts()
    if Config.SellToAllNpcs == false then
        spawnDealers()
    else
        clearDealers()
    end
    setupNpcOxTarget()
    startMarkerThread()
    startInteractionThread()
end

RegisterNetEvent('iddrugnsale:sync', function(data)
    State = data or State
    refreshWorld()
end)

RegisterNetEvent('iddrugnsale:sellResult', function(result)
    sellInProgress = false
    SendNUIMessage({ action = 'sellResult', result = result })
    if result.ok then
        if currentSellTarget then
            markNpcAsSold(currentSellTarget)
        elseif result.netId then
            soldNpcNetIds[result.netId] = true
        end
        notify(result.message, 'success')
        Wait(400)
        closeNui()
    else
        notify(result.message, 'error')
    end
end)

RegisterNetEvent('iddrugnsale:openAdmin', function()
    local isAdmin = lib.callback.await('iddrugnsale:isAdmin', false)
    if not isAdmin then return end

    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    local oxItems = lib.callback.await('iddrugnsale:getOxItems', false) or {}

    nuiOpen = true
    if interactKeybind then interactKeybind:disable(true) end
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openAdmin',
        state = State,
        drugs = Config.Drugs,
        oxItems = oxItems,
        dealerModels = Config.DealerModels,
        position = { x = coords.x, y = coords.y, z = coords.z, heading = heading },
        defaults = {
            farm = Config.DefaultFarm,
            process = Config.DefaultProcess,
            dealer = Config.DefaultDealer,
        },
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeNui()
    cb('ok')
end)

RegisterNUICallback('sellDrug', function(data, cb)
    cb('ok')

    if sellInProgress then return end

    local target = data.target or currentSellTarget
    local drugKey = data.drugKey
    local drug = Config.Drugs[drugKey]
    local label = drug and drug.label or 'stof'

    closeNui()
    sellInProgress = true

    playStreetDeal(target, label, function(success)
        if not success then
            sellInProgress = false
            notify('Salg afbrudt.', 'error')
            return
        end

        TriggerServerEvent(
            'iddrugnsale:sellDrug',
            target,
            drugKey,
            data.bagGrams,
            data.bagCount,
            data.offerPrice
        )
    end)
end)

RegisterNUICallback('sellNotify', function(data, cb)
    notify(data.message or 'Fejl', data.type or 'error')
    cb('ok')
end)

RegisterNUICallback('adminCreateFarm', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminCreateFarm', data)
    cb('ok')
end)

RegisterNUICallback('adminCreateProcess', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminCreateProcess', data)
    cb('ok')
end)

RegisterNUICallback('adminCreateDealer', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminCreateDealer', data)
    cb('ok')
end)

RegisterNUICallback('adminToggle', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminToggle', data.kind, data.id, data.enabled)
    cb('ok')
end)

RegisterNUICallback('adminDelete', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminDelete', data.kind, data.id)
    cb('ok')
end)

RegisterNUICallback('adminUpdateFarm', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminUpdateFarm', data.id, data)
    cb('ok')
end)

RegisterNUICallback('adminUpdateProcess', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminUpdateProcess', data.id, data)
    cb('ok')
end)

RegisterNUICallback('adminToggleMarker', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminToggleMarker', data.kind, data.id)
    cb('ok')
end)

RegisterNUICallback('adminUpdatePrices', function(data, cb)
    TriggerServerEvent('iddrugnsale:adminUpdatePrices', data)
    cb('ok')
end)

RegisterNUICallback('adminRefresh', function(_, cb)
    State = lib.callback.await('iddrugnsale:getState', false) or State
    SendNUIMessage({ action = 'stateUpdate', state = State })
    cb('ok')
end)

CreateThread(function()
    ensureInteractKeybind()
    while not ESX.PlayerLoaded do Wait(200) end
    State = lib.callback.await('iddrugnsale:getState', false) or State
    refreshWorld()
    setupDealerFallback()

    local processCount = #(State.process or {})
    local farmCount = #(State.farms or {})
    if processCount == 0 and farmCount == 0 then
        notify('Ingen farme/omdan-punkter sat op endnu. Admin: /iddrugadmin eller /iddrughere hash', 'inform')
    end
end)

RegisterNetEvent('esx:playerLoaded', function()
    State = lib.callback.await('iddrugnsale:getState', false) or State
    refreshWorld()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == 'ox_target' then
        setupNpcOxTarget()
        return
    end

    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        while not ESX.PlayerLoaded do Wait(200) end
        State = lib.callback.await('iddrugnsale:getState', false) or State
        refreshWorld()
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    interacting = false
    activeInteract = nil
    clearNpcOxTarget()
    clearDealers()
    hideAllPrompts()
    if nuiOpen then SetNuiFocus(false, false) end
end)

exports('bagProduct', function(slotId)
    local inventory = exports.ox_inventory:GetPlayerItems() or {}
    local slot = inventory[slotId]
    if not slot then
        notify('Kunne ikke finde stoffet i inventory.', 'error')
        return
    end

    local available = math.max(0, math.floor(tonumber(slot.metadata and slot.metadata.grams) or 0))
    local gramsPerBag = Config.BagMinGrams or 1
    if available < gramsPerBag then
        notify('Du har ikke nok løst stof til at pakke.', 'error')
        return
    end

    local emptyPoses = exports.ox_inventory:GetItemCount(Config.BagItem) or 0
    if emptyPoses < 1 then
        notify('Du mangler en tom pølsemandspose.', 'error')
        return
    end

    local maxUnits = math.min(math.floor(available / gramsPerBag), emptyPoses)
    local result = lib.inputDialog('Pak stof', {
        {
            type = 'number',
            label = 'Antal at pakke',
            description = ('Du har %d gram løst og %d tomme poser.'):format(available, emptyPoses),
            default = maxUnits,
            min = 1,
            max = maxUnits,
            required = true,
        },
    })

    if not result then return end

    TriggerServerEvent('iddrugnsale:bagProduct', slotId, math.floor(result[1]))
end)

RegisterNetEvent('iddrugnsale:requestPoliceDispatch', function(context, target)
    target = target or currentSellTarget

    local player = cache.ped
    local coords = GetEntityCoords(player)
    if target and target.x and target.y and target.z then
        coords = vector3(tonumber(target.x) or coords.x, tonumber(target.y) or coords.y, tonumber(target.z) or coords.z)
    end

    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    if crossingHash and crossingHash ~= 0 then
        local crossing = GetStreetNameFromHashKey(crossingHash)
        if crossing and crossing ~= '' then
            street = ('%s / %s'):format(street, crossing)
        end
    end
    if not street or street == '' then street = 'Ukendt vej' end

    local isReject = context == 'reject'
    local customerPed = resolveNpcPed(target)
    if customerPed and DoesEntityExist(customerPed) then
        requestEntityControl(customerPed, 1500)
        lib.requestAnimDict('cellphone@')
        TaskPlayAnim(customerPed, 'cellphone@', 'cellphone_call_listen_base', 8.0, -8.0, 3500, 49, 0.0, false, false, false)
    end

    local witnessLine = isReject
        and ('En borger ringede til politiet efter at have afvist et mistænkeligt stoftilbud ved %s.'):format(street)
        or ('En borger ringede til politiet og anmeldte stofsalg på gaden ved %s.'):format(street)

    local dispatch = {
        type = 'drug_sale',
        title = isReject and 'Borger: mistænkeligt stofsalg' or 'Borger: anmeldelse om stofsalg',
        description = isReject
            and 'Kunde ringede efter afvist/mistænkeligt narkosalg.'
            or 'Kunde anmeldte stofsalg efter gadehandel.',
        street = street,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        priority = 2,
        witnessCount = 1,
        metadata = {
            witnessStatements = { witnessLine },
            witnesses = { total = 1 },
            signalement = {
                gender = IsPedMale(player) and 'Mand' or 'Kvinde',
                mask = GetPedDrawableVariation(player, 1) > 0 and 'Mulig maske' or 'Ingen tydelig maske',
                hat = GetPedPropIndex(player, 0) ~= -1 and 'Hovedbeklædning' or 'Ingen tydelig hovedbeklædning',
                movement = IsPedInAnyVehicle(player, false) and 'I køretøj' or 'Til fods',
            },
            noPhotoText = 'Intet foto modtaget fra vidne',
            source = 'iddrugnsale',
        },
    }

    local dispatchRes = Config.DispatchResource or 'san_dispatch'
    local mdtRes = Config.MdtResource or 'san_mdt'

    if GetResourceState(dispatchRes) == 'started' then
        TriggerServerEvent('san_dispatch:report', dispatch)
        return
    end

    if GetResourceState(mdtRes) == 'started' then
        TriggerServerEvent('san_mdt:autoDispatchCall', dispatch)
    end
end)
