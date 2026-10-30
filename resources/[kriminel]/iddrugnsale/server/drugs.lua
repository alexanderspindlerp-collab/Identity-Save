local DrugUtils = {}

local function itemsTable()
    if GetResourceState('ox_inventory') ~= 'started' then
        return {}
    end

    local ok, items = pcall(function()
        return exports.ox_inventory:Items()
    end)

    if ok and type(items) == 'table' then
        return items
    end

    ok, items = pcall(function()
        return exports.ox_inventory:ItemList()
    end)

    if ok and type(items) == 'table' then
        return items
    end

    return {}
end

local function slotNumber(slotId, slot)
    return tonumber(slotId) or tonumber(slot and slot.slot)
end

function DrugUtils.itemLabel(itemName)
    local data = itemsTable()[itemName]
    return (data and data.label) or itemName
end

function DrugUtils.getLooseItem(drugKey)
    local drug = Config.Drugs[drugKey]
    if not drug then return end
    return drug.looseItem or drug.productItem
end

function DrugUtils.getSellItem(drugKey)
    local drug = Config.Drugs[drugKey]
    return drug and drug.sellItem
end

function DrugUtils.drugKeyFromLooseItem(itemName)
    for key, drug in pairs(Config.Drugs) do
        if (drug.looseItem or drug.productItem) == itemName then
            return key
        end
    end
end

function DrugUtils.getInventoryItems(source)
    return exports.ox_inventory:GetInventoryItems(source) or {}
end

function DrugUtils.getSlotGrams(slot)
    if not slot or not slot.metadata then return 0 end
    return math.max(0, math.floor(tonumber(slot.metadata.grams) or 0))
end

function DrugUtils.productLabel(drugLabel)
    return drugLabel
end

function DrugUtils.buildProductMetadata(drugLabel, grams)
    return {
        grams = grams,
        label = drugLabel,
    }
end

function DrugUtils.findProductSlot(source, slotId)
    local slotNum = tonumber(slotId)
    if not slotNum then return end
    return exports.ox_inventory:GetSlot(source, slotNum)
end

function DrugUtils.findProductSlotId(source, itemName)
    for slotId, slot in pairs(DrugUtils.getInventoryItems(source)) do
        if slot.name == itemName then
            return slotNumber(slotId, slot)
        end
    end
end

function DrugUtils.getProductGrams(source, itemName)
    local total = 0
    for _, slot in pairs(DrugUtils.getInventoryItems(source)) do
        if slot.name == itemName then
            total = total + DrugUtils.getSlotGrams(slot)
        end
    end
    return total
end

function DrugUtils.getLooseGrams(source, drugKey)
    local itemName = DrugUtils.getLooseItem(drugKey)
    if not itemName then return 0 end
    return DrugUtils.getProductGrams(source, itemName)
end

function DrugUtils.canCarryNewProduct(source, itemName, drugLabel, grams)
    local metadata = DrugUtils.buildProductMetadata(drugLabel, grams)
    return exports.ox_inventory:CanCarryItem(source, itemName, 1, metadata) == true
end

function DrugUtils.canCarryProduct(source, itemName, drugLabel, grams)
    if DrugUtils.findProductSlotId(source, itemName) then
        return true
    end

    return DrugUtils.canCarryNewProduct(source, itemName, drugLabel, grams)
end

function DrugUtils.addProductGrams(source, itemName, drugLabel, grams)
    grams = math.floor(tonumber(grams) or 0)
    if grams < 1 then return false, 'invalid_grams' end

    for slotId, slot in pairs(DrugUtils.getInventoryItems(source)) do
        if slot.name == itemName then
            local slotNum = slotNumber(slotId, slot)
            if slotNum then
                local current = DrugUtils.getSlotGrams(slot)
                local nextGrams = current + grams

                exports.ox_inventory:SetMetadata(source, slotNum, DrugUtils.buildProductMetadata(drugLabel, nextGrams))
                return true
            end
        end
    end

    local metadata = DrugUtils.buildProductMetadata(drugLabel, grams)
    if not exports.ox_inventory:CanCarryItem(source, itemName, 1, metadata) then
        return false, 'no_space'
    end

    local success = exports.ox_inventory:AddItem(source, itemName, 1, metadata)
    if not success then
        return false, 'add_failed'
    end

    return true
