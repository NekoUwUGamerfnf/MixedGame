// nessie WIP: Take out overloaded portal nodes

untyped

global function OnWeaponPrimaryAttack_shifter
global function MpAbilityShifterWeapon_Init
global function MpAbilityShifterWeapon_OnWeaponTossPrep
global function AbilityShifter_ApplyInProgressStimIfNeeded

const SHIFTER_WARMUP_TIME = 0.0
const SHIFTER_WARMUP_TIME_FAST = 0.0
const float PMMOD_ENDLESS_STRENGTH = 0.8

global const SHIFTER_WARMUP_TIME_WRAITH = 1.25
const WRAITH_SEVERITY_SLOWMOVE = 0.25
const SHIFTER_SLOWMOVE_TIME_WRAITH = 1.25
global const WRAITH_SPEED_BOOST_SEVERITY = 0.25

#if SERVER
// Phase rework stuff
global function createindicator
global table<string, vector> playerorigpostable
global table<string, bool> playerrewindusedtable
global table<string , bool> playerongoingcounttable
global table<string, bool> startposonground
global table<string, bool> startpostouchedroof

const vector ROOFCHECK_HEIGHT = < 0,0,100 > // added pilot's height( 60 ), so actually it's 40 height check
const float FIX_AMOUNT = 20

const PHASE_BOOST_COOLDOWN = 15
const asset PHASE_REWIND_MODEL = $"models/fx/core_energy.mdl"

//make a dict with the player name as key and location vector as content
//global bool rewindused = false

// Portal stuff
// most of these are hardcoded, cannot easily change, fuck I cannot code it well
const float PORTAL_TICKRATE = 0.1
const float PORTAL_DURATION = 30 // should be a multipiler of PORTAL_FX_TICKRATE, could be PORTAL_DURATION + PORTAL_FX_TICKRATE * 2 in actrual
const float PORTAL_MAX_DISTANCE = 3500 // should set higher since lastPos wasn't very accurate
const float PORTAL_CANCEL_PERCENTAGE = 0.95
//const float PORTAL_MIN_DISTANCE = 150 // using PORTAL_CANCEL_PERCENTAGE
const float PORTAL_TRAVEL_LENGTH_MAX = 2.0 // // should match PORTAL_MAX_DISTANCE, but don't know how to calculate now
const float PORTAL_TRAVEL_LENGTH_MIN = 0.4 // min phase duation, basically shouldn't have a limit
//const float PORTAL_TRAVEL_TICKRATE = PORTAL_TICKRATE / 5 // travel tickrate, let's ingore this shit
const float PORTAL_WARP_TIME_PER_SEGMENT = 0.2 // better don't change this, if changed, should set highter than 0.1
const float PORTAL_NODES_MAX = PORTAL_TRAVEL_LENGTH_MAX / PORTAL_WARP_TIME_PER_SEGMENT // use for checking overloaded nodes
//const float PORTAL_NODES_MIN = 8 // no need for now
const float PORTAL_DEPLOY_TIME = 1.2 // defensive fix
const float PORTAL_FX_TICKRATE = 1.5

const bool shouldDoWarpEffect = true // warp is so annoying! can turn it off if need( before I able to remove extra nodes )

struct PortalData
{
	array<vector> progPoses
	array<vector> progAngs
	array<bool> crouchedArray
}

struct PortalStruct
{
	vector goalPos
	vector goalAng
	float travelTime
	string ownerUID
	bool canPortalOwner
	PortalData savedVecs
	bool infiniteDistance
	bool infiniteDuration
}

table<string, bool> playerPlacingPortal = {}
table<entity, PortalStruct> portalGoalTable = {}
array<string> inPortalCooldownPlayers = []

#endif

const string PHASEEXIT_IMPACT_TABLE_PROJECTILE	= "default"
const string PHASEEXIT_IMPACT_TABLE_TRACE		= "superSpectre_groundSlam_impact"

int ammoreduce

// spellcard
const float SPELL_CARD_DURATION_DEFAULT = 1
const float SPELL_CARD_RADIUS = 600

struct
{
	int phaseExitExplodeImpactTable
} file;

void function MpAbilityShifterWeapon_Init()
{
	// "exp_rocket_archer"
	// "exp_xlarge"
	// "exp_arc_ball"
	file.phaseExitExplodeImpactTable = PrecacheImpactEffectTable( PHASEEXIT_IMPACT_TABLE_PROJECTILE )
	PrecacheImpactEffectTable( PHASEEXIT_IMPACT_TABLE_TRACE )

	#if SERVER
	PrecacheModel( PHASE_REWIND_MODEL )
	RegisterSignal( "PlacedPortal" )
	AddCallback_OnClientConnected( OnClientConnected )
	#endif
}

#if SERVER
void function OnClientConnected( entity player )
{
	playerPlacingPortal[player.GetUID()] <- false
}
#endif

void function MpAbilityShifterWeapon_OnWeaponTossPrep( entity weapon, WeaponTossPrepParams prepParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if( !weaponOwner.IsPlayer() )
		return
	if( weapon.HasMod( "wraith_phase" ) )
	{
		int phaseResult = PhaseShift( weaponOwner, SHIFTER_WARMUP_TIME_WRAITH, weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration ), true )
		if( phaseResult )
		{
			StatusEffect_AddTimed( weaponOwner, eStatusEffect.move_slow, WRAITH_SEVERITY_SLOWMOVE, SHIFTER_SLOWMOVE_TIME_WRAITH, 0 )
			#if SERVER
			thread WraithPhaseTrailThink( weaponOwner, SHIFTER_WARMUP_TIME_WRAITH )
			// all handle in server-side
			EmitSoundOnEntityOnlyToPlayer( weaponOwner, weaponOwner, "Pilot_PhaseShift_PreActivate_1P" )
			Remote_CallFunction_NonReplay( weaponOwner, "ServerCallback_PlayScreenFXWarpJump" )
			#endif
			ammoreduce = weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		}
		else
			ammoreduce = 0
	}
	// don't need a slow down actually
	if( weapon.HasMod( "wraith_portal" ) )
	{
		#if SERVER
		if( weapon.GetWeaponPrimaryClipCount() == weapon.GetWeaponPrimaryClipCountMax() )
			SendHudMessage( weaponOwner, "正在架设传送门", -1, 0.65, 255, 255, 100, 1, 0, 3, 0 )
		else if( !playerPlacingPortal[weaponOwner.GetUID()] )
		{
			SendHudMessage( weaponOwner, "需要完全充满以架设传送门", -1, 0.65, 255, 255, 100, 1, 0, 3, 0 )
			weaponOwner.HolsterWeapon()
			weaponOwner.DeployWeapon()
		}
		//if( !(weaponOwner.GetUID() in playerPlacingPortal) )
		//	StatusEffect_AddTimed( weapon.GetWeaponOwner(), eStatusEffect.move_slow, WRAITH_SEVERITY_SLOWMOVE, PORTAL_DEPLOY_TIME, 0 )
		//else if( !playerPlacingPortal[ weaponOwner.GetUID() ] )
		//	StatusEffect_AddTimed( weapon.GetWeaponOwner(), eStatusEffect.move_slow, WRAITH_SEVERITY_SLOWMOVE, PORTAL_DEPLOY_TIME, 0 )
		#endif
	}
	int pmLevel = GetPVEAbilityLevel( weapon )
	if ( (pmLevel >= 2) && IsValid( weaponOwner ) && weaponOwner.IsPhaseShifted() )
		weapon.SetScriptTime0( Time() )
	else
		weapon.SetScriptTime0( 0.0 )
}

int function GetPVEAbilityLevel( entity weapon )
{
	if ( weapon.HasMod( "pm2" ) )
		return 2
	if ( weapon.HasMod( "pm1" ) )
		return 1
	if ( weapon.HasMod( "pm0" ) )
		return 0

	return -1
}

