local teamManager = game.ReplicatedStorage:WaitForChild("Administer").Apps:WaitForChild("TeamManager")
local Apps = require(script:FindFirstAncestor("AdministerMainPanel").Client.Modules.Apps)
local Utilities = require(script:FindFirstAncestor("AdministerMainPanel").Client.Modules.Utilities)

local RemoteFunction: RemoteFunction = teamManager:WaitForChild("TeamRemote")

local actions = {
	[1] = "GetAllTeams",
	[2] = "CreateTeam",
	[3] = "GetPlayersInTeam",
	[4] = "IsPlayerInTeam",
	[5] = "EditTeam",
	[6] = "DeleteTeam",
	[7] = "CheckSaved",
	[8] = "GetSavedTeams",
	[9] = "Save",
	[10] = "Load",
	[11] = "GetGroupInfo",
	[12] = "AddPlayerToTeam",
	[13] = "RemovePlayerFromTeam",
	[14] = "setAttribute",
	[15] = "IsPlayerInGroup",
	[16] = "RemoveSavedTeam",
	[17] = "Delete"
}

local options = script.Parent.Options
local editor = script.Parent.Edit
local mainFrame = script.Parent.Main
local optionsFrame = script.Parent.Options
local teamTemplate = mainFrame.Admins.Content.Template

local groupsTable = {}
local playersTable = {}

local teamInfo = "%s • %s Players • %s"

options.ColorInput.FocusLost:Connect(function()
	local text = options.ColorInput.Text

	options.Color.BackgroundColor3 = BrickColor.new(text).Color
end)

editor.ColorInput.FocusLost:Connect(function()
	local text = editor.ColorInput.Text

	editor.Color.BackgroundColor3 = BrickColor.new(text).Color
end)

local function getTeamFromGroups(specifiedTeam)
	local ids = {}
	for id, team in groupsTable do
		if team == specifiedTeam then
			table.insert(ids, id)
		end
	end
	return ids
end

local function getTeamFromPlayers(specifiedTeam)
	local ids = {}
	for id, team in playersTable do
		if team == specifiedTeam then
			table.insert(ids, id)
		end
	end
	return ids
end

local function AddUserFunction(Frame)
	local PlayerTemplate = Frame.Members.PlayerTemplate
	local ClonedPlayerTemplate = PlayerTemplate:Clone()
	ClonedPlayerTemplate.Visible = true
	ClonedPlayerTemplate.Parent = Frame.Members
	ClonedPlayerTemplate.TextInput.FocusLost:Connect(function()
		if ClonedPlayerTemplate.TextInput.Text then
			local userId = tonumber(ClonedPlayerTemplate.TextInput.Text)
			local userImage = tostring(game.Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180))
			ClonedPlayerTemplate.Image.Image = userImage
			ClonedPlayerTemplate._Name.Text = string.format("%s (@%s)", 
				game:GetService("UserService"):GetUserInfosByUserIdsAsync({userId})[1].DisplayName or nil, 
				game.Players:GetNameFromUserIdAsync(userId))
			ClonedPlayerTemplate.Name = "playerId__" .. userId
		end
	end)
	local function RemoveUserFunction()
		ClonedPlayerTemplate:Destroy()
	end
	ClonedPlayerTemplate.Delete.MouseButton1Click:Connect(RemoveUserFunction)
	ClonedPlayerTemplate.Delete.TouchTap:Connect(RemoveUserFunction)
end

local function AddGroupFunction(Frame)
	local GroupTemplate = Frame.Members.GroupTemplate
	local ClonedGroupTemplate = GroupTemplate:Clone()
	ClonedGroupTemplate.Visible = true
	ClonedGroupTemplate.Parent = Frame.Members
	ClonedGroupTemplate.TextInput.FocusLost:Connect(function()
		if ClonedGroupTemplate.TextInput.Text then
			local groupId = tonumber(ClonedGroupTemplate.TextInput.Text)
			local groupInfo = RemoteFunction:InvokeServer({["action"] = actions[11], ["data"] = {["groupId"] = groupId}})
			ClonedGroupTemplate.Image.Image = string.gsub(tostring(groupInfo.imageId), "http://www.roblox.com/asset/?id=", "rbxassetid://")
			ClonedGroupTemplate._Name.Text = groupInfo.name
			ClonedGroupTemplate.Name = "groupId__" .. groupId
		end
	end)
	local function RemoveGroupFunction()
		ClonedGroupTemplate:Destroy()
	end
	ClonedGroupTemplate.Delete.MouseButton1Click:Connect(RemoveGroupFunction)
	ClonedGroupTemplate.Delete.TouchTap:Connect(RemoveGroupFunction)
