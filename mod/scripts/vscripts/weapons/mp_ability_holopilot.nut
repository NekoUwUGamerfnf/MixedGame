global function OnWeaponPrimaryAttack_holopilot
global function PlayerCanUseDecoy

global const int DECOY_FADE_DISTANCE = 16000 //Really just an arbitrarily large number
global const float DECOY_DURATION = 10.0

global const vector HOLOPILOT_ANGLE_SEGMENT = < 0, 25, 0 >

#if SERVER
global function CodeCallback_PlayerDecoyDie
global function CodeCallback_PlayerDecoyDissolve
global function CodeCallback_PlayerDecoyRemove
global function CodeCallback_PlayerDecoyStateChange
global function CreateHoloPilotDecoys
global function SetupDecoy_Common

global function Decoy_Init

global function SetNessieDecoyOn
#if MP
global function GetDecoyActiveCountForPlayer
#endif //if MP

#endif //if server

// for holoshift
global function OnWeaponOwnerChange_holopilot

const float PHASE_REWIND_PATH_SNAPSHOT_INTERVAL = 0.1

// for infinite_decoy
const int WORLD_MAX_DECOY_COUNT = 24 // you can only spawn this much of decoy!

struct
{
	table< entity, int > playerToDecoysActiveTable //Mainly used to track stat for holopilot unlock

	// holoshift tables
	table< entity > playerDecoyList //CUSTOM used to track the decoy the user will be teleported to

	// strange things
	bool isInfiniteDecoy = false
	bool isStrangeDecoy = false
	// infinite decoy array
	array<entity> infiniteDecoyOnWorld = []

	// defined for nessy.gnut
	bool isNessieOutfit = false
}
file



/*Player decoy states: defined in player_decoy_shared.h
	PLAYER_DECOY_STATE_NONE,
	PLAYER_DECOY_STATE_IDLE,
	PLAYER_DECOY_STATE_CROUCH_IDLE,
	PLAYER_DECOY_STATE_CROUCH_WALK,
	PLAYER_DECOY_STATE_WALLHANG,
	PLAYER_DECOY_STATE_AIRBORNE,
	PLAYER_DECOY_STATE_WALK,
	PLAYER_DECOY_STATE_RUN,
	PLAYER_DECOY_STATE_SPRINT,
	PLAYER_DECOY_STATE_DYING,
	PLAYER_DECOY_STATE_COUNT
*/

// mirage_decoy
const float MIRAGE_DECOY_LIFETIME = 60.0
// hardcode every movement here
const string MIRAGE_DECOY_FORWARD = "DecoyMoveForward"
const string MIRAGE_DECOY_LEFT = "DecoyMoveLeft"
const string MIRAGE_DECOY_RIGHT = "DecoyMoveRight"
const string MIRAGE_DECOY_BACK = "DecoyMoveBack"
const string MIRAGE_DECOY_SPRINT = "DecoySprint"
const string MIRAGE_DECOY_CROUCH = "DecoyCrouch"
const string MIRAGE_DECOY_JUMP = "DecoyJump"
const string MIRAGE_DECOY_WALLRUN = "DecoyWallRun"
const string MIRAGE_DECOY_SLIDE = "DecoySlide"
struct MirageDecoyStruct
{
	entity decoy
	string lastAction
}
table< string, MirageDecoyStruct > mirageDecoyTable // use to track remote decoys
//

