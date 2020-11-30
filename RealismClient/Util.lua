------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CloneTrooper1019, 2020 
-- Util Module
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Util = {}
local RunService = game:GetService("RunService")

function Util:Round(number, factor)
	local mult = 10 ^ (factor or 0)
	return math.floor((number * mult) + 0.5) / mult
end

function Util:RoundNearestInterval(number, factor)
	return Util:Round(number / factor) * factor
end

function Util:StepTowards(value, goal, rate)
	if math.abs(value - goal) < rate then
		return goal
	elseif value > goal then
		return value - rate
	elseif value < goal then
		return value + rate
	end
end

function Util:PromiseChild(object, name, andThen, ...)
	local promise = coroutine.wrap(function (...)
		local child = object:WaitForChild(name, 10)
		
		if child then
			andThen(child, ...)
		end
	end)
	
	promise(...)
end

function Util:PromiseValue(object, prop, andThen, ...)
	local args = {...}
	
	local promise = coroutine.wrap(function (...)
		local timeOut = tick() + 10
		
		while not object[prop] do
			local now = tick()
			
			if (timeOut - now) < 0 then
				return
			end
			
			RunService.Heartbeat:Wait()
		end
		
		andThen(object[prop], ...)
	end)
	
	promise(...)
end

return Util

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------