end

Apps.AddAppDrawerButton({
	AppName = "Team Manager",
	Description = "Manage your game's teams.",
	Icon = Utilities.Icon "flag-usa",
	ButtonID = "TeamManager",

	MainButtonClick = function() end,
	MainButtonFrame = script.Parent,

	SubIcons = {}
})


local currentTeam: Team
local isEditorOpen = false

local function openTeamEditor(teamFrame: Frame, team: Team)
	if isEditorOpen then return end
	isEditorOpen = true
	currentTeam = team

	editor.Header.HeaderLabel.Text = tostring(team)
	editor.Visible = true
	editor.TextInput.Text = team.Name
	editor.ColorInput.Text = team.TeamColor.Name
	editor.Color.BackgroundColor3 = team.TeamColor.Color

	for _, child in editor.InTeam:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "PlayerTemplate" then
			child:Destroy()
		end
	end

	for _, child in editor.NotInTeam:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "PlayerTemplate" then
			child:Destroy()
		end
	end

	for _, child in editor.Members:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "GroupTemplate" and child.Name ~= "PlayerTemplate" then
			child:Destroy()
		end
	end

	local playerTemplate = editor.NotInTeam.PlayerTemplate
	local playersInTeam = {}

	for _, player in game.Players:GetPlayers() do
		if player.Team == team then
			playersInTeam[player] = true
		else
			playersInTeam[player] = false
		end
	end

	for player, isInTeam in playersInTeam do
		local clonedPlayerTemplate = playerTemplate:Clone()
		clonedPlayerTemplate._Name.Text = string.format("%s (@%s)", 
			game:GetService("UserService"):GetUserInfosByUserIdsAsync({player.UserId})[1].DisplayName or nil, 
			game.Players:GetNameFromUserIdAsync(player.UserId))
		local userImage = tostring(game.Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180))
		clonedPlayerTemplate.Name = player.Name
		clonedPlayerTemplate.Image.Image = userImage
		clonedPlayerTemplate.Visible = true
		if isInTeam then
			clonedPlayerTemplate.Parent = editor.InTeam
		else
			clonedPlayerTemplate.Parent = editor.NotInTeam
		end

		clonedPlayerTemplate.TextButton.MouseButton1Click:Connect(function()
			local originalTeam = player.Team
			if clonedPlayerTemplate.Parent == editor.InTeam and originalTeam ~= team then
				clonedPlayerTemplate.Parent = editor.NotInTeam
				RemoteFunction:InvokeServer({["action"] = actions[12], ["data"] = {["player"] = player, ["team"] = originalTeam}})
			elseif player.Team == team then
				clonedPlayerTemplate.Parent = editor.NotInTeam
				RemoteFunction:InvokeServer({["action"] = actions[13], ["data"] = {["player"] = player}})
			else
				clonedPlayerTemplate.Parent = editor.InTeam
				RemoteFunction:InvokeServer({["action"] = actions[12], ["data"] = {["player"] = player, ["team"] = team}})
			end
		end)
	end

	local playerIds = getTeamFromPlayers(team.Name)
	local groupIds = getTeamFromGroups(team.Name)

	for playerId, teamName in playersTable do
		if tostring(teamName) == team.Name then
			playerId = tonumber(playerId)
			local ClonedPlayerTemplate = editor.Members.PlayerTemplate:Clone()
			ClonedPlayerTemplate.TextInput.Text = playerId
			ClonedPlayerTemplate.Visible = true
			ClonedPlayerTemplate.Parent = editor.Members
			local function focusLost()
				if ClonedPlayerTemplate.TextInput.Text then
					local userId = tonumber(ClonedPlayerTemplate.TextInput.Text)
					local userImage = tostring(game.Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180))
					ClonedPlayerTemplate.Image.Image = userImage
					ClonedPlayerTemplate._Name.Text = string.format("%s (@%s)", 
						game:GetService("UserService"):GetUserInfosByUserIdsAsync({userId})[1].DisplayName or nil, 
						game.Players:GetNameFromUserIdAsync(userId))
					ClonedPlayerTemplate.Name = "playerId__" .. userId
				end
			end
			ClonedPlayerTemplate.TextInput.FocusLost:Connect(focusLost)
			focusLost()
			local function RemoveUserFunction()
				ClonedPlayerTemplate:Destroy()
				playersTable[tostring(playerId)] = nil
			end
			ClonedPlayerTemplate.Delete.MouseButton1Click:Connect(RemoveUserFunction)
			ClonedPlayerTemplate.Delete.TouchTap:Connect(RemoveUserFunction)
		end
	end

	for groupId, teamName in groupsTable do
		if tostring(teamName) == team.Name then
			groupId = tonumber(groupId)
			local ClonedGroupTemplate = editor.Members.GroupTemplate:Clone()
			ClonedGroupTemplate.TextInput.Text = groupId
			ClonedGroupTemplate.Visible = true
			ClonedGroupTemplate.Parent = editor.Members
			local function focusLost()
				if ClonedGroupTemplate.TextInput.Text then
					local groupId = tonumber(ClonedGroupTemplate.TextInput.Text)
					local groupInfo = RemoteFunction:InvokeServer({["action"] = actions[11], ["data"] = {["groupId"] = groupId}})
					ClonedGroupTemplate.Image.Image = string.gsub(tostring(groupInfo.imageId), "http://www.roblox.com/asset/?id=", "rbxassetid://")
					ClonedGroupTemplate._Name.Text = groupInfo.name
					ClonedGroupTemplate.Name = "groupId__" .. groupId
				end
			end
			ClonedGroupTemplate.TextInput.FocusLost:Connect(focusLost)
			focusLost()
			local function RemoveGroupFunction()
				ClonedGroupTemplate:Destroy()
				groupsTable[tostring(groupId)] = nil
			end
			ClonedGroupTemplate.Delete.MouseButton1Click:Connect(RemoveGroupFunction)
			ClonedGroupTemplate.Delete.TouchTap:Connect(RemoveGroupFunction)
		end
	end
	wait(0.1)
	isEditorOpen = false
