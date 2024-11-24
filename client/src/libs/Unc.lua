local Module = {}

-- Console
function Module.rconsoleprint(text)
	return rconsoleprint(text)
end

function Module.rconsoleinfo(text)
	return rconsoleinfo(text)
end

function Module.rconsoleerr(text)
	return rconsoleerr(text)
end

function Module.rconsoleclear()
	return rconsoleclear()
end

function Module.rconsolename(title)
	return rconsolename(title)
end

function Module.rconsoleinput()
	return rconsoleinput()
end

function Module.rconsoleclose()
	return rconsoleclose()
end

function Module.printconsole(message, red, green, blue)
	return printconsole(message, red, green, blue)
end

-- Environment
function Module.getgenv()
	return getgenv()
end

function Module.getrenv()
	return getrenv()
end

function Module.getreg()
	return getreg()
end

function Module.getgc(include_tables)
	return getgc(include_tables)
end

function Module.getinstances()
	return getinstances()
end

function Module.getnilinstances()
	return getnilinstances()
end

function Module.getloadedmodules()
	return getloadedmodules()
end

function Module.getconnections(signal)
	return getconnections(signal)
end

function Module.firesignal(signal, ...)
	return firesignal(signal, ...)
end

function Module.fireclickdetector(detector, distance, event)
	return fireclickdetector(detector, distance, event)
end

function Module.fireproximityprompt(prompt)
	return fireproximityprompt(prompt)
end

function Module.firetouchinterest(totouch, part, toggle)
	return firetouchinterest(totouch, part, toggle)
end

function Module.setscriptable(object, toggle)
	return setscriptable(object, toggle)
end

function Module.gethiddenproperty(object, property)
	return gethiddenproperty(object, property)
end

function Module.sethiddenproperty(object, property, value)
	return sethiddenproperty(object, property, value)
end

function Module.setsimulationradius(radius)
	return setsimulationradius(radius)
end

-- File System
function Module.readfile(path)
	return readfile(path)
end

function Module.writefile(path, content)
	return writefile(path, content)
end

function Module.appendfile(path, content)
	return appendfile(path, content)
end

function Module.loadfile(path)
	return loadfile(path)
end

function Module.listfiles(folder)
	return listfiles(folder)
end

function Module.isfile(path)
	return isfile(path)
end

function Module.isfolder(path)
	return isfolder(path)
end

function Module.makefolder(path)
	return makefolder(path)
end

function Module.delfolder(path)
	return delfolder(path)
end

function Module.delfile(path)
	return delfile(path)
end

-- Hooking
function Module.hookfunction(old, newfunc)
	return hookfunction(old, newfunc)
end

function Module.hookmetamethod(object, metamethod, a1)
	return hookmetamethod(object, metamethod, a1)
end

function Module.newcclosure(a1)
	return newcclosure(a1)
end

-- Input
function Module.keypress(keycode)
	return keypress(keycode)
end

function Module.keyrelease(keycode)
	return keyrelease(keycode)
end

function Module.mouse1click()
	return mouse1click()
end

function Module.mouse1press()
	return mouse1press()
end

function Module.mouse1release()
	return mouse1release()
end

function Module.mouse2click()
	return mouse2click()
end

function Module.mouse2press()
	return mouse2press()
end

function Module.mouse2release()
	return mouse2release()
end

function Module.mousescroll(number)
	return mousescroll(number)
end

function Module.mousemoverel(a1, a2)
	return mousemoverel(a1, a2)
end

function Module.mousemoveabs(a1, a2)
	return mousemoveabs(a1, a2)
end

-- Miscellaneous
function Module.setclipboard(content)
	return setclipboard(content)
end

function Module.setfflag(flag, value)
	return setfflag(flag, value)
end

function Module.getnamecallmethod()
	return getnamecallmethod()
end

function Module.setnamecallmethod(method)
	return setnamecallmethod(method)
end

function Module.indentifyexecutor()
	return indentifyexecutor()
end

function Module.setfpscap(cap)
	return setfpscap(cap)
end

function Module.saveinstance(object, file_path, options)
	return saveinstance(object, file_path, options)
end

function Module.decompile(script)
	return decompile(script)
end

function Module.messagebox(text, title, flag)
	return messagebox(text, title, flag)
end

-- Reflection
function Module.loadstring(chunk, chunk_name)
	return loadstring(chunk, chunk_name)
