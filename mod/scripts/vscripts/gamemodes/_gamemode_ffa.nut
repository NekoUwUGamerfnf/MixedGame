global function FFA_Init

// modified: for saving player's score in ffa, don't let mid-game joined players get illegal scores
struct
{
	table<entity, int> ffaPlayerScore
} file

void function FFA_Init()
{
	// ffa mode already handled by ClassicMP_ShouldRunEpilogue(), no need to force disable everywhere
	//ClassicMP_ForceDisableEpilogue( true )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()

	// northstar missing titan score value
	AddCallback_OnPlayerKilled( HandleFFAScoreEventValue )
	AddCallback_OnNPCKilled( HandleFFAScoreEventValue )

	SetUpFFAScoreEvents() // northstar missing

	// modified for northstar
	AddCallback_OnClientConnected( OnClientConnected )

	// tempfix specifics
	EarnMeterMP_SetPassiveGainProgessEnable( true ) // enable earnmeter gain progressing like vanilla
}

// northstar missing
void function SetUpFFAScoreEvents()
{
	// pilot kill: 20%
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.10, 0.10 )
}

void function HandleFFAScoreEventValue( entity victim, entity attacker, var damageInfo )
{
	if ( attacker.IsPlayer() && victim != attacker && GetGameState() == eGameState.Playing  )
	{
		// northstar missing: titan score value
		if ( victim.IsTitan() && ( victim.IsPlayer() || ( IsValid( victim.GetTitanSoul() ) && GetPetTitanOwner( victim ) != attacker ) ) )
		{
			AddFFAPlayerTeamScore( attacker, 3 )
		}

		// pilot score value, will also be added if killed a titan with pilot
		if ( victim.IsPlayer() )
		{
			// use AddFFAPlayerScore() for better handling
			//AddTeamScore( attacker.GetTeam(), 1 )
			// why isn't this PGS_SCORE? odd game
			//attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )

			// modified for northstar
			AddFFAPlayerTeamScore( attacker, 1 )
		}
	}
}

// modified for northstar
void function AddFFAPlayerTeamScore( entity player, int scoreAmount )
{
	AddTeamScore( player.GetTeam(), scoreAmount ) // add to team score
	file.ffaPlayerScore[ player ] += scoreAmount // add for later we clean up
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, scoreAmount ) // add to scoreboard
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