var function OnWeaponPrimaryAttack_shifter( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()
	if( !IsValid( player ) )
		return
		
	float warmupTime = SHIFTER_WARMUP_TIME
	if ( weapon.HasMod( "short_shift" ) )
	{
		warmupTime = SHIFTER_WARMUP_TIME_FAST
	}
	if ( weapon.HasMod( "wraith_phase" ) )
	{
		warmupTime = SHIFTER_WARMUP_TIME_WRAITH
	}
	if( weapon.HasMod( "phase_rework" ) )
	{
		#if SERVER
		entity indicatorent
		int ammoMax = weapon.GetWeaponPrimaryClipCountMax()
		string playerName = player.GetPlayerName()

		if (weapon.GetWeaponPrimaryClipCount() == ammoMax ) { //first charge
			thread move (player , weapon)
			addplayerorigpos(player,player.GetOrigin())
			indicatorent = createindicator(getplayerorigpos(player))
		}
		else if(weapon.GetWeaponPrimaryClipCount() == ammoMax / 2 && playerName in playerorigpostable ) { //second charge
			thread moveback(player,getplayerorigpos(player))
			weapon.SetWeaponPrimaryClipCount(0)
			player.TouchGround()//allways allows a double jump after phasing back
		}
		else if( !(playerName in playerorigpostable) )
		{
			SendHudMessage( player, "未能正常启动，已回复充能", -1,0.65,255,255,100,1,0,4,0 )
			weapon.SetWeaponPrimaryClipCount( ammoMax )
		}
			

		thread cooldownmngmnt (weapon,indicatorent)
		#endif
		return 0
	}
	else if( weapon.HasMod( "wraith_portal" ) )
	{
		#if SERVER
		int ammoMax = weapon.GetWeaponPrimaryClipCountMax()
		string playerUID = player.GetUID()

		if (weapon.GetWeaponPrimaryClipCount() == ammoMax ) //first charge
		{ 
			thread PortalStart( player, weapon )
			return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		}
		else if(weapon.GetWeaponPrimaryClipCount() == ammoMax / 2 && playerUID in playerPlacingPortal ) //second charge
		{
			if( playerPlacingPortal[ playerUID ] )
			{
				player.Signal( "PlacedPortal" )
				return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
			}
			else
			{
				SendHudMessage( player, "没有检测到传送门起点，已回复充能", -1, 0.65, 255, 255, 100, 1, 0, 4, 0 )
				weapon.SetWeaponPrimaryClipCount( ammoMax )
			}
		}
		else if( !(playerUID in playerPlacingPortal) )
		{
			SendHudMessage( player, "未能正常启动，已回复充能", -1,0.65,255,255,100,1,0,4,0 )
			weapon.SetWeaponPrimaryClipCount( ammoMax )
		}
		/*
		else
		{
			SendHudMessage( player, "需要完全充满以放置传送门", -1,0.65,255,255,100,1,0,4,0 )
		}
		*/
		#endif
		return 0
	}
	else if( weapon.HasMod( "spellcard" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		float fireDuration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
		if( fireDuration == 0 )
		{
			#if SERVER
			thread SpellCardThink( weaponOwner, SPELL_CARD_DURATION_DEFAULT )
			#endif

			return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		}

		int phaseResult = PhaseShift( weaponOwner, warmupTime, fireDuration )
		if ( phaseResult )
		{
			PlayerUsedOffhand( weaponOwner, weapon )

			#if BATTLECHATTER_ENABLED && SERVER
				TryPlayWeaponBattleChatterLine( weaponOwner, weapon )
			#endif

			#if SERVER
			thread SpellCardThink( weaponOwner, fireDuration*10 )
			#endif

			return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		}
	}

	entity weaponOwner = weapon.GetWeaponOwner()

	int pmLevel = GetPVEAbilityLevel( weapon )
	if ( weaponOwner.IsPlayer() && (pmLevel >= 0) )
	{
		if ( weaponOwner.IsPhaseShifted() )
		{
			float scriptTime = weapon.GetScriptTime0()
			if ( (pmLevel >= 2) && (scriptTime != 0.0) )
			{
				float chargeMaxTime = weapon.GetWeaponSettingFloat( eWeaponVar.custom_float_0 )
				float chargeTime = (Time() - scriptTime)
				if ( chargeTime >= chargeMaxTime )
				{
					DoPhaseExitExplosion( weaponOwner, weapon )
					StatusEffect_AddTimed( weaponOwner, eStatusEffect.move_slow, 1.0, 1.5, 1.5 )	// "stick" a bit more than usual on exit
				}
			}

			CancelPhaseShift( weaponOwner );
			EndlessStimEnd( weaponOwner )

			if ( pmLevel >= 0 )
				StatusEffect_AddTimed( weaponOwner, eStatusEffect.move_slow, 0.75, 0.75, 0.75 )	// "stick" a bit on exit

			return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		}
		else
		{
			PhaseShift( weaponOwner, 0, 99999 );
			if ( pmLevel >= 1 )
				EndlessStimBegin( weaponOwner, PMMOD_ENDLESS_STRENGTH )
			return 0
		}
	}
	else
	{
		if( weapon.HasMod( "wraith_phase" ) )
		{
			return ammoreduce
		}
		else
		{
			int phaseResult = PhaseShift( weaponOwner, warmupTime, weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration ) )
			if ( phaseResult )
			{
				PlayerUsedOffhand( weaponOwner, weapon )
				// tried to move up for owner himself can hear, but it's bad!
				#if BATTLECHATTER_ENABLED && SERVER
					TryPlayWeaponBattleChatterLine( weaponOwner, weapon )
				#endif

				return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
			}
		}
	}

	return 0
}

void function ApplyInProgressStimIfNeededThread( entity player )
{
	wait 0.5  // timed to kick in when the notify appears on player's screen

	if ( !IsAlive( player ) )
		return
	if ( !player.IsPhaseShifted() )
		return

	EndlessStimBegin( player, PMMOD_ENDLESS_STRENGTH )
}

void function AbilityShifter_ApplyInProgressStimIfNeeded( entity player )
{
	thread ApplyInProgressStimIfNeededThread( player )
}

void function DoPhaseExitExplosion( entity player, entity phaseWeapon )
{
#if CLIENT
	if ( !phaseWeapon.ShouldPredictProjectiles() )
		return
#endif //

	player.PhaseShiftCancel()

	vector origin = player.GetWorldSpaceCenter() + player.GetForwardVector() * 16.0

	//DebugDrawLine( player.GetWorldSpaceCenter(), origin, 255, 0, 0, true, 5.0 )

	int damageType = (DF_RAGDOLL | DF_EXPLOSION | DF_ELECTRICAL)
	entity nade = phaseWeapon.FireWeaponGrenade( origin, <0,0,1>, <0,0,0>, 0.01, damageType, damageType, true, true, true )
	if ( !nade )
		return

	player.PhaseShiftBegin( 0, 1.0 )

	nade.SetImpactEffectTable( file.phaseExitExplodeImpactTable )
	nade.GrenadeExplode( <0,0,0> )

#if SERVER
	PlayImpactFXTable( player.GetOrigin(), player, PHASEEXIT_IMPACT_TABLE_TRACE, SF_ENVEXPLOSION_INCLUDE_ENTITIES )
#endif //
}

#if SERVER
entity function CreatePhaseShiftTrail( entity player )
{
	entity portalTrail = StartParticleEffectOnEntity_ReturnEntity( player, HOLO_PILOT_TRAIL_FX, FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "CHESTFOCUS" ) )
	return portalTrail
}

void function DestroyTrailAfterExitPhase( entity player, entity trail )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function(): ( trail )
		{
			if( IsValid( trail ) )
				EffectStop( trail )
		}
	)
	player.WaitSignal( "StopPhaseShift" )
}

void function WraithPhaseTrailThink( entity player, float delay )
{
	wait delay + 0.1
	if( !IsAlive( player ) )
		return
	if( !player.IsPhaseShifted() )
		return
	entity phaseTrail = CreatePhaseShiftTrail( player )
	thread DestroyTrailAfterExitPhase( player, phaseTrail )
}
#endif

