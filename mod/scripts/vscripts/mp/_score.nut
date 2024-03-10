untyped

global function Score_Init

global function AddPlayerScore
global function ScoreEvent_PlayerKilled
global function ScoreEvent_TitanDoomed
global function ScoreEvent_TitanKilled
global function ScoreEvent_NPCKilled
global function ScoreEvent_MatchComplete
// vanilla behavior
global function ScoreEvent_VictoryKill

global function ScoreEvent_SetEarnMeterValues
// northstar missing
// this seems to be how vanilla overwrite display type
// because if we add eEventDisplayType.CENTER by default
// we'll have to handle events like "Titanfall" and "DoomTitan" manually, which is pretty bad
global function ScoreEvent_SetEventDisplayTypes

global function ScoreEvent_SetupEarnMeterValuesForMixedModes
global function ScoreEvent_SetupEarnMeterValuesForTitanModes

// callback for doomed health loss titans
global function AddCallback_TitanDoomedScoreEvent
// new settings override func
global function ScoreEvent_SetScoreEventNameOverride
global function ScoreEvent_SetDisabledForEntity // allow us disable certain entity's score event
global function ScoreEvent_IsDisabledForEntity // to be shared with _base_gametype.gnut
global function ScoreEvent_SetEntityEarnValueOverride // for us set specific earnmeter value scale for an entity. note that this only works for player and npc kills / assists
global function ScoreEvent_DisableEntityFactionDialogueEvent // for us disable certain entity's faction dialogue event, so we can handle them manually in other files...

// nessie fix
global function ScoreEvent_GetPlayerMVP
global function ScoreEvent_SetMVPCompareFunc
global function ScoreEvent_PlayerAssist
global function AddTitanKilledDialogueEvent

// nessie modify
global function ScoreEvent_DisableCallSignEvent
global function ScoreEvent_EnableComebackEvent // doesn't exsit in vanilla, make it a setting
// funny things to be shared with other files, add more kill streak stuffs
global function UpdateUntimedKillStreaks
global function UpdateMixedTimedKillStreaks

struct EarnValueOverride
{
	float earnMeterEarnValue
	float earnMeterOwnValue
	float coreMeterScalar
	float earnMeterScalar
}

struct 
{
	// respawn behavior
	float earn_meter_pilot_multiplier
	float earn_meter_titan_multiplier
	int earn_meter_pilot_overdrive

	bool firstStrikeDone = false

	// callback for doomed health loss titans
	table<entity, bool> soulHasDoomedOnce // for handling UndoomTitan() conditions, one soul can only be earn score once
	array<void functionref( entity, var, bool )> titanDoomedScoreEventCallbacks

	// new settings override func
	table<string, string> scoreEventNameOverride
	table<entity, bool> entScoreEventDisabled
	table< entity, table<string, EarnValueOverride> > entScoreEventValueOverride
	table<entity, bool> entScoreEventDialogueDisabled

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

	// respawn behavior
	file.earn_meter_pilot_multiplier = GetCurrentPlaylistVarFloat( "earn_meter_pilot_multiplier", 1.0 )
	file.earn_meter_titan_multiplier = GetCurrentPlaylistVarFloat( "earn_meter_titan_multiplier", 1.0 )
	file.earn_meter_pilot_overdrive = GetCurrentPlaylistVarInt( "earn_meter_pilot_overdrive", ePilotOverdrive.Enabled )

	// little tweak for fun
	AddCallback_OnPlayerRespawned( OnPlayerRespawned )
	AddDeathCallback( "player", OnPlayerDeath )

	// modified
	InitTitanKilledDialogues()
	AddCallback_OnTitanDoomed( HandleTitanDoomedScoreEvent )
}

void function OnPlayerRespawned( entity player )
{
	// reset killstreaks and stuff
	player.s.currentKillstreak = 0
	player.s.lastKillTime = 0.0
	player.s.currentTimedKillstreak = 0
	// npc&player mixed killstreaks
	player.s.lastMixedKillTime = 0.0
	player.s.currentMayhemKillstreak = 0
	player.s.currentOnslaughtKillstreak = 0
}

