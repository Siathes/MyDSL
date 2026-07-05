-- Affects Bar Script
-- 11/21/2014
-- v4.01c
--

dslpnp.affects.bar = dslpnp.affects.bar or {}
dslpnp.affects.bar.image = dslpnp.affects.bar.image or {}
dslpnp.affects.bar.border = dslpnp.affects.bar.border or {}
dslpnp.affects.bar.configs = dslpnp.affects.bar.configs or {}

local defaults = {
	rows = 20,
	columns = 2,
	width = "3.25%",
	height = "5%",
	x = "30%", y = 0, origin = "topright",
	warn_ticks = 5,
	warn_color = "yellow",
	critical_ticks = 0,
	critical_color = "red",
	normal_color = "green",
	bold = false,
	font_size = 9,
	font_color = "white",
	alignment = "center"
}

local hide_spell = {
	"toughness"
}
local spell_list = {}

local function update_bar()
	local configs = dslpnp.affects.bar.configs
	local path = string.gsub(getMudletHomeDir() .. "/icons/",[[\]],"/")
	local alignment = configs.alignment
	local padding, name
	if alignment == "center" then
		alignment = "qproperty-alignment: AlignCenter;"
		padding = ""
	else
		alignment = "qproperty-alignment: 'AlignRight | AlignBottom';"
		padding = " "
	end
	local rows, columns = configs.rows, configs.columns
	local total = rows * columns
	local text
	for k = 1, total do
		hideWindow("af_image_" .. k)
		hideWindow("af_border_" .. k)
	end
	if not table.is_empty(spell_list) then
		table.sort(spell_list, function(a,b) return (a[2]<b[2] and a[2]>-1) or (a[2]<b[2] and b[2]<0) or (a[2]==b[2] and a[1]<b[1]) or (a[2]>-1 and b[2]<0) end)
	end

	local index = 0
	for k,v in ipairs(spell_list) do
		index = index + 1
		showWindow("af_image_" .. index)
		showWindow("af_border_" .. index)
		name = string.gsub(v[1]," ","_") .. ".png"
		if io.exists(path .. name) then
			setLabelStyleSheet("af_image_" .. index,[[border-image: url(]] .. path .. name .. ");" .. alignment)
			text = dslpnp.support.formatLabelText(((v[2] >= 0 and v[2]) or "") .. padding, configs.font_size, false, configs.bold, false, false, "white")
			echo("af_image_" .. index, text)
		else
			setLabelStyleSheet("af_image_" .. index,[[qproperty-alignment: AlignCenter;]])
			text = dslpnp.support.formatLabelText(v[1] .. ((v[2] >= 0 and ("<br>" .. v[2])) or ""), configs.font_size, true, configs.bold, false, false, "white")
			echo("af_image_" .. index, text)
		end
		if v[2] > configs.warn_ticks or v[2] == -2 then
			setLabelStyleSheet("af_border_" .. index,[[
				border: 2px solid ]] .. configs.normal_color .. [[;
				border-radius: 5px;
				background-color: rgba(0,0,0,0)]])
		elseif v[2] > configs.critical_ticks then
			setLabelStyleSheet("af_border_" .. index,[[
				border: 2px solid ]] .. configs.warn_color .. [[;
				border-radius: 5px;
				background-color: rgba(0,0,0,0)]])
		else
			setLabelStyleSheet("af_border_" .. index,[[
				border: 2px solid ]] .. configs.critical_color .. [[;
				border-radius: 5px;
				background-color: rgba(0,0,0,0)]])
		end
	end
end

local function add_spell(name, duration)
	duration = duration or -1
	if duration == "permanently" then duration = -2 end
	if duration == "" then duration = -1 end
	assert(type(name) == "string","Invalid name!")
	duration = assert(tonumber(duration), "Invalid duration!")

	if not table.contains(hide_spell,name) then
		if not table.contains(spell_list,name) then
			table.insert(spell_list,{name,duration})
		else
			for k,v in ipairs(spell_list) do
				if v[1] == name then
					spell_list[k] = {name, duration}
					break
				end
			end
		end
		update_bar()
	end
end

local function remove_spell(name)
	for k,v in ipairs(spell_list) do
		if v[1] == name then
			table.remove(spell_list,k)
			update_bar()
		end
	end
end

local function decrement_affects()
	for k,v in ipairs(spell_list) do
		if v[2] >= 0 then
			spell_list[k][2] = v[2] - 1
		end
	end
	update_bar()
end

local function toggle(setVal)
	dslpnp.affects.bar.Active = dslpnp.toggle("affects : bar",dslpnp.affects.bar.Active, setVal)
	if dslpnp.affects.bar.Active then
		update_bar()
	else
		local configs = dslpnp.affects.bar.configs or {}
		local rows, columns = configs.rows or 0, configs.columns or 0
		local total = rows * columns
		for k = 1, total do
			hideWindow("af_image_" .. k)
			hideWindow("af_border_" .. k)
		end
	end
end

local function config()
	local configs = dslpnp.config.affects.bar or {}
	configs = table.update(defaults,configs)
	dslpnp.affects.bar.configs = configs
	local width, height = configs.width, configs.height
	local x,y = configs.x, configs.y
	local origin = configs.origin

	if string.find(origin,"right") then
		x = x .. " + 16"
	end

	local index, tmp_x, tmp_y
	for k1 = 1, configs.rows do
		tmp_x = x
		if k1 > 1 then
			tmp_y = tmp_y .. " + " .. height
		else
			tmp_y = y
			index = 0
		end
		for k2 = 1, configs.columns do
			if k2 > 1 then
				tmp_x = tmp_x .. " + " .. width
			end
			index = index + 1
			createLabel("af_image_" .. index,0,0,0,0,1)
			createLabel("af_border_" .. index,0,0,0,0,1)
			windowManager.add("af_image_" .. index,"label",tmp_x,tmp_y,width,height,origin)
			windowManager.add("af_border_" .. index,"label",tmp_x,tmp_y,width,height,origin)
			setLabelStyleSheet("af_border_" .. index,[[
				border: 2px solid white;
				border-radius: 5px;
				background-color: rgba(0,0,0,0)]])
			echo("af_image_" .. index, dslpnp.support.formatLabelText(tostring(index), 12, true, true, false, false, "white"))
			setBackgroundColor("af_image_" .. index,0,0,0,255)
			showWindow("af_image_" .. index)
			showWindow("af_border_" .. index)
		end
	end
	raiseEvent("onToggle","affects.bar","on")
	return true
end

function dslpnp.affects.bar.eventHandler(event, ...)
	if event == "onToggle" and (arg[1] == "affectsbar" or arg[1] == "affects.bar") then
		toggle(arg[2])
	elseif event == "onTick" and dslpnp.affects.bar.Active then
		decrement_affects()
	elseif event == "affectAdd" and dslpnp.affects.bar.Active then
		add_spell(arg[1],arg[2])
	elseif event == "affectRemove" or event == "affectClear" and dslpnp.affects.bar.Active then
		remove_spell(arg[1])
	elseif event == "onConfig" and arg[1] == "affects.bar" then
		config()
	end
end

registerAnonymousEventHandler("onToggle", "dslpnp.affects.bar.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.affects.bar.eventHandler")
registerAnonymousEventHandler("onTick", "dslpnp.affects.bar.eventHandler")
registerAnonymousEventHandler("affectAdd", "dslpnp.affects.bar.eventHandler")
registerAnonymousEventHandler("affectRemove", "dslpnp.affects.bar.eventHandler")
registerAnonymousEventHandler("affectClear", "dslpnp.affects.bar.eventHandler")