end

function Module.checkcaller()
	return checkcaller()
end

function Module.islclosure(a1)
	return islclosure(a1)
end

-- Script
function Module.getsenv(script)
	return getsenv(script)
end

function Module.getcallingscript()
	return getcallingscript()
end

function Module.getscriptclosure(script)
	return getscriptclosure(script)
end

function Module.getscripthash(script)
	return getscripthash(script)
end

function Module.getscriptbytecode(script)
	return getscriptbytecode(script)
end

-- Table
function Module.getrawmetatable(a1)
	return getrawmetatable(a1)
end

function Module.setrawmetatable(a1, a2)
	return setrawmetatable(a1, a2)
end

function Module.setreadonly(a1, a2)
	return setreadonly(a1, a2)
end

function Module.isreadonly(a1)
	return isreadonly(a1)
end

function Module.queue_on_teleport(a1)
	queue_on_teleport(a1)
end

-- Cache library
Module.cache = {
	replace = function(x, y)
		return cache.replace(x, y)
	end,

	invalidate = function(x)
		return cache.invalidate(x)
	end,

	iscached = function(x)
		return cache.iscached(x)
	end,

	cloneref = function(x)
		return cache.cloneref(x)
	end,

	compareinstances = function(x, y)
		return cache.compareinstances(x, y)
	end,
}

-- Crypt library
Module.crypt = {
	encrypt = function(data, key)
		return crypt.encrypt(data, key)
	end,

	decrypt = function(data, key)
		return crypt.decrypt(data, key)
	end,

	base64 = {
		encode = function(data)
			return crypt.base64.encode(data)
		end,

		decode = function(data)
			return crypt.base64.decode(data)
		end,
	},

	hash = function(data)
		return crypt.hash(data)
	end,

	derive = function(value, length)
		return crypt.derive(value, length)
	end,

	random = function(size)
		return crypt.random(size)
	end,
}

-- Debug library
Module.debug = {
	getconstants = function(f)
		return debug.getconstants(f)
	end,

	getconstant = function(f, index)
		return debug.getconstant(f, index)
	end,

	setconstant = function(f, index, value)
		return debug.setconstant(f, index, value)
	end,

	getupvalues = function(f)
		return debug.getupvalues(f)
	end,

	getupvalue = function(f, index)
		return debug.getupvalue(f, index)
	end,

	setupvalue = function(f, index, value)
		return debug.setupvalue(f, index, value)
	end,

	getproto = function(f, index, activated)
		return debug.getproto(f, index, activated)
	end,

	setproto = function(f, index, replacement)
		return debug.setproto(f, index, replacement)
	end,

	getstack = function(f, index, value)
		return debug.getstack(f, index, value)
	end,

	setmetatable = function(o, mt)
		return debug.setmetatable(o, mt)
	end,

	getregistry = function()
		return debug.getregistry()
	end,

	getinfo = function(f)
		return debug.getinfo(f)
	end,
}

-- Drawing library
Module.Drawing = {
	new = function(type)
		return Drawing.new(type)
	end,

	cleardrawcache = function()
		return Drawing.cleardrawcache()
	end,

	getrenderproperty = function(obj)
		return Drawing.getrenderproperty(obj)
	end,

	isrenderobj = function(obj)
		return Drawing.isrenderobj(obj)
	end,

	setrenderobj = function(drawing, property, value)
		return Drawing.setrenderobj(drawing, property, value)
	end,

	Fonts = {
		UI = 0,
		System = 1,
		Plex = 2,
		Monospace = 3,
	},
}

-- WebSocket library
Module.websocket = {
	connect = function(url)
		local socket = websocket.connect(url)
		return {
			Send = function(message)
				return socket:Send(message)
			end,

			Close = function()
				return socket:Close()
			end,

			OnMessage = socket.OnMessage,
			OnClose = socket.OnClose,
		}
	end,
}

-- Actors library
Module.actors = {
	getactors = function()
		return getactors()
	end,

	run_on_actor = function(actor, script)
		return run_on_actor(actor, script)
	end,

	is_parallel = function()
		return is_parallel()
	end,
}

-- Runs the passed in functions and returns true if the functions were successful and false if not
function Module.ensure_executor_functions_access(...)
	local funcs = { ... }
    for i = 1, #funcs do
        if not funcs[i] then
            return false
        end
    end
	return true
end

return Module
