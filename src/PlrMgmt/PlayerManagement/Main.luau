--// pyxfluff 2024 - 2025

--// Modules
local ServerIndex = require(script.Parent.Modules.ServerIndex)

--// Services
local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local TextService      = game:GetService("TextService")

--// DataStores
local PlayerStore = DataStoreService:GetDataStore("AdministerPM_PlayerStore")

--// Variables
local RefreshDuration = 10 --// How often new data gets sent to the archive
local AllTimePlayers  = 0
local CurrentAdmins   = 0
local ChatMessages    = {}

local SLock        = 0 --// 0 = unlocked, 1 = admins, 2 = everyone
local SLockMessage = ""
local SLockActor   = ""

local DefaultData = {
	Joins = 0,
	PlayTime = 0,
	FirstSeen = 0,
	LastSeen = 0,
	IsActive = true,

	ModRecords = {
		_Warnings = 0,
		_Bans = 0,
		Actions = {

		}
	},

	AuditableActions = {

	}
}

local Players           = {}
local ServerBanned      = {}
local PlayerCache       = {}
local PrivateMessageIDs = {}

local Utils

local function RefreshTask()
	ServerIndex.UploadToIndex({
		["AP"] = AllTimePlayers
	})

	while task.wait(RefreshDuration) do
		xpcall(function()
			ServerIndex.UploadToIndex({
				["AP"] = AllTimePlayers,
				--["GameErrorCount"] = 0,
				--["GameWarningCount"] = 0
			})
		end, function(p)
			warn(`Failed to refresh our server for this frame: {p}`)
		end)
	end
end

