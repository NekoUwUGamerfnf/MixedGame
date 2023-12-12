// NESSIE: the file has been modified to add npc compatibility. maybe separent a file "npc_cloak.nut"?
untyped //TODO: get rid of player.s.cloakedShotsAllowed. (Referenced in base_gametype_sp, so remove for R5)

global function PlayerCloak_Init

global const CLOAK_FADE_IN = 1.0
global const CLOAK_FADE_OUT = 1.0

global function EnableCloak
global function DisableCloak
global function EnableCloakForever
global function DisableCloakForever

//=========================================================
//	player_cloak
//
//=========================================================

void function PlayerCloak_Init()
{
	RegisterSignal( "OnStartCloak" )
	RegisterSignal( "KillHandleCloakEnd" ) //Somewhat awkward, mainly to smooth out weird interactions with cloak ability and cloak execution

	AddCallback_OnPlayerKilled( AbilityCloak_OnDeath )
	AddSpawnCallback( "npc_titan", SetCannotCloak ) // nessie: does this make any sense?
	// adding npc usage support
	AddCallback_OnNPCKilled( AbilityCloak_OnDeath )
}

void function SetCannotCloak( entity ent )
{
	ent.SetCanCloak( false )
}

void function PlayCloakSounds( entity player )
{
	// clear last sound so player won't receive too much noise!
	if ( player.IsPlayer() )
		StopSoundOnEntity( player, "cloak_sustain_loop_1P" )
	StopSoundOnEntity( player, "cloak_sustain_loop_3P" )
	// add npc cloak compatibility
	if ( player.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_on_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "cloak_on_3P" )

		EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_sustain_loop_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "cloak_sustain_loop_3P" )
	}
	else
	{
		EmitSoundOnEntity( player, "cloak_on_3P" )
		EmitSoundOnEntity( player, "cloak_sustain_loop_3P" )
	}
}

void function EnableCloak( entity player, float duration, float fadeIn = CLOAK_FADE_IN )
{
	// add npc cloak compatibility
	if ( player.IsPlayer() && player.cloakedForever )
		return
	if ( player.IsNPC() )
		player.SetCanCloak( true ) // npc is default to be cannotCloak. needs to enable

	//print( "RUNNING EnableCloak() for player: " + string( player ) + " , duration: " +string( duration ) )

	// add npc cloak compatibility
	if ( player.IsPlayer() )
		thread AICalloutCloak( player )

	PlayCloakSounds( player )

	float cloakDuration = duration - fadeIn

	Assert( cloakDuration > 0.0, "Not valid cloak duration. Check that duration is larger than the fadeinTime. When this is not true it will cause the player to be cloaked forever. If you want to do that use EnableCloakForever instead" )

	player.SetCloakDuration( fadeIn, cloakDuration, CLOAK_FADE_OUT )

	// add npc cloak compatibility, ensure this index has been initilized
	if ( !( "cloakedShotsAllowed" in player.s ) )
		player.s.cloakedShotsAllowed <- 0
	//

	player.s.cloakedShotsAllowed = 0

	// add npc cloak compatibility
	if ( player.IsPlayer() )
		Battery_StopFXAndHideIconForPlayer( player )

	thread HandleCloakEnd( player )
}

void function AICalloutCloak( entity player )
{
	player.EndSignal( "OnDeath" )

	wait CLOAK_FADE_IN //Give it a beat after cloak has finishing cloaking in

	array<entity> nearbySoldiers = GetNPCArrayEx( "npc_soldier", TEAM_ANY, player.GetTeam(), player.GetOrigin(), 1000  )  //-1 for distance parameter means all spectres in map
	foreach ( entity grunt in nearbySoldiers )
	{
		if ( !IsAlive( grunt ) )
			continue

		if ( grunt.GetEnemy() == player )
		{
			ScriptDialog_PilotCloaked( grunt, player )
			return //Only need one guy to say this instead of multiple guys
		}
	}
}

void function EnableCloakForever( entity player )
{
	// add npc cloak compatibility
	if ( player.IsNPC() )
		player.SetCanCloak( true ) // npc is default to be cannotCloak. needs to enable
	//

	player.SetCloakDuration( CLOAK_FADE_IN, -1, CLOAK_FADE_OUT )

	// add npc cloak compatibility
	if ( player.IsPlayer() )
		player.cloakedForever = true

	thread HandleCloakEnd( player )
	PlayCloakSounds( player )
}