end


editor.AddPane.AddGroup.Click.MouseButton1Click:Connect(function()
	AddGroupFunction(editor)
end)
editor.AddPane.AddUser.Click.MouseButton1Click:Connect(function()
	AddUserFunction(editor)
end)
editor.Header.Exit.MouseButton1Click:Connect(function()
	editor.Visible = false
	for _, frame in editor.Members:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "GroupTemplate" and frame.Name ~= "PlayerTemplate" then
			frame:Destroy()
		end
	end

	for _, frame in editor.InTeam:GetChildren() do
		if frame:IsA("Frame") then
			frame:Destroy()
		end
	end

	for _, frame in editor.NotInTeam:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "PlayerTemplate" then
			frame:Destroy()
		end
	end
	return
end)
editor.ServerSave.MouseButton1Click:Connect(function()
	editor.Visible = false
	local playerIds = {}
	local groupIds = {}
	local allPlayerIds = getTeamFromPlayers(currentTeam)
	local allGroupIds = getTeamFromGroups(currentTeam)
	for i, Frame in editor.Members:GetChildren() do
		if Frame:IsA("Frame") and Frame.Name ~= "GroupTemplate" and Frame.Name ~= "PlayerTemplate" then
			if string.find(Frame.Name, "playerId__") then -- playerId
				local newString,number = string.gsub(Frame.Name, "playerId__", "")
				playersTable[newString] = currentTeam
				table.insert(playerIds, newString)
			elseif string.find(Frame.Name, "groupId__") then -- groupId
				local newString,number = string.gsub(Frame.Name, "groupId__", "")
				groupsTable[newString] = currentTeam
				table.insert(groupIds, newString)
			end
		end
	end

	for _, frame in editor.Members:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "GroupTemplate" and frame.Name ~= "PlayerTemplate" then
			frame:Destroy()
		end
	end

	for _, frame in editor.InTeam:GetChildren() do
		if frame:IsA("Frame") then
			frame:Destroy()
		end
	end

	for _, frame in editor.NotInTeam:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "PlayerTemplate" then
			frame:Destroy()
		end
	end

	for i,PlayerId in allPlayerIds do
		if not playerIds[PlayerId] then
			allPlayerIds[PlayerId] = nil
		end
	end

	for i,GroupId in allGroupIds do
		if not groupIds[GroupId] then
			allGroupIds[GroupId] = nil
		end
	end

	RemoteFunction:InvokeServer({["action"] = actions[5], ["data"] = {["team"] = currentTeam, ["name"] = editor.TextInput.Text, ["color"] = BrickColor.new(editor.ColorInput.Text), ["autoAssignable"] = false}})

	return
end)