// Portal Stuff
#if SERVER
void function PortalStart( entity player, entity weapon )
{
	if( !IsAlive( player ) )
		return
	if( !IsValid( weapon ) )
		return
	// why signals not work?
	//player.EndSignal( "OnDeath" )
	//player.EndSignal( "OnDestroy" )
	//player.EndSignal( "PlacedPortal" )
	//weapon.EndSignal( "OnDestroy" )
	bool isInfiniteDistance = false
	bool isInfiniteDuration = false
	if( IsValid( weapon ) )
	{
		weapon.AddMod( "no_regen" )
		if( weapon.HasMod( "infinite_distance_portal" ) )
			isInfiniteDistance = true
		if( weapon.HasMod( "infinite_duration_portal" ) )
			isInfiniteDuration = true
		//weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() / 2 )
	}

	// moved to OnWeaponTossPrep() for better visual
	//SendHudMessage( player,"正在架设传送门", -1, 0.65, 255, 255, 100, 1, 0, 3, 0 )

	//wait PORTAL_DEPLOY_TIME // defensive fix
	//if( !IsAlive( player ) ) // if player died before actually starting placing portal, just return
	//	return
	// should set up down here
	
	string playerUID = player.GetUID()
	playerPlacingPortal[ playerUID ] = true

	int statusEffect = -1
	if( !isInfiniteDistance ) // infinite duration portal don't have a speed boost
		statusEffect = StatusEffect_AddEndless( player, eStatusEffect.speed_boost, WRAITH_SPEED_BOOST_SEVERITY )
	entity portalTrail = CreatePhaseShiftTrail( player )

	EmitSoundOnEntityOnlyToPlayer( player, player, SHIFTER_START_SOUND_1P )
	EmitSoundOnEntityExceptToPlayer( player, player, SHIFTER_START_SOUND_3P )
	//EmitSoundOnEntityOnlyToPlayer( player, player, "Pilot_PhaseShift_Loop_1P" )
	//EmitSoundOnEntity( player, "Pilot_PhaseShift_Loop_3P" )
	PlayFX( $"P_phase_shift_main", player.GetOrigin() )

	vector startPos = player.GetOrigin()
	vector startAng = player.EyeAngles()
	startAng.x = 0
	array<vector> progressPoses
	array<vector> progressAngs
	array<bool> wasCrouchedArray
	float travelTime = 0
	if( player.IsOnGround() )
		startPos += < 0,0,FIX_AMOUNT >
	else if( TraceLine( player.GetOrigin(), player.GetOrigin() + ROOFCHECK_HEIGHT, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE ).hitEnt != null )
		startPos -= < 0,0,FIX_AMOUNT >
	vector lastTickPos = player.GetOrigin()
	float portalLeft = PORTAL_MAX_DISTANCE
	float startTime = Time()

	/* // shouldn't be at the bottom of the function, or it will be pretty messed up
	OnThreadEnd(
		function() : ( player, playerUID, weapon, startPos, startAng, progressVecs, progressAngs, travelTime, statusEffect, stimFX )
		{
			thread DelayedClearTable( playerUID )
			if( IsValid( player ) )
			{
				StatusEffect_Stop( player, statusEffect )
				StopSoundOnEntity( player, "Pilot_PhaseShift_Loop_1P" )
				StopSoundOnEntity( player, "Pilot_PhaseShift_Loop_3P" )
				PortalEnd( player, weapon, startPos, startAng, progressVecs, progressAngs, travelTime )
			}
			if( IsValid( stimFX ) )
				EffectStop( stimFX )
		}
	)
	*/
	
	while( true )
	{
		if( IsAlive( player ) )
		{
			//float distance = fabs( Distance2D( startPos, player.GetOrigin() ) )
			//if( distance >= PORTAL_MAX_DISTANCE )
				//break

			if( portalLeft <= 0 )
				break
			if( !IsValid( weapon ) )
				break
			if( startTime + PORTAL_DEPLOY_TIME < Time() ) // defensive fix
			{
				if( player.GetActiveWeapon().HasMod( "wraith_portal" ) )
					break
			}
			/*
			SendHudMessage( player,"传送门距离剩余：" + string( ( 1 - distance / PORTAL_MAX_DISTANCE ) * 100 ) + "%", -1, 0.65, 255, 255, 100, 1, 0, 0.2, 0 )
			if( player.GetVelocity() != < 0,0,0 > )
				travelTime += PORTAL_TICKRATE
			if( travelTime >= PORTAL_TRAVEL_LENGTH_MAX )
				travelTime = PORTAL_TRAVEL_LENGTH_MAX
			*/
			if( player.GetVelocity() != < 0,0,0 > )
			{
				progressPoses.append( player.GetOrigin() )
				bool isCrouched = player.IsCrouched()
				wasCrouchedArray.append( isCrouched )
				progressAngs.append( < 0, player.EyeAngles().y, player.EyeAngles().z > )
				if( !isInfiniteDistance )
					portalLeft -= fabs( Distance2D( lastTickPos, player.GetOrigin() ) )
				travelTime += PORTAL_TICKRATE
				lastTickPos = player.GetOrigin()
			}
			wait PORTAL_TICKRATE // wait before it can trigger "continue"
			if( isInfiniteDistance )
			{
				SendHudMessage( player,"传送门距离剩余：无限制", -1, 0.65, 255, 255, 100, 1, 0, 0.2, 0 )
				continue
			}
			float portalPercentage = portalLeft / PORTAL_MAX_DISTANCE * 100
			if( portalPercentage <= 0 )
				portalPercentage = 0
			SendHudMessage( player,"传送门距离剩余：" + string( portalPercentage ) + "%", -1, 0.65, 255, 255, 100, 1, 0, 0.2, 0 )
		}
		else
			break
	}

	thread DelayedClearTable( playerUID )
	if( IsValid( player ) )
	{
		StatusEffect_Stop( player, statusEffect )
		StopSoundOnEntity( player, "Pilot_PhaseShift_Loop_1P" )
		StopSoundOnEntity( player, "Pilot_PhaseShift_Loop_3P" )
		PortalEnd( player, weapon, startPos, startAng, progressPoses, progressAngs, wasCrouchedArray, travelTime, portalLeft, isInfiniteDistance, isInfiniteDuration )
	}
	if( IsValid( portalTrail ) )
		EffectStop( portalTrail )
}

