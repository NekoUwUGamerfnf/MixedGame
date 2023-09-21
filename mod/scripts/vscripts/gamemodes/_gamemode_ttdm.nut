global function GamemodeTTDM_Init

const float TTDMIntroLength = 15.0

void function GamemodeTTDM_Init()
{
	Riff_ForceSetSpawnAsTitan( eSpawnAsTitan.Always )
	Riff_ForceTitanExitEnabled( eTitanExitEnabled.Never )
	TrackTitanDamageInPlayerGameStat( PGS_ASSAULT_SCORE )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	SetLoadoutGracePeriodEnabled( false )

	ClassicMP_SetCustomIntro( TTDMIntroSetup, TTDMIntroLength )
	ClassicMP_ForceDisableEpilogue( true )
	SetTimeoutWinnerDecisionFunc( CheckScoreForDraw )

	AddCallback_OnPlayerKilled( AddTeamScoreForPlayerKilled ) // dont have to track autotitan kills since you cant leave your titan in this mode

	// probably needs scoreevent earnmeter values
	SetUpTTDMScoreEvents() // northstar missing

	// tempfix specifics
	SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point
}

// northstar missing
void function SetUpTTDMScoreEvents()
{
	// pilot kill: 15%
	// titan kill: 0%
	// titan assist: 0%
	// execution: 0%
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.0, 0.15, 1.0 )
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "KillAutoTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "TitanKillTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "TitanAssist", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "Execution", 0.0, 0.0 )
}

void function TTDMIntroSetup()
{
	// this should show intermission cam for 15 sec in prematch, before spawning players as titans
	AddCallback_GameStateEnter( eGameState.Prematch, TTDMIntroStart )
	//AddCallback_OnClientConnected( TTDMIntroShowIntermissionCam )
	// vanilla behavior...
	AddCallback_GameStateEnter( eGameState.Playing, TTDMGameStart )
	AddCallback_OnClientConnected( TTDMIntroConntectedPlayer )
}

void function TTDMIntroStart()
{
	thread TTDMIntroStartThreaded()
}

void function TTDMIntroStartThreaded()
{
	ClassicMP_OnIntroStarted()

	foreach ( entity player in GetPlayerArray() )
	{
		if ( !IsPrivateMatchSpectator( player ) )
			TTDMIntroShowIntermissionCam( player )
		else
			RespawnPrivateMatchSpectator( player )
	}

	wait TTDMIntroLength

	ClassicMP_OnIntroFinished()
}

void function TTDMIntroShowIntermissionCam( entity player )
{
	// vanilla behavior
	//if ( GetGameState() != eGameState.Prematch )
	//	return
	
	thread PlayerWatchesTTDMIntroIntermissionCam( player )
}

// vanilla behavior
void function TTDMGameStart()
{
	foreach ( entity player in GetPlayerArray_Alive() )
	{
		TryGameModeAnnouncement( player ) // announce players whose already alive
		player.UnfreezeControlsOnServer() // if a player is alive they must be freezed, unfreeze them
	}
}

void function TTDMIntroConntectedPlayer( entity player )
{
	if ( GetGameState() != eGameState.Prematch )
		return
		
	thread TTDMIntroConntectedPlayer_Threaded( player )
}

void function TTDMIntroConntectedPlayer_Threaded( entity player )
{
	player.EndSignal( "OnDestroy" )

	RespawnAsTitan( player, false )
	if ( GetGameState() == eGameState.Prematch ) // still in intro
		player.FreezeControlsOnServer() // freeze
	else if ( GetGameState() == eGameState.Playing ) // they may connect near the end of intro
		TryGameModeAnnouncement( player )
}

void function PlayerWatchesTTDMIntroIntermissionCam( entity player )
{
	player.EndSignal( "OnDestroy" )
	ScreenFadeFromBlack( player )

	entity intermissionCam = GetEntArrayByClass_Expensive( "info_intermission" )[ 0 ]

	// the angle set here seems sorta inconsistent as to whether it actually works or just stays at 0 for some reason
	player.SetObserverModeStaticPosition( intermissionCam.GetOrigin() )
	player.SetObserverModeStaticAngles( intermissionCam.GetAngles() )
	player.StartObserverMode( OBS_MODE_STATIC_LOCKED )

	wait TTDMIntroLength

	RespawnAsTitan( player, false )
	TryGameModeAnnouncement( player )
}

void function AddTeamScoreForPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim == attacker || !victim.IsPlayer() || !attacker.IsPlayer() && GetGameState() == eGameState.Playing )
		return

	AddTeamScore( GetOtherTeam( victim.GetTeam() ), 1 )
}

int function CheckScoreForDraw()
{
	if (GameRules_GetTeamScore(TEAM_IMC) > GameRules_GetTeamScore(TEAM_MILITIA))
		return TEAM_IMC
	else if (GameRules_GetTeamScore(TEAM_MILITIA) > GameRules_GetTeamScore(TEAM_IMC))
		return TEAM_MILITIA

	return TEAM_UNASSIGNED
}