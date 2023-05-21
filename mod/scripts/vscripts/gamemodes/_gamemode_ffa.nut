global function FFA_Init

// modified: for saving player's score in ffa, don't let mid-game joined players get illegal scores
struct
{
	table<entity, int> ffaPlayerScore
} file

void function FFA_Init()
{
	ClassicMP_ForceDisableEpilogue( true )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()

	AddCallback_OnPlayerKilled( OnPlayerKilled )

	// modified for northstar
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnClientDisconnected( OnClientDisconnected )
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker && victim.IsPlayer() && attacker.IsPlayer() && GetGameState() == eGameState.Playing )
	{
		// use AddFFAPlayerScore() for better handling
		//AddTeamScore( attacker.GetTeam(), 1 )
		// why isn't this PGS_SCORE? odd game
		//attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )

		// modified for northstar
		AddFFAPlayerTeamScore( attacker, 1 )
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 ) // add to scoreboard
	}
}

// modified for northstar
void function AddFFAPlayerTeamScore( entity player, int scoreAmount )
{
	AddTeamScore( player.GetTeam(), scoreAmount ) // add to team score
	file.ffaPlayerScore[ player ] += scoreAmount // add for later we clean up
}

void function OnClientConnected( entity player )
{
	file.ffaPlayerScore[ player ] <- 0
}

void function OnClientDisconnected( entity player )
{
	// take score from this team, based on how much score player earned. handles ffa with 2 or more players in 1 team
	int team = player.GetTeam()
	int score = file.ffaPlayerScore[ player ]

	if ( GetGameState() == eGameState.Playing ) // game still playing, we remove score from this player
		AddTeamScore( team, -score )
	delete file.ffaPlayerScore[ player ]
}