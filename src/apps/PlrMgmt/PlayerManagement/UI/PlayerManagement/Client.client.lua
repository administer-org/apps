--// pyxfluff 2024

local Remotes = game.ReplicatedStorage:WaitForChild("AdministerApps"):WaitForChild("Player Management")

local PausePolling = false
local PollInterval = 10
local Connections = {}
local PlayerCache = {}

local MainFrame = script.Parent
local Box = script.Parent.ServerDir.ServerLookup
local PlayerFrame = MainFrame.Player 

local Shimmer = require(game.Players.LocalPlayer.PlayerGui.AdministerMainPanel.MainClient.Shime)

local function FormatTime(Seconds, Full, _)
	local Days = math.floor(Seconds / 86400)
	Seconds = Seconds % 86400
	local Hours = math.floor(Seconds / 3600)
	Seconds = Seconds % 3600
	local Minutes = math.floor(Seconds / 60)
	Seconds = math.floor(Seconds % 60)

	local Final = ""
	if Days > 0 then
		Final = `{Final}{Days}{Full and ` day{Days == 1 and "" or "s"}, ` or "d"}`
	end
	if Hours > 0 then
		Final = `{Final}{Hours}{Full and ` hour{Hours == 1 and "" or "s"}, ` or "h"}`
	end
	if Minutes > 0 then
		Final = `{Final}{Minutes}{Full and ` minute{Minutes == 1 and "" or "s"}, ` or "m"}`
	end
	if Seconds > 0 or Final == "" then
		--Final = `{Final}{Seconds}{Full and ` second{Seconds == 1 and "" or "s"}{Period and "." or ""}` or "s"}`
		Final = `{Final}{Seconds}{Full and ` second{Seconds == 1 and "" or "s"}` or "s"}`
	end

	return Final
end

local function FormatRelativeTime(Unix)
	local TimeDifference = os.time() - (Unix ~= nil and Unix or 0)

	if TimeDifference < 60 then
		return "a few seconds ago"
	elseif TimeDifference < 3600 then
		local Minutes = math.floor(TimeDifference / 60)
		return `{Minutes} {Minutes == 1 and "minute" or "minutes"} ago`
	elseif TimeDifference < 86400 then
		local Hours = math.floor(TimeDifference / 3600)
		return `{Hours} {Hours == 1 and "hour" or "hours"} ago`
	elseif TimeDifference < 604800 then
		local Days = math.floor(TimeDifference / 86400)
		return `{Days} {Days == 1 and "day" or "days"} ago`
	elseif TimeDifference < 31536000 then
		local Weeks = math.floor(TimeDifference / 604800)
		return `{Weeks} {Weeks == 1 and "week" or "weeks"} ago`
	else
		local Years = math.floor(TimeDifference / 31536000)
		return `{Years} {Years == 1 and "years" or "years"} ago`
	end
end

local function CachePlayer(
	ID, 
	Verbose, 
	ReturnPlaceholderOnFail
): { Id: string, DisplayName: string, Username: string, HasVerifiedBadge: boolean, Photo: string<RBXAsset> }
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
						Username = "Ratelimit reached",
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

--// Take a sample and attempt to cache as many people as possible
task.spawn(function()
	local List = Remotes.ServerComm:InvokeServer("RequestServers")

	for i, s in List do
		for _i, p in s[2]["P"] do
			CachePlayer(p, false, false)
		end
	end
end)

