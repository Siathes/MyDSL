-- Growl Script
-- 1/28/2013
--
-- Use the following code to raise an alert in Growl:
-- raiseEvent("onGrowlAlert", message, title, is_priority, is_sticky)
-- All arguments after message are optional.
--
-- Example: raiseEvent("onGrowlAlert", matches[1], "Incoming Tell", false, true)
--

dslpnp.growl = dslpnp.growl or {}
dslpnp.growl.help = [[Use the following code to raise an alert in Growl:
raiseEvent("onGrowlAlert", message, title, is_priority, is_sticky)
All arguments after message are optional.

Example: raiseEvent("onGrowlAlert", matches[1], "Incoming Tell", false, true)]]

local defaults = {
	path = "/usr/local/bin/growlnotify", --Path: This is the default path, change it if you have it somewhere else.
	icon = "-a Mudlet.app"
}

local function growlNotify(message, title, priority, sticky)
	assert(message, "Growl Alert: no message!")
	assert(type(priority)=="boolean" or type(priority)=="nil", "Growl Alert: invalid priority type!")
	assert(type(sticky)=="boolean" or type(sticky)=="nil", "Growl Alert: invalid sticky type!")
	
	local path = dslpnp.config.growl.path or defaults.path
	local icon = dslpnp.config.growl.icon or defaults.icon
	
	message = string.gsub(message, [["]], "'") or ""
	sticky = sticky and " -s " or " "
	priority = priority and " -p 2" or ""
	title = title or "Mudlet"
	if not hasFocus() or priority ~= "" then
		os.execute( defaults.path .. sticky .. defaults.icon .. priority .. [[ -m " ]] .. message .. [[ " " ]]..title..[[ "]])
	end
end

function dslpnp.growl.eventHandler(event, ...)
	if event == "onGrowlAlert" then
		growlNotify(arg[1], arg[2], arg[3], arg[4])
	end
end

registerAnonymousEventHandler("onGrowlAlert", "dslpnp.growl.eventHandler")
