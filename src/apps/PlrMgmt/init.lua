return {
	OnDownload = function()
		print("Pulled!")
	end,
	
	Init = function()
		script.PlayerManagement.Parent = game.ServerScriptService.Administer.Apps
		
		return "Player Management", "Your one-stop-shop to manage your game's players.\n\nCreated by @pyxfluff, 2024", "v1.1"
	end,
}