// reset decoy's model will lead to a really weird behavior
const array<asset> RANDOM_DECOY_ASSETS = 
[
	$"models/humans/pilots/pilot_medium_stalker_m.mdl", 
	$"models/humans/pilots/pilot_medium_stalker_f.mdl", 
	$"models/humans/pilots/pilot_light_ged_f.mdl", 
	$"models/humans/pilots/pilot_light_ged_m.mdl", 
	$"models/humans/pilots/pilot_light_jester_m.mdl", 
	$"models/humans/pilots/pilot_light_jester_f.mdl", 
	$"models/humans/pilots/pilot_medium_reaper_m.mdl", 
	$"models/humans/pilots/pilot_medium_reaper_f.mdl", 
	$"models/humans/pilots/pilot_medium_geist_m.mdl", 
	$"models/humans/pilots/pilot_medium_geist_f.mdl", 
	$"models/humans/grunts/mlt_grunt_lmg.mdl", 
	$"models/humans/grunts/imc_grunt_lmg.mdl", 
	$"models/humans/heroes/imc_hero_ash.mdl", 
	$"models/humans/heroes/mlt_hero_jack.mdl", 
	$"models/humans/heroes/mlt_hero_sarah.mdl", 
	$"models/humans/heroes/imc_hero_blisk.mdl", 
	$"models/humans/pilots/sp_medium_geist_f.mdl", 
	$"models/humans/pilots/sp_medium_reaper_m.mdl", 
	$"models/humans/pilots/sp_medium_stalker_m.mdl"
]

#if SERVER

void function Decoy_Init()
{
	#if MP
		RegisterSignal( "CleanupFXAndSoundsForDecoy" )
	#endif

	#if SERVER
	RegisterSignal( "HoloShiftCooldownThink" )
	#endif
}

void function CleanupExistingDecoy( entity decoy )
{
	if ( IsValid( decoy ) ) //This cleanup function is called from multiple places, so check that decoy is still valid before we try to clean it up again
	{
		decoy.Decoy_Dissolve()
		CleanupFXAndSoundsForDecoy( decoy )
	}
}

void function CleanupFXAndSoundsForDecoy( entity decoy )
{
	if ( !IsValid( decoy ) )
		return

	decoy.Signal( "CleanupFXAndSoundsForDecoy" )

	foreach( fx in decoy.decoy.fxHandles )
	{
		if ( IsValid( fx ) )
		{
			fx.ClearParent()
			EffectStop( fx )
		}
	}

	decoy.decoy.fxHandles.clear() //probably not necessary since decoy is already being cleaned up, just for throughness.

	foreach ( loopingSound in decoy.decoy.loopingSounds )
	{
		StopSoundOnEntity( decoy, loopingSound )
	}

	decoy.decoy.loopingSounds.clear()
}

void function OnHoloPilotDestroyed( entity decoy )
{
	EmitSoundAtPosition( TEAM_ANY, decoy.GetOrigin(), "holopilot_end_3P" )

	entity bossPlayer = decoy.GetBossPlayer()
	if ( IsValid( bossPlayer ) )
	{
		EmitSoundOnEntityOnlyToPlayer( bossPlayer, bossPlayer, "holopilot_end_1P" )

		// holoshift clean up
		if( bossPlayer in file.playerDecoyList )
		{
			if( decoy == file.playerDecoyList[bossPlayer] )
				delete file.playerDecoyList[bossPlayer]

		}

		// infinite decoy clean up
		file.infiniteDecoyOnWorld.removebyvalue( decoy )
	}
	CleanupFXAndSoundsForDecoy( decoy )
	ClearNessy( decoy )
}

void function CodeCallback_PlayerDecoyDie( entity decoy, int currentState ) //All Die does is play the death animation. Eventually calls CodeCallback_PlayerDecoyDissolve too
{
	//PrintFunc()
	OnHoloPilotDestroyed( decoy )
}

void function CodeCallback_PlayerDecoyDissolve( entity decoy, int currentState )
{
	//PrintFunc()
	OnHoloPilotDestroyed( decoy )
}


void function CodeCallback_PlayerDecoyRemove( entity decoy, int currentState )
{
	//PrintFunc()
}


void function CodeCallback_PlayerDecoyStateChange( entity decoy, int previousState, int currentState )
{
	//PrintFunc()
}

#endif

