-- Extensions Script
-- 4/26/2014
-- v4.01a
--
-- Extends Table, String, and Math libraries.
-- Overwrites faulty Mudlet functions.

-- Extensions List:
--
-- table.copy
-- table.update
-- table.keyFind
-- table.push
-- table.pop
--
-- string.titleAll
-- string.replace
--
-- math.round
-- math.stdev

-- Overwritten functions:
-- Geyser.MiniConsole:setFontSize
-- gmod.reenableModules
-- permGroup

-- Creates a duplicate of the given table
function table.copy(tbl)
	local new = {}
	for k,v in pairs(tbl) do
		if type(v) == "table" then
			new[k] = table.copy(v)
		else
			new[k] = v
		end
	end
	return new
end

-- Updates the first table with values from the second table
function table.update(t1, t2)
	local tbl = table.copy(t1)
	for k,v in pairs(t2) do
		if type(v) == "table" then
			tbl[k] = table.update(tbl[k] or {}, v)
		else
			tbl[k] = v
		end
	end
	return tbl
end

-- Iterates through a table, looking for specified key
function table.keyFind(tbl, what)
   assert(type(tbl) == "table")

   for k,v in pairs(tbl) do
       if k == what then
         return true
       end
   end
   return false
end

-- Push functionality for an indexed table. Can push onto either end.
function table.push(tbl, value, from_end)
	if from_end == nil then from_end = true end
	if from_end then
		table.insert(tbl, value)
		return true
	elseif not from_end then
		table.insert(tbl, 1, value)
		return true
	else
		return nil
	end
end

-- Pop functionality for an indexed table. Can pop from either end.
function table.pop(tbl, from_end)
	if from_end == nil then from_end = true end
	if from_end then
		return table.remove(tbl)
	elseif not from_end then
		return table.remove(tbl, 1)
	else
		return nil
	end
end

-- Capitalizes the first letter of all words in a string.
function string.titleAll(s)
	return string.gsub(s,"([a-zA-Z%']+)",string.title)
end

-- Like gsub function, but allows for special characters to be ignored.
function string.replace(s, pattern, repl, init, plain)
	local a,b
	init = tonumber(init) or 1
	repeat
		a, b = string.find(s, pattern, init, plain)
		if a then
			s = string.sub(s,1,a-1) .. repl .. string.sub(s,b+1)
			init = b+1
		end
	until not a
	return s
end

-- Rounds number at given decimal place
function math.round(num, idp)
	if idp then
		assert(idp > 0 and idp == math.floor(idp), "Invalid decimal place!")
		local mult = 10^idp
		return math.floor(num * mult + 0.5) / mult
	else
		return math.floor(num + 0.5)
	end
end

-- Calculates the standard deviation of an indexed array of numbers
function math.stdev(numArray)
	assert(type(numArray) == "table" and table.size(numArray) == table.maxn(numArray), "Invalid number array!")
	local numArrayStDev = 0
	local numMean = 0
	for k, v in pairs(numArray) do numMean = numMean + v 	end
	numMean = numMean / #numArray
	for k, v in pairs(numArray) do numArrayStDev = numArrayStDev + (v - numMean)^2 end
	numArrayStDev = (numArrayStDev/#numArray)^.5
	return numArrayStDev
end

-- Overwrites Geyser.MiniConsole:setFontSize function so it works properly
function Geyser.MiniConsole:setFontSize(size)
   self.parent.setFontSize(self, size)
   setMiniConsoleFontSize(self.name, size)
end

-- Overwrites GMCP function that sends GMCP data on connect
function gmod.reenableModules()
    if not next(gmcp) then return end

    local list = {}
    for module, users in pairs(registeredModules) do
        list[#list+1] = module.." 1"
    end
    if list[1] then sendGMCP("Core.Supports.Set "..yajl.to_string(list)) end
end

--Overwriting the existing permGroup function so that it supports
--nesting groups. Even though the function technically does not
--create "groups".
function permGroup(name, itemtype, ...)
  assert(type(name) == "string", "permGroup: need a name for the new thing")
  local parent
  if #arg > 1 then
    return false
  elseif #arg == 1 then
    parent = arg[1]
  else
    parent = ""
  end
  local t = {
    timer = function(name)
        return (permTimer(name, parent, 0, "") == -1) and false or true
       end,
    trigger = function(name)
        return (permSubstringTrigger(name, parent, {""}, "") == -1) and false or true
      end,
    alias = function(name)
        return (permAlias(name, parent, "", "") == -1) and false or true
      end
 	}
 end
