-- Compass Script
-- 11/28/2014
-- v4.00a
--

dslpnp.compass = dslpnp.compass or {}
dslpnp.compass.labels = dslpnp.compass.labels or {}
dslpnp.compass.configs = dslpnp.compass.configs or {}

local defaults = {
	width = 100,
	height = 100,
	x = "35%", y = 0, origin = "topright",
}

local path = string.gsub(getMudletHomeDir() .. "/icons/",[[\]],"/")
local on_imgs = {
	n = "n_arrow.png",
	s = "s_arrow.png",
	e = "e_arrow.png",
	w = "w_arrow.png",
	u = "n_arrow.png",
	d = "s_arrow.png",
	nw = "nw_arrow.png",
	ne = "ne_arrow.png",
	sw = "sw_arrow.png",
	se = "se_arrow.png"
	}
local off_imgs = {
	n = "n_arrow_off.png",
	s = "s_arrow_off.png",
	e = "e_arrow_off.png",
	w = "w_arrow_off.png",
	u = "n_arrow_off.png",
	d = "s_arrow_off.png",
	nw = "nw_arrow_off.png",
	ne = "ne_arrow_off.png",
	sw = "sw_arrow_off.png",
	se = "se_arrow_off.png"
	}

local cur_exits = cur_exits or {}
local old_exits = old_exits or {}

local function update()
	-- store old exits
	old_exits = cur_exits
	-- clear current exits
	cur_exits = {n = false,s = false,e = false,w = false,u = false,d = false,nw = false,ne = false,sw = false,se = false}
	local exits = (dslpnp.prompt and dslpnp.prompt.exits) or ""
	exits = string.lower(exits)
	-- populate table with exits
	local tbl = string.split(exits,"-")
	local tmp = table.remove(tbl,1)
	for k = 1,#tmp do
		table.insert(tbl,string.sub(tmp,k,k))
	end
	-- mark available exits
	for k,v in ipairs(tbl) do
		cur_exits[v] = true
	end
	-- create table of changed exits
	tmp = table.complement(cur_exits,old_exits)
	-- set images as needed
	for k,v in pairs(tmp) do
		if v then
			setLabelStyleSheet(dslpnp.compass.labels[k],[[border-image: url(]] .. path .. on_imgs[k] .. ");qproperty-alignment: AlignCenter;")
		else
			setLabelStyleSheet(dslpnp.compass.labels[k],[[border-image: url(]] .. path .. off_imgs[k] .. ");qproperty-alignment: AlignCenter;")
		end
	end
end

local function toggle(setVal)
	dslpnp.compass.Active = dslpnp.toggle("compass",dslpnp.compass.Active, setVal)
	if dslpnp.compass.Active then
		for k,v in pairs(dslpnp.compass.labels) do
			showWindow(v)
		end
		update()
	else
		for k,v in pairs(dslpnp.compass.labels) do
			hideWindow(v)
		end
	end
end

local function config()
	local configs = dslpnp.config.compass or {}
	configs = table.update(defaults,configs)
	dslpnp.compass.configs = configs
	local width, height = configs.width, configs.height
	local x,y = configs.x, configs.y
	local origin = configs.origin

	local dirs = {"nw","n","ne","w","u","d","e","sw","s","se"}
	-- relative size and positions of each label, aligns with dirs table
	local heights = {.3,.3,.3,.4,.2,.2,.4,.3,.3,.3}
	local widths = {.3,.4,.3,.3,.4,.4,.3,.3,.4,.3}
	local x_pos = {0,.3,.7,0,.3,.3,.7,0,.3,.7}
	local y_pos = {0,0,0,.3,.3,.5,.3,.7,.7,.7}

	local val
	-- scale sizes
	for k = 1,10 do
		heights[k] = windowManager.math(height,heights[k],"multiply")
		y_pos[k] = windowManager.math(height,y_pos[k],"multiply")
		widths[k] = windowManager.math(width,widths[k],"multiply")
		x_pos[k] = windowManager.math(width,x_pos[k],"multiply")
	end

	-- adjust x and y positions when positioned on the right or on the bottom
	if string.find(origin,"right") then
		x = x .. " + 16"
		for k,v in ipairs(x_pos) do
			x_pos[k] = windowManager.math(width,v,"subtract")
			x_pos[k] = windowManager.math(x_pos[k],widths[k],"subtract")
		end
	end
	if string.find(origin,"bottom") then
		for k,v in ipairs(y_pos) do
			y_pos[k] = windowManager.math(height,v,"subtract")
			y_pos[k] = windowManager.math(y_pos[k],heights[k],"subtract")
		end
	end

	-- create, size, and position image labels
	for k = 1, 10 do
		dslpnp.compass.labels[dirs[k]] = "compass_image_" .. k
		createLabel("compass_image_" .. k,0,0,0,0,1)
		windowManager.add("compass_image_" .. k,"label",windowManager.math(x_pos[k],x,"add"),windowManager.math(y_pos[k],y,"add"),widths[k],heights[k],origin)
		showWindow("compass_image_" .. k)
	end

	-- create icon folder if it doesn't exist
	if not io.exists(getMudletHomeDir() .. "/icons") then
		lfs.mkdir(getMudletHomeDir() .. "/icons")
	end

	-- download icons
	local path = getMudletHomeDir() .. "/icons/"
	local download_path = dslpnp.config.download_path .. "/icons/"
	for k,v in pairs(on_imgs) do
		downloadFile(path..v,download_path..v)
	end
	for k,v in pairs(off_imgs) do
		downloadFile(path..v,download_path..v)
	end

	-- toggle script on
	raiseEvent("onToggle","compass","on")
end

function dslpnp.compass.eventHandler(event, ...)
	if event == "onPrompt" and dslpnp.compass.Active then
		update()
	elseif event == "onToggle" and (arg[1] == "compass") then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "compass" then
		config()
	end
end

registerAnonymousEventHandler("onToggle", "dslpnp.compass.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.compass.eventHandler")
registerAnonymousEventHandler("onPrompt", "dslpnp.compass.eventHandler")
