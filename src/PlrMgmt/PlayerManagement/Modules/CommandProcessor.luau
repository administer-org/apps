--// pyxfluff 2024

local Commands = {
	"Anchor",
	"Blind",
	"Blur",
	"Bring",
	"BuildTools",
	"Crash",
	"Fling",
	"Fly",
	"Jail",
	"Kill",
	"Morph",
	"Mute",
	"NoClip",
	"PlaySound",
	"PromptPurchase",
	"SendTo",
	"SetJP",
	"SetSpeed",
	"Sit",
	"Teleport",
	"Watch",
}

return {
	GetCommandIndex = function()
		return {
			["Anchor"] = {
				["Name"] = "Anchor",
				["Description"] = "Freezes a character.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, TargetState)
					Player.Character.Anchored = TargetState
				end,
			},
			["Blind"] = {
				["Name"] = "Blind",
				["Description"] = "Blinds the character.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, State)
					local PlrGui = Player.PlayerGui
					local BlindFrame

					if not PlrGui:FindFirstChild("_AdmBlind") then
						local BlindGui = Instance.new("ScreenGui", PlrGui)
						BlindGui.IgnoreGuiInset = true

						BlindFrame = Instance.new("Frame", BlindGui)
						BlindFrame.Size = UDim2.new(1, 0, 1, 0)
					end

					if not BlindFrame then BlindFrame = PlrGui:FindFirstChild("_AdmBlind"):FindFirstChild("Frame") end

					game:GetService("TweenService")
						:Create(
							BlindFrame,
							TweenInfo.new(0.45),
							{ BackgroundTransparency = (State == true and 0 or 1) }
						)
						:Play()
				end,
			},
			["Blur"] = {
				["Name"] = "Blur",
				["Description"] = "Applies a blur effect.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Bring"] = {
				["Name"] = "Bring",
				["Description"] = "Brings the character to a player.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["BuildTools"] = {
				["Name"] = "BuildTools",
				["Description"] = "Grants F3X btools.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Crash"] = {
				["Name"] = "Crash",
				["Description"] = "Crashes the player's game.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Fling"] = {
				["Name"] = "Fling",
				["Description"] = "Flings the character.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Fly"] = {
				["Name"] = "Fly",
				["Description"] = "Enables flying for the character.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Jail"] = {
				["Name"] = "Jail",
				["Description"] = "Imprisons the character.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Kill"] = {
				["Name"] = "Kill",
				["Description"] = "Kills the character.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player)
					local character = Player.Character or Player.CharacterAdded:Wait()
					local humanoid: Humanoid = character:FindFirstChild("Humanoid")
					humanoid.Health = 0
				end,
			},
			["Morph"] = {
				["Name"] = "Morph",
				["Description"] = "Changes their avatar to somebody else.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Mute"] = {
				["Name"] = "Mute",
				["Description"] = "Takes away their ability to chat.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, state)
					local TextChatService = game:GetService("TextChatService")
					if state == true then
						for _, child in TextChatService:GetDescendants() do
							if child:IsA("TextSource") and child.UserId == Player.UserId then child.CanSend = false end
						end
					else
						for _, child in TextChatService:GetDescendants() do
							if child:IsA("TextSource") and child.UserId == Player.UserId then child.CanSend = true end
						end
					end
				end,
			},
			["NoClip"] = {
				["Name"] = "NoClip",
				["Description"] = "Enables noclip.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["PlaySound"] = {
				["Name"] = "PlaySound",
				["Description"] = "Plays a sound locally.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["PromptPurchase"] = {
				["Name"] = "PromptPurchase",
				["Description"] = "Prompts a purchase for an asset.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, productId: number)
					xpcall(function()
						local MarketplaceService = game:GetService("MarketplaceService")
						MarketplaceService:PromptPurchase(Player, productId, false, Enum.CurrencyType.Robux)
					end, function()
						print("Failed to prompt player, are third party sales enabled?")
					end)
				end,
			},
			["SendTo"] = {
				["Name"] = "Send to",
				["Description"] = "Teleports them to a new game.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["SetJP"] = {
				["Name"] = "Set JumpPower",
				["Description"] = "Sets the character's jump power.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, state: number)
					local character = Player.Character or Player.CharacterAdded:Wait()
					local humanoid: Humanoid = character:FindFirstChild("Humanoid")
					if typeof(state) ~= "number" and state < 0 then return end
					humanoid.JumpPower = state
				end,
			},
			["SetSpeed"] = {
				["Name"] = "SetSpeed",
				["Description"] = "Sets the character's speed.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, state: number)
					local character = Player.Character or Player.CharacterAdded:Wait()
					local humanoid: Humanoid = character:FindFirstChild("Humanoid")
					if typeof(state) ~= "number" and state < 0 then return end
					humanoid.WalkSpeed = state
				end,
			},
			["Sit"] = {
				["Name"] = "Sit",
				["Description"] = "Makes their character sit.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player)
					local character = Player.Character or Player.CharacterAdded:Wait()
					local humanoid: Humanoid = character:FindFirstChild("Humanoid")
					humanoid.Sit = true
				end,
			},
			["Teleport"] = {
				["Name"] = "Teleport to",
				["Description"] = "Teleports them to a location in-game.",
				["RequireLocalPlayer"] = false,
				["Trigger"] = function(Player: Player, ...) end,
			},
			["Watch"] = {
				["Name"] = "Watch",
				["Description"] = "Sets your camera subject to their character.",
				["RequireLocalPlayer"] = true,
				["Trigger"] = function(Player: Player, ...) end,
			},
		}
	end,

	Commands = Commands,
}
