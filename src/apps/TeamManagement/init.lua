return {
	OnDownload = function()
		print("Pulled!")
	end,

	Init = function()
		return {
			LocalTitle = "Team Manager", 
			LocalDesc  = "Manage your game's teams.", 
			AppVersion = "v1",
			AppContent = script.TeamManager
		}
	end,
}