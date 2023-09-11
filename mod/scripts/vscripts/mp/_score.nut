untyped

global function Score_Init

global function AddPlayerScore
global function ScoreEvent_PlayerKilled
global function ScoreEvent_TitanDoomed
global function ScoreEvent_TitanKilled
global function ScoreEvent_NPCKilled
global function ScoreEvent_MatchComplete

global function ScoreEvent_SetEarnMeterValues
global function ScoreEvent_SetupEarnMeterValuesForMixedModes
global function ScoreEvent_SetupEarnMeterValuesForTitanModes

// callback for doomed health loss titans
global function AddCallback_TitanDoomedScoreEvent
// new settings override func
global function ScoreEvent_SetScoreEventNameOverride

// nessie fix
global function ScoreEvent_GetPlayerMVP
global function ScoreEvent_SetMVPCompareFunc
global function AddTitanKilledDialogueEvent

// nessie modify
global function ScoreEvent_DisableCallSignEvent
global function ScoreEvent_EnableComebackEvent // doesn't exsit in vanilla, make it a setting

struct 
{
	bool firstStrikeDone = false

	// callback for doomed health loss titans
	table<entity, bool> soulHasDoomedOnce // for handling UndoomTitan() conditions, one soul can only be earn score once
	array<void functionref( entity, var, bool )> titanDoomedScoreEventCallbacks

	// new settings override func
	table<string, string> scoreEventNameOverride

	// nessie fix
	table<string, string> killedTitanDialogues
	IntFromEntityCompare mvpCompareFunc = null

	// nessie modify
	bool disableCallSignEvent = false
	bool headshotDialogue = false
	bool comebackEvent = false
} file

