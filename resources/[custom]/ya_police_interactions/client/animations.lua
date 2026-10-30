RegisterNetEvent('ya_police:client:copCuffAnim', function(cuffStyle)
    local ped = cache.ped
    local style = YAPolice.GetCuffStyle(cuffStyle)
    local anim = style.copAnim
    YAPolice.PlayAnim(ped, anim, anim.duration)
    Wait(anim.duration)
    ClearPedTasks(ped)
end)

RegisterNetEvent('ya_police:client:cuffAnim', function(cuffStyle)
    local ped = cache.ped
    local style = YAPolice.GetCuffStyle(cuffStyle)
    local anim = style.suspectAnim
    YAPolice.PlayAnim(ped, anim, anim.duration)
end)

function YAPolice.DoActionWithProgress(label, durationMs, anim, canCancel, onDone)
    if anim then
        YAPolice.PlayAnim(cache.ped, anim, durationMs)
    end

    local prop
    if anim == Config.Anims.AlcoholTest then
        prop = YAPolice.AttachProp(cache.ped, Config.Props.Breathalyzer, 57005, vec3(0.12, 0.02, 0.0), vec3(-80.0, 0.0, 0.0))
    elseif anim == Config.Anims.DrugTest then
        prop = YAPolice.AttachProp(cache.ped, Config.Props.DrugTest, 57005, vec3(0.1, 0.02, 0.0), vec3(0.0, 0.0, 0.0))
    elseif anim == Config.Anims.DnaSample then
        prop = YAPolice.AttachProp(cache.ped, Config.Props.DnaSwab, 57005, vec3(0.08, 0.02, 0.0), vec3(0.0, 90.0, 0.0))
    end

    local ok = lib.progressBar({
        label = label,
        duration = durationMs,
        useWhileDead = false,
        canCancel = canCancel ~= false,
        disable = { move = true, car = true, combat = true },
    })

    ClearPedTasks(cache.ped)
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end

    if ok and onDone then onDone() end
    return ok
end

function YAPolice.PlayVehicleAction(anim, meText, serverEvent, serverId)
    YAPolice.DoActionWithProgress('Udfører handling...', Config.Timings.SeatbeltMs, anim, true, function()
        if meText and meText ~= '' then
            TriggerServerEvent('ya_police:server:meAction', meText)
        end
        TriggerServerEvent(serverEvent, serverId)
    end)
end
