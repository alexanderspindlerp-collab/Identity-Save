RegisterNetEvent('esx_rpchat:sendProximityMessage')
AddEventHandler('esx_rpchat:sendProximityMessage', function(playerId, title, message, color)
	local player = PlayerId()
	local target = GetPlayerFromServerId(playerId)

	if target ~= -1 then
		local playerPed = PlayerPedId()
		local targetPed = GetPlayerPed(target)
		local playerCoords = GetEntityCoords(playerPed)
		local targetCoords = GetEntityCoords(targetPed)

		if target == player or #(playerCoords - targetCoords) <= 20.0 then
			TriggerEvent('chat:addMessage', { args = { title, message }, color = color })
		end
	end
end)

CreateThread(function()
	TriggerEvent('chat:addSuggestion', '/ool', 'Lokal OOC besked (20 meter)', {
		{ name = 'besked', help = 'Beskeden som kun spillere tæt på kan se' }
	})

	TriggerEvent('chat:addSuggestion', '/staffmsg', 'Send STAFF besked til en spiller', {
		{ name = 'id', help = 'Spillerens ID' },
		{ name = 'besked', help = 'Beskeden spilleren skal modtage' }
	})
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		TriggerEvent('chat:removeSuggestion', '/ool')
		TriggerEvent('chat:removeSuggestion', '/staffmsg')
	end
end)