void function Score_Init()
{
	SvXP_Init()
	AddCallback_OnClientConnected( InitPlayerForScoreEvents )

	// modified
	InitTitanKilledDialogues()
	AddCallback_OnNPCKilled( CheckForAutoTitanDeath )
	AddCallback_OnPlayerKilled( CheckForAutoTitanDeath )
	AddCallback_OnTitanDoomed( HandleTitanDoomedScoreEvent )
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
void function AddPlayerScore( entity targetPlayer, string scoreEventName, entity associatedEnt = null, var displayTypeOverride = null, int pointValueOverride = -1, float earnMeterPercentage = -1 )
{
	// modified: adding score event override
	if ( scoreEventName in file.scoreEventNameOverride )
		scoreEventName = file.scoreEventNameOverride[ scoreEventName ]
	// anti-crash
	if ( scoreEventName == "" )
		return
	//

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

	// fix score event value override
	if ( earnMeterPercentage != -1 )
	{
		earnValue *= earnMeterPercentage
		ownValue *= earnMeterPercentage
	}
	
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
		// if pilot player can't earn, remove earn value display
		if ( !PlayerEarnMeter_CanEarn( targetPlayer ) )
		{
			earnValue = 0.0
			ownValue = 0.0
		}
	}

	// nessie modify
	if ( file.disableCallSignEvent )
	{
		if ( event.displayType & eEventDisplayType.CALLINGCARD )
			event.displayType = event.displayType & ~eEventDisplayType.CALLINGCARD
	}
	//
	
	if ( displayTypeOverride != null ) // has overrides?
	{
		// anti-crash for calling in GameModeRulesEarnMeterOnDamage_Default()
		if ( typeof( displayTypeOverride ) == "int" )
			event.displayType = expect int( displayTypeOverride )
		else
			event.displayType = int( displayTypeOverride )
	}
	else // default, add a eEventDisplayType.CENTER, required for client to show earnvalue on screen
		event.displayType = event.displayType | eEventDisplayType.CENTER
	
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
	
	string pilotKillEvent = "KillPilot"
	if( IsPilotEliminationBased() )
		pilotKillEvent = "EliminatePilot" // elimination gamemodes have a special medal

	AddPlayerScore( attacker, pilotKillEvent, victim )

	// mvp kill, triggers when there're more than one player in a team
	bool enoughPlayerForMVP = GetPlayerArrayOfTeam( victim.GetTeam() ).len() > 1
	if ( IsFFAGame() ) // for ffa, we check if there're more than 2 players in total
		enoughPlayerForMVP = GetPlayerArray().len() > 2
	if ( enoughPlayerForMVP && ScoreEvent_GetPlayerMVP( victim.GetTeam() ) == victim )
		AddPlayerScore( attacker, "KilledMVP", victim )
	
	int methodOfDeath = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	// headshot
	//if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
	//	AddPlayerScore( attacker, "Headshot", victim )
	// modified to handle specific damages
	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
	{
		AddPlayerScore( attacker, "Headshot", victim )
		// headshot dialogue, doesn't exist in vanilla so make it a setting
		if ( file.headshotDialogue )
			PlayFactionDialogueToPlayer( "kc_bullseye", attacker )
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

	// assist. was previously be in _base_gametype_mp.gnut, which is bad. vanilla won't add assist on npc killing a player
	if ( !victim.IsTitan() ) // titan assist handled by ScoreEvent_TitanKilled()
	{
		table<int, bool> alreadyAssisted
		foreach( DamageHistoryStruct attackerInfo in victim.e.recentDamageHistory )
		{
			if ( !IsValid( attackerInfo.attacker ) || !attackerInfo.attacker.IsPlayer() || attackerInfo.attacker == victim )
				continue

			bool exists = attackerInfo.attacker.GetEncodedEHandle() in alreadyAssisted ? true : false
			if( attackerInfo.attacker != attacker && !exists )
			{
				alreadyAssisted[attackerInfo.attacker.GetEncodedEHandle()] <- true
				Remote_CallFunction_NonReplay( attackerInfo.attacker, "ServerCallback_SetAssistInformation", attackerInfo.damageSourceId, attacker.GetEncodedEHandle(), victim.GetEncodedEHandle(), attackerInfo.time ) 
				AddPlayerScore( attackerInfo.attacker, "PilotAssist", victim )
				attackerInfo.attacker.AddToPlayerGameStat( PGS_ASSISTS, 1 )
			}
		}
	}
}

// this only gets called when titan's owner is player
void function ScoreEvent_TitanDoomed( entity titan, entity attacker, var damageInfo )
{
	// will this handle npc titans with no owners well? i have literally no idea
	// these two shouldn't add eEventDisplayType.CENTER, override with eEventDisplayType.MEDAL
	if ( titan.IsNPC() )
		AddPlayerScore( attacker, "DoomAutoTitan", titan, eEventDisplayType.MEDAL )
	else
		AddPlayerScore( attacker, "DoomTitan", titan, eEventDisplayType.MEDAL )
}

// needs this to handle npc doom titan
void function HandleTitanDoomedScoreEvent( entity titan, var damageInfo )
{
	entity titanSoul = titan.GetTitanSoul()

	// first doom check. ttf2 titans can recover from doomed state
	bool firstDoom = !( titanSoul in file.soulHasDoomedOnce )
	//print( "firstDoom: " + string( firstDoom ) )
	if ( firstDoom )
		file.soulHasDoomedOnce[ titanSoul ] <- true

	// same check as _titan_health.gnut, HandleKillshot() does
	entity attacker = expect entity( expect table( titanSoul.lastAttackInfo ).attacker )
	if ( IsValid( attacker ) )
	{
		entity bossPlayer = attacker.GetBossPlayer()
		if ( attacker.IsNPC() && IsValid( bossPlayer ) )
			attacker = bossPlayer

		// obit
		// modified function in _titan_health.gnut, recovering ttf1 behavior: we do obit on doom but not on death for health loss titans
		if ( !TitanHealth_GetSoulInfiniteDoomedState( titan.GetTitanSoul() ) )
			NotifyClientsOfTitanDeath( titan, attacker, damageInfo )
		// run callbacks
		foreach ( callbackFunc in file.titanDoomedScoreEventCallbacks )
			callbackFunc( titan, damageInfo, firstDoom )
	}
}

void function ScoreEvent_TitanKilled( entity victim, entity attacker, var damageInfo )
{
	// will this handle npc titans with no owners well? i have literally no idea
	// this won't, attacker needs to have a player owner or something to trigger score event
	if ( !attacker.IsPlayer() )
		return

	string scoreEvent = "KillTitan"
	if ( attacker.IsTitan() )
		scoreEvent = "TitanKillTitan"
	if( victim.IsNPC() )
		scoreEvent = "KillAutoTitan"

	if( IsTitanEliminationBased() )
	{
		if( victim.IsNPC() )
			scoreEvent = "EliminateAutoTitan"
		else
			scoreEvent = "EliminateTitan"
	}

	bool isPlayerTitan = IsValid( victim.GetBossPlayer() ) || victim.IsPlayer()
	if( isPlayerTitan ) // to confirm this is a pet titan or player titan
		AddPlayerScore( attacker, scoreEvent, attacker ) // this will show the "Titan Kill" callsign event
	else
		AddPlayerScore( attacker, scoreEvent ) // no callsign event

	bool playTitanKilledDiag = isPlayerTitan
	// modified for npc pilot embarked titan
	#if NPC_TITAN_PILOT_PROTOTYPE
		entity owner = victim.GetOwner()
		bool hasNPCPilot = ( IsAlive( owner ) && IsPilotElite( owner ) ) || TitanHasNpcPilot( victim )
		playTitanKilledDiag = isPlayerTitan || hasNPCPilot
	#endif

	if ( playTitanKilledDiag )
		KilledPlayerTitanDialogue( attacker, victim )

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

// this can also handle npc killing another npc condition
void function CheckForAutoTitanDeath( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsTitan() )
		return

	if ( !IsValid( attacker ) )
		return

	// modified function in _titan_health.gnut, recovering ttf1 behavior: we do obit on doom but not on death for health loss titans
	if ( !TitanHealth_GetSoulInfiniteDoomedState( victim.GetTitanSoul() ) )
		return

	// modified function in _codecallbacks_common.gnut
	if ( EntityKilledEvent_IsDisabledForEntity( victim ) )
		return

	// obit
	NotifyClientsOfTitanDeath( victim, attacker, damageInfo )
}

// titan killed remotecall. was previously be in _base_gametype_mp.gnut, which is bad
void function NotifyClientsOfTitanDeath( entity victim, entity attacker, var damageInfo )
{
	if ( !IsValid( victim ) || !victim.IsTitan() )
		return

	// below are from SendEntityKilledEvent(), removed headshot checks
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	// trigger_hurt is no longer networked, so the "attacker" fails to display obituaries
	if ( attacker )
	{
		string attackerClassname = attacker.GetClassName()

		if ( attackerClassname == "trigger_hurt" || attackerClassname == "trigger_multiple" )
			attacker = GetEntByIndex( 0 ) // worldspawn
	}

	int attackerEHandle = victim.GetEncodedEHandle() // by default we just use victim's EHandle
	// ServerCallback_OnTitanKilled() is not using "GetHeavyWeightEntityFromEncodedEHandle()"
	// which means we can't pass a non-heavy weighted entity into it
	// non-heavy weighted entity including projectile stuffs
	// all movers, props, npcs and players are heavy weighted

	// crash happens after I made ball lightning use projectile as the inflictor of it's zap damage( in vanilla they uses movers )
	// after owner being destroyed, the projectile will be passed as attacker!
	if ( IsValid( attacker ) && !attacker.IsProjectile() )
		attackerEHandle = attacker.GetEncodedEHandle()

	int victimEHandle = victim.GetEncodedEHandle()
	int scriptDamageType = DamageInfo_GetCustomDamageType( damageInfo )
	int damageSourceId = DamageInfo_GetDamageSourceIdentifier( damageInfo )

	if ( scriptDamageType & DF_VORTEX_REFIRE )
		damageSourceId = eDamageSourceId.mp_titanweapon_vortex_shield

	foreach ( player in GetPlayerArray() )
		Remote_CallFunction_NonReplay( player, "ServerCallback_OnTitanKilled", attackerEHandle, victimEHandle, scriptDamageType, damageSourceId )
}

void function ScoreEvent_NPCKilled( entity victim, entity attacker, var damageInfo )
{
	try
	{		
		// have to trycatch this because marvins will crash on kill if we dont
		AddPlayerScore( attacker, ScoreEventForNPCKilled( victim, damageInfo ), victim )
	}
	catch ( ex ) {}

	// headshot
	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
		AddPlayerScore( attacker, "Headshot", victim, null, -1, 0.0 ) // no value earn from npc headshots

	// mayhem and onslaught, doesn't add any score but vanilla has this event
	// mayhem killstreak broke
	if ( attacker.s.lastNPCKillTime < Time() - MAYHEM_REQUIREMENT_TIME )
		attacker.s.currentMayhemNPCKillstreak = 0
	// onslaught killstreak broke
	if ( attacker.s.lastNPCKillTime < Time() - ONSLAUGHT_REQUIREMENT_TIME )
		attacker.s.currentOnslaughtNPCKillstreak = 0
	
	// update last killed time
	attacker.s.lastNPCKillTime = Time()

	// they only count on killing grunts(humansized npcs)
	if ( IsHumanSized( victim ) )
	{
		// mayhem
		attacker.s.currentMayhemNPCKillstreak++
		if ( attacker.s.currentMayhemNPCKillstreak == MAYHEM_REQUIREMENT_KILLS )
			AddPlayerScore( attacker, "Mayhem" )
		// onslaught
		attacker.s.currentOnslaughtNPCKillstreak++
		if ( attacker.s.currentOnslaughtNPCKillstreak == ONSLAUGHT_REQUIREMENT_KILLS )
			AddPlayerScore( attacker, "Onslaught" )
	}
}

void function ScoreEvent_MatchComplete( int winningTeam, bool isMatchEnd = true )
{
	string matchScoreEvent = "MatchComplete"
	string winningScoreEvent = "MatchVictory"
	if ( !isMatchEnd ) // round based scoring!
	{
		matchScoreEvent = "RoundComplete"
		winningScoreEvent = "RoundVictory"
	}

	float scoreAddDelay = 2.0 // vanilla do have a delay for match ending score
	if ( !isMatchEnd ) // round based scoring!
		scoreAddDelay = 0.0 // no delay
	thread DelayedAddMatchCompleteScore( winningScoreEvent, matchScoreEvent, winningTeam, scoreAddDelay )
}

void function DelayedAddMatchCompleteScore( string winningScoreEvent, string matchScoreEvent, int winningTeam, float delay )
{
	if ( delay > 0 )
		wait delay
	foreach( entity player in GetPlayerArray() )
		AddPlayerScore( player, matchScoreEvent )
	foreach( entity winningPlayer in GetPlayerArrayOfTeam( winningTeam ) )
		AddPlayerScore( winningPlayer, winningScoreEvent )
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
	if ( IsLobby() ) // setup score events in lobby can cause crash
		return

	// pilot kill
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.10, 0.05 )
	ScoreEvent_SetEarnMeterValues( "EliminatePilot", 0.10, 0.05 )
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.04, 0.01, 0.0 )
	// titan kill
	ScoreEvent_SetEarnMeterValues( "DoomTitan", 0.0, 0.0 )
	// don't know why titan kills appear to be no value in vanilla
	// was set to 0.10, 0.15
	// in vanilla all values seems to be pilot kill only
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "KillAutoTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "EliminateTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "EliminateAutoTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "TitanKillTitan", 0.0, 0.0 )
	// but titan assist do have earn values...
	ScoreEvent_SetEarnMeterValues( "TitanAssist", 0.10, 0.10 )
	// rodeo
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.35, 0.0 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryApplied", 0.0, 0.35, 0.0 )
	// special method of killing
	ScoreEvent_SetEarnMeterValues( "Headshot", 0.0, 0.02, 0.0 )
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.04, 0.01, 0.0 )
	
	// ai
	ScoreEvent_SetEarnMeterValues( "KillGrunt", 0.03, 0.01 )
	ScoreEvent_SetEarnMeterValues( "KillSpectre", 0.03, 0.01 )
	ScoreEvent_SetEarnMeterValues( "LeechSpectre", 0.03, 0.01 )
	ScoreEvent_SetEarnMeterValues( "KillHackedSpectre", 0.03, 0.01 )
	ScoreEvent_SetEarnMeterValues( "KillStalker", 0.03, 0.01 )
	ScoreEvent_SetEarnMeterValues( "KillSuperSpectre", 0.15, 0.05 )
	ScoreEvent_SetEarnMeterValues( "KillLightTurret", 0.05, 0.05 )
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

	string titanCharacterName = GetTitanCharacterName( titan )
	string dialogue = "kc_pilotkilltitan"
	if ( CoinFlip() && titanCharacterName in file.killedTitanDialogues ) // 50% chance to play titan specific dialogue
		dialogue = file.killedTitanDialogues[ titanCharacterName ]

	PlayFactionDialogueToPlayer( dialogue, attacker )
}