void function OnPlayerDeath( entity player, var damageInfo )
{
	player.p.numberOfDeathsSinceLastKill++ // this is reset on kill
	player.p.lastDeathTime = Time()
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

	// npc&player mixed killsteaks
	player.s.lastMixedKillTime <- 0.0
	player.s.currentMayhemKillstreak <- 0
	player.s.currentOnslaughtKillstreak <- 0
}

// idk why forth arg is a string, maybe it should be a var type?
// pointValueOverride takes no effect in tf2, but _codecallbacks.gnut uses it... sucks
//void function AddPlayerScore( entity targetPlayer, string scoreEventName, entity associatedEnt = null, string noideawhatthisis = "", int pointValueOverride = -1 )
void function AddPlayerScore( entity targetPlayer, string scoreEventName, entity associatedEnt = null, var displayTypeOverride = null, int pointValueOverride = -1, float earnMeterScalar = 1.0, entity earnValueOverrideEnt = null )
{
	// modified: adding score event override
	if ( scoreEventName in file.scoreEventNameOverride )
		scoreEventName = file.scoreEventNameOverride[ scoreEventName ]
	// anti-crash
	if ( scoreEventName == "" )
		return
	//

	// never directly modify a struct... use a clone!
	//ScoreEvent event = GetScoreEvent( scoreEventName )
	ScoreEvent event = clone GetScoreEvent( scoreEventName )
	
	if ( !event.enabled || !IsValid( targetPlayer ) || !targetPlayer.IsPlayer() )
		return

	var associatedHandle = 0
	if ( IsValid( associatedEnt ) )
		associatedHandle = associatedEnt.GetEncodedEHandle()
	
	// pointValueOverride takes no effect in tf2, but _codecallbacks.gnut uses it... sucks
	if ( pointValueOverride != -1 )
		event.pointValue = pointValueOverride
	
	// settings override
	bool hasEarnValueOverride = false
	EarnValueOverride overrideStruct
	if ( IsValid( earnValueOverrideEnt ) && ( earnValueOverrideEnt in file.entScoreEventValueOverride ) && ( scoreEventName in file.entScoreEventValueOverride[ earnValueOverrideEnt ] ) )
	{
		overrideStruct = file.entScoreEventValueOverride[ earnValueOverrideEnt ][ scoreEventName ]
		hasEarnValueOverride = true
	}

	float coreMeterScalar = event.coreMeterScalar
	// settings override
	if ( hasEarnValueOverride )
		coreMeterScalar = overrideStruct.coreMeterScalar

	float earnScale = targetPlayer.IsTitan() ? 0.0 : 1.0 // titan shouldn't get any earn value
	float ownScale = targetPlayer.IsTitan() ? coreMeterScalar : 1.0
	
	float earnValue = event.earnMeterEarnValue 
	float ownValue = event.earnMeterOwnValue 
	// settings override
	if ( hasEarnValueOverride )
	{
		earnValue = overrideStruct.earnMeterEarnValue
		ownValue = overrideStruct.earnMeterOwnValue 
	}
	earnValue *= earnScale
	ownValue *= ownScale

	// score event value override
	if ( hasEarnValueOverride )
		earnMeterScalar = overrideStruct.earnMeterScalar
	earnValue *= earnMeterScalar
	ownValue *= earnMeterScalar

	// debug
	//print( "not calculated earnValue: " + string( earnValue ) )
	//print( "not calculated ownValue: " + string( ownValue ) )
	
	PlayerEarnMeter_AddEarnedAndOwned( targetPlayer, earnValue, ownValue ) //( targetPlayer, earnValue * scale, ownValue * scale ) // seriously? this causes a value*scale^2
	
	// PlayerEarnMeter_AddEarnedAndOwned handles this scaling by itself, we just need to do this for the visual stuff
	// we could use GetCurrentPlaylistVarFloat(), and use a file variable like other respawn codes...
	//float pilotScaleVar = ( expect string ( GetCurrentPlaylistVarOrUseValue( "earn_meter_pilot_multiplier", "1" ) ) ).tofloat()
	//float titanScaleVar = ( expect string ( GetCurrentPlaylistVarOrUseValue( "earn_meter_titan_multiplier", "1" ) ) ).tofloat()

	if ( targetPlayer.IsTitan() )
	{
		// use a file variable like other respawn codes...
		//earnValue *= titanScaleVar
		//ownValue *= titanScaleVar
		//earnValue *= file.earn_meter_titan_multiplier // titan shouldn't get any earn value
		ownValue *= file.earn_meter_titan_multiplier
	}
	else
	{
		// use a file variable like other respawn codes...
		//earnValue *= pilotScaleVar
		//ownValue *= pilotScaleVar
		earnValue *= file.earn_meter_pilot_multiplier
		ownValue *= file.earn_meter_pilot_multiplier
		// if pilot player can't earn, remove all value display
		if ( !PlayerEarnMeter_CanEarn( targetPlayer ) )
		{
			earnValue = 0.0
			ownValue = 0.0
		}
		// if pilot player can only earn overdrive, remove own value display
		else if ( file.earn_meter_pilot_overdrive == ePilotOverdrive.Only )
			ownValue = 0.0
		// if pilot player can't earn overdrive, remove earn value display
		else if ( file.earn_meter_pilot_overdrive == ePilotOverdrive.Disabled )
			earnValue = 0.0
	}

	// nessie modify
	if ( file.disableCallSignEvent )
	{
		if ( event.displayType & eEventDisplayType.CALLINGCARD )
			event.displayType = event.displayType & ~eEventDisplayType.CALLINGCARD
	}
	//
	// debug
	//print( "calculated earnValue: " + string( earnValue ) )
	//print( "calculated ownValue: " + string( ownValue ) )
	
	// modified: displayTypeOverride
	if ( displayTypeOverride != null ) // has overrides?
	{
		// anti-crash for calling in GameModeRulesEarnMeterOnDamage_Default()
		if ( typeof( displayTypeOverride ) == "int" )
			event.displayType = expect int( displayTypeOverride )
		else
			event.displayType = int( displayTypeOverride )
	}
	
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
	{
		// change to use wrapped function for get settings
		//PlayFactionDialogueToPlayer( event.conversation, targetPlayer )
		// by default, earnValueOverrideEnt will be our victim. but if that isn't valid, try using associatedEnt if it's not player themselves
		entity victimEnt
		if ( IsValid( earnValueOverrideEnt ) )
			victimEnt = earnValueOverrideEnt
		else if ( associatedEnt != targetPlayer )
			victimEnt = associatedEnt
		ScoreEvent_PlayFactionDialogueToPlayer( event.conversation, targetPlayer, victimEnt )
	}
		
	HandleXPGainForScoreEvent( targetPlayer, event )
}

