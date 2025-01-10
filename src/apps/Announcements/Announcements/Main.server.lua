--// dullerkiller 2024

--// Modules
local Runner = require(game.ServerScriptService.Administer.AppAPI)

local UIFolder = script.Parent:WaitForChild("UI")
local AccouncementsGui = UIFolder:WaitForChild("AnnouncementsGui")
AccouncementsGui.Parent = game:GetService("StarterGui")

--// Run
local App = Runner.Build(
	function(Config, AppAPI)
	end, 
	{
	}, 
	{
		Icon = "rbxassetid://13657718907",
		Name = "Announcements",
		Frame = UIFolder:WaitForChild("Announcements"),
		Tip = "Manage your announcements with ease.",
		HasBG = false
	}
)