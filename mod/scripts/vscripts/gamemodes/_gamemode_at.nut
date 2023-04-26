untyped // AddCallback_OnUseEntity() needs untyped
global function GamemodeAt_Init
global function RateSpawnpoints_AT

// bank settings
const float AT_BANK_OPENING_DURATION = 45.0
const int AT_BANK_UPLOAD_RATE = 10 // uploads 10$ per tick(0.1s)
const int AT_BANK_UPLOAD_RADIUS = 256

// wave settings
// general
const int AT_BOUNTY_TEAM = TEAM_BOTH // they can be attacked by both teams
const float FIRST_WAVE_START_DELAY = 10.0 // time before first wave starts, after intro end
const float WAVE_STATE_TRANSITION_TIME = 5.0 // time between each wave and bank opening/closing

// bounty boss titans
const float BOUNTY_TITAN_CHECK_DELAY = 10.0 // wait for bounty titans landing before we start checking their life state
const float BOUNTY_TITAN_HEALTH_MULTIPLIER = 3
const array<string> VALID_BOUNTY_TITAN_SETTINGS = // titans spawn in second half of a wave
[
	"npc_titan_atlas_stickybomb_bounty",
	"npc_titan_atlas_tracker_bounty",
	"npc_titan_ogre_minigun_bounty",
	"npc_titan_ogre_meteor_bounty",
	"npc_titan_stryder_leadwall_bounty",
	"npc_titan_stryder_sniper_bounty",
	"npc_titan_atlas_vanguard_bounty"
]



// IMPLEMENTATION NOTES:
// bounty hunt is a mode that was clearly pretty heavily developed, and had alot of scrapped concepts (i.e. most wanted player bounties, turret bounties, collectable blackbox objectives)
// in the interest of time, this script isn't gonna support any of that atm
// alot of the remote functions also take parameters that aren't used, i'm not gonna populate these and just use default values for now instead
// however, if you do want to mess with this stuff, almost all the remote functions for this stuff are still present in cl_gamemode_at, and should work fine with minimal fuckery in my experience

struct 
{
	array<entity> campsToRegisterOnEntitiesDidLoad

	array<entity> banks 
	array<AT_WaveOrigin> camps
	
	table<entity, bool> titanIsBountyBoss
	table<entity, int> bountyTitanRewards
	table<entity, bool> playerBankUploading
	table< entity, table<entity, int> > playerSavedBountyDamage
} file

void function GamemodeAt_Init()
{
	// wave
	RegisterSignal( "ATWaveEnd" )
	// camp
	RegisterSignal( "ATCampClean" )
	RegisterSignal( "ATAllCampsClean" )
	// bank
	RegisterSignal( "ATBankClosed" )

	AiGameModes_SetNPCWeapons( "npc_soldier", [ "mp_weapon_rspn101", "mp_weapon_dmr", "mp_weapon_r97", "mp_weapon_lmg" ] )
	AiGameModes_SetNPCWeapons( "npc_spectre", [ "mp_weapon_hemlok_smg", "mp_weapon_doubletake", "mp_weapon_mastiff" ] )
	AiGameModes_SetNPCWeapons( "npc_stalker", [ "mp_weapon_hemlok_smg", "mp_weapon_lstar", "mp_weapon_mastiff" ] )

	AddCallback_GameStateEnter( eGameState.Playing, AT_GameLoop )
	AddCallback_GameStateEnter( eGameState.Prematch, AT_ScoreEventsValueSetUp )
	AddCallback_OnClientConnected( InitialiseATPlayer )

	AddSpawnCallbackEditorClass( "info_target", "info_attrition_bank", CreateATBank )
	AddSpawnCallbackEditorClass( "info_target", "info_attrition_camp", CreateATCamp )
	AddCallback_EntitiesDidLoad( CreateATCamps_Delayed )

	AddDamageFinalCallback( "npc_titan", OnNPCTitanFinalDamaged )
	AddCallback_OnPlayerKilled( AT_PlayerOrNPCKilledScoreEvent )
	AddCallback_OnNPCKilled( AT_PlayerOrNPCKilledScoreEvent )
}

void function RateSpawnpoints_AT( int checkclass, array<entity> spawnpoints, int team, entity player )
{
	RateSpawnpoints_Generic( checkclass, spawnpoints, team, player ) // temp 
}

// world and player inits

void function InitialiseATPlayer( entity player )
{
	Remote_CallFunction_NonReplay( player, "ServerCallback_AT_OnPlayerConnected" )
	player.SetPlayerNetInt( "AT_bonusPointMult", 1 ) // for damage score popups
	file.playerBankUploading[ player ] <- false
	file.playerSavedBountyDamage[ player ] <- {}
	thread AT_PlayerTitleThink( player )
	thread AT_PlayerObjectiveThink( player )
}

void function AT_PlayerTitleThink( entity player )
{
	player.EndSignal( "OnDestroy" )

	while ( true )
	{
		if ( GetGameState() == eGameState.Playing )
			player.SetTitle( "$" + string( AT_GetPlayerBonusPoints( player ) ) )
		else if ( GetGameState() >= eGameState.WinnerDetermined )
		{
			if ( player.IsTitan() )
				player.SetTitle( GetTitanPlayerTitle( player ) )
			else
				player.SetTitle( "" )
			return
		}

		WaitFrame()
	}
}

string function GetTitanPlayerTitle( entity player )
{
	entity soul = player.GetTitanSoul()
	if ( !IsValid( soul ) )
		return ""
	string settings = GetSoulPlayerSettings( soul )
	var title = GetPlayerSettingsFieldForClassName( settings, "printname" )

	if ( title == null )
		return ""
	
	return expect string( title )
}

const int OBJECTIVE_EMPTY = -1 // remove objective
const int OBJECTIVE_KILL_DZ = 104 // #AT_OBJECTIVE_KILL_DZ
const int OBJECTIVE_KILL_DZ_MULTI = 105 // #AT_OBJECTIVE_KILL_DZ_MULTI
const int OBJECTIVE_KILL_BOSS = 106 // #AT_OBJECTIVE_KILL_BOSS
const int OBJECTIVE_KILL_BOSS_MULTI = 107 // s#AT_OBJECTIVE_KILL_BOSS_MULTI
const int OBJECTIVE_BANK_OPEN = 109 // #AT_BANK_OPEN_OBJECTIVE