// callback for doomed health loss titans
void function AddCallback_TitanDoomedScoreEvent( void functionref( entity, var, bool ) callbackFunc )
{
	if ( !file.titanDoomedScoreEventCallbacks.contains( callbackFunc ) )
		file.titanDoomedScoreEventCallbacks.append( callbackFunc )
}

// new settings override func
void function ScoreEvent_SetScoreEventNameOverride( string eventName, string overrideName )
{
	if ( !( eventName in file.scoreEventNameOverride ) )
		file.scoreEventNameOverride[ eventName ] <- ""
	file.scoreEventNameOverride[ eventName ] = overrideName
}

// nessie fix
entity function ScoreEvent_GetPlayerMVP( int team = 0 )
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

void function ScoreEvent_SetMVPCompareFunc( IntFromEntityCompare func )
{
	file.mvpCompareFunc = func
}

void function AddTitanKilledDialogueEvent( string titanName, string dialogueName )
{
	file.killedTitanDialogues[titanName] <- dialogueName
}

// nessie modify
void function ScoreEvent_DisableCallSignEvent( bool disable )
{
	file.disableCallSignEvent = disable
}

void function ScoreEvent_EnableHeadshotDialogue( bool enable )
{
	file.headshotDialogue = enable
}

void function ScoreEvent_EnableComebackEvent( bool enable )
{
	file.comebackEvent = enable
}