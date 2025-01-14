local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local BaseAnnouncementsGui = script.Parent
local ControllsCanvas = BaseAnnouncementsGui:WaitForChild("Controls")
local BaseGui = BaseAnnouncementsGui.Parent :: CanvasGroup
local ClosedSize = UDim2.new(1.4, 0, 1.5, 0)
local UnsupportedText = BaseAnnouncementsGui:WaitForChild("Header"):WaitForChild("Disclaimer")
UnsupportedText.Visible = (game:GetService("RunService"):IsStudio())
local FilteredMessageValue = script:WaitForChild("FilteredMessage")
local SendCooldown = false
local BaseButtons = {
	BaseAnnouncementsGui:WaitForChild("BannerSend"),
	BaseAnnouncementsGui:WaitForChild("FullscreenSend"),
	BaseAnnouncementsGui:WaitForChild("SmallAlertSend"),
}
local TextBoxes = {
	["Duration"] = ControllsCanvas:WaitForChild("AnnouncementDuration") :: TextBox,
	["Text"] = ControllsCanvas:WaitForChild("AnnouncementText") :: TextBox,
	["AnonMode"] = ControllsCanvas:WaitForChild("AnonMode") :: TextButton,
	["Image"] = ControllsCanvas:WaitForChild("DecalID") :: TextBox,
	["IDBox"] = ControllsCanvas:WaitForChild("IDSpecifier") :: TextBox,
}
local GetDataFunction = script:WaitForChild("GetData")

local function GetTextBoxText(TextBox: TextBox)
	local Player = script.Parent.Parent.Parent.Parent.Parent :: Player
	if Player and Player:IsA("Player") then return GetDataFunction:InvokeClient(Player, TextBox) end
	return nil
end

local function BadInput(TextBox: TextBox, CustomText: any)
	TextBox.Text = ""
	TextBox.Text = not CustomText and "Bad input, try again!" or CustomText
end

local function FormatSeconds()
	local DurationBox = TextBoxes.Duration
	local TextBoxText = GetTextBoxText(DurationBox)

	local ValueTypes = {
		{
			Type = "second",
			Shorten = "s",
			Value = 1,
		},
		{
			Type = "minute",
			Shorten = "m",
			Value = 60,
		},
		{
			Type = "hour",
			Shorten = "h",
			Value = 60 * 60,
		},
		{
			Type = "day",
			Shorten = "d",
			Value = (60 * 60) * 24,
		},
		{
			Type = "week",
			Shorten = "w",
			Value = ((60 * 60) * 24) * 7,
		},
		{
			Type = "month",
			Shorten = "mo",
			Value = ((60 * 60) * 24 * 30),
		},
		{
			Type = "year",
			Shorten = "y",
			Value = (((60 * 60) * 24 * 30) * 12) + (((60 * 60) * 24) * 5),
		},
		{
			Type = "never",
			Shorten = "never",
			Value = (1 / 0),
		},
	}

	local function FilterNumbersFromString(String: string)
		local Numbers = ""
		local Default = ""
		local Characters = String:split("")

		for Index, Value: string in pairs(Characters) do
			if tonumber(Value) ~= nil then
				Numbers = Numbers .. Value
			else
				Default = Default .. Value
			end
		end

		return { Default, Numbers }
	end

	local function GetType(String: string)
		local Type = nil
		local FilteredText = FilterNumbersFromString(String)[1]
		local LoweredString = FilteredText:lower()

		for Index, Value in pairs(ValueTypes) do
			local First2Characters = Value.Type:split("")[1] .. Value.Type:split("")[2]
			local ShortenCharacters = Value.Shorten
			if LoweredString:find(First2Characters, 1, true) then
				Type = Value.Type
			elseif
				LoweredString:find(ShortenCharacters, 1, true)
				and #LoweredString:split("") < (#Value.Type:split("") + 1)
				and not Type
			then
				Type = Value.Type
			end
		end

		return Type
	end

	local Seconds = nil
	local TimeValue = tonumber(FilterNumbersFromString(TextBoxText)[2])
	local Type = GetType(TextBoxText)

	if Type == "never" then TimeValue = (1 / 0) end
	if TimeValue and Type then
		for Index, Value in pairs(ValueTypes) do
			if Value.Type == Type then
				Seconds = TimeValue * Value.Value
				break
			end
		end
	else
		BadInput(DurationBox)
		return nil
	end

	return Seconds
end

local function GetId()
	local String = GetTextBoxText(TextBoxes.IDBox) :: string
	local StringList = String:split(".")
	local TotalList = {}

	for Index, Value in pairs(StringList) do
		if Value and (Value:len()) > 3 then
			if Value:find("-", 1, true) then
				local NewTable = {
					Kind = "JobID",
					Value = Value,
				}
				table.insert(TotalList, NewTable)
			elseif Value and tonumber(Value) and tostring(tonumber(Value)) == Value then
				local NewTable = {
					Kind = "UserID",
					Value = Value,
				}
				table.insert(TotalList, NewTable)
			end
		end
	end
	return TotalList
end

local AnonModeEnabled = false
TextBoxes.AnonMode.Text = "No"
local LastUnfilteredMessage = nil
TextBoxes.AnonMode.MouseButton1Down:Connect(function()
	AnonModeEnabled = not AnonModeEnabled
	TextBoxes.AnonMode.Text = AnonModeEnabled and "Yes" or "No"
end)

