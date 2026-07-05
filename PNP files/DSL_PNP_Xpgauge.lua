-- XP Gauge Script
-- 2/24/2014
--
-- Type "toggle xpgauge" to disable or enable this script.
--

dslpnp.xpgauge = dslpnp.xpgauge or {}
dslpnp.xpgauge.configs = dslpnp.xpgauge.configs or {}

local defaults = {
	height = "2%",
	width = "10%",
	display = "number",
	color = "orange",
	font_size = 12,
	font_color = "white",
	x = "30%", y = "40", origin = "bottomleft",
	orientation = "horizontal",
	color_codes = {
		red = {"#FF0000","#BF0000","#7F0000"},
		vermilion = {"#FF3F00","#BF2F00","#7F1F00"},
		orange = {"#FF7F00","#BF5F00","#7F3F00"},
		amber = {"#FFBF00","#BF8F00","#7F5F00"},
		yellow = {"#FFFF00","#BFBF00","#7F7F00"},
		chartreuse = {"#BFFF00","#8FBF00","#5F7F00"},
		lime = {"#7FFF00","#5FBF00","#3F7F00"},
		emerald = {"#3FFF00","#2FBF00","#1F7F00"},
		green = {"#00FF00","#00BF00","#007F00"},
		aquamarine = {"#00FF3F","#00BF2F","#007F1F"},
		turquoise = {"#00FF7F","#00BF5F","#007F3F"},
		viridian = {"#00FFBF","#00BF8F","#007F5F"},
		cyan = {"#00FFFF","#00BFBF","#007F7F"},
		sky = {"#00BFFF","#008FBF","#005F7F"},
		cobalt = {"#007FFF","#005FBF","#003F7F"},
		ultramarine = {"#003FFF","#002FBF","#001F7F"},
		blue = {"#0000FF","#0000BF","#00007F"},
		indigo = {"#3F00FF","#2F00BF","#1F007F"},
		violet = {"#7F00FF","#5F00BF","#3F007F"},
		purple = {"#BF00FF","#8F00BF","#5F007F"},
		magenta = {"#FF00FF","#BF00BF","#7F007F"},
		lavender = {"#FF00BF","#BF008F","#7F005F"},
		crimson = {"#FF007F","#BF005F","#7F003F"},
		lake = {"#FF003F","#BF002F","#7F001F"},
		white = {"#FFFFFF","#BFBFBF","#7F7F7F"},
		silver = {"#BFBFBF","#8F8F8F","#5F5F5F"},
		gray = {"#7F7F7F","#5F5F5F","#3F3F3F"},
		black = {"#3F3F3F","#2F2F2F","#1F1F1F"}
	}
}

local function config()
	local configs = dslpnp.config.xpgauge or {}
	configs = table.update(defaults,configs)
	dslpnp.xpgauge.configs = configs
	local style, gradstr
	local width, height = configs.width, configs.height
	local x,y = configs.x, configs.y
	local origin = configs.origin
	local orientation = configs.orientation
	local layout = configs.layout
	local color_codes = dslpnp.config.color_codes or defaults.color_codes

	if string.find(origin,"right") then
		x = x .. " + 16"
	end
	if orientation == "horizontal" then
		gradstr = "x1: 0, y1: 0, x2: 0, y2: 1,"
	elseif orientation == "vertical" then
		gradstr = "x1: 0, y1: 0, x2: 1, y2: 0,"
	end

	windowManager.create("xp_bar", "gauge", x, y, width, height, origin)
	local gauge_color = color_codes[configs.color]
	local align_str, padding_str = "", ""
	if orientation == "vertical" then
		align_str = [[ qproperty-alignment: 'AlignHCenter | AlignTop';]]
		padding_str = [[ padding-bottom: 5px;]]
	else
		align_str = [[ qproperty-alignment: 'AlignLeft | AlignVCenter';]]
		padding_str = [[ padding-left: 5px;]]
	end
	setGaugeStyleSheet("xp_bar",[[background-color: QLinearGradient( ]] .. gradstr ..
		[[stop: 0]] .. gauge_color[1] .. [[, stop: 0.2 ]] .. gauge_color[1] .. [[, stop: 0.8 ]] .. gauge_color[2] .. [[, stop: 1 ]] .. gauge_color[2] .. [[);
		border-radius: 3;]],
		[[background-color: QLinearGradient( ]] .. gradstr ..
		[[stop: 0]] .. gauge_color[2] .. [[, stop: 0.2 ]] .. gauge_color[2] .. [[, stop: 0.8 ]] .. gauge_color[3] .. [[, stop: 1 ]] .. gauge_color[3] .. [[);
		border-radius: 3;]],
		padding_str .. [[ font-size: ]] .. configs.font_size .. [[; ]] .. align_str)

	raiseEvent("onToggle","xpgauge","on")
end

function dslpnp.xpgauge.setGauge(curVal, maxVal, text)
	if dslpnp.xpgauge.Active then
		local configs = dslpnp.xpgauge.configs
		maxVal = maxVal or curVal
		local display = configs.display
		local orientation = configs.orientation
		local color = configs.font_color
		local message = ""

		if display == "number" then
			message = "XP: " .. curVal .. "/" .. maxVal
		elseif display == "percent" then
			message = "XP: " .. math.round(100 * curVal / maxVal) .. "%"
		elseif display == "none" then
			message = ""
		end
		message = text or message
		if orientation == "vertical" then
			message = string.gsub(message, ".", "%1<br>")
		end
		setGauge("xp_bar", curVal, maxVal)
		setGaugeText("xp_bar", message, color)
	end
end


local function toggle(setVal)
	dslpnp.xpgauge.Active = dslpnp.toggle("xpgauge",dslpnp.xpgauge.Active, setVal)
	if dslpnp.xpgauge.Active then
		showGauge("xp_bar")
	else
		hideGauge("xp_bar")
	end
end

function dslpnp.xpgauge.eventHandler(event, ...)
	if event == "onPrompt" and dslpnp.xpgauge.Active then
		local level = dslpnp.character.getCharData("level") or 0
		if level < 51 then
			showGauge("xp_bar")
			local curxp, xptnl = dslpnp.prompt.curxp, dslpnp.prompt.xptnl
			local xpper = (curxp + xptnl) / (level + 1)
			dslpnp.xpgauge.setGauge(xptnl, xpper)
		else
			hideGauge("xp_bar")
		end
	elseif event == "onToggle" and arg[1] == "xpgauge" then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "xpgauge" then
		config()
	end
end

registerAnonymousEventHandler("onPrompt", "dslpnp.xpgauge.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.xpgauge.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.xpgauge.eventHandler")
