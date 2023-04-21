untyped

global function Score_Init

global function AddPlayerScore
global function ScoreEvent_PlayerKilled
global function ScoreEvent_TitanDoomed
global function ScoreEvent_TitanKilled
global function ScoreEvent_NPCKilled

global function ScoreEvent_SetEarnMeterValues
global function ScoreEvent_SetupEarnMeterValuesForMixedModes
global function ScoreEvent_SetupEarnMeterValuesForTitanModes

// nessie modify
global function GetMvpPlayer
global function AddTitanKilledDialogueEvent
global function ScoreEvent_ForceUsePilotEliminateEvent
global function ScoreEvent_DisableCallSignEvent
global function ScoreEvent_AddHeadShotMedalDisabledDamageSourceId // basically for eDamageSourceId.bleedout
global function ScoreEvent_EnableComebackEvent

struct 
{
	bool firstStrikeDone = false

	// nessie modify
	table<string, string> killedTitanDialogues

	IntFromEntityCompare mvpCompareFunc = null
	
	bool forceAddEliminateScore = false
	bool disableCallSignEvent = false
	array<int> headShotMedalDisabledDamageSource
	bool comebackEvent = false
} file

void function Score_Init()
{
	SvXP_Init()
	AddCallback_OnClientConnected( InitPlayerForScoreEvents )

	// modified
	InitTitanKilledDialogues()
}

// modified!!!
void function InitTitanKilledDialogues() // init vanilla ones
{
	file.killedTitanDialogues["ion"] <- "kc_pilotkillIon"
	file.killedTitanDialogues["tone"] <- "kc_pilotkillTone"
	file.killedTitanDialogues["legion"] <- "kc_pilotkillLegion"
	file.killedTitanDialogues["scorch"] <- "kc_pilotkillScorch"
	file.killedTitanDialogues["northstar"] <- "kc_pilotkillNorthstar"
	file.killedTitanDialogues["ronin"] <- "kc_pilotkillRonin"
}

void function InitPlayerForScoreEvents( entity player )
{	
	player.s.currentKillstreak <- 0
	player.s.lastKillTime <- 0.0
	player.s.currentTimedKillstreak <- 0

	// npc killstreak
	player.s.lastNPCKillTime <- 0.0
	player.s.currentMayhemNPCKillstreak <- 0
	player.s.currentOnslaughtNPCKillstreak <- 0
}

