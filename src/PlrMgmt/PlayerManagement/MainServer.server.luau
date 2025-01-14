--// pyxfluff 2024
--// Player Management

--// Modules
local Runner = require(game.ServerScriptService.Administer.AppAPI)
local ServerIndex = require(script.Parent.Modules.ServerIndex)

--// Services
local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local TextService = game:GetService("TextService")

--// DataStores
local PlayerStore = DataStoreService:GetDataStore("AdministerPM_PlayerStore")

--// Variables
local RefreshDuration = 15 --// You may want to tweak this based on the 1000 + 100(players) rate limit. Do NOT make higher than 60.
local AllTimePlayers = 0
local AllTimeAdmins = 0
local CurrentAdmins = 0
local ChatMessages = {}
local SLock = 0 --// 0 = unlocked, 1 = admins, 2 = everyone
local SLockMessage = ""
local DefaultData = {
	["Joins"] = 0,
	["PlayTime"] = 0,
	["FirstSeen"] = 0,
	["LastSeen"] = 0,
	["IsActive"] = true,
	["ModRecords"] = {
		["_Warnings"] = 0,
		["_Bans"] = 0,
		["Actions"] = {},
	},
	["AuditableActions"] = {},
}

local Players = {}
local AdminIDs = {}
local ServerBanned = {}
local PlayerCache = {}
local IsAdmin
local RefreshTask = function()
	ServerIndex.UploadToIndex({
		["AP"] = AllTimePlayers,
		["AA"] = AllTimeAdmins,
		["CA"] = CurrentAdmins,
		["AI"] = AdminIDs,
	})

	while task.wait(RefreshDuration) do
		xpcall(function()
			ServerIndex.UploadToIndex({
				["AP"] = AllTimePlayers,
				["AA"] = AllTimeAdmins,
				["CA"] = CurrentAdmins,
				["AI"] = AdminIDs,
				--["GameErrorCount"] = 0,
				--["GameWarningCount"] = 0
				["SR"] = "US",
			})
		end, function(p)
			print(`Failed to refresh our server for this frame: {p}`)
		end)
	end
end