void function ScoreEvent_PlayerKilled( entity victim, entity attacker, var damageInfo )
{
	// reset killstreaks and stuff	
	// moved to OnPlayerRespawned()
	// though it's not vanilla behavior, having killstreak after death is funny( like for grenadier weapons )
	/*
	victim.s.currentKillstreak = 0
	victim.s.lastKillTime = 0.0
	victim.s.currentTimedKillstreak = 0
	// npc&player mixed killstreaks
	victim.s.lastMixedKillTime = 0.0
	victim.s.currentMayhemKillstreak = 0
	victim.s.currentOnslaughtKillstreak = 0
	*/
	
	// moving these to OnPlayerDeath(), because ScoreEvent_PlayerKilled() isn't always called
	/*
	victim.p.numberOfDeathsSinceLastKill++ // this is reset on kill
	victim.p.lastDeathTime = Time()
	*/
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
	string pilotKillEvent = "KillPilot"
	if( IsPilotEliminationBased() )
		pilotKillEvent = "EliminatePilot" // elimination gamemodes have a special medal

	AddPlayerScore( attacker, pilotKillEvent, victim, null, -1, 1.0, victim )

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

	// increment untimed killstreaks against specific players
	if ( !( victim in attacker.p.playerKillStreaks ) )
		attacker.p.playerKillStreaks[ victim ] <- 1
	else
		attacker.p.playerKillStreaks[ victim ]++
	
	// dominating
	if ( attacker.p.playerKillStreaks[ victim ] >= DOMINATING_KILL_REQUIREMENT )
		AddPlayerScore( attacker, "Dominating", victim )
	
	// timed killstreak broke
	if ( Time() - attacker.s.lastKillTime > CASCADINGKILL_REQUIREMENT_TIME )
		attacker.s.currentTimedKillstreak = 0 // reset first before adding score
	
	// timed killstreaks
	attacker.s.currentTimedKillstreak++
	
	if ( attacker.s.currentTimedKillstreak == DOUBLEKILL_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "DoubleKill", attacker )
	else if ( attacker.s.currentTimedKillstreak == TRIPLEKILL_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "TripleKill", attacker )
	else if ( attacker.s.currentTimedKillstreak >= MEGAKILL_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "MegaKill", attacker )
	
	attacker.s.lastKillTime = Time() // update last kill time

	// npc&player mixed killsteaks
	UpdateUntimedKillStreaks( attacker )
	UpdateMixedTimedKillStreaks( attacker )

	// assist. was previously be in _base_gametype_mp.gnut, which is bad. vanilla won't add assist on npc killing a player
	if ( !victim.IsTitan() ) // titan assist handled by ScoreEvent_TitanKilled()
	{
		// wrap into this function
		ScoreEvent_PlayerAssist( victim, attacker, "PilotAssist" )
	}
}

