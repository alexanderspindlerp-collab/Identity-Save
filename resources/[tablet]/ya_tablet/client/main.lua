local ESX = exports['es_extended']:getSharedObject()

local uiOpen = false

local tabletProp = nil

local pendingWorkshopApp = false
local pendingAdminWorkshops = nil

local function sendAdminWorkshops(rows, shopCatalog, blipCatalog, blipColors)
    SendNUIMessage({
        action = 'adminWorkshops',
        rows = rows or {},
        shopCatalog = shopCatalog or {},
        blipCatalog = blipCatalog or {},
        blipColors = blipColors or {},
    })
end

local function parseAdminWorkshopsPayload(rowsOrPayload, shopCatalog, blipCatalog, blipColors)
    local rows, catalog, blips, colors = {}, {}, {}, {}
    if type(rowsOrPayload) == 'table' and rowsOrPayload.rows then
        rows = rowsOrPayload.rows or {}
        catalog = rowsOrPayload.shopCatalog or shopCatalog or {}
        blips = rowsOrPayload.blipCatalog or blipCatalog or {}
        colors = rowsOrPayload.blipColors or blipColors or {}
    elseif type(rowsOrPayload) == 'table' then
        rows = rowsOrPayload
        catalog = shopCatalog or {}
        blips = blipCatalog or {}
        colors = blipColors or {}
    end
    return rows, catalog, blips, colors
end



local function isInventoryOpen()

    return LocalPlayer.state.invOpen == true

end



local function deleteTabletProp()

    if tabletProp and DoesEntityExist(tabletProp) then

        DeleteEntity(tabletProp)

    end

    tabletProp = nil

end



local function attachTabletProp()

    deleteTabletProp()

    local ped = PlayerPedId()

    local model = joaat('prop_cs_tablet')

    RequestModel(model)

    local timeout = GetGameTimer() + 3000

    while not HasModelLoaded(model) and GetGameTimer() < timeout do

        Wait(0)

    end

    if not HasModelLoaded(model) then return end



    local coords = GetEntityCoords(ped)

    tabletProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)

    AttachEntityToEntity(

        tabletProp,

        ped,

        GetPedBoneIndex(ped, 28422),

        0.0, 0.0, 0.03,

        0.0, 0.0, 0.0,

        true, true, false, true, 1, true

    )

    SetModelAsNoLongerNeeded(model)

end



local function closeUI()

    if not uiOpen then

        SetNuiFocus(false, false)

        deleteTabletProp()

        ClearPedTasks(PlayerPedId())

        return

    end



    uiOpen = false
    pendingAdminWorkshops = nil

    SetNuiFocus(false, false)

    SendNUIMessage({ action = 'close' })

    deleteTabletProp()

    ClearPedTasks(PlayerPedId())

end



local function openUI()

    if uiOpen or isInventoryOpen() then return end



    local dict = 'amb@world_human_seat_wall_tablet@female@base'

    local anim = 'base'

    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 3000

    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do

        Wait(0)

    end



    if HasAnimDictLoaded(dict) then

        TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, -1, 49, 0, false, false, false)

    end



    attachTabletProp()

    TriggerServerEvent('ya_tablet:requestOpen')

end



RegisterNetEvent('ya_tablet:openUI', function(payload)

    if type(payload) ~= 'table' then return end

    uiOpen = true

    SetNuiFocus(true, true)

    SendNUIMessage({

        action = 'open',

        data = payload

    })

    if pendingWorkshopApp then
        pendingWorkshopApp = false
        SetTimeout(250, function()
            if uiOpen then
                SendNUIMessage({ action = 'openApp', appId = 'workshop' })
            end
        end)
    end

    if pendingAdminWorkshops then
        local pending = pendingAdminWorkshops
        pendingAdminWorkshops = nil
        sendAdminWorkshops(pending.rows, pending.shopCatalog, pending.blipCatalog, pending.blipColors)
    end

end)



RegisterNetEvent('ya_workshop:openWorkTablet', function()
    pendingWorkshopApp = true
    openUI()
end)



RegisterNetEvent('ya_tablet:sync', function(payload)

    if not uiOpen or type(payload) ~= 'table' then return end

    SendNUIMessage({

        action = 'sync',

        data = payload

    })

end)



RegisterNetEvent('ya_tablet:adminOrgs', function(rows)

    if not uiOpen then return end

    SendNUIMessage({

        action = 'adminOrgs',

        rows = rows or {}

    })

end)



