untyped
global function GamemodeLts_Init

struct {
	entity lastDamageInfoVictim
	entity lastDamageInfoAttacker
	int lastDamageInfoMethodOfDeath
	float lastDamageInfoTime
	
	bool shouldDoHighlights
} file

// titan selection shouldn't last 30s
const float LTS_TITAN_SELECTION_DURATION = 15.0

// vanilla behavior: add 6s sonar for all players, not resetting their highlight life-long
const float LTS_THIRTY_SECONDS_SONAR_DURATION = 6.0

void function GamemodeLts_Init()
{
	// gamemode settings
	SetShouldUsePickLoadoutScreen( true )
	SetTitanSelectionMenuDuration( LTS_TITAN_SELECTION_DURATION )
	SetSwitchSidesBased( true )
	SetRoundBased( true )
	SetRespawnsEnabled( false )
	EarnMeterMP_SetPassiveGainProgessEnable( false )
	Riff_ForceSetEliminationMode( eEliminationMode.PilotsTitans )
	Riff_ForceSetSpawnAsTitan( eSpawnAsTitan.Always )
	SetShouldUseRoundWinningKillReplay( true )
	SetRoundWinningKillReplayKillClasses( true, true ) // both titan and pilot kills are tracked
	ScoreEvent_SetupEarnMeterValuesForTitanModes()
	SetLoadoutGracePeriodEnabled( false )
	FlagSet( "ForceStartSpawn" )

	AddCallback_OnPlayerKilled( LTS_OnPlayerOrNPCKilled )
	AddCallback_OnNPCKilled( LTS_OnPlayerOrNPCKilled )

	SetTimeoutWinnerDecisionFunc( CheckTitanHealthForDraw )
	SetTimeoutWinnerDecisionReason( "#GAMEMODE_TITAN_DAMAGE_ADVANTAGE", "#GAMEMODE_TITAN_DAMAGE_DISADVANTAGE" )
	TrackTitanDamageInPlayerGameStat( PGS_ASSAULT_SCORE )
	
	ClassicMP_SetCustomIntro( ClassicMP_DefaultNoIntro_Setup, ClassicMP_DefaultNoIntro_GetLength() )
	ClassicMP_ForceDisableEpilogue( true )
	AddCallback_GameStateEnter( eGameState.Playing, WaitForThirtySecondsLeft )
}

void function WaitForThirtySecondsLeft()
{
	thread WaitForThirtySecondsLeftThreaded()
}

void function WaitForThirtySecondsLeftThreaded()
{
	svGlobal.levelEnt.EndSignal( "RoundEnd" ) // end this on round end
	
	float endTime = expect float ( GetServerVar( "roundEndTime" ) )
	// wait until 30sec left 
	wait ( endTime - 30 ) - Time()

	//PlayMusicToAll( eMusicPieceID.LEVEL_LAST_MINUTE )
	//try using this?
	CreateTeamMusicEvent( TEAM_IMC, eMusicPieceID.LEVEL_LAST_MINUTE, Time() )
	CreateTeamMusicEvent( TEAM_MILITIA, eMusicPieceID.LEVEL_LAST_MINUTE, Time() )
	foreach( entity player in GetPlayerArray() )
		PlayCurrentTeamMusicEventsOnPlayer( player )
	
	foreach ( entity player in GetPlayerArray() )
	{	
		// warn there's 30 seconds left
		Remote_CallFunction_NonReplay( player, "ServerCallback_LTSThirtySecondWarning" )
	}

	// vanilla behavior: add 6s sonar for all players, not resetting their highlight life-long
	ThirtySecondWallhackHighlight()
}

// vanilla behavior: add 6s sonar for all players, not resetting their highlight life-long
void function ThirtySecondWallhackHighlight()
{
	foreach ( entity player in GetPlayerArray() )
	{
		thread TitanSonarThink( player )
	}
}