local function LoadPlayer(
	PlayerID, 
	ServerJobID, 
	Delay
): nil
	for i, conn in Connections do conn:Disconnect() end
	Connections = {}
	
	for i, c in PlayerFrame.ModerationHistory.ActionList:GetChildren() do
		if c:IsA("Frame") and c.Name ~= "Log" then
			c:Destroy() 
		end
	end

	for i, c in PlayerFrame.ChatLogs.ActionList:GetChildren() do
		if c:IsA("Frame") and c.Name ~= "Log" then
			c:Destroy() 
		end
	end

	for i, c in PlayerFrame.AuditLogs.ActionList:GetChildren() do
		if c:IsA("Frame") and c.Name ~= "Log" then
			c:Destroy() 
		end
	end

	PlayerFrame.ImageLabel.ImageColor3 = Color3.fromRGB(126, 128, 175)
	PlayerFrame.PlayerImage.Image = "rbxassetid://15105863258"
	PlayerFrame.PlayerDN.Text = "Loading player info..."
	PlayerFrame.PlayerUN.Text = ""

	local Shimmers = {}
	Connections = {}

	PlayerFrame.Visible = true
	Box.Visible = false
	MainFrame.ServerDir.Visible = false

	for i, Frame in {PlayerFrame.PlayerImage, PlayerFrame.AuditLogs, PlayerFrame.ChatLogs, PlayerFrame.ModerationHistory, PlayerFrame.PlayerUN, PlayerFrame.PlayerDN, PlayerFrame.Stats, PlayerFrame.QuickActions} do
		Shimmers[Frame.Name] = Shimmer.new(Frame)

		Shimmers[Frame.Name]:Play()
	end

	if Delay then
		task.wait(2)
	end
	
	print("Starting playr loading sequence..")
	local PlayerBasic = CachePlayer(PlayerID, false, false)
	print("Got basic")
	local PlayerFull = Remotes.ServerComm:InvokeServer("RequestPlayerJSON", PlayerID)
	print("Got JSON")
	local PromColor = game.ReplicatedStorage.AdministerRemotes.GetProminentColorFromUserID:InvokeServer(PlayerID)
	print("Got color")
	
	PlayerFrame.PlayerDN.Text = PlayerBasic["DisplayName"]
	PlayerFrame.PlayerUN.Text = `{PlayerBasic["Username"]} · {PlayerBasic["Id"]}`
	PlayerFrame.ImageLabel.ImageColor3 = Color3.fromRGB(PromColor[1], PromColor[2], PromColor[3])
	PlayerFrame.PlayerImage.Image = PlayerBasic["Photo"]

	if PlayerFull["Main"]["IsActive"] then
		PlayerFrame.PlayerImage.UIStroke.Enabled = true
		PlayerFrame.PlayerStatusIcon.BackgroundColor3 = Color3.fromRGB(20, 255, 114)
	else
		PlayerFrame.PlayerImage.UIStroke.Enabled = false
		PlayerFrame.PlayerStatusIcon.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	end

	local Stats = PlayerFrame.Stats.ActionList
	
	print(PlayerFull["Main"])
	
	if PlayerFull["Main"]["LastSeen"] == 0 then
		Stats.Stat_FirstSeen.Desc.Text = "First seen: never"
		Stats.Stat_LastSeen.Desc.Text = "Last seen: never"
		Stats.Stat_PlayTime.Desc.Text = "Playtime: 0 minutes"
		Stats.Stat_Plays.Desc.Text = `Game joins: 0`
		Stats.Stat_Warnings.Desc.Text = `<font color="{PlayerFull["Main"]["ModRecords"]["_Warnings"] >= 2 and "rgb(187, 189, 49)" or "rgb(255,255,255)"}">{PlayerFull["Main"]["ModRecords"]["_Warnings"]} Warnings</font>`
		Stats.Stat_Warnings.Icon.ImageColor3 = (PlayerFull["Main"]["ModRecords"]["_Warnings"] >= 2 and Color3.fromRGB(187,189, 49) or Color3.new(1,1,1))
		Stats.Stat_IsAdmin.Desc.Text = `<font color=\"{PlayerFull["Admin"]["IsAdmin"] and "rgb(255,0,0)" or "rgb(255,255,255)"}\">User is not protected</font>`
	else
		Stats.Stat_FirstSeen.Desc.Text = `First seen: {FormatRelativeTime(PlayerFull["Main"]["FirstSeen"])}`
		Stats.Stat_LastSeen.Desc.Text = `Last seen: {PlayerFull["Main"]["IsActive"] and "<font color=\"rgb(0,255,0)\">now</font>" or FormatRelativeTime(PlayerFull["Main"]["LastSeen"])}`
		Stats.Stat_PlayTime.Desc.Text = `Playtime: {FormatTime(PlayerFull["Main"]["PlayTime"])}`
		Stats.Stat_Plays.Desc.Text = `Game joins: {PlayerFull["Main"]["Joins"]}`
		Stats.Stat_Warnings.Desc.Text = `<font color="{PlayerFull["Main"]["ModRecords"]["_Warnings"] >= 2 and "rgb(187, 189, 49)" or "rgb(255,255,255)"}">{PlayerFull["Main"]["ModRecords"]["_Warnings"]} Warnings</font>`
		Stats.Stat_Warnings.Icon.ImageColor3 = (PlayerFull["Main"]["ModRecords"]["_Warnings"] >= 2 and Color3.fromRGB(187,189, 49) or Color3.new(1,1,1))
		Stats.Stat_IsAdmin.Desc.Text = `<font color=\"{PlayerFull["Admin"]["IsAdmin"] and "rgb(255,0,0)" or "rgb(255,255,255)"}\">User is {PlayerFull["Admin"]["IsAdmin"] and `protected (admin under Rank {PlayerFull["Admin"]["RankID"]})` or "not protected"}</font>`
	end

	for _, Obj in {"PlayerImage", "PlayerUN", "PlayerDN", "Stats", "QuickActions"} do
		Shimmers[Obj]:Pause()
		Shimmers[Obj]:GetFrame():Destroy()
	end

	for key, Data in PlayerFull["Main"]["ModRecords"]["Actions"] do
		local Action = PlayerFrame.ModerationHistory.ActionList.Log:Clone()
		local ModData = CachePlayer(Data["Moderator"], false, false)

		Action.Parent = PlayerFrame.ModerationHistory.ActionList
		Action.Visible = true
		Action.Name = math.random(1,834285348)

		Action.ActionLabel.Text = `<b>@{ModData["Username"]}</b> {
			Data["_Type"] == "BAN"        and   `created a ban for {FormatTime(Data["Duration"], true)}` or
			Data["_Type"] == "WARN"       and   "created an active warning" or
			Data["_Type"] == "NOTE"       and   "sent a note privately" or
			Data["_Type"] == "LOGS_CLEAR" and   "cleared their logs" or
			Data["_Type"] == "KICK"       and   "kicked them out of the game server" or
			Data["_Type"] == "TELEPORT"   and   "moved them to another game" or
			Data["_Type"] == "UNBAN"      and   "unbanned them early" or
			"... did something that confused your client"
		}`
		Action.Note.Text = 
			Data["_Type"] == "BAN"        and   `{Data["Reason"]} ({Data["PrivNote"]}).` or
			Data["_Type"] == "WARN"       and   Data["Warning"] or
			Data["_Type"] == "NOTE"       and   Data["Message"] or
			Data["_Type"] == "LOGS_CLEAR" and   `All logs and statistics may have been reset.` or
			Data["_Type"] == "KICK"       and   `{Data["Reason"]} ({Data["PrivNote"]}).` or
			Data["_Type"] == "TELEPORT"   and   `Sent to {Data["PlaceID"]}. {Data["Reason"]}` or
			Data["_Type"] == "UNBAN"      and   Data["PrivNote"] or
			"Failed (_Type was an unexpected value, corrupt datastore or unfinished feature)"
		Action.Icon.Image = 
			Data["_Type"] == "BAN"        and   "https://www.roblox.com/asset/?id=11284736452" or
			Data["_Type"] == "WARN"       and   "https://www.roblox.com/asset/?id=17402667535" or
			-- Data["_Type"] == "NOTE"       and   "0" or
			-- Data["_Type"] == "LOGS_CLEAR" and   "0" or
			Data["_Type"] == "KICK"       and   "https://www.roblox.com/asset/?id=138303173193406" or
			Data["_Type"] == "TELEPORT"   and   "https://www.roblox.com/asset/?id=84037313964620" or
			"http://www.roblox.com/asset/?id=15105963940"
		Action.Player.Image = ModData["Photo"]
	end

	Shimmers["ModerationHistory"]:Pause()
	Shimmers["ModerationHistory"]:GetFrame():Destroy()

	--// load chatlogs todotodotodotodo

	Shimmers["AuditLogs"]:Pause()
	Shimmers["AuditLogs"]:GetFrame():Destroy()

	Connections["BanButton"] = PlayerFrame.QuickActions.ActionList.Ban.Click.MouseButton1Click:Connect(function()
		PlayerFrame.BanBox.Visible = true

		PlayerFrame.BanBox.MiscMeta.Text = `@{PlayerBasic["Username"]} • {PlayerID}`
		PlayerFrame.BanBox.TopEffect.PlayerImage.Image = PlayerBasic["Photo"]
		PlayerFrame.BanBox.Header.Text = `Ban {PlayerBasic["DisplayName"]}`
		PlayerFrame.BanBox.HeaderContainer.HeaderLabel.Text = `Ban @{PlayerBasic["Username"]}`

		Connections["BanClose"] = PlayerFrame.BanBox.HeaderContainer.Exit.MouseButton1Click:Connect(function()
			PlayerFrame.BanBox.Visible = false
		end)
	end)

	Connections["KickButton"] = PlayerFrame.QuickActions.ActionList.Kick.Click.MouseButton1Click:Connect(function()
		PlayerFrame.KickBox.Visible = true

		PlayerFrame.KickBox.MiscMeta.Text = `@{PlayerBasic["Username"]} • {PlayerID}`
		PlayerFrame.KickBox.TopEffect.PlayerImage.Image = PlayerBasic["Photo"]
		PlayerFrame.KickBox.Header.Text = `Kick {PlayerBasic["DisplayName"]}`
		PlayerFrame.KickBox.HeaderContainer.HeaderLabel.Text = `Kick @{PlayerBasic["Username"]}`

		Connections["KickClose"] = PlayerFrame.KickBox.HeaderContainer.Exit.MouseButton1Click:Connect(function()
			PlayerFrame.KickBox.Visible = false
		end)
	end)

	Connections["DoKick"] = PlayerFrame.KickBox.Kick.MouseButton1Click:Connect(function()
		local Shm = Shimmer.new(PlayerFrame.KickBox.Kick)
		Shm:Play()

		print(Remotes.ServerComm:InvokeServer("KickPlayer", {
			["PrivateNote"] = PlayerFrame.KickBox.LogMessage.Text or "No reason provided.",
			["KickMsg"] = PlayerFrame.KickBox.KickMessage.Text or `No reason provided.`,
			["TargetID"] = PlayerID,
		}))

		PlayerFrame.KickBox.Kick.Label.Text = "SUCCESS!"

		Shm:Pause()
		Shm:GetFrame():Destroy()

		task.wait(2) --// make sure data is up to date bc message might take a minute to send
		PlayerFrame.KickBox.Visible = false
		PlayerFrame.KickBox.Kick.Label.Text = "KICK"
		LoadPlayer(PlayerID, ServerJobID)
	end)

	Connections["JoinServer"] = PlayerFrame.QuickActions.ActionList.JoinServer.Click.MouseButton1Click:Connect(function()
		PlayerFrame.QuickActions.ActionList.JoinServer.Icon.Desc.Text = "Teleporting..."
		xpcall(function()
			if ServerJobID == 0 then
				PlayerFrame.QuickActions.ActionList.JoinServer.Icon.Desc.Text = "Unavailable"
			end
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, ServerJobID)
		end, function(e)
			PlayerFrame.QuickActions.ActionList.JoinServer.Icon.Desc.Text = "Failed ("..e..")"
		end)
		
		task.delay(5, function()
			PlayerFrame.QuickActions.ActionList.JoinServer.Icon.Desc.Text = "Join server"
		end)
		
	end)

	local function DoBan(ClearWarns)	
		local Shm = Shimmer.new(ClearWarns and PlayerFrame.BanBox.BanClear or PlayerFrame.BanBox.BanKeep)
		Shm:Play()

		--// serialize the duration
		local Sep = string.split(string.lower(PlayerFrame.BanBox.LengthInput.Text), " ")

		if not tonumber(Sep[1]) then
			PlayerFrame.BanBox.LengthInput.Text = "Bad input, try again (according to \"x (time unit)\")"
			Shm:Pause()
			Shm:GetFrame():Destroy()

			return
		end

		local Seconds = ((
				Sep[2] == "seconds" and 1 or 
				Sep[2] == "minutes" and 60 or
				Sep[2] == "hours" and (60 * 60) or
				Sep[2] == "days" and (60 * 60 * 24) or
				Sep[2] == "weeks" and (60 * 60 * 24 * 7) or
				Sep[2] == "months" and (60 * 60 * 24 * 7 * 30) or --// 30 just to be safe
				Sep[2] == "years" and (60 * 60 * 24 * 7 * 30 * 365) or
				Sep[2] == "year" and (60 * 60 * 24 * 7 * 30 * 365) or
				Sep[2] == "month" and (60 * 60 * 24 * 7 * 30) or
				Sep[2] == "week" and (60 * 60 * 24 * 7) or
				Sep[2] == "day" and (60 * 60 * 24) or
				Sep[2] == "hour" and (60 * 60) or
				Sep[2] == "minute" and 60 or
				Sep[2] == "second" and 1 
				or 0
			) * tonumber(Sep[1])
		)

		if Seconds == 0 then
			PlayerFrame.BanBox.LengthInput.Text = "Bad input, please specify a valid duration (second(s), minute(s), day(s), ...)"
			Shm:Pause()
			Shm:GetFrame():Destroy()

			return
		end

		print(Remotes.ServerComm:InvokeServer("BanPlayer", {
			["DidClearWarnings"] = ClearWarns,
			["BanDuration"] = Seconds,
			["PrivateNote"] = PlayerFrame.BanBox.LogMessage.Text or "No reason provided.",
			["BanReason"] = PlayerFrame.BanBox.BanMessage.Text or `Ban reason not provided.\n\nBanned by {game.Players.LocalPlayer.Name} for {FormatTime(Seconds)}.\n\nPowered by Administer.`,
			["TargetID"] = PlayerID,
			["BanDurationString"] = FormatTime(Seconds)
		}))

		Shm:Pause()
		Shm:GetFrame():Destroy(); --// i hate semicolons. i hate semicolons. i hate semicolons.

		(ClearWarns and PlayerFrame.BanBox.BanClear or PlayerFrame.BanBox.BanKeep).Label.Text = "SUCCESS!"

		--// goodbye :saluting_face:
		task.wait(2)
		PlayerFrame.BanBox.Visible = false
		(ClearWarns and PlayerFrame.BanBox.BanClear or PlayerFrame.BanBox.BanKeep).Label.Text = ClearWarns and "BAN & CLEAR WARNINGS" or "BAN (RETAIN RECORDS)"

		LoadPlayer(PlayerID, ServerJobID)
	end

	Connections["BanClearWarns"] = PlayerFrame.BanBox.BanClear.MouseButton1Click:Connect(function()
		DoBan(true)
	end)

	Connections["BanNoClear"] = PlayerFrame.BanBox.BanKeep.MouseButton1Click:Connect(function()
		DoBan(false)
	end)

	if PlayerFull["Main"]["ModRecords"]["ActiveBan"] then
		Stats.Stat_Status.Desc.Text = `Banned for {PlayerFull["Main"]["ModRecords"]["CurrentBanDuration"] / 60 / 24} days`
		PlayerFrame.QuickActions.ActionList.Ban.Icon.Desc.Text = "Unban"
		Connections["BanButton"]:Disconnect()

		Connections["BanButton"] = PlayerFrame.QuickActions.ActionList.Ban.Click.MouseButton1Click:Connect(function()
			PlayerFrame.UnbanBox.Visible = true

			PlayerFrame.UnbanBox.MiscMeta.Text = `@{PlayerBasic["Username"]} • {PlayerID}`
			PlayerFrame.UnbanBox.TopEffect.PlayerImage.Image = PlayerBasic["Photo"]
			PlayerFrame.UnbanBox.Header.Text = `Unban {PlayerBasic["DisplayName"]}`
			PlayerFrame.UnbanBox.HeaderContainer.HeaderLabel.Text = `Unban @{PlayerBasic["Username"]}`

			Connections["BanClose"] = PlayerFrame.BanBox.HeaderContainer.Exit.MouseButton1Click:Connect(function()
				PlayerFrame.BanBox.Visible = false
			end)
		end)

		Connections["Unban"] = PlayerFrame.UnbanBox.Yes.MouseButton1Click:Connect(function()
			local Shm = Shimmer.new(PlayerFrame.UnbanBox.Yes)
			Shm:Play()

			print(Remotes.ServerComm:InvokeServer("UnbanPlayer", {
				["TargetID"] = PlayerID,
			}))

			PlayerFrame.UnbanBox.Yes.Label.Text = "SUCCESS!"

			Shm:Pause()
			Shm:GetFrame():Destroy()

			task.wait(2)
			PlayerFrame.UnbanBox.Visible = false
			PlayerFrame.UnbanBox.Yes.Label.Text = "YES"

			LoadPlayer(PlayerID, ServerJobID)
		end)
	else
		Stats.Stat_Status.Desc.Text = `Not currently banned`
	end

	Connections["WarnButton"] = PlayerFrame.QuickActions.ActionList.WriteWarning.Click.MouseButton1Click:Connect(function()
		PlayerFrame.WarnBox.Visible = true

		PlayerFrame.WarnBox.MiscMeta.Text = `@{PlayerBasic["Username"]} • {PlayerID}`
		PlayerFrame.WarnBox.TopEffect.PlayerImage.Image = PlayerBasic["Photo"]
		PlayerFrame.WarnBox.Header.Text = `Warn {PlayerBasic["DisplayName"]}`
		PlayerFrame.WarnBox.HeaderContainer.HeaderLabel.Text = `Warn @{PlayerBasic["Username"]}`

		Connections["WarnClose"] = PlayerFrame.WarnBox.HeaderContainer.Exit.MouseButton1Click:Connect(function()
			PlayerFrame.WarnBox.Visible = false
		end)
	end)

	Connections["WarnSend"] = PlayerFrame.WarnBox.Send.MouseButton1Click:Connect(function()
		local Shm = Shimmer.new(PlayerFrame.WarnBox.Send)
		Shm:Play()

		print(Remotes.ServerComm:InvokeServer("WarnPlayer", {
			["TargetID"] = PlayerID,
			["Warning"] = PlayerFrame.WarnBox.Warning.Text
		}))

		PlayerFrame.WarnBox.Send.Label.Text = "SUCCESS!"

		Shm:Pause()
		Shm:GetFrame():Destroy()

		task.wait(2)
		PlayerFrame.WarnBox.Visible = false
		PlayerFrame.WarnBox.Send.Label.Text = "DONE"

		LoadPlayer(PlayerID, ServerJobID)
	end)
	
	Connections["NoteButton"] = PlayerFrame.QuickActions.ActionList.SendNote.Click.MouseButton1Click:Connect(function()
		PlayerFrame.SendMessage.Visible = true

		PlayerFrame.SendMessage.MiscMeta.Text = `@{PlayerBasic["Username"]} • {PlayerID}`
		PlayerFrame.SendMessage.TopEffect.PlayerImage.Image = PlayerBasic["Photo"]
		PlayerFrame.SendMessage.Header.Text = `Send note to {PlayerBasic["DisplayName"]}`
		PlayerFrame.SendMessage.HeaderContainer.HeaderLabel.Text = `Writing note to @{PlayerBasic["Username"]}`

		Connections["NoteClose"] = PlayerFrame.SendMessage.HeaderContainer.Exit.MouseButton1Click:Connect(function()
			PlayerFrame.SendMessage.Visible = false
		end)
	end)

	Connections["NoteSend"] = PlayerFrame.SendMessage.Send.MouseButton1Click:Connect(function()
		local Shm = Shimmer.new(PlayerFrame.SendMessage.Send)
		Shm:Play()

		print(Remotes.ServerComm:InvokeServer("SendNote", {
			["TargetID"] = PlayerID,
			["Message"] = PlayerFrame.SendMessage.Message.Text
		}))

		PlayerFrame.SendMessage.Send.Label.Text = "SUCCESS!"

		Shm:Pause()
		Shm:GetFrame():Destroy()

		task.wait(2)
		PlayerFrame.SendMessage.Visible = false
		PlayerFrame.SendMessage.Send.Label.Text = "SEND"

		LoadPlayer(PlayerID, ServerJobID)
	end)
	
	Connections["FunPrompt"] = PlayerFrame.QuickActions.ActionList.MiscCommands.Click.MouseButton1Click:Connect(function()
		PlayerFrame.FunCommands.Visible = true	
	end)
	
	local ChatLogs = Remotes.ServerComm:InvokeServer("RequestChatlogs")
	
	Shimmers.ChatLogs:Pause()
	Shimmers.ChatLogs:GetFrame():Destroy()