// npc&player mixed killsteaks
void function UpdateUntimedKillStreaks( entity attacker )
{
	// untimed killstreaks
	attacker.s.currentKillstreak++
	if ( attacker.s.currentKillstreak == KILLINGSPREE_KILL_REQUIREMENT )
		AddPlayerScore( attacker, "KillingSpree", attacker )
	else if ( attacker.s.currentKillstreak == RAMPAGE_KILL_REQUIREMENT )
		AddPlayerScore( attacker, "Rampage", attacker )
}

void function UpdateMixedTimedKillStreaks( entity attacker )
{
	// mayhem and onslaught, won't add any value but vanilla have these events
	// mayhem killstreak broke
	if ( attacker.s.lastMixedKillTime < Time() - MAYHEM_REQUIREMENT_TIME )
		attacker.s.currentMayhemKillstreak = 0
	// onslaught killstreak broke
	if ( attacker.s.lastMixedKillTime < Time() - ONSLAUGHT_REQUIREMENT_TIME )
		attacker.s.currentOnslaughtKillstreak = 0

	// mayhem
	attacker.s.currentMayhemKillstreak++
	if ( attacker.s.currentMayhemKillstreak == MAYHEM_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "Mayhem" )
	// onslaught
	attacker.s.currentOnslaughtKillstreak++
	if ( attacker.s.currentOnslaughtKillstreak == ONSLAUGHT_REQUIREMENT_KILLS )
		AddPlayerScore( attacker, "Onslaught" )
	
	attacker.s.lastMixedKillTime = Time() // update last kill time
}

// this only gets called when titan's owner is player
void function ScoreEvent_TitanDoomed( entity titan, entity attacker, var damageInfo )
{
	// will this handle npc titans with no owners well? i have literally no idea
	if ( titan.IsPlayer() )
		AddPlayerScore( attacker, "DoomTitan", titan )
	else
		AddPlayerScore( attacker, "DoomAutoTitan", titan )
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

	// run callbacks
	foreach ( callbackFunc in file.titanDoomedScoreEventCallbacks )
		callbackFunc( titan, damageInfo, firstDoom )
}

