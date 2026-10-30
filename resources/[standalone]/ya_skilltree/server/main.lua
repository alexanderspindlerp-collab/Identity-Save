local ESX = exports['es_extended']:getSharedObject()

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `ya_skilltree` (
            `identifier` VARCHAR(60) NOT NULL,
            `points` INT NOT NULL DEFAULT 0,
            `unlocked` LONGTEXT NULL,
            `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    print('[ya_skilltree] Database table ready.')
end)

local skillIndex = {}
for i = 1, #Config.Skills do
    skillIndex[Config.Skills[i].id] = Config.Skills[i]
end

local branchIndex = Config.Branches or {}

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.identifier or nil
end

local function decodeUnlocked(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return {} end
    return data
end

local function encodeUnlocked(list)
    return json.encode(list or {})
end

local function ensureRow(identifier)
    MySQL.insert.await(
        'INSERT IGNORE INTO ya_skilltree (identifier, points, unlocked) VALUES (?, ?, ?)',
        { identifier, Config.StartingPoints or 0, '[]' }
    )
end

local function getState(identifier)
    ensureRow(identifier)
    local row = MySQL.single.await(
        'SELECT points, unlocked FROM ya_skilltree WHERE identifier = ? LIMIT 1',
        { identifier }
    )
    return {
        points = row and tonumber(row.points) or 0,
        unlocked = decodeUnlocked(row and row.unlocked or '[]')
    }
end

local function saveState(identifier, points, unlocked)
    MySQL.update.await(
        'UPDATE ya_skilltree SET points = ?, unlocked = ? WHERE identifier = ?',
        { points, encodeUnlocked(unlocked), identifier }
    )
end

local function hasUnlocked(unlocked, skillId)
    for i = 1, #unlocked do
        if unlocked[i] == skillId then return true end
    end
    return false
end

local function getDependents(skillId, unlocked)
    local dependents = {}
    for i = 1, #unlocked do
        local id = unlocked[i]
        local skill = skillIndex[id]
        if skill and skill.requires then
            for j = 1, #skill.requires do
                if skill.requires[j] == skillId then
                    dependents[#dependents + 1] = id
                    break
                end
            end
        end
    end
    return dependents
end

local function requirementsMet(skill, unlocked)
    if not skill.requires then return true end
    for i = 1, #skill.requires do
        if not hasUnlocked(unlocked, skill.requires[i]) then
            return false
        end
    end
    return true
end

local function blockedByUnlocked(skill, unlocked)
    if not skill.blocks then return false end
    for i = 1, #skill.blocks do
        if hasUnlocked(unlocked, skill.blocks[i]) then
            return true
        end
    end
    return false
end

local function countUnlockedInCategory(unlocked, categoryId)
    local count = 0
    for i = 1, #unlocked do
        local skill = skillIndex[unlocked[i]]
        if skill and skill.category == categoryId then
            count = count + 1
        end
    end
    return count
end

local function buildPayload(identifier)
    local state = getState(identifier)
    local categoryProgress = {}

    for i = 1, #(Config.Categories or {}) do
        local cat = Config.Categories[i]
        if cat and cat.id then
            categoryProgress[cat.id] = countUnlockedInCategory(state.unlocked, cat.id)
        end
    end

    return {
        categories = Config.Categories,
        branches = Config.Branches,
        skills = Config.Skills,
        points = state.points,
        unlocked = state.unlocked,
        categoryProgress = categoryProgress,
        pointRewards = Config.PointRewards or {}
    }
end

local maxEffectKeys = {
    street_want_mult = true
}

local function aggregateEffects(unlocked, categoryId)
    local totals = {}
    for i = 1, #unlocked do
        local skill = skillIndex[unlocked[i]]
        if skill and skill.category == categoryId and skill.effects then
            for key, value in pairs(skill.effects) do
                if maxEffectKeys[key] then
                    totals[key] = math.max(totals[key] or 0, value)
                else
                    totals[key] = (totals[key] or 0) + value
                end
            end
        end
    end
    return totals
end

local function addPoints(src, amount, silent)
    local identifier = getIdentifier(src)
    if not identifier or not amount or amount < 1 then return false end

    local state = getState(identifier)
    local newPoints = math.min((Config.MaxPoints or 99), state.points + amount)
    if newPoints == state.points then return false end

    saveState(identifier, newPoints, state.unlocked)
    TriggerClientEvent('ya_skilltree:sync', src, buildPayload(identifier))
    if not silent then
        TriggerClientEvent('ya_skilltree:notify', src, ('+%s skillpoint%s'):format(amount, amount > 1 and 's' or ''))
    end
    return true
end

local function awardFromSource(src, sourceKey)
    local amount = Config.PointRewards and Config.PointRewards[sourceKey]
    if not amount then return false end

    local identifier = getIdentifier(src)
    if identifier then
        local bonuses = aggregateEffects(getState(identifier).unlocked, 'criminal')
        if sourceKey == 'mission' then
            amount = amount + (bonuses.mission_point_bonus or 0)
        elseif sourceKey == 'house_robbery' then
            amount = amount + (bonuses.house_point_bonus or 0)
        elseif sourceKey == 'street_sale' then
            amount = amount + (bonuses.street_sale_point_bonus or 0)
        end
    end

    return addPoints(src, amount, false)
end

RegisterNetEvent('ya_skilltree:requestOpen', function()
    local src = source
    local identifier = getIdentifier(src)

    if not identifier then
        TriggerClientEvent('ya_skilltree:openFailed', src, 'Kunne ikke finde spiller-data.')
        return
    end

    local ok, payload = pcall(buildPayload, identifier)
    if not ok or type(payload) ~= 'table' then
        print(('[ya_skilltree] requestOpen failed for %s: %s'):format(identifier, tostring(payload)))
        TriggerClientEvent('ya_skilltree:openFailed', src, 'DB-fejl — kør ya_skilltree/sql/install.sql og ensure ya_skilltree')
        return
    end

    TriggerClientEvent('ya_skilltree:openUI', src, payload)
end)

RegisterNetEvent('ya_skilltree:unlock', function(skillId)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier or type(skillId) ~= 'string' then return end

    local skill = skillIndex[skillId]
    if not skill then
        TriggerClientEvent('ya_skilltree:notify', src, 'Ukendt skill.')
        return
    end

    local state = getState(identifier)
    if hasUnlocked(state.unlocked, skillId) then
        TriggerClientEvent('ya_skilltree:notify', src, 'Allerede låst op.')
        return
    end

    if not requirementsMet(skill, state.unlocked) then
        TriggerClientEvent('ya_skilltree:notify', src, 'Mangler forudsætninger.')
        return
    end

    if blockedByUnlocked(skill, state.unlocked) then
        TriggerClientEvent('ya_skilltree:notify', src, 'Blokeret af en anden valgt skill.')
        return
    end

    local cost = skill.cost or 1
    if state.points < cost then
        TriggerClientEvent('ya_skilltree:notify', src, 'Ikke nok points.')
        return
    end

    state.points = state.points - cost
    state.unlocked[#state.unlocked + 1] = skillId
    saveState(identifier, state.points, state.unlocked)
    TriggerClientEvent('ya_skilltree:sync', src, buildPayload(identifier))
    TriggerClientEvent('ya_skilltree:notify', src, ('%s låst op!'):format(skill.title))
end)

RegisterNetEvent('ya_skilltree:refund', function(skillId)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier or type(skillId) ~= 'string' then return end

    local skill = skillIndex[skillId]
    if not skill then return end

    local state = getState(identifier)
    if not hasUnlocked(state.unlocked, skillId) then
        TriggerClientEvent('ya_skilltree:notify', src, 'Skill er ikke låst op.')
        return
    end

    if #getDependents(skillId, state.unlocked) > 0 then
        TriggerClientEvent('ya_skilltree:notify', src, 'Kan ikke fjernes — andre skills afhænger af den.')
        return
    end

    local newUnlocked = {}
    for i = 1, #state.unlocked do
        if state.unlocked[i] ~= skillId then
            newUnlocked[#newUnlocked + 1] = state.unlocked[i]
        end
    end

    state.points = math.min((Config.MaxPoints or 99), state.points + (skill.cost or 1))
    saveState(identifier, state.points, newUnlocked)
    TriggerClientEvent('ya_skilltree:sync', src, buildPayload(identifier))
    TriggerClientEvent('ya_skilltree:notify', src, ('%s fjernet.'):format(skill.title))
end)

RegisterNetEvent('ya_skilltree:resetBranch', function(branchId)
    local src = source
    local identifier = getIdentifier(src)
    if not identifier or type(branchId) ~= 'string' or not branchIndex[branchId] then return end

    local state = getState(identifier)
    local refund = 0
    local kept = {}

    for i = 1, #state.unlocked do
        local id = state.unlocked[i]
        local skill = skillIndex[id]
        if skill and skill.branch == branchId then
            refund = refund + (skill.cost or 1)
        else
            kept[#kept + 1] = id
        end
    end

    if refund == 0 then
        TriggerClientEvent('ya_skilltree:notify', src, 'Ingen skills at nulstille i denne gren.')
        return
    end

    state.points = math.min((Config.MaxPoints or 99), state.points + refund)
    saveState(identifier, state.points, kept)
    TriggerClientEvent('ya_skilltree:sync', src, buildPayload(identifier))
    TriggerClientEvent('ya_skilltree:notify', src, ('%s nulstillet (+%s points).'):format(branchIndex[branchId].label, refund))
end)

exports('GetUnlockedSkills', function(src)
    local identifier = getIdentifier(src)
    if not identifier then return {} end
    return getState(identifier).unlocked
end)

exports('HasSkill', function(src, skillId)
    local identifier = getIdentifier(src)
    if not identifier then return false end
    return hasUnlocked(getState(identifier).unlocked, skillId)
end)

exports('GetCategoryEffects', function(src, categoryId)
    local identifier = getIdentifier(src)
    if not identifier then return {} end
    return aggregateEffects(getState(identifier).unlocked, categoryId or 'criminal')
end)

exports('GetCriminalBonuses', function(src)
    return exports.ya_skilltree:GetCategoryEffects(src, 'criminal')
end)

exports('AwardPoints', function(src, sourceKey)
    return awardFromSource(src, sourceKey)
end)

exports('AddPoints', function(src, amount)
    return addPoints(src, tonumber(amount) or 0, false)
end)