// for holoshift
void function OnWeaponOwnerChange_holopilot( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
	thread DelayedCheckHoloshift( weapon )
	#endif
}

#if SERVER
void function DelayedCheckHoloshift( entity weapon )
{
	weapon.EndSignal( "OnDestroy" )
	WaitFrame()
	if( weapon.HasMod( "holoshift" ) )
		thread HoloShiftCooldownThink( weapon )
}
#endif

var function OnWeaponPrimaryAttack_holopilot( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	Assert( weaponOwner.IsPlayer() )

	if( weapon.HasMod( "dead_ringer" ) )
		return OnAbilityStart_FakeDeath( weapon, attackParams )
	if( weapon.HasMod( "infinite_decoy" ) )
		file.isInfiniteDecoy = true
	if( weapon.HasMod( "strange_decoy" ) )
		file.isStrangeDecoy = true

	if ( !PlayerCanUseDecoy( weapon ) )
		return 0

#if SERVER
	if ( weaponOwner in file.playerDecoyList && weapon.HasMod( "holoshift" ) )
	{
		CreateHoloPilotDecoys( weaponOwner, 1 )
		entity decoy = file.playerDecoyList[ weaponOwner ]
		weapon.SetWeaponPrimaryClipCount(0)
		PlayerUsesHoloRewind(weaponOwner, decoy)

		// in lts you'll drop your battery while phasing back
		/* // not enabled
		if( GetCurrentPlaylistName() == "lts" ) 
		{
			if( PlayerHasBattery(weaponOwner) )
				Rodeo_TakeBatteryAwayFromPilot(weaponOwner)
		}
		*/

		// print("teleporting to"+decoy)
		// print("Origin"+decoy.GetOrigin())
		// print("Angles"+decoy.GetAngles())
		// print("Velocity"+decoy.GetVelocity())
		// weaponOwner.SetOrigin(decoy.GetOrigin())
		// weaponOwner.SetAngles(decoy.GetAngles())
		// weaponOwner.SetVelocity(decoy.GetVelocity())
	}
	/*
	else if( weapon.HasMod( "mirage_decoy" ) )
	{
		entity decoy = CreateHoloPilotDecoys( weaponOwner, 1 )
		thread MirageDecoyThink( weaponOwner, decoy )
	}
	*/
	else
	{
		entity decoy = CreateHoloPilotDecoys( weaponOwner, 1 )
		if( weapon.HasMod( "holoshift" ) )
			file.playerDecoyList[ weaponOwner ] <- decoy
	}
#else
	Rumble_Play( "rumble_holopilot_activate", {} )
#endif

	PlayerUsedOffhand( weaponOwner, weapon )
	//return 0
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

#if SERVER

entity function CreateHoloPilotDecoys( entity player, int numberOfDecoysToMake = 1 )
{
	Assert( numberOfDecoysToMake > 0  )
	Assert( player )

	float displacementDistance = 30.0

	bool setOriginAndAngles = numberOfDecoysToMake > 1

	float stickPercentToRun = 0.65
	if ( setOriginAndAngles )
		stickPercentToRun = 0.0

	entity decoy
	for( int i = 0; i < numberOfDecoysToMake; ++i )
	{
		decoy = player.CreatePlayerDecoy( stickPercentToRun )
		decoy.SetMaxHealth( 50 )
		decoy.SetHealth( 50 )
		decoy.EnableAttackableByAI( 50, 0, AI_AP_FLAG_NONE )
		SetObjectCanBeMeleed( decoy, true )
		if( file.isInfiniteDecoy )
			decoy.SetTimeout( 9999 )
		else
			decoy.SetTimeout( DECOY_DURATION )
		if( file.isStrangeDecoy )
		{
			decoy.SetOrigin( player.GetOrigin() + < 0,0,15 > )
			asset decoyModel = RANDOM_DECOY_ASSETS[ RandomInt( RANDOM_DECOY_ASSETS.len() ) ]
			decoy.SetModel( decoyModel )
			//decoy.SetValueForModelKey( decoyModel )
			DispatchSpawn( decoy )
		}
		if( file.isNessieOutfit )
		{
			CreateNessyHat( hatassets, decoy )
			CreateNessyBackpack( backpackassets, decoy )
			//CreateNessyPistol( pistolassets, decoy )
		}
		if ( setOriginAndAngles )
		{
			vector angleToAdd = CalculateAngleSegmentForDecoy( i, HOLOPILOT_ANGLE_SEGMENT )
			vector normalizedAngle = player.GetAngles() +  angleToAdd
			normalizedAngle.y = AngleNormalize( normalizedAngle.y ) //Only care about changing the yaw
			decoy.SetAngles( normalizedAngle )

			vector forwardVector = AnglesToForward( normalizedAngle )
			forwardVector *= displacementDistance
			decoy.SetOrigin( player.GetOrigin() + forwardVector ) //Using player origin instead of decoy origin as defensive fix, see bug 223066
			PutEntityInSafeSpot( decoy, player, null, player.GetOrigin(), decoy.GetOrigin()  )
		}

		SetupDecoy_Common( player, decoy )

		#if MP
			thread MonitorDecoyActiveForPlayer( decoy, player )
		#endif
	}

	#if BATTLECHATTER_ENABLED
		PlayBattleChatterLine( player, "bc_pHolo" )
	#endif

	if(numberOfDecoysToMake == 1){ // for holoshift to work
		return decoy
	}
}

void function SetupDecoy_Common( entity player, entity decoy ) //functioned out mainly so holopilot execution can call this as well
{
	decoy.SetDeathNotifications( true )
	decoy.SetPassThroughThickness( 0 )
	decoy.SetNameVisibleToOwner( true )
	decoy.SetNameVisibleToFriendly( true )
	decoy.SetNameVisibleToEnemy( true )
	decoy.SetDecoyRandomPulseRateMax( 0.5 ) //pulse amount per second
	decoy.SetFadeDistance( DECOY_FADE_DISTANCE )

	int friendlyTeam = decoy.GetTeam()
	if( !file.isInfiniteDecoy )
	{
		EmitSoundOnEntityToTeam( decoy, "holopilot_loop", friendlyTeam  ) //loopingSound
		EmitSoundOnEntityToEnemies( decoy, "holopilot_loop_enemy", friendlyTeam  ) ///loopingSound
		decoy.decoy.loopingSounds = [ "holopilot_loop", "holopilot_loop_enemy" ]
		Highlight_SetFriendlyHighlight( decoy, "friendly_player_decoy" )
		Highlight_SetOwnedHighlight( decoy, "friendly_player_decoy" )
	}
	else // infinite decoy
	{
		file.infiniteDecoyOnWorld.append( decoy )
		if( file.infiniteDecoyOnWorld.len() >= WORLD_MAX_DECOY_COUNT )
		{
			file.infiniteDecoyOnWorld.removebyvalue( null ) // remove all invalid decoy
			if( IsValid( file.infiniteDecoyOnWorld[0] ) )
				file.infiniteDecoyOnWorld[0].Destroy() // maybe this?
		}
		decoy.SetNameVisibleToOwner( false )
		decoy.SetNameVisibleToFriendly( false )
		decoy.SetNameVisibleToEnemy( false )
	}
	decoy.e.hasDefaultEnemyHighlight = true
	SetDefaultMPEnemyHighlight( decoy )

	int attachID = decoy.LookupAttachment( "CHESTFOCUS" )

	#if MP
	var childEnt = player.FirstMoveChild()
	while ( childEnt != null )
	{
		expect entity( childEnt )

		bool isBattery = false
		bool createHologram = false
		switch( childEnt.GetClassName() )
		{
			case "item_titan_battery":
			{
				isBattery = true
				createHologram = true
				break
			}

			case "item_flag":
			{
				createHologram = true
				break
			}
		}

		// in lts you won't create new decoy after phasing back
		/* // not enabled
		if (GetCurrentPlaylistName() == "lts" ) 
		{
			if( !( player in file.playerDecoyList ) )
			{
				if( isBattery )
					createHologram = false;
			}
		}
		*/

		asset modelName = childEnt.GetModelName()
		if ( createHologram && modelName != $"" && childEnt.GetParentAttachment() != "" )
		{
			entity decoyChildEnt = CreatePropDynamic( modelName, <0, 0, 0>, <0, 0, 0>, 0 )
			decoyChildEnt.Highlight_SetInheritHighlight( true )
			decoyChildEnt.SetParent( decoy, childEnt.GetParentAttachment() )

			if ( isBattery ){
				thread Decoy_BatteryFX( decoy, decoyChildEnt )
			}else{
				thread Decoy_FlagFX( decoy, decoyChildEnt )
			}
		}

		childEnt = childEnt.NextMovePeer()
	}
	#endif // MP
	
	if( !file.isInfiniteDecoy )
	{
		entity holoPilotTrailFX = StartParticleEffectOnEntity_ReturnEntity( decoy, HOLO_PILOT_TRAIL_FX, FX_PATTACH_POINT_FOLLOW, attachID )
		SetTeam( holoPilotTrailFX, friendlyTeam )
		holoPilotTrailFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY
		decoy.decoy.fxHandles.append( holoPilotTrailFX )
	}
	if( file.isInfiniteDecoy )
		decoy.SetFriendlyFire( true ) // so you can adjust decoy count yourself
	else
		decoy.SetFriendlyFire( false )
	// clean it up
	file.isInfiniteDecoy = false
	file.isStrangeDecoy = false
	decoy.SetKillOnCollision( false )
}

	vector function CalculateAngleSegmentForDecoy( int loopIteration, vector angleSegment )
	{
		if ( loopIteration == 0 )
			return < 0, 0, 0 >

		if ( loopIteration % 2 == 0  )
			return ( loopIteration / 2 ) * angleSegment * -1
		else
			return ( ( loopIteration / 2 ) + 1 ) * angleSegment

		unreachable
	}

#if MP
void function Decoy_BatteryFX( entity decoy, entity decoyChildEnt )
{
	decoy.EndSignal( "OnDeath" )
	decoy.EndSignal( "CleanupFXAndSoundsForDecoy" )
	Battery_StartFX( decoyChildEnt )

	OnThreadEnd(
		function() : ( decoyChildEnt )
		{
			Battery_StopFX( decoyChildEnt )
			if ( IsValid( decoyChildEnt ) )
				decoyChildEnt.Destroy()
		}
	)

	WaitForever()
}

void function Decoy_FlagFX( entity decoy, entity decoyChildEnt )
{
	decoy.EndSignal( "OnDeath" )
	decoy.EndSignal( "CleanupFXAndSoundsForDecoy" )

	SetTeam( decoyChildEnt, decoy.GetTeam() )
	entity flagTrailFX = StartParticleEffectOnEntity_ReturnEntity( decoyChildEnt, GetParticleSystemIndex( FLAG_FX_ENEMY ), FX_PATTACH_POINT_FOLLOW, decoyChildEnt.LookupAttachment( "fx_end" ) )
	flagTrailFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY

	OnThreadEnd(
		function() : ( flagTrailFX, decoyChildEnt )
		{
			if ( IsValid( flagTrailFX ) )
				flagTrailFX.Destroy()

			if ( IsValid( decoyChildEnt ) )
				decoyChildEnt.Destroy()
		}
	)

	WaitForever()
}

void function MonitorDecoyActiveForPlayer( entity decoy, entity player )
{
	if ( player in file.playerToDecoysActiveTable )
		++file.playerToDecoysActiveTable[ player ]
	else
		file.playerToDecoysActiveTable[ player ] <- 1

	decoy.EndSignal( "OnDestroy" ) //Note that we do this OnDestroy instead of the inbuilt OnHoloPilotDestroyed() etc functions so there is a bit of leeway after the holopilot starts to die/is fully invisible before being destroyed
	player.EndSignal( "OnDestroy" )

	OnThreadEnd(
	function() : ( player )
		{
			if( IsValid( player ) )
			{
				Assert( player in file.playerToDecoysActiveTable )
				--file.playerToDecoysActiveTable[ player ]
			}

		}
	)

	WaitForever()
}

int function GetDecoyActiveCountForPlayer( entity player )
{
	if ( !(player in file.playerToDecoysActiveTable ))
		return 0

	return file.playerToDecoysActiveTable[player ]
}

#endif // MP
#endif // SERVER

bool function PlayerCanUseDecoy( entity weapon ) //For holopilot and HoloPilot Nova. No better place to put this for now
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	if ( !ownerPlayer.IsZiplining() )
	{
		if ( ownerPlayer.IsTraversing() )
			return false

		if ( ownerPlayer.ContextAction_IsActive() ) //Stops every single context action from letting decoy happen, including rodeo, melee, embarking etc
			return false
	}

	if( weapon.HasMod( "holoshift" ) )
	{
		foreach( entity offhand in ownerPlayer.GetOffhandWeapons() )
		{
			if(offhand.GetWeaponClassName() == "mp_ability_holopilot")
			{
				if(offhand.GetWeaponPrimaryClipCount()<100)
				{
					//#if SERVER
					//SendHudMessage(ownerPlayer, "需要完全充满以使用幻影转移", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
					//#endif
					return false
				}
			}
		}
		foreach( entity offhand in ownerPlayer.GetOffhandWeapons() )
		{
			if(offhand.GetWeaponClassName() == "mp_ability_holopilot" )
			{
				if(offhand.GetWeaponPrimaryClipCount() < 200 && !( IsValid( file.playerDecoyList ) ) )
				{
					//#if SERVER
					//SendHudMessage(ownerPlayer, "场内无自身幻影!\n需要完全充满以使用幻影转移", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
					//#endif
					return false
				}
			}
		}
	}

	//Do we need to check isPhaseShifted here? Re-examine when it's possible to get both Phase and Decoy (maybe through burn cards?)
	if(ownerPlayer.IsPhaseShifted())
		return false
	return true
}

