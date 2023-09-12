global function GamemodeSpeedball_Init

const NOINTRO_INTRO_SPEEDBALL_LENGTH = 6.0 // vanilla behaves like this

struct {
	entity flagBase
	entity flag
	entity flagCarrier
} file

// modded gamemodes
global function Modded_Gamemode_Survival_Enable_Init

struct
{
	bool survival = false
} modGamemodes

void function Modded_Gamemode_Survival_Enable_Init()
{
	modGamemodes.survival = true
}

void function GamemodeSpeedball_Init()
{
	if ( modGamemodes.survival )
		Modded_Gamemode_Survival_Init()
	else // vanilla gameplay
	{
		PrecacheModel( CTF_FLAG_MODEL )
		PrecacheModel( CTF_FLAG_BASE_MODEL )

		// gamemode settings
		FlagSet( "ForceStartSpawn" ) // northstar missing
		SetRoundBased( true )
		SetSwitchSidesBased( true ) // northstar missing
		SetRespawnsEnabled( false )
		SetShouldUseRoundWinningKillReplay( true )
		EarnMeterMP_SetPassiveGainProgessEnable( false )
		Riff_ForceTitanAvailability( eTitanAvailability.Never )
		Riff_ForceSetEliminationMode( eEliminationMode.Pilots )
		ScoreEvent_SetupEarnMeterValuesForMixedModes()
		SetUpSpeedBallScoreEvent() // northstar missing

		AddSpawnCallbackEditorClass( "script_ref", "info_speedball_flag", CreateFlag )
		AddCallback_OnClientConnected( OnClientConnected )

		AddCallback_GameStateEnter( eGameState.Prematch, CreateFlagIfNoFlagSpawnpoint )
		AddCallback_GameStateEnter( eGameState.Playing, ResetFlag )
		AddCallback_GameStateEnter( eGameState.WinnerDetermined,GamemodeSpeedball_OnWinnerDetermined)
		AddCallback_OnTouchHealthKit( "item_flag", OnFlagCollected )

		AddCallback_OnPlayerKilled( OnPlayerKilled )
		SetTimeoutWinnerDecisionFunc( TimeoutCheckFlagHolder )
		SetTimeoutWinnerDecisionReason( "#GAMEMODE_SPEEDBALL_WIN_TIME_FLAG_LAST", "#GAMEMODE_SPEEDBALL_LOSS_TIME_FLAG_LAST" )
		AddCallback_OnRoundEndCleanup( ResetFlag )

		ClassicMP_SetCustomIntro( ClassicMP_DefaultNoIntro_Setup, NOINTRO_INTRO_SPEEDBALL_LENGTH )
		ClassicMP_ForceDisableEpilogue( true )
	}
}

// northstar missing
// livefire do have stronger score events
void function SetUpSpeedBallScoreEvent()
{
	// override settings
	ScoreEvent_SetEarnMeterValues( "EliminatePilot", 0.20, 0.15 )
}

void function OnClientConnected( entity player )
{
	thread SpeedBallPlayerObjectiveThink( player )
}

const int OBJECTIVE_EMPTY = -1
const int OBJECTIVE_KILL_CAP = 110 // #SPEEDBALL_OBJECTIVE_KILL_CAP
const int OBJECTIVE_ENEMY_FLAG = 111 // #SPEEDBALL_OBJECTIVE_ENEMY_FLAG
const int OBJECTIVE_FRIENDLY_FLAG = 112 // #SPEEDBALL_OBJECTIVE_FRIENDLY_FLAG
const int OBJECTIVE_PLAYER_FLAG = 113 // #SPEEDBALL_OBJECTIVE_PLAYER_FLAG

void function SpeedBallPlayerObjectiveThink( entity player )
{
	player.EndSignal( "OnDestroy" )

	while ( true )
	{
		int nextObjective = OBJECTIVE_KILL_CAP
		if ( !IsAlive( player ) || GetGameState() != eGameState.Playing ) // don't show objective to died player
			nextObjective = OBJECTIVE_EMPTY
		else
		{
			entity flagCarrier = GetGlobalNetEnt( "flagCarrier" )
			if ( IsValid( flagCarrier ) ) // flag carrier stuffs
			{
				if ( flagCarrier == player )
					nextObjective = OBJECTIVE_PLAYER_FLAG
				else if ( flagCarrier.GetTeam() == player.GetTeam() )
					nextObjective = OBJECTIVE_FRIENDLY_FLAG
				else if ( flagCarrier != file.flag ) // file.flag will be neatual flagCarrier
					nextObjective = OBJECTIVE_ENEMY_FLAG
			}
		}

		int curObjective = player.GetPlayerNetInt( "gameInfoStatusText" )
		if ( curObjective != nextObjective )
			player.SetPlayerNetInt( "gameInfoStatusText", nextObjective )

		WaitFrame()
	}
}
//