void function PortalEnd( entity player, entity weapon, vector startPos, vector startAng, array<vector> progressPoses, array<vector> progressAngs, array<bool> wasCrouchedArray, float travelTime, float portalLeft, bool isInfiniteDistance, bool isInfiniteDuration )
{
	if( IsValid( weapon ) )
	{
		weapon.RemoveMod( "no_regen" )
		thread DelayedDiscardAmmo( weapon )
	}
	vector endPos = player.GetOrigin()
	vector endAng = player.EyeAngles()
	endAng.x = 0
	if( player.IsOnGround() )
		endPos += < 0,0,FIX_AMOUNT >
	else if( TraceLine( player.GetOrigin(), player.GetOrigin() + ROOFCHECK_HEIGHT, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE ).hitEnt != null )
		endPos -= < 0,0,FIX_AMOUNT >
	
	EmitSoundOnEntity( player, SHIFTER_END_SOUND_3P )
	//PlayFX( $"P_phase_shift_main", player.GetOrigin() ) // using cooldown management to do this

	/* //using PORTAL_CANCEL_PERCENTAGE
	if( fabs( Distance2D( startPos, endPos ) ) <= PORTAL_MIN_DISTANCE )
	{
		SendHudMessage( player,"传送门放置已取消", -1, 0.65, 255, 255, 100, 1, 0, 4, 0 )
		thread DelayedRechargeWeapon( weapon )
		return
	}
	*/
	if( portalLeft / PORTAL_MAX_DISTANCE >= PORTAL_CANCEL_PERCENTAGE && !isInfiniteDistance )
	{
		SendHudMessage( player,"传送门放置已取消", -1, 0.65, 255, 255, 100, 1, 0, 4, 0 )
		thread DelayedRechargeWeapon( weapon )
		return
	}

	// idk how to use it
	//DebugDrawCircle( startPos, startAng, 60, 128, 255, 128, false, PORTAL_DURATION, 32 )
	//DebugDrawCircle( endPos, endAng, 60, 128, 255, 128, false, PORTAL_DURATION, 32 )

	entity startTrig = CreateTriggerRadiusMultiple( startPos, 64, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_NO_PHASE_SHIFT, 48, 48 )
	entity endTrig = CreateTriggerRadiusMultiple( endPos, 64, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_NO_PHASE_SHIFT, 48, 48 )
	
	//print( "[PORTAL] Total travel time is " + string( travelTime ) )

	// let's remove overloaded nodes
	if( progressPoses.len() > PORTAL_NODES_MAX * 4 )
	{
		array<vector> tempVectors
		float overTime = travelTime - PORTAL_TRAVEL_LENGTH_MAX
		float overTicks = overTime / PORTAL_TICKRATE - 0.01 // hardcoded fix!
		int segment = int( progressPoses.len() / PORTAL_NODES_MAX )
		for( int i = 0; i < overTicks; i++ )
		{
			if( progressPoses.len() <= segment * i )
				break
			tempVectors.append( progressPoses[ segment * i ] )
		}
		travelTime = tempVectors.len() * 0.2
		progressPoses = tempVectors
	}
	else if( progressPoses.len() > PORTAL_NODES_MAX * 2 )
	{
		array<vector> tempVectors
		for( int i = 0; i < progressPoses.len() - 1; i++ )
		{
			if( i * 4 < progressPoses.len() - 1 )
				tempVectors.append( progressPoses[ i * 4 ] )
		}
		travelTime = tempVectors.len() * 0.25
		progressPoses = tempVectors
	}
	else if( progressPoses.len() > PORTAL_NODES_MAX )
	{
		array<vector> tempVectors
		for( int i = 0; i < progressPoses.len() - 1; i++ )
		{
			if( i * 3 < progressPoses.len() - 1 )
				tempVectors.append( progressPoses[ i * 3 ] )
		}
		travelTime = tempVectors.len() * 0.3
		progressPoses = tempVectors
	}
	else if( progressPoses.len() > PORTAL_NODES_MAX * 0.5 )
	{
		array<vector> tempVectors
		for( int i = 0; i < progressPoses.len() - 1; i++ )
		{
			if( i * 2 < progressPoses.len() - 1 )
				tempVectors.append( progressPoses[ i * 2 ] )
		}
		travelTime = tempVectors.len() * 0.35
		progressPoses = tempVectors
	}
	else
		travelTime = progressPoses.len() * 0.3

	//print( "Total travelTime is " + string( travelTime ) )
	//print( "Total nodes.len() is " + string( progressPoses.len() ) )

	//if( progressPoses.len() >= PORTAL_NODES_MAX )
	/* // HACK!!! using hardcoded checking now!
	if( travelTime > PORTAL_TRAVEL_LENGTH_MAX && progressPoses.len() > PORTAL_NODES_MAX && PORTAL_MAX_DISTANCE - portalLeft > PORTAL_MAX_DISTANCE * 0.3 )
	{
		//print( "[PORTAL] Travel time is larger than length_max and nodes are more than nodes_max" )
		array<vector> tempVectors
		float overTime = travelTime - PORTAL_TRAVEL_LENGTH_MAX
		float overTicks = overTime / PORTAL_TICKRATE - 0.01 // hardcoded fix!
		int segment = int( progressPoses.len() / PORTAL_NODES_MAX )
		for( int i = 0; i < overTicks; i++ )
		{
			if( progressPoses.len() <= segment * i )
				break
			tempVectors.append( progressPoses[ segment * i ] )
			//print( "[PORTAL] New Position index is: " + string( segment * i ) )
		}
		travelTime = tempVectors.len() * 0.15
		progressPoses = tempVectors
		//print( "[PORTAL] Nodes count reset to " + string( progressPoses.len() ) + ", and travel time has been set to " + string( travelTime ) )
	}
	else if( progressPoses.len() >= PORTAL_NODES_MAX )
	{
		//print( "[PORTAL] Nodes are more than nodes_max" )
		array<vector> tempVectors
		for( int i = 0; i < progressPoses.len() - 1; i++ )
		{
			if( i * 2 < progressPoses.len() - 1 )
				tempVectors.append( progressPoses[ i * 2 ] )
		}
		travelTime = tempVectors.len() * 0.15
		progressPoses = tempVectors
		//print( "[PORTAL] Nodes count reset to " + string( progressPoses.len() ) + ", and travel time has been set to " + string( travelTime ) )
	}
	else if( travelTime >= PORTAL_TRAVEL_LENGTH_MAX )
	{
		//print( "[PORTAL] Travel time is larger than length_max" )
		array<vector> tempVectors
		for( int i = 0; i < progressPoses.len() - 1; i++ )
		{
			if( i * 2 < progressPoses.len() - 1 )
				tempVectors.append( progressPoses[ i * 2 ] )
		}
		travelTime = tempVectors.len() * 0.15
		progressPoses = tempVectors
		//print( "[PORTAL] Nodes count reset to " + string( progressPoses.len() ) + ", and travel time has been set to " + string( travelTime ) )
	}

	// these works fine with very high portal distance, but fucked up with normal distance
	if( progressPoses.len() > PORTAL_NODES_MAX )
	{
		print( "[PORTAL] Travel time is larger than length_max and nodes are more than nodes_max" )
		array<vector> tempVectors
		float overTime = travelTime - PORTAL_TRAVEL_LENGTH_MAX
		float overTicks = overTime / PORTAL_TICKRATE - 0.01 // hardcoded fix!
		int segment = int( progressPoses.len() / PORTAL_NODES_MAX )
		for( int i = 0; i < overTicks; i++ )
		{
			if( progressPoses.len() <= segment * i )
				break
			tempVectors.append( progressPoses[ segment * i ] )
			print( "[PORTAL] New Position index is: " + string( segment * i ) )
		}
		travelTime = tempVectors.len() * 0.15
		progressPoses = tempVectors
		print( "[PORTAL] Nodes count reset to " + string( progressPoses.len() ) + ", and travel time has been set to " + string( travelTime ) )
	}
	else
	{
		print( "[PORTAL] Travel time is smaller than length_max" )
		array<vector> tempVectors
		for( int i = 0; i < progressPoses.len() - 1; i++ )
		{
			if( i * 2 < progressPoses.len() - 1 )
				tempVectors.append( progressPoses[ i * 2 ] )
		}
		travelTime = tempVectors.len() * 0.15
		progressPoses = tempVectors
		print( "[PORTAL] Nodes count reset to " + string( progressPoses.len() ) + ", and travel time has been set to " + string( travelTime ) )
	}
	*/

	// reverse start & end origin and angle
	PortalStruct startStruct
	startStruct.goalPos = endPos
	startStruct.goalAng = endAng
	startStruct.travelTime = travelTime
	startStruct.ownerUID = player.GetUID()
	startStruct.canPortalOwner = false
	startStruct.savedVecs.progPoses = progressPoses // reverse while phasing back, see below
	startStruct.savedVecs.progAngs = progressAngs
	startStruct.savedVecs.crouchedArray = wasCrouchedArray
	startStruct.infiniteDistance = isInfiniteDistance
	startStruct.infiniteDuration = isInfiniteDuration
	portalGoalTable[ startTrig ] <- startStruct
	SetTeam( startTrig, TEAM_IMC ) // to check if it's start or end, imc = startTrig, mlt = endTrig

	PortalStruct endStruct
	endStruct.goalPos = startPos
	endStruct.goalAng = startAng
	endStruct.travelTime = travelTime
	endStruct.ownerUID = player.GetUID()
	endStruct.canPortalOwner = false
	endStruct.savedVecs.progPoses = progressPoses
	endStruct.savedVecs.progAngs = progressAngs
	endStruct.savedVecs.crouchedArray = wasCrouchedArray
	endStruct.infiniteDistance = isInfiniteDistance
	endStruct.infiniteDuration = isInfiniteDuration
	portalGoalTable[ endTrig ] <- endStruct
	SetTeam( endTrig, TEAM_MILITIA )

	/* // no need to try this, seriously
	startTrig.SetAngles( startAng )
	startTrig.kv.fadedist = travelTime // to save travel duration
	SetTeam( startTrig, TEAM_IMC ) // to check if it's start or end, imc = startTrig, mlt = endTrig

	
	endTrig.SetAngles( endAng )
	endTrig.kv.fadedist = travelTime
	SetTeam( endTrig, TEAM_MILITIA )

	startTrig.kv.rendercolor =  string(endTrig.x) + " " + string(endTrig.y) + " " + string(endTrig.y)//pretty silly, save fliped pos by this
	endTrig.kv.rendercolor = string(startPos.x) + " " + string(startPos.y) + " " + string(startPos.y)
	*/

	if( !( IsValid( startTrig ) || IsValid( endTrig ) || IsValid( player ) ) )
		return

	SendHudMessage( player,"传送门已放置!", -1, 0.65, 255, 255, 100, 1, 0, 4, 0 )
	EmitSoundAtPosition( TEAM_UNASSIGNED, startTrig.GetOrigin(), SHIFTER_END_SOUND_3P_TITAN )
	EmitSoundAtPosition( TEAM_UNASSIGNED, endTrig.GetOrigin(), SHIFTER_END_SOUND_3P_TITAN )
	//print( "[PORTAL] " + player.GetPlayerName() + " placed portal!" )

	AddCallback_ScriptTriggerEnter( startTrig, OnPortalTiggerEnter )
	AddCallback_ScriptTriggerEnter( endTrig, OnPortalTiggerEnter )

	ScriptTriggerSetEnabled( startTrig, true )
	ScriptTriggerSetEnabled( endTrig, true )

	thread DelayedMakeOwnerAbleToPortal( startTrig )
	thread DelayedMakeOwnerAbleToPortal( endTrig )

	if( isInfiniteDuration )
		thread PortalLifetimeManagement( startTrig, endTrig, 99999 )
	else
		thread PortalLifetimeManagement( startTrig, endTrig, PORTAL_DURATION )
}