// nessie modify
#if SERVER
void function SetNessieDecoyOn( bool isOn )
{
	file.isNessieOutfit = isOn
}
#endif

// holoshift stuff!
#if SERVER
void function HoloShiftCooldownThink( entity weapon )
{
	entity player = weapon.GetWeaponOwner()
	if( !IsValid( player ) )
		return
	if( !player.IsPlayer() )
		return

	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.Signal( "HoloShiftCooldownThink" )
	player.EndSignal( "HoloShiftCooldownThink" )
	weapon.EndSignal( "OnDestroy" )

	bool lastFrameDecoyValid
	while( true )
	{	
		int currentAmmo = weapon.GetWeaponPrimaryClipCount()
		int maxAmmo = weapon.GetWeaponPrimaryClipCountMax()
		int ammoPerShot = weapon.GetAmmoPerShot()
		if ( player in file.playerDecoyList ) // we have a decoy waiting to be phase back!
		{
			weapon.SetWeaponPrimaryClipCountAbsolute( ammoPerShot ) // lock to only one charge
			lastFrameDecoyValid = true
		}
		else if( lastFrameDecoyValid ) // last frame decoy was valid...
		{
			weapon.SetWeaponPrimaryClipCountAbsolute( 0 ) // reset ammo
			lastFrameDecoyValid = false
		}
		else if( currentAmmo > ammoPerShot ) // decoy never valid
		{
			weapon.SetWeaponPrimaryClipCountAbsolute( maxAmmo ) // instant make it have 2 charges 
			lastFrameDecoyValid = false // clean it up
		}

		WaitFrame()
	}
}