void function DisableCloak( entity player, float fadeOut = CLOAK_FADE_OUT )
{
	//print( "RUNNING DisableCloak() for player: " + string( player ) )

	// vanilla seems to miss this behavior
	// we need to clean up any running HandleCloakEnd() think on decloak
	player.Signal( "KillHandleCloakEnd" )

	StopSoundOnEntity( player, "cloak_sustain_loop_1P" )
	StopSoundOnEntity( player, "cloak_sustain_loop_3P" )

	bool wasCloaked = player.IsCloaked( CLOAK_INCLUDE_FADE_IN_TIME )

	if ( fadeOut < CLOAK_FADE_OUT && wasCloaked )
	{
		// add npc cloak compatibility
		if ( player.IsPlayer() )
		{
			EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_interruptend_1P" )
			EmitSoundOnEntityExceptToPlayer( player, player, "cloak_interruptend_3P" )
		}
		else
			EmitSoundOnEntity( player, "cloak_interruptend_3P" )

		StopSoundOnEntity( player, "cloak_warningtoend_1P" )
		StopSoundOnEntity( player, "cloak_warningtoend_3P" )
	}

	player.SetCloakDuration( 0, 0, fadeOut )

	// add npc cloak compatibility
	// no need to clean up this, will make their fadeOut flicker seem bad
	//if ( player.IsNPC() )
	//	player.SetCanCloak( false ) // set npc's cloak availability to default
}

void function DisableCloakForever( entity player, float fadeOut = CLOAK_FADE_OUT )
{
	DisableCloak( player, fadeOut )
	// add npc cloak compatibility
	if ( player.IsPlayer() )
		player.cloakedForever = false
}


void function HandleCloakEnd( entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnEMPPilotHit" )
	player.EndSignal( "OnChangedPlayerClass" )
	player.Signal( "OnStartCloak" )
	player.EndSignal( "OnStartCloak" )
	player.EndSignal( "KillHandleCloakEnd" ) //Calling DisableCloak() after EnableCloak() doesn't kill this thread by design (to allow attacking through cloak etc), so this signal is for when you want to kill this thread

	float duration = player.GetCloakEndTime() - Time()

	OnThreadEnd(
		function() : ( player )
		{
			//print( "RUNNING HandleCloakEnd() OnTheadEnd" )
			if ( !IsValid( player ) )
				return
			// add npc cloak compatibility
			//if ( PlayerHasBattery( player ) )
			if ( player.IsPlayer() && PlayerHasBattery( player ) )
				Battery_StartFX( GetBatteryOnBack( player ) )

			StopSoundOnEntity( player, "cloak_sustain_loop_1P" )
			StopSoundOnEntity( player, "cloak_sustain_loop_3P" )
			if ( !IsCloaked( player ) )
				return

			if ( !IsAlive( player ) || !player.IsHuman() )
			{
				DisableCloak( player )
				return
			}

			float duration = player.GetCloakEndTime() - Time()
			if ( duration <= 0 )
			{
				DisableCloak( player )
			}
		}
	)

	float soundBufferTime = 3.45

	if ( duration > soundBufferTime )
	{
		wait ( duration - soundBufferTime )
		// clear last sound so player won't receive too much noise!
		if ( player.IsPlayer() )
			StopSoundOnEntity( player, "cloak_sustain_loop_1P" )
		StopSoundOnEntity( player, "cloak_sustain_loop_3P" )
		// add npc cloak compatibility
		if ( player.IsPlayer() )
		{
			if ( !IsCloaked( player ) ) // npc cloak isn't very accurate, no need to check this
				return

			EmitSoundOnEntityOnlyToPlayer( player, player, "cloak_warningtoend_1P" )
			EmitSoundOnEntityExceptToPlayer( player, player, "cloak_warningtoend_3P" )
		}
		else
			EmitSoundOnEntity( player, "cloak_warningtoend_3P" )

		wait soundBufferTime
	}
	else
	{
		wait duration
	}
}


void function AbilityCloak_OnDeath( entity player, entity attacker, var damageInfo )
{
	if ( !IsCloaked( player ) )
		return

	DisableCloak( player, 0 )
}