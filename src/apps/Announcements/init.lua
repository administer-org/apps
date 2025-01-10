return {
	OnDownload = function()
		print("Pulled!")
	end,
	
	Init = function()
		script.Announcements.Parent = game.ServerScriptService.Administer.Apps
		
		return "Announcements", "Manage your announcements with ease.", "v1"
	end,
}