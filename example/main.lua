local FakeRpc = require("example.fakerpc")
local FakeTimer = require("example.faketimer")
local Await = require("await")


GFrameNo = 0

local CLI_RPC_ID = 1
local SVR_RPC_ID = 2

local function gprintf(fmt, ...)
	local body = string.format(fmt, ...)
	print("GFrameNo: [" .. GFrameNo .. "] " .. body)
end

local client = FakeRpc.New(CLI_RPC_ID)

local function cliRpcCall(cb, func_name, ...)
	client:AsyncCall(cb, SVR_RPC_ID, func_name, ...)
end

local svr_methods = {}

function svr_methods.on_recv_call1(a, b)
	gprintf("Server: on_recv_call1: %s, %s", a, b)
	return "aaa", true
end

function svr_methods.on_recv_call2(a, b)
	gprintf("Server: on_recv_call2: %s, %s", a, b)
	return "bbb", false
end

local server = FakeRpc.New(SVR_RPC_ID)
server:RegHandlers(svr_methods)

local SLEEP_TOKEN = "qwerty"
local IS_RUNNING = true
local function test()
	gprintf("Client: sleep 3 frame begin")
	Await.Sleep(FakeTimer.AddTimer, 3)
	gprintf("Client: sleep 3 frame end")
	gprintf("Client: rpc call begin")
	local ret11, ret12 = Await.Call(cliRpcCall, "on_recv_call1", 123, "hello")
	assert(ret11 == "aaa" and ret12 == true)
	gprintf("Client: rpc call end")
	gprintf("Client: fork rpc call func")
	Await.Fork(function()
		gprintf("Client: fork rpc call begin")
		local ret21, ret22 = Await.Call(cliRpcCall, "on_recv_call2", 456, "world")
		assert(ret21 == "bbb" and ret22 == false)
		gprintf("Client: fork rpc call end")
	end)
	gprintf("Client: sleep 5 frame begin")
	Await.Sleep(FakeTimer.AddTimer, 5)
	gprintf("Client: sleep 5 frame end")

	gprintf("Client: fork wakeup func")
	Await.Fork(function()
		gprintf("Client: wakeup begin, will sleep 2 frame")
		Await.Sleep(FakeTimer.AddTimer, 2)
		gprintf("Client: wakeup end")
		Await.Wakeup(SLEEP_TOKEN)
	end)

	gprintf("Client: wait begin")
	Await.Wait(SLEEP_TOKEN)
	gprintf("Client: wait end")

	IS_RUNNING = false
end

local function exception_test()
	for i = 1, 3 do
		Await.Fork(function()
			local x = 10 * i
			local y = {}
			local z = x + y
			gprintf("%s calc z is: %s", i, z)
		end)
	end

	gprintf("invalid use raw coroutine.yield")
	coroutine.yield()
end

gprintf("----test begin----")
Await.Run(test)
while IS_RUNNING do
	GFrameNo = GFrameNo + 1
	if GFrameNo % 2 == 0 then
		client:DispatchMsg()
	else
		server:DispatchMsg()
	end
	FakeTimer.Update()
end
gprintf("----exception test begin----")
local ok, errmsg = pcall(Await.Run, exception_test)
assert(not ok)
gprintf(errmsg)
gprintf("----test done----")