// idk why forth arg is a string, maybe it should be a var type?
//void function AddPlayerScore( entity targetPlayer, string scoreEventName, entity associatedEnt = null, string noideawhatthisis = "", int pointValueOverride = -1 )
void function AddPlayerScore( entity targetPlayer, string scoreEventName, entity associatedEnt = null, string displayTypeOverride = "", int pointValueOverride = -1 )
{
	ScoreEvent event = GetScoreEvent( scoreEventName )
	
	if ( !event.enabled || !IsValid( targetPlayer ) || !targetPlayer.IsPlayer() )
		return

	var associatedHandle = 0
	if ( associatedEnt != null )
		associatedHandle = associatedEnt.GetEncodedEHandle()
		
	if ( pointValueOverride != -1 )
		event.pointValue = pointValueOverride 
	
	float earnScale = targetPlayer.IsTitan() ? 0.0 : 1.0 // titan shouldn't get any earn value
	float ownScale = targetPlayer.IsTitan() ? event.coreMeterScalar : 1.0
	
	float earnValue = event.earnMeterEarnValue * earnScale
	float ownValue = event.earnMeterOwnValue * ownScale
	
	PlayerEarnMeter_AddEarnedAndOwned( targetPlayer, earnValue, ownValue ) //( targetPlayer, earnValue * scale, ownValue * scale ) // seriously? this causes a value*scale^2
	
	// PlayerEarnMeter_AddEarnedAndOwned handles this scaling by itself, we just need to do this for the visual stuff
	float pilotScaleVar = ( expect string ( GetCurrentPlaylistVarOrUseValue( "earn_meter_pilot_multiplier", "1" ) ) ).tofloat()
	float titanScaleVar = ( expect string ( GetCurrentPlaylistVarOrUseValue( "earn_meter_titan_multiplier", "1" ) ) ).tofloat()
	
	if ( targetPlayer.IsTitan() )
	{
		//earnValue *= titanScaleVar // titan shouldn't get any earn value
		ownValue *= titanScaleVar
	}
	else
	{
		earnValue *= pilotScaleVar
		ownValue *= pilotScaleVar
	}

	// nessie modify
	if ( file.disableCallSignEvent )
	{
		if ( event.displayType & eEventDisplayType.CALLINGCARD )
			event.displayType = event.displayType & ~eEventDisplayType.CALLINGCARD
	}
	
	if ( displayTypeOverride != "noCenter" ) // default
		event.displayType = event.displayType | eEventDisplayType.CENTER // eEventDisplayType.CENTER is required for client to show earnvalue on screen
	// messed up "ownValue" and "earnValue"
	//Remote_CallFunction_NonReplay( targetPlayer, "ServerCallback_ScoreEvent", event.eventId, event.pointValue, event.displayType, associatedHandle, ownValue, earnValue )
	Remote_CallFunction_NonReplay( targetPlayer, "ServerCallback_ScoreEvent", event.eventId, event.pointValue, event.displayType, associatedHandle, earnValue, ownValue )

	if ( event.displayType & eEventDisplayType.CALLINGCARD ) // callingcardevents are shown to all players
	{
		foreach ( entity player in GetPlayerArray() )
		{
			if ( player == targetPlayer ) // targetplayer already gets this in the scorevent callback
				continue
				
			Remote_CallFunction_NonReplay( player, "ServerCallback_CallingCardEvent", event.eventId, associatedHandle )
		}
	}
	
	if ( ScoreEvent_HasConversation( event ) )
		PlayFactionDialogueToPlayer( event.conversation, targetPlayer )
		
	HandleXPGainForScoreEvent( targetPlayer, event )
}

