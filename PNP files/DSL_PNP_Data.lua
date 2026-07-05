-- Data Script
-- 11/05/2014
-- v4.00a
--

dslpnp.data = dslpnp.data or {}

local data_path = getMudletHomeDir() .. "/PNP/DSL_data"

function dslpnp.data.eventHandler(event, ...)
	if event == "loadData" then
		if not io.exists(data_path) then
			table.save(data_path,{})
		end
		table.load(data_path, dslpnp.data)
	elseif not table.is_empty(dslpnp.data) then
		if event == "saveData" then
			table.save(data_path, dslpnp.data)
		elseif event == "sysExitEvent" then
			table.save(data_path, dslpnp.data)
		elseif event == "sysDisconnectionEvent" then
			table.save(data_path, dslpnp.data)
		end
	end
end

registerAnonymousEventHandler("saveData", "dslpnp.data.eventHandler")
registerAnonymousEventHandler("loadData", "dslpnp.data.eventHandler")
registerAnonymousEventHandler("sysExitEvent", "dslpnp.data.eventHandler")
registerAnonymousEventHandler("sysDisconnectionEvent", "dslpnp.data.eventHandler")
