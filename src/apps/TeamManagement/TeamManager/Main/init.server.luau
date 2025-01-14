local Runner = require(game.ServerScriptService.Administer.AppAPI)
local HttpService = game:GetService("HttpService")
local presetTeams = {}
local groupService = game:GetService("GroupService")
for _, team in ipairs(game.Teams:GetChildren()) do
	table.insert(presetTeams, team.Name)
end
local TeamManager = require(script.teamManager)
local DataStoreService = game:GetService("DataStoreService")
local DataStore = DataStoreService:GetDataStore("Administer_TeamSaves")
local SecondaryDataStore = DataStoreService:GetDataStore("Administer_TeamSaves_2")

--[[
TeamSaveTable: {
	["teamInfo"] = {name, color, autoAssignable},
	["savedPlayers"] = {playerId},
	["savedGroups"] = {groupId}
}
]]

local function ProcessAction(action, data: { [string]: any })
	if action == "GetAllTeams" then
		return TeamManager.GetAllTeams()
	elseif action == "CreateTeam" then
		return TeamManager.CreateTeam(data.name, data.color, data.autoAssignable)
	elseif action == "GetPlayersInTeam" then
		return TeamManager.GetPlayersInTeam(data.team)
	elseif action == "IsPlayerInTeam" then
		return TeamManager.IsPlayerInTeam(data.player, data.team)
	elseif action == "AddPlayerToTeam" then
		return TeamManager.AddPlayerToTeam(data.player, data.team)
	elseif action == "RemovePlayerFromTeam" then
		return TeamManager.RemovePlayerFromTeam(data.player)
	elseif action == "EditTeam" then
		return TeamManager.EditTeam(data.team, data.name, data.color, data.autoAssignable)
	elseif action == "DeleteTeam" then
		return TeamManager.DeleteTeam(data.team)
	elseif action == "CheckSaved" then
		local teamInfo = DataStore:GetAsync(data.key) -- TeamSaveTable
		if teamInfo then
			return "Saved"
		elseif table.find(presetTeams, tostring(data.key)) then
			return "Preset"
		else
			return "Not saved"
		end
	elseif action == "IsPlayerInGroup" then
		return data.player:IsInGroup(data.groupId)
	elseif action == "Load" then
		local teamInfo = DataStore:GetAsync(data.key) -- TeamSaveTable
		if teamInfo then return HttpService:JSONDecode(teamInfo) end
	elseif action == "Save" then
		local encodedData = HttpService:JSONEncode(data.data)
		local success, err = pcall(function()
			DataStore:SetAsync(data.key, encodedData) -- TeamSaveTable
		end)
		if not success then
			warn("Failed to save team data: " .. err)
			return false
		end
		local currentSavedTeams
		local successSecondary, errSecondary = pcall(function()
			currentSavedTeams = SecondaryDataStore:GetAsync("SavedTeams")
		end)
		if not successSecondary then
			warn("Failed to retrieve saved teams: " .. errSecondary)
			return false
		end
		if not currentSavedTeams then
			currentSavedTeams = {}
		else
			currentSavedTeams = HttpService:JSONDecode(currentSavedTeams)
		end
		if not table.find(currentSavedTeams, data.key) then table.insert(currentSavedTeams, data.key) end
		local successSecondarySave, errSecondarySave = pcall(function()
			SecondaryDataStore:SetAsync("SavedTeams", HttpService:JSONEncode(currentSavedTeams))
		end)
		if not successSecondarySave then
			warn("Failed to update saved teams: " .. errSecondarySave)
			return false
		end
		return true
	elseif action == "GetSavedTeams" then
		local success, reponse = pcall(function()
			return HttpService:JSONDecode(SecondaryDataStore:GetAsync("SavedTeams"))
		end)
		return success and reponse or {}
	elseif action == "RemoveSavedTeam" then
		local currentSavedTeams: {} = HttpService:JSONDecode(SecondaryDataStore:GetAsync("SavedTeams"))
		local index = table.find(currentSavedTeams, data.key)
		if index then
			table.remove(currentSavedTeams, index)
			SecondaryDataStore:SetAsync("SavedTeams", HttpService:JSONEncode(currentSavedTeams))
			DataStore:RemoveAsync(data.key)
			return true
		else
			return false
		end
	elseif action == "GetGroupInfo" then
		local groupInfo = groupService:GetGroupInfoAsync(data.groupId)
		return { ["name"] = groupInfo.Name, ["imageId"] = groupInfo.EmblemUrl }
	else
		warn("Invalid Action: " .. tostring(action))
		return nil
	end
end

local function OnServerInvoke(player: Player, data: { ["action"]: string, ["data"]: any })
	local action = ProcessAction(data.action, data.data)
	local RemoteEvent = game.ReplicatedStorage:WaitForChild("AdministerApps")["Team Manager"].TeamRemote
	return action
end

local App = Runner.Build(function(Config, AppAPI)
	AppAPI.NewRemoteFunction("TeamRemote", OnServerInvoke)
end, {}, {
	Icon = "rbxassetid://9368579295",
	Name = "Team Manager",
	Frame = script.Parent.UI.TeamManagement,
	Tip = "Manage your game's teams.",
})
