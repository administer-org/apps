local MessagingService = game:GetService("MessagingService")
local AnnouncementsTopic =  "Announcements_Administer"
local Debris = game:GetService("Debris")
local ChangeBlurRemote = script:WaitForChild("ChangeBlur") :: RemoteEvent
local Sound = script:WaitForChild("Sound") :: Sound


-- // DEBUG FUNCTIONS

local _DEBUG_ = {}

function _DEBUG_.WarnTable(Table)
	warn("⚠️>>DEBUG<<⚠️")
	for Index, value in pairs(Table) do
		warn("#"..tostring(Index).." "..tostring(value))
	end
	warn("-------------- DEBUG")
end

--

local function String2Data(String : string)
	local TotalDataList = String:split("!!")
	local DurationTime = TotalDataList[2]
	local Message = TotalDataList[3]
	local AnonMode = TotalDataList[4]
	local ImageID = TotalDataList[5]
	local GuiType = TotalDataList[6]
	local AdminUserId = TotalDataList[7] -- Final


	--// Data

	--DurationTime
	--Text
	--Anon
	--Decal
	--ID

	--


	local IDList = {}

	for Index = (8), (100), 1 do
		local TableString = TotalDataList[Index]
		if TableString then
			local MixedString = TableString:split("|")[2]
			if MixedString then
				local TableStringList = MixedString:split("/")
				local Kind = TableStringList[1]
				local Value = TableStringList[2]
				local NewTable = {
					Kind = Kind,
					Value = Value
				}
				table.insert(IDList,NewTable)
			end
		else
			break
		end
		task.wait()
	end

	local NewDataList = {
		["DurationTime"] = DurationTime,
		["Text"] = Message,
		["Anon"] = AnonMode,
		["Decal"] = ImageID,
		["ID"] = IDList,
		["GuiType"] = GuiType,
		["AdminUserId"] = AdminUserId
	}


	return NewDataList
end

local Player = script.Parent.Parent.Parent :: Player
local TweenService = game:GetService("TweenService")
local BaseGui = script.Parent
local Info = TweenInfo.new(
	0.3,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)
local Players = game:GetService("Players")
local GetLocalTimeFunction = script:WaitForChild("GetLocalTime") :: RemoteFunction

-- // Tweening

local TweenService = game:GetService("TweenService")
local GeneralTweenInfo = TweenInfo.new(
	0.66,
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out,
	0,
	false,
	0
)

--

local UserService = game:GetService("UserService")

