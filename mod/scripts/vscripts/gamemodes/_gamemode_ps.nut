untyped
global function GamemodePs_Init
//global function RateSpawnpoints_SpawnZones

struct {
	array<entity> spawnzones
	
	entity militiaActiveSpawnZone
	entity imcActiveSpawnZone
	
	array<entity> militiaPreviousSpawnZones
	array<entity> imcPreviousSpawnZones
} file

void function GamemodePs_Init()
{
	Riff_ForceTitanAvailability( eTitanAvailability.Never )

	AddCallback_OnPlayerKilled( GiveScoreForPlayerKill )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	SetUpPilotSkirmishScoreEvent() // northstar missing
	SetTimeoutWinnerDecisionFunc( CheckScoreForDraw )

	// spawnzone stuff
	SetShouldCreateMinimapSpawnZones( true )
	
	//AddCallback_OnPlayerKilled( CheckSpawnzoneSuspiciousDeaths )
	//AddSpawnCallbackEditorClass( "trigger_multiple", "trigger_mp_spawn_zone", SpawnzoneTriggerInit )
	
	file.militiaPreviousSpawnZones = [ null, null, null ]
	file.imcPreviousSpawnZones = [ null, null, null ]

	// tempfix specifics
	SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point
}

// northstar missing
void function SetUpPilotSkirmishScoreEvent()
{
	// override settings
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.10, 0.10 )
}

void function GiveScoreForPlayerKill( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker 
		 && victim.IsPlayer() 
		 && IsValid( attacker ) 
		 && attacker.IsPlayer() 
		 && GetGameState() == eGameState.Playing )
	{
		AddTeamScore( attacker.GetTeam(), 1 )
		
		if ( GetGameState() == eGameState.WinnerDetermined ) // win match with AddTeamScore()
			ScoreEvent_VictoryKill( attacker )
	}
}

int function CheckScoreForDraw()
{
	if ( GameRules_GetTeamScore( TEAM_IMC ) > GameRules_GetTeamScore( TEAM_MILITIA ) )
		return TEAM_IMC
	else if ( GameRules_GetTeamScore( TEAM_MILITIA ) > GameRules_GetTeamScore( TEAM_IMC ) )
		return TEAM_MILITIA

	return TEAM_UNASSIGNED
}