local function CachePlayer(ID, Verbose, ReturnPlaceholderOnFail)
	local PlayerData = PlayerCache[ID]

	if not PlayerData then
		repeat
			local Suc, Content = pcall(function()
				return game:GetService("UserService"):GetUserInfosByUserIdsAsync({ID})[1]
			end)

			if not Suc then
				if Verbose then print("We appear to be ratelimited, trying again soon.") end
				if ReturnPlaceholderOnFail then
					return {
						Id = ID,
						DisplayName = "Loading failed",
						Username = `Ratelimit reached ({ID})`,
						HasVerifiedBadge = false,
						Photo = "rbxassetid://84027648824846"
					}
				end
				task.wait(2)
			else
				PlayerData = Content
				PlayerData["Photo"] = game.Players:GetUserThumbnailAsync(ID, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				PlayerCache[PlayerData["Id"]] = PlayerData

				if Verbose then print("Found from API!") end
			end
		until PlayerData ~= nil
	elseif PlayerData and Verbose then
		print("Found from CACHE!")
	end

	return PlayerData
end

local function Clone(Original)
	local copy = {}

	for key, value in Original do
		copy[key] = type(value) == "table" and Clone(value) or value
	end

	return copy
end

local function WebhookPost(Data)
	--// TODO
	--game:GetService("HttpService"):PostAsync(
	--	"https://",
	--	game:GetService("HttpService"):JSONEncode({
	--		["embeds"] = {{
	--			["color"] = tonumber(`0x{Data["Color"]}`, 16),
	--			["title"] = Data["Title"],
	--			["description"] = Data["Body"],
	--			["footer"] = {
	--				["text"] = `{Data["Footer"]} • Powered by Administer`
	--			}
	--		}}
	--	})
	--)
end

local function InitPlayer(Player: Player)
	repeat task.wait() until Player.UserId
	local PlayerInfo = PlayerStore:GetAsync(Player.UserId) or Clone(DefaultData) 

	if SLock == "2" then
		Player:Kick(`This server was locked by {SLockActor}. Try rejoining later.\n\n{SLockMessage}`)
	elseif SLock == "1" then
		if not Utils.IsAdmin(Player).Utils.IsAdmin then
			Player:Kick(`This server is locked to admins only by {SLockActor}. Try rejoining later.\n\n{SLockMessage}`)
		end
	end

	if PlayerInfo.FirstSeen == 0 then
		PlayerInfo["FirstSeen"] = os.time()
	end

	if PlayerInfo.Inactive then
		PlayerInfo.Inactive = nil --// this property should only be for new people
	end

	PlayerInfo.LastSeen = os.time()
	PlayerInfo.IsActive = true
	PlayerInfo.Joins += 1
	PlayerInfo.RegionSerialized = game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(Player)

	Players[Player.UserId] = {
		JoinTime = os.time(),
		Messages = {},
		DS = PlayerInfo,
		PlrInstance = Player
	}

	PlayerStore:SetAsync(Player.UserId, PlayerInfo, { Player.UserId })
	AllTimePlayers += 1

	if PlayerInfo.ModRecords.ActiveBan then
		task.delay(2, function()
			if Players[Player.UserId] ~= nil then
				PlayerInfo.ModRecords.ActiveBan = false

				PlayerStore:SetAsync(Player.UserId, PlayerInfo, {Player.UserId})

				print("Set ban record to false!")

			else
				print("Not found, assuming ban is active still")
			end
		end)
	end
end

local function ForceInitPlayerByID(UserID: number)
	local PlayerInfo = PlayerStore:GetAsync(UserID) or Clone(DefaultData)

	--// ik this is kinda dumb but one is "have they been seen" and the other is "are they i nthe game"
	PlayerInfo.Inactive = true
	PlayerInfo.IsActive = false

	print("init", PlayerInfo)

	PlayerStore:SetAsync(UserID, PlayerInfo, {UserID})

	return PlayerInfo
end

local function ConnectToSocket(M)
	local Data = M.Data

	print("Got event", Data)

	if Data["Action"] == "KickPlayer" then
		if not Players[Data.TargetID] then return end

		Players[Data.TargetID].PlrInstance:Kick(`Kicked by {Data["AdminName"]}:\n{Data["KickMessage"]}\n\nPowered by Administer`)
	elseif Data["Action"] == "PlayerNote" then
		if not Players[Data.TargetID] then return end

		local NewUI = script.Parent.UI.Message:Clone()
		local AdminDat = CachePlayer(Data["AdminID"], false, false)

		NewUI.Parent = Players[Data.TargetID].PlrInstance.PlayerGui
		NewUI.MainNote.MainNote.MainText.Text = `{Data["Message"]}`
		NewUI.MainNote.UserData.UserMeta.Text = `- <b>{AdminDat["DisplayName"]}</b> (@{AdminDat["Username"]})`
		NewUI.MainNote.UserData.Profile.Image = AdminDat.Photo

		if Data.RequestMessageBack then
			NewUI.MainNote.TextInputArea.Visible = true

			NewUI.MainNote.Exit.HeaderLabel.Text = "Send"
			NewUI.MainNote.Exit.CurrentApp.Image = Utils.Icon "send"
		else
			NewUI.MainNote.Exit.HeaderLabel.Text = "Close"
			NewUI.MainNote.Exit.CurrentApp.Image = Utils.Icon "x"
		end

		NewUI.MainNote.LocalScript.Enabled = true

		PrivateMessageIDs[Data.TargetID] = Data.MessageID

	elseif Data.Action == "ShutdownServer" then
		if Data.JobID ~= game.JobId then return end

		for _, Player: Player in game.Players:GetPlayers() do
			Player:Kick(`This server has been shutdown by {Data.AdminName}:\n{Data.PubReason}\n\nPowered by Administer`)
		end

	elseif Data.Action == "ChangeAccessLevel" then
		if Data.JobID ~= game.JobId then return end

		SLock = Data.Level
		SLockMessage = Data.PubReason
		SLockActor = Data.AdminName

	elseif Data.Action == "ReturnPMData" then
		local MessageID = Data.AdmMessageID

		for _, Player in game.Players:GetPlayers() do 
			if tostring(Player.UserId) == PrivateMessageIDs[MessageID] then
				Utils.NewNotification(
					Player,
					`{Data.Sender} says: {Data.Message}`,
					`New Response`,
					Utils.Icon "send",
					10,
					nil,
					{}
				)
			end
		end
	end
end

local function GlobalReplicate(Data)
	if game:GetService("RunService"):IsStudio() then
		ConnectToSocket({Data = Data})
	else
		MessagingService:PublishAsync("Administer-PlayerManagement", Data)
	end
end

return function(_, _, RuntimeAPI)
	local MainMessageSocket = MessagingService:SubscribeAsync("Administer-PlayerManagement", ConnectToSocket)
	
	local Utilities = RuntimeAPI.Modules.Utilities

	local function ClientMessagePort(Player, Message, Data)
		local ST = tick()
		local TargetDat
		local AdminDat = PlayerStore:GetAsync(Player.UserId)

		xpcall(
			function()
				if Data.TargetID then
					if Data.TargetID == Player.UserId then
						return {false, "You may not take action on yourself."}
					end

					TargetDat = Players[Data.TargetID]

					if not TargetDat then
						TargetDat = PlayerStore:GetAsync(Data.TargetID)
					else
						TargetDat = TargetDat.DS
					end
				end
			end,
			function()
				--// no TargetID pls stop erroring
			end
		)

		if Message == "RequestServers" then
			return ServerIndex.GetAllServers()

		elseif Message == "RequestPlayerJSON" then
			Data = tonumber(Data)

			local MainDat = PlayerStore:GetAsync(Data)
			local AdminInfo = Utils.IsAdmin({UserId = Data})

			if MainDat == nil then
				xpcall(function()
					MainDat = ForceInitPlayerByID(Data)
				end, function(dcvguihjdgfhjiu)
					warn(debug.traceback(dcvguihjdgfhjiu))
				end)
			end

			return {
				Main = MainDat, 
				Admin = AdminInfo
			}

		elseif Message == "BanPlayer" then
			return xpcall(
				function()
					TargetDat.ModRecords.Actions[`Ban-{math.random(1,50000)}`] = {
						DidClearWarnings = Data.ClearWarnings,
						Duration         = Data.BanDuration,
						Expires          = os.time() + Data.BanDuration,
						Moderator        = Player.UserId,
						PrivNote         = Data.PrivateNote,
						Reason           = Data.BanReason,
						Timestamp        = os.time(),
						_Type            = "BAN",
						Source           = `Administer AdministerPlayerManagement`
					}
					TargetDat.ModRecords._Bans += 1
					TargetDat.ModRecords.CurrentBanDuration = Data.BanDuration
					TargetDat.ModRecords.ActiveBan = true

					if Data.ClearWarnings then
						for k, Record in TargetDat.ModRecords.Actions do
							if Record._Type == "WARN" then
								TargetDat.DS.ModRecords.Actions[k] = nil
							end
						end

						TargetDat["ModRecords"]["_Warnings"] = 0

						table.insert(AdminDat["AuditableActions"], {
							["App"] = {
								["Name"] = "Player Management",
								["Icon"] = Utilities.Icon "users"
							},
							["Action"] = `Removed all of {Data.TargetID}'s warnings (as a part of a ban).`,
							["Icon"] = Utilities.Icon "trash",
							["Timestamp"] = os.time()
						})
					end

					table.insert(AdminDat["AuditableActions"], {
						["App"] = {
							["Name"] = "Player Management",
							["Icon"] = Utilities.Icon "users"
						},
						["Action"] = `Banned {Data.TargetID} for {Data["BanDurationString"]} ({Data["BanReason"]}).`,
						["Icon"] = Utilities.Icon "no-entry",
						["Timestamp"] = os.time()
					})

					PlayerStore:SetAsync(Data["TargetID"], TargetDat)
					PlayerStore:SetAsync(Player.UserId, AdminDat)

					game.Players:BanAsync({
						["UserIds"] = {tonumber(Data["TargetID"])},
						["ApplyToUniverse"] = true,
						["Duration"] = Data["BanDuration"],
						["DisplayReason"] = Data["BanReason"],
						["PrivateReason"] = `{Data["PrivateNote"]} (banned by {Player.Name} ({Player.UserId}) for {Data.BanDuration} seconds)`,
						["ExcludeAltAccounts"] = false
					})

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `{Player.Name} has banned {Data["TargetID"]}!`,
						["Body"] = `This ban lasts for {Data["BanDurationString"]}.\n\nReason: {Data["BanReason"]}\n\nModerator note: {Data["PrivateNote"]}.`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {true, "Success!", os.time() - ST}
				end,

				function(E)
					warn(`Failed to ban: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to ban {Data["TargetID"]}!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "KickPlayer" then
			return xpcall(
				function()
					TargetDat["ModRecords"]["Actions"][`Kick-{math.random(1,1500000)}`] = {
						["DidClearWarnings"] = Data["ClearWarnings"],
						["Moderator"] = Player.UserId,
						["PrivNote"] = Data["PrivateNote"],
						["Reason"] = Data["KickMsg"],
						["Timestamp"] = os.time(),
						["_Type"] = "KICK"
					}				

					table.insert(AdminDat["AuditableActions"], {
						["App"] = {
							["Name"] = "Player Management",
							["Icon"] = Utilities.Icon "users"
						},
						["Action"] = `Kicked {Data.TargetID} ({Data["BanReason"]}).`,
						["Icon"] = Utilities.Icon "user-exit",
						["Timestamp"] = os.time()
					})

					PlayerStore:SetAsync(Data["TargetID"], TargetDat)
					PlayerStore:SetAsync(Player.UserId, AdminDat)

					GlobalReplicate({
						["Action"] = "KickPlayer",
						["TargetID"] = Data["TargetID"],
						["AdminID"] = Player.UserId,
						["AdminName"] = Player.Name,
						["KickMessage"] = Data["KickMsg"]
					})

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `{Player.Name} kicked {Data["TargetID"]}!`,
						["Body"] = `{Data["KickMsg"]}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {true, "Success! Sent the message off, wait a few seconds and then check again.", os.time() - ST}
				end,

				function(E)
					warn(`Failed to kick: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to kick {Data["TargetID"]}!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "WarnPlayer" then
			return xpcall(
				function()
					TargetDat["ModRecords"]["Actions"][`Warning-{math.random(1,50000)}`] = {
						["Moderator"] = Player.UserId,
						["Warning"] = Data["Warning"],

						["Timestamp"] = os.time(),
						["_Type"] = "WARN",
					}

					table.insert(AdminDat["AuditableActions"], {
						["App"] = {
							["Name"] = "Player Management",
							["Icon"] = Utilities.Icon "users"
						},
						["Action"] = `Warned {Data.TargetID}: {Data["Warning"]}`,
						["Icon"] = Utilities.Icon "warning-filled",
						["Timestamp"] = os.time()
					})

					PlayerStore:SetAsync(Data["TargetID"], TargetDat)
					PlayerStore:SetAsync(Player.UserId, AdminDat)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `{Player.Name} warned {Data["TargetID"]}!`,
						["Body"] = Data["Warning"],
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {true, "Success!", os.time() - ST}
				end,

				function(E)
					warn(`Failed to warn: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to warn {Data["TargetID"]}!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "UnbanPlayer" then
			return xpcall(
				function()
					TargetDat["ModRecords"]["Actions"][`Unban-{math.random(1,50000)}`] = {
						["Moderator"] = Player.UserId,
						["PrivNote"] = Data["Note"],

						["Timestamp"] = os.time(),
						["_Type"] = "UNBAN",
						["Source"] = `Administer`
					}
					TargetDat["ModRecords"]["ActiveBan"] = false

					table.insert(AdminDat["AuditableActions"], {
						["App"] = {
							["Name"] = "Player Management",
							["Icon"] = Utilities.Icon "users"
						},
						["Action"] = `Unbanned {Data.TargetID} early.`,
						["Icon"] = Utilities.Icon "check-plain",
						["Timestamp"] = os.time()
					})

					PlayerStore:SetAsync(Data["TargetID"], TargetDat)
					PlayerStore:SetAsync(Player.UserId, AdminDat)

					game.Players:UnbanAsync({
						["UserIds"] = {tonumber(Data["TargetID"])},
						["ApplyToUniverse"] = true,
					})

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `{Player.Name} unbanned {Data["TargetID"]} early!`,
						["Body"] = ``,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {true, "Success!", os.time() - ST}
				end,

				function(E)
					warn(`Failed to unban: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to unban {Data["TargetID"]}!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "SendNote" then
			return xpcall(
				function()
					TargetDat.ModRecords.Actions[`Unban-{math.random(1,50000)}`] = {
						Moderator = Player.UserId,
						Message = Data.Message,

						Timestamp = os.time(),
						_Type = "NOTE"
					}

					table.insert(AdminDat["AuditableActions"], {
						App = {
							Name = "Player Management",
							Icon = ""
						},
						Action = `Sent a note to {Data.TargetID}: {Data.Message}`,
						Icon = "",
						Timestamp = os.time()
					})

					PlayerStore:SetAsync(Data["TargetID"], TargetDat)
					PlayerStore:SetAsync(Player.UserId, AdminDat)

					local MessageID = game:GetService("HttpService"):GenerateGUID(false)

					PrivateMessageIDs[MessageID] = tostring(Player.UserId)

					GlobalReplicate({
						Action = "PlayerNote",
						Message = Data.Message,
						RequestMessageBack = Data.UseInput,
						MessageID = MessageID,

						TargetID = Data.TargetID,
						AdminID = Player.UserId
					})

					WebhookPost({
						Color = "ff000",
						Title = `{Player.Name} sent a note to {Data["TargetID"]}!`,
						Body = `They said: {Data["Message"]}`,
						Footer = `Successfully Processed in {tick() - ST}s`
					})

					return {true, "Success!", os.time() - ST}
				end,

				function(E)
					warn(`Failed to execute: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to send note to {Data["TargetID"]}!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "LockServer" then
			return xpcall(
				function()
					table.insert(AdminDat.AuditableActions, {
						["App"] = {
							["Name"] = "Player Management",
							["Icon"] = Utilities.Icon "users"
						},
						["Action"] = `Locked a server down with reason: {Data.PrivReason}`,
						["Icon"] = Utilities.Icon "lock-closed",
						["Timestamp"] = os.time()
					})

					PlayerStore:SetAsync(Player.UserId, AdminDat)
					GlobalReplicate({
						Action      = "ChangeAccessLevel",
						JobID       = Data.JobID,
						Level       = Data.AccessLevel, 
						AdminName   = Player.Name,
						PubReason   = Data.PubReason
					})

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `{Player.Name} changed a server's access level!`,
						["Body"] = `Data: \n\`\`\`json\n{game:GetService("HttpService"):JSONEncode(Data)}\n\`\`\``,
						["Footer"] = `Successfully processed in {tick() - ST}s`
					})

					return {true, "Success!", os.time() - ST}
				end,
				function(E)
					warn(`Failed to execute: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to change a servers access level!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "ShutdownServer" then
			return xpcall(
				function()
					table.insert(AdminDat.AuditableActions, {
						["App"] = {
							["Name"] = "Player Management",
							["Icon"] = Utilities.Icon "users"
						},
						["Action"] = `Shut a server down with reason: {Data.PrivReason}`,
						["Icon"] = Utilities.Icon "user-exit",
						["Timestamp"] = os.time()
					})

					PlayerStore:SetAsync(Player.UserId, AdminDat)

					GlobalReplicate({
						Action    = "ShutdownServer",
						JobID     = Data.JobID,
						AdminID   = Player.UserId,
						AdminName = Player.Name,
						PubReason = Data.PubReason
					})

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `{Player.Name} shut down a server!`,
						["Body"] = `Data: \n\`\`\`json\n{game:GetService("HttpService"):JSONEncode(Data)}\n\`\`\``,
						["Footer"] = `Successfully processed in {tick() - ST}s`
					})

					return {true, "Success!", os.time() - ST}
				end,
				function(E)
					warn(`Failed to execute: {E}`)

					WebhookPost({
						["Color"] = "ff000",
						["Title"] = `(fault) {Player.Name} failed to shutdown a server!`,
						["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
						["Footer"] = `Successfully Processed in {tick() - ST}s`
					})

					return {false, E, os.time() - ST}
				end
			)
		elseif Message == "SendCommand" then


		elseif Message == "GetAllPlayers" then
			local Final = {}
			local Pages

			if Data.Type == "Deep" then
				Pages = PlayerStore:ListKeysAsync()
			else
				Pages = PlayerStore:ListKeysAsync(Data.Query, 100)
			end

			while true do
				for j, Key in Pages:GetCurrentPage() do
					table.insert(Final, Key.KeyName)
				end

				if Pages.IsFinished or #Final >= 6500 then break end

				if not pcall(function()
						Pages:AdvanceToNextPageAsync()
					end) then
					print("waiting out a throttle..")

					task.wait(10)

					Pages:AdvanceToNextPageAsync()
				end
			end

			if #Final >= 6500 then
				warn("Results have been truncated!")
			end

			return Final

		elseif Message == "SearchFromRoblox" then
			local Final = {}
			local Http = game:GetService("HttpService")
			local ProxyURL = require(script:FindFirstAncestor("Administer").Loader.Core.Variables).ProxyURL
			local Cursor = ""

			while true do
				local Response = Http:RequestAsync({
					Url = `{ProxyURL}/users/v1/users/search?keyword={Data.Query}&limit=100&cursor={Cursor}`,
					Method = "GET"
				})

				local Data = Http:JSONDecode(Response.Body)

				xpcall(function()
					for _, v in Data.data do
						table.insert(Final, v.id)
					end
				end, function()
					Final.__message = "We encountered an error early, results may be incomplete."		
				end)

				if Data.nextPageCursor ~= nil then
					Cursor = Data.nextPageCursor
				else
					break
				end
			end

			return Final
		end
	end

	--// Run
	print("[✓] Player Management initialized, spawning refresh thread.")
	task.spawn(RefreshTask)
	
	Utils = RuntimeAPI.Modules.Utilities

	--// Remotes
	Utilities.NewRemote("RemoteFunction", "ServerComm", true, function(Player, ...)
		return ClientMessagePort(Player, ...)
	end, "PlayerManagement")

	Utilities.NewRemote("RemoteFunction", "PerformClientAction", true, function(Player, ...)
		--// We don't actuially want to do anything here, only create the event to have the client be able to use it.
		return true
	end, "PlayerManagement")

	Utilities.NewRemote("RemoteFunction", "InsecureClientAction", false, function(Player, Data)
		if Data.Action == "ReturnPrivateMessage" then
			local MessageID = PrivateMessageIDs[Player.UserId]

			GlobalReplicate({
				Action = "ReturnPMData",
				AdmMessageID = MessageID,

				Sender = Player.Name,
				Message = Data.Text
			})

			PrivateMessageIDs[Player.UserId] = nil
		else
			return {false, "Unknown command"}
		end
	end, "PlayerManagement")

	game.Players.PlayerAdded:Connect(InitPlayer)
	game.Players.PlayerRemoving:Connect(function(Player)
		local Info = Players[Player.UserId]
		local DSInfo = PlayerStore:GetAsync(Player.UserId)

		DSInfo.LastSeen = os.time()
		DSInfo.PlayTime = DSInfo.PlayTime + (os.time() - Info.JoinTime)
		DSInfo.IsActive = false

		PlayerStore:SetAsync(Player.UserId, DSInfo, { Player.UserId })
	end)

	for i, Player in game.Players:GetPlayers() do
		if Players[Player.UserId] == nil then
			task.spawn(function()
				InitPlayer(Player)
			end)
		end
	end
end
