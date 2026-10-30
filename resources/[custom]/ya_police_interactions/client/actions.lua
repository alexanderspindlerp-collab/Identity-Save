function YAPolice.SearchPlayer(serverId)
    TriggerEvent('ya_police:client:openSearch', serverId)
end

function YAPolice.Handcuff(serverId, cuffStyle)
    TriggerServerEvent('ya_police:server:handcuff', serverId, cuffStyle)
end

function YAPolice.Escort(serverId)
    YAPolice.PlayAnim(cache.ped, Config.Anims.EscortCop, -1)
    TriggerServerEvent('esx_policejob:drag', serverId)
end

function YAPolice.PutInVehicle(serverId, entity)
    local handcuffed = YAPolice.IsTargetHandcuffed(entity)
    local meText = handcuffed and 'Putter sele på personen' or nil

    YAPolice.PlayVehicleAction(Config.Anims.PutInVehicle, meText, 'esx_policejob:putInVehicle', serverId)
end

function YAPolice.OutVehicle(serverId, entity)
    local handcuffed = YAPolice.IsTargetHandcuffed(entity)
    local meText = handcuffed and 'Tager sele af personen' or nil

    YAPolice.PlayVehicleAction(Config.Anims.OutVehicle, meText, 'esx_policejob:OutVehicle', serverId)
end

function YAPolice.GsrTest(serverId)
    YAPolice.DoActionWithProgress('GSR-test i gang...', Config.Timings.GsrTestMs, Config.Anims.GsrTest, true, function()
        local status = lib.callback.await('bzn_gsr:server:check:gsr', false, serverId)
        if status then
            ESX.ShowNotification('GSR — ~g~Positiv~s~: Krudtslam fundet.')
        else
            ESX.ShowNotification('GSR — ~r~Negativ~s~: Intet krudtslam fundet.')
        end
    end)
end

function YAPolice.AlcoholTest(serverId)
    YAPolice.DoActionWithProgress('Alkoholtest i gang...', Config.Timings.AlcoholTestMs, Config.Anims.AlcoholTest, true, function()
        local result = lib.callback.await('ya_police:server:alcoholTest', false, serverId)
        local promille = result.promille or 0
        local legal = Config.DrunkLegalPromille or 0.50

        ESX.ShowNotification(('Alkoholtest — ~y~%.2f‰~s~'):format(promille))

        if result.positive then
            ESX.ShowNotification(('~r~Påvirket~s~ over lovlig grænse (%.2f‰).'):format(legal))
        else
            ESX.ShowNotification(('~g~Under~s~ lovlig grænse (%.2f‰).'):format(legal))
        end
    end)
end

function YAPolice.DrugTest(serverId)
    YAPolice.DoActionWithProgress('Narkotest i gang...', Config.Timings.DrugTestMs, Config.Anims.DrugTest, true, function()
        local result = lib.callback.await('ya_police:server:drugTest', false, serverId)
        if result.positive then
            local labels = {}
            for i = 1, #(result.substances or {}) do
                labels[#labels + 1] = result.substances[i].label or result.substances[i].substance
            end
            ESX.ShowNotification(('Narkotest — ~g~Positiv~s~: %s i blodet.'):format(table.concat(labels, ', ')))
        else
            ESX.ShowNotification('Narkotest — ~r~Negativ~s~: Intet fundet i blodet.')
        end
    end)
end

function YAPolice.DnaSample(serverId)
    YAPolice.DoActionWithProgress('Indsamler DNA-prøve...', Config.Timings.DnaSampleMs, Config.Anims.DnaSample, true, function()
        local result = lib.callback.await('ya_police:server:collectDna', false, serverId)
        if not result or not result.ok then
            ESX.ShowNotification('DNA-prøve mislykkedes.')
            return
        end

        ESX.ShowNotification('DNA-prøve indsamlet.')
        ESX.ShowNotification(('DNA Reference: ~b~%s~s~'):format(result.dnaId))
        ESX.ShowNotification('Registreret i kriminalteknisk database (MDT KRIM).')
    end)
end