RegisterNetEvent('ya_tablet:adminOrgDetail', function(detail)

    if not uiOpen then return end

    SendNUIMessage({

        action = 'adminOrgDetail',

        detail = detail

    })

end)



local function tabletNotify(message, ntype)
    message = tostring(message or '')
    if message == '' then return end
    if uiOpen then
        SendNUIMessage({
            action = 'toast',
            message = message,
            type = ntype or 'info'
        })
        return
    end
    ESX.ShowNotification(message)
end

RegisterNetEvent('ya_tablet:notify', function(message, ntype)
    tabletNotify(message, ntype)
end)



RegisterNetEvent('ya_tablet:newMessage', function()

    SendNUIMessage({ action = 'newMessage' })

end)



exports('useTablet', function()

    if isInventoryOpen() then return end

    openUI()

end)



exports('Open', openUI)

exports('Close', closeUI)



RegisterNUICallback('close', function(_, cb)

    closeUI()

    cb('ok')

end)



RegisterNUICallback('refreshTablet', function(_, cb)

    ESX.TriggerServerCallback('ya_tablet:getBootstrap', function(payload)

        if type(payload) == 'table' then

            if uiOpen then

                SendNUIMessage({

                    action = 'sync',

                    data = payload

                })

            end

            cb(payload)

            return

        end

        cb({})

    end)

end)



RegisterNUICallback('installApp', function(data, cb)

    if data and data.appId then

        TriggerServerEvent('ya_tablet:installApp', data.appId)

    end

    cb('ok')

end)



local function gangEvent(name, ...)

    TriggerServerEvent(('ya_gangs:%s'):format(name), ...)

end



RegisterNUICallback('createOrg', function(data, cb)

    if data and data.name then gangEvent('createOrg', data.name) end

    cb('ok')

end)



RegisterNUICallback('inviteMember', function(data, cb)

    if data and data.targetId then gangEvent('inviteMember', data.targetId) end

    cb('ok')

end)



RegisterNUICallback('acceptInvite', function(data, cb)

    if data and data.inviteId then gangEvent('acceptInvite', data.inviteId) end

    cb('ok')

end)



RegisterNUICallback('declineInvite', function(data, cb)

    if data and data.inviteId then gangEvent('declineInvite', data.inviteId) end

    cb('ok')

end)



RegisterNUICallback('kickMember', function(data, cb)

    if data and data.memberId then gangEvent('kickMember', data.memberId) end

    cb('ok')

end)



RegisterNUICallback('setMemberRole', function(data, cb)

    if data and data.memberId and data.roleId then

        gangEvent('setMemberRole', data.memberId, data.roleId)

    end

    cb('ok')

end)



RegisterNUICallback('createRole', function(data, cb)

    if data and data.name then

        gangEvent('createRole', data.name, data.permissions or {})

    end

    cb('ok')

end)



RegisterNUICallback('updateRole', function(data, cb)

    if data and data.roleId then

        gangEvent('updateRole', data.roleId, data.name, data.permissions or {})

    end

    cb('ok')

end)



RegisterNUICallback('deleteRole', function(data, cb)

    if data and data.roleId then

        gangEvent('deleteRole', data.roleId)

    end

    cb('ok')

end)



RegisterNUICallback('moveRole', function(data, cb)

    if data and data.roleId and data.direction then

        gangEvent('moveRole', data.roleId, data.direction)

    end

    cb('ok')

end)



RegisterNUICallback('leaveOrg', function(_, cb)

    gangEvent('leaveOrg')

    cb('ok')

end)



RegisterNUICallback('deleteOrg', function(_, cb)

    gangEvent('deleteOrg')

    cb('ok')

end)



RegisterNUICallback('adminListOrgs', function(_, cb)

    gangEvent('adminListOrgs')

    cb('ok')

end)



RegisterNUICallback('adminSetLocked', function(data, cb)

    if data and data.orgId ~= nil then

        gangEvent('adminSetLocked', data.orgId, data.locked == true)

    end

    cb('ok')

end)



RegisterNUICallback('adminCloseOrg', function(data, cb)

    if data and data.orgId then gangEvent('adminCloseOrg', data.orgId) end

    cb('ok')

end)



RegisterNUICallback('adminGetOrg', function(data, cb)

    if data and data.orgId then gangEvent('adminGetOrg', data.orgId) end

    cb('ok')

end)



