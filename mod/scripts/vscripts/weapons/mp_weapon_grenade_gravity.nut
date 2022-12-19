untyped
global function OnWeaponTossReleaseAnimEvent_weapon_greanade_gravity
global function OnProjectileCollision_weapon_grenade_gravity
global function MpWeaponGrenadeGravity_Init

//int hopupindex = 0

// Vanilla
const float MAX_WAIT_TIME = 6.0 // trigger wait time
const float POP_DELAY = 0.8 // pre ignition time
const float PULL_DELAY = 2.0 // explosion delay
const float PUSH_DELAY = 0.2 // grenade timer after all delays
const float POP_HEIGHT = 60
const float PULL_RANGE = 150.0
const float PULL_STRENGTH_MAX = 300.0
const float PULL_VERT_VEL = 220
const float PUSH_STRENGTH_MAX = 125.0
const float EXPLOSION_DELAY = 0.1
const float FX_END_CAP_TIME = 1.5

// Anti Gravity Star
const float MAX_WAIT_TIME_ANTI = 6.0
const float POP_DELAY_ANTI = 0.1
const float PULL_DELAY_ANTI = 2.0
const float PUSH_DELAY_ANTI = 0.2
const float POP_HEIGHT_ANTI = 1
const float PULL_RANGE_ANTI = 150.0
const float PULL_STRENGTH_MAX_ANTI = 300.0
const float PULL_VERT_VEL_ANTI = 60
const float PUSH_STRENGTH_MAX_ANTI = 0.0
const float EXPLOSION_DELAY_ANTI = 0.1
const float FX_END_CAP_TIME_ANTI = 1.5
//const float PULL_VERTICAL_KNOCKUP_MAX = 75.0
//const float PULL_VERTICAL_KNOCKUP_MIN = 55.0
//const float PUSH_STRENGTH_MIN = 100.0

// Gravity Lift
//const int LIFT_SEGMENT_COUNT = 10
//const float LIFT_HEIGHT_PER_SEGMENT = 50
const float LIFT_HEIGHT = 1200
const float LIFT_RADIUS = 120
const float LIFT_RISE_SPEED = 325
const float LIFT_HORIZON_MOVE_SPEED = 225
const float LIFT_PULL_SPEED_HORIZON = 400
//const float LIFT_PULL_SPEED_MULTIPLIER = 2
const float LIFT_PULL_SPEED_VERTICAl = 300
const float LIFT_TOP_TIME_LIMIT = 2
const float LIFT_LIFETIME = 10
const float LIFT_COOLDOWN = 0.0 // 0.5 // time between second lift, I guess it's no need for titanfall?

//array<entity> hasGravityLifted = []
struct GravLiftStruct
{
	entity trigger
	array<entity> gravityLiftedPlayers = []
	array<entity> reachedHighestPlayers = []
}

array<GravLiftStruct> gravityLifts = []
array<entity> inGravLiftCooldownPlayers = []
//array<entity> gravityLiftedPlayers = []
//array<entity> reachedHighestPlayers = []

// Bleedout balance
const float PULL_DELAY_BLEEDOUT = 1.0

struct
{
	int cockpitFxHandle = -1
} file

const asset GRAVITY_VORTEX_FX = $"P_wpn_grenade_gravity"
const asset GRAVITY_SCREEN_FX = $"P_gravity_mine_FP"

void function MpWeaponGrenadeGravity_Init()
{
	PrecacheParticleSystem( GRAVITY_VORTEX_FX )
	PrecacheParticleSystem( GRAVITY_SCREEN_FX )
	RegisterSignal( "GravityMineTriggered" )
	RegisterSignal( "TouchVisible" )
	RegisterSignal( "LeftGravityMine" )
	#if SERVER
	RegisterSignal( "EnterGravityLift" )
	RegisterSignal( "LeaveGravityLift" )
	#endif

	#if CLIENT
 	StatusEffect_RegisterEnabledCallback( eStatusEffect.gravity_grenade_visual, GravityScreenFXEnable )
 	StatusEffect_RegisterDisabledCallback( eStatusEffect.gravity_grenade_visual, GravityScreenFXDisable )
	#endif
}

var function OnWeaponTossReleaseAnimEvent_weapon_greanade_gravity( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if( weapon.HasMod( "gravity_lift" ) )
	{
		entity deployable = ThrowDeployable( weapon, attackParams, 0.3, OnGravityLiftDeployed )
		weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )
	}
	else
		Grenade_OnWeaponTossReleaseAnimEvent( weapon, attackParams )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
	
}

void function OnProjectileCollision_weapon_grenade_gravity( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()
	entity owner = projectile.GetOwner()
	if( mods.contains( "gravity_lift" ) )
	{
		#if SERVER
		if( !IsAlive( owner ) )
		{
			if( IsValid( projectile ) ) // don't let a useless shuriken stay on ground
			{
				projectile.Destroy()
				return
			}
		}
		OnProjectileCollision_weapon_deployable( projectile, pos, normal, hitEnt, hitbox, isCritical )
		#endif
	}
	else
	{
		bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )

		if ( !didStick )
			return

		if ( projectile.IsMarkedForDeletion() )
			return

		array<string> mods = projectile.ProjectileGetMods()

		#if SERVER
		if( mods.contains( "shuriken" ) )
		{
			if( IsValid( owner ) )
			{
				EmitSoundAtPositionExceptToPlayer( TEAM_UNASSIGNED, pos, owner, "Pilot_PulseBlade_Activated_3P" )
				EmitSoundAtPositionOnlyToPlayer( TEAM_UNASSIGNED, pos, owner, "Pilot_PulseBlade_Activated_1P" )
			}
			PlayFX( $"P_impact_exp_laserlite_AMP", pos + normal, VectorToAngles( normal ) )
			projectile.Destroy()
		}
		else
			thread GravityGrenadeThink( projectile, hitEnt, normal, pos )
		#endif
	}
}