void function AT_PlayerObjectiveThink( entity player )
{
	player.EndSignal( "OnDestroy" )

	int curObjective = OBJECTIVE_EMPTY
	while ( true )
	{
		WaitFrame()
		// game entered other state
		if ( GetGameState() >= eGameState.WinnerDetermined )
		{
			player.SetPlayerNetInt( "gameInfoStatusText", OBJECTIVE_EMPTY )
			return
		}

		int nextObjective = OBJECTIVE_EMPTY

		if ( !IsAlive( player ) ) // don't show objetive for dying players
			nextObjective = OBJECTIVE_EMPTY
		else // player still alive
		{
			// banking check
			if ( GetGlobalNetBool( "banksOpen" ) )
				nextObjective = OBJECTIVE_BANK_OPEN
			else if ( GetGlobalNetBool( "preBankPhase" ) )
				nextObjective = OBJECTIVE_EMPTY
			else // combat
			{
				int dropZoneActiveCount = 0
				int bossAliveCount = 0
				array<entity> campEnts
				campEnts.append( GetGlobalNetEnt( "camp1Ent" ) )
				campEnts.append( GetGlobalNetEnt( "camp2Ent" ) )
				foreach ( entity ent in campEnts )
				{
					if ( IsValid( ent ) )
					{
						if ( ent.IsTitan() )
							bossAliveCount += 1
						else
							dropZoneActiveCount += 1
					}
				}
				switch( dropZoneActiveCount )
				{
					case 0:
						break
					case 1:
						nextObjective = OBJECTIVE_KILL_DZ
						break
					case 2:
						nextObjective = OBJECTIVE_KILL_DZ_MULTI
						break
				}
				switch( bossAliveCount )
				{
					case 0:
						break
					case 1:
						nextObjective = OBJECTIVE_KILL_BOSS
						break
					case 2:
						nextObjective = OBJECTIVE_KILL_BOSS_MULTI
						break
				}

				// cannot find any combat objective
				if ( dropZoneActiveCount == 0 && bossAliveCount == 0 )
					nextObjective = OBJECTIVE_EMPTY
			}
		}

		// set up objective, try not to overloop too much
		if ( curObjective != nextObjective )
		{
			player.SetPlayerNetInt( "gameInfoStatusText", nextObjective )
			curObjective = nextObjective
		}
	}
}

void function CreateATBank( entity spawnpoint )
{
	entity bank = CreatePropScript( spawnpoint.GetModelName(), spawnpoint.GetOrigin(), spawnpoint.GetAngles(), SOLID_VPHYSICS )
	bank.SetScriptName( "AT_Bank" )
	// init minimap icon, we show them when active
	bank.Minimap_SetCustomState( eMinimapObject_prop_script.AT_BANK )
	bank.Minimap_SetAlignUpright( true )
	bank.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	bank.Minimap_Hide( TEAM_IMC, null )
	bank.Minimap_Hide( TEAM_MILITIA, null )
	
	// create tracker ent
	// we don't need to store these at all, client just needs to get them
	DispatchSpawn( GetAvailableBankTracker( bank ) )
	
	thread PlayAnim( bank, "mh_inactive_idle" )
	// add usecallback to it and unset usable
	AddCallback_OnUseEntity( bank, OnPlayerUseBank )
	bank.UnsetUsable()
	
	file.banks.append( bank )
}

void function CreateATCamp( entity spawnpoint )
{
	// delay this so we don't do stuff before all spawns are initialised and that
	file.campsToRegisterOnEntitiesDidLoad.append( spawnpoint )
}

void function CreateATCamps_Delayed()
{
	// we delay registering camps until EntitiesDidLoad since they rely on spawnpoints and stuff, which might not all be ready in the creation callback
	// unsure if this would be an issue in practice, but protecting against it in case it would be
	foreach ( entity camp in file.campsToRegisterOnEntitiesDidLoad )
	{
		AT_WaveOrigin campStruct
		campStruct.ent = camp
		campStruct.origin = camp.GetOrigin()
		campStruct.radius = expect string( camp.kv.radius ).tofloat()
		campStruct.height = expect string( camp.kv.height ).tofloat()
		
		// assumes every info_attrition_camp will have all 9 phases, possibly not a good idea?
		for ( int i = 0; i < 9; i++ )
			campStruct.phaseAllowed.append( expect string( camp.kv[ "phase_" + ( i + 1 ) ] ) == "1" )
		
		// get droppod spawns
		foreach ( entity spawnpoint in SpawnPoints_GetDropPod() )
		{
			vector campPos = camp.GetOrigin()
			vector spawnPos = spawnpoint.GetOrigin()
			if ( Distance( campPos, spawnPos ) < campStruct.radius && fabs( campPos.z - spawnPos.z ) < campStruct.height )
				campStruct.dropPodSpawnPoints.append( spawnpoint )
		}
		
		// get titan spawns
		foreach ( entity spawnpoint in SpawnPoints_GetTitan() )
		{
			vector campPos = camp.GetOrigin()
			vector spawnPos = spawnpoint.GetOrigin()
			if ( Distance( campPos, spawnPos ) < campStruct.radius && fabs( campPos.z - spawnPos.z ) < campStruct.height )
				campStruct.titanSpawnPoints.append( spawnpoint )
		}
	
		// todo: turret spawns someday maybe
	
		file.camps.append( campStruct )
	}
	
	file.campsToRegisterOnEntitiesDidLoad.clear()
}

// scoring funcs
void function AT_ScoreEventsValueSetUp()
{
	// combat
	ScoreEvent_SetEarnMeterValues( "AttritionTitanKilled", 0.20, 0.10 )
	ScoreEvent_SetEarnMeterValues( "AttritionPilotKilled", 0.10, 0.10 )
	ScoreEvent_SetEarnMeterValues( "AttritionBossKilled", 0.20, 0.10 )
	ScoreEvent_SetEarnMeterValues( "AttritionGruntKilled", 0.02, 0.02, 0.5 )
	ScoreEvent_SetEarnMeterValues( "AttritionSpectreKilled", 0.02, 0.02, 0.5 )
	ScoreEvent_SetEarnMeterValues( "AttritionStalkerKilled", 0.02, 0.02, 0.5 )
	ScoreEvent_SetEarnMeterValues( "AttritionSuperSpectreKilled", 0.10, 0.10, 0.5 )
}