RegisterNUICallback('adminUpdateOrg', function(data, cb)

    if data and data.orgId then

        gangEvent('adminUpdateOrg', data.orgId, data.patch or {})

    end

    cb('ok')

end)



RegisterNUICallback('adminSetMemberRole', function(data, cb)

    if data and data.orgId and data.memberId and data.roleId then

        gangEvent('adminSetMemberRole', data.orgId, data.memberId, data.roleId)

    end

    cb('ok')

end)



RegisterNUICallback('adminKickMember', function(data, cb)

    if data and data.orgId and data.memberId then

        gangEvent('adminKickMember', data.orgId, data.memberId)

    end

    cb('ok')

end)



RegisterNUICallback('adminDeleteZone', function(data, cb)

    if data and data.orgId and data.zoneId then

        gangEvent('adminDeleteZone', data.orgId, data.zoneId)

    end

    cb('ok')

end)



RegisterNUICallback('markMessagesRead', function(_, cb)

    gangEvent('markMessagesRead')

    cb('ok')

end)



RegisterNUICallback('createZone', function(data, cb)

    if data and data.name and data.vertices then

        gangEvent('createZone', data.name, data.vertices)

    end

    cb('ok')

end)



RegisterNUICallback('updateZone', function(data, cb)

    if data and data.zoneId and data.vertices then

        gangEvent('updateZone', data.zoneId, data.vertices)

    end

    cb('ok')

end)



RegisterNUICallback('renameZone', function(data, cb)

    if data and data.zoneId and data.name then

        gangEvent('renameZone', data.zoneId, data.name)

    end

    cb('ok')

end)



RegisterNUICallback('deleteZone', function(data, cb)

    if data and data.zoneId then gangEvent('deleteZone', data.zoneId) end

    cb('ok')

end)



RegisterNUICallback('requestZone', function(data, cb)

    if data and data.zoneId then gangEvent('requestZone', data.zoneId) end

    cb('ok')

end)



RegisterNUICallback('transferZone', function(data, cb)

    if data and data.zoneId and data.targetOrgId then

        gangEvent('transferZone', data.zoneId, data.targetOrgId)

    end

    cb('ok')

end)



RegisterNUICallback('upgradeZoneLevel', function(data, cb)

    if data and data.zoneId then

        gangEvent('upgradeZoneLevel', data.zoneId)

    end

    cb('ok')

end)



RegisterNUICallback('unlockSkill', function(data, cb)

    if data and data.skillKey then

        gangEvent('unlockSkill', data.skillKey, data.zoneId)

    end

    cb('ok')

end)



RegisterNUICallback('gangNotify', function(data, cb)

    if data and data.message then

        tabletNotify(data.message, data.type or 'error')

    end

    cb('ok')

end)



local function cardealerEvent(name, ...)
    TriggerServerEvent(('ya_cardealer:%s'):format(name), ...)
end

RegisterNetEvent('ya_tablet:adminDealerships', function(rows)
    if not uiOpen then return end
    SendNUIMessage({ action = 'adminDealerships', rows = rows or {} })
end)

RegisterNetEvent('ya_tablet:adminDealershipDetail', function(detail)
    if not uiOpen then return end
    SendNUIMessage({ action = 'adminDealershipDetail', detail = detail })
end)

RegisterNetEvent('ya_tablet:adminCatalog', function(rows)
    if not uiOpen then return end
    SendNUIMessage({ action = 'adminCatalog', rows = rows or {} })
end)

RegisterNetEvent('ya_tablet:cardealerAppData', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'cardealerAppData', data = data or {} })
end)

RegisterNetEvent('ya_tablet:adminDealershipVehicles', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'adminDealershipVehicles', data = data or {} })
end)

RegisterNUICallback('cardealerGetAppData', function(data, cb)
    cardealerEvent('getAppData', data and data.tab or 'oversigt')
    cb('ok')
end)

RegisterNUICallback('cardealerImportVehicle', function(data, cb)
    if data and data.assignmentId then cardealerEvent('importVehicle', data.assignmentId) end
    cb('ok')
end)

RegisterNUICallback('cardealerSellVehicle', function(data, cb)
    if data and data.stockId then
        cardealerEvent('sellVehicle', data)
    end
    cb('ok')
end)

RegisterNUICallback('cardealerGetSalesInvoice', function(data, cb)
    if data and data.invoiceId then cardealerEvent('getSalesInvoice', data.invoiceId) end
    cb('ok')
end)

