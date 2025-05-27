local Types = require(game.ServerScriptService.Administer.Loader.Core.Types)

return function(InvokeAPI: Types.InvocationAPI, a)
	local RichConfig = InvokeAPI.RichConfig()

	RichConfig.AppMeta.Name = "Team Manager"
	RichConfig.AppMeta.Description = "Manage teams from inside of your game."
	RichConfig.AppMeta.Icon = require(game.ServerScriptService.Administer.Loader.Core.Icons)["flag-usa"]
	RichConfig.AppMeta.Copyright = "2024 dogo8me"
	RichConfig.AppMeta.Version = "1.0.0"

	RichConfig.Dependencies.AppPlatform = "min:2.0.0;max:3.0.0"
	RichConfig.Dependencies.Administer = "min:2.0.0;max:3.0.0"
	RichConfig.Dependencies.AdministerModules = {
		{
			Type = "SERVER",
			Name = "Utilities"
		}
	} :: any

	RichConfig.ClientFrame = script.TeamManager.UI.TeamManagement
	RichConfig.Bootstrap = require(script.TeamManager.Server)

	return InvokeAPI.Construct(RichConfig, a)
end
