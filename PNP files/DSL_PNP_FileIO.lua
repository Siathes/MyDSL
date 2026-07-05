-- File IO Script
-- 1/30/2013
--

dslpnp.fileIO = dslpnp.fileIO or {}
dslpnp.fileIO.__index = dslpnp.fileIO

function dslpnp.fileIO.fileDialog(title, target)
	if target == "folder" then target = false else target = true end
	local path = invokeFileDialog(target, title)
	return path
end

function dslpnp.fileIO.exists(filename)
	if type(filename) == "table" and filename.type == "fileIO_file" then filename = filename.name end
	local info = lfs.attributes(filename)
	if info.mode == "file" then
		return true
	else
		return false
	end
end

function dslpnp.fileIO.open(filename,mode)
	local errors
	mode = mode or "read"
	if not table.contains({"read","write","append","modify"},mode) then
		error("File IO Open: Invalid mode: must be 'read', 'write', 'append', or 'modify'.",2)
	end
	if mode ~= "write" then
		local info = lfs.attributes(filename)
		if not info then
			errors = "Invalid filename: no such file."
			return nil, errors
		end
		if info.mode ~= "file" then
			errors = "Invalid filename: path points to a directory."
			return nil, errors
		end
	end
	local file = {}
	file.name = filename
	file.mode = mode
	file.type = "fileIO_file"
	file.contents = {}
	if file.mode == "read" or file.mode == "modify" then
		local tmp = io.open(file.name,"r")
		local linenum = 1
		for line in tmp:lines() do
			file.contents[linenum] = line
			linenum = linenum + 1
		end
		tmp:close()
	end
	setmetatable(file,dslpnp.fileIO)
	return file, nil
end

function dslpnp.fileIO.read(file, line)
	if file.type ~= "fileIO_file" then
		error("File IO Read: Invalid file: must be file returned by fileIO.open.",2)
	end
	if line ~= "all" and not tonumber(line) then
		error("File IO Read: Invalid argument: must be 'all' or the line number to be read.",2)
	end
	local text = ""
	if line == "all" then
		for k, v in ipairs(file.contents) do
			text = text .. v .. "\n"
		end
	else
		text = file.contents[line]
	end
	return text
end

function dslpnp.fileIO.lines(file)
	if file.type ~= "fileIO_file" then
		error("File IO Lines: Invalid file: must be file returned by fileIO.open.",2)
	end
	local line = 0
	return function ()
		line = line + 1
		if file.contents[line] then
			return line, file.contents[line]
		else
			return nil
		end
	end
end

function dslpnp.fileIO.write(file, text, line)
	if file.type ~= "fileIO_file" then
		error("File IO Write: Invalid file: must be file returned by fileIO.open.",2)
	end
	if line ~= nil and not tonumber(line) then
		error("File IO Write: Invalid argument: must be the line number to write to or nil (to write at the end).",2)
	end
	text = tostring(text)
	if line then
		file.contents[line] = text
	else
		table.insert(file.contents,text)
	end
	return file
end

function dslpnp.fileIO.delete(file, line)
	if file.type ~= "fileIO_file" then
		error("File IO Delete: Invalid file: must be file returned by fileIO.open.",2)
	end
	if line ~= "all" and not tonumber(line) then
		error("File IO Delete: Invalid argument: must be 'all' or the line number to be deleted.",2)
	end
	if line == "all" then
		file.contents = {}
	else
		table.remove(file.contents,line)
	end
	return file
end

function dslpnp.fileIO.close(file)
	if file.type ~= "fileIO_file" then
		error("File IO Close: Invalid file: must be file returned by fileIO.open.",2)
	end
	local tmp
	if file.mode == "write" then
		tmp = io.open(file.name,"w")
	elseif file.mode == "append" then
		tmp = io.open(file.name,"a")
	elseif file.mode == "modify" then
		tmp = io.open(file.name,"w+")
	end
	if tmp then
		for k,v in ipairs(file.contents) do
			tmp:write(v .. "\n")
		end
		tmp:flush()
		tmp:close()
		tmp = nil
	end
	return true
end