void function ScoreEvent_TitanKilled( entity victim, entity attacker, var damageInfo )
{
	// will this handle npc titans with no owners well? i have literally no idea
	// this won't, attacker needs to have a player owner or something to trigger score event
	if ( !attacker.IsPlayer() )
		return

	// modified for npc pilot embarked titan
#if NPC_TITAN_PILOT_PROTOTYPE
	entity owner = victim.GetOwner()
	bool hasNPCPilot = TitanHasNpcPilot( victim )
	// EDIT here: no need to handle ejecting case!
	// npc can always eject even with pilots still inside
	/*
	bool isEjecting = true // npc pilot ejecting meaning their titan already died. default to be true
	if ( IsValid( victim.GetTitanSoul() ) )
		isEjecting = victim.GetTitanSoul().IsEjecting()
	*/
	// debug
	//print( "hasNPCPilot: " + string( hasNPCPilot ) )
	//print( "isEjecting: " + string( isEjecting ) )
#endif

	string scoreEvent = "KillTitan"
	if ( attacker.IsTitan() )
		scoreEvent = "TitanKillTitan"
	else if( victim.IsNPC() ) // vanilla still use KillAutoTitan even if the titan is pet titan... pretty weird
	{
		scoreEvent = "KillAutoTitan"

		// modified for npc pilot embarked titan
#if NPC_TITAN_PILOT_PROTOTYPE
		// EDIT here: no need to handle ejecting case!
		//if ( hasNPCPilot && !isEjecting )
		if ( hasNPCPilot )
		{
			scoreEvent = "KillTitan"
			if ( attacker.IsTitan() )
				scoreEvent = "TitanKillTitan"
		}
#endif
	}
	// debug
	//print( "scoreEvent: " + scoreEvent )

	if( IsTitanEliminationBased() )
	{
		scoreEvent = "EliminateTitan"
		if( victim.IsNPC() )
		{
			scoreEvent = "EliminateAutoTitan"
			// modified for npc pilot embarked titan
#if NPC_TITAN_PILOT_PROTOTYPE
			if ( hasNPCPilot )
				scoreEvent = "EliminateTitan"
#endif
		}
	}

	bool isPlayerTitan = IsValid( victim.GetBossPlayer() ) || victim.IsPlayer()
	// modified here: we now always do callsign event on titan kill
	//if( isPlayerTitan ) // to confirm this is a pet titan or player titan
		AddPlayerScore( attacker, scoreEvent, attacker, null, -1, 1.0, victim ) // this will show the "Titan Kill" callsign event
	//else
	//	AddPlayerScore( attacker, scoreEvent ) // no callsign event

	bool playTitanKilledDiag = isPlayerTitan
	// modified for npc pilot embarked titan
#if NPC_TITAN_PILOT_PROTOTYPE
	bool isNPCPilotPet = TitanIsNpcPilotPetTitan( victim )
	//print( "isNPCPilotPet: " + string( isNPCPilotPet ) )
	playTitanKilledDiag = isPlayerTitan || hasNPCPilot || isNPCPilotPet
#endif

	if ( playTitanKilledDiag )
		KilledPlayerTitanDialogue( attacker, victim )

	// npc&player mixed killsteaks
	// only handle npc victim case-- player victim already handled by ScoreEvent_PlayerKilled()
	// welp, this check is because vanilla don't count "player controlled titan" as two kills( pilot and titan )
	// but this detail wasn't very necessary, why don't we just give players more kill streak for fun!
	
	//if ( !victim.IsPlayer() )
	//{
		UpdateUntimedKillStreaks( attacker )
		UpdateMixedTimedKillStreaks( attacker )
	//}

	// titan damage history stores in titanSoul, but if they killed by termination it's gonna transfer to victim themselves
	// seems no need to specify such a check... souls will still retain their damage history
	/*
	bool killedByTermination = DamageInfo_GetDamageSourceIdentifier( damageInfo ) == eDamageSourceId.titan_execution
	entity damageHistorySaver = killedByTermination ? victim : victim.GetTitanSoul()
	if ( IsValid( damageHistorySaver ) )
	{
		// debug
		//print( "damageHistorySaver valid! " + string( damageHistorySaver ) )
		// wrap into this function
		ScoreEvent_PlayerAssist( damageHistorySaver, attacker, "TitanAssist" )
	}
	*/
	entity titanSoul = victim.GetTitanSoul()
	if ( IsValid( titanSoul ) )
	{
		// wrap into this function
		ScoreEvent_PlayerAssist( titanSoul, attacker, "TitanAssist" )
	}
}

