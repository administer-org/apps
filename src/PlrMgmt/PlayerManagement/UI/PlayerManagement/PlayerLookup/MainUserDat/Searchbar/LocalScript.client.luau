--// Administer

--// PyxFluff 2022-2024

local TB = script.Parent.Searchbar.TextBox
local EnterToForce = 0
local Remotes = game.ReplicatedStorage:WaitForChild("AdministerApps"):WaitForChild("Player Management") --// TODO im adding this so i dont forget
local Open = false

TB.MouseEnter:Connect(function()
	if Open then return end
	local Tween = game:GetService("TweenService"):Create(
		script.Parent.UIGridLayout,
		TweenInfo.new(0.15, Enum.EasingStyle.Quart),
		{ CellSize = UDim2.new(0.66, 0, 1, 0) }
	)

	Tween:Play()
end)

TB.MouseLeave:Connect(function()
	if Open then return end
	local Tween = game:GetService("TweenService"):Create(
		script.Parent.UIGridLayout,
		TweenInfo.new(0.15, Enum.EasingStyle.Quart),
		{ CellSize = UDim2.new(0.63, 0, 1, 0) }
	)

	Tween:Play()
end)

TB.Focused:Connect(function()
	local Tween = game:GetService("TweenService"):Create(
		script.Parent.UIGridLayout,
		TweenInfo.new(0.8, Enum.EasingStyle.Elastic),
		{ CellSize = UDim2.new(1, 0, 1, 0) }
	)

	Open = true
	Tween:Play()
end)

TB.FocusLost:Connect(function(EnterPressed)
	if EnterPressed then
		if EnterToForce ~= 0 then
			script.Parent.Parent.Parent:SetAttribute("ShouldDelay", true)

			Remotes.ServerComm:InvokeServer("PlayerLookup", { ["ID"] = EnterToForce, ["Force"] = true })

			script.Parent.Parent.Parent:SetAttribute("ShouldDelay", false)
		end
	end

	local Tween = game:GetService("TweenService"):Create(
		script.Parent.UIGridLayout,
		TweenInfo.new(0.8, Enum.EasingStyle.Elastic),
		{ CellSize = UDim2.new(0.63, 0, 1, 0) }
	)

	Open = false
	Tween:Play()
	task.delay(0.25, function()
		TB.Text = ""
		script.Parent.Searchbar.Label.Text = "Enter a UserID or name..."
	end)

	Tween = game:GetService("TweenService"):Create(
		script.Parent.Searchbar.Popup,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart),
		{ Size = UDim2.new(1, 0, 0.469, 0), Position = UDim2.new(0, 0, 0, 0) }
	)
	local Tween2 = game:GetService("TweenService"):Create(
		script.Parent.Searchbar.Popup.Label,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart),
		{ TextTransparency = 1 }
	)
	local Tween3 = game:GetService("TweenService"):Create(
		script.Parent.Searchbar.Popup.Icon,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart),
		{ ImageTransparency = 1 }
	)

	Tween:Play()
	Tween2:Play()
	Tween3:Play()
end)

TB:GetPropertyChangedSignal("Text"):Connect(function()
	if not Open then return end
	script.Parent.Searchbar.Label.Text = TB.Text
	EnterToForce = 0

	local Tween = game:GetService("TweenService"):Create(
		script.Parent.Searchbar.Popup,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart),
		{ Size = UDim2.new(1, 0, 1.224, 0), Position = UDim2.new(0, 0, -0.755, 0) }
	)
	local Tween2 = game:GetService("TweenService"):Create(
		script.Parent.Searchbar.Popup.Label,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart),
		{ TextTransparency = 0 }
	)
	local Tween3 = game:GetService("TweenService"):Create(
		script.Parent.Searchbar.Popup.Icon,
		TweenInfo.new(0.4, Enum.EasingStyle.Quart),
		{ ImageTransparency = 0 }
	)

	Tween:Play()
	Tween2:Play()
	Tween3:Play()

	local UserID
	if tonumber(TB.Text) == nil then
		xpcall(function()
			UserID = game.Players:GetUserIdFromNameAsync(TB.Text)
			script.Parent.Searchbar.Popup.Label.Text = "Press enter to go to this player's page."
		end, function()
			script.Parent.Searchbar.Popup.Label.Text = "This is not a valid player."
			return
		end)
	elseif tonumber(TB.Text) ~= nil then
		UserID = tonumber(TB.Text)
		script.Parent.Searchbar.Popup.Label.Text = "Press enter to go to this player's page."
	else
		script.Parent.Searchbar.Popup.Label.Text =
			"You shouldn't be seeing this but you are somehow, try something else."
	end

	local MainContent = game:GetService("UserService"):GetUserInfosByUserIdsAsync({ UserID })[1]
	local ServerData = Remotes.ServerComm:InvokeServer("PlayerLookup", { ["ID"] = UserID, ["Force"] = false })
	local MainFrame = script.Parent.Parent

	xpcall(function()
		MainContent["Photo"] =
			game.Players:GetUserThumbnailAsync(UserID, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		MainFrame.PlayerDN.Text = MainContent["DisplayName"]
		MainFrame.PlayerUN.Text = `@{MainContent["Username"]} · {UserID}`
		MainFrame.PlayerImage.Image = MainContent["Photo"]
	end, function()
		script.Parent.Searchbar.Popup.Label.Text =
			"Invalid player (appears to be banned or not exist); try something else"
		return
	end)

	if ServerData["Message"] then
		script.Parent.Searchbar.Popup.Label.Text = ServerData["Message"]
		EnterToForce = UserID
	end

	-- glow maybe? i dont wanna overload the proxy
end)