void function AT_PlayerOrNPCKilledScoreEvent( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( attacker ) || !attacker.IsPlayer() )
		return
	if ( attacker == victim )
		return
	if ( victim.IsTitan() && GetPetTitanOwner( victim ) == attacker )
		return
	
	string eventName = GetAttritionScoreEventName( victim.GetClassName() )
	if ( victim.IsTitan() ) // titan specific
		eventName = GetAttritionScoreEventNameFromAI( victim )
	if ( eventName == "" ) // no valid scoreEvent
		return
	int scoreVal = ScoreEvent_GetPointValue( GetScoreEvent( eventName ) )
	//print( "eventName: " + eventName )

	// pet titan check
	if ( victim.IsTitan() && IsValid( GetPetTitanOwner( victim ) ) )
		scoreVal = ATTRITION_SCORE_TITAN_MIN

	// killed npc
	if ( !victim.IsPlayer() )
	{
		AT_AddPlayerBonusPointsForEntityKilled( attacker, scoreVal, damageInfo )
		AddPlayerScore( attacker, eventName ) // we add scoreEvent here, since basic score events has been overwrited by sh_gamemode_at.nut
		// update score difference
		AddTeamScore( attacker.GetTeam(), scoreVal )
		// add to scoreboard
		attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, scoreVal )
	}

	// bonus stealing check
	if ( victim.IsPlayer() )
		AT_TryStealPlayerBonusPoints( attacker, victim, damageInfo )
}

bool function AT_TryStealPlayerBonusPoints( entity attacker, entity victim, var damageInfo )
{
	if ( !victim.IsPlayer() )
		return false
	
	int victimBonus = AT_GetPlayerBonusPoints( victim )
	int minScoreCanSteal = ATTRITION_SCORE_PILOT_MIN
	if ( victim.IsTitan() )
		minScoreCanSteal = ATTRITION_SCORE_TITAN_MIN

	int bonusToSteal = victimBonus / 2
	int attackerScore = bonusToSteal
	bool realStealBonus = true
	if ( bonusToSteal <= minScoreCanSteal ) // no enough bonus to steal
	{
		attackerScore = minScoreCanSteal // give attacker min bonus
		realStealBonus = false // we don't do attacker steal events below, just half victim's bonus
	}

	// servercallback
	int victimEHandle = victim.GetEncodedEHandle()
	vector damageOrigin = DamageInfo_GetDamagePosition( damageInfo )
	// only do attacker events if victim has enough bonus to steal
	if ( realStealBonus )
	{
		Remote_CallFunction_NonReplay( 
			attacker, 
			"ServerCallback_AT_PlayerKillScorePopup",
			// basically damage table as parameters
			bonusToSteal,
			victimEHandle,
			damageOrigin.x,
			damageOrigin.y,
			damageOrigin.z
		)
	}
	else // otherwise we do a normal entity killed scoreEvent
		AT_AddPlayerBonusPointsForEntityKilled( attacker, attackerScore, damageInfo )
	
	// update score difference
	AddTeamScore( attacker.GetTeam(), minScoreCanSteal )
	// add to scoreboard
	attacker.AddToPlayerGameStat( PGS_ASSAULT_SCORE, minScoreCanSteal )

	// victim stolen popup
	Remote_CallFunction_NonReplay( 
		victim, 
		"ServerCallback_AT_ShowStolenBonus",
		bonusToSteal
	)

	// steal bonus
	AT_AddPlayerBonusPoints( victim, -bonusToSteal )
	// only do attacker events if victim has enough bonus to steal
	if ( realStealBonus )
	{
		AT_AddPlayerBonusPoints( attacker, bonusToSteal )
		AddPlayerScore( attacker, "AttritionBonusStolen" )
	}
	
	return realStealBonus
}

// bonus points, players earn from killing
void function AT_AddPlayerBonusPoints( entity player, int amount )
{
	// add to scoreboard
	player.AddToPlayerGameStat( PGS_SCORE, amount )
	AT_SetPlayerBonusPoints( player, player.GetPlayerNetInt( "AT_bonusPoints" ) + ( player.GetPlayerNetInt( "AT_bonusPoints256" ) * 256 ) + amount )
}

int function AT_GetPlayerBonusPoints( entity player )
{
	return player.GetPlayerNetInt( "AT_bonusPoints" ) + player.GetPlayerNetInt( "AT_bonusPoints256" ) * 256
}

void function AT_SetPlayerBonusPoints( entity player, int amount )
{
	// split into stacks of 256 where necessary
	int stacks = amount / 256 // automatically rounds down because int division

	player.SetPlayerNetInt( "AT_bonusPoints256", stacks )
	player.SetPlayerNetInt( "AT_bonusPoints", amount - stacks * 256 )
}

// total points, the value player actually uploaded to team score
void function AT_AddPlayerTotalPoints( entity player, int amount )
{
	// update score difference, using this means player has upload the points to game score
	AddTeamScore( player.GetTeam(), amount )
	// add to scoreboard
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, amount )
	AT_SetPlayerTotalPoints( player, player.GetPlayerNetInt( "AT_totalPoints" ) + ( player.GetPlayerNetInt( "AT_totalPoints256" ) * 256 ) + amount )
}

void function AT_SetPlayerTotalPoints( entity player, int amount )
{
	// split into stacks of 256 where necessary
	int stacks = amount / 256 // automatically rounds down because int division

	player.SetPlayerNetInt( "AT_totalPoints256", stacks )
	player.SetPlayerNetInt( "AT_totalPoints", amount - stacks * 256 )
}

// earn points, seems not used
void function AT_AddPlayerEarnedPoints( entity player, int amount )
{
	AT_SetPlayerBonusPoints( player, player.GetPlayerNetInt( "AT_earnedPoints" ) + ( player.GetPlayerNetInt( "AT_earnedPoints256" ) * 256 ) + amount )
}

void function AT_SetPlayerEarnedPoints( entity player, int amount )
{
	// split into stacks of 256 where necessary
	int stacks = amount / 256 // automatically rounds down because int division

	player.SetPlayerNetInt( "AT_earnedPoints256", stacks )
	player.SetPlayerNetInt( "AT_earnedPoints", amount - stacks * 256 )
}

// damaging bounty
void function AT_AddPlayerBonusPointsForBossDamaged( entity player, entity victim, int amount, var damageInfo )
{
	AT_AddPlayerBonusPoints( player, amount )
	// update score difference
	AddTeamScore( player.GetTeam(), amount )
	// add to scoreboard
	player.AddToPlayerGameStat( PGS_ASSAULT_SCORE, amount )

	// send servercallback for damaging
	int bossEHandle = victim.GetEncodedEHandle()
	vector damageOrigin = DamageInfo_GetDamagePosition( damageInfo )

	Remote_CallFunction_NonReplay( 
		player, 
		"ServerCallback_AT_BossDamageScorePopup",
		// popup
		amount,
		amount,
		bossEHandle,
		damageOrigin.x,
		damageOrigin.y,
		damageOrigin.z
	)
}