void function PortalLifetimeManagement( entity startTrig, entity endTrig, float duration )
{
	float startTime = Time()
	while( Time() < startTime + duration )
	{
		if( IsValid( startTrig ) )
		{
			EmitSoundAtPosition( TEAM_UNASSIGNED, startTrig.GetOrigin(), "Pilot_PhaseShift_WarningToEnd_3P" )
			PlayFX( $"P_phase_shift_main", startTrig.GetOrigin() )
		}
		if( IsValid( endTrig ) )
		{
			EmitSoundAtPosition( TEAM_UNASSIGNED, endTrig.GetOrigin(), "Pilot_PhaseShift_WarningToEnd_3P" )
			PlayFX( $"P_phase_shift_main", endTrig.GetOrigin() )
		}
		if( !IsValid( startTrig ) && !IsValid( endTrig ) )
			return
		wait PORTAL_FX_TICKRATE
	}
	if( IsValid( startTrig ) )
	{
		EmitSoundAtPosition( TEAM_UNASSIGNED, startTrig.GetOrigin(), SHIFTER_END_SOUND_3P )
		startTrig.Destroy()
	}
	if( IsValid( endTrig ) )
	{
		EmitSoundAtPosition( TEAM_UNASSIGNED, endTrig.GetOrigin(), SHIFTER_END_SOUND_3P )
		endTrig.Destroy()
	}
}

void function OnPortalTiggerEnter( entity trigger, entity player )
{
	if( !IsValid( player ) )
		return
	
	//print( "[PORTAL] Someone entered trigger!" )

	thread PortalTravelThink( trigger, player )
}

void function PortalTravelThink( entity trigger, entity player )
{
	//why endsignal so messed up
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "StopPhaseShift" )
	trigger.EndSignal( "OnDestroy" )

	/* no need to try this, seriously
	array<string> originConver = split( trigger.kv.rendercolor, " " )
	float travelTime = float( trigger.kv.fadedist )
	vector goalOrigin = < float( originConver[0] ), float( originConver[1] ), float( originConver[2] ) >
	vector goalAngles = trigger.GetAngles()
	*/
	vector goalOrigin = portalGoalTable[ trigger ].goalPos
	vector goalAngles = portalGoalTable[ trigger ].goalAng
	float travelTime = portalGoalTable[ trigger ].travelTime
	string ownerUID = portalGoalTable[ trigger ].ownerUID
	bool canPortalOwner = portalGoalTable[ trigger ].canPortalOwner
	array<vector> progressPoses = portalGoalTable[ trigger ].savedVecs.progPoses
	array<vector> progressAngs = portalGoalTable[ trigger ].savedVecs.progAngs
	array<bool> crouchedArray = portalGoalTable[ trigger ].savedVecs.crouchedArray
	bool goalShouldCrouch = trigger.GetTeam() == TEAM_MILITIA ? crouchedArray[0] : crouchedArray[crouchedArray.len()-1]
	bool isInfiniteDistance = portalGoalTable[ trigger ].infiniteDistance
	bool isInfiniteDuration = portalGoalTable[ trigger ].infiniteDuration
	
	int totalSegments = progressPoses.len()
	int segmentsLeft = totalSegments
	bool playedPreEndSound = false
	float timePerSigment = PORTAL_WARP_TIME_PER_SEGMENT - 0.1 //controlls travel speed
	if( timePerSigment <= 0 ) // defensive fix
		timePerSigment = 0.1
	float fixedTimePerSigment = timePerSigment + 0.06 //visual fix, controlls travel speed
	if( isInfiniteDistance )
	{
		timePerSigment = PORTAL_WARP_TIME_PER_SEGMENT
		fixedTimePerSigment = timePerSigment + 0.1 //visual fix
	}
	float totalTime = travelTime
	float phaseTimeMulti = 1.1
	// CancelPhaseShift() version, don't need this
	//if( shouldDoWarpEffect )
	//{
		// player.WaitSignal( "StopPhaseShift" ) version
		//phaseTimeMulti = 0.75 // should set bit lower
		//if( totalSegments > 11 )
			//phaseTimeMulti = 0.83 // tempfix
	//}
	//if( shouldDoWarpEffect && totalTime >= PORTAL_TRAVEL_LENGTH_MAX ) // hardcoded now
		//phaseTimeMulti = 0.75 // should set bit lower

	if( player.IsPhaseShifted() || player.GetParent() )
	{
		return
	}
	if( player.GetUID() == ownerUID && !canPortalOwner )
	{
		return
	}
	if( inPortalCooldownPlayers.contains( player.GetUID() ) )
	{
		//print( "[PORTAL] Someone is in cooldown so cannot portal!" )
		return
	}
	if( player.GetUID() in playerPlacingPortal )
	{
		if( playerPlacingPortal[ player.GetUID() ] )
		{
			return
		}
	}
	if( !inPortalCooldownPlayers.contains( player.GetUID() ) )
	{
		// CancelPhaseShift() version
		if( shouldDoWarpEffect )
			thread PortalCooldownThink( player, totalTime )
		else
			thread PortalCooldownThink( player, totalTime * phaseTimeMulti )
		//print( "[PORTAL] Set someone in portal cooldown!" )
	}
	entity portalTrail = CreatePhaseShiftTrail( player )
	entity mover = CreateOwnedScriptMover( player )
	//player.ForceStand()
	player.SetParent( mover )
	player.HolsterWeapon()
	player.Server_TurnOffhandWeaponsDisabledOn()
	player.SetPredictionEnabled( false )
	ViewConeZero( player )
	// CancelPhaseShift() version
	if( shouldDoWarpEffect )
		PhaseShift( player, 0, 9999 )
	else
		PhaseShift( player, 0, totalTime * phaseTimeMulti ) // phase player, defensive fix

	//shouldn't be at the bottom of the function, or it will be pretty messed up
	OnThreadEnd(
		function() : ( player, trigger, mover, portalTrail, goalOrigin, goalAngles, goalShouldCrouch )
		{
			if( IsValid( player ) )
			{
				player.SetVelocity( < 0,0,0 > )
				//player.UnforceStand()
				if( goalShouldCrouch )
					thread TravelEndForceCrouch( player )
				player.ClearParent()
				player.DeployWeapon()
				player.Server_TurnOffhandWeaponsDisabledOff()
				player.SetPredictionEnabled( true )
				ViewConeFree( player )
				CancelPhaseShift( player ) // better, wraith be like this
				player.TouchGround() // able to double jump after leaving
				//whatever we get from segment teleports, just set player to the right origin
				if( IsAlive( player ) && IsValid( trigger ) )
				{
					player.SetOrigin( goalOrigin )
					// moved to NonPhysicsRotateTo()
					//vector viewVector = player.GetViewVector()
					//vector viewAngles = VectorToAngles( viewVector )
					//player.SetAngles( < 0,viewAngles.y,0 > ) // so player won't face the ground or sky
					//player.SetAngles( goalAngles )
				}
				Nessie_PutPlayerInSafeSpot( player, 1 )
			}
			if( IsValid( portalTrail ) )
				EffectStop( portalTrail )
			if( IsValid( mover ) )
				mover.Destroy()
		}
	)

	if( shouldDoWarpEffect )
	{
		// phase all ticks
		if( IsValid( trigger ) )
		{
			if( trigger.GetTeam() == TEAM_MILITIA ) // endTrig confrimation, reversed array
			{
				//for( int i = totalSegments - 1, j = 0; i >= 0 && j <= totalSegments - 1; i--, j++ )
				for( int i = totalSegments - 1; i >= 0; i-- )
				{
					player.UnforceCrouch()
					if( crouchedArray[i] )
						player.ForceCrouch() // make player's view lower
					player.HolsterWeapon() // defensive fix
					player.Server_TurnOffhandWeaponsDisabledOn()
					mover.NonPhysicsMoveTo( progressPoses[i] , fixedTimePerSigment, 0, 0 )
					if( i < totalSegments - 2 ) // prevent calculate out of index
					{
						vector curAngle = CalculateFaceToOrigin( progressPoses[i+1], progressPoses[i] )
						mover.NonPhysicsRotateTo( curAngle, fixedTimePerSigment, 0, 0 )
					}
					float travelTimeLeft = segmentsLeft * timePerSigment
					//print( travelTimeLeft )
					if( travelTimeLeft < 1.0 && !playedPreEndSound ) // near end, play sound. this kind of sound have a delay
					{
						playedPreEndSound = true
						EmitSoundOnEntityOnlyToPlayer( player, player, "Pilot_PhaseShift_WarningToEnd_1P" )
						EmitSoundOnEntityExceptToPlayer( player, player, "Pilot_PhaseShift_WarningToEnd_3P" )
					}
					segmentsLeft -= 1
					// rotation like this is messed up
					//mover.NonPhysicsRotateTo( progressAngs[j], timePerSigment, 0, 0 )
					wait timePerSigment
				}
			}
			else if( trigger.GetTeam() == TEAM_IMC ) // startTrig confrimation
			{
				for( int i = 0; i <= totalSegments - 1; i++ )
				{
					player.UnforceCrouch()
					if( crouchedArray[i] )
						player.ForceCrouch() // make player's view lower
					player.HolsterWeapon() // defensive fix
					player.Server_TurnOffhandWeaponsDisabledOn()
					mover.NonPhysicsMoveTo( progressPoses[i] , fixedTimePerSigment, 0, 0 )
					if( i > 0 ) // prevent calculate out of index
					{
						vector curAngle = CalculateFaceToOrigin( progressPoses[i-1], progressPoses[i] )
						mover.NonPhysicsRotateTo( curAngle, fixedTimePerSigment, 0, 0 )
					}
					float travelTimeLeft = segmentsLeft * timePerSigment
					//print( travelTimeLeft )
					if( travelTimeLeft < 1.0 && !playedPreEndSound ) // near end, play sound. this kind of sound have a delay
					{
						playedPreEndSound = true
						EmitSoundOnEntityOnlyToPlayer( player, player, "Pilot_PhaseShift_WarningToEnd_1P" )
						EmitSoundOnEntityExceptToPlayer( player, player, "Pilot_PhaseShift_WarningToEnd_3P" )
					}
					segmentsLeft -= 1
					// rotation like this is messed up
					//mover.NonPhysicsRotateTo( progressAngs[i], timePerSigment, 0, 0 )
					wait timePerSigment
				}
			}
		}
		//wait totalTime * ( phaseTimeMulti - 0.9 ) // defensive fix, wait 0.1s more, hardcoded
		mover.NonPhysicsMoveTo( goalOrigin, fixedTimePerSigment ,0, 0 )
		vector targetAngle = CalculateFaceToOrigin( mover.GetOrigin(), goalOrigin )
		mover.NonPhysicsRotateTo( < 0,targetAngle.y,0 >, fixedTimePerSigment, 0, 0 ) // so player won't face the ground or sky
		//player.WaitSignal( "StopPhaseShift" ) // wait till player exit phase, wraith's portal don't have this lmao
		wait fixedTimePerSigment + 0.1
		//player.Signal( "StopPhaseShift" )
	}
	else
	{
		mover.NonPhysicsMoveTo( goalOrigin, totalTime, 0, 0 )
		wait totalTime * phaseTimeMulti
	}
	
}