void function ScoreEvent_PlayerKilled( entity victim, entity attacker, var damageInfo )
{
	// reset killstreaks and stuff		
	victim.s.currentKillstreak = 0
	victim.s.lastKillTime = 0.0
	victim.s.currentTimedKillstreak = 0
	// npc killstreaks
	victim.s.lastNPCKillTime = 0.0
	victim.s.currentMayhemNPCKillstreak = 0
	victim.s.currentOnslaughtNPCKillstreak = 0
	
	victim.p.numberOfDeathsSinceLastKill++ // this is reset on kill
	victim.p.lastDeathTime = Time()
	victim.p.lastKiller = attacker
	victim.p.seekingRevenge = true
	
	// have to do this early before we reset victim's player killstreaks
	// nemesis when you kill a player that is dominating you
	if ( attacker.IsPlayer() && attacker in victim.p.playerKillStreaks && victim.p.playerKillStreaks[ attacker ] >= NEMESIS_KILL_REQUIREMENT )
		AddPlayerScore( attacker, "Nemesis", attacker )
	
	// reset killstreaks on specific players
	foreach ( entity killstreakPlayer, int numKills in victim.p.playerKillStreaks )
		delete victim.p.playerKillStreaks[ killstreakPlayer ]

	if ( victim.IsTitan() )
		ScoreEvent_TitanKilled( victim, attacker, damageInfo )

	if ( !attacker.IsPlayer() )
		return

	// pilot kill
	if( IsPilotEliminationBased() || IsTitanEliminationBased() )
	{
		if( GetPlayerArrayOfEnemies_Alive( attacker.GetTeam() ).len() == 0 ) // no enemy player left
			AddPlayerScore( attacker, "VictoryKill", attacker ) // show a callsign event
	}
	
	if( IsPilotEliminationBased() || file.forceAddEliminateScore )
		AddPlayerScore( attacker, "EliminatePilot", victim ) // elimination gamemodes have a special medal
	else
		AddPlayerScore( attacker, "KillPilot", victim )

	// mvp kill, triggers when there're more than one player in a team
	bool enoughPlayerForMVP = GetPlayerArrayOfTeam( victim.GetTeam() ).len() > 1
	if ( IsFFAGame() ) // for ffa, we check if there're more than 2 players in total
		enoughPlayerForMVP = GetPlayerArray().len() > 2
	if ( enoughPlayerForMVP && GetMvpPlayer( victim.GetTeam() ) == victim )
		AddPlayerScore( attacker, "KilledMVP", victim )
	
	int methodOfDeath = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	// headshot
	//if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
	//	AddPlayerScore( attacker, "Headshot", victim )
	// modified to handle specific damages
	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
	{
		if ( file.headShotMedalDisabledDamageSource.contains( methodOfDeath ) )
		{
			AddPlayerScore( attacker, "Headshot", victim )
			PlayFactionDialogueToPlayer( "kc_bullseye", attacker )
		}
	}

	// special method of killing dialogues	
	if( methodOfDeath == damagedef_titan_step )
		PlayFactionDialogueToPlayer( "kc_hitandrun", attacker )

	// first strike
	if ( !file.firstStrikeDone )
	{
		file.firstStrikeDone = true
		AddPlayerScore( attacker, "FirstStrike", attacker )
	}

	// revenge && quick revenge
	if( attacker.p.lastKiller == victim && attacker.p.seekingRevenge )
	{
		if( Time() <= attacker.p.lastDeathTime + QUICK_REVENGE_TIME_LIMIT )
			AddPlayerScore( attacker, "QuickRevenge", victim )
		else
			AddPlayerScore( attacker, "Revenge", victim )
		attacker.p.seekingRevenge = false
	}

	// comeback, doesn't exist in vanilla so make it a setting
	if ( file.comebackEvent )
	{
		if ( attacker.p.numberOfDeathsSinceLastKill >= COMEBACK_DEATHS_REQUIREMENT )
			AddPlayerScore( attacker, "Comeback", victim )
	}
	attacker.p.numberOfDeathsSinceLastKill = 0 // since they got a kill, remove the comeback trigger
	
	// untimed killstreaks
	attacker.s.currentKillstreak++
	if ( attacker.s.currentKillstreak == 3 )
		AddPlayerScore( attacker, "KillingSpree", attacker )
	else if ( attacker.s.currentKillstreak == 5 )
		AddPlayerScore( attacker, "Rampage", attacker )
	
	// increment untimed killstreaks against specific players
	if ( !( victim in attacker.p.playerKillStreaks ) )
		attacker.p.playerKillStreaks[ victim ] <- 1
	else
		attacker.p.playerKillStreaks[ victim ]++
	
	// dominating
	if ( attacker.p.playerKillStreaks[ victim ] >= DOMINATING_KILL_REQUIREMENT )
		AddPlayerScore( attacker, "Dominating", victim )
	
	if ( Time() - attacker.s.lastKillTime > CASCADINGKILL_REQUIREMENT_TIME )
	{
		attacker.s.currentTimedKillstreak = 0 // reset first before kill
		attacker.s.lastKillTime = Time()
	}
	
	// timed killstreaks
	if ( Time() - attacker.s.lastKillTime <= CASCADINGKILL_REQUIREMENT_TIME )
	{
		attacker.s.currentTimedKillstreak++
		
		if ( attacker.s.currentTimedKillstreak == DOUBLEKILL_REQUIREMENT_KILLS )
			AddPlayerScore( attacker, "DoubleKill", attacker )
		else if ( attacker.s.currentTimedKillstreak == TRIPLEKILL_REQUIREMENT_KILLS )
			AddPlayerScore( attacker, "TripleKill", attacker )
		else if ( attacker.s.currentTimedKillstreak >= MEGAKILL_REQUIREMENT_KILLS )
			AddPlayerScore( attacker, "MegaKill", attacker )
	}
	
	attacker.s.lastKillTime = Time()
}

void function ScoreEvent_TitanDoomed( entity titan, entity attacker, var damageInfo )
{
	// will this handle npc titans with no owners well? i have literally no idea
	// these two shouldn't add eEventDisplayType.CENTER, now hardcoded by "noCenter" param
	if ( titan.IsNPC() )
		AddPlayerScore( attacker, "DoomAutoTitan", titan, "noCenter" )
	else
		AddPlayerScore( attacker, "DoomTitan", titan, "noCenter" )
}