void function CreateFlag( entity flagSpawn )
{ 
	entity flagBase = CreatePropDynamic( CTF_FLAG_BASE_MODEL, flagSpawn.GetOrigin(), flagSpawn.GetAngles() )
	
	entity flag = CreateEntity( "item_flag" )
	flag.SetValueForModelKey( CTF_FLAG_MODEL )
	flag.MarkAsNonMovingAttachment()
	DispatchSpawn( flag )
	flag.SetModel( CTF_FLAG_MODEL )
	flag.SetOrigin( flagBase.GetOrigin() + < 0, 0, flagBase.GetBoundingMaxs().z + 1 > )
	flag.SetVelocity( < 0, 0, 1 > )

	flag.Minimap_AlwaysShow( TEAM_IMC, null )
	flag.Minimap_AlwaysShow( TEAM_MILITIA, null )
	flag.Minimap_SetAlignUpright( true )

	file.flag = flag
	file.flagBase = flagBase
}	

bool function OnFlagCollected( entity player, entity flag )
{
	if ( !IsAlive( player ) || flag.GetParent() != null || player.IsTitan() || player.IsPhaseShifted() ) 
		return false
		
	GiveFlag( player )
	return false // so flag ent doesn't despawn
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	if ( file.flagCarrier == victim )
		DropFlag()
		
	if ( victim.IsPlayer() && GetGameState() == eGameState.Playing )
	{
		if ( GetPlayerArrayOfTeam_Alive( victim.GetTeam() ).len() == 1 )
		{
			foreach ( entity player in GetPlayerArray() )
			{
				if ( player.GetTeam() != victim.GetTeam() || player == GetPlayerArrayOfTeam_Alive( victim.GetTeam() )[0] )
					Remote_CallFunction_NonReplay( player, "ServerCallback_SPEEDBALL_LastPlayer", player.GetTeam() != victim.GetTeam() )
			}
		}
	}
}

void function GiveFlag( entity player )
{
	file.flag.SetParent( player, "FLAG" )
	file.flagCarrier = player
	SetTeam( file.flag, player.GetTeam() )
	SetGlobalNetEnt( "flagCarrier", player )
	thread DropFlagIfPhased( player )
	
	EmitSoundOnEntityOnlyToPlayer( player, player, "UI_CTF_1P_GrabFlag" )
	foreach ( entity otherPlayer in GetPlayerArray() )
	{
		MessageToPlayer( otherPlayer, eEventNotifications.SPEEDBALL_FlagPickedUp, player )
		
		if ( otherPlayer.GetTeam() == player.GetTeam() )
			EmitSoundOnEntityToTeamExceptPlayer( file.flag, "UI_CTF_3P_TeamGrabFlag", player.GetTeam(), player )
	}
}

void function DropFlagIfPhased( entity player )
{
	player.EndSignal( "StartPhaseShift" )
	player.EndSignal( "OnDestroy" )
	
	OnThreadEnd( function() : ( player ) 
	{
		if ( file.flag.GetParent() == player )
			DropFlag()
	})
	
	while( file.flag.GetParent() == player )
		WaitFrame()
}

void function DropFlag()
{
	file.flag.ClearParent()
	file.flag.SetAngles( < 0, 0, 0 > )
	SetTeam( file.flag, TEAM_UNASSIGNED )
	SetGlobalNetEnt( "flagCarrier", file.flag )
	
	if ( IsValid( file.flagCarrier ) )
		EmitSoundOnEntityOnlyToPlayer( file.flagCarrier, file.flagCarrier, "UI_CTF_1P_FlagDrop" )
	
	foreach ( entity player in GetPlayerArray() )
		MessageToPlayer( player, eEventNotifications.SPEEDBALL_FlagDropped, file.flagCarrier )
	
	file.flagCarrier = null
}

void function CreateFlagIfNoFlagSpawnpoint()
{
	if ( IsValid( file.flag ) )
		return
	
	foreach ( entity hardpoint in GetEntArrayByClass_Expensive( "info_hardpoint" ) )
	{
		if ( GetHardpointGroup(hardpoint) == "B" )
		{
			CreateFlag( hardpoint )
			return
		}
	}
}

void function ResetFlag()
{
	file.flag.ClearParent()
	file.flag.SetAngles( < 0, 0, 0 > )
	file.flag.SetVelocity( < 0, 0, 1 > ) // hack: for some reason flag won't have gravity if i don't do this
	file.flag.SetOrigin( file.flagBase.GetOrigin() + < 0, 0, file.flagBase.GetBoundingMaxs().z * 2 > )
	SetTeam( file.flag, TEAM_UNASSIGNED )
	file.flagCarrier = null
	SetGlobalNetEnt( "flagCarrier", file.flag )
}

int function TimeoutCheckFlagHolder()
{
	if ( file.flagCarrier == null )
		return TEAM_UNASSIGNED
		
	return file.flagCarrier.GetTeam()
}

void function GamemodeSpeedball_OnWinnerDetermined()
{
	if(IsValid(file.flagCarrier))
		file.flagCarrier.AddToPlayerGameStat( PGS_ASSAULT_SCORE, 1 )
}

string function GetHardpointGroup(entity hardpoint) //Hardpoint Entity B on Homestead is missing the Hardpoint Group KeyValue
{
	if((GetMapName()=="mp_homestead")&&(!hardpoint.HasKey("hardpointGroup")))
		return "B"

	return string(hardpoint.kv.hardpointGroup)
}