#if SERVER
void function TriggerWait( entity trig, float maxtime )
{
	trig.CheckForLOS()
	trig.EndSignal( "TouchVisible" )
	wait maxtime
}

void function SetGravityGrenadeTriggerFilters( entity gravityMine, entity trig )
{
	if ( gravityMine.GetTeam() == TEAM_IMC )
		trig.kv.triggerFilterTeamIMC = "0"
	else if ( gravityMine.GetTeam() == TEAM_MILITIA )
		trig.kv.triggerFilterTeamMilitia = "0"
	trig.kv.triggerFilterNonCharacter = "0"
}

bool function GravityGrenadeTriggerThink( entity gravityMine )
{
	// EmitSoundOnEntity( gravityMine, "SonarGrenade_On" )

	entity trig = CreateEntity( "trigger_cylinder" )
	trig.SetRadius( PULL_RANGE )
	trig.SetAboveHeight( PULL_RANGE )
	trig.SetBelowHeight( PULL_RANGE )
	trig.SetAbsOrigin( gravityMine.GetOrigin() )

	SetGravityGrenadeTriggerFilters( gravityMine, trig )

	DispatchSpawn( trig )
	trig.SearchForNewTouchingEntity()

	OnThreadEnd(
		function() : ( trig )
		{
			trig.Destroy()
		}
	)

	waitthread TriggerWait( trig, MAX_WAIT_TIME )

	return trig.IsTouched()
}


