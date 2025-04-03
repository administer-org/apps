--// pyxfluff 2024 - 2025

local Types = require(game.ServerScriptService.Administer.Loader.Core.Types)

return function(InvokeAPI: Types.InvocationAPI, a)
	local RichConfig = InvokeAPI.RichConfig()

	RichConfig.AppMeta.Name = "Player Management"
	RichConfig.AppMeta.Description = "Manage your game's players with ease.\n\nADMINISTER 2.0 API TESTING, ROUGH EDGES EVERYWHERE"
	RichConfig.AppMeta.Icon = require(game.ServerScriptService.Administer.Loader.Core.Icons).users
	RichConfig.AppMeta.Copyright = "2024 - 2025 pyxfluff"
	RichConfig.AppMeta.Version = "2.0.0"

	RichConfig.Dependencies.AppPlatform = "min:2.0.0;max:3.0.0"
	RichConfig.Dependencies.Administer = "min:2.0.0;max:3.0.0"
	RichConfig.Dependencies.SettingsAPI = "2.0"
	RichConfig.Dependencies.AdministerModules = {
		{
			Type = "SERVER",
			Name = "AdminRunner"
		},
		{
			Type = "SERVER",
			Name = "Utilities"
		}
	} :: any

	RichConfig.ClientFrame = script.PlayerManagement.UI.PlayerManagement
	RichConfig.Bootstrap = require(script.PlayerManagement.Main)

	return InvokeAPI.Construct(RichConfig, a)
end