editor.GameSave.MouseButton1Click:Connect(function()
	editor.Visible = false
	local playerIds = {}
	local groupIds = {}
	local allPlayerIds = getTeamFromPlayers(currentTeam)
	local allGroupIds = getTeamFromGroups(currentTeam)

	for i, Frame in editor.Members:GetChildren() do
		if Frame:IsA("Frame") and Frame.Name ~= "GroupTemplate" and Frame.Name ~= "PlayerTemplate" then
			if string.find(Frame.Name, "playerId__") then -- playerId
				local newString,number = string.gsub(Frame.Name, "playerId__", "")
				playersTable[newString] = currentTeam
				table.insert(playerIds, newString)
			elseif string.find(Frame.Name, "groupId__") then -- groupId
				local newString,number = string.gsub(Frame.Name, "groupId__", "")
				groupsTable[newString] = currentTeam
				table.insert(groupIds, newString)
			end
		end
	end

	for _, frame in editor.Members:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "GroupTemplate" and frame.Name ~= "PlayerTemplate" then
			frame:Destroy()
		end
	end

	for _, frame in editor.InTeam:GetChildren() do
		if frame:IsA("Frame") then
			frame:Destroy()
		end
	end

	for _, frame in editor.NotInTeam:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "PlayerTemplate" then
			frame:Destroy()
		end
	end

	for i,PlayerId in allPlayerIds do
		if not playerIds[PlayerId] then
			allPlayerIds[PlayerId] = nil
		end
	end

	for i,GroupId in allGroupIds do
		if not groupIds[GroupId] then
			allGroupIds[GroupId] = nil
		end
	end
	
	local removeFromDatastore = RemoteFunction:InvokeServer({["action"] = actions[16], ["data"] = {["key"] = currentTeam.Name}})

	RemoteFunction:InvokeServer({["action"] = actions[5], ["data"] = {["team"] = currentTeam, ["name"] = editor.TextInput.Text, ["color"] = BrickColor.new(editor.ColorInput.Text), ["autoAssignable"] = false}})

	local success = RemoteFunction:InvokeServer({
		["action"] = actions[9],
		["data"] = {
			["key"] = editor.TextInput.Text,
			["data"] = {
				["teamInfo"] = {editor.TextInput.Text, tostring(currentTeam.TeamColor), false},
				["savedPlayers"] = getTeamFromPlayers(currentTeam),
				["savedGroups"] = getTeamFromGroups(currentTeam)
			}
		}
	})

	return
end)
local function createNewTeam(team: Team, isSaved: any, frameNameToReplace: any)
	local clonedTeamTemplate
	if not mainFrame.Admins.Content:FindFirstChild((frameNameToReplace or team.Name)) then
		clonedTeamTemplate = teamTemplate:Clone()
	else
		clonedTeamTemplate = mainFrame.Admins.Content:FindFirstChild((frameNameToReplace or team.Name))
	end
	clonedTeamTemplate.Parent = mainFrame.Admins.Content
	clonedTeamTemplate.Name = team.Name
	clonedTeamTemplate.Visible = true
	clonedTeamTemplate.Gradient2.ImageLabel.ImageColor3 = team.TeamColor.Color
	local players = RemoteFunction:InvokeServer({["action"] = actions[3], ["data"] = {["team"] = team}})
	local members = clonedTeamTemplate.Members
	local saved =  isSaved and "" or RemoteFunction:InvokeServer({["action"] = actions[7], ["data"] = {["key"] = team.Name}})

	local function deleteTeam()
		local deleteTeam = RemoteFunction:InvokeServer({["action"] = actions[6], ["data"] = {["team"] = team}})
		if saved == "Saved" then
			local removeFromDatastore = RemoteFunction:InvokeServer({["action"] = actions[16], ["data"] = {["key"] = team.Name}})
		end
		clonedTeamTemplate:Remove()
		return
	end

	clonedTeamTemplate.Delete.MouseButton1Click:Connect(deleteTeam)
	clonedTeamTemplate.Delete.TouchTap:Connect(deleteTeam)

	clonedTeamTemplate.EditExisting.MouseButton1Click:Connect(function()
		openTeamEditor(clonedTeamTemplate, team)
	end)

	clonedTeamTemplate.Info.Text = string.format(tostring(teamInfo), tostring(team.TeamColor), tostring(#players), saved)
	clonedTeamTemplate.RankName.Text = tostring(team)
	for i,frame in members:GetChildren() do
		if frame:IsA("Frame") and frame.Name ~= "More" and frame.Name ~= "Template" then
			frame:Remove()
		end
	end
	local playerCount = #players
	for i, player in players do
		if i <= 6 then
			local clonedPlayerFrame = members.Template:Clone()
			clonedPlayerFrame.Visible = true
			clonedPlayerFrame.Name = player.Name
			clonedPlayerFrame.Player.Text = "@" .. player.Name
			clonedPlayerFrame.Parent = members
		end
	end
	if playerCount > 6 then
		members.More.Visible = true
		members.More.Player.Text = (playerCount - 6) .. " more..."
	else
		members.More.Visible = false
	end
end

options.AddPane.AddGroup.Click.MouseButton1Click:Connect(function()
	AddGroupFunction(options)
end)
options.AddPane.AddUser.Click.MouseButton1Click:Connect(function()
	AddUserFunction(options)
end)

-- saves everything serverside via tables
local function exitAndSaveToServer()
	local color = options.ColorInput
	local name = options.TextInput.Text
	local team = RemoteFunction:InvokeServer({["action"] = actions[2], ["data"] = {["name"] = name, ["color"] = BrickColor.new(color.Text), ["autoAssignable"] = false}})
	createNewTeam(team)
	for i, Frame in options.Members:GetChildren() do
		if Frame:IsA("Frame") and Frame.Name ~= "GroupTemplate" and Frame.Name ~= "PlayerTemplate" then
			if string.find(Frame.Name, "playerId__") then -- playerId
				local newString,number = string.gsub(Frame.Name, "playerId__", "")
				playersTable[newString] = team
			elseif string.find(Frame.Name, "groupId__") then -- groupId
				local newString,number = string.gsub(Frame.Name, "groupId__", "")
				groupsTable[newString] = team
			end
		end
	end
	options.Visible = false
end
-- saves everything globally via datastores
local function exitAndSaveToGame()
	local color = options.ColorInput
	local name = options.TextInput.Text
	local teamColor = BrickColor.new(color.Text)
	local team: Team = RemoteFunction:InvokeServer({
		["action"] = actions[2],
		["data"] = {["name"] = name, ["color"] = teamColor, ["autoAssignable"] = false}
	})
	if not team then
		warn("Failed to create the team.")
		return
	end

	createNewTeam(team, true)

	-- assign players and groups to the team
	for _, Frame in options.Members:GetChildren() do
		if Frame:IsA("Frame") and Frame.Name ~= "GroupTemplate" and Frame.Name ~= "PlayerTemplate" then
			if string.find(Frame.Name, "playerId__") then -- playerId
				local playerId = string.gsub(Frame.Name, "playerId__", "")
				playersTable[playerId] = team
			elseif string.find(Frame.Name, "groupId__") then -- groupId
				local groupId = string.gsub(Frame.Name, "groupId__", "")
				groupsTable[groupId] = team
			end
		end
	end

	options.Visible = false

	-- save the team
	local success = RemoteFunction:InvokeServer({
		["action"] = actions[9],
		["data"] = {
			["key"] = name,
			["data"] = {
				["teamInfo"] = {name, tostring(teamColor), false},
				["savedPlayers"] = getTeamFromPlayers(team),
				["savedGroups"] = getTeamFromGroups(team)
			}
		}
	})

	if not success then
		warn("Failed to save the team to the DataStore.")
	end
end

options.ServerSave.MouseButton1Click:Connect(exitAndSaveToServer)
options.ServerSave.TouchTap:Connect(exitAndSaveToServer)

options.GlobalSave.MouseButton1Click:Connect(exitAndSaveToGame)
options.GlobalSave.TouchTap:Connect(exitAndSaveToGame)
-- close the options tab
function optionsExit()
	options.Visible = false
end
options.Header.Exit.MouseButton1Click:Connect(optionsExit)
options.Header.Exit.TouchTap:Connect(optionsExit)
-- toggle the options tab
function newTeamClick()
	options.Visible = not options.Visible
end

mainFrame.Admins.BottomControls.NewTeam.MouseButton1Click:Connect(newTeamClick)
mainFrame.Admins.BottomControls.NewTeam.TouchTap:Connect(newTeamClick)

local currentTeams = RemoteFunction:InvokeServer({["action"] = actions[1]})
-- creates the initial teams
for i, team: Team in currentTeams do
	createNewTeam(team)
end
-- function to update the teams list
local function updateTeams(originalName: any, newName: any)
	if originalName then
		local team = game.Teams:FindFirstChild(tostring(newName))
		createNewTeam(team, false, originalName)
	else
		local currentTeams = RemoteFunction:InvokeServer({["action"] = actions[1]})
		for i, team: Team in currentTeams do
			if mainFrame.Admins.Content:FindFirstChild(team.Name) then
				createNewTeam(team)
			end
		end
	end
end
-- update teams list
for i, player in game.Players:GetPlayers() do
	player.Changed:Connect(function(property)
		if property == "Team" or property == "TeamColor" or property == "Neutral" then
			updateTeams()
		end
	end)
end
-- update teams list
game.Teams.DescendantAdded:Connect(function(team)
	if team:IsA("Team") then
		updateTeams()
		local oldName = team.Name
		team.Changed:Connect(function(property)
			if property == "Name" then
				updateTeams(oldName, team.Name)
				oldName = team.Name
			else
				updateTeams()
			end
		end)
	end
end)
-- update teams list
game.Teams.DescendantRemoving:Connect(function(team)
	if team:IsA("Team") then
		updateTeams()
	end
end)

for i, team in game.Teams:GetChildren() do
	local oldName = team.Name
	team.Changed:Connect(function(property)
		if property == "Name" then
			updateTeams(oldName, team.Name)
			oldName = team.Name
		else
			updateTeams()
		end
	end)
end
-- load all saved data
local data = RemoteFunction:InvokeServer({["action"] = actions[8]})
if data then
	for _, teamName in data do
		local teamData = RemoteFunction:InvokeServer({["action"] = actions[10], ["data"] = {["key"] = teamName}})
		if teamData then
			local teamInfo = teamData.teamInfo
			local savedPlayers = teamData.savedPlayers
			local savedGroups = teamData.savedGroups

			local teamColor = teamInfo[2]
			local newTeam = RemoteFunction:InvokeServer({
				["action"] = actions[2], 
				["data"] = {
					["name"] = teamName, 
					["color"] = BrickColor.new(teamColor), 
					["autoAssignable"] = false
				}
			})

			for _, player in savedPlayers do
				playersTable[player] = newTeam
			end

			for _, group in savedGroups do
				groupsTable[group] = newTeam
			end
			createNewTeam(newTeam)
		end
	end
end

-- load all player data
local teams = game.Teams:GetChildren()
if playersTable[tostring(game.Players.LocalPlayer.UserId)] then
	RemoteFunction:InvokeServer({["action"] = actions[12], ["data"] = {["player"] = game.Players.LocalPlayer, ["team"] = playersTable[tostring(game.Players.LocalPlayer.UserId)]}})
else
	for groupId, team in groupsTable do
		if game.Players.LocalPlayer:IsInGroup(tonumber(groupId)) then
			RemoteFunction:InvokeServer({["action"] = actions[12], ["data"] = {["player"] = game.Players.LocalPlayer, ["team"] = team}})
		end
	end
end
