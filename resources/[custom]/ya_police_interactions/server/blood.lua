local BloodHours = Config.BloodDrugHours or 48

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS ya_blood_drugs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        identifier VARCHAR(80) NOT NULL,
        substance VARCHAR(32) NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        KEY identifier_idx (identifier),
        KEY expires_idx (expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]], {})
end)

local function cleanupExpired(identifier)
    MySQL.update.await('DELETE FROM ya_blood_drugs WHERE expires_at <= NOW() AND identifier = ?', { identifier })
end

local function getActiveBloodDrugs(identifier)
    cleanupExpired(identifier)
    local rows = MySQL.query.await(
        'SELECT substance, expires_at FROM ya_blood_drugs WHERE identifier = ? AND expires_at > NOW() ORDER BY expires_at DESC',
        { identifier }
    ) or {}

    local seen = {}
    local out = {}

    for i = 1, #rows do
        local substance = rows[i].substance
        if substance and not seen[substance] then
            seen[substance] = true
            out[#out + 1] = {
                substance = substance,
                label = (Config.BloodDrugs and Config.BloodDrugs[substance]) or substance,
                expiresAt = rows[i].expires_at,
            }
        end
    end

    return out
end

function YAPoliceAddBloodDrug(identifier, substance)
    if not identifier or not substance or substance == '' then return false end

    local hours = BloodHours
    MySQL.insert.await(
        'INSERT INTO ya_blood_drugs (identifier, substance, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))',
        { identifier, substance, hours }
    )

    return true
end

exports('AddBloodDrug', function(identifier, substance)
    return YAPoliceAddBloodDrug(identifier, substance)
end)

RegisterNetEvent('ya_police:server:addBloodDrug', function(substance)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not substance then return end
    if not Config.BloodDrugs or not Config.BloodDrugs[substance] then return end

    YAPoliceAddBloodDrug(xPlayer.identifier, substance)
end)

RegisterNetEvent('ya_police:server:consumeDrugItem', function(itemName, slot)
    local src = source
    if not itemName or GetResourceState('ox_inventory') ~= 'started' then return end
    exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)
end)

lib.callback.register('ya_police:server:drugTest', function(source, targetId)
    if not isPolice(source) or not targetId then return { positive = false, substances = {} } end

    local target = ESX.GetPlayerFromId(targetId)
    if not target then return { positive = false, substances = {} } end

    local substances = getActiveBloodDrugs(target.identifier)
    return {
        positive = #substances > 0,
        substances = substances,
    }
end)

