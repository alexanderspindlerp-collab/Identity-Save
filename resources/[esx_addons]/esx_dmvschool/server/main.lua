
ESX.RegisterServerCallback('esx_dmvschool:getLicenses', function(source, cb)
	TriggerEvent('esx_license:getLicenses', source, function(licenses)
		cb(licenses or {})
	end)
end)

ESX.RegisterServerCallback('esx_dmvschool:canYouPay', function(source, cb, type)
	local xPlayer = ESX.GetPlayerFromId and ESX.GetPlayerFromId(source) or ESX.Player(source)
	local price = Config.Prices[type]

	if not xPlayer or not price then
		print(('[esx_dmvschool] Payment failed. Invalid player or license type: %s'):format(tostring(type)))
		cb(false)
		return
	end

	if xPlayer.getMoney() >= price then
		xPlayer.removeMoney(price, "DMV Purchase")
		TriggerClientEvent('esx:showNotification', source, TranslateCap('you_paid', price))
		cb(true)
	else
		cb(false)
	end
end)

AddEventHandler('esx:playerLoaded', function(source)
	TriggerEvent('esx_license:getLicenses', source, function(licenses)
		TriggerClientEvent('esx_dmvschool:loadLicenses', source, licenses)
	end)
end)

RegisterNetEvent('esx_dmvschool:addLicense')
AddEventHandler('esx_dmvschool:addLicense', function(type)
	local source = source

	TriggerEvent('esx_license:addLicense', source, type, function()
		TriggerEvent('esx_license:getLicenses', source, function(licenses)
			TriggerClientEvent('esx_dmvschool:loadLicenses', source, licenses)
		end)
	end)
end)