void function ScoreEvent_NPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !attacker.IsPlayer() )
		return

	// validation checks
	if ( !IsValidNPCTarget( victim ) ) // might be unnecessary, PlayerOrNPCKilled() in base_gametype.gnut already handled this
		return	
	
	// maybe no need to try-catch after changing IsValidNPCTarget() checks
	// welp we still need, respawn hardcode too many stuffs and always throw "unreachable"
	try
	{
		// to prevent crash happen when killing a modified npc target
		AddPlayerScore( attacker, ScoreEventForNPCKilled( victim, damageInfo ), victim, null, -1, 1.0, victim )
	}
	catch(ex) {}

	// headshot
	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_HEADSHOT )
		AddPlayerScore( attacker, "Headshot", victim, null, -1, 0.0, victim ) // no extra value earn from npc headshots

	// npc&player mixed killsteaks
	UpdateMixedTimedKillStreaks( attacker )
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

// vanilla behavior, northstar missing
void function ScoreEvent_VictoryKill( entity attacker )
{
	AddPlayerScore( attacker, "VictoryKill", attacker ) // show a callsign event
}

void function ScoreEvent_SetEarnMeterValues( string eventName, float earned, float owned, float coreScale = 1.0 )
{
	ScoreEvent event = GetScoreEvent( eventName )
	event.earnMeterEarnValue = earned
	event.earnMeterOwnValue = owned
	event.coreMeterScalar = coreScale
}

// welp I think is is pretty bad, we should store these things in file.table, never touch struct themselves?
// but it works fine so guess it's alright?
void function ScoreEvent_SetEventDisplayTypes( string eventName, int displayTypes )
{
	ScoreEvent event = GetScoreEvent( eventName )
	event.displayType = displayTypes
}