void function ScoreEvent_TitanKilled( entity victim, entity attacker, var damageInfo )
{
	// will this handle npc titans with no owners well? i have literally no idea
	if ( !attacker.IsPlayer() )
		return

	string scoreEvent = "KillTitan"
	if( attacker.IsTitan() )
		scoreEvent = "TitanKillTitan"
	if( victim.IsNPC() )
		scoreEvent = "KillAutoTitan"
	if( IsTitanEliminationBased() || file.forceAddEliminateScore )
	{
		if( victim.IsNPC() )
			scoreEvent = "EliminateAutoTitan"
		else
			scoreEvent = "EliminateTitan"
	}

	if( victim.GetBossPlayer() || victim.IsPlayer() ) // to confirm this is a pet titan or player titan
	{
		AddPlayerScore( attacker, scoreEvent, attacker ) // this will show the "Titan Kill" callsign event
		KilledPlayerTitanDialogue( attacker, victim )
	}
	else
	{
		AddPlayerScore( attacker, scoreEvent ) // no callsign event
	}

	// titan damage history stores in titanSoul, but if they killed by termination it's gonna transfer to victim themselves
	bool killedByTermination = DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.titan_execution
	entity damageHistorySaver = killedByTermination ? victim : victim.GetTitanSoul()
	if ( IsValid( damageHistorySaver ) )
	{
		//print( "damageHistorySaver valid! " + string( damageHistorySaver ) )
		table<int, bool> alreadyAssisted
		foreach( DamageHistoryStruct attackerInfo in damageHistorySaver.e.recentDamageHistory )
		{
			//print( "attackerInfo.attacker: " + string( attackerInfo.attacker ) )
			if ( !IsValid( attackerInfo.attacker ) || !attackerInfo.attacker.IsPlayer() || attackerInfo.attacker == victim )
				continue
				
			bool exists = attackerInfo.attacker.GetEncodedEHandle() in alreadyAssisted ? true : false
			if( attackerInfo.attacker != attacker && !exists )
			{
				alreadyAssisted[attackerInfo.attacker.GetEncodedEHandle()] <- true
				Remote_CallFunction_NonReplay( attackerInfo.attacker, "ServerCallback_SetAssistInformation", attackerInfo.damageSourceId, attacker.GetEncodedEHandle(), victim.GetEncodedEHandle(), attackerInfo.time )
				AddPlayerScore( attackerInfo.attacker, "TitanAssist", victim )
				attackerInfo.attacker.AddToPlayerGameStat( PGS_ASSISTS, 1 )
			}
		}
	}
}

void function ScoreEvent_NPCKilled( entity victim, entity attacker, var damageInfo )
{
	try
	{		
		// have to trycatch this because marvins will crash on kill if we dont
		AddPlayerScore( attacker, ScoreEventForNPCKilled( victim, damageInfo ), victim )
	}
	catch ( ex ) {}

	// mayhem and onslaught, doesn't add any score but vanilla has this event
	// mayhem killstreak broke
	if ( attacker.s.lastNPCKillTime < Time() - MAYHEM_REQUIREMENT_TIME )
		attacker.s.currentMayhemNPCKillstreak = 0
	// onslaught killstreak broke
	if ( attacker.s.lastNPCKillTime < Time() - ONSLAUGHT_REQUIREMENT_TIME )
		attacker.s.currentOnslaughtNPCKillstreak = 0
	
	// update last killed time
	attacker.s.lastNPCKillTime = Time()

	// mayhem
	attacker.s.currentMayhemNPCKillstreak++
	if ( attacker.s.currentMayhemNPCKillstreak == MAYHEM_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "Mayhem" )
	// onslaught
	attacker.s.currentOnslaughtNPCKillstreak++
	if ( attacker.s.currentOnslaughtNPCKillstreak == ONSLAUGHT_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "Onslaught" )
}

void function ScoreEvent_SetEarnMeterValues( string eventName, float earned, float owned, float coreScale = 1.0 )
{
	ScoreEvent event = GetScoreEvent( eventName )
	event.earnMeterEarnValue = earned
	event.earnMeterOwnValue = owned
	event.coreMeterScalar = coreScale
}