RegisterNUICallback('adminCaptureDealerSpawn', function(data, cb)
    if data and data.dealershipId then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        cardealerEvent('adminSetSpawnCoords', data.dealershipId, coords.x, coords.y, coords.z, GetEntityHeading(ped))
    end
    cb('ok')
end)

RegisterNUICallback('adminSaveDealerSpawn', function(data, cb)
    if data and data.dealershipId then
        cardealerEvent('adminSetSpawnCoords', data.dealershipId, data.spawnX, data.spawnY, data.spawnZ, data.spawnHeading or 0)
    end
    cb('ok')
end)

RegisterNetEvent('ya_tablet:cardealerSalesInvoice', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'cardealerSalesInvoice', data = data or {} })
end)

RegisterNUICallback('adminGetDealershipVehicles', function(data, cb)
    if data and data.dealershipId then cardealerEvent('adminGetDealershipVehicles', data.dealershipId) end
    cb('ok')
end)

RegisterNUICallback('adminSetDealershipVehicle', function(data, cb)
    if data and data.dealershipId and data.catalogId then
        cardealerEvent('adminSetDealershipVehicle', data.dealershipId, data.catalogId, data.patch or {})
    end
    cb('ok')
end)

RegisterNUICallback('adminSetDealershipBalance', function(data, cb)
    if data and data.dealershipId ~= nil then
        cardealerEvent('adminSetDealershipBalance', data.dealershipId, data.balance)
    end
    cb('ok')
end)

RegisterNUICallback('cardealerGetDashboard', function(_, cb)
    cardealerEvent('getAppData', 'oversigt')
    cb('ok')
end)

local function garageEvent(name, ...)
    TriggerServerEvent(('esx_garage:%s'):format(name), ...)
end

RegisterNUICallback('garageGetAppData', function(_, cb)
    garageEvent('getTabletAppData')
    cb('ok')
end)

RegisterNetEvent('ya_tablet:garageAppData', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'garageAppData', data = data or {} })
end)

RegisterNUICallback('adminListDealerships', function(_, cb)
    cardealerEvent('adminListDealerships')
    cb('ok')
end)

RegisterNUICallback('adminCreateDealership', function(data, cb)
    if data then cardealerEvent('adminCreateDealership', data.name, tonumber(data.ownerId)) end
    cb('ok')
end)

RegisterNUICallback('adminGetDealership', function(data, cb)
    if data and data.dealershipId then cardealerEvent('adminGetDealership', data.dealershipId) end
    cb('ok')
end)

RegisterNUICallback('adminUpdateDealership', function(data, cb)
    if data and data.dealershipId then cardealerEvent('adminUpdateDealership', data.dealershipId, data.patch or {}) end
    cb('ok')
end)

RegisterNUICallback('adminSetDealerLocked', function(data, cb)
    if data and data.dealershipId ~= nil then cardealerEvent('adminSetLocked', data.dealershipId, data.locked == true) end
    cb('ok')
end)

RegisterNUICallback('adminCloseDealership', function(data, cb)
    if data and data.dealershipId then cardealerEvent('adminCloseDealership', data.dealershipId) end
    cb('ok')
end)

RegisterNUICallback('adminSetDealerOwner', function(data, cb)
    if data and data.dealershipId and data.ownerId then cardealerEvent('adminSetOwner', data.dealershipId, tonumber(data.ownerId)) end
    cb('ok')
end)

RegisterNUICallback('adminSetDealerMemberRole', function(data, cb)
    if data and data.dealershipId and data.memberId and data.roleId then
        cardealerEvent('adminSetMemberRole', data.dealershipId, data.memberId, data.roleId)
    end
    cb('ok')
end)

RegisterNUICallback('adminKickDealerMember', function(data, cb)
    if data and data.dealershipId and data.memberId then cardealerEvent('adminKickMember', data.dealershipId, data.memberId) end
    cb('ok')
end)

RegisterNUICallback('adminAddDealerMember', function(data, cb)
    if data and data.dealershipId and data.targetId then cardealerEvent('adminAddMember', data.dealershipId, tonumber(data.targetId)) end
    cb('ok')
end)

RegisterNUICallback('adminListCatalog', function(_, cb)
    cardealerEvent('adminListCatalog')
    cb('ok')
end)

RegisterNUICallback('adminAddCatalogItem', function(data, cb)
    if data then cardealerEvent('adminAddCatalogItem', data) end
    cb('ok')
end)