void function AT_AddPlayerBonusPointsForEntityKilled( entity player, int amount, var damageInfo )
{
	AT_AddPlayerBonusPoints( player, amount )

	// send servercallback for damaging
	int attackerEHandle = player.GetEncodedEHandle()
	vector damageOrigin = DamageInfo_GetDamagePosition( damageInfo )
	int damageType = DamageInfo_GetCustomDamageType( damageInfo )
	
	Remote_CallFunction_NonReplay( 
		player, 
		"ServerCallback_AT_ShowATScorePopup",
		attackerEHandle,
		// popup
		amount,
		amount,
		damageOrigin.x,
		damageOrigin.y,
		damageOrigin.z,
		damageType
	)
}

// run gamestate

void function AT_GameLoop()
{
	thread AT_GameLoop_Threaded()
}

void function AT_GameLoop_Threaded()
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	
	// game end func
	OnThreadEnd
	( 
		function()
		{
			// prevent crash before entity creation on map change
			if ( GetGameState() >= eGameState.Prematch )
			{
				SetGlobalNetBool( "preBankPhase", false )
				SetGlobalNetBool( "banksOpen", false )
			}
		}
	)
	
	wait FIRST_WAVE_START_DELAY - WAVE_STATE_TRANSITION_TIME // initial wait before first wave
	
	int lastWaveId = -1
	for ( int waveCount = 1; ; waveCount++  )
	{
		wait WAVE_STATE_TRANSITION_TIME
	
		// cap to number of real waves
		int waveId = ( waveCount - 1 ) / 2
		// last wave is clearly unfinished so don't use, just cap to last actually used one
		if ( waveId >= GetWaveDataSize() - 1 )
		{
			waveId = GetWaveDataSize() - 2	
			waveCount = waveId * 2
		}

		// new wave dialogue
		bool waveChanged = lastWaveId != waveId
		if ( waveChanged )
		{
			PlayFactionDialogueToTeam( "bh_newWave", TEAM_IMC )
			PlayFactionDialogueToTeam( "bh_newWave", TEAM_MILITIA )
		}
		else // same wave, second half
		{
			PlayFactionDialogueToTeam( "bh_incoming", TEAM_IMC )
			PlayFactionDialogueToTeam( "bh_incoming", TEAM_MILITIA )
		}
		lastWaveId = waveId
			
		SetGlobalNetInt( "AT_currentWave", waveId )
		bool isBossWave = waveCount % 2 == 0 // even number waveCount means boss wave
		
		// announce the wave 
		foreach ( entity player in GetPlayerArray() )
		{
			if ( isBossWave )
				Remote_CallFunction_NonReplay( player, "ServerCallback_AT_AnnounceBoss" )
			else
			{
				Remote_CallFunction_NonReplay( 
					player, 
					"ServerCallback_AT_AnnouncePreParty", 
					0.0, // useless parameter
					waveId 
				)
			}
		}
		
		wait WAVE_STATE_TRANSITION_TIME
		
		// run the wave
		thread AT_CampSpawnThink( waveId, isBossWave )

		if ( !isBossWave )
			svGlobal.levelEnt.WaitSignal( "ATAllCampsClean" ) // signaled when all camps cleaned in spawn functions
		else
		{
			wait BOUNTY_TITAN_CHECK_DELAY
			// wait until all bounty titans killed
			while ( IsAlive( GetGlobalNetEnt( "camp1Ent" ) ) || IsAlive( GetGlobalNetEnt( "camp2Ent" ) ) )
				WaitFrame()
		}

		// wave end, prebank phase
		svGlobal.levelEnt.Signal( "ATWaveEnd" ) // destroy existing campEnts
		SetGlobalNetBool( "preBankPhase", true )
		// announce wave end
		foreach ( entity player in GetPlayerArray() )
		{
			Remote_CallFunction_NonReplay( 
				player, 
				"ServerCallback_AT_AnnounceWaveOver",
				waveId, // wave id
				// below are useless parameters
				0,
				0,
				0,
				0,
				0,
				0
			)
		}

		wait WAVE_STATE_TRANSITION_TIME
		
		// banking phase
		SetGlobalNetBool( "preBankPhase", false )
		SetGlobalNetTime( "AT_bankStartTime", Time() )
		SetGlobalNetTime( "AT_bankEndTime", Time() + AT_BANK_OPENING_DURATION )
		SetGlobalNetBool( "banksOpen", true )

		foreach ( entity player in GetPlayerArray() )
			Remote_CallFunction_NonReplay( player, "ServerCallback_AT_BankOpen" )

		foreach ( entity bank in file.banks )
			thread AT_BankActiveThink( bank )

		wait AT_BANK_OPENING_DURATION
		
		SetGlobalNetBool( "banksOpen", false )
		foreach ( entity player in GetPlayerArray() )
			Remote_CallFunction_NonReplay( player, "ServerCallback_AT_BankClose" )
		// new wave begins after here
	}
}

// camp spawn
void function AT_CampSpawnThink( int waveId, bool isBossWave )
{
	AT_WaveData wave = GetWaveData( waveId )
	array< array<AT_SpawnData> > campSpawnData

	if ( isBossWave )
		campSpawnData = wave.bossSpawnData
	else
		campSpawnData = wave.spawnDataArrays
	

	int totalCampUse = waveId == 0 ? 1 : 2  //campSpawnData.len() // don't know how to get this
	//print( "totalCampUse: " + string( totalCampUse ) )

	for ( int campId = 0; campId < totalCampUse; campId++ )
	{
		array<AT_SpawnData> curSpawnData = campSpawnData[ campId ]
		int spawnId = campId
		if ( totalCampUse == 1 ) // if we only used 1 camp, pick a random position
			spawnId = RandomInt( campSpawnData.len() )

		int totalNPCsToSpawn = 0
		// initialise pending spawns and get total npcs
		foreach ( AT_SpawnData spawnData in curSpawnData )
		{
			spawnData.pendingSpawns = spawnData.totalToSpawn
			// add to network variables
			string npcNetVar = GetNPCNetVarName( spawnData.aitype, campId )
			SetGlobalNetInt( npcNetVar, spawnData.totalToSpawn )
			//print( "Setting " + npcNetVar + " to " + string( GetGlobalNetInt( npcNetVar ) ) )

			totalNPCsToSpawn += spawnData.totalToSpawn
		}
		//print( "totalNPCsToSpawn: " + string( totalNPCsToSpawn ) )

		if ( !isBossWave ) 
		{
			// camp Ent, boss wave will use boss themselves as campEnt
			string campEntVarName = "camp" + string( campId + 1 ) + "Ent"
			bool waveNotActive = GetGlobalNetBool( "preBankPhase" ) || GetGlobalNetBool( "banksOpen" )
			if ( !IsValid( GetGlobalNetEnt( campEntVarName ) ) && !waveNotActive )
				SetGlobalNetEnt( campEntVarName, CreateCampTracker( file.camps[ spawnId ], campId ) )
			
			foreach ( AT_SpawnData data in curSpawnData )
			{
				switch ( data.aitype )
				{
					case "npc_soldier":
					case "npc_spectre":
					case "npc_stalker":
						thread AT_DroppodSquadEvent( spawnId, data )
						break
					
					case "npc_super_spectre":
						thread AT_ReaperEvent( spawnId, data )
						break
				}
			}

			// use campProgressThink for handling wave state
			thread CampProgressThink( campId, totalNPCsToSpawn )
		}
		else // bosswave spawn
		{
			foreach ( AT_SpawnData data in curSpawnData )
			{
				switch ( data.aitype )
				{
					case "npc_titan":
						thread AT_BountyTitanEvent( spawnId, data )
						break
				}
			}
		}
	}
}

