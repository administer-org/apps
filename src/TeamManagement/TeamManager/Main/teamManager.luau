local TeamManager = {}
local teams = game:GetService("Teams")

function TeamManager.GetAllTeams(): {Team}
	return teams:GetChildren()
end

function TeamManager.CreateTeam(name: string, color: BrickColor, autoAssignable: boolean): Team
	local team = Instance.new("Team")
	team.Name = name
	team.TeamColor = color
	team.AutoAssignable = autoAssignable
	team.Parent = teams
	return team
end

function TeamManager.GetPlayersInTeam(team: Team): {Player}
	local playersInTeam = {}

	for _, player in pairs(game:GetService("Players"):GetPlayers()) do
		if player.Team == team then
			table.insert(playersInTeam, player)
		end
	end

	return playersInTeam
end

function TeamManager.IsPlayerInTeam(player: Player, team: Team): boolean
	return player.Team == team
end

function TeamManager.EditTeam(team: Team, name: string, color: BrickColor, autoAssignable: boolean): Team
	team.Name = name
	team.TeamColor = color
	team.AutoAssignable = autoAssignable
	return team
end

function TeamManager.DeleteTeam(team: Team)
	return team:Destroy()
end

function TeamManager.AddPlayerToTeam(player: Player, team: Team)
	player.Team = team
	return player.Team
end
function TeamManager.RemovePlayerFromTeam(player: Player)
	player.Team = nil
	return player.Team
end
return TeamManager