void function ScoreEvent_SetupEarnMeterValuesForMixedModes() // mixed modes in this case means modes with both pilots and titans
{
	if ( IsLobby() ) // setup score events in lobby can cause crash
		return

	// pilot kill
	ScoreEvent_SetEarnMeterValues( "KillPilot", 0.10, 0.05 )
	ScoreEvent_SetEarnMeterValues( "EliminatePilot", 0.10, 0.05 )
	ScoreEvent_SetEarnMeterValues( "PilotAssist", 0.03, 0.020001, 0.0 ) // if set to "0.03, 0.02", will display as "4%"
	// titan doom
	ScoreEvent_SetEarnMeterValues( "DoomTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "DoomAutoTitan", 0.0, 0.0 )
	// titan kill
	// don't know why auto titan kills appear to be no value in vanilla
	// even when the titan have an owner player
	ScoreEvent_SetEarnMeterValues( "KillTitan", 0.20, 0.10, 0.0 )
	ScoreEvent_SetEarnMeterValues( "KillAutoTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "EliminateTitan", 0.20, 0.10, 0.0 )
	ScoreEvent_SetEarnMeterValues( "EliminateAutoTitan", 0.0, 0.0 )
	ScoreEvent_SetEarnMeterValues( "TitanKillTitan", 0.0, 0.0 )
	// but titan assist do have earn values... 
	// maybe because they're not splitted into AutoTitan or PlayerTitan variant
	ScoreEvent_SetEarnMeterValues( "TitanAssist", 0.10, 0.10 )
	// rodeo
	ScoreEvent_SetEarnMeterValues( "PilotBatteryStolen", 0.0, 0.35, 0.0 )
	ScoreEvent_SetEarnMeterValues( "PilotBatteryApplied", 0.0, 0.35, 0.0 )
	// special method of killing
	ScoreEvent_SetEarnMeterValues( "Headshot", 0.0, 0.02, 0.0 )
	ScoreEvent_SetEarnMeterValues( "FirstStrike", 0.03, 0.020001, 0.0 ) // if set to "0.03, 0.02", will display as "4%"
	
	// ai
	// so here's a funny twist, respawn don't know "0.03, 0.02" will display as 4%
	// which means actual vanilla infantry value is 5% but it displays as 4%
	// (if you set earnmeter multiplier to 5.0 it displays as 24%, proving my thought)
	ScoreEvent_SetEarnMeterValues( "KillGrunt", 0.03, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillSpectre", 0.03, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "LeechSpectre", 0.03, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillHackedSpectre", 0.03, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillStalker", 0.03, 0.020001, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillSuperSpectre", 0.10, 0.10, 0.5 )
	ScoreEvent_SetEarnMeterValues( "KillLightTurret", 0.05, 0.050001 )


	// display type
	// default case is adding a eEventDisplayType.CENTER, required for client to show earnvalue on screen
	ScoreEvent_SetEventDisplayTypes( "KillPilot", GetScoreEvent( "KillPilot" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "EliminatePilot", GetScoreEvent( "EliminatePilot" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "PilotAssist", GetScoreEvent( "PilotAssist" ).displayType | eEventDisplayType.CENTER )
	// doom a titan shouldn't be displayed at center of screen

	ScoreEvent_SetEventDisplayTypes( "KillTitan", GetScoreEvent( "KillTitan" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "KillAutoTitan", GetScoreEvent( "KillAutoTitan" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "EliminateTitan", GetScoreEvent( "EliminateTitan" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "EliminateAutoTitan", GetScoreEvent( "EliminateAutoTitan" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "TitanKillTitan", GetScoreEvent( "TitanKillTitan" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "TitanAssist", GetScoreEvent( "TitanAssist" ).displayType | eEventDisplayType.CENTER )
	
	ScoreEvent_SetEventDisplayTypes( "PilotBatteryStolen", GetScoreEvent( "PilotBatteryStolen" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "PilotBatteryApplied", GetScoreEvent( "PilotBatteryApplied" ).displayType | eEventDisplayType.CENTER )
	
	ScoreEvent_SetEventDisplayTypes( "Headshot", GetScoreEvent( "Headshot" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "FirstStrike", GetScoreEvent( "FirstStrike" ).displayType | eEventDisplayType.CENTER )
	
	ScoreEvent_SetEventDisplayTypes( "KillGrunt", GetScoreEvent( "KillGrunt" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "KillSpectre", GetScoreEvent( "KillSpectre" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "LeechSpectre", GetScoreEvent( "LeechSpectre" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "KillHackedSpectre", GetScoreEvent( "KillHackedSpectre" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "KillStalker", GetScoreEvent( "KillStalker" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "KillSuperSpectre", GetScoreEvent( "KillSuperSpectre" ).displayType | eEventDisplayType.CENTER )
	ScoreEvent_SetEventDisplayTypes( "KillLightTurret", GetScoreEvent( "KillLightTurret" ).displayType | eEventDisplayType.CENTER )
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

	// we allow disable dialogue when killing certain entity, use wrapped function
	//PlayFactionDialogueToPlayer( dialogue, attacker )
	ScoreEvent_PlayFactionDialogueToPlayer( dialogue, attacker, titan )
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

void function ScoreEvent_SetDisabledForEntity( entity ent, bool disable )
{
	if ( !( ent in file.entScoreEventDisabled ) )
		file.entScoreEventDisabled[ ent ] <- false
	file.entScoreEventDisabled[ ent ] = disable
}

bool function ScoreEvent_IsDisabledForEntity( entity ent )
{
	if ( !( ent in file.entScoreEventDisabled ) )
		return false // default is we never disable entity's score event
	return file.entScoreEventDisabled[ ent ]
}

void function ScoreEvent_SetEntityEarnValueOverride( entity ent, string scoreEventName, float earnValue, float ownValue, float coreScalar = 1.0, float earnMeterScalar = 1.0 )
{
	EarnValueOverride newOverride
	newOverride.earnMeterEarnValue = earnValue
	newOverride.earnMeterOwnValue = ownValue
	newOverride.coreMeterScalar = coreScalar
	newOverride.earnMeterScalar = earnMeterScalar

	if ( !( ent in file.entScoreEventValueOverride ) )
		file.entScoreEventValueOverride[ ent ] <- {}
	
	if ( !( scoreEventName in file.entScoreEventValueOverride[ ent ] ) )
		file.entScoreEventValueOverride[ ent ][ scoreEventName ] <- newOverride
	else
		file.entScoreEventValueOverride[ ent ][ scoreEventName ] = newOverride
}

void function ScoreEvent_DisableEntityFactionDialogueEvent( entity ent, bool disable )
{
	if ( !( ent in file.entScoreEventDialogueDisabled ) )
		file.entScoreEventDialogueDisabled[ ent ] <- false
	file.entScoreEventDialogueDisabled[ ent ] = disable
}

// wrapped function, only do score event if entity's event isn't disabled
bool function ScoreEvent_PlayFactionDialogueToPlayer( string dialogueName, entity player, entity victimEnt = null )
{
	if ( ( victimEnt in file.entScoreEventDialogueDisabled ) && file.entScoreEventDialogueDisabled[ victimEnt ] )
		return false

	PlayFactionDialogueToPlayer( dialogueName, player )
	return true
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

// wrap assist checks into this function
void function ScoreEvent_PlayerAssist( entity victim, entity attacker, string eventName, var displayTypeOverride = null )
{
	// add error handle
	if ( !IsValid( victim ) || victim.IsMarkedForDeletion() )
		return

	table<int, bool> alreadyAssisted
	foreach( DamageHistoryStruct attackerInfo in victim.e.recentDamageHistory )
	{
		// Give all assisted player an extra score event
		// Not for attack themselves only

		// debug
		//print( "attackerInfo.attacker: " + string( attackerInfo.attacker ) )

		// generic check
		if ( !IsValid( attackerInfo.attacker ) || !attackerInfo.attacker.IsPlayer() )
			continue
		// checks for self damage
		if ( attackerInfo.attacker == victim )
			continue
		// checks for blank damage( scorch thermite, pilot non-critical-hit titan or smoke healing stuffs )
		if ( attackerInfo.damage <= 0 )
			continue
		// checks for player owned entities( such as titan, spectre or soul )
		// owner checks has been removed because it only handles visibility stuffs, not related with ownership
		//if ( attackerInfo.attacker == victim.GetOwner() || attackerInfo.attacker == victim.GetBossPlayer() )
		if ( attackerInfo.attacker == victim.GetBossPlayer() )
			continue
		
		// if we're getting damage history from soul, should ignore their titan's self damage and owner's damage
		if ( IsSoul( victim ) )
		{
			entity titan = victim.GetTitan()
			if ( IsValid( titan ) )
			{
				// checks for self damage
				if ( attackerInfo.attacker == titan )
				{
					//print( "victim is soul but attacker is it's titan! skipping Assist score" )
					return
				}
				// checks for player owned entities
				if ( attackerInfo.attacker == titan.GetBossPlayer() )
					continue
			}
		}
		
		bool exists = attackerInfo.attacker.GetEncodedEHandle() in alreadyAssisted ? true : false
		if( attackerInfo.attacker != attacker && !exists )
		{
			alreadyAssisted[attackerInfo.attacker.GetEncodedEHandle()] <- true
			Remote_CallFunction_NonReplay( attackerInfo.attacker, "ServerCallback_SetAssistInformation", attackerInfo.damageSourceId, attacker.GetEncodedEHandle(), victim.GetEncodedEHandle(), attackerInfo.time )
			AddPlayerScore( attackerInfo.attacker, eventName, victim, displayTypeOverride, -1, 1.0, victim )
			attackerInfo.attacker.AddToPlayerGameStat( PGS_ASSISTS, 1 )
		}
	}
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