void function CampProgressThink( int campId, int totalNPCsToSpawn )
{
	string campLetter = GetCampLetter( campId )
	string campProgressName = campLetter + "campProgress"
	string campEntVarName = "camp" + string( campId + 1 ) + "Ent"

	// initial wait
	SetGlobalNetFloat( campProgressName, 1.0 )
	wait 3.0
	while ( true )
	{
		int npcsLeft
		// get all npcs might be in this camp
		for ( int i = 0; i < 5; i++ )
		{
			string netVarName = string( i + 1 ) + campLetter + "campCount"
			int netVarValue = GetGlobalNetInt( netVarName )
			if ( netVarValue >= 0 ) // network vars starts from 0
				npcsLeft += netVarValue
		}
		//print( "npcsLeft: " + string( npcsLeft ) )

		float campLeft = float( npcsLeft ) / float( totalNPCsToSpawn )
		//print( "campLeft: " + string( campLeft ) )
		SetGlobalNetFloat( campProgressName, campLeft )

		if ( campLeft <= 0.0 ) // camp wiped!
		{
			//print( "Camp " + campLetter + " has been wiped!" )
			PlayFactionDialogueToTeam( "bh_cleared" + campLetter, TEAM_IMC )
			PlayFactionDialogueToTeam( "bh_cleared" + campLetter, TEAM_MILITIA )

			entity campEnt = GetGlobalNetEnt( campEntVarName )
			if ( IsValid( campEnt ) )
				campEnt.Signal( "ATCampClean" ) // destroy the camp ent
			// check if both camps being destroyed
			if ( !IsValid( GetGlobalNetEnt( "camp1Ent" ) ) && !IsValid( GetGlobalNetEnt( "camp2Ent" ) ) )
				svGlobal.levelEnt.Signal( "ATAllCampsClean" ) // end the wave
			return
		}

		WaitFrame()
	}
}

// entity funcs
// camp
entity function CreateCampTracker( AT_WaveOrigin campData, int campId )
{
	// store data
	vector campOrigin = campData.origin
	float campRadius = campData.radius
	float campHeight = campData.height
	// add a minimap icon
	entity mapIconEnt = CreateEntity( "prop_script" )
	DispatchSpawn( mapIconEnt )

	mapIconEnt.SetOrigin( campOrigin )
	mapIconEnt.DisableHibernation()
	SetTeam( mapIconEnt, AT_BOUNTY_TEAM )
	mapIconEnt.Minimap_AlwaysShow( TEAM_IMC, null )
	mapIconEnt.Minimap_AlwaysShow( TEAM_MILITIA, null )

	// hardcoded
	int campMinimapState
	switch ( campId )
	{
		case 0:
			campMinimapState = eMinimapObject_prop_script.AT_DROPZONE_A
			break
		case 1:
			campMinimapState = eMinimapObject_prop_script.AT_DROPZONE_B
			break
		case 2:
			campMinimapState = eMinimapObject_prop_script.AT_DROPZONE_C
			break
	}
	mapIconEnt.Minimap_SetCustomState( campMinimapState )
	mapIconEnt.Minimap_SetAlignUpright( true )
	mapIconEnt.Minimap_SetZOrder( MINIMAP_Z_OBJECT )
	mapIconEnt.Minimap_SetObjectScale( campRadius / 16000.0 ) // proper icon on the map

	// attach a location tracker
	entity tracker = GetAvailableLocationTracker()
	tracker.SetOwner( mapIconEnt ) // needs a owner to show up
	tracker.SetOrigin( campOrigin )
	SetLocationTrackerRadius( tracker, campRadius )
	SetLocationTrackerID( tracker, campId )
	DispatchSpawn( tracker )

	thread TrackWaveEndForCampInfo( tracker, mapIconEnt )
	return tracker
}

void function TrackWaveEndForCampInfo( entity tracker, entity mapIconEnt )
{
	tracker.EndSignal( "OnDestroy" )
	tracker.EndSignal( "ATCampClean" )

	OnThreadEnd
	(
		function(): ( tracker, mapIconEnt )
		{
			// camp cleaned, wave or game ended, destroy the camp info
			if ( IsValid( tracker ) )
				tracker.Destroy()
			if ( IsValid( mapIconEnt ) )
				mapIconEnt.Destroy()
		}
	)

	WaitSignal( svGlobal.levelEnt, "GameStateChanged", "ATWaveEnd" )
}

// bank
void function AT_BankActiveThink( entity bank )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )
	bank.EndSignal( "OnDestroy" )
	
	// bank closed!
	OnThreadEnd
	(
		function(): ( bank )
		{
			if ( IsValid( bank ) )
			{
				bank.Signal( "ATBankClosed" )
				// disable bank usage
				bank.UnsetUsable()
				thread PlayAnim( bank, "mh_active_2_inactive" )
				FadeOutSoundOnEntity( bank, "Mobile_Hardpoint_Idle", 0.5 )
				// hide on minimap
				bank.Minimap_Hide( TEAM_IMC, null )
				bank.Minimap_Hide( TEAM_MILITIA, null )
			}
		}
	)

	// make bank usable
	bank.SetUsable()
	bank.SetUsePrompts( "#AT_USE_BANK", "#AT_USE_BANK_PC" )
	thread PlayAnim( bank, "mh_inactive_2_active" )
	EmitSoundOnEntity( bank, "Mobile_Hardpoint_Idle" )

	// show minimap icon for bank
	bank.Minimap_AlwaysShow( TEAM_IMC, null )
	bank.Minimap_AlwaysShow( TEAM_MILITIA, null )
	bank.Minimap_SetCustomState( eMinimapObject_prop_script.AT_BANK )
	
	// wait for bank close or game end
	while ( GetGlobalNetBool( "banksOpen" ) )
		WaitFrame()
}

