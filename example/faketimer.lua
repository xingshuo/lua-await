
local handle = 0
local timers = {}

local T = {}

function T.AddTimer(ti, cb)
	handle = handle + 1
	timers[handle] = {GFrameNo + ti, cb}
	return handle
end

function T.DelTimer(hd)
	timers[hd] = nil
end

local timeouts = {}
function T.Update()
	local n = 0
	for hd, timer in pairs(timers) do
		local expired = timer[1]
		if expired <= GFrameNo then
			n = n + 1
			timeouts[n] = hd
		end
	end

	for i = 1, n do
		local hd = timeouts[i]
		local timer = timers[hd]
		if timer then
			timers[hd] = nil
			timer[2]()
		end
	end
end

return T