end

local function InitServers()
	local Servers = Remotes.ServerComm:InvokeServer("RequestServers")
	local CanClick = true

	for i, Server in Servers do
		--local PlayerData = game:GetService("UserService"):GetUserInfosByUserIdsAsync(Server[2]["P"])

		local Template = script.Parent.ServerDir.Content.Template:Clone()

		Template.Parent = script.Parent.ServerDir.Content
		Template.Name = Server[1]

		Template.RankName.Text = `Server {i}`
		Template.Info.Text = `{FormatTime(Server[2]["CST"] - Server[2]["ST"], true)} uptime · {#Server[2]["P"]} players ({Server[2]["AP"]} in server lifetime) · {Server[2]["CA"]} admins in-game`
		if #Server[2]["P"] >= 6 then
			for m = 1, 6 do
				local PlayerFrame = Template.Members.Template:Clone()
				local PlayerData = CachePlayer(Server[2]["P"][m], false, true)

				PlayerFrame.Parent = Template.Members --// why is this not replicated?????????
				PlayerFrame.Player.Text = `@{PlayerData["Username"]}`
				PlayerFrame.MiscLabel.Text = PlayerData["HasVerifiedBadge"] and utf8.char(0xE000) or ""
				PlayerFrame.PlayerIcon.Image = PlayerData["Photo"]
				PlayerFrame.Visible = true
			end

			local PlayerFrame = Template.Members.Template:Clone()

			PlayerFrame.Parent = Template.Members
			PlayerFrame.Player.Text = `{#Server[2]["P"] - 6} others...`
			PlayerFrame.Visible = true
		else
			for _, m in Server[2]["P"] do
				local PlayerFrame = Template.Members.Template:Clone()
				local PlayerData = CachePlayer(m, false, true)

				PlayerFrame.Parent = Template.Members
				PlayerFrame.Player.Text = `@{PlayerData["Username"]}`
				PlayerFrame.MiscLabel.Text = PlayerData["HasVerifiedBadge"] and utf8.char(0xE000) or ""
				PlayerFrame.PlayerIcon.Image = PlayerData["Photo"]
				PlayerFrame.Visible = true
			end
		end

		Template.Visible = true
		Connections[Server[1]] = Template.Activate.MouseButton1Click:Connect(function()
			if not CanClick then return end

			CanClick = false
			PausePolling = true
			Box.Visible = true

			Box.ServerStats.JobID.Text = `JobID: <b>{Server[1]}</b>`
			Box.ServerStats.CurrentCCU.Text = `Active players: <b>{#Server[2]["P"]}</b>`
			Box.ServerStats.LifetimeAdmins.Text = `Lifetime admins: <b>{Server[2]["AA"]}</b> (currently <b>{Server[2]["CA"]}</b>)`
			Box.ServerStats.LifetimePlayers.Text = `Lifetime players: <b>{Server[2]["AP"]}</b>`
			Box.ServerStats.Uptime.Text = `Total uptime: <b>{FormatTime(Server[2]["CST"] - Server[2]["ST"])}</b>`
			Box.ServerStats.LockedTo.Text = `Open to: <b>{Server[2]["L"] == 1 and "Admins" or Server[2]["L"] == 2 and "Nobody" or "Not locked"}</b>`
			Box.ServerStats.GameVersion.Text = `Game version: <b>{Server[2]["PV"]}</b>`

			Connections["ServerExit"] = Box.ServerStats.ZExit.Click.MouseButton1Click:Connect(function()
				Box.Visible = false
				CanClick = true
				PausePolling = false
			end)

			for i, ch in Box.Members:GetChildren() do
				if ch.Name ~= "Template" and ch:IsA("Frame") then 
					ch:Destroy() 
				end
			end

			for _, ID in Server[2]["P"] do
				local Template = Box.Members.Template:Clone()
				local PlayerInfo = CachePlayer(ID, false, true)
				local ServerPlayerInfo = Remotes.ServerComm:InvokeServer("RequestPlayerJSON", ID)

				Template.PlayerData.Text = `Current session: 0s · {ServerPlayerInfo["Main"]["Joins"] - 1} historical joins`
				Template.Icon.Image = PlayerInfo["Photo"]
				Template.PlrName.Text = `<b>{PlayerInfo.DisplayName}</b> (@{PlayerInfo.Username})`

				Template.Visible = true
				Template.Parent = Box.Members
				Template.Name = PlayerInfo["Id"]

				Connections[`Clickbox-{ID}-{math.random(1,50)}`] = Template.Clickbox.MouseButton1Click:Connect(function()
					CanClick = true
					Box.Visible = false

					LoadPlayer(ID, Server[1])
				end)
			end
		end)
	end