function OnPlayerUseBank( bank, player )
{
	expect entity( bank )
	expect entity( player )

	// no bonus!
	if ( AT_GetPlayerBonusPoints( player ) == 0 )
	{
		SendHudMessage( player, "#AT_USE_BANK_NO_BONUS_HINT", -1, 0.4, 255, 255, 255, 255, 0.5, 1.0, 0.5 )
		return
	}

	thread PlayerUploadingBonus( bank, player )
}

void function PlayerUploadingBonus( entity bank, entity player )
{
	if ( file.playerBankUploading[ player ] )
		return

	bank.EndSignal( "OnDestroy" )
	bank.EndSignal( "ATBankClosed" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	// mark as player uploading, so they can't use the bank multiple times
	file.playerBankUploading[ player ] = true

	table results =
	{
		depositedPoints = 0
	}

	OnThreadEnd
	(
		function(): ( player, results )
		{
			if ( IsValid( player ) )
			{
				file.playerBankUploading[ player ] = false
				// clean up looping sound
				StopSoundOnEntity( player, "HUD_MP_BountyHunt_BankBonusPts_Ticker_Loop_1P" )
				StopSoundOnEntity( player, "HUD_MP_BountyHunt_BankBonusPts_Ticker_Loop_3P" )

				// do medal event
				AddPlayerScore( player, "AttritionCashedBonus" )
				// do server callback
				Remote_CallFunction_NonReplay( 
					player, 
					"ServerCallback_AT_FinishDeposit",
					expect int( results.depositedPoints )
				)

				player.SetPlayerNetBool( "AT_playerUploading", false )

				if ( IsAlive( player ) ) // player still alive
				{
					// emit uploading successful sound
					EmitSoundOnEntityOnlyToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Deposit_End_Successful_1P" )
					EmitSoundOnEntityOnlyToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Deposit_End_Successful_3P" )
				}
				else // player killed while uploading
				{
					// emit uploading failed sound
					EmitSoundOnEntityOnlyToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Deposit_End_Unsuccessful_1P" )
					EmitSoundOnEntityOnlyToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Deposit_End_Unsuccessful_3P" )
				}
			}
		}
	)

	// this will move point value position
	Remote_CallFunction_NonReplay( player, "ServerCallback_AT_ShowRespawnBonusLoss" )

	// uploading start sound
	EmitSoundOnEntityOnlyToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Deposit_Start_1P" )
	EmitSoundOnEntityExceptToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Deposit_Start_3P" )
	EmitSoundOnEntityOnlyToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Ticker_Loop_1P" )
	EmitSoundOnEntityExceptToPlayer( player, player, "HUD_MP_BountyHunt_BankBonusPts_Ticker_Loop_3P" )

	player.SetPlayerNetBool( "AT_playerUploading", true )
	//AT_AddPlayerEarnedPoints( player, AT_GetPlayerBonusPoints( player ) ) // earned points, seems unused
	// uploading bonus
	while ( Distance( player.GetOrigin(), bank.GetOrigin() ) <= AT_BANK_UPLOAD_RADIUS )
	{
		int bonusToUpload = int( min( AT_BANK_UPLOAD_RATE, AT_GetPlayerBonusPoints( player ) ) )
		if ( bonusToUpload == 0 ) // no bonus left
			return

		AT_AddPlayerBonusPoints( player, -bonusToUpload )
		// add to total points
		AT_AddPlayerTotalPoints( player, bonusToUpload )

		results.depositedPoints += bonusToUpload
		WaitFrame()
	}
}

// npcs
int function GetScriptManagedNPCArrayLength_Alive( int scriptManagerId )
{
	array<entity> entities = GetScriptManagedEntArray( scriptManagerId )
	entities.removebyvalue( null )
	int npcsAlive = 0
	foreach ( entity ent in entities )
	{
		if ( IsAlive( ent ) && ent.IsNPC() )
			npcsAlive += 1
	}
	return npcsAlive
}

void function AT_DroppodSquadEvent( int campId, AT_SpawnData data )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	// get ent and create a script managed array for current event
	string ent = data.aitype
	int eventManager = CreateScriptManagedEntArray()
	
	int spawnedNPCs = 0
	int totalNPCsToSpawn = data.totalToSpawn
	int totalAllowedOnField = data.totalAllowedOnField
	while ( true )
	{
		waitthread AT_SpawnDroppodSquad( campId, ent, eventManager )
		spawnedNPCs += 4
		if ( spawnedNPCs >= totalNPCsToSpawn ) // we have reached max npcs
			return // stop any spawning functions

		int npcOnFieldCount = GetScriptManagedNPCArrayLength_Alive( eventManager )
		//print( "npcOnFieldCount: " + string( npcOnFieldCount ) )
		while ( npcOnFieldCount > totalAllowedOnField - 4 ) // wait until we have less npcs than allowed count
		{
			WaitFrame()
			npcOnFieldCount = GetScriptManagedNPCArrayLength_Alive( eventManager )
		}
	}
}

void function AT_SpawnDroppodSquad( int campId, string aiType, int scriptManagerId )
{
	entity spawnpoint
	if ( file.camps[ campId ].dropPodSpawnPoints.len() == 0 )
		spawnpoint = file.camps[ campId ].ent
	else
		spawnpoint = file.camps[ campId ].dropPodSpawnPoints.getrandom()
	// anti-crash
	if ( !IsValid( spawnpoint ) )
		spawnpoint = file.camps[ campId ].ent
	
	// add variation to spawns
	wait RandomFloat( 1.0 )
	
	AiGameModes_SpawnDropPod( 
		spawnpoint.GetOrigin(), 
		spawnpoint.GetAngles(), 
		AT_BOUNTY_TEAM, 
		aiType, 
		// squad handler
		void function( array<entity> guys ) : ( campId, aiType, scriptManagerId ) 
		{
			AT_HandleSquadSpawn( guys, campId, aiType, scriptManagerId )
		}
	)
}