RegisterNUICallback('adminRemoveCatalogItem', function(data, cb)
    if data and data.catalogId then cardealerEvent('adminRemoveCatalogItem', data.catalogId) end
    cb('ok')
end)

CreateThread(function()

    while true do

        if uiOpen then

            DisableControlAction(0, 1, true)

            DisableControlAction(0, 2, true)

            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then

                closeUI()

            end

            Wait(0)

        else

            Wait(400)

        end

    end

end)



AddEventHandler('onResourceStop', function(resource)

    if resource ~= GetCurrentResourceName() then return end

    closeUI()

end)

local function workshopEvent(name, ...)
    TriggerServerEvent(('ya_workshop:%s'):format(name), ...)
end

RegisterNetEvent('ya_tablet:workshopAppData', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'workshopAppData', data = data or {} })
end)

RegisterNetEvent('ya_tablet:workshopOrderDetail', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'workshopOrderDetail', data = data or {} })
end)

RegisterNetEvent('ya_tablet:workshopInvoiceDetail', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'workshopInvoiceDetail', data = data or {} })
end)

RegisterNetEvent('ya_tablet:workshopInvoiceSearch', function(data)
    if not uiOpen then return end
    SendNUIMessage({ action = 'workshopInvoiceSearch', data = data or {} })
end)

RegisterNetEvent('ya_tablet:adminWorkshops', function(rowsOrPayload, shopCatalog, blipCatalog, blipColors)
    if not uiOpen then
        local rows, catalog, blips, colors = parseAdminWorkshopsPayload(rowsOrPayload, shopCatalog, blipCatalog, blipColors)
        pendingAdminWorkshops = { rows = rows, shopCatalog = catalog, blipCatalog = blips, blipColors = colors }
        return
    end
    local rows, catalog, blips, colors = parseAdminWorkshopsPayload(rowsOrPayload, shopCatalog, blipCatalog, blipColors)
    sendAdminWorkshops(rows, catalog, blips, colors)
end)

RegisterNetEvent('ya_tablet:adminWorkshopDetail', function(detail)
    if not uiOpen then return end
    SendNUIMessage({ action = 'adminWorkshopDetail', detail = detail })
end)

RegisterNUICallback('workshopGetAppData', function(data, cb)
    workshopEvent('getAppData', data and data.tab or 'oversigt')
    cb('ok')
end)

RegisterNUICallback('workshopGetOrderDetail', function(data, cb)
    if data and data.orderId then workshopEvent('getOrderDetail', data.orderId) end
    cb('ok')
end)

RegisterNUICallback('workshopUpdateOrderStatus', function(data, cb)
    if data and data.orderId and data.status then
        workshopEvent('updateOrderStatus', data.orderId, data.status)
    end
    cb('ok')
end)

RegisterNUICallback('workshopDeleteOrder', function(data, cb)
    if data and data.orderId then workshopEvent('deleteOrder', data.orderId) end
    cb('ok')
end)

RegisterNUICallback('workshopSendInvoice', function(data, cb)
    if data and data.orderId then
        workshopEvent('sendOrderInvoice', data.orderId, data.tab)
    end
    cb('ok')
end)

RegisterNUICallback('workshopSendManualInvoice', function(data, cb)
    if data then workshopEvent('sendManualInvoice', data) end
    cb('ok')
end)

RegisterNUICallback('workshopSearchInvoiceCustomers', function(data, cb)
    if data then workshopEvent('searchInvoiceCustomers', data.query or '') end
    cb('ok')
end)

RegisterNUICallback('workshopGetInvoiceDetail', function(data, cb)
    if data and data.invoiceId then workshopEvent('getInvoiceDetail', data.invoiceId) end
    cb('ok')
end)

RegisterNUICallback('workshopAcceptCall', function(data, cb)
    if data and data.callId then workshopEvent('acceptCall', data.callId) end
    cb('ok')
end)

RegisterNUICallback('workshopCloseCall', function(data, cb)
    if data and data.callId then workshopEvent('closeCall', data.callId) end
    cb('ok')
end)

RegisterNUICallback('workshopSetCallWaypoint', function(data, cb)
    if data and data.callId then workshopEvent('setOrderWaypoint', data.callId) end
    cb('ok')
end)

RegisterNUICallback('workshopEmployeeInvite', function(data, cb)
    if data and data.targetId then workshopEvent('employeeInvite', tonumber(data.targetId)) end
    cb('ok')
end)

