local table = table
local coroutine = coroutine
local traceback = debug.traceback
local tostring = tostring
local coroutine_pool = setmetatable({}, { __mode = "kv" })

local sleep_coroutines = {}
local wakeup_queue = {}
local fork_queue = {}

local function create_co(f)
	local co = table.remove(coroutine_pool)
	if co == nil then
		co = coroutine.create(function(...)
			f(...)
			while true do
				f = nil
				coroutine_pool[#coroutine_pool+1] = co
				f = coroutine.yield("SUSPEND")
				f(coroutine.yield())
			end
		end)
	else
		coroutine.resume(co, f)
	end
	return co
end

local suspend

local function dispatch_wakeup()
	while true do
		local token = table.remove(wakeup_queue, 1)
		if not token then
			break
		end
		local co = sleep_coroutines[token]
		if co then
			return suspend(co, coroutine.resume(co))
		end
	end
end

function suspend(co, result, command)
	if not result then
		local tb = traceback(co, tostring(command))
		if coroutine.close then
			coroutine.close(co)
		end
		return tb
	end
	if command == "SUSPEND" then
		return dispatch_wakeup()
	else
		return "Unknown cmd: " .. tostring(command) .. "\n" .. traceback(co)
	end
end

local function dispatch_msg(co)
	local err = suspend(co, coroutine.resume(co))
	local errors = err and {err} or {}
	while true do
		local f = table.remove(fork_queue, 1)
		if not f then
			break
		end
		local fork_co = create_co(f)
		local fork_err = suspend(fork_co, coroutine.resume(fork_co))
		if fork_err then
			table.insert(errors, fork_err)
		end
	end
	assert(#errors == 0, table.concat(errors, "\n"))
end

local await = {}

--[[
	rpcInvoke: func (callback, ...)
]]
function await.Call(rpcInvoke, ...)
	local n, rets
	local co = coroutine.running()
	local callback = function (...)
		n = select("#", ...)
		if n > 0 then
			rets = {...}
		end
		await.Wakeup(co)
	end
	rpcInvoke(callback, ...)
	await.Wait(co)

	if n > 0 then
		return table.unpack(rets, 1, n)
	end
end

--[[
	timeoutInvoke: func (ti, callback)
]]
function await.Sleep(timeoutInvoke, ti)
	local co = coroutine.running()
	timeoutInvoke(ti, function ()
		await.Wakeup(co)
	end)
	await.Wait(co)
end

function await.Fork(f)
	table.insert(fork_queue, f)
end

function await.Wait(token)
	local co = coroutine.running()
	token = token or co
	assert(sleep_coroutines[token] == nil, token)
	sleep_coroutines[token] = co
	coroutine.yield("SUSPEND")
	sleep_coroutines[token] = nil
end

function await.Wakeup(token)
	local sleep_co = sleep_coroutines[token]
	if sleep_co then
		local _, is_main = coroutine.running()
		if is_main then
			dispatch_msg(sleep_co)
		else
			table.insert(wakeup_queue, token)
		end
		return true
	end
end

function await.Run(f)
	local _, is_main = coroutine.running()
	assert(is_main)
	local co = create_co(f)
	dispatch_msg(co)
end

return await