end

script.Parent.PlayerLookup.MainUserDat.Searchbar.Searchbar.TextBox.FocusLost:Connect(function(enter)
	if not enter then return end
	local UserID, TB = nil, script.Parent.PlayerLookup.MainUserDat.Searchbar.Searchbar.TextBox
	
	if tonumber(TB.Text) == nil then
		xpcall(function()
			UserID = game.Players:GetUserIdFromNameAsync(TB.Text)
		end, function()
			print("Attempt to load a player which doesnt exist, ignoring")
			UserID = 0
			return
		end)
	elseif tonumber(TB.Text) ~= nil then
		UserID = tonumber(TB.Text)
	else
		print("Attempt to load a player which doesnt exist, ignoring")
		UserID = 0
		return
	end
	
	if UserID == 0 then
		print("Got kill term, goodbye")
		return
	end
	
	script.Parent.PlayerLookup.Visible = false
	
	LoadPlayer(UserID, 0, script.Parent.Player:GetAttribute("ShouldDelay"))
end)

script.Parent.MenuBar.buttons.AServerDir.TextButton.MouseButton1Click:Connect(function()
	PlayerFrame.ImageLabel.ImageColor3 = Color3.fromRGB(126, 128, 175)
	PlayerFrame.PlayerImage.Image = "rbxassetid://15105863258"
	PlayerFrame.PlayerUN.Text = "Player info has been unloaded to resume server polling. Please reselct or look up the target player."
	PlayerFrame.PlayerDN.Text = "Nobody"

	for i, conn in Connections do conn:Disconnect() end --// idk why it wasnt happen before but ? 
	Connections = {}

	PausePolling = false
	
	--// force an update
	
	for i, ch in script.Parent.ServerDir.Content:GetChildren() do
		if ch.Name ~= "Template" and ch:IsA("Frame") then ch:Destroy() end
	end

	task.spawn(InitServers)
end)

task.spawn(InitServers)

while task.wait(PollInterval) do
	if PausePolling then continue end

	for i, ch in script.Parent.ServerDir.Content:GetChildren() do
		if ch.Name ~= "Template" and ch:IsA("Frame") then ch:Destroy() end
	end

	for i, conn in Connections do conn:Disconnect() end
	Connections = {}

	task.spawn(InitServers)
end