void function PlayerUsesHoloRewind( entity player, entity decoy )
{
	thread PlayerUsesHoloRewindThreaded( player, decoy )
}

void function PlayerUsesHoloRewindThreaded( entity player, entity decoy )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	decoy.EndSignal("OnDestroy")
	decoy.EndSignal("OnDeath")
	entity mover = CreateScriptMover( player.GetOrigin(), player.GetAngles() )
	player.SetParent( mover, "REF" )

	table decoyData = {}
	decoyData.forceCrouch <- TraceLine
							 ( decoy.GetOrigin(), 
							   decoy.GetOrigin() + < 0,0,80 >, // 40 is crouched pilot height! add additional 40 for better check
							   [ decoy ], 
							   TRACE_MASK_SHOT, 
							   TRACE_COLLISION_GROUP_NONE 
							 ).hitEnt != null // decoy will stuck

	//print( "should forceCrouch player: " + string( decoyData.forceCrouch ) )

	OnThreadEnd( 
		function() : ( player, mover, decoy, decoyData )
		{
			if ( IsValid( player ) )
			{
				player.SetOrigin(decoy.GetOrigin())
				player.SetAngles(decoy.GetAngles())
				player.SetVelocity(decoy.GetVelocity())
				CancelPhaseShift( player )
				player.DeployWeapon()
				player.SetPredictionEnabled( true )
				player.ClearParent()
				ViewConeFree( player )
				FindNearestSafeSpotAndPutEntity( player, 1 ) // defensive fix, good to have
				if( decoyData.forceCrouch )
					thread HoloRewindForceCrouch( player ) // this will handle "UnforceCrouch()"
			}

			if ( IsValid( mover ) )
				mover.Destroy()

			if ( IsValid( decoy ) )
				CleanupExistingDecoy(decoy)
		}
	)

	vector initial_origin = player.GetOrigin()
	vector initial_angle = player.GetAngles()
	array<PhaseRewindData> positions = clone player.p.burnCardPhaseRewindStruct.phaseRetreatSavedPositions

	ViewConeZero( player )
	player.HolsterWeapon()
	player.SetPredictionEnabled( false )
	if( decoyData.forceCrouch )
		player.ForceCrouch() // avoid stucking!
	PhaseShift( player, 0.0, 7 * PHASE_REWIND_PATH_SNAPSHOT_INTERVAL * 1.5 )
	
	// this mean mover will try to catch up with decoy, 7 times
	for ( float i = 7; i > 0; i-- )
	{
		initial_origin -= (initial_origin-decoy.GetOrigin())*(1/i)
		initial_angle -= (initial_angle-decoy.GetAngles())*(1/i)
		mover.NonPhysicsMoveTo( initial_origin, PHASE_REWIND_PATH_SNAPSHOT_INTERVAL, 0, 0 )
		mover.NonPhysicsRotateTo( initial_angle, PHASE_REWIND_PATH_SNAPSHOT_INTERVAL, 0, 0 )
		wait PHASE_REWIND_PATH_SNAPSHOT_INTERVAL
	}

	mover.NonPhysicsMoveTo( decoy.GetOrigin(), PHASE_REWIND_PATH_SNAPSHOT_INTERVAL, 0, 0 )
	mover.NonPhysicsRotateTo( decoy.GetAngles(), PHASE_REWIND_PATH_SNAPSHOT_INTERVAL, 0, 0 )
	player.SetVelocity( decoy.GetVelocity() )
}

void function HoloRewindForceCrouch( entity player )
{
	// make player crouch
	player.ForceCrouch()
	wait 0.2
	if( IsValid( player ) )
		player.UnforceCrouch()
}
#endif
