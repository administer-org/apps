local GetLocalTimeFunction = script.Parent:WaitForChild("GetLocalTime") :: RemoteFunction

GetLocalTimeFunction.OnClientInvoke = function()
	local PlayerTime = os.date("*t", os.time())
	local Hours, Minutes = PlayerTime.hour, PlayerTime.min
	local AM = true

	if tonumber(Hours) > 12 then
		local Num = tonumber(Hours)

		Num -= 12
		Hours = Num
		AM = false
	end
	Minutes = tostring(Minutes)
	if Minutes:len() == 1 then Minutes = "0" .. Minutes end
	return Hours .. ":" .. Minutes .. " " .. (AM == true and "AM" or "PM")
end
