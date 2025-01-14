local GetData = script.Parent:WaitForChild("GetData")
local PrimaryTextBox = script.Parent.Parent:WaitForChild("Controls"):WaitForChild("AnnouncementText")
local TextLenLabel = PrimaryTextBox.Parent:WaitForChild("TextLen")
local FilteredMessageValue = script.Parent:WaitForChild("FilteredMessage")
local AccouncementsGui = script.Parent.Parent.Parent:WaitForChild("Announcements") :: Frame
local MainCanvasGroup = AccouncementsGui.Parent :: CanvasGroup
local MainTextbox = AccouncementsGui:WaitForChild("Controls"):WaitForChild("AnnouncementText") :: TextBox
local IDBox = script.Parent.Parent.Parent
	:WaitForChild("Announcements")
	:WaitForChild("Controls")
	:WaitForChild("IDSpecifier") :: TextBox
local Player = game:GetService("Players").LocalPlayer
local AddSelfButton = IDBox.Parent:WaitForChild("AddMe") :: TextButton
local AddButtonActive = true

local function GetId()
	local String = IDBox.Text
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

local function RemoveSpaces(Textbox: TextBox): string
	local Text = ""
	local Letters = Textbox.Text:split("")

	for Index, Letter: string in pairs(Letters) do
		if string.lower(Letter) ~= " " then Text = Text .. Letter end
	end

	return Text
end

local DefaultAddButtonText = AddSelfButton.Text
local InactiveAddButtonText = "Already Added"

IDBox:GetPropertyChangedSignal("Text"):Connect(function()
	local IDs = GetId()
	local FoundLocalPlayer = false
	IDBox.Text = RemoveSpaces(IDBox)

	for Index, Value in pairs(IDs) do
		if Value and Value.Kind == "UserID" then
			if Value.Value == tostring(Player.UserId) then FoundLocalPlayer = true end
		end
	end

	if FoundLocalPlayer then
		AddButtonActive = false
		AddSelfButton.TextColor3 = Color3.fromRGB(122, 122, 122)
		AddSelfButton.Text = InactiveAddButtonText
	else
		AddButtonActive = true
		AddSelfButton.TextColor3 = Color3.fromRGB(210, 210, 210)
		AddSelfButton.Text = DefaultAddButtonText
	end
end)

local function AddSelfClicked()
	if AddButtonActive == true then
		AddButtonActive = false
		AddSelfButton.TextColor3 = Color3.fromRGB(122, 122, 122)
		IDBox:ReleaseFocus()
		AddSelfButton.Text = InactiveAddButtonText
		local IDs = GetId()

		local AddComa = false
		if tostring(#IDs) ~= "0" then AddComa = true end

		IDBox.Text = IDBox.Text .. (AddComa and "." or "") .. tostring(Player.UserId)
	end
end

AddSelfButton.MouseButton1Down:Connect(function()
	warn("Clicked")
	AddSelfClicked()
end)

PrimaryTextBox:GetPropertyChangedSignal("Text"):Connect(function()
	TextLenLabel.Text = tostring((PrimaryTextBox.Text:len()))
end)
GetData.OnClientInvoke = function(TextBox: TextBox)
	if TextBox and TextBox:IsA("TextBox") then return TextBox.Text end
end

local DefaultColor = PrimaryTextBox.TextColor3
local RedColor = Color3.fromRGB(255, 0, 0)
local LastText = ""

MainTextbox:GetPropertyChangedSignal("Text"):Connect(function()
	if MainTextbox.Text == FilteredMessageValue.Value then
		MainTextbox.TextColor3 = RedColor
		MainTextbox.RichText = true
	else
		LastText = MainTextbox.Text
		MainTextbox.RichText = false
		MainTextbox.TextColor3 = DefaultColor
	end
end)
MainTextbox.Focused:Connect(function()
	--warn("FOCUSED")
	if MainTextbox.Text == FilteredMessageValue.Value and LastText ~= FilteredMessageValue.Value then
		MainTextbox.Text = LastText
	end
end)
