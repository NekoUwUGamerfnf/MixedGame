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

	// tempfix specifics
	EarnMeterMP_SetPassiveGainProgessEnable( true ) // enable earnmeter gain progressing like vanilla
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
	thread FFAPlayerScoreThink( player ) // good to have this! instead of DisconnectCallback this could handle a null player
}

void function FFAPlayerScoreThink( entity player )
{
	player.EndSignal( "OnDestroy" ) // this can handle disconnecting

	table results = {
		team = player.GetTeam()
		score = 0
	}

	OnThreadEnd
	(
		function(): ( results )
		{
			int team = expect int( results.team )
			int score = expect int( results.score )
			if ( GetGameState() == eGameState.Playing ) // game still playing, we remove score from this player
				AddTeamScore( team, -score )
			if ( GetPlayerArrayOfTeam( team ).len() == 0 ) // all player of this team has disconnected!
				AddTeamScore( team, -GameRules_GetTeamScore( team ) ) // remove all score
		}
	)

	// keep updating
	while ( true )
	{
		results.team = player.GetTeam()
		results.score = file.ffaPlayerScore[ player ]

		WaitFrame()
	}
}