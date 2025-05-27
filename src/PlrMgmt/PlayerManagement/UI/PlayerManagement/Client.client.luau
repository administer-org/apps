--// pyxfluff 2024 - 2025

local AdmRemotes = game.ReplicatedStorage:WaitForChild("Administer")
local Remotes    = AdmRemotes:WaitForChild("Apps"):WaitForChild("PlayerManagement")

local PausePolling = false
local PollInterval = 20
local IsVerbose    = false
local Connections  = {}
local PlayerCache  = {}

local MainFrame = script.Parent

local ServerDir = script.Parent.ServerDir
local Box = ServerDir.ServerLookup
local PlayerFrame = MainFrame.Player 

local AdministerClient = game.Players.LocalPlayer.PlayerGui:FindFirstChild("AdministerMainPanel", true).Client

local Shimmer   = require(AdministerClient.Libraries.Shime)
local AdmAppAPI = require(AdministerClient.Modules.Apps)
local Utilities = require(AdministerClient.Modules.Utilities)
local Frontend  = require(AdministerClient.Modules.Frontend)

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

local function CachePlayer(
	Id,
	Verbose,
	ReturnPlaceholderOnFail
): any
	Verbose = IsVerbose

	if typeof(Id) ~= "table" then
		Id = { tonumber(Id) }
	else
		for I = 1, #Id do
			Id[I] = tonumber(Id[I])
		end
	end

	local Result = {}
	local ToFetch = {}

	for I = 1, #Id do
		local Cached = PlayerCache[Id[I]]
		if Cached then
			if Verbose then print("Found", Id[I], "from local cache!") end
			Result[Id[I]] = Cached
		else
			ToFetch[#ToFetch + 1] = Id[I]
		end
	end

	local Current = 1
	local Final = {
		{ }
	}

	for I = 1, #ToFetch do
		local UID = ToFetch[I]
		if #Final[Current] >= 100 then
			Current += 1
			Final[Current] = {}
		end

		Final[Current][#Final[Current] + 1] = UID
	end

	for I = 1, #Final do
		local Batch = Final[I]

		while true do
			local Success, Response = pcall(function()
				return game:GetService("UserService"):GetUserInfosByUserIdsAsync(Batch)
			end)

			if not Success then
				if Verbose then print("UserService request failed:", Response) end

				local Lower = string.lower(Response)
				for J = 1, #Batch do
					local UID = Batch[J]

					if string.find(Lower, "invalid userid") then
						Result[UID] = {
							Id = UID,
							DisplayName = `Banned user {UID}`,
							Username = "This user appears to have been banned.",
							HasVerifiedBadge = false,
							Photo = game.Players:GetUserThumbnailAsync(UID, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
						}
					elseif ReturnPlaceholderOnFail then
						Result[UID] = {
							Id = UID,
							DisplayName = `Loading failed ({UID})`,
							Username = "Roblox ratelimit reached",
							HasVerifiedBadge = false,
							Photo = "rbxassetid://84027648824846"
						}
					end
				end

				if not ReturnPlaceholderOnFail then
					task.wait(2)
					continue
				end

				break
			end

			for J = 1, #Response do
				local Info = Response[J]
				local UID = Info.Id

				Info.Photo = game.Players:GetUserThumbnailAsync(UID, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)

				PlayerCache[UID] = Info
				Result[UID] = Info
			end

			break
		end
	end

	if Verbose then
		local Total = 0
		for _, entry in PlayerCache do --// idk why # isnt working right
			Total += 1
		end
		print(`Completed! The cache is now {Total} items big.`)
	end

	return #Id == 1 and Result[Id[1]] or Result
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

	PausePolling = true

	for i, c in PlayerFrame.Logs.ActionList:GetChildren() do
		if c:IsA("Frame") and c.Name ~= "Log" then
			c:Destroy() 
		end
	end

	PlayerFrame.ImageLabel.ImageColor3 = Color3.fromRGB(25, 25, 34)
	PlayerFrame.PlayerImage.Image = "rbxassetid://15105863258"
	PlayerFrame.PlayerDN.Text = "Loading player info..."
	PlayerFrame.PlayerUN.Text = ""

	local Shimmers = {}
	Connections = {}

	for i, Frame in {PlayerFrame.PlayerImage, PlayerFrame.Logs, PlayerFrame.PlayerUN, PlayerFrame.PlayerDN, PlayerFrame.Stats} do
		Shimmers[Frame.Name] = Shimmer.new(Frame)

		Shimmers[Frame.Name]:Play()
	end

	task.defer(function()
		Frontend.SwapApps(PlayerFrame)
	end)

	if Delay then
		task.wait(2)
	end

	local PlayerBasic = CachePlayer(PlayerID, false, false)
	local PlayerFull = Remotes.ServerComm:InvokeServer("RequestPlayerJSON", PlayerID)

	task.defer(function()
		local PromColor = game.ReplicatedStorage.Administer.GetProminentColorFromUserID:InvokeServer(PlayerID)
		PlayerFrame.ImageLabel.ImageColor3 = Color3.fromRGB(PromColor[1], PromColor[2], PromColor[3])
	end)

	PlayerFrame.PlayerDN.Text = PlayerBasic.DisplayName
	PlayerFrame.PlayerUN.Text = `@{PlayerBasic.Username}`
	PlayerFrame.PlayerImage.Image = PlayerBasic.Photo

	pcall(function()
		if PlayerFull.Main.IsActive then
			PlayerFrame.PlayStatus.Orb.BackgroundColor3 = Color3.fromRGB(20, 255, 114)
			PlayerFrame.PlayStatus.Text = `Playing for {FormatTime(AdmRemotes.GetSystemClock:InvokeServer() - PlayerFull["Main"]["LastSeen"])}`
		else
			PlayerFrame.PlayStatus.Orb.BackgroundColor3 = Color3.fromRGB(30, 32, 36)
			PlayerFrame.PlayStatus.Text = `Offline`
		end
	end)

	local Stats = PlayerFrame.Stats.ActionList

	print(PlayerFull)

	if PlayerFull.Main.Inactive then
		Stats.FirstSeen.Desc.Text = "Never"
		Stats.LastSeen.Desc.Text = "Never"
		Stats.PlayTime.Desc.Text = "0s"
		Stats.Plays.Desc.Text = "0"

		Stats.IsAdmin.Desc.Text = PlayerFull.Admin.RankName
		Stats.UserID.Desc.Text = PlayerID

		Stats.ServerID.Desc.Text = "Offline"

		Stats.Region.Desc.Text = "UNKWN"

		Stats.Warnings.Desc.Text = `<font color="{PlayerFull.Main.ModRecords._Warnings >= 2 and "rgb(187, 189, 49)" or "rgb(176, 176, 176)"}">{PlayerFull.Main.ModRecords._Warnings} Warnings</font>`
		Stats.Warnings.Icon.ImageColor3 = (PlayerFull.Main.ModRecords._Warnings >= 2 and Color3.fromRGB(187,189,49) or Color3.new(1,1,1))
	else
		Stats.FirstSeen.Desc.Text = Utilities.FormatRelativeTime(PlayerFull.Main.FirstSeen)
		Stats.LastSeen.Desc.Text = PlayerFull.Main.IsActive and "<font color=\"rgb(0,255,0)\">now</font>" or Utilities.FormatRelativeTime(PlayerFull.Main.LastSeen)
		Stats.PlayTime.Desc.Text = FormatTime(PlayerFull.Main.PlayTime)
		Stats.Plays.Desc.Text = PlayerFull.Main.Joins

		xpcall(function()
			Stats.Region.Desc.Text = PlayerFull.Main.RegionSerialized
		end, function()
			Stats.Region.Desc.Text = "UNKWN"
		end)

		Stats.IsAdmin.Desc.Text = PlayerFull.Admin.RankName
		Stats.UserID.Desc.Text = PlayerID

		if ServerJobID ~= nil then
			Stats.ServerID.Desc.Text = ServerJobID
		else
			Stats.ServerID.Desc.Text = "Offline"
		end


		Stats.Warnings.Desc.Text = `<font color="{PlayerFull.Main.ModRecords._Warnings >= 2 and "rgb(187, 189, 49)" or "rgb(176, 176, 176)"}">{PlayerFull.Main.ModRecords._Warnings} Warnings</font>`
		Stats.Warnings.Icon.ImageColor3 = (PlayerFull.Main.ModRecords._Warnings >= 2 and Color3.fromRGB(187,189,49) or Color3.new(1,1,1))
	end
	
	local IsOnline = PlayerFull.Main.Inactive or not PlayerFull.Main.IsActive 

	for _, Data in PlayerFull.Main.ModRecords.Actions do
		local Action = PlayerFrame.Logs.ActionList.Log:Clone()
		local ModData = CachePlayer(Data.Moderator, false, false)

		Action.Parent = PlayerFrame.Logs.ActionList
		Action.Visible = true
		Action.Name = game:GetService("HttpService"):GenerateGUID(false)

		Action.ActionLabel.Text = `<b>@{ModData.Username}</b> {Data._Type == "BAN" and `created a ban for {FormatTime(Data.Duration, true)}` or
			Data._Type == "WARN"       and   "created an active warning" or
			Data._Type == "NOTE"       and   "sent a note privately" or
			Data._Type == "LOGS_CLEAR" and   "cleared their logs" or
			Data._Type == "KICK"       and   "kicked them out of the game server" or
			Data._Type == "TELEPORT"   and   "moved them to another game" or
			Data._Type == "UNBAN"      and   "unbanned them early" or
			"... did something that confused your client"
		}`
		Action.Note.Text = 
			Data._Type == "BAN"        and   `{Data.Reason} ({Data.PrivNote}).` or
			Data._Type == "WARN"       and    Data.Warning or
			Data._Type == "NOTE"       and    Data.Message or
			Data._Type == "LOGS_CLEAR" and   `All logs and statistics may have been reset.` or
			Data._Type == "KICK"       and   `{Data.Reason} ({Data.PrivNote}).` or
			Data._Type == "TELEPORT"   and   `Sent to {Data.PlaceID}. {Data.Reason}` or
			Data._Type == "UNBAN"      and    Data.PrivNote or
			`Failed (_Type ({Data._Type} is unknown, unfinished feature)`
		Action.Icon.Image = 
			Data._Type == "BAN"        and   "rbxassetid://11284736452" or
			Data._Type == "WARN"       and   "rbxassetid://17402667535" or
			Data._Type == "NOTE"       and   "0" or
			Data._Type == "LOGS_CLEAR" and   "0" or
			Data._Type == "KICK"       and   "rbxassetid://138303173193406" or
			Data._Type == "TELEPORT"   and   "rbxassetid://84037313964620" or
			"http://www.roblox.com/asset/?id=15105963940"
		Action.Player.Image = ModData.Photo
	end

	for _, Log in PlayerFull.Main.AuditableActions do
		local Action = PlayerFrame.Logs.ActionList.Log:Clone()

		Action.Parent = PlayerFrame.Logs.ActionList
		Action.Visible = true
		Action.Name = game:GetService("HttpService"):GenerateGUID(false)

		Action.ActionLabel.Text = `Auditable action from app {Log.App.Name}:`
		Action.Note.Text = Log.Action

		Action.Icon.Image = `rbxassetid://{Log.Icon}`
		Action.Player.Image = `rbxassetid://{Log.App.Icon}`
	end

	for _, Obj in {"PlayerImage", "PlayerUN", "PlayerDN", "Stats", "Logs"} do
		Shimmers[Obj]:Pause()
		Shimmers[Obj]:GetFrame():Destroy()
	end
	
	local function NotAvailableBox(IsOffline: boolean)
		Frontend.Popup.new(
			{
				Name = "Player Management",
				Icon = Utilities.Icon "users",
			},
			{
				Primary = PlayerBasic.Photo,
				SubIcon = Utilities.Icon "x"
			},

			`Feature unavailable`,
			IsOffline and "This feature does not allow targets to be offline or in restricted servers."
				or "You cannot make moderation actions against yourself. If you are simply testing then please load an alt account.",

			{
				{
					Text = "OK",
					Icon = Utilities.Icon "check-plain",
					Callback = function(Close)
						Close()
					end
				}
			}
		)
	end

	if PlayerBasic.Id == game.Players.LocalPlayer.UserId then
		for _, Button in PlayerFrame.QuickActions.ActionList:GetChildren() do
			if not Button:IsA("Frame") or Button.Name == "Fun" then continue end

			table.insert(Connections, Button.Click.MouseButton1Click:Connect(function()
				NotAvailableBox(false)
				
				return
			end))
		end

		return
	end

	Connections["KickButton"] = PlayerFrame.QuickActions.ActionList.Kick.Click.MouseButton1Click:Connect(function()
		if not IsOnline then
			NotAvailableBox(true)	
		end
		
		Frontend.Popup.new(
			{
				Name = "Player Management",
				Icon = Utilities.Icon "users",
			},
			{
				Primary = PlayerBasic.Photo,
				SubIcon = Utilities.Icon "user-exit"
			},

			`Kick @{PlayerBasic.Username}`,
			"Kicking removes somebody from the current server while retaining the ability to join instantly.",
			{
				{
					Text = "Yes",
					Icon = Utilities.Icon "check-plain",
					Callback = function(Close, Text)
						print(Remotes.ServerComm:InvokeServer("KickPlayer", {
							["PrivateNote"] = Text[2],
							["KickMsg"] = Text[1],
							["TargetID"] = PlayerID,
						}))

						Close()
						LoadPlayer(PlayerID, ServerJobID)
					end
				},
				{
					Text = "No",
					Icon = Utilities.Icon "x",
					Callback = function(Close)
						Close()
					end
				}
			},
			{
				{
					HeaderText = "Kick message"
				},
				{
					HeaderText = "Audit log reason"
				}
			}
		)
	end)

	if ServerJobID == 0 or ServerJobID == nil then
		PlayerFrame.QuickActions.ActionList.TeleporterNudge.Desc.Text = "Unavailable"

	else
		PlayerFrame.QuickActions.ActionList.TeleporterNudge.Desc.Text = "Join server..."
	end

	Connections["JoinServer"] = PlayerFrame.QuickActions.ActionList.TeleporterNudge.Click.MouseButton1Click:Connect(function()
		if (
			ServerJobID == 0 or 
				ServerJobID == nil or
				string.find(ServerJobID:lower(), "studio") ~= nil
			) then

			NotAvailableBox(true)

			return
		end

		Frontend.Popup.new(
			{
				Name = "Player Management",
				Icon = Utilities.Icon "users",
			},
			{
				Primary = PlayerBasic.Photo,
				SubIcon = Utilities.Icon "route"
			},

			`Join @{PlayerBasic.Username}`,
			`Are you sure you would like to teleport to {PlayerBasic.DisplayName}? You will instantly join their server.`,
			{
				{
					Text = "Yes",
					Icon = Utilities.Icon "check-plain",
					Callback = function(Close, Text)
						xpcall(function()
							game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, ServerJobID)
						end, function(e)
							Utilities.Logging.Warn(e)
						end)

						Close()
						LoadPlayer(PlayerID, ServerJobID)
					end
				},
				{
					Text = "Cancel",
					Icon = Utilities.Icon "x",
					Callback = function(Close)
						Close()
					end
				}
			}
		)
	end)

	local function DoBan(ClearWarns)	
		local Shm = Shimmer.new(ClearWarns and PlayerFrame.Prompts.BanBox.BanClear or PlayerFrame.Prompts.BanBox.BanKeep)
		Shm:Play()

		--// serialize the duration
		local Sep = string.split(string.lower(PlayerFrame.Prompts.BanBox.LengthInput.Text), " ")

		if not tonumber(Sep[1]) then
			PlayerFrame.Prompts.BanBox.LengthInput.Text = "Bad input, try again (according to \"x (time unit)\")"
			Shm:Pause()
			Shm:GetFrame():Destroy()

			return
		end

		local Seconds = (({
			["second"] = 1, ["seconds"] = 1,
			["minute"] = 60, ["minutes"] = 60,
			["hour"] = 3600, ["hours"] = 3600,
			["day"] = 86400, ["days"] = 86400,
			["week"] = 604800, ["weeks"] = 604800,
			["month"] = 18144000, ["months"] = 18144000,
			["year"] = 31556952, ["years"] = 31556952
		})[Sep[2]] or 0) * tonumber(Sep[1])

		if Seconds == 0 then
			PlayerFrame.Prompts.BanBox.LengthInput.Text = "Bad input, please specify a valid duration (second(s), minute(s), day(s), ...)"
			Shm:Pause()
			Shm:GetFrame():Destroy()

			return
		end

		print(Remotes.ServerComm:InvokeServer("BanPlayer", {
			["DidClearWarnings"] = ClearWarns,
			["BanDuration"] = Seconds,
			["PrivateNote"] = PlayerFrame.Prompts.BanBox.LogMessage.Text or "No reason provided.",
			["BanReason"] = PlayerFrame.Prompts.BanBox.BanMessage.Text or `Ban reason not provided.\n\nBanned by {game.Players.LocalPlayer.Name} for {FormatTime(Seconds)}.\n\nPowered by Administer.`,
			["TargetID"] = PlayerID,
			["BanDurationString"] = FormatTime(Seconds)
		}))

		Shm:Pause()
		Shm:GetFrame():Destroy(); --// i hate semicolons. i hate semicolons. i hate semicolons. i ha

		(ClearWarns and PlayerFrame.Prompts.BanBox.BanClear or PlayerFrame.Prompts.BanBox.BanKeep).Label.Text = "SUCCESS!"

		--// goodbye :saluting_face:
		task.wait(2)
		PlayerFrame.Prompts.BanBox.Visible = false
		(ClearWarns and PlayerFrame.Prompts.BanBox.BanClear or PlayerFrame.Prompts.BanBox.BanKeep).Label.Text = ClearWarns and "BAN & CLEAR WARNINGS" or "BAN (RETAIN RECORDS)"

		LoadPlayer(PlayerID, ServerJobID)
	end

	if PlayerFull.Main.ModRecords.ActiveBan then
		Stats.BanStatus.Desc.Text = `Suspended for {PlayerFull["Main"]["ModRecords"]["CurrentBanDuration"] / 60 / 24} days`
		PlayerFrame.QuickActions.ActionList.Ban.Desc.Text = "Unban"

		Connections["UnbanButton"] = PlayerFrame.QuickActions.ActionList.Ban.Click.MouseButton1Click:Connect(function()
			Frontend.Popup.new(
				{
					Name = "Player Management",
					Icon = Utilities.Icon "users",
				},
				{
					Primary = PlayerBasic.Photo,
					SubIcon = Utilities.Icon "warning-triangle"
				},

				`Unban @{PlayerBasic.Username}`,
				"Are you sure you would like to end this players ban early? They will be able to join the game normally again.",
				{
					{
						Text = "Yes",
						Icon = Utilities.Icon "warning-filled",
						Callback = function(Close, Text)
							print(Remotes.ServerComm:InvokeServer("UnbanPlayer", {
								TargetID = PlayerID,
								AuditLogMessage = Text[1] 
							}))

							Close()
							LoadPlayer(PlayerID, ServerJobID)
						end
					},
					{
						Text = "No",
						Icon = Utilities.Icon "x",
						Callback = function(Close)
							Close()
						end
					}
				},
				{
					{
						HeaderText = "Reason"
					}
				}
			)
		end)
	else
		Stats.BanStatus.Desc.Text = `Not suspended`
		PlayerFrame.QuickActions.ActionList.Ban.Desc.Text = "Issue ban.."

		Connections["BanButton"] = PlayerFrame.QuickActions.ActionList.Ban.Click.MouseButton1Click:Connect(function()
			PlayerFrame.Prompts.BanBox.Visible = true

			PlayerFrame.Prompts.BanBox.MiscMeta.Text = `@{PlayerBasic["Username"]} • {PlayerID}`
			PlayerFrame.Prompts.BanBox.TopEffect.PlayerImage.Image = PlayerBasic["Photo"]
			PlayerFrame.Prompts.BanBox.Header.Text = `Ban {PlayerBasic["DisplayName"]}`
			PlayerFrame.Prompts.BanBox.HeaderContainer.HeaderLabel.Text = `Ban @{PlayerBasic["Username"]}`

			Connections["BanClose"] = PlayerFrame.Prompts.BanBox.HeaderContainer.Exit.MouseButton1Click:Connect(function()
				PlayerFrame.Prompts.BanBox.Visible = false
			end)
		end)

		Connections["BanClearWarns"] = PlayerFrame.Prompts.BanBox.BanClear.MouseButton1Click:Connect(function()
			DoBan(true)
		end)

		Connections["BanKeepWarns"] = PlayerFrame.Prompts.BanBox.BanKeep.MouseButton1Click:Connect(function()
			DoBan(false)
		end)
	end

	Connections["Warn"] = PlayerFrame.QuickActions.ActionList.Warn.Click.MouseButton1Click:Connect(function() 
		Frontend.Popup.new(
			{
				Name = "Player Management",
				Subheader = "Create warning",
				Icon = Utilities.Icon "users"
			},
			{
				Primary = PlayerBasic.Photo,
				SubIcon = Utilities.Icon "warning-filled"
			},

			`Warn @{PlayerBasic.Username}?`,
			"Are you sure you would like to file a warning for this player?",
			{
				{
					Text = "Yes",
					Icon = Utilities.Icon "warning-filled",
					Callback = function(Close, Text)
						print(Remotes.ServerComm:InvokeServer("WarnPlayer", {
							TargetID = PlayerID,
							Warning = Text[1]
						}))

						Close()
						LoadPlayer(PlayerID, ServerJobID)
					end
				},
				{
					Text = "No",
					Icon = Utilities.Icon "x",
					Callback = function(Close)
						Close()
					end
				}
			},
			{
				{
					HeaderText = "Warning Text"
				},
				{
					HeaderText = "Log Reason"
				}
			}
		) 
	end)

	Connections["NoteButton"] = PlayerFrame.QuickActions.ActionList.SendNote.Click.MouseButton1Click:Connect(function()
		if not IsOnline then
			NotAvailableBox(true)	
		end
		
		Frontend.Popup.new(
			{
				Name = "Player Management",
				Subheader = "Send note",
				Icon = Utilities.Icon "users"
			},
			{
				Primary = PlayerBasic.Photo,
				SubIcon = Utilities.Icon "megaphone"
			},

			`Send note to @{PlayerBasic.Username}`,
			"They will be privately notified with a fullscreen message.",
			{
				{
					Text = "Send",
					Icon = Utilities.Icon "check-plain",
					Callback = function(Close, Text)
						if Text[2] ~= "" and not table.find({"y", "n", "yes", "no"}, string.lower(Text[2])) then
							Close()

							Frontend.Popup.new(
								{
									Name = "Player Management",
									Subheader = "Send note",
									Icon = Utilities.Icon "users"
								},
								{
									Primary = Utilities.Icon "megaphone",
									SubIcon = Utilities.Icon "x"
								},

								"Unexpected value",
								'"Allow replying" must be y/n.',
								{
									{
										Text = "OK",
										Icon = Utilities.Icon "check-plain",
										Callback = function(Close)
											Close()
										end
									}
								}
							) 

							return
						end

						print(Remotes.ServerComm:InvokeServer("SendNote", {
							TargetID = PlayerID,
							Message = Text[1],
							UseInput = string.lower(Text[2]) == "y" or string.lower(Text[2]) == "yes" 
						}))

						Close()
						LoadPlayer(PlayerID, ServerJobID)
					end
				},
				{
					Text = "Cancel",
					Icon = Utilities.Icon "x",
					Callback = function(Close)
						Close()
					end
				}
			},
			{
				{
					HeaderText = "Message"
				},
				{
					HeaderText = "Allow replying? (y/n)"
				}
			}
		) 
	end)

	--// DO NOT PUT ANYTHING DOWN HERE
end

local function InitServers(PopulateFakeServers)
	local Servers = Remotes.ServerComm:InvokeServer("RequestServers")
	local CanClick = true

	if PopulateFakeServers ~= nil then
		Servers = {}

		for i = 1, PopulateFakeServers do
			local FakeData = {
				CST = os.time(),
				ST = os.time() - math.random(60, 14000),
				AP = 0,
				P = {}
			}

			for i = 1, math.random(4, 50) do
				FakeData.AP += 1
				table.insert(FakeData.P, math.random(1, 2^30) + math.random(1, 2^30))
			end

			table.insert(Servers, {
				game:GetService("HttpService"):GenerateGUID(false),
				FakeData
			})
		end
	end

	for i, Server in Servers do
		local Template = ServerDir.Content.Template:Clone()

		Template.Name = Server[1]

		Template.RankName.Text = `Server {i}`
		Template.Info.Text = `{FormatTime(Server[2]["CST"] - Server[2]["ST"], true)} uptime · {#Server[2]["P"]} CCU · {Server[2]["AP"]} visits`

		for _, Child in Template.ProfilePictures:GetChildren() do
			if Child:IsA("ImageLabel") then Child.Visible = false end
		end

		for i, Player in Server[2]["P"] do
			local PlayerData = CachePlayer(Player, false, true)

			pcall(function()
				if Template.ProfilePictures[i] == nil or PlayerData == {} then return end

				local CorrespondingIcon = Template.ProfilePictures[i]

				CorrespondingIcon.Image = PlayerData["Photo"]
				CorrespondingIcon.Visible = true
			end)
		end

		Template.Parent = ServerDir.Content
		Template.Visible = true

		Connections[Server[1]] = Template.Activate.MouseButton1Click:Connect(function()
			if not CanClick then return end

			local Admins = 0
			local ShimmerAnim = Shimmer.new(Template)
			ShimmerAnim:Play()

			CanClick = false
			PausePolling = true

			Box.Position = UDim2.new(.35,0,0,0)
			--Box.Size = UDim2.new(.475, 0, .775, 0)
			Box.GroupTransparency = 1

			Box.GameDataHolder.GameData.Text = `Job ID: <b>{Server[1]}</b> • {FormatTime(Server[2]["CST"] - Server[2]["ST"])} uptime • version {Server[2]["PV"]}`

			task.defer(function()
				--// do slower processes here
				Box.GameDataHolder.GameName.Text = `<b>{game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name}</b> • Server {i}`
				Box.GameDataHolder.Thumb.Image = AdmRemotes.GetGameMedia:InvokeServer()
				Box.ServerStats.Region.Desc.Text = AdmRemotes.GetServerRegion:InvokeServer()
			end)

			Box.ServerStats.CurrentUsers.Desc.Text = #Server[2]["P"]
			Box.ServerStats.Visits.Desc.Text = Server[2]["AP"]
			Box.ServerStats.LockedTo.Desc.Text = Server[2]["L"] == "1" and "Admins" or Server[2]["L"] == "2" and "Nobody" or "Everybody"

			Connections["ServerExit"] = Box.GameDataHolder.Close.MouseButton1Click:Connect(function()
				game:GetService("TweenService"):Create(Box, TweenInfo.new(.65, Enum.EasingStyle.Quart), {
					Position = UDim2.new(.35, 0, 0, 0),
					--Size = UDim2.new(.475, 0, .775, 0),
					GroupTransparency = 1
				}):Play()

				CanClick = true
				PausePolling = false

				for _, Connection in Connections do
					Connection:Disconnect()
				end

				task.delay(.65, function()
					Box.Visible = false
				end)
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

				Template.PlayerData.Text = `Current session: {FormatTime(AdmRemotes.GetSystemClock:InvokeServer() - ServerPlayerInfo["Main"]["LastSeen"])}\n{ServerPlayerInfo["Main"]["Joins"]} visits`
				Template.Icon.Image = PlayerInfo["Photo"]
				Template.PlrName.Text = `@{PlayerInfo.Username}`
				Template.PlrDisplayName.Text = PlayerInfo.DisplayName

				Template.AdminShield.Visible = ServerPlayerInfo.Admin.IsAdmin

				Template.Visible = true
				Template.Parent = Box.Members
				Template.Name = PlayerInfo["Id"]

				Connections[`Clickbox-{ID}-{math.random(1,50)}`] = Template.Clickbox.MouseButton1Click:Connect(function()
					CanClick = true

					game:GetService("TweenService"):Create(Box, TweenInfo.new(.65, Enum.EasingStyle.Quart), {
						Position = UDim2.new(.35, 0, 0, 0),
						--Size = UDim2.new(.475, 0, .775, 0),
						GroupTransparency = 1
					}):Play()

					LoadPlayer(ID, Server[1])
				end)

				if ServerPlayerInfo.Admin.IsAdmin then
					Admins += 1
				end
			end

			Box.ServerStats.CurrentAdmins.Desc.Text = Admins
			Box.GameDataHolder.Controls.Join.MouseButton1Click:Connect(function()
				if Server[1] == 0 or string.find(Server[1]:lower(), "studio") ~= nil then
					Frontend.Popup.new(
						{
							Name = "Player Management",
							Icon = Utilities.Icon "users",
							Subheader = "Teleport Unavailable"
						},
						{
							Primary = Utilities.Icon "route",
							SubIcon = Utilities.Icon "no-entry"
						},
						`This feature isn't available`,
						Server[1] == 0 and `This player cannot be teleported to because they are in a reserved server.` or "This player cannot be teleported to because they are in Studio.",
						{
							{
								Text = "OK",
								Icon = Utilities.Icon "check-plain",
								Callback = function(Close, Text)
									Close()
								end
							}
						}
					)

					return
				end

				Frontend.Popup.new(
					{
						Name = "Player Management",
						Icon = Utilities.Icon "users",
					},
					{
						Primary = AdmRemotes.GetGameArt:InvokeServer(),
						SubIcon = Utilities.Icon "route"
					},

					`Join Server`,
					`Are you sure you would like to join {Server[1]}?`,

					{
						{
							Text = "Yes",
							Icon = Utilities.Icon "check-plain",
							Callback = function(Close, Text)
								xpcall(function()
									game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, Server[1])
								end, function(e)
									Utilities.Logging.Warn(e)
								end)

								Close()
							end
						},
						{
							Text = "Cancel",
							Icon = Utilities.Icon "x",
							Callback = function(Close)
								Close()
							end
						}
					}
				)
			end)

			Box.GameDataHolder.Controls.ShutDown.MouseButton1Click:Connect(function()
				Frontend.Popup.new(
					{
						Name = "Player Management",
						Icon = Utilities.Icon "users",
					},
					{
						Primary = AdmRemotes.GetGameArt:InvokeServer(),
						SubIcon = Utilities.Icon "x"
					},

					`Shutdown server`,
					`Are you sure you would like to shutdown this game instance?`,

					{
						{
							Text = "Yes",
							Icon = Utilities.Icon "check-plain",
							Callback = function(Close, Text)
								print(Remotes.ServerComm:InvokeServer("ShutdownServer", {
									JobID = Server[1],
									PubReason = Text[1],
									PrivReason = Text[2]
								}))

								Close()
							end
						},
						{
							Text = "Cancel",
							Icon = Utilities.Icon "x",
							Callback = function(Close)
								Close()
							end
						}
					},
					{
						{
							HeaderText = "Reason"
						},
						{
							HeaderText = "Log reason"
						}
					}
				)
			end)

			Box.GameDataHolder.Controls.Lock.MouseButton1Click:Connect(function()
				Frontend.Popup.new(
					{
						Name = "Player Management",
						Icon = Utilities.Icon "users",
						Subheader = "Lock server"
					},
					{
						Primary = AdmRemotes.GetGameArt:InvokeServer(),
						SubIcon = Utilities.Icon "house-key"
					},

					`Change Server Access Level`,
					`To make a server inaccessible, use level <b>2</b>. To make a server accessible to admins, use <b>1</b>. To allow everybody to join, use <b>0</b>.`,

					{
						{
							Text = "Yes",
							Icon = Utilities.Icon "check-plain",
							Callback = function(Close, Text)
								print(Remotes.ServerComm:InvokeServer("LockServer", {
									JobID = Server[1],
									AccessLevel = Text[1],
									PubReason = Text[2],
									PrivReason = "N/A"
								}))

								Close()
							end
						},
						{
							Text = "Cancel",
							Icon = Utilities.Icon "x",
							Callback = function(Close)
								Close()
							end
						}
					},
					{
						{
							HeaderText = "Security level"
						},
						{
							HeaderText = "Message to display"
						}
					}
				)
			end)

			Box.Visible = true
			game:GetService("TweenService"):Create(Box, TweenInfo.new(.65, Enum.EasingStyle.Quart), {
				Position = UDim2.new(.316, 0, 0, 0),
				--Size = UDim2.new(.675, 0, .974, 0),
				GroupTransparency = 0
			}):Play()

			ShimmerAnim:Pause()
			ShimmerAnim:GetFrame():Destroy()
		end)
	end
end

AdmAppAPI.AddAppDrawerButton({
	AppName = "Player Management",
	Description = "Manage every player in your game from one place.",
	Icon = Utilities.Icon "users",
	ButtonID = "PlayerManagement",

	SubIcons = {
		{
			Name = "Directory",
			Icon = Utilities.Icon "network",
			Frame = ServerDir,
			Click = function()
				for i, conn in Connections do conn:Disconnect() end --// idk why it wasnt happen before but ? 

				PausePolling = false

				--// force an update
				for i, ch in ServerDir.Content:GetChildren() do
					if ch.Name ~= "Template" and ch:IsA("Frame") then ch:Destroy() end
				end

				task.defer(InitServers)
			end,
			ButtonID = "PlrDirectory"
		},
		{
			Name = "Bulk Moderate",
			Icon = Utilities.Icon "no-entry",
			Frame = script.Parent.Ban,
			ButtonID = "BulkModerate"
		},
		{
			Name = "Search",
			Icon = Utilities.Icon "user-search",
			Frame = script.Parent.PlayerLookup,
			ButtonID = "PlayerSearch"
		}
	}
})

task.defer(InitServers)

local SearchEvents = {}
local SearchFrame = script.Parent.PlayerLookup

local function IsExtendedTable(Table)
	for _, Child in Table do
		if type(Child) == "table" then
			return true
		else
			return false
		end
	end
end

--// Player Search functionality
local function UserSearchItem(
	UserID:      number,
	SearchQuery: string,
	SkipChecks:  boolean,
	ServerID:    string?
): ()
	if UserID == "InfoTip" then
		local Card = SearchFrame.Results.Template:Clone()

		Card.Name = "TipFrame"
		Card.Visible = true

		Card.User.Text = "Information"
		Card.Info.Text = SearchQuery
		Card.ProfilePicture.Image = Utilities.Icon "question-circle"

		Card.Parent = SearchFrame.Results

		return
	end

	if #UserID >= 100 then
		UserSearchItem("InfoTip", `Loading {#UserID} players... this will take a while! For a quicker result please narrow your search query down or use a user ID for direct searches.`)
	end

	local User = CachePlayer(UserID, false, false)
	local Sanitized = {}

	if SkipChecks ~= true or SearchQuery == "" then
		local function Check(User)
			xpcall(function()
				if string.find(string.lower(User.DisplayName), SearchQuery) then
					User.IndexedFrom = "DisplayName"
				end
			end, function()
				UserSearchItem("InfoTip", "No results found.")
				User.IndexedFrom = "NoResults"
			end)

			if User.IndexedFrom == "NoResults" then return false end

			if string.find(string.lower(User.Username), SearchQuery) then
				User.IndexedFrom = "Username"
			end

			if tonumber(SearchQuery) ~= nil and string.find(tostring(UserID), SearchQuery) then
				User.IndexedFrom = "UserID"
			end

			if User.IndexedFrom == nil then
				return false
			else
				return true
			end
		end

		if IsExtendedTable(User) then
			for i, Player in User do
				if Check(Player) then
					Sanitized[i] = Player
				end
			end
		else
			Check(User)
		end
	end

	local function Card(User)
		local Card = SearchFrame.Results.Template:Clone()

		Card.Name = User.Id
		Card.Visible = true

		Card.User.Text = User.DisplayName
		Card.Info.Text = `@{User.Username} · {User.Id} · Found from {User.IndexedFrom}`
		Card.ProfilePicture.Image = User.Photo

		SearchEvents[User.Id] = Card.Activate.MouseButton1Click:Connect(function()
			LoadPlayer(User.Id, ServerID, false)
		end)

		Card.Parent = SearchFrame.Results
	end

	if IsExtendedTable(User) then
		for _, User in Sanitized do
			Card(User)
		end
	else
		Card(User)
	end
end

SearchFrame.FromWhere.Searchbar.Input.FocusLost:Connect(function(WasEnter)
	if not WasEnter then return end

	local IndexLocation = (
		SearchFrame.FromWhere.Buttons.AllUsers.BackgroundTransparency == 0 and "Roblox" or
			SearchFrame.FromWhere.Buttons.GameDB.BackgroundTransparency == 0 and "Game" or
			SearchFrame.FromWhere.Buttons.Servers.BackgroundTransparency == 0 and "Servers"
	)

	for _, Child in SearchFrame.Results:GetChildren() do
		if not Child:IsA("Frame") or Child.Name == "Template" then continue end

		Child:Destroy()
	end

	for _, Connection in SearchEvents do
		Connection:Disconnect()
	end

	print(`Indexing search from {IndexLocation}`)

	if IndexLocation == "Servers" then
		local List = Remotes.ServerComm:InvokeServer("RequestServers")

		for _, Server in List do
			UserSearchItem(Server[2].P, SearchFrame.FromWhere.Searchbar.Input.Text, false, Server[1])
		end
	elseif IndexLocation == "Game" then
		UserSearchItem("InfoTip", `This tool is designed for smaller games. If you are having trouble loading page content please use Roblox search.`, false)
		local List = Remotes.ServerComm:InvokeServer("GetAllPlayers", {
			Type = "Deep"
		})		

		if List.__message ~= nil then
			UserSearchItem("InfoTip", List.__message, false)	
		end

		UserSearchItem(List, SearchFrame.FromWhere.Searchbar.Input.Text, false)
	elseif IndexLocation == "Roblox" then
		local List 

		if tonumber(SearchFrame.FromWhere.Searchbar.Input.Text) ~= nil then
			UserSearchItem({ tonumber(SearchFrame.FromWhere.Searchbar.Input.Text) }, "", true)

			return
		end

		xpcall(function()
			List = Remotes.ServerComm:InvokeServer("SearchFromRoblox", {
				Query = SearchFrame.FromWhere.Searchbar.Input.Text
			})
		end, function(e)
			UserSearchItem("InfoTip", `No results found ({e}).`, false)

			List = {}
		end)

		UserSearchItem(List, SearchFrame.FromWhere.Searchbar.Input.Text, false)
	end
end)

for _, Button: TextButton in SearchFrame.FromWhere.Buttons:GetChildren() do
	if not Button:IsA("TextButton") then continue end

	Button.MouseButton1Click:Connect(function()
		for _, Button2: TextButton in SearchFrame.FromWhere.Buttons:GetChildren() do
			if not Button2:IsA("TextButton") then continue end
			if Button2 == Button then continue end

			game:GetService("TweenService"):Create(Button2, TweenInfo.new(.3), { BackgroundTransparency = 1 }):Play()
		end

		game:GetService("TweenService"):Create(Button, TweenInfo.new(.3), { BackgroundTransparency = 0 }):Play()
	end)
end

while task.wait(PollInterval) do
	if PausePolling then continue end

	for i, ch in ServerDir.Content:GetChildren() do
		if ch.Name ~= "Template" and ch:IsA("Frame") then ch:Destroy() end
	end

	for i, conn in Connections do conn:Disconnect() end
	Connections = {}

	task.spawn(InitServers)
end