void function TravelEndForceCrouch( entity player )
{
	// make player crouch
	player.ForceCrouch()
	wait 0.2
	if( IsValid( player ) )
		player.UnforceCrouch()
}

void function PortalCooldownThink( entity player, float travelTime )
{
	if( !IsValid( player ) )
		return
	string playerUID = player.GetUID()
	inPortalCooldownPlayers.append( playerUID )
	wait travelTime * 1.1 + PORTAL_DEPLOY_TIME
	inPortalCooldownPlayers.fastremovebyvalue( playerUID )
}

void function DelayedMakeOwnerAbleToPortal( entity trigger ) // defensive fix
{
	wait PORTAL_DEPLOY_TIME
	if( IsValid( trigger ) )
		portalGoalTable[ trigger ].canPortalOwner = true
	//print( "[PORTAL] Set owner able to use portal!" )
}

void function DelayedRechargeWeapon( entity weapon )
{
	wait PORTAL_DEPLOY_TIME
	if( IsValid( weapon ) )
		weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
}

void function DelayedDiscardAmmo( entity weapon )
{
	wait PORTAL_DEPLOY_TIME
	if( IsValid( weapon ) )
		weapon.SetWeaponPrimaryClipCount( 0 )
}

void function DelayedClearTable( string playerUID )
{
	wait PORTAL_DEPLOY_TIME
	playerPlacingPortal[ playerUID ] = false
}

vector function CalculateFaceToOrigin( vector startPos, vector endPos )
{
	vector posDiffer = endPos - startPos
	vector moveAng = VectorToAngles( posDiffer )
    return moveAng
}