void function GravityGrenadeThink( entity projectile, entity hitEnt, vector normal, vector pos )
{
	projectile.EndSignal( "OnDestroy" )

	WaitFrame()

	array<string> mods = projectile.ProjectileGetMods()
	if( mods.contains( "anti_gravity_star" ) || mods.contains( "friendlyfire_weapon" ) || IsFriendlyFireOn() )
		SetTeam( projectile, TEAM_UNASSIGNED ) // anti_gravity all players, or pull all players

	vector pullPosition
	if ( hitEnt == svGlobal.worldspawn )
	{
		if( mods.contains( "anti_gravity_star" ) )
			pullPosition = pos + normal * POP_HEIGHT_ANTI
		else
			pullPosition = pos + normal * POP_HEIGHT
	}
	else
		pullPosition = projectile.GetOrigin()

	entity gravTrig = CreateEntity( "trigger_point_gravity" )
	// pull inner radius, pull outer radius, reduce speed inner radius, reduce speed outer radius, pull accel, pull speed, 0
	if( mods.contains( "anti_gravity_star" ) )
		gravTrig.SetParams( 0.0, PULL_RANGE_ANTI * 2, 32, 128, 1500, 600 )
	else
		gravTrig.SetParams( 0.0, PULL_RANGE * 2, 32, 128, 1500, 600 ) // more subtle pulling effect before popping up
	gravTrig.SetOrigin( projectile.GetOrigin() )
	projectile.ClearParent()
	projectile.SetParent( gravTrig )
	gravTrig.RoundOriginAndAnglesToNearestNetworkValue()

	entity trig = CreateEntity( "trigger_cylinder" )
	trig.SetRadius( PULL_RANGE )
	trig.SetAboveHeight( PULL_RANGE )
	trig.SetBelowHeight( PULL_RANGE )
	trig.SetOrigin( projectile.GetOrigin() )
	SetGravityGrenadeTriggerFilters( projectile, trig )
	trig.kv.triggerFilterPlayer = "none" // player effects
	if( mods.contains( "anti_gravity_star" ) )
		trig.SetEnterCallback( OnAntiGravTrigEnter )
	else
		trig.SetEnterCallback( OnGravGrenadeTrigEnter )
	trig.SetLeaveCallback( OnGravGrenadeTrigLeave )

	SetTeam( gravTrig, projectile.GetTeam() )
	SetTeam( trig, projectile.GetTeam() )
	DispatchSpawn( gravTrig )
	DispatchSpawn( trig )
	gravTrig.SearchForNewTouchingEntity()
	trig.SearchForNewTouchingEntity()

	EmitSoundOnEntity( projectile, "default_gravitystar_impact_3p" )
	entity FX = StartParticleEffectOnEntity_ReturnEntity( projectile, GetParticleSystemIndex( GRAVITY_VORTEX_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
//	EmitSoundOnEntity( projectile, "gravitystar_vortex" )

	string noSpawnArea = CreateNoSpawnArea( TEAM_INVALID, projectile.GetTeam(), projectile.GetOrigin(), MAX_WAIT_TIME + POP_DELAY + PULL_DELAY + EXPLOSION_DELAY + 0.1, PULL_RANGE * 3.0 )
	if( mods.contains( "anti_gravity_star" ) )
		noSpawnArea = CreateNoSpawnArea( TEAM_INVALID, projectile.GetTeam(), projectile.GetOrigin(), MAX_WAIT_TIME_ANTI + POP_DELAY_ANTI + PULL_DELAY_ANTI + EXPLOSION_DELAY_ANTI + 0.1, PULL_RANGE_ANTI * 3.0 )

	OnThreadEnd(
		function() : ( gravTrig, trig, FX, noSpawnArea )
		{
			if ( IsValid( trig ) )
				trig.Destroy()
			if ( IsValid( gravTrig ) )
				gravTrig.Destroy()

			EntFireByHandle( FX, "kill", "", FX_END_CAP_TIME, null, null )

			DeleteNoSpawnArea( noSpawnArea )
		}
	)
	
	// early version behavior!
	if ( mods.contains( "gravity_mine" ) && !hitEnt.IsPlayer() && !hitEnt.IsNPC() )
		GravityGrenadeTriggerThink( projectile ) 

	if( mods.contains( "anti_gravity_star" ) )
		wait POP_DELAY_ANTI
	else
		wait POP_DELAY

	entity mover = CreateOwnedScriptMover( projectile )
	projectile.SetParent( mover, "ref", true )
	EmitSoundOnEntity( projectile, "weapon_gravitystar_preexplo" )

	if ( hitEnt == svGlobal.worldspawn )
	{
		if( mods.contains( "anti_gravity_star" ) )
			mover.NonPhysicsMoveTo( pullPosition, POP_DELAY_ANTI, 0, POP_DELAY_ANTI )
		else
			mover.NonPhysicsMoveTo( pullPosition, POP_DELAY, 0, POP_DELAY )
		gravTrig.SetOrigin( pullPosition )
		gravTrig.RoundOriginAndAnglesToNearestNetworkValue()
	}

	// full strength radius, outer radius, reduce vel radius, accel, maxvel
	if( mods.contains( "anti_gravity_star" ) )
		gravTrig.SetParams( PULL_RANGE_ANTI, PULL_RANGE_ANTI * 2, 32, 128, -1500, 400 )
	else
		gravTrig.SetParams( PULL_RANGE, PULL_RANGE * 2, 32, 128, 2000, 400 ) // more intense pull

	AI_CreateDangerousArea( projectile, projectile, PULL_RANGE * 2.0, TEAM_INVALID, true, false )

	if( mods.contains( "anti_gravity_star" ) )
		wait PULL_DELAY_ANTI
	else if( mods.contains( "bleedout_balance" ) )
		wait PULL_DELAY_BLEEDOUT
	else
		wait PULL_DELAY

	if( mods.contains( "anti_gravity_star" ) )
		projectile.SetGrenadeTimer( EXPLOSION_DELAY_ANTI )
	else
		projectile.SetGrenadeTimer( EXPLOSION_DELAY )
		
	if( mods.contains( "anti_gravity_star" ) )
		wait EXPLOSION_DELAY_ANTI - 0.1 // ensure gravTrig is destroyed before detonation
	else
		wait EXPLOSION_DELAY - 0.1

	thread DestroyAfterDelay( mover, 0.25 )
}

void function OnGravGrenadeTrigEnter( entity trigger, entity ent )
{
	if ( ent.GetTeam() == trigger.GetTeam() ) // trigger filters handle this except in FFA
		return

	if ( ent.IsNPC() && ( IsGrunt( ent ) || IsSpectre( ent ) || IsStalker( ent ) ) && IsAlive( ent ) && !ent.ContextAction_IsActive() && ent.IsInterruptable() )
	{
		ent.ContextAction_SetBusy()
		ent.Anim_ScriptedPlayActivityByName( "ACT_FALL", true, 0.2 )

		if ( IsGrunt( ent ) )
			EmitSoundOnEntity( ent, "diag_efforts_gravStruggle_gl_grunt_3p" )

		thread EndNPCGravGrenadeAnim( ent )
	}
}

void function OnAntiGravTrigEnter( entity trigger, entity ent )
{
	if ( ent.GetTeam() != trigger.GetTeam() )
		return
}

void function OnGravGrenadeTrigLeave( entity trigger, entity ent )
{
	if ( IsValid( ent ) )
	{
		ent.Signal( "LeftGravityMine" )
	}
}

void function EndNPCGravGrenadeAnim( entity ent )
{
	ent.EndSignal( "OnDestroy" )
	ent.EndSignal( "OnAnimationInterrupted" )
	ent.EndSignal( "OnAnimationDone" )

	ent.WaitSignal( "LeftGravityMine", "OnDeath" )

	ent.ContextAction_ClearBusy()
	ent.Anim_Stop()
}

void function Proto_SetEnemyVelocity_Pull( entity enemy, vector projOrigin )
{
	

	if ( enemy.IsPhaseShifted() )
		return
	vector enemyOrigin = enemy.GetOrigin()
	vector dir = Normalize( projOrigin - enemy.GetOrigin() )
	float dist = Distance( enemyOrigin, projOrigin )
	float distZ = enemyOrigin.z - projOrigin.z

	vector newVelocity = enemy.GetVelocity() * GraphCapped( dist, 50, PULL_RANGE, 0, 1 ) + dir * GraphCapped( dist, 50, PULL_RANGE, 0, PULL_STRENGTH_MAX ) + < 0, 0, GraphCapped( distZ, -50, 0, PULL_VERT_VEL, 0 )>
	if ( enemy.IsTitan() )
		newVelocity.z = 0
	/*
	if( hopupindex == 1 )
		newVelocity = enemy.GetVelocity() * GraphCapped( dist, 50, PULL_RANGE_ANTI, 0, 1 ) + dir * GraphCapped( dist, 50, PULL_RANGE_ANTI, 0, PULL_STRENGTH_MAX_ANTI ) + < 0, 0, GraphCapped( distZ, -50, 0, PULL_VERT_VEL, 0 )>
	*/
	enemy.SetVelocity( newVelocity )
}

array<entity> function GetNearbyEnemiesForGravGrenade( entity projectile )
{
	array<string> mods = projectile.ProjectileGetMods()
	int team = projectile.GetTeam()
	entity owner = projectile.GetOwner()
	vector origin = projectile.GetOrigin()
	array<entity> nearbyEnemies
	array<entity> guys = GetPlayerArrayEx( "any", TEAM_ANY, TEAM_ANY, origin, PULL_RANGE )
	if( mods.contains( "anti_gravity_star" ) )
		guys = GetPlayerArrayEx( "any", TEAM_ANY, TEAM_ANY, origin, PULL_RANGE_ANTI )
	foreach ( guy in guys )
	{
		if ( !IsAlive( guy ) )
			continue

		if ( IsEnemyTeam( team, guy.GetTeam() ) || (IsValid( owner ) && guy == owner) )
			nearbyEnemies.append( guy )
	}

	array<entity> ai = GetNPCArrayEx( "any", TEAM_ANY, team, origin, PULL_RANGE )
	if( mods.contains( "anti_gravity_star" ) )
		ai = GetNPCArrayEx( "any", TEAM_ANY, team, origin, PULL_RANGE_ANTI )
	foreach ( guy in ai )
	{
		if ( IsAlive( guy ) )
			nearbyEnemies.append( guy )
	}

	return nearbyEnemies
}

array<entity> function GetNearbyProjectilesForGravGrenade( entity gravGrenade )
{
	int team = gravGrenade.GetTeam()
	entity owner = gravGrenade.GetOwner()
	vector origin = gravGrenade.GetOrigin()

	array<entity> projectiles = GetProjectileArrayEx( "any", TEAM_ANY, TEAM_ANY, origin, PULL_RANGE )
	/*
	if( hopupindex == 1 )
		projectiles = GetProjectileArrayEx( "any", TEAM_ANY, TEAM_ANY, origin, PULL_RANGE_ANTI )
	*/
	array<entity> affectedProjectiles

	entity projectileOwner
	foreach( projectile in projectiles )
	{
		if ( projectile == gravGrenade )
			continue

		projectileOwner = projectile.GetOwner()
		if ( IsEnemyTeam( team, projectile.GetTeam() ) || ( IsValid( projectileOwner ) && projectileOwner == owner ) )
			affectedProjectiles.append( projectile )
	}

	return affectedProjectiles
}

//point_push version - hard to control motion with this.
/*
void function CreateGravitationalForce( float mag, vector org )
{
	entity point_push = CreateEntity( "point_push" )
	point_push.kv.spawnflags = 31
	point_push.kv.enabled = 1
	point_push.kv.magnitude = mag
	point_push.kv.radius = PULL_RANGE
	point_push.SetOrigin( org )
	DispatchSpawn( point_push )
	point_push.Fire( "Enable" )
	point_push.Fire( "Kill", "", 0.2 )
}
*/
//Script mover version
/*
array<entity> nearbyEnemies = GetNearbyEnemiesForGravGrenade( projectile )
foreach ( enemy in nearbyEnemies )
{
	if ( enemy.IsPlayer() )
		EmitSoundOnEntityOnlyToPlayer( enemy, enemy, "Explo_VortexGrenade_Impact_1P" )

	if ( !enemy.IsTitan() )
		thread PROTO_GravGrenadePull( enemy, projectile )
}
void function PROTO_GravGrenadePull( entity enemy, entity projectile )
{
	enemy.EndSignal( "OnDestroy" )

	entity mover = CreateOwnedScriptMover( enemy )
	enemy.SetParent( mover, "ref", true )

	OnThreadEnd(
	function() : ( enemy, mover )
		{
			if ( IsValid( enemy ) )
				enemy.ClearParent()

			if ( IsValid( mover ) )
				mover.Destroy()
		}
	)

	if ( enemy.IsPlayer() )
		enemy.StunMovementBegin( POP_DELAY )

	vector mins = enemy.GetBoundingMins()
	vector maxs = enemy.GetBoundingMaxs()
	vector org1 = enemy.GetOrigin()
	vector org2 = projectile.GetOrigin()
	vector additonalHeight = < 0, 0, GraphCapped( Distance( org1, org2 ), 0, PULL_RANGE, PULL_VERTICAL_KNOCKUP_MIN, PULL_VERTICAL_KNOCKUP_MAX ) >
	vector newPosition = org1 + ( org2 - org1 ) / 2.0 + additonalHeight
	TraceResults result = TraceHull( org1, newPosition, mins, maxs, [enemy,mover], TRACE_MASK_SOLID_BRUSHONLY, TRACE_COLLISION_GROUP_NONE )
	mover.NonPhysicsMoveTo( ( newPosition - org1 ) * result.fraction + org1 + result.surfaceNormal, PULL_DELAY, 0, 0 )

	wait PULL_DELAY

	org1 = mover.GetOrigin()
	vector dir = Normalize( org1 - org2 )
	newPosition = org1 + dir * RandomFloatRange( PUSH_STRENGTH_MIN, PUSH_STRENGTH_MAX )
	result = TraceHull( org1, newPosition, mins, maxs, [enemy,mover], TRACE_MASK_SOLID_BRUSHONLY, TRACE_COLLISION_GROUP_NONE )
	mover.NonPhysicsMoveTo( ( newPosition - org1 ) * result.fraction + org1 + result.surfaceNormal, PUSH_DELAY, 0, 0 )

	wait PUSH_DELAY
}
*/
#endif

#if CLIENT
void function GravityScreenFXEnable( entity ent, int statusEffect, bool actuallyChanged )
{
	printt( "GravityScreenFXEnable" )
	if ( !actuallyChanged )
		return

	if ( ent == GetLocalViewPlayer() )
	{
		entity cockpit =GetLocalViewPlayer().GetCockpit()
		if ( IsValid( cockpit ) )
		{
			file.cockpitFxHandle = StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( GRAVITY_SCREEN_FX ), FX_PATTACH_POINT_FOLLOW, cockpit.LookupAttachment("CAMERA") )
		}
	}
}

void function GravityScreenFXDisable( entity ent, int statusEffect, bool actuallyChanged )
{
	printt( "GravityScreenFXDisable" )
	if ( !actuallyChanged )
		return

	if ( ent == GetLocalViewPlayer() )
	{
		EffectStop( file.cockpitFxHandle, false, true )
	}
}
#endif

void function OnGravityLiftDeployed( entity projectile )
{
	#if SERVER
	thread GravityLiftThink( projectile )
	#endif
}

#if SERVER
void function GravityLiftThink( entity projectile )
{
	if( !IsValid( projectile ) )
		return

	GravLiftStruct gravityLift

	EmitSoundOnEntity( projectile, "default_gravitystar_impact_3p" )
	
	/*// FX_HARVESTER_BEAM don't have these things
	entity cpColor = CreateEntity( "info_placement_helper" )
	SetTargetName( cpColor, UniqueString( "gravlift_cpColor" ) )
	cpColor.SetOrigin( < 0,100,255 > )
	DispatchSpawn( cpColor )

	entity cpRadius = CreateEntity( "info_placement_helper" )
	SetTargetName( cpRadius, UniqueString( "gravlift_cpRadius" ) )
	cpRadius.SetOrigin( Vector(LIFT_HEIGHT,LIFT_HEIGHT,LIFT_HEIGHT) )
	DispatchSpawn( cpRadius )

	entity gravliftbeam = CreateEntity( "info_particle_system" )
	gravliftbeam.kv.start_active = 1
	gravliftbeam.SetValueForEffectNameKey( FX_HARVESTER_BEAM )
	SetTargetName( gravliftbeam, UniqueString() )
	gravliftbeam.kv.cpoint1 = cpColor.GetTargetName()
	gravliftbeam.kv.cpoint5 = cpRadius.GetTargetName()
	gravliftbeam.SetOrigin( projectile.GetOrigin() )
	DispatchSpawn( gravliftbeam )
	*/

	entity gravliftbeam = StartParticleEffectOnEntity_ReturnEntity( projectile, GetParticleSystemIndex( FX_HARVESTER_BEAM ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
	EffectSetControlPointVector( gravliftbeam, 1, < 0,100,255 > )

	entity trigger = CreateTriggerRadiusMultiple( projectile.GetOrigin(), LIFT_RADIUS, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_START_DISABLED | TRIG_FLAG_NO_PHASE_SHIFT, LIFT_HEIGHT, -1 )

	AddCallback_ScriptTriggerEnter( trigger, OnGravityLiftTriggerEnter )
	AddCallback_ScriptTriggerLeave( trigger, OnGravityLiftTriggerLeave )

	ScriptTriggerSetEnabled( trigger, true )

	gravityLift.trigger = trigger
	gravityLifts.append( gravityLift )

	float startTime = Time()
	float bottomHeight = projectile.GetOrigin().z
	float progressTime
	while( true )
	{
		if( IsValid( trigger ) )
		{
			foreach( entity player in gravityLift.gravityLiftedPlayers )
			{
				if( IsValid( player ) )
				{
					//if( player.IsWallRunning() || player.IsWallHanging() || player.GetParent() != null )
					if( inGravLiftCooldownPlayers.contains( player ) || player.GetParent() != null )
					{
						player.kv.gravity = 0.0
						continue
					}
					if( !gravityLift.reachedHighestPlayers.contains( player ) )
					{
						player.kv.gravity = 0.001
						vector airspeed = GetPlayerVelocityFromInput( player, LIFT_HORIZON_MOVE_SPEED )
						airspeed.z = LIFT_RISE_SPEED
						player.SetVelocity( airspeed )
					}
					if( gravityLift.reachedHighestPlayers.contains( player ) )
					{
						vector airspeed = GetPlayerVelocityFromInput( player, LIFT_HORIZON_MOVE_SPEED )
						airspeed.z = 0
						player.SetVelocity( airspeed )
					}
					if( player.GetOrigin().z - bottomHeight >= LIFT_HEIGHT && !gravityLift.reachedHighestPlayers.contains( player ) )
						thread OnPlayerReachedHighest( player, trigger )
					Nessie_PutPlayerInSafeSpot( player, 1 )
				}
			}
		}
		WaitFrame()
		progressTime = Time()
		if( progressTime - startTime >= LIFT_LIFETIME && gravityLift.gravityLiftedPlayers.len() == 0 /*gravityLift.reachedHighestPlayers.len() == 0*/ )
		{
			//DestroyPlacementHelper( cpRadius, cpColor )
			thread DestroyGravityLift( projectile, trigger, gravityLift, gravliftbeam )
			return
		}
		else if( progressTime - startTime >= LIFT_LIFETIME * 1.5 )
		{
			//DestroyPlacementHelper( cpRadius, cpColor )
			thread DestroyGravityLift( projectile, trigger, gravityLift, gravliftbeam )
			return
		}
	}
}

void function OnGravityLiftTriggerEnter( entity trigger, entity player )
{
	if( player.IsTitan() )
		return

	player.Signal( "EnterGravityLift" )

	GravLiftStruct gravityLift
	foreach( GravLiftStruct lift in gravityLifts )
	{
		if( lift.trigger == trigger )
			gravityLift = lift
	}

	if( !gravityLift.gravityLiftedPlayers.contains( player ) )
	{
		gravityLift.gravityLiftedPlayers.append( player )
		//EmitSoundOnEntityOnlyToPlayer( player, player, "titan_flight_hover_1p" )
		//EmitSoundOnEntityExceptToPlayer( player, player, "titan_flight_hover_3p" )
		StopSoundOnEntity( player, "titan_flight_hover_3p" )
		EmitSoundOnEntity( player, "titan_flight_hover_3p" )
		player.ForceStand()
		//player.kv.airSpeed = LIFT_HORIZON_MOVE_SPEED
		//player.kv.gravity = 0.001
		//if( player.IsOnGround() )
		//	player.SetOrigin( player.GetOrigin() + < 0,0,20 > ) //may get stuck, but should set this on if radius is small
		//else
		//	player.SetOrigin( player.GetOrigin() + < 0,0,5 > ) //may get stuck
	}
}

void function OnGravityLiftTriggerLeave( entity trigger, entity player )
{
	if( player.IsTitan() )
		return

	player.Signal( "LeaveGravityLift" )

	GravLiftStruct gravityLift
	foreach( GravLiftStruct lift in gravityLifts )
	{
		if( lift.trigger == trigger )
			gravityLift = lift
	}

	if( gravityLift.gravityLiftedPlayers.contains( player ) )
	{
		gravityLift.gravityLiftedPlayers.fastremovebyvalue( player )
		//StopSoundOnEntity( player, "titan_flight_hover_1p" )
		StopSoundOnEntity( player, "titan_flight_hover_3p" )
		//player.kv.airSpeed = 60.0
		player.kv.gravity = 0.0 // defensive fix
		array<string> settingMods = player.GetPlayerSettingsMods()
		//if( settingMods.contains( "wallclimber" ) ) // wallclimber uses settings gravity now, not kv.gravity
		//	player.kv.gravity = player.GetPlayerSettingsField( "gravityScale" )
		player.UnforceStand()
		if( !inGravLiftCooldownPlayers.contains( player ) )
		{
			vector airspeed = GetPlayerVelocityFromInput( player, LIFT_PULL_SPEED_HORIZON )
			airspeed.z = LIFT_PULL_SPEED_VERTICAl
			player.SetVelocity( airspeed )
			thread GravLiftCooldownThink( player )
		}
		//print( "[MIXED_GAME]" + player.GetPlayerName() + " left gravitylift and has been bounced away" )
	}
}

void function OnPlayerReachedHighest( entity player, entity trigger )
{
	player.EndSignal( "LeaveGravityLift" )
		
	GravLiftStruct gravityLift
	foreach( GravLiftStruct lift in gravityLifts )
	{
		if( lift.trigger == trigger )
			gravityLift = lift
	}

	if( !gravityLift.reachedHighestPlayers.contains( player ) )
		gravityLift.reachedHighestPlayers.append( player )

	OnThreadEnd(
		function(): ( player, gravityLift )
		{
			if( gravityLift.reachedHighestPlayers.contains( player ) )
				gravityLift.reachedHighestPlayers.fastremovebyvalue( player )
		}
	)

	wait LIFT_TOP_TIME_LIMIT

	if( IsValid( player ) && IsAlive( player ) )
	{
		BouncePlayerForward( player )
		//StopSoundOnEntity( player, "titan_flight_hover_1p" )
		StopSoundOnEntity( player, "titan_flight_hover_3p" )
		if( gravityLift.gravityLiftedPlayers.contains( player ) )
		{
			gravityLift.gravityLiftedPlayers.fastremovebyvalue( player )
			//player.kv.airSpeed = 60.0
			player.kv.gravity = 0.0
			//player.kv.gravity = player.GetPlayerSettingsField( "gravityScale" )
		}
		if( gravityLift.reachedHighestPlayers.contains( player ) )
			gravityLift.reachedHighestPlayers.fastremovebyvalue( player )
	}
}

void function BouncePlayerForward( entity player )
{
	if( IsValid( player ) )
	{
		player.UnforceStand()
		vector playerAngles = player.EyeAngles()
		//vector playerAngles = player.GetAngles()
		//vector forward = AnglesToForward( playerAngles )
		vector forward = AnglesToForward( < 0, playerAngles.y, 0 > ) // yaw only
		//vector directionVec = Vector(0,0,0)
		//directionVec += forward
		//vector directionAngles = VectorToAngles( directionVec )
		//vector directionForward = AnglesToForward( directionAngles )
		//vector airspeed = directionForward * LIFT_PULL_SPEED_HORIZON
		vector airspeed = forward * LIFT_PULL_SPEED_HORIZON
		airspeed.z = LIFT_PULL_SPEED_VERTICAl
		player.SetVelocity( airspeed )
		thread GravLiftCooldownThink( player )
	}
}

void function GravLiftCooldownThink( entity player )
{
	if( LIFT_COOLDOWN <= 0 )
		return

	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	inGravLiftCooldownPlayers.append( player )

	OnThreadEnd(
		function(): ( player )
		{
			if( IsValid( player ) )
			{
				inGravLiftCooldownPlayers.fastremovebyvalue( player )
			}
		}
	)


	wait LIFT_COOLDOWN
}

void function DestroyGravityLift( entity projectile, entity trigger, GravLiftStruct gravityLift, entity gravliftbeam )
{
	if( IsValid(gravliftbeam) )
	{
		gravliftbeam.kv.Visibilityflags = 0
		wait 0.1
		EffectStop(gravliftbeam)
	}
	if( IsValid(projectile) )
	{
		projectile.Destroy()
	}
	if( IsValid(trigger) )
		trigger.Destroy()
	gravityLifts.fastremovebyvalue( gravityLift )
	//foreach( entity player in GetPlayerArray() ) // fix!!! for sometimes ending lift stucks players
	//{	
	//	Nessie_PutPlayerInSafeSpot( player, 1 )
	//}
}

void function DestroyPlacementHelper( entity cpRadius, entity cpColor )
{
	if( IsValid( cpRadius ) )
		cpRadius.Destroy()
	if( IsValid( cpColor ) )
		cpColor.Destroy()
}

vector function GetPlayerVelocityFromInput( entity player, float scale )
{
	vector angles = player.EyeAngles()
	float xAxis = player.GetInputAxisRight()
	float yAxis = player.GetInputAxisForward()
	vector directionForward = GetDirectionFromInput( angles, xAxis, yAxis )

	return directionForward * scale
}

vector function GetDirectionFromInput( vector playerAngles, float xAxis, float yAxis )
{
	playerAngles.x = 0
	playerAngles.z = 0
	vector forward = AnglesToForward( playerAngles )
	vector right = AnglesToRight( playerAngles )

	vector directionVec = Vector(0,0,0)
	directionVec += right * xAxis
	directionVec += forward * yAxis

	vector directionAngles = VectorToAngles( directionVec )
	vector directionForward = AnglesToForward( directionAngles )

	return directionForward
}

/* //Bassically some try, failed though
void function GravityLiftThink( entity projectile )
{
	if( !IsValid( projectile ) )
		return

	//float height = GetRoofHeight( projectile )
	
	//float highestpoint
	//if( height >= LIFT_HEIGHT )
	//	highestpoint = LIFT_HEIGHT //* 1.2
	//else
	//	highestpoint = height - 80

	GravLiftStruct gravityLift

	EmitSoundOnEntity( projectile, "default_gravitystar_impact_3p" )
	entity gravliftbeam = StartParticleEffectOnEntity_ReturnEntity( projectile, GetParticleSystemIndex( FX_HARVESTER_BEAM ), FX_PATTACH_ABSORIGIN_FOLLOW, 0 )
	EffectSetControlPointVector( gravliftbeam, 1, < 0,100,255 > )

	//entity trigger = CreateTriggerRadiusMultiple( projectile.GetOrigin(), LIFT_RADIUS, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_START_DISABLED | TRIG_FLAG_NO_PHASE_SHIFT, height, -1 )
	entity trigger = CreateTriggerRadiusMultiple( projectile.GetOrigin(), LIFT_RADIUS, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_START_DISABLED | TRIG_FLAG_NO_PHASE_SHIFT, LIFT_HEIGHT, -1 )

	AddCallback_ScriptTriggerEnter( trigger, OnGravityLiftTriggerEnter )
	AddCallback_ScriptTriggerLeave( trigger, OnGravityLiftTriggerLeave )

	ScriptTriggerSetEnabled( trigger, true )

	gravityLift.trigger = trigger
	gravityLifts.append( gravityLift )

	//thread DelayedDestroyTrigger( projectile, trigger, gravliftbeam )

	float startTime = Time()
	float progressTime
	while( true )
	{
		if( IsValid( trigger ) )
		{
			foreach( entity player in gravityLift.gravityLiftedPlayers )
			{
				if( IsValid( player ) )
				{
					if( !gravityLift.reachedHighestPlayers.contains( player ) )
					{
						vector airspeed = GetPlayerVelocityFromInput( player, LIFT_HORIZON_MOVE_SPEED )
						airspeed.z = LIFT_RISE_SPEED
						player.SetVelocity( airspeed )
					}
					if( gravityLift.reachedHighestPlayers.contains( player ) )
					{
						vector airspeed = GetPlayerVelocityFromInput( player, LIFT_HORIZON_MOVE_SPEED )
						airspeed.z = 0
						player.SetVelocity( airspeed )
					}
					//if( player.GetOrigin().z - projectile.GetOrigin().z >= highestpoint && !reachedHighestPlayers.contains( player ) )
					if( player.GetOrigin().z - projectile.GetOrigin().z >= LIFT_HEIGHT && !gravityLift.reachedHighestPlayers.contains( player ) )
						thread OnPlayerReachedHighest( player, trigger )
					//if( !reachedHighestPlayers.contains( player ) )
					//{
					//	vector liftspeed = player.GetVelocity()
					//	liftspeed.z = LIFT_RISE_SPEED
					//	if( !CanTetherPlayer( player, trigger ) )
					//	{
					//		BouncePlayerAway( player )
					//		if( gravityLiftedPlayers.contains( player ) )
					//		{
					//			gravityLiftedPlayers.fastremovebyvalue( player )
					//			player.kv.gravity = 1
					//			//player.kv.gravity = player.GetPlayerSettingsField( "gravityScale" )
					//		}
					//		if( reachedHighestPlayers.contains( player ) )
					//			reachedHighestPlayers.fastremovebyvalue( player )
					//	}
					//	player.SetVelocity( liftspeed )
					//}
					if( reachedHighestPlayers.contains( player ) )
					{
						vector liftspeed = player.GetVelocity()
						liftspeed.z = 0
						player.SetVelocity( liftspeed )
					}
					if( PlayerTouchedRoof( player ) )
					{
						if( !reachedHighestPlayers.contains( player ) )
							thread OnPlayerReachedHighest( player )
					}
				}
			}
		}
		WaitFrame()
		progressTime = Time()
		//if( progressTime - startTime >= LIFT_LIFETIME - 0.1 )
		//{
		//	if( IsValid(gravliftbeam) )
		//	{
		//		if( gravliftbeam.kv.Visibilityflags != 0 )
		//			gravliftbeam.kv.Visibilityflags = 0
		//	}
		//}
		if( progressTime - startTime >= LIFT_LIFETIME && gravityLift.gravityLiftedPlayers.len() == 0 ) //gravityLift.reachedHighestPlayers.len() == 0
		{
			if( IsValid(gravliftbeam) )
			{
				gravliftbeam.kv.Visibilityflags = 0
				wait 0.1
				EffectStop(gravliftbeam)
			}
			if( IsValid(projectile) )
			{
				//projectile.GrenadeExplode( < 0,0,0 > )
				projectile.Destroy()
			}
			if( IsValid(trigger) )
				trigger.Destroy()
			gravityLifts.fastremovebyvalue( gravityLift )
			break
		}
	}
}

void function DelayedDestroyTrigger( entity projectile, entity trigger, entity fx )
{
	wait LIFT_LIFETIME
	if( IsValid( fx ) )
		fx.kv.Visibilityflags = 0
	if( IsValid( trigger ) )
		trigger.Destroy()
	if( IsValid( projectile ) )
		projectile.Destroy()
}

bool function CanTetherPlayer( entity player, entity trigger )
{
	TraceResults trace = TraceLine( trigger.GetOrigin(), player.GetOrigin(), [ trigger ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
	if( trace.hitEnt != player )
		return false

	return true
}

bool function PlayerTouchedRoof( entity player )
{
	TraceResults trace = TraceLine( player.GetOrigin(), player.GetOrigin() + < 0,0,60 >, [ player ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
	if( trace.hitEnt == null )
		return false

	return true
}

float function GetRoofHeight( entity projectile, vector startpos, vector endpos )
{
	TraceResults trace = TraceLine( startpos, startpos + < 0,0,9999 >, [projectile], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
	float roofheight
	// Avoid line been interrupted by players or npcs
	if( IsValid( trace.hitEnt ) )
	{
		if( trace.hitEnt.IsPlayer() || trace.hitEnt.IsNPC() )
		{
			return GetRoofHeight( projectile, trace.hitEnt.GetOrigin() + < 0,0,20 >, trace.hitEnt.GetOrigin() + < 0,0,9999 > )
		}
	}
	else
		roofheight = trace.endPos.z - projectile.GetOrigin().z

	if( roofheight >= LIFT_HEIGHT )
		return LIFT_HEIGHT

	return roofheight
}

void function CreateGravityLift( entity projectile )
{
	array<entity> triggers = []
	array<entity> fxhandles = []
	entity poshandle = CreateEntity( "script_mover" )
	poshandle.SetOrigin( projectile.GetOrigin() )
	
	for( int i = 0; i < LIFT_SEGMENT_COUNT; i++ )
	{
		if( !RoofCheck( poshandle ) )
			continue
		entity trigger = CreateTriggerBySegment( poshandle.GetOrigin() )
		entity fxhandle = CreateEntity( "script_mover" )
		fxhandle.SetOrigin( poshandle.GetOrigin() )
		fxhandle.SetModel( $"models/domestic/nessy_doll.mdl" )
		entity fx = StartParticleEffectOnEntity_ReturnEntity( fxhandle, GetParticleSystemIndex( GRAVITY_VORTEX_FX ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		triggers.append( trigger )
		fxhandles.append( fxhandle )
		poshandle.SetOrigin( poshandle.GetOrigin() + < 0,0,LIFT_HEIGHT_PER_SEGMENT > )
	}
	poshandle.Destroy()

	wait LIFT_LIFETIME

	foreach( entity trigger in triggers )
	{
		if( IsValid( trigger ) )
			trigger.Destroy()
	}
	foreach( entity fxhandle in fxhandles )
	{
		if( IsValid( fxhandle ) )
			fxhandle.Destroy()
	}
	if( IsValid( projectile ) )
		projectile.GrenadeExplode( < 0,0,0 > )
}

entity function CreateTriggerBySegment( vector pos )
{
	entity trigger = CreateTriggerRadiusMultiple( pos, LIFT_RADIUS, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_START_DISABLED | TRIG_FLAG_NO_PHASE_SHIFT, LIFT_HEIGHT_PER_SEGMENT, 0 )

	AddCallback_ScriptTriggerEnter( trigger, OnGravityLiftTriggerEnter )
	AddCallback_ScriptTriggerLeave( trigger, OnGravityLiftTriggerLeave )

	ScriptTriggerSetEnabled( trigger, true )
	return trigger
}

void function OnGravityLiftTriggerEnter( entity trigger, entity ent )
{
	//ent.Signal( "EnterGravityLift" )
	ent.EndSignal( "LeaveGravityLift" )
	ent.EndSignal( "OnDeath" )
	ent.EndSignal( "OnDestroy" )

	
	//hasGravityLifted.append( ent )
	//if( !hasGravityLifted.contains( ent ) )
	//{
	//	ent.kv.gravity = 0.0
	//	ent.kv.airAcceleration = 5400
		while( true )
		{
			if( IsValid( ent ) )
			{
				vector airspeed = GetPlayerVelocityFromInput( ent, LIFT_HORIZON_MOVE_SPEED )
				airspeed.z = LIFT_RISE_SPEED
				ent.SetVelocity( airspeed )
			}
			WaitFrame()
		}
	//}

	//OnThreadEnd(
	//	function(): ( ent )
	//	{
	//		hasGravityLifted.fastremovebyvalue( ent )
	//		if( IsValid( ent ) )
	//			ent.kv.gravity = 0.8
	//	}
	//)
}

void function OnGravityLiftTriggerLeave( entity trigger, entity ent )
{
	ent.Signal( "LeaveGravityLift" )
	//SetPlayerVelocityFromInput( ent, LIFT_PULL_SPEED_HORIZON, < 0,0,LIFT_PULL_SPEED_VERTICAl> )
}

void function OnPlayerReachedHighestTrigger( entity player )
{
	player.EndSignal( "LeaveGravityLift" )

	OnThreadEnd(
		function(): ( player )
		{
			if( IsValid( player ) )
				SetPlayerVelocityFromInput( player, LIFT_PULL_SPEED_HORIZON, < 0,0,LIFT_PULL_SPEED_VERTICAl> )
		}
	)

	wait LIFT_TOP_TIME_LIMIT
}

bool function RoofCheck( entity trigger )
{
	if( TraceLine( trigger.GetOrigin(), trigger.GetOrigin() + < 0,0,LIFT_HEIGHT_PER_SEGMENT >, [ trigger ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE ).hitEnt == null )
		return false

	return true
}
*/
#endif