local function GetDecal()
	local Text = GetTextBoxText(TextBoxes.Image) :: string
	local PossibleImage = tonumber(Text)
	if PossibleImage == nil then
		local Decal = ""
		local Letters = Text:split("")
		for Index, Value: string in pairs(Letters) do
			if Value and tostring(tonumber(Value)) == Value then Decal = Decal .. tostring(Value) end
		end
		local FinalPossibleNumber = tonumber(Decal)
		if FinalPossibleNumber then return "rbxassetid://" .. tostring(FinalPossibleNumber) end
	else
		return "rbxassetid://" .. tostring(PossibleImage)
	end
	return nil
end

local function GetAnnouncementBoxData()
	local Data = {
		["DurationTime"] = FormatSeconds(),
		["Text"] = tostring(GetTextBoxText(TextBoxes.Text)),
		["Anon"] = AnonModeEnabled,
		["Decal"] = GetDecal(),
		["ID"] = GetId(),
	}
	return Data
end

local MessageGui_Uncloned = script:WaitForChild("Message")

local function GetAnnnouncementType(Data, Button)
	local ImageBased = tostring(Data.Decal) ~= "nil" and true or false
	local SizeType = Button == BaseButtons[1] and "Banner"
		or (Button == BaseButtons[2] and "FullBlock" or (Button == BaseButtons[3] and "TinyAlert" or "Banner"))

	local ChosenGui = MessageGui_Uncloned:WaitForChild("Banner_Default")
	if not ImageBased and SizeType == "Banner" then
		ChosenGui = MessageGui_Uncloned:WaitForChild("Banner_Default")
	elseif ImageBased and SizeType == "Banner" then
		ChosenGui = MessageGui_Uncloned:WaitForChild("Banner_Image")
	elseif not ImageBased and SizeType == "FullBlock" then
		ChosenGui = MessageGui_Uncloned:WaitForChild("FullBlock_Default")
	elseif ImageBased and SizeType == "FullBlock" then
		ChosenGui = MessageGui_Uncloned:WaitForChild("FullBlock_Image")
	elseif SizeType == "TinyAlert" then
		ChosenGui = MessageGui_Uncloned:WaitForChild("Min_Default")
	end

	ChosenGui = ChosenGui.Name

	return ChosenGui
end

local function AproveData(Data): boolean
	local Aproved = false
	--// Data

	--DurationTime
	--Text
	--Anon
	--Decal
	--ID

	--
	if Data then
		if Data.DurationTime and Data.DurationTime > 0 and Data.Text ~= "" then Aproved = true end
	end
	local Player = script.Parent.Parent.Parent.Parent.Parent :: Player

	if Data then
		if Data.Text then
			if Data.Text == "" then
				BadInput(TextBoxes.Text)
				Aproved = false
			else
				local PcallReturn, ErrorMessage = pcall(function()
					local FilteredInstance = TextService:FilterStringAsync(
						Data.Text,
						Player.UserId,
						Enum.TextFilterContext.PublicChat
					) :: TextFilterResult
					local FilteredTextString = FilteredInstance:GetNonChatStringForBroadcastAsync()

					if FilteredTextString ~= Data.Text then
						LastUnfilteredMessage = GetTextBoxText(TextBoxes.Text)
						BadInput(TextBoxes.Text, FilteredMessageValue.Value)
						Aproved = false
					end
				end)
				if ErrorMessage then
					BadInput(TextBoxes.Text, "Filtering failed.")
					Aproved = false
				end
			end
		end
	end

	return Aproved
end

local function Data2String(TotalData, AdminUserId)
	local ConCurrentString = ""
	local MainData = TotalData.Data
	local Type = TotalData.Type :: string

	--// Data

	--DurationTime
	--Text
	--Anon
	--Decal
	--ID

	--

	local function AddString(String)
		ConCurrentString = ConCurrentString .. "!!" .. tostring(String)
	end

	AddString(MainData.DurationTime)
	AddString(MainData.Text)
	AddString(MainData.Anon)
	AddString(MainData.Decal)
	AddString(Type)
	AddString(AdminUserId)

	local StringID = "\\"

	--// ID DATA

	-- Kind -> UserID / JobID
	--Value

	--

	local IDList = MainData.ID

	for Index, Value in pairs(IDList) do
		local NewString = "|" .. Value.Kind .. "/" .. Value.Value .. "|"
		AddString(NewString)
	end

	return ConCurrentString
end

local Info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0)

local MessagingService = game:GetService("MessagingService")
local AnnouncementsTopic = "Announcements_Administer"

local FixBlurRemote = script:WaitForChild("FixBlur") :: RemoteEvent

local function SendAnnnouncement(Button)
	SendCooldown = true
	local Data = GetAnnouncementBoxData()
	local Type = GetAnnnouncementType(Data, Button)
	local Aproved = AproveData(Data)

	if Aproved then
		local TotalData = {
			["Data"] = Data,
			["Type"] = Type,
		}

		--// Close Gui

		--warn(BaseAnnouncementsGui.Parent)

		local Player = script.Parent.Parent.Parent.Parent.Parent :: Player

		task.wait(0.5)

		local DataString = Data2String(TotalData, Player.UserId)
		MessagingService:PublishAsync(AnnouncementsTopic, DataString)

		task.wait(1)
		SendCooldown = false
	end
end

for Index, Value: TextButton in pairs(BaseButtons) do
	if Value and Value:IsA("TextButton") then
		Value.MouseButton1Down:Connect(function()
			if SendCooldown == false then SendAnnnouncement(Value) end
		end)
	end
end