RegisterNUICallback('workshopEmployeeSetRole', function(data, cb)
    if data and data.memberId and data.roleId then
        workshopEvent('employeeSetMemberRole', data.memberId, data.roleId)
    end
    cb('ok')
end)

RegisterNUICallback('workshopEmployeeKick', function(data, cb)
    if data and data.memberId then workshopEvent('employeeKickMember', data.memberId) end
    cb('ok')
end)

RegisterNUICallback('workshopEmployeeUpsertRole', function(data, cb)
    if data then workshopEvent('employeeUpsertRole', data.roleId, data.name, data.permissions or {}) end
    cb('ok')
end)

RegisterNUICallback('workshopEmployeeDeleteRole', function(data, cb)
    if data and data.roleId then workshopEvent('employeeDeleteRole', data.roleId) end
    cb('ok')
end)

RegisterNUICallback('workshopSavePrice', function(data, cb)
    if data and data.categoryKey and data.groupKey and data.itemKey then
        workshopEvent('savePrice', data.categoryKey, data.groupKey, data.itemKey, tonumber(data.price) or 0)
    end
    cb('ok')
end)

RegisterNUICallback('adminListWorkshops', function(_, cb)
    if GetResourceState('ya_workshop') ~= 'started' then
        SendNUIMessage({ action = 'toast', message = 'ya_workshop kører ikke — skriv ensure ya_workshop i server.cfg.', type = 'error' })
        cb('ok')
        return
    end
    workshopEvent('adminListCompanies')
    cb('ok')
end)

RegisterNUICallback('adminCreateWorkshop', function(data, cb)
    if data then
        workshopEvent('adminCreateCompany', data.name, tonumber(data.ownerId), data.companyType, data.jobName, data.shopKeys or {}, data.shopLocations or {}, data.shopBlips or {})
    end
    cb('ok')
end)

RegisterNUICallback('adminGetWorkshop', function(data, cb)
    if data and data.companyId then workshopEvent('adminGetCompany', data.companyId) end
    cb('ok')
end)

RegisterNUICallback('adminUpdateWorkshop', function(data, cb)
    if data and data.companyId then workshopEvent('adminUpdateCompany', data.companyId, data.patch or {}) end
    cb('ok')
end)

RegisterNUICallback('adminSetWorkshopLocked', function(data, cb)
    if data and data.companyId ~= nil then workshopEvent('adminSetLocked', data.companyId, data.locked == true) end
    cb('ok')
end)

RegisterNUICallback('adminCloseWorkshop', function(data, cb)
    if data and data.companyId then workshopEvent('adminCloseCompany', data.companyId) end
    cb('ok')
end)

RegisterNUICallback('adminSetWorkshopOwner', function(data, cb)
    if data and data.companyId and data.ownerId then
        workshopEvent('adminSetOwner', data.companyId, tonumber(data.ownerId))
    end
    cb('ok')
end)

RegisterNUICallback('adminSetWorkshopMemberRole', function(data, cb)
    if data and data.companyId and data.memberId and data.roleId then
        workshopEvent('adminSetMemberRole', data.companyId, data.memberId, data.roleId)
    end
    cb('ok')
end)

RegisterNUICallback('adminKickWorkshopMember', function(data, cb)
    if data and data.companyId and data.memberId then
        workshopEvent('adminKickMember', data.companyId, data.memberId)
    end
    cb('ok')
end)

RegisterNUICallback('adminAddWorkshopMember', function(data, cb)
    if data and data.companyId and data.targetId then
        workshopEvent('adminAddMember', data.companyId, tonumber(data.targetId))
    end
    cb('ok')
end)

RegisterNUICallback('adminUpsertWorkshopRole', function(data, cb)
    if data and data.companyId then
        workshopEvent('adminUpsertRole', data.companyId, data.roleId, data.name, data.permissions or {})
    end
    cb('ok')
end)

RegisterNUICallback('adminDeleteWorkshopRole', function(data, cb)
    if data and data.companyId and data.roleId then
        workshopEvent('adminDeleteRole', data.companyId, data.roleId)
    end
    cb('ok')
end)

RegisterNUICallback('adminCaptureWorkshopShop', function(data, cb)
    if data and data.shopKey then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        SendNUIMessage({
            action = 'adminShopCaptured',
            shopKey = data.shopKey,
            x = coords.x,
            y = coords.y,
            z = coords.z,
        })
    end
    cb('ok')
end)