/* // OnThreadEnd() messed things up
void function PortalStart( entity player, entity weapon )
{
	if( !IsAlive( player ) )
		return
	if( !IsValid( weapon ) )
		return
	// why signals not work?
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "PlacedPortal" )
	weapon.EndSignal( "OnDestroy" )
	if( IsValid( weapon ) )
	{
		weapon.AddMod( "no_regen" )
		//weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() / 2 )
	}

	// should set up down here
	string playerUID = player.GetUID()
	playerPlacingPortal[ playerUID ] = true

	int statusEffect = StatusEffect_AddEndless( player, eStatusEffect.speed_boost, WRAITH_SPEED_BOOST_SEVERITY )
	entity stimFX = StartParticleEffectOnEntity_ReturnEntity( player, PILOT_STIM_HLD_FX, FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "CHESTFOCUS" ) )
	stimFX.SetOwner( player )
	stimFX.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY)

	EmitSoundOnEntityOnlyToPlayer( player, player, SHIFTER_START_SOUND_1P )
	EmitSoundOnEntity( player, SHIFTER_START_SOUND_3P )
	EmitSoundOnEntityOnlyToPlayer( player, player, "Pilot_PhaseShift_Loop_1P" )
	EmitSoundOnEntity( player, "Pilot_PhaseShift_Loop_3P" )
	PlayFX( $"P_phase_shift_main", player.GetOrigin() )

	vector startPos = player.GetOrigin()
	vector startAng = player.EyeAngles()
	startAng.x = 0
	array<vector> progressPoses
	float travelTime
	if( player.IsOnGround() )
		startPos += < 0,0,FIX_AMOUNT >
	else if( TraceLine( player.GetOrigin(), player.GetOrigin() + ROOFCHECK_HEIGHT, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE ).hitEnt != null )
		startPos -= < 0,0,FIX_AMOUNT >
	vector lastTickPos = player.GetOrigin()
	float portalLeft

	// shouldn't be at the bottom of the function, or it will be pretty messed up
	OnThreadEnd(
		function() : ( player, playerUID, weapon, startPos, startAng, progressPoses, travelTime, portalLeft, statusEffect, stimFX )
		{
			playerPlacingPortal[ playerUID ] = false
			if( IsValid( player ) )
			{
				StatusEffect_Stop( player, statusEffect )
				StopSoundOnEntity( player, "Pilot_PhaseShift_Loop_1P" )
				StopSoundOnEntity( player, "Pilot_PhaseShift_Loop_3P" )
				PortalEnd( player, weapon, startPos, startAng, progressPoses, travelTime, portalLeft )
			}
			if( IsValid( stimFX ) )
				EffectStop( stimFX )
		}
	)
	
	portalLeft += PORTAL_MAX_DISTANCE
	while( true )
	{
		wait PORTAL_TICKRATE
		if( IsAlive( player ) )
		{

			if( portalLeft <= 0 )
			{
				portalLeft = 0
				break
			}
			if( !IsValid( weapon ) )
				break

			if( player.GetVelocity() != < 0,0,0 > )
			{
				progressPoses.append( player.GetOrigin() )
				portalLeft -= fabs( Distance2D( lastTickPos, player.GetOrigin() ) )
				//print( "Portal Left: " + string( portalLeft ) )
				travelTime += PORTAL_TICKRATE
				lastTickPos = player.GetOrigin()
			}
			float portalPercentage = portalLeft / PORTAL_MAX_DISTANCE * 100
			if( portalPercentage <= 0 )
				portalPercentage = 0
			SendHudMessage( player,"传送门距离剩余：" + string( portalPercentage ) + "%", -1, 0.65, 255, 255, 100, 1, 0, 0.2, 0 )
		}
		else
			break
	}
}

void function PortalEnd( entity player, entity weapon, vector startPos, vector startAng, array<vector> progressPoses, float travelTime, float portalLeft )
{
	if( IsValid( weapon ) )
	{
		weapon.RemoveMod( "no_regen" )
		weapon.SetWeaponPrimaryClipCount( 0 )
	}
	vector endPos = player.GetOrigin()
	vector endAng = player.EyeAngles()
	endAng.x = 0
	if( player.IsOnGround() )
		endPos += < 0,0,FIX_AMOUNT >
	else if( TraceLine( player.GetOrigin(), player.GetOrigin() + ROOFCHECK_HEIGHT, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE ).hitEnt != null )
		endPos -= < 0,0,FIX_AMOUNT >
	
	EmitSoundOnEntity( player, SHIFTER_END_SOUND_3P )
	PlayFX( $"P_phase_shift_main", player.GetOrigin() )

	if( portalLeft / PORTAL_MAX_DISTANCE >= PORTAL_CANCEL_PERCENTAGE )
	{
		SendHudMessage( player,"传送门放置已取消", -1, 0.65, 255, 255, 100, 1, 0, 4, 0 )
		weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
		print( "Portal Left: " + string( portalLeft ) )
		return
	}

	entity startTrig = CreateTriggerRadiusMultiple( startPos, 64, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_NO_PHASE_SHIFT, 48, 48 )
	entity endTrig = CreateTriggerRadiusMultiple( endPos, 64, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_NO_PHASE_SHIFT, 48, 48 )
	
	//print( "[PORTAL] Total travel time is " + string( travelTime ) )

	// let's remove overloaded nodes
	if( progressPoses.len() >= PORTAL_NODES_MAX )
	{
		array<vector> tempVectors
		float overTime = travelTime - PORTAL_TRAVEL_LENGTH_MAX
		float overTicks = overTime / PORTAL_TICKRATE
		int segment = int( progressPoses.len() / PORTAL_NODES_MAX )
		for( int i = 0; i < overTicks; i++ )
		{
			if( progressPoses.len() <= segment * i )
				break
			tempVectors.append( progressPoses[ segment * i ] )
		}
		travelTime = PORTAL_TRAVEL_LENGTH_MAX
		progressPoses = tempVectors
		//print( "[PORTAL] Nodes count reset to " + string( progressPoses.len() ) + ", and travel time has been set to " + string( travelTime ) )
	}

	// reverse start & end origin and angle
	PortalStruct startStruct
	startStruct.goalPos = endPos
	startStruct.travelTime = travelTime
	startStruct.ownerUID = player.GetUID()
	startStruct.canPortalOwner = false
	startStruct.savedVecs.progPoses = progressPoses // reverse while phasing back, see below
	portalGoalTable[ startTrig ] <- startStruct
	SetTeam( startTrig, TEAM_IMC ) // to check if it's start or end, imc = startTrig, mlt = endTrig

	PortalStruct endStruct
	endStruct.goalPos = startPos
	endStruct.travelTime = travelTime
	endStruct.ownerUID = player.GetUID()
	endStruct.canPortalOwner = false
	endStruct.savedVecs.progPoses = progressPoses
	portalGoalTable[ endTrig ] <- endStruct
	SetTeam( endTrig, TEAM_MILITIA )

	if( !( IsValid( startTrig ) || IsValid( endTrig ) || IsValid( player ) ) )
		return

	SendHudMessage( player,"传送门已放置!", -1, 0.65, 255, 255, 100, 1, 0, 4, 0 )
	EmitSoundAtPosition( TEAM_UNASSIGNED, startTrig.GetOrigin(), SHIFTER_END_SOUND_3P_TITAN )
	EmitSoundAtPosition( TEAM_UNASSIGNED, endTrig.GetOrigin(), SHIFTER_END_SOUND_3P_TITAN )
	//print( "[PORTAL] " + player.GetPlayerName() + " placed portal!" )

	AddCallback_ScriptTriggerEnter( startTrig, OnPortalTiggerEnter )
	AddCallback_ScriptTriggerEnter( endTrig, OnPortalTiggerEnter )

	ScriptTriggerSetEnabled( startTrig, true )
	ScriptTriggerSetEnabled( endTrig, true )

	thread PortalLifetimeManagement( startTrig, endTrig )
}

void function PortalLifetimeManagement( entity startTrig, entity endTrig )
{
	float startTime = Time()
	while( Time() < startTime + PORTAL_DURATION )
	{
		wait PORTAL_FX_TICKRATE
		if( IsValid( startTrig ) )
		{
			EmitSoundAtPosition( TEAM_UNASSIGNED, startTrig.GetOrigin(), "Pilot_PhaseShift_WarningToEnd_3P" )
			PlayFX( $"P_phase_shift_main", startTrig.GetOrigin() )
		}
		if( IsValid( endTrig ) )
		{
			EmitSoundAtPosition( TEAM_UNASSIGNED, endTrig.GetOrigin(), "Pilot_PhaseShift_WarningToEnd_3P" )
			PlayFX( $"P_phase_shift_main", endTrig.GetOrigin() )
		}
		if( !IsValid( startTrig ) && !IsValid( endTrig ) )
			return
	}
	wait PORTAL_FX_TICKRATE
	if( IsValid( startTrig ) )
	{
		EmitSoundAtPosition( TEAM_UNASSIGNED, startTrig.GetOrigin(), SHIFTER_END_SOUND_3P )
		startTrig.Destroy()
	}
	if( IsValid( endTrig ) )
	{
		EmitSoundAtPosition( TEAM_UNASSIGNED, endTrig.GetOrigin(), SHIFTER_END_SOUND_3P )
		endTrig.Destroy()
	}
}

void function OnPortalTiggerEnter( entity trigger, entity player )
{
	if( !IsValid( player ) )
		return
	
	//print( "[PORTAL] Someone entered trigger!" )

	thread PortalTravelThink( trigger, player )
}

void function PortalTravelThink( entity trigger, entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	trigger.EndSignal( "OnDestroy" )

	vector goalOrigin = portalGoalTable[ trigger ].goalPos
	float travelTime = portalGoalTable[ trigger ].travelTime
	string ownerUID = portalGoalTable[ trigger ].ownerUID
	bool canPortalOwner = portalGoalTable[ trigger ].canPortalOwner
	array<vector> progressPoses = portalGoalTable[ trigger ].savedVecs.progPoses
	
	int totalSegments = progressPoses.len()
	float timePerSigment = PORTAL_TICKRATE + 0.05 // needs defensive fix
	float totalTime = travelTime
	float phaseTimeMulti = 1.1
	if( shouldDoWarpEffect && totalTime >= PORTAL_TRAVEL_LENGTH_MAX )
		phaseTimeMulti = 1.5

	if( player.IsPhaseShifted() )
	{
		return
	}
	if( player.GetUID() == ownerUID && !canPortalOwner )
	{
		portalGoalTable[ trigger ].canPortalOwner = true
		//print( "[PORTAL] Set owner able to use portal!" )
		return
	}
	if( inPortalCooldownPlayers.contains( player.GetUID() ) )
	{
		//print( "[PORTAL] Someone is in cooldown so cannot portal!" )
		return
	}
	if( player.GetUID() in playerPlacingPortal )
	{
		if( playerPlacingPortal[ player.GetUID() ] )
		{
			return
		}
	}
	if( !inPortalCooldownPlayers.contains( player.GetUID() ) )
	{
		thread PortalCooldownThink( player, totalTime * phaseTimeMulti )
		//print( "[PORTAL] Set someone in portal cooldown!" )
	}

	entity mover = CreateOwnedScriptMover(player)
	//shouldn't be at the bottom of the function, or it will be pretty messed up
	OnThreadEnd(
		function() : ( player, mover, goalOrigin )
		{
			if( IsValid( player ) )
			{
				player.SetVelocity( < 0,0,0 > )
				player.ClearParent()
				player.DeployWeapon()
				player.TouchGround() // able to double jump after leaving
				//whatever we get from segmented teleport, just set player to the right origin
				player.SetOrigin( goalOrigin )
				Nessie_PutPlayerInSafeSpot( entity player, 1 )
			}
			if( IsValid( mover ) )
				mover.Destroy()
		}
	)
	player.SetParent( mover )
	player.HolsterWeapon()
	PhaseShift( player, 0, totalTime * phaseTimeMulti ) // phase player, defensive fix
	if( shouldDoWarpEffect )
	{
		// phase all ticks
		if( IsValid( trigger ) )
		{
			if( trigger.GetTeam() == TEAM_MILITIA ) // endTrig confrimation, reversed array
			{
				for( int i = totalSegments - 1; i >= 0; i-- )
				{
					wait timePerSigment
					mover.NonPhysicsMoveTo( progressPoses[i] , timePerSigment, 0, 0 )
					vector curAngle = CalculateFaceToOrigin( progressPoses[i-1], progressPoses[i] )
					mover.NonPhysicsRotateTo( curAngle, timePerSigment, 0, 0 )
				}
			}
			else if( trigger.GetTeam() == TEAM_IMC ) // startTrig confrimation, reversed array
			{
				for( int i = 0; i <= totalSegments - 1; i++ )
				{
					wait timePerSigment
					mover.NonPhysicsMoveTo( progressPoses[i] , timePerSigment, 0, 0 )
					vector curAngle = CalculateFaceToOrigin( progressPoses[i-1], progressPoses[i] )
					mover.NonPhysicsRotateTo( curAngle, timePerSigment, 0, 0 )
				}
			}
		}
		wait totalTime * ( phaseTimeMulti - 1 )
	}
	else
	{
		mover.NonPhysicsMoveTo( goalOrigin , totalTime ,0, 0 )
		wait totalTime * phaseTimeMulti
	}

}

void function PortalCooldownThink( entity player, float travelTime )
{
	if( !IsValid( player ) )
		return
	string playerUID = player.GetUID()
	inPortalCooldownPlayers.append( playerUID )
	wait travelTime * 1.1 + PORTAL_DEPLOY_TIME
	inPortalCooldownPlayers.fastremovebyvalue( playerUID )
}

vector function CalculateFaceToOrigin( vector startPos, vector endPos )
{
	vector posDiffer = endPos - startPos
	vector moveAng = VectorToAngles( posDiffer )
    return moveAng
}
*/
#endif