end

function DrugUtils.removeProductGramsFromSlot(source, slotId, grams)
    grams = math.floor(tonumber(grams) or 0)
    if grams < 1 then return false end

    local slotNum = tonumber(slotId)
    if not slotNum then return false end

    local slot = DrugUtils.findProductSlot(source, slotNum)
    if not slot then return false end

    local drugKey = DrugUtils.drugKeyFromLooseItem(slot.name)
    local drug = drugKey and Config.Drugs[drugKey]
    if not drug then return false end

    local current = DrugUtils.getSlotGrams(slot)
    if current < grams then return false end

    local remaining = current - grams
    if remaining < 1 then
        return exports.ox_inventory:RemoveItem(source, slot.name, 1, nil, slotNum)
    end

    exports.ox_inventory:SetMetadata(source, slotNum, DrugUtils.buildProductMetadata(drug.label, remaining))
    return true
end

function DrugUtils.countEmptyPoses(source)
    local total = 0
    for _, slot in pairs(DrugUtils.getInventoryItems(source)) do
        if slot.name == Config.BagItem then
            total = total + (slot.count or 1)
        end
    end
    return total
end

function DrugUtils.removeOneEmptyPose(source)
    return exports.ox_inventory:RemoveItem(source, Config.BagItem, 1)
end

function DrugUtils.removeEmptyPoses(source, count)
    count = math.floor(tonumber(count) or 0)
    if count < 1 then return false end
    return exports.ox_inventory:RemoveItem(source, Config.BagItem, count)
end

function DrugUtils.countSellUnits(source, drugKey)
    local itemName = DrugUtils.getSellItem(drugKey)
    if not itemName then return 0 end
    return exports.ox_inventory:GetItemCount(source, itemName) or 0
end

function DrugUtils.hasSellUnits(source)
    for drugKey in pairs(Config.Drugs) do
        if DrugUtils.countSellUnits(source, drugKey) > 0 then
            return true
        end
    end
    return false
end

function DrugUtils.getSellBreakdown(source, drugKey)
    local count = DrugUtils.countSellUnits(source, drugKey)
    if count < 1 then return {} end

    return {
        {
            grams = 1,
            count = count,
        },
    }
end

function DrugUtils.countFilledBagsBySize(source, drugKey, _)
    return DrugUtils.countSellUnits(source, drugKey)
end

function DrugUtils.removeSellUnits(source, drugKey, count)
    count = math.floor(tonumber(count) or 0)
    if count < 1 then return false end

    local itemName = DrugUtils.getSellItem(drugKey)
    if not itemName then return false end

    return exports.ox_inventory:RemoveItem(source, itemName, count) and true or false
end

function DrugUtils.removeFilledBagsBySize(source, drugKey, _, count)
    return DrugUtils.removeSellUnits(source, drugKey, count)
end

function DrugUtils.canCarrySellUnits(source, drugKey, count)
    count = math.floor(tonumber(count) or 0)
    if count < 1 then return false end

    local itemName = DrugUtils.getSellItem(drugKey)
    if not itemName then return false end

    return exports.ox_inventory:CanCarryItem(source, itemName, count) == true
end

function DrugUtils.addSellUnits(source, drugKey, count)
    count = math.floor(tonumber(count) or 0)
    if count < 1 then return false end

    local itemName = DrugUtils.getSellItem(drugKey)
    if not itemName then return false end

    return exports.ox_inventory:AddItem(source, itemName, count) and true or false
end

-- Bag-compat aliases (gammel API)
function DrugUtils.hasFilledBags(source)
    return DrugUtils.hasSellUnits(source)
end

function DrugUtils.getFilledBagBreakdown(source, drugKey)
    return DrugUtils.getSellBreakdown(source, drugKey)
end

function DrugUtils.canCarryFilledBags(source, drugKey, _, count)
    return DrugUtils.canCarrySellUnits(source, drugKey, count)
end

function DrugUtils.addFilledBag(source, drugKey, _)
    return DrugUtils.addSellUnits(source, drugKey, 1)
end

_G.DrugUtils = DrugUtils

return DrugUtils