void function ScoreEvent_SetupEarnMeterValuesForMixedModes() // mixed modes in this case means modes with both pilots and titans
{
	thread SetupEarnMeterValuesForMixedModes_Threaded() // needs thread or "PilotEmilinate" won't be set up correctly
}

void function SetupEarnMeterValuesForMixedModes_Threaded()
{
	WaitFrame()

	// todo needs earn/overdrive values
	// player-controlled stuff
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.07, 0.15, 0.33 )
	ScoreEvent_SetEarnMeterValues( "EliminatePilot", 0.07, 0.15 )
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.02, 0.05, 0.0 )
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.0, 0.15 )
	ScoreEvent_SetEarnMeterValues( "KillAutoTitan", 0.0, 0.15 )
	ScoreEvent_SetEarnMeterValues( "EliminateTitan", 0.0, 0.15 )
	ScoreEvent_SetEarnMeterValues( "EliminateAutoTitan", 0.0, 0.15 )
	ScoreEvent_SetEarnMeterValues( "TitanKillTitan", 0.0, 0.15 ) // unsure
	ScoreEvent_SetEarnMeterValues( "TitanAssist", 0.0, 0.10 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.35 ) // this actually just doesn't have overdrive in vanilla even
	ScoreEvent_SetEarnMeterValues( "Headshot", 0.0, 0.02 )
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.0, 0.05 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryApplied", 0.0, 0.35 )
	
	// ai
	ScoreEvent_SetEarnMeterValues( "KillGrunt", 0.02, 0.02, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillSpectre", 0.02, 0.02, 0.5 )
	ScoreEvent_SetEarnMeterValues( "LeechSpectre", 0.02, 0.02 )
	ScoreEvent_SetEarnMeterValues( "KillStalker", 0.02, 0.02, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillSuperSpectre", 0.0, 0.1, 0.5 )
}

void function ScoreEvent_SetupEarnMeterValuesForTitanModes()
{
	// relatively sure we don't have to do anything here but leaving this function for consistency
}

void function KilledPlayerTitanDialogue( entity attacker, entity victim )
{
	if( !attacker.IsPlayer() )
		return
	entity titan
	if ( victim.IsTitan() )
		titan = victim

	if( !IsValid( titan ) )
		return
	string titanCharacterName = ""
	// may have modded titan that can't use GetTitanCharacterName()
	try { titanCharacterName = GetTitanCharacterName( titan ) }
	catch(ex) {}

	if( titanCharacterName in file.killedTitanDialogues ) // have this titan's dialogue
		PlayFactionDialogueToPlayer( file.killedTitanDialogues[titanCharacterName], attacker )
	else // play a default one
		PlayFactionDialogueToPlayer( "kc_pilotkilltitan", attacker )
}

// nessy modify
entity function GetMvpPlayer( int team = 0 )
{
	if( IsFFAGame() )
		team = 0 // 0 means sorting all players( good for ffa ), if use a teamNumber it will sort a certain team
	
	array<entity> sortedPlayer
	if( file.mvpCompareFunc != null ) // a overwriting one, save for modding
	{
		sortedPlayer = GetSortedPlayers( file.mvpCompareFunc, team )
		return sortedPlayer[0] // mvp
	}

	// default one
	sortedPlayer = GetSortedPlayers( GameMode_GetScoreCompareFunc( GAMETYPE ), team )
	return sortedPlayer[0] // mvp
}

void function AddTitanKilledDialogueEvent( string titanName, string dialogueName )
{
	file.killedTitanDialogues[titanName] <- dialogueName
}

void function ScoreEvent_ForceUsePilotEliminateEvent( bool force )
{
	file.forceAddEliminateScore = force
}

void function ScoreEvent_DisableCallSignEvent( bool disable )
{
	file.disableCallSignEvent = disable
}

void function ScoreEvent_AddHeadShotMedalDisabledDamageSourceId( int damageSourceId )
{
	if ( file.headShotMedalDisabledDamageSource.contains( damageSourceId ) )
		return

	file.headShotMedalDisabledDamageSource.append( damageSourceId )
}

void function ScoreEvent_EnableComebackEvent( bool enable )
{
	file.comebackEvent = enable
}