void function AT_HandleSquadSpawn( array<entity> guys, int campId, string aiType, int scriptManagerId )
{
	foreach ( entity guy in guys )
	{
		guy.EnableNPCFlag( NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
		guy.DisableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE ) // no patrol and investigate allowed, avoid them running around

		// tracking lifetime
		AddToScriptManagedEntArray( scriptManagerId, guy )
		thread AT_TrackNPCLifeTime( guy, campId, aiType )

		// at least don't let them running around
		float radius = file.camps[ campId ].radius
		thread AT_ForceAssaultAroundSpawn( guy, radius )
	}
}

void function AT_ForceAssaultAroundSpawn( entity guy, float maxRadius = 1200.0 )
{
	guy.EndSignal( "OnDestroy" )
	guy.EndSignal( "OnDeath" )

	vector spawnPos = guy.GetOrigin()
	// goal radius check
	float goalRadius = maxRadius / 2
	float guyGoalRadius = guy.GetMinGoalRadius()
	if ( guyGoalRadius > goalRadius ) // this npc cannot use forced goal radius?
		goalRadius = guyGoalRadius
	while( true )
	{
		guy.AssaultPoint( spawnPos )
		guy.AssaultSetGoalRadius( goalRadius )
		guy.AssaultSetFightRadius( goalRadius / 2 )

		wait RandomFloatRange( 10, 15 ) // make randomness
	}
}

void function AT_ReaperEvent( int campId, AT_SpawnData data )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	// create a script managed array for current event
	int eventManager = CreateScriptManagedEntArray()
	
	int spawnedNPCs = 0
	int totalNPCsToSpawn = data.totalToSpawn
	int totalAllowedOnField = data.totalAllowedOnField
	while ( true )
	{
		waitthread AT_SpawnReaper( campId, eventManager )
		spawnedNPCs += 1
		if ( spawnedNPCs >= totalNPCsToSpawn ) // we have reached max npcs
			return // stop any spawning functions

		int npcOnFieldCount = GetScriptManagedNPCArrayLength_Alive( eventManager )
		//print( "npcOnFieldCount: " + string( npcOnFieldCount ) )
		while ( npcOnFieldCount > totalAllowedOnField ) // wait until we have less npcs than allowed count
		{
			WaitFrame()
			npcOnFieldCount = GetScriptManagedNPCArrayLength_Alive( eventManager )
		}
	}
}

void function AT_SpawnReaper( int campId, int scriptManagerId )
{
	entity spawnpoint
	if ( file.camps[ campId ].dropPodSpawnPoints.len() == 0 )
		spawnpoint = file.camps[ campId ].ent
	else
		spawnpoint = file.camps[ campId ].titanSpawnPoints.getrandom()
	// anti-crash
	if ( !IsValid( spawnpoint ) )
		spawnpoint = file.camps[ campId ].ent

	// add variation to spawns
	wait RandomFloat( 1.0 )
	
	AiGameModes_SpawnReaper( 
		spawnpoint.GetOrigin(), 
		spawnpoint.GetAngles(), 
		AT_BOUNTY_TEAM, 
		"npc_super_spectre_aitdm", 
		// reaper handler
		void function( entity reaper ) : ( campId, scriptManagerId ) 
		{
			AT_HandleReaperSpawn( reaper, campId, scriptManagerId )
		}
	)
}

void function AT_HandleReaperSpawn( entity reaper, int campId, int scriptManagerId )
{
	// tracking lifetime
	AddToScriptManagedEntArray( scriptManagerId, reaper )
	thread AT_TrackNPCLifeTime( reaper, campId, "npc_super_spectre" )

	// at least don't let them running around
	float radius = file.camps[ campId ].radius
	thread AT_ForceAssaultAroundSpawn( reaper, radius )
}

void function AT_BountyTitanEvent( int campId, AT_SpawnData data )
{
	svGlobal.levelEnt.EndSignal( "GameStateChanged" )

	// create a script managed array for current event
	int eventManager = CreateScriptManagedEntArray()
	
	int spawnedNPCs = 0
	int totalNPCsToSpawn = data.totalToSpawn
	int totalAllowedOnField = data.totalAllowedOnField
	while ( true )
	{
		waitthread AT_SpawnBountyTitan( campId, eventManager )
		spawnedNPCs += 1
		if ( spawnedNPCs >= totalNPCsToSpawn ) // we have reached max npcs
			return // stop any spawning functions

		int npcOnFieldCount = GetScriptManagedNPCArrayLength_Alive( eventManager )
		//print( "npcOnFieldCount: " + string( npcOnFieldCount ) )
		while ( npcOnFieldCount > totalAllowedOnField ) // wait until we have less npcs than allowed count
		{
			WaitFrame()
			npcOnFieldCount = GetScriptManagedNPCArrayLength_Alive( eventManager )
		}
	}
}

void function AT_SpawnBountyTitan( int campId, int scriptManagerId )
{
	entity spawnpoint
	if ( file.camps[ campId ].dropPodSpawnPoints.len() == 0 )
		spawnpoint = file.camps[ campId ].ent
	else
		spawnpoint = file.camps[ campId ].titanSpawnPoints.getrandom()
	// anti-crash
	if ( !IsValid( spawnpoint ) )
		spawnpoint = file.camps[ campId ].ent

	// add variation to spawns
	wait RandomFloat( 1.0 )
	
	// look up titan to use
	int bountyID = 0
	try 
	{
		bountyID = ReserveBossID( VALID_BOUNTY_TITAN_SETTINGS.getrandom() )
	}
	catch ( ex ) {} // if we go above the expected wave count that vanilla supports, there's basically no way to ensure that this func won't error, so default 0 after that point
	
	string aisettings = GetTypeFromBossID( bountyID )
	string titanClass = expect string( Dev_GetAISettingByKeyField_Global( aisettings, "npc_titan_player_settings" ) )
	
	AiGameModes_SpawnTitan( 
		spawnpoint.GetOrigin(), 
		spawnpoint.GetAngles(), 
		AT_BOUNTY_TEAM, 
		titanClass, 
		aisettings,
		// titan handler 
		void function( entity titan ) : ( campId, bountyID, scriptManagerId ) 
		{
			AT_HandleBossTitanSpawn( titan, campId, bountyID, scriptManagerId )
		} 
	)
}