local function CachePlayer(ID, Verbose, ReturnPlaceholderOnFail)
	local PlayerData = PlayerCache[ID]

	if not PlayerData then
		repeat
			local Suc, Content = pcall(function()
				return game:GetService("UserService"):GetUserInfosByUserIdsAsync({ ID })[1]
			end)

			if not Suc then
				if Verbose then print("We appear to be ratelimited, trying again soon.") end
				if ReturnPlaceholderOnFail then
					return {
						Id = ID,
						DisplayName = "Loading failed",
						Username = `Ratelimit reached ({ID})`,
						HasVerifiedBadge = false,
						Photo = "rbxassetid://84027648824846",
					}
				end
				task.wait(2)
			else
				PlayerData = Content
				PlayerData["Photo"] =
					game.Players:GetUserThumbnailAsync(ID, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
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

local function InitPlayer(Player: Player)
	repeat
		task.wait(0.1)
	until Player.UserId
	local PlayerInfo = PlayerStore:GetAsync(Player.UserId) or Clone(DefaultData)

	if SLock == 2 then
		Player:Kick(`This server is locked. Try rejoining later.\n\n{SLockMessage}`)
	elseif SLock == 1 then
		if not IsAdmin(Player) then
			Player:Kick(`This server is locked to admins only. Try rejoining later.\n\n{SLockMessage}`)
		end
	end

	if PlayerInfo == Clone(DefaultData) or PlayerInfo["FirstSeen"] == 0 then PlayerInfo["FirstSeen"] = os.time() end

	PlayerInfo["LastSeen"] = os.time()
	PlayerInfo["IsActive"] = true
	PlayerInfo["Joins"] += 1
	PlayerInfo["_AdministerSaveData"] = true

	Players[Player.UserId] = {
		JoinTime = os.time(),
		Messages = {},
		DS = PlayerInfo,
		PlrInstance = Player,
	}

	PlayerStore:SetAsync(Player.UserId, PlayerInfo, { Player.UserId })
	AllTimePlayers += 1

	Player.Chatted:Connect(function(Message)
		local Success, FilteredMessage = pcall(function()
			return TextService:FilterStringAsync(Message, Player.UserId):GetNonChatStringForBroadcastAsync()
		end)

		table.insert(Players[Player.UserId]["Messages"], FilteredMessage)
	end)

	if PlayerInfo["ModRecords"]["ActiveBan"] then
		task.delay(2, function()
			if Players[Player.UserId] ~= nil then
				PlayerInfo["ModRecords"]["ActiveBan"] = false

				PlayerStore:SetAsync(Player.UserId, PlayerInfo, { Player.UserId })

				print("Set ban record to false!")
			else
				print("Not found, assuming ban is active still")
			end
		end)
	end
end

local function ForceInitPlayerByID(UserID: number)
	local PlayerInfo = PlayerStore:GetAsync(UserID) or DefaultData

	print("init", PlayerInfo)

	PlayerInfo["LastSeen"] = 0
	PlayerInfo["IsActive"] = false
	PlayerInfo["Joins"] += 1

	PlayerStore:SetAsync(UserID, PlayerInfo, { UserID })
end

local function MessageSocket(M)
	local Data = M.Data

	if Data["Action"] == "UploadChatLogs" then
		if not Players[Data.ID] then
			--// This request is not for us
			return
		end

		print(Players[Data.ID].Messages)
	elseif Data["Action"] == "KickPlayer" then
		if not Players[Data.TargetID] then return end

		Players[Data.TargetID].PlrInstance:Kick(
			`\n[Administer]\n\nKicked by {Data["AdminName"]}:\n{Data["KickMessage"]}`
		)
	elseif Data["Action"] == "PlayerNote" then
		if not Players[Data.TargetID] then return end

		local NewUI = script.Parent.UI.Message:Clone()
		local AdminDat = CachePlayer(Data["AdminID"], false, false)

		NewUI.Parent = Players[Data.TargetID].PlrInstance.PlayerGui
		NewUI.CanvasGroup.MainNote.Notice.Text = `<i>{Data["Message"]}</i>`
		NewUI.CanvasGroup.MainNote.UserMeta.Text = `<b>{AdminDat["DisplayName"]}</b> (@{AdminDat["Username"]}) • Now`
		NewUI.CanvasGroup.MainNote.Icon.Image = AdminDat.Photo

		NewUI.CanvasGroup.LocalScript.Enabled = true
	elseif Data["Action"] == "FunCommand" then
		if not Players[Data.TargetID] then return end
		if Data["Action"] then
			if Data["Action"] == "shirt" then
			elseif Data["Action"] == "pants" then
			elseif Data["Action"] == "hat" then
			elseif Data["Action"] == "face" then
			elseif Data["Action"] == "invisible" then
			elseif Data["Action"] == "visible" then
			elseif Data["Action"] == "walkspeed" then
			elseif Data["Action"] == "jumppower" then
			elseif Data["Action"] == "freeze" then
			elseif Data["Action"] == "forcefield" then
			elseif Data["Action"] == "size" then
			elseif Data["Action"] == "health" then
			elseif Data["Action"] == "heal" then
			elseif Data["Action"] == "god" then
			elseif Data["Action"] == "damage" then
			elseif Data["Action"] == "kill" then
			elseif Data["Action"] == "control" then
			elseif Data["Action"] == "sword" then
			elseif Data["Action"] == "name" then
			end
		end
	end
end

local MainMessageSocket = MessagingService:SubscribeAsync("Administer-PlayerManagement", MessageSocket)

local function WebhookPost(Data)
	--// TODO
	game:GetService("HttpService"):PostAsync(
		"",
		game:GetService("HttpService"):JSONEncode({
			["embeds"] = {
				{
					["color"] = tonumber(`0x{Data["Color"]}`, 16),
					["title"] = Data["Title"],
					["description"] = Data["Body"],
					["footer"] = {
						["text"] = `{Data["Footer"]} • Powered by Administer`,
					},
				},
			},
		})
	)
end

local function CommunicateWithClient(Player, Message, Data)
	local ST = tick()
	local TargetDat
	local AdminDat = PlayerStore:GetAsync(Player.UserId)

	xpcall(function()
		if Data["TargetID"] then
			TargetDat = Players[Data.TargetID]

			if not TargetDat then
				print("External player...")
				TargetDat = PlayerStore:GetAsync(Data.TargetID)
			else
				TargetDat = TargetDat["DS"]
			end

			if Message ~= "WarnPlr" then
				TargetDat["_AdministerSaveData"] = false --// ensure our changes do not get overwritten
				TargetDat["IsActive"] = false
			end
		end
	end, function()
		--// no TargetID pls stop erroring
	end)

	if Message == "RequestServers" then
		return ServerIndex.GetAllServers()
	elseif Message == "PlayerLookup" then
		local MainDat
		xpcall(function()
			MainDat = PlayerStore:GetAsync(Data["ID"])
		end, function()
			return { ["Message"] = "Invalid player!" }
		end)

		if MainDat then
			return { ["Main"] = MainDat, ["Admin"] = {} }
		else
			if not Data["Force"] then
				return {
					["Message"] = "This user does not exist. Hit enter to force load this player (results in incorrect data!)",
				}
			end

			ForceInitPlayerByID(Data["ID"])

			return CommunicateWithClient(Player, Message, Data)
		end
	elseif Message == "RequestPlayerJSON" then
		local MainDat = PlayerStore:GetAsync(Data)
		--local AdminInfo = IsAdmin({UserId = Data})

		return { ["Main"] = MainDat, ["Admin"] = {} }
	elseif Message == "BanPlayer" then
		xpcall(function()
			TargetDat["ModRecords"]["Actions"][`Ban-{math.random(1, 50000)}`] = {
				["DidClearWarnings"] = Data["ClearWarnings"],
				["Duration"] = Data["BanDuration"],
				["Expires"] = os.time() + Data["BanDuration"],
				["Moderator"] = Player.UserId,
				["PrivNote"] = Data["PrivateNote"],
				["Reason"] = Data["BanReason"],
				["Timestamp"] = os.time(),
				["_Type"] = "BAN",
				["Source"] = `Administer`,
			}
			TargetDat["ModRecords"]["_Bans"] += 1
			TargetDat["ModRecords"]["CurrentBanDuration"] = Data["BanDuration"]
			TargetDat["ModRecords"]["ActiveBan"] = true

			if Data["ClearWarnings"] then
				for k, Record in TargetDat["ModRecords"]["Actions"] do
					if Record["_Type"] == "WARN" then TargetDat["DS"]["ModRecords"]["Actions"][k] = nil end
				end

				TargetDat["ModRecords"]["_Warnings"] = 0

				table.insert(AdminDat["AuditableActions"], {
					["App"] = {
						["Name"] = "Player Management",
						["Icon"] = "",
					},
					["Action"] = `Removed all of {Data.TargetID}'s warnings (as a part of a ban).`,
					["Icon"] = "",
					["Timestamp"] = os.time(),
				})
			end

			table.insert(AdminDat["AuditableActions"], {
				["App"] = {
					["Name"] = "Player Management",
					["Icon"] = "",
				},
				["Action"] = `Banned {Data.TargetID} for {Data["BanDurationString"]} ({Data["BanReason"]}).`,
				["Icon"] = "",
				["Timestamp"] = os.time(),
			})

			PlayerStore:SetAsync(Data["TargetID"], TargetDat)
			PlayerStore:SetAsync(Player.UserId, AdminDat)

			game.Players:BanAsync({
				["UserIds"] = { tonumber(Data["TargetID"]) },
				["ApplyToUniverse"] = true,
				["Duration"] = Data["BanDuration"],
				["DisplayReason"] = Data["BanReason"],
				["PrivateReason"] = `{Data["PrivateNote"]} (banned by: {Player.Name} ({Player.UserId}) )`,
				["ExcludeAltAccounts"] = false,
			})

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `{Player.Name} has banned {Data["TargetID"]}!`,
				["Body"] = `This ban lasts for {Data["BanDurationString"]}.\n\nReason: {Data["BanReason"]}\n\nModerator note: {Data["PrivateNote"]}.`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { true, "Success!", os.time() - ST }
		end, function(E)
			warn(`Failed to ban: {E}`)

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `(fault) {Player.Name} failed to ban {Data["TargetID"]}!`,
				["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { false, E, os.time() - ST }
		end)
	elseif Message == "KickPlayer" then
		xpcall(function()
			TargetDat["ModRecords"]["Actions"][`Kick-{math.random(1, 1500000)}`] = {
				["DidClearWarnings"] = Data["ClearWarnings"],
				["Moderator"] = Player.UserId,
				["PrivNote"] = Data["PrivateNote"],
				["Reason"] = Data["KickMsg"],
				["Timestamp"] = os.time(),
				["_Type"] = "KICK",
			}

			table.insert(AdminDat["AuditableActions"], {
				["App"] = {
					["Name"] = "Player Management",
					["Icon"] = "",
				},
				["Action"] = `Kicked {Data.TargetID} ({Data["BanReason"]}).`,
				["Icon"] = "",
				["Timestamp"] = os.time(),
			})

			PlayerStore:SetAsync(Data["TargetID"], TargetDat)
			PlayerStore:SetAsync(Player.UserId, AdminDat)

			MessagingService:PublishAsync("Administer-PlayerManagement", {
				["Action"] = "KickPlayer",
				["TargetID"] = Data["TargetID"],
				["AdminID"] = Player.UserId,
				["AdminName"] = Player.Name,
				["KickMessage"] = Data["KickMsg"],
			})

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `{Player.Name} kicked {Data["TargetID"]}!`,
				["Body"] = `{Data["KickMsg"]}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { true, "Success! Sent the message off, wait a few seconds and then check again.", os.time() - ST }
		end, function(E)
			warn(`Failed to kick: {E}`)

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `(fault) {Player.Name} failed to kick {Data["TargetID"]}!`,
				["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { false, E, os.time() - ST }
		end)
	elseif Message == "WarnPlayer" then
		xpcall(function()
			TargetDat["ModRecords"]["Actions"][`Warning-{math.random(1, 50000)}`] = {
				["Moderator"] = Player.UserId,
				["Warning"] = Data["Warning"],

				["Timestamp"] = os.time(),
				["_Type"] = "WARN",
			}

			table.insert(AdminDat["AuditableActions"], {
				["App"] = {
					["Name"] = "Player Management",
					["Icon"] = "",
				},
				["Action"] = `Warned {Data.TargetID}: {Data["Warning"]}`,
				["Icon"] = "",
				["Timestamp"] = os.time(),
			})

			PlayerStore:SetAsync(Data["TargetID"], TargetDat)
			PlayerStore:SetAsync(Player.UserId, AdminDat)

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `{Player.Name} warned {Data["TargetID"]}!`,
				["Body"] = Data["Warning"],
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { true, "Success!", os.time() - ST }
		end, function(E)
			warn(`Failed to unban: {E}`)

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `(fault) {Player.Name} failed to warn {Data["TargetID"]}!`,
				["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { false, E, os.time() - ST }
		end)
	elseif Message == "UnbanPlayer" then
		xpcall(function()
			TargetDat["ModRecords"]["Actions"][`Unban-{math.random(1, 50000)}`] = {
				["Moderator"] = Player.UserId,
				["PrivNote"] = Data["Note"],

				["Timestamp"] = os.time(),
				["_Type"] = "UNBAN",
				["Source"] = `Administer`,
			}
			TargetDat["ModRecords"]["ActiveBan"] = false

			table.insert(AdminDat["AuditableActions"], {
				["App"] = {
					["Name"] = "Player Management",
					["Icon"] = "",
				},
				["Action"] = `Unbanned {Data.TargetID} early.`,
				["Icon"] = "",
				["Timestamp"] = os.time(),
			})

			PlayerStore:SetAsync(Data["TargetID"], TargetDat)
			PlayerStore:SetAsync(Player.UserId, AdminDat)

			game.Players:UnbanAsync({
				["UserIds"] = { tonumber(Data["TargetID"]) },
				["ApplyToUniverse"] = true,
			})

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `{Player.Name} unbanned {Data["TargetID"]} early!`,
				["Body"] = ``,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { true, "Success!", os.time() - ST }
		end, function(E)
			warn(`Failed to unban: {E}`)

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `(fault) {Player.Name} failed to unban {Data["TargetID"]}!`,
				["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { false, E, os.time() - ST }
		end)
	elseif Message == "SendNote" then
		xpcall(function()
			TargetDat["ModRecords"]["Actions"][`Unban-{math.random(1, 50000)}`] = {
				["Moderator"] = Player.UserId,
				["Message"] = Data["Message"],

				["Timestamp"] = os.time(),
				["_Type"] = "NOTE",
			}

			table.insert(AdminDat["AuditableActions"], {
				["App"] = {
					["Name"] = "Player Management",
					["Icon"] = "",
				},
				["Action"] = `Sent a note to {Data.TargetID}: {Data.Message}`,
				["Icon"] = "",
				["Timestamp"] = os.time(),
			})

			PlayerStore:SetAsync(Data["TargetID"], TargetDat)
			PlayerStore:SetAsync(Player.UserId, AdminDat)

			MessagingService:PublishAsync("Administer-PlayerManagement", {
				["Action"] = "PlayerNote",
				["Message"] = Data["Message"],

				["TargetID"] = Data["TargetID"],
				["AdminID"] = Player.UserId,
			})

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `{Player.Name} sent a note to {Data["TargetID"]}!`,
				["Body"] = `They said: {Data["Message"]}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { true, "Success!", os.time() - ST }
		end, function(E)
			warn(`Failed to unban: {E}`)

			WebhookPost({
				["Color"] = "ff000",
				["Title"] = `(fault) {Player.Name} failed to send not to {Data["TargetID"]}!`,
				["Body"] = `If this isn't a misconfiguration or Roblox API issue, please report it to Administer. Error: {E}`,
				["Footer"] = `Successfully Processed in {tick() - ST}s`,
			})

			return { false, E, os.time() - ST }
		end)
	elseif Message == "WritePlayerPrivNote" then
	elseif Message == "LockServer" then
	elseif Message == "CloseServer" then
	elseif Message == "SendCommand" then
	end
end

--// Run
local App = Runner.Build(function(Config, AppAPI)
	print("✓ App initialized, spawning refresh thread.")
	task.spawn(RefreshTask)

	IsAdmin = AppAPI.IsAdmin

	--// Remotes
	AppAPI.NewRemoteFunction("ServerComm", function(Player, ...)
		if not AppAPI.IsAdmin(Player) then
			return { false }
		else
			return CommunicateWithClient(Player, ...)
		end
	end)

	AppAPI.NewRemoteFunction("PerformClientAction", function()
		--// We don't actuially want to do anything here, only create the event to have the client be able to use it.
		return true
	end)

	game.Players.PlayerAdded:Connect(function(Player)
		InitPlayer(Player, AppAPI)
	end)

	game.Players.PlayerRemoving:Connect(function(Player)
		local Info = Players[Player.UserId]
		local DSInfo = PlayerStore:GetAsync(Player.UserId)
		local ShouldSave = DSInfo["_AdministerSaveData"]

		if not ShouldSave then
			print("Ignoring request to save...")
			return
		end

		Info["DS"]["LastSeen"] = os.time()
		Info["DS"]["PlayTime"] = Info["DS"]["PlayTime"] + (os.time() - Info["JoinTime"])
		Info["DS"]["IsActive"] = false
		Info["DS"]["ModRecords"] = DSInfo["ModRecords"]

		PlayerStore:SetAsync(Player.UserId, Info["DS"], { Player.UserId })
	end)

	for i, Player in game.Players:GetPlayers() do
		if Players[Player.UserId] == nil then task.spawn(function()
			InitPlayer(Player, AppAPI)
		end) end
	end
end, {}, {
	Icon = "rbxassetid://15098897156",
	Name = "Player Management",
	Frame = script.Parent.UI.PlayerManagement,
	Tip = "Manage your game's players from anywhere.",
	HasBG = false,
})
