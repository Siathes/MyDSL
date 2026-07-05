-- Tick Timer Script
-- 01/11/2015
-- v4.01c
--

dslpnp.ticktimer = dslpnp.ticktimer or {}
dslpnp.ticktimer.configs = dslpnp.ticktimer.configs or {}

local defaults = {
	average = 40,
	window = 5,
	increment = 0.25, -- needs to be a multiple of 0.05
	height = "4%",
	width = "2%",
	color = "gray",
	message_on_tick = "TICK!",
	message_color = "red",
	display_tick_times = true,
	warn_time = 5,
	close_time = 15,
	color_warn = false,
	color_warn_message = false,
	warn_colors = {
		close = "yellow",
		warn = "red",
		message = "red",
	},
	warn_message = "5 seconds until tick!",
	x = 0, y = 0, origin = "bottomright",
	orientation = "vertical",
	show_text_in_gauge = true,
	font_size = 12,
	font_color = "white",
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

local currentTickTime = 0
local averageTickTime

local myTickTimer

local function colorTickTimer(gauge_colors)
	local configs = dslpnp.ticktimer.configs
	local gradstr
	local orientation = configs.orientation

	if orientation == "horizontal" then
		gradstr = "x1: 0, y1: 0, x2: 0, y2: 1,"
	elseif orientation == "vertical" then
		gradstr = "x1: 0, y1: 0, x2: 1, y2: 0,"
	end
	local align_str, padding_str = "", ""
	if orientation == "vertical" then
		align_str = [[ qproperty-alignment: 'AlignHCenter | AlignTop';]]
		padding_str = [[ padding-bottom: 5px;]]
	else
		align_str = [[ qproperty-alignment: 'AlignLeft | AlignVCenter';]]
		padding_str = [[ padding-left: 5px;]]
	end
	setGaugeStyleSheet("tick_timer_gauge",[[background-color: QLinearGradient( ]] .. gradstr ..
		[[stop: 0]] .. gauge_colors[1] .. [[, stop: 0.2 ]] .. gauge_colors[1] .. [[, stop: 0.8 ]] .. gauge_colors[2] .. [[, stop: 1 ]] .. gauge_colors[2] .. [[);
		border-radius: 3;]],
		[[background-color: QLinearGradient( ]] .. gradstr ..
		[[stop: 0]] .. gauge_colors[2] .. [[, stop: 0.2 ]] .. gauge_colors[2] .. [[, stop: 0.8 ]] .. gauge_colors[3] .. [[, stop: 1 ]] .. gauge_colors[3] .. [[);
		border-radius: 3;]],
		padding_str .. [[ font-size: ]] .. configs.font_size .. [[; ]] .. align_str)
end

local function startTickTimer()
	local configs = dslpnp.ticktimer.configs
	if math.abs(averageTickTime - currentTickTime) < configs.window then
		averageTickTime = 0.01 * math.floor(90 * averageTickTime +  10 * currentTickTime)
	else
		averageTickTime = configs.average
	end
	currentTickTime = 0
	if not dslpnp.timers.exists("Tick Timer Gauge Timer") then
		dslpnp.timers.register(configs.increment,dslpnp.ticktimer.increment_tick_timer,"Tick Timer Gauge Timer",true)
	end
	colorTickTimer(configs.color_codes[configs.color])
end

local function displayTickTimes()
	 echo(" " .. currentTickTime .. " / " .. averageTickTime)
end

local function checkTickTime()
	local configs = dslpnp.ticktimer.configs
	local curTime = configs.increment * math.floor((1 / configs.increment) * (averageTickTime - currentTickTime))
	if curTime == configs.warn_time then
		cecho("\n<" .. (configs.color_warn_message and configs.warn_colors.message or "reset") .. ">" .. configs.warn_message .. "\n")
		raiseEvent("onTickWarn",configs.warn_time)
		if configs.color_warn then colorTickTimer(configs.color_codes[configs.warn_colors.warn]) end
	elseif curTime == configs.close_time and configs.color_warn then
		colorTickTimer(configs.color_codes[configs.warn_colors.close])
	end
end

local function setTimeGauge(curTime, maxTime)
	assert(tonumber(curTime), "Invalid current time!")
	assert(tonumber(maxTime), "Invalid maximum time!")
	local configs = dslpnp.ticktimer.configs
	-- update tick timer gauge
	if curTime < maxTime then
		setGauge("tick_timer_gauge",maxTime - curTime, maxTime)
	else
		setGauge("tick_timer_gauge",0, maxTime)
	end
	if configs.show_text_in_gauge then
		setGaugeText("tick_timer_gauge",math.floor(maxTime - curTime),configs.font_color)
	end
end

local function showTickInfo()
	local configs = dslpnp.ticktimer.configs
	cecho("\n<" .. configs.message_color .. ">" .. configs.message_on_tick .. "<reset>")
	if configs.display_tick_times then
		displayTickTimes()
	end
	startTickTimer()
end

local function newTick()
	if dslpnp.ticktimer.Active then
		dslpnp.timers.register(0,showTickInfo)
	end
end

function dslpnp.ticktimer.increment_tick_timer()
	if dslpnp.ticktimer.Active then
		currentTickTime = currentTickTime + dslpnp.ticktimer.configs.increment
		if currentTickTime > averageTickTime + 5 then
			dslpnp.timers.remove("Tick Timer Gauge Timer")
		end
		checkTickTime()
		setTimeGauge(currentTickTime, averageTickTime)
	end
end

local function config()
	local configs = dslpnp.config.ticktimer or {}
	configs = table.update(defaults,configs)
	dslpnp.ticktimer.configs = configs
	local style, gradstr
	local width, height = configs.width, configs.height
	local x,y = configs.x, configs.y
	local origin = configs.origin
	local orientation = configs.orientation
	local offset = (dslpnp.config.sidebar and dslpnp.config.sidebar.width) or "0"
	local color_codes = dslpnp.config.color_codes or defaults.color_codes

	averageTickTime = configs.average

	if string.find(origin,"right") then
		x = x .. " + " .. offset .. " + 16"
	end
	if orientation == "horizontal" then
		gradstr = "x1: 0, y1: 0, x2: 0, y2: 1,"
	elseif orientation == "vertical" then
		gradstr = "x1: 0, y1: 0, x2: 1, y2: 0,"
	end

	createGauge("tick_timer_gauge", 0, 0, 0, 0, nil, nil, orientation)
	windowManager.add("tick_timer_gauge", "gauge", x, y, width, height, origin)
	local gauge_colors = color_codes[configs.color]
	local align_str, padding_str = "", ""
	if orientation == "vertical" then
		align_str = [[ qproperty-alignment: 'AlignHCenter | AlignTop';]]
		padding_str = [[ padding-bottom: 5px;]]
	else
		align_str = [[ qproperty-alignment: 'AlignLeft | AlignVCenter';]]
		padding_str = [[ padding-left: 5px;]]
	end
	setGaugeStyleSheet("tick_timer_gauge",[[background-color: QLinearGradient( ]] .. gradstr ..
		[[stop: 0]] .. gauge_colors[1] .. [[, stop: 0.2 ]] .. gauge_colors[1] .. [[, stop: 0.8 ]] .. gauge_colors[2] .. [[, stop: 1 ]] .. gauge_colors[2] .. [[);
		border-radius: 3;]],
		[[background-color: QLinearGradient( ]] .. gradstr ..
		[[stop: 0]] .. gauge_colors[2] .. [[, stop: 0.2 ]] .. gauge_colors[2] .. [[, stop: 0.8 ]] .. gauge_colors[3] .. [[, stop: 1 ]] .. gauge_colors[3] .. [[);
		border-radius: 3;]],
		padding_str .. [[ font-size: ]] .. configs.font_size .. [[; ]] .. align_str)

	raiseEvent("onToggle","ticktimer","on")
end

function dslpnp.ticktimer.setGauge(curVal, maxVal)
	if dslpnp.ticktimer.Active then
		setTimeGauge(curVal, maxVal)
	end
end

local function toggle(setVal)
	dslpnp.ticktimer.Active = dslpnp.toggle("ticktimer",dslpnp.ticktimer.Active, setVal)
	if dslpnp.ticktimer.Active then
		showGauge("tick_timer_gauge")
	else
		hideGauge("tick_timer_gauge")
	end
end

function dslpnp.ticktimer.eventHandler(event, ...)
	if event == "onTick" and dslpnp.ticktimer.Active then
		newTick()
	elseif event == "onToggle" and arg[1] == "ticktimer" then
		toggle(arg[2])
	elseif event == "onConfig" and arg[1] == "ticktimer" then
		config()
	end
end

registerAnonymousEventHandler("onTick", "dslpnp.ticktimer.eventHandler")
registerAnonymousEventHandler("onToggle", "dslpnp.ticktimer.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.ticktimer.eventHandler")