local function ApproveWithIDList(IDTable) : boolean
	local Approved = true
	
	--_DEBUG_.WarnTable(IDTable)
	if (#IDTable) ~= 0 then
		Approved = false
		local MainPlayerUserId = Player.UserId
		local ServerID = game.JobId
		
		--// Data
		
		--	Kind. JobID, UserID
		--	Value. String, String
		
		--
		
		for Index, Value in pairs(IDTable) do
			if Value.Kind == "JobID" then
				if Value.Value == ServerID then
					Approved = true
					break
				end
			elseif Value.Kind == "UserID" then
				local UserID = tonumber(Value.Value)
				
				if UserID then
					if UserID == MainPlayerUserId then
						Approved = true
					end
				end
			end
		end
	else
		Approved = true
	end
	
	return Approved
end

MessagingService:SubscribeAsync(AnnouncementsTopic,function(MessageData)
	local StringData = MessageData.Data :: string
	local Data = String2Data(StringData)

	if Data and Data.Text and Data.DurationTime and Data.GuiType then
		local Type = Data.GuiType

		if BaseGui:FindFirstChild(Type) and ApproveWithIDList(Data.ID) then
			local TimeString = GetLocalTimeFunction:InvokeClient(Player)
			local AnonMode = Data.Anon == "true" and true or false
			local UserID = tonumber(Data.AdminUserId) :: number
			local UserInfoTable = UserService:GetUserInfosByUserIdsAsync({UserID})[1]
			local Username = AnonMode and "SYSTEM" or UserInfoTable.Username
			local DisplayName = AnonMode and "" or UserInfoTable.DisplayName
			local ProfileImage = AnonMode and "rbxassetid://15351501819" or Players:GetUserThumbnailAsync(UserID,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100)
			local Image = Data.Decal
			local DurationTime = tonumber(Data.DurationTime)
			warn("DURATION TIME: "..tostring(DurationTime))
			-- // Gui Labels / Buttons
			local ImageLabel
			local TextLabel
			local ProfileLabel
			local UserMeta
			local ExitButton
			--




			local NewlyCreatedGui = BaseGui:FindFirstChild(Type):Clone() :: CanvasGroup
			NewlyCreatedGui.Parent = BaseGui
			NewlyCreatedGui.Visible = true
			Sound:Play()

			for Index, Value in pairs(NewlyCreatedGui:GetDescendants()) do
				if Value and Value:IsA("ImageLabel") then
					if Value and Value.Name == "KeyImg" then
						ImageLabel = Value
					elseif Value and Value.Name == "Profile" then
						ProfileLabel = Value
					end
				elseif Value and Value:IsA("TextLabel") then
					if Value and Value.Name == "MainText" then
						TextLabel = Value
					elseif Value and Value.Name == "UserMeta" then
						UserMeta = Value
					end
				elseif Value and Value:IsA("TextButton") or Value and Value:IsA("ImageButton") then
					if Value and Value.Name == "Exit" then
						ExitButton = Value
					end
				end
			end
			
			local TimerText = NewlyCreatedGui:FindFirstChild("Timer")
			if TimerText and TimerText:IsA("Frame") then
				TimerText = TimerText:FindFirstChildOfClass("TextLabel")
			end
			
			

			if ImageLabel and Image then
				ImageLabel.Image = Image
			end

			if TextLabel then
				TextLabel.Text = Data.Text
			end

			if ProfileLabel then
				ProfileLabel.Image = ProfileImage
			end
			
			if UserMeta then
				UserMeta.Text = [[<b>]]..DisplayName..[[</b> (]]..(AnonMode and "#" or "@")..Username..[[) • Today at ]]..TimeString
			end

			local Goal = {
				Size = Type:find("FullBlock") and UDim2.new(1,0,1,0) or NewlyCreatedGui.Size,
				GroupTransparency = 0
			}

			local Tween = TweenService:Create(NewlyCreatedGui,Info,Goal)

			Tween:Play()
			
			if Type:find("FullBlock") then
				ChangeBlurRemote:FireClient(Player,1)
			end
			
			local CounterConnection = nil
			
			local Exitted = false
			local function Exit()
				if Exitted == false then
					Exitted = true
					if CounterConnection then
						CounterConnection:Disconnect()
						CounterConnection = nil
					end
					ChangeBlurRemote:FireClient(Player,0)
					
					local ExitGoal = {
						Size = UDim2.new(0,0,0,0),
						GroupTransparency = 1
					}
					
					local ExitTween = TweenService:Create(NewlyCreatedGui,Info,ExitGoal)
					ExitTween:Play()
					ExitTween.Completed:Once(function()
						task.wait()
						Debris:AddItem(NewlyCreatedGui,1)
					end)
				end
			end
			
			ExitButton.MouseButton1Down:Once(function()
				Exit()
			end)
			
			local TempValue = Instance.new("IntValue")
			TempValue.Parent = NewlyCreatedGui
			TempValue.Value = DurationTime
			
			local CounterGoal = {
				Value = 0
			}
			
			local CounterInfo = TweenInfo.new(
				DurationTime,
				Enum.EasingStyle.Linear,
				Enum.EasingDirection.InOut,
				0,
				false,
				0
			)
			
			local CounterTween = TweenService:Create(TempValue,CounterInfo,CounterGoal)
			CounterTween:Play()
			
			TimerText.Text = TempValue.Value
			CounterConnection = TempValue:GetPropertyChangedSignal("Value"):Connect(function()
				TimerText.Text = TempValue.Value
			end)
			
			if DurationTime and DurationTime ~= (1 / 0) and DurationTime < 99999 and DurationTime > 0 then
				task.wait(DurationTime)
				Exit()
			end
		end
	end
end)