void function TitanSonarThink( entity player )
{
	player.EndSignal( "OnDestroy" )

	entity titan = GetTitanFromPlayer( player )
	if ( !IsValid( titan ) )
		return

	int sonarTeam = GetOtherTeam( player.GetTeam() )
	// start sonar
	SonarStart( titan, titan.GetOrigin(), sonarTeam, titan )
	IncrementSonarPerTeam( sonarTeam )

	OnThreadEnd
	(
		function() : ( player, sonarTeam ) // we can't pass the titan here, it will remain initial value 
		{
			DecrementSonarPerTeam( sonarTeam )
			if ( IsValid( player ) )
			{
				entity titan = GetTitanFromPlayer( player )
				if ( IsValid( titan ) )
				{
					//print( "Disabling sonar on titan: " + string( titan ) )
					SonarEnd( titan, sonarTeam )
				}
			}
		}
	)

	float endTime = Time() + LTS_THIRTY_SECONDS_SONAR_DURATION
	// keep updating titan sonar on transfering
	entity titanLastTick = GetTitanFromPlayer( player )
	while ( Time() < endTime )
	{
		WaitFrame()

		titan = GetTitanFromPlayer( player )
		if ( !IsValid( titan ) )
		{
			//print( "Player titan invalid!" )
			return
		}

		if ( titan != titanLastTick ) // this must means player has transfered
		{
			//print( "Player titan transferred!" )
			//if ( "inSonarTriggerCount" in titan.s )
			//	print( string( titan ) + " 's sonar trigger count is: " + string( titan.s.inSonarTriggerCount ) )
			
			if ( IsValid( titanLastTick ) && titanLastTick.IsPlayer() )
				SonarEnd( titanLastTick, sonarTeam )
			
			// start sonar on new titan
			SonarStart( titan, titan.GetOrigin(), sonarTeam, titan )
		}

		titanLastTick = titan
	}
}

void function LTS_OnPlayerOrNPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( victim.IsTitan() )
	{
		array<entity> allies = GetPlayerArrayOfTeam_Alive( victim.GetTeam() )
		int teamTitanCount
		entity latestCheckedPlayer
		foreach( entity player in allies )
		{
			if( PlayerHasTitan( player ) )
			{
				teamTitanCount += 1
				latestCheckedPlayer = player
			}
		}
		if( teamTitanCount == 1 )
		{
			if( IsValid( latestCheckedPlayer ) )
				PlayFactionDialogueToPlayer( "lts_playerLastTitanOnTeam", latestCheckedPlayer )
		}
	}
}

int function CheckTitanHealthForDraw()
{
	int militiaTitans
	int imcTitans
	
	float militiaHealth
	float imcHealth
	
	foreach ( entity titan in GetTitanArray() )
	{
		if ( titan.GetTeam() == TEAM_MILITIA )
		{
			// doomed is counted as 0 health
			militiaHealth += titan.GetTitanSoul().IsDoomed() ? 0.0 : GetHealthFrac( titan )
			if ( !( "noLongerCountsForLTS" in titan.s ) ) // in sh_titan.gnut. nuke titan don't cound as lts scoring
				militiaTitans++
		}
		else
		{
			// doomed is counted as 0 health in this
			imcHealth += titan.GetTitanSoul().IsDoomed() ? 0.0 : GetHealthFrac( titan )
			if ( !( "noLongerCountsForLTS" in titan.s ) ) // in sh_titan.gnut. nuke titan don't cound as lts scoring
				imcTitans++
		}
	}
	
	// note: due to how stuff is set up rn, there's actually no way to do win/loss reasons outside of a SetWinner call, i.e. not in timeout winner decision
	// as soon as there is, strings in question are "#GAMEMODE_TITAN_TITAN_ADVANTAGE" and "#GAMEMODE_TITAN_TITAN_DISADVANTAGE"
	
	if ( militiaTitans != imcTitans )
		return militiaTitans > imcTitans ? TEAM_MILITIA : TEAM_IMC
	else if ( militiaHealth != imcHealth )
		return militiaHealth > imcHealth ? TEAM_MILITIA : TEAM_IMC
		
	return TEAM_UNASSIGNED
}