void function AT_HandleBossTitanSpawn( entity titan, int campId, int bountyID, int scriptManagerId )
{
	// set the bounty to be campEnt, for client tracking
	SetGlobalNetEnt( "camp" + string( campId + 1 ) + "Ent", titan )
	// set up health
	titan.SetMaxHealth( titan.GetMaxHealth() * BOUNTY_TITAN_HEALTH_MULTIPLIER )
	titan.SetHealth( titan.GetMaxHealth() )
	// make minimap always show them and highlight them
	titan.Minimap_AlwaysShow( TEAM_IMC, null )
	titan.Minimap_AlwaysShow( TEAM_MILITIA, null )
	thread BountyBossHighlightThink( titan )

	// set up titan-specific death callbacks, mark it as bounty boss for finalDamageCallbacks to work
	file.titanIsBountyBoss[ titan ] <- true
	file.bountyTitanRewards[ titan ] <- ATTRITION_SCORE_BOSS_DAMAGE
	AddEntityCallback_OnKilled( titan, OnBountyTitanKilled )
	
	titan.GetTitanSoul().soul.skipDoomState = true
	// i feel like this should be localised, but there's nothing for it in r1_english?
	titan.SetTitle( GetNameFromBossID( bountyID ) )

	// tracking lifetime
	AddToScriptManagedEntArray( scriptManagerId, titan )
	thread AT_TrackNPCLifeTime( titan, campId, "npc_titan" )
}

void function BountyBossHighlightThink( entity titan )
{
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )

	while ( true )
	{
		Highlight_SetEnemyHighlight( titan, "enemy_boss_bounty" )
		titan.WaitSignal( "StopPhaseShift" ) // prevent phase shift mess up highlights
	}
}

void function OnNPCTitanFinalDamaged( entity titan, var damageInfo )
{
	if ( titan in file.titanIsBountyBoss )
		OnBountyTitanDamaged( titan, damageInfo )
}

// Tracked entities will require their own "wallet"
// for titans it should be used for rounding error compenstation
// for infantry it sould be used to store money if the npc kills a player
void function OnBountyTitanDamaged( entity titan, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) ) // delayed by projectile shots
		return
	// damaged by npc or something?
	if ( !attacker.IsPlayer() )
	{
		attacker = GetBountyBossDamageOwner( attacker, titan )
		if ( !IsValid( attacker ) || !attacker.IsPlayer() )
			return
	}

	int healthSegment = titan.GetMaxHealth() / 100

	// sometimes damage is not enough to add 1 point, we save the damage for player's next attack
	if ( !( titan in file.playerSavedBountyDamage[ attacker ] ) )
		file.playerSavedBountyDamage[ attacker ][ titan ] <- 0

	file.playerSavedBountyDamage[ attacker ][ titan ] += int( DamageInfo_GetDamage( damageInfo ) )
	if ( file.playerSavedBountyDamage[ attacker ][ titan ] < healthSegment )
		return // they can't earn reward from this shot
	
	int damageSegment = file.playerSavedBountyDamage[ attacker ][ titan ] / healthSegment
	int savedDamageLeft = file.playerSavedBountyDamage[ attacker ][ titan ] % healthSegment
	file.playerSavedBountyDamage[ attacker ][ titan ] = savedDamageLeft
	//print( "damageSegment: " + string( damageSegment ) )
	//print( "playerSavedBountyDamage: " + string( file.playerSavedBountyDamage[ attacker ][ titan ] ) )

	float damageFrac = float( damageSegment ) / 100
	int rewardLeft = file.bountyTitanRewards[ titan ]
	int reward = int( ATTRITION_SCORE_BOSS_DAMAGE * damageFrac )
	//print( "reward: " + string( reward ) )
	//printt ( titan.GetMaxHealth(), DamageInfo_GetDamage( damageInfo ) )
	if ( reward >= rewardLeft ) // overloaded shot?
		reward = rewardLeft
	file.bountyTitanRewards[ titan ] -= reward
	
	if ( reward > 0 )
		AT_AddPlayerBonusPointsForBossDamaged( attacker, titan, reward, damageInfo )
}

void function OnBountyTitanKilled( entity titan, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) ) // delayed by projectile shots
		return
	// damaged by npc or something?
	if ( !attacker.IsPlayer() )
	{
		attacker = GetBountyBossDamageOwner( attacker, titan )
		if ( !IsValid( attacker ) || !attacker.IsPlayer() )
			return
	}
	
	if ( titan in file.playerSavedBountyDamage[ attacker ] )
		delete file.playerSavedBountyDamage[ attacker ][ titan ]
	
	// add all remaining reward to attacker
	// bounty killed bonus handled by AT_PlayerOrNPCKilledScoreEvent()
	int rewardLeft = file.bountyTitanRewards[ titan ]
	delete file.bountyTitanRewards[ titan ]
	if ( rewardLeft > 0 )
		AT_AddPlayerBonusPointsForBossDamaged( attacker, titan, rewardLeft, damageInfo )

	// faction dialogue
	int team = attacker.GetTeam()
	PlayFactionDialogueToPlayer( "bh_playerKilledBounty", attacker )
	PlayFactionDialogueToTeamExceptPlayer( "bh_bountyClaimedByFriendly", team, attacker )
	PlayFactionDialogueToTeam( "bh_bountyClaimedByFriendly", GetOtherTeam( team ) )
}

entity function GetBountyBossDamageOwner( entity attacker, entity titan )
{
	if ( attacker.IsPlayer() ) // already a player
		return attacker
	
	if ( attacker.IsTitan() ) // attacker is a npc titan
	{
		// try to find it's pet titan owner
		if ( IsValid( GetPetTitanOwner( attacker ) ) )
			return GetPetTitanOwner( attacker )
	}

	// other damages or non-owner npcs, not sure how it happens, just use this titan's last attacker
	return GetLatestAssistingPlayerInfo( titan ).player
}

void function AT_TrackNPCLifeTime( entity guy, int campId, string aiType )
{
	guy.WaitSignal( "OnDeath", "OnDestroy" )

	string npcNetVar = GetNPCNetVarName( aiType, campId )
	SetGlobalNetInt( npcNetVar, GetGlobalNetInt( npcNetVar ) - 1 )
}


// camp functions
string function GetNPCNetVarName( string className, int campId )
{
	string npcId = string( GetAiTypeInt( className ) + 1 )
	string campLetter = GetCampLetter( campId )
	if ( npcId == "0" ) // cannot find this ai support!
	{
		if ( className == "npc_super_spectre" ) // stupid, reapers are not handled by GetAiTypeInt(), but it must be 4
			return "4" + campLetter + "campCount"
		return ""
	}
	return npcId + campLetter + "campCount"
}

string function GetCampLetter( int campId )
{
	return campId == 0 ? "A" : "B"
}