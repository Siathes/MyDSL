-- Borders Script
-- 2/24/2014

dslpnp.borders = dslpnp.borders or {}
dslpnp.borders.configs = dslpnp.borders.configs or {}

local defaults = {
	top = 0,
	left = 0,
	right = 0,
	bottom = "40 + 2%"
}

local resizing = false

local function resizeBorders()
	if not resizing then
		resizing = true
		setBorderLeft(windowManager.getValue("border_bottom_left_corner","width"))
		setBorderBottom(windowManager.getValue("border_bottom_left_corner","height"))
		setBorderRight(windowManager.getValue("border_top_right_corner","width"))
		setBorderTop(windowManager.getValue("border_top_right_corner","height"))
		resizing = false
	end
end

local function config()
	dslpnp.borders.configs = table.update(defaults, dslpnp.config.borders or {})
	windowManager.create("border_bottom_left_corner","label",0,0,dslpnp.borders.configs.left,dslpnp.borders.configs.bottom,"bottomleft")
	windowManager.create("border_top_right_corner","label",0,0,dslpnp.borders.configs.right,dslpnp.borders.configs.top,"topright")
	windowManager.hide("border_bottom_left_corner")
	windowManager.hide("border_top_right_corner")
	raiseEvent("onToggle","borders","on")
end

local function toggle(setVal)
	dslpnp.borders.Active = dslpnp.toggle("borders",dslpnp.borders.Active, setVal)
	if dslpnp.borders.Active then
		resizeBorders()
	else
		setBorderLeft(0)
		setBorderBottom(0)
		setBorderRight(0)
		setBorderTop(0)
	end
end

function dslpnp.borders.eventHandler(event, ...)
	if event == "onConfig" and arg[1] == "borders" then
		config()
	elseif event == "onToggle" and arg[1] == "borders" then
		toggle(arg[2])
	elseif event == "sysWindowResizeEvent" and dslpnp.borders.Active then
		resizeBorders()
	end
end

registerAnonymousEventHandler("onToggle", "dslpnp.borders.eventHandler")
registerAnonymousEventHandler("onConfig", "dslpnp.borders.eventHandler")
registerAnonymousEventHandler("sysWindowResizeEvent", "dslpnp.borders.eventHandler")
