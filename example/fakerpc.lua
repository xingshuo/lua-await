local Await = require("await")

local RPC_MSG_TYPE = {
	Request = 1,
	Response = 2,
}

local rpc_session = 0

local rpc_objs_tbl = {}

local rpc_meta = {}
rpc_meta.__index = rpc_meta

function rpc_meta.New(uid)
	assert(rpc_objs_tbl[uid] == nil, uid)
	local o = {
		id = uid,
		msg_queue = {},
		callbacks = {},
		handlers = {},
		async_handler_names = {},
	}
	setmetatable(o, rpc_meta)
	rpc_objs_tbl[uid] = o
	return o
end

function rpc_meta:RegHandlers(handlers, async)
	assert(type(handlers) == "table")
	for name, func in pairs(handlers) do
		self.handlers[name] = func
	end
	if async then
		for name in pairs(handlers) do
			self.async_handler_names[name] = true
		end
	end
end

function rpc_meta:Send(dest_id, func_name, ...)
	local dest_obj = assert(rpc_objs_tbl[dest_id], dest_id)
	local msg = {
		source = self.id,
		type = RPC_MSG_TYPE.Request, 
		func_name = func_name,
		args = {...},
	}
	dest_obj:_pushMsg(msg)
end

function rpc_meta:AsyncCall(cb, dest_id, func_name, ...)
	assert(type(cb) == "function")
	local dest_obj = assert(rpc_objs_tbl[dest_id], dest_id)
	rpc_session = rpc_session + 1
	self.callbacks[rpc_session] = cb

	local msg = {
		source = self.id,
		session = rpc_session,
		type = RPC_MSG_TYPE.Request,
		func_name = func_name, 
		args = {...},
	}
	dest_obj:_pushMsg(msg)
end

function rpc_meta:_pushMsg(msg)
	table.insert(self.msg_queue, msg)
end

local function _handleRequest(self, msg, handler)
	local rets = {handler(table.unpack(msg.args))}
	local dest_obj = assert(rpc_objs_tbl[msg.source], msg.source)
	local rsp = {
		source = self.id,
		session = msg.session,
		type = RPC_MSG_TYPE.Response,
		reply = rets,
	}
	dest_obj:_pushMsg(rsp)
end

function rpc_meta:DispatchMsg()
	local n = 0
	while true do
		local msg = table.remove(self.msg_queue, 1)
		if not msg then
			break
		end
		n = n + 1
		if msg.type == RPC_MSG_TYPE.Request then
			local handler = assert(self.handlers[msg.func_name], msg.func_name)
			if msg.session then -- AsyncCall
				if self.async_handler_names[msg.func_name] then
					Await.Run(_handleRequest, self, msg, handler)
				else
					_handleRequest(self, msg, handler)
				end

			else -- Send
				handler(table.unpack(msg.args))
			end
		elseif msg.type == RPC_MSG_TYPE.Response then
			local cb = assert(self.callbacks[msg.session])
			cb(table.unpack(msg.reply))
			self.callbacks[msg.session] = nil
		end
	end

	return n
end

return rpc_meta