//Phase Rework Stuff
#if SERVER
void function addplayerorigpos(entity player,vector origpos) {
	string playername = player.GetPlayerName()
	playerorigpostable[playername] <- origpos;
	playerongoingcounttable[playername] <- false
	startposonground[playername] <- false // DB: Initializing
	startpostouchedroof[playername] <- false
	if( player.IsOnGround() )
		startposonground[playername] <- true
	if( TraceLine( player.GetOrigin(), player.GetOrigin() + ROOFCHECK_HEIGHT, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE ).hitEnt != null && !player.IsOnGround() ) // DB: If there's something blocked the line, we consider it as touched the roof
		startpostouchedroof[playername] <- true
}

vector function getplayerorigpos(entity player){
	return playerorigpostable[player.GetPlayerName()]
}

void function move (entity player, entity weapon) {

	float velmultiplier = 0.8

	if (weapon.HasMod( "boost_strength_lv1" )) 
		velmultiplier = 1
	if(weapon.HasMod( "boost_strength_lv2" ))
		velmultiplier = 1.5
	if(weapon.HasMod( "boost_strength_lv3" ))
		velmultiplier = 2

	PhaseShift(player, 0, 0.3 )
	vector viewvector = player.GetViewVector() * 1000 * velmultiplier
	player.SetVelocity(viewvector)
	weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() / 2 )

}

void function moveback (entity player , vector origpos) {
	string playername = player.GetPlayerName()
	EmitSoundAtPosition( TEAM_UNASSIGNED, player.GetOrigin(), SHIFTER_START_SOUND_3P )
    PlayFX( $"P_phase_shift_main", player.GetOrigin() )
	playerrewindusedtable[playername] <- true
	entity mover = CreateOwnedScriptMover (player)
	player.ForceStand()
	player.SetParent(mover)
	PhaseShift(player, 0, 0.55 )
	if( startposonground[playername] )
		mover.NonPhysicsMoveTo (<origpos.x,origpos.y,origpos.z + FIX_AMOUNT>, 0.5,0,0) //bit of added z height to prevent getting stuck ( in ground )
	else if( startpostouchedroof[playername] )
		mover.NonPhysicsMoveTo (<origpos.x,origpos.y,origpos.z - FIX_AMOUNT>, 0.5,0,0) //DB: Bit of minused z height to prevent getting stuck in roof
	else
		mover.NonPhysicsMoveTo (origpos, 0.5,0,0) //DB: Normal rewind
	wait 0.55;
	player.SetVelocity(<0,0,0>)
	player.UnforceStand()
	player.ClearParent()
	Nessie_PutPlayerInSafeSpot( player, 1 )
	mover.Destroy()

}

void function cooldownmngmnt (entity weapon,entity indicatorent) {

	//if (ongoingcount == false) { //function gets called twice in ability "cycle" , prevents two timers from going at the same time
	//	ongoingcount = true

	if (playerongoingcounttable[weapon.GetWeaponOwner().GetPlayerName()] == false) 
	{

		string playername = weapon.GetWeaponOwner().GetPlayerName()
		weapon.EndSignal( "OnDestroy" ) //DB: If the weapon has been destroyed( owner died or got another phase shift ), it will run 'OnThreadEnd()' function
		// DB: `EndSignal()` function: if entity triggered this signal, thread will be cut off then runs `OnThreadEnd()` function
		OnThreadEnd(
			function(): ( playername )
			{
				playerrewindusedtable[playername] <- false
				playerongoingcounttable[playername] <- false
				startposonground[playername] <- false
				startpostouchedroof[playername] <- false
			}

		)

			//possible rewind window//
			if (weapon.HasMod( "phase_rework" ) && weapon.HasMod( "amped_tacticals" )) // no amped tacticals = dash only
			{
				playerongoingcounttable[playername] <- true
				int x = 0
				int deco_x = 5
				while (x < 5) 
				{
					try
					{
						if (playerrewindusedtable[playername] == true) 
						{
							break
						}
					}
					catch(ex)
					{
						//print(ex)
					}
					try 
					{
						SendHudMessage(weapon.GetWeaponOwner(),string(deco_x) + "秒内可进行相位回溯",-1,0.65,255,255,100,1,0,1,0)
					}
					catch(ex0) 
					{
						//print("Phase Error:"+ex0)
					}
					x++
					deco_x = deco_x -1
					wait 1;
				}
			}

			//needs to be 0ed in case the player didnt phase back
			deleteindicator(indicatorent)
			try 
			{
				weapon.SetWeaponPrimaryClipCount(0)
			} //I cant be bothered to fix this , doesnt matter anyway the player is dead if this errors out
			catch (ex1) 
			{
				//print("Phase Error:"+ex1)
			}

			//cooldown//
			int cooldownint = PHASE_BOOST_COOLDOWN
			wait cooldownint


			try 
			{
				weapon.SetWeaponPrimaryClipCount( weapon.GetWeaponPrimaryClipCountMax() )
				playerrewindusedtable[playername] <- false
				SendHudMessage(weapon.GetWeaponOwner(),"冲刺冷却完毕",-1,0.65,255,255,100,1,0,1,0) //player //text //x //y //r //g //b  /a  //fade-in s //lenght s //fade-out s
			} 
			catch(ex2) 
			{
				//print("Phase Error:"+ex2)
			}

		//	ongoingcount = false
		//}
	}

}

entity function createindicator (vector location) {

	entity ind = CreateEntity( "prop_dynamic" )
	ind.SetValueForModelKey( PHASE_REWIND_MODEL )
	ind.SetOrigin( <location.x,location.y,location.z+50>)
	DispatchSpawn( ind )

	thread indicatortimeout(ind)

	return ind

}

void function indicatortimeout(entity indicator) {
	wait 10
	try
	{
		indicator.Destroy()
	}
	catch(ex)
	{
		//print("Phase Error:"+ex)
	}
}

void function deleteindicator (entity indicator) {

	if (IsValid(indicator)) 
	{
		indicator.Destroy()
	} 
	//else
		//print("Phase Error:"+"wasnt valid")

}

// spellcard
void function SpellCardThink( entity player, float duration )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	entity fxHandle = PlayFXOnEntity( $"P_ar_holopulse_CP", player )
	vector controlPoint = <duration, 10, 0.0>
	EffectSetControlPointVector( fxHandle, 1, controlPoint )
	OnThreadEnd(
		function(): ( fxHandle )
		{
			if( IsValid( fxHandle ) )
			{
				fxHandle.Destroy()
			}
		}
	)
	EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Tone_SonarLock_Impact_Pulse_3P" )
	EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Tone_SonarLock_Impact_Pulse_1P" )
	float startTime = Time()
	while( Time() - startTime < duration )
	{
		foreach( entity projectile in GetProjectileArrayEx( "any", TEAM_ANY, TEAM_ANY, player.GetOrigin(), SPELL_CARD_RADIUS ) )
		{
			if( projectile.GetTeam() != player.GetTeam() )
			{
				PlayFX( $"P_plasma_exp_SM", projectile.GetOrigin() )
				EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "Explo_40mm_Impact_3P" )
				projectile.Destroy()
			}
		}
		WaitFrame()
	}
}
#endif