#if SERVER
untyped
#endif

global function MpTitanAbilitySlowTrap_Init
global function OnWeaponPrimaryAttack_titanweapon_slow_trap

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_slow_trap
#endif

global function OnWeaponOwnerChange_titanweapon_slow_trap // for molotovs

//TODO: Need to reassign ownership to whomever destroys the Barrel.
const asset DAMAGE_AREA_MODEL = $"models/fx/xo_shield.mdl"
const asset SLOW_TRAP_MODEL = $"models/weapons/titan_incendiary_trap/w_titan_incendiary_trap.mdl"
const asset SLOW_TRAP_FX_ALL = $"P_meteor_Trap_start"
const float SLOW_TRAP_LIFETIME = 12.0
const float SLOW_TRAP_BUILD_TIME = 1.0
const float SLOW_TRAP_RADIUS = 240
const asset TOXIC_FUMES_FX 	= $"P_meteor_trap_gas"
const asset TOXIC_FUMES_S2S_FX 	= $"P_meteor_trap_gas_s2s"
const asset FIRE_CENTER_FX = $"P_meteor_trap_center"
const asset BARREL_EXP_FX = $"P_meteor_trap_EXP"
const asset FIRE_LINES_FX = $"P_meteor_trap_burn"
const asset FIRE_LINES_S2S_FX = $"P_meteor_trap_burn_s2s"
const float FIRE_TRAP_MINI_EXPLOSION_RADIUS = 75
const float FIRE_TRAP_LIFETIME = 10.5
const int GAS_FX_HEIGHT = 45

const float GAS_TRAP_BUILD_TIME = 1.5
const float GAS_TRAP_LIFETIME = 60
const float GAS_TRAP_TOXIC_DURATION = 12.0
const float GAS_TRAP_ALARM_TIME = 5.0
const float GAS_TRAP_ALARM_INTERVAL = 1.0
const float GAS_TRAP_DAMAGE_TICK = 0.5
const float GAS_TRAP_DETECTION_RADIUS = 140.0
const float GAS_TRAP_RADIUS = 256
const float GAS_TRAP_HEIGHT = 60
const int GAS_TRAP_HEALTH = 150 // was 300, needs nerf!
//const float GAS_TRAP_SLOW_DURATION_PER_TICK = 1.5 // should be damagetick * 3
//const float GAS_TRAP_SLOW_DURATION_LEAVING = 1
// gas settings
const float GAS_SLOWMOVE_DURATION = 2.0
const float GAS_SLOWMOVE_FADEOUT_DURATION = 0.5
const int GAS_MAX_STACKS = 4
const float GAS_STACK_CLEAR_DELAY = 3.0
const int GAS_BASE_DAMAGE = 5
const int GAS_ADDITIONAL_DAMAGE_PER_STACK = 4
const float GAS_SEVERITY_SLOWMOVE = 0.1 
const float GAS_DAMAGE_INTERVAL = 1.0

// molotov, since it has been reduced to 1 charge through StartForcedCooldownThinkForWeapon(), damage can be higher
const float MOLOTOV_IGNITE_DELAY = 0.1
const float MOLOTOV_DAMAGE_TICK_PILOT = 10
const float MOLOTOV_DAMAGE_TICK = 50

//array<entity> inGasPlayers = []

void function MpTitanAbilitySlowTrap_Init()
{
	PrecacheModel( SLOW_TRAP_MODEL )
	PrecacheParticleSystem( SLOW_TRAP_FX_ALL )
	PrecacheParticleSystem( TOXIC_FUMES_FX )
	PrecacheParticleSystem( FIRE_CENTER_FX )
	PrecacheParticleSystem( FIRE_LINES_FX )
	PrecacheParticleSystem( BARREL_EXP_FX )

	if ( GetMapName() == "sp_s2s" )
	{
		PrecacheParticleSystem( TOXIC_FUMES_S2S_FX )
		PrecacheParticleSystem( FIRE_LINES_S2S_FX )
	}


	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanability_slow_trap, FireTrap_DamagedPlayerOrNPC )
		
		// modified
		RegisterSignal( "GasDamaged" )
		RegisterSignal( "GasTrapTriggered" )
		AddDamageCallbackSourceID( eDamageSourceId.molotov, FireTrap_DamagedPlayerOrNPC )
		AddDamageCallbackSourceID( eDamageSourceId.toxic_sludge, GasTrap_DamagedPlayer )
		AddCallback_OnClientConnected( InitPlayerGasStat )
	#endif
}

// for molotovs
void function OnWeaponOwnerChange_titanweapon_slow_trap( entity weapon, WeaponOwnerChangedParams changeParams )
{
#if SERVER
	thread DelayedStartForcedCooldownThink( weapon, ["molotov"] )
#endif
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_slow_trap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_slow_trap( weapon, attackParams )
}
#endif

var function OnWeaponPrimaryAttack_titanweapon_slow_trap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetOwner()
	if ( weaponOwner.IsPlayer() )
	{
		PlayerUsedOffhand( weaponOwner, weapon )
	
		// modified
	#if SERVER
		if( weapon.HasMod( "gas_trap" ) || weapon.HasMod( "molotov" ) ) // pilot ones?
			thread HolsterWeaponForPilotInstants( weapon )
		if( weapon.HasMod( "molotov" ) )
			ForceCleanWeaponAmmo( weapon )
	#endif
	}

	ThrowDeployable( weapon, attackParams, 1500, OnSlowTrapPlanted, <0,0,0> )
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnSlowTrapPlanted( entity projectile )
{
	#if SERVER
		thread DeploySlowTrap( projectile )
	#endif
}

#if SERVER
function DeploySlowTrap( entity projectile )
{
	vector origin = OriginToGround( projectile.GetOrigin() )
	vector angles = projectile.proj.savedAngles
	angles = < angles.x + 90, angles.y, angles.z > // rotate 90 to face up
	entity owner = projectile.GetOwner()
	entity _parent = projectile.GetParent()
	if ( !IsValid( owner ) )
		return

	//array<string> projectileMods = projectile.ProjectileGetMods() // behavior is "absorb", no need to change to Vortex_GetRefiredProjectileMods()
	array<string> projectileMods = Vortex_GetRefiredProjectileMods( projectile ) // all good, refired mods not that bad to use
	bool isExplosiveBarrel = projectileMods.contains( "fd_explosive_barrel" )
	bool isMolotov = projectileMods.contains( "molotov" )
	bool isGasTrap = projectileMods.contains( "gas_trap" )

	owner.EndSignal( "OnDestroy" )
	if ( IsValid( projectile ) )
		projectile.Destroy()

	int team = owner.GetTeam()
	entity tower = CreatePropScript( SLOW_TRAP_MODEL, origin, angles, SOLID_VPHYSICS )
	tower.kv.collisionGroup = TRACE_COLLISION_GROUP_BLOCK_WEAPONS
	//if( isGasTrap )
	//	tower.kv.solid = 2
	if( isGasTrap )
		tower.Solid()
	if( isGasTrap )
	{
		tower.SetMaxHealth( GAS_TRAP_HEALTH )
		tower.SetHealth( GAS_TRAP_HEALTH )
	}
	else
	{
		tower.SetMaxHealth( 100 )
		tower.SetHealth( 100 )
	}
	if( isGasTrap )
		tower.SetTakeDamageType( DAMAGE_YES )
	else
		tower.SetTakeDamageType( DAMAGE_NO )
	if( isGasTrap )
		tower.SetDamageNotifications( true )
	else
		tower.SetDamageNotifications( false )
	tower.SetDeathNotifications( false )
	if( !isGasTrap )
		tower.SetArmorType( ARMOR_TYPE_HEAVY )
	tower.SetTitle( "#WPN_TITAN_SLOW_TRAP" )
	SetTargetName( tower, "#WPN_TITAN_SLOW_TRAP" )
	tower.EndSignal( "OnDestroy" )
	string noSpawnIdx = CreateNoSpawnArea( TEAM_INVALID, team, origin, SLOW_TRAP_BUILD_TIME + SLOW_TRAP_LIFETIME, SLOW_TRAP_RADIUS )
	if( isGasTrap )
	{
		// gas trap use owner to get teams, but it will cause owner not able to damage it
		//tower.s.trapOwner <- owner
		//tower.s.gasTeam <- team // int
		// using this setting, doing a check in base_gametype
		tower.s.takeFriendlyDamage <- true
		SetTeam( tower, team )
		//tower.SetOwner( owner ) // still can't set owner, which will cause tower to have no collision
		tower.SetBossPlayer( owner )
		tower.e.noOwnerFriendlyFire = false
		Highlight_SetFriendlyHighlight( tower, "sp_enemy_pilot" )
		tower.Highlight_SetParam( 1, 0, < 3,3,3 > )
		Highlight_SetOwnedHighlight( tower, "sp_friendly_hero" )
		//Highlight_SetEnemyHighlight( reaper, "enemy_titan" )
	}
	else
		SetTeam( tower, team )
	SetObjectCanBeMeleed( tower, false )
	SetVisibleEntitiesInConeQueriableEnabled( tower, false )
	thread TrapDestroyOnRoundEnd( owner, tower )
	if ( IsValid( _parent ) )
		tower.SetParent( _parent, "", true, 0 )

	//make npc's fire at their own traps to cut off lanes
	if ( owner.IsNPC() )
	{
		owner.SetSecondaryEnemy( tower )
		tower.EnableAttackableByAI( AI_PRIORITY_NO_THREAT, 0, AI_AP_FLAG_NONE )		// don't let other AI target this
	}

	EmitSoundOnEntity( tower, "incendiary_trap_land" )
	if( !isGasTrap )
	{
		EmitSoundOnEntity( tower, "incendiary_trap_gas" )
		PlayLoopFXOnEntity( SLOW_TRAP_FX_ALL, tower, "smoke" )
	}

	if( !isGasTrap )
	{
		if ( GetMapName() != "sp_s2s" )
			CreateToxicFumesFXSpot( origin, tower )
		else
			CreateToxicFumesInWindFX( origin, tower )
	}

	//TODO - HACK : Update to use Vortex Sphere once the Vortex Sphere explosion code feature is done.
	entity damageArea = CreatePropScript( DAMAGE_AREA_MODEL, origin, angles, 0 )
	damageArea.SetOwner( owner )
	if ( owner.IsPlayer() )
		damageArea.SetBossPlayer( owner )
	damageArea.SetMaxHealth( 100 )
	damageArea.SetHealth( 100 )
	damageArea.SetTakeDamageType( DAMAGE_NO )
	damageArea.SetDamageNotifications( false )
	damageArea.SetDeathNotifications( false )
	damageArea.SetArmorType( ARMOR_TYPE_HEAVY )
	damageArea.Hide()
	if ( IsValid( _parent ) )
		damageArea.SetParent( _parent, "", true, 0 )
	damageArea.LinkToEnt( tower )
	if ( isExplosiveBarrel && isMolotov )
		damageArea.SetScriptName( "explosive_molotov" )
	else if( isExplosiveBarrel )
		damageArea.SetScriptName( "explosive_barrel" )
	else if( isMolotov )
		damageArea.SetScriptName( "molotov" )
	SetTeam( damageArea, TEAM_UNASSIGNED )
	SetObjectCanBeMeleed( damageArea, false )
	SetVisibleEntitiesInConeQueriableEnabled( damageArea, false )

	OnThreadEnd(
	function() : ( tower, noSpawnIdx, damageArea )
		{
			DeleteNoSpawnArea( noSpawnIdx )

			if ( IsValid( tower ) )
			{
				foreach ( fx in tower.e.fxArray )
				{
					if ( IsValid( fx ) )
						fx.Destroy()
				}
				tower.Destroy()
			}

			if ( IsValid( damageArea ) )
			{
				//Naturally Timed Out
				EmitSoundAtPosition( TEAM_UNASSIGNED, damageArea.GetOrigin() + <0,0,GAS_FX_HEIGHT>, "incendiary_trap_gas_stop" )
				damageArea.Destroy()
			}
		}
	)

	damageArea.EndSignal( "OnDestroy" )

	if( isGasTrap )
		WaitFrame()
	else if( projectileMods.contains( "molotov" ) )
		wait MOLOTOV_IGNITE_DELAY
	else
		wait SLOW_TRAP_BUILD_TIME
	if( projectileMods.contains( "molotov" ) )
	{
		IgniteTrap( damageArea, null, false )
		tower.Destroy()
		damageArea.Destroy()
	}
	if( isGasTrap )
	{
		//gas trap trigger stuff
		thread GasTrapThink( tower )
		AddEntityCallback_OnDamaged( tower, OnGasTrapDamaged )
	}
	else
	{
		AddEntityCallback_OnDamaged( damageArea, OnSlowTrapDamaged )
		damageArea.SetTakeDamageType( DAMAGE_YES )
	}

	if( isGasTrap )
		wait GAS_TRAP_LIFETIME
	else
		wait SLOW_TRAP_LIFETIME
}

void function OnSlowTrapDamaged( entity damageArea, var damageInfo )
{
	//HACK - Should use damage flags, but we might be capped?
	bool shouldExplode = false
	int damageSourceID = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	switch( damageSourceID )
	{
		//case eDamageSourceId.mp_titanweapon_meteor: Secondary explosions to hit it, not the flying projectile.
		case eDamageSourceId.mp_titanweapon_meteor:
		case eDamageSourceId.mp_titanweapon_meteor_thermite:
		case eDamageSourceId.mp_weapon_thermite_grenade:
		case eDamageSourceId.mp_titancore_flame_wave:
		case eDamageSourceId.mp_titancore_flame_wave_secondary:
		case eDamageSourceId.mp_titanweapon_flame_wall:
		case eDamageSourceId.mp_titanweapon_heat_shield:
		case eDamageSourceId.mp_titanability_slow_trap:
			shouldExplode = true
			break
	}
	if ( shouldExplode )
	{
		bool isExplosiveBarrel = false
		if( damageArea.GetScriptName() == "explosive_barrel" || damageArea.GetScriptName() == "explosive_molotov" )
			isExplosiveBarrel = true
		if ( isExplosiveBarrel )
			CreateExplosiveBarrelExplosion( damageArea )
		IgniteTrap( damageArea, damageInfo, isExplosiveBarrel )
		DamageInfo_SetDamage( damageInfo, 1001 )
	}
	else
	{
		DamageInfo_SetDamage( damageInfo, 0 )
	}
}

function CreateExplosiveBarrelExplosion( entity damageArea )
{
	entity owner = damageArea.GetOwner()
	if ( !IsValid( owner ) )
		return

	Explosion_DamageDefSimple( damagedef_fd_explosive_barrel, damageArea.GetOrigin(),owner, owner, damageArea.GetOrigin() )
}

function IgniteTrap( entity damageArea, var damageInfo, bool isExplosiveBarrel = false )
{
	entity owner = damageArea.GetOwner()
	Assert( IsValid( owner ) )
	if ( !IsValid( owner ) )
		return

	entity weapon

	foreach( entity offhandweapon in owner.GetOffhandWeapons() )
	{
		if ( !IsValid( offhandweapon ) )
			continue
		if ( offhandweapon.GetWeaponClassName() != "mp_titanability_slow_trap"  )
			continue
		if ( offhandweapon.GetWeaponClassName() == "mp_titanability_slow_trap" )
			weapon = offhandweapon
	}

	if( !IsValid( weapon ) ) // player don't have a trap weapon!
		return

	vector originNoHeightAdjust = damageArea.GetOrigin()
	vector origin = originNoHeightAdjust + <0,0,GAS_FX_HEIGHT>
	float range = SLOW_TRAP_RADIUS

	//DebugDrawTrigger( origin, range, 255, 0, 0 )
	if ( isExplosiveBarrel )
	{
		entity initialExplosion = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( BARREL_EXP_FX ), origin, <0,0,0> )
		EntFireByHandle( initialExplosion, "Kill", "", 3.0, null, null )
		EmitSoundAtPosition( TEAM_UNASSIGNED, origin, "incendiary_trap_explode_large" )
	}
	else
	{
		entity initialExplosion = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_CENTER_FX ), origin, <0,0,0> )
		EntFireByHandle( initialExplosion, "Kill", "", 3.0, null, null )
		EmitSoundAtPosition( TEAM_UNASSIGNED, origin, "incendiary_trap_explode" )

	}

	float duration = FLAME_WALL_THERMITE_DURATION
	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE
	entity inflictor = CreateOncePerTickDamageInflictorHelper( duration )
	inflictor.SetOrigin( origin )

	// Increase the radius a bit so AI proactively try to get away before they have a chance at taking damage
	float dangerousAreaRadius = SLOW_TRAP_RADIUS + 50

	array<entity> ignoreArray = damageArea.GetLinkEntArray()
	ignoreArray.append( damageArea )
	entity myParent = damageArea.GetParent()
	entity movingGeo = ( myParent && myParent.HasPusherRootParent() ) ? myParent : null
	if ( movingGeo )
	{
		inflictor.SetParent( movingGeo, "", true, 0 )
		AI_CreateDangerousArea( inflictor, weapon, dangerousAreaRadius, TEAM_INVALID, true, true )
	}
	else
	{
		AI_CreateDangerousArea_Static( inflictor, weapon, dangerousAreaRadius, TEAM_INVALID, true, true, originNoHeightAdjust )
	}

	for ( int i = 0; i < 12; i++ )
	{
		vector trailAngles = < 30 * i, 30 * i, 0 >
		vector forward = AnglesToForward( trailAngles )
		vector startPosition = origin + forward * FIRE_TRAP_MINI_EXPLOSION_RADIUS
		vector direction = forward * 150
		if ( i > 5 )
			direction *= -1
		const float FUSE_TIME = 0.0
		if( !IsValid( weapon ) ) // nessie defensive fix
			return
		entity projectile = weapon.FireWeaponGrenade( origin, <0,0,0>, <0,0,0>, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, PROJECTILE_NOT_PREDICTED, true, true )
		if ( !IsValid( projectile ) )
			continue
		projectile.SetModel( $"models/dev/empty_model.mdl" )
		projectile.SetOrigin( origin )
		projectile.SetVelocity( Vector( 0, 0, 0 ) )
		projectile.StopPhysics()
		projectile.SetTakeDamageType( DAMAGE_NO )
		projectile.Hide()
		projectile.NotSolid()
		projectile.SetProjectilTrailEffectIndex( 1 )
		thread SpawnFireLine( projectile, i, inflictor, origin, direction )
	}
	thread IncendiaryTrapFireSounds( inflictor )

	if ( !movingGeo )
		thread FlameOn( inflictor )
	else
		thread FlameOnMovingGeo( inflictor )
}

void function IncendiaryTrapFireSounds( entity inflictor )
{
	inflictor.EndSignal( "OnDestroy" )

	vector position = inflictor.GetOrigin()
	EmitSoundAtPosition( TEAM_UNASSIGNED, position, "incendiary_trap_burn" )
	OnThreadEnd(
	function() : ( position )
		{
			StopSoundAtPosition( position, "incendiary_trap_burn" )
			EmitSoundAtPosition( TEAM_UNASSIGNED, position, "incendiary_trap_burn_stop" )
		}
	)

	WaitForever()
}

void function FlameOn( entity inflictor )
{
	inflictor.EndSignal( "OnDestroy")

	float intialWaitTime = 0.3
	wait intialWaitTime

	float duration = FLAME_WALL_THERMITE_DURATION
	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE
	foreach( key, pos in inflictor.e.fireTrapEndPositions )
	{
		entity fireLine = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_LINES_FX ), pos, inflictor.GetAngles() )
		EntFireByHandle( fireLine, "Kill", "", duration, null, null )
		EffectSetControlPointVector( fireLine, 1, inflictor.GetOrigin() )
	}
}

void function FlameOnMovingGeo( entity inflictor )
{
	inflictor.EndSignal( "OnDestroy")

	float intialWaitTime = 0.3
	wait intialWaitTime

	float duration = FLAME_WALL_THERMITE_DURATION
	if ( GAMETYPE == GAMEMODE_SP )
		duration *= SP_FLAME_WALL_DURATION_SCALE

	vector angles = inflictor.GetAngles()
	int fxID = GetParticleSystemIndex( FIRE_LINES_FX )
	if ( GetMapName() == "sp_s2s" )
	{
		angles = <0,-90,0> // wind dir
		fxID = GetParticleSystemIndex( FIRE_LINES_S2S_FX )
	}

	foreach( key, relativeDelta in inflictor.e.fireTrapEndPositions )
	{
		if ( ( key in inflictor.e.fireTrapMovingGeo ) )
		{
			entity movingGeo = inflictor.e.fireTrapMovingGeo[ key ]
			if ( !IsValid( movingGeo ) )
				continue
			vector pos = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )

			entity script_mover = CreateScriptMover( pos, angles )
			script_mover.SetParent( movingGeo, "", true, 0 )

			int attachIdx 		= script_mover.LookupAttachment( "REF" )
			entity fireLine 	= StartParticleEffectOnEntity_ReturnEntity( script_mover, fxID, FX_PATTACH_POINT_FOLLOW, attachIdx )

			EntFireByHandle( script_mover, "Kill", "", duration, null, null )
			EntFireByHandle( fireLine, "Kill", "", duration, null, null )
			thread EffectUpdateControlPointVectorOnMovingGeo( fireLine, 1, inflictor )
		}
		else
		{
			entity fireLine = StartParticleEffectInWorld_ReturnEntity( GetParticleSystemIndex( FIRE_LINES_FX ), relativeDelta, inflictor.GetAngles() )
			EntFireByHandle( fireLine, "Kill", "", duration, null, null )
			EffectSetControlPointVector( fireLine, 1, inflictor.GetOrigin() )
		}
	}
}

void function EffectUpdateControlPointVectorOnMovingGeo( entity fireLine, int cpIndex, entity inflictor )
{
	fireLine.EndSignal( "OnDestroy" )
	inflictor.EndSignal( "OnDestroy" )

	while ( 1 )
	{
		EffectSetControlPointVector( fireLine, cpIndex, inflictor.GetOrigin() )
		WaitFrame()
	}
}


void function SpawnFireLine( entity projectile, int projectileCount, entity inflictor, vector origin, vector direction )
{
	if ( !IsValid( projectile ) ) //unclear why this is necessary. We check for validity before creating the thread.
		return

	projectile.EndSignal( "OnDestroy" )
	entity owner = projectile.GetOwner()
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd(
	function() : ( projectile )
		{
			if ( IsValid( projectile ) )
				projectile.Destroy()
		}
	)
	projectile.SetAbsOrigin( origin )
	projectile.SetAbsAngles( direction )
	projectile.proj.savedOrigin = < -999999.0, -999999.0, -999999.0 >

	wait RandomFloatRange( 0.0, 0.1 )

	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, origin, direction, CreateSlowTrapSegment )
}

void function CreateToxicFumesFXSpot( vector origin, entity tower )
{
	int fxID = GetParticleSystemIndex( TOXIC_FUMES_FX )
	int attachID = tower.LookupAttachment( "smoke" )
	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( tower, fxID, FX_PATTACH_POINT_FOLLOW, attachID, <0,0,0>, <0,0,0> )

	tower.e.fxArray.append( particleSystem )
}

void function CreateToxicFumesInWindFX( vector origin, entity tower )
{
	int fxID = GetParticleSystemIndex( TOXIC_FUMES_S2S_FX )
	int attachID = tower.LookupAttachment( "smoke" )

	entity particleSystem = StartParticleEffectOnEntityWithPos_ReturnEntity( tower, fxID, FX_PATTACH_POINT_FOLLOW_NOROTATE, attachID, <0,0,0>, <0,90,0> )

	tower.e.fxArray.append( particleSystem )
}

bool function CreateSlowTrapSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )
	//array<string> mods = projectile.ProjectileGetMods() // behavior is "absorb", no need to change to Vortex_GetRefiredProjectileMods()
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // all good, refired mods not that bad to use
	bool isMolotov = mods.contains( "molotov" )
	entity owner = projectile.GetOwner()

	if ( projectile.proj.savedOrigin != < -999999.0, -999999.0, -999999.0 > )
	{
		float duration = FLAME_WALL_THERMITE_DURATION

		if ( GAMETYPE == GAMEMODE_SP )
			duration *= SP_FLAME_WALL_DURATION_SCALE

		if ( !movingGeo )
		{
			if ( projectileCount in inflictor.e.fireTrapEndPositions )
				inflictor.e.fireTrapEndPositions[projectileCount] = pos
			else
				inflictor.e.fireTrapEndPositions[projectileCount] <- pos

			thread FireTrap_DamageAreaOverTime( owner, inflictor, pos, duration, isMolotov )
		}
		else
		{
			vector relativeDelta = GetRelativeDelta( pos, movingGeo )

			if ( projectileCount in inflictor.e.fireTrapEndPositions )
				inflictor.e.fireTrapEndPositions[projectileCount] = relativeDelta
			else
				inflictor.e.fireTrapEndPositions[projectileCount] <- relativeDelta

			if ( projectileCount in inflictor.e.fireTrapMovingGeo )
				inflictor.e.fireTrapMovingGeo[projectileCount] = movingGeo
			else
				inflictor.e.fireTrapMovingGeo[projectileCount] <- movingGeo

			thread FireTrap_DamageAreaOverTimeOnMovingGeo( owner, inflictor, movingGeo, relativeDelta, duration, isMolotov )
		}

	}

	projectile.proj.savedOrigin = pos
	return true
}

void function FireTrap_DamageAreaOverTime( entity owner, entity inflictor, vector pos, float duration, bool isMolotov = false )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )
	float endTime = Time() + duration
	while ( Time() < endTime )
	{
		if( isMolotov )
			Molotov_RadiusDamage( pos, owner, inflictor )
		else
			FireTrap_RadiusDamage( pos, owner, inflictor )
		//FireTrap_RadiusDamage( pos, owner, inflictor )
		wait 0.2
	}
}

void function FireTrap_DamageAreaOverTimeOnMovingGeo( entity owner, entity inflictor, entity movingGeo, vector relativeDelta, float duration, bool isMolotov = false )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )
	movingGeo.EndSignal( "OnDestroy" )
	inflictor.EndSignal( "OnDestroy" )

	float endTime = Time() + duration
	while ( Time() < endTime )
	{
		vector pos = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )
		if( isMolotov )
			Molotov_RadiusDamage( pos, owner, inflictor )
		else
			FireTrap_RadiusDamage( pos, owner, inflictor )
		//FireTrap_RadiusDamage( pos, owner, inflictor )
		wait 0.2
	}
}

void function FireTrap_RadiusDamage( vector pos, entity owner, entity inflictor )
{
	MeteorRadiusDamage meteorRadiusDamage = GetMeteorRadiusDamage( owner )
	float METEOR_DAMAGE_TICK_PILOT = meteorRadiusDamage.pilotDamage
	float METEOR_DAMAGE_TICK = meteorRadiusDamage.heavyArmorDamage

	RadiusDamage(
		pos,												// origin
		owner,												// owner
		inflictor,		 									// inflictor
		METEOR_DAMAGE_TICK_PILOT,							// pilot damage
		METEOR_DAMAGE_TICK,									// heavy armor damage
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// inner radius
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
		0, 													// distanceFromAttacker
		0, 													// explosionForce
		DF_EXPLOSION,										// damage flags
		eDamageSourceId.mp_titanability_slow_trap			// damage source id
	)
}

void function Molotov_RadiusDamage( vector pos, entity owner, entity inflictor )
{
	RadiusDamage(
		pos,												// origin
		owner,												// owner
		inflictor,		 									// inflictor
		MOLOTOV_DAMAGE_TICK_PILOT,							// pilot damage
		MOLOTOV_DAMAGE_TICK,									// heavy armor damage
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// inner radius
		FIRE_TRAP_MINI_EXPLOSION_RADIUS,					// outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
		0, 													// distanceFromAttacker
		0, 													// explosionForce
		DF_EXPLOSION,										// damage flags
		eDamageSourceId.molotov			// damage source id
	)
}

void function FireTrap_DamagedPlayerOrNPC( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return

	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_DOOMED_HEALTH_LOSS )
		return

	Thermite_DamagePlayerOrNPCSounds( ent )

	float originDistance2D = Distance2D( inflictor.GetOrigin(), DamageInfo_GetDamagePosition( damageInfo ) )
	if ( originDistance2D > SLOW_TRAP_RADIUS )
		DamageInfo_SetDamage( damageInfo, 0 )
	else
		Scorch_SelfDamageReduction( ent, damageInfo )

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	// adding friendlyfire support!
	//if ( !IsValid( attacker ) || attacker.GetTeam() == ent.GetTeam() )
	if ( !IsValid( attacker ) || ( attacker.GetTeam() == ent.GetTeam() && !FriendlyFire_IsEnabled() ) )
		return

	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() > 0 )
	{
		if ( weapons[0].HasMod( "fd_fire_damage_upgrade" )  )
			DamageInfo_ScaleDamage( damageInfo, FD_FIRE_DAMAGE_SCALE )
		if ( weapons[0].HasMod( "fd_hot_streak" ) )
			UpdateScorchHotStreakCoreMeter( attacker, DamageInfo_GetDamage( damageInfo ) )
	}
}
#endif

//	TODO:
//	Reassign damage to person who triggers the trap for FF reasons.

// gas_trap
#if SERVER
void function GasTrapThink( entity tower )
{
	tower.EndSignal( "OnDestroy" )

	tower.s.gasTrapTriggered <- false
	//entity trapOwner = expect entity( tower.s.trapOwner )//tower.GetOwner()
	entity trapOwner = tower.GetBossPlayer()
	float startTime = Time()
	float progressTime

	OnThreadEnd(
		function() : ( tower )
		{
			if ( IsValid( tower ) )
				tower.Destroy()
		}
	)
	wait GAS_TRAP_BUILD_TIME

	// Wait for someone to trigger the trap
	thread GasTrapTriggerThink( tower, trapOwner )

	tower.WaitSignal( "GasTrapTriggered" )
	tower.s.gasTrapTriggered = true
	waitthread GasTrapToxicThink( tower )


	/*
	while( true )
	{
		foreach( entity player in inGasPlayers )
		{
			if( IsValid(player) )
			{
				GiveGasStatusEffects( player, trapOwner )
			}
		}
		wait GAS_TRAP_DAMAGE_TICK
		progressTime = Time()
		if( progressTime - startTime >= GAS_TRAP_LIFETIME )
			break
		if( !IsValid( tower ) )
			break
	}
	*/

	//foreach( entity player in GetPlayerArray() )
	//	SetDefaultMPEnemyHighlight( player )
}

void function GasTrapToxicThink( entity tower )
{
	tower.EndSignal( "OnDestroy" )
	//entity owner = expect entity( tower.s.trapOwner )
	entity owner = tower.GetBossPlayer()
	owner.EndSignal( "OnDestroy" )

	EmitSoundOnEntity( tower, "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
	EmitSoundOnEntity( tower, "incendiary_trap_gas" )
	PlayLoopFXOnEntity( SLOW_TRAP_FX_ALL, tower, "smoke" )
	// highlight for friendly and owner
	tower.Highlight_SetParam( 1, 0, < 1,3,0 > ) // friendly
	tower.Highlight_SetParam( 3, 0, < 0,1,0 > ) // owner

	//if ( GetMapName() != "sp_s2s" ) // needs test to select a better one
		CreateToxicFumesFXSpot( tower.GetOrigin(), tower )
	//else
	//	CreateToxicFumesInWindFX( origin, tower )

	entity trigger = CreateTriggerRadiusMultiple( tower.GetOrigin(), GAS_TRAP_RADIUS, [], TRIG_FLAG_START_DISABLED | TRIG_FLAG_NO_PHASE_SHIFT, GAS_TRAP_RADIUS * 0.1, GAS_TRAP_RADIUS * 0.1 )
	//SetTeam( trigger, tower.GetTeam() )
	//trigger.SetOwner( tower.GetOwner() )

	AddCallback_ScriptTriggerEnter( trigger, OnGasTrapTriggerEnter )
	AddCallback_ScriptTriggerLeave( trigger, OnGasTrapTriggerLeave )

	ScriptTriggerSetEnabled( trigger, true )

	OnThreadEnd(
		function(): ( trigger )
		{
			if( IsValid(trigger) )
				trigger.Destroy()
		}
	)

	float startTime = Time()
	float alarmStartTime = GAS_TRAP_TOXIC_DURATION - GAS_TRAP_ALARM_TIME
	float lastAlarmedTime = Time()
	while( startTime + GAS_TRAP_TOXIC_DURATION > Time() )
	{
		RadiusDamage(
			tower.GetOrigin(),									// origin
			owner,												// owner
			tower,		 										// inflictor
			GAS_BASE_DAMAGE,									// pilot damage, for gas trap is now decided here
			0,													// heavy armor damage
			GAS_TRAP_RADIUS,									// inner radius
			GAS_TRAP_RADIUS,									// outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
			0, 													// distanceFromAttacker
			0, 													// explosionForce
			DF_BYPASS_SHIELD,									// damage flags
			eDamageSourceId.toxic_sludge						// damage source id
		)

		if( Time() > startTime + alarmStartTime )
		{
			if( Time() - lastAlarmedTime >= GAS_TRAP_ALARM_INTERVAL )
			{
				EmitSoundOnEntity( tower, "Weapon_ProximityMine_ArmedBeep" )
				lastAlarmedTime = Time()
			}
		}
		WaitFrame()
	}
}

void function GasTrapTriggerThink( entity tower, entity owner )
{
	tower.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDestroy" )
	tower.EndSignal( "GasTrapTriggered" )

	float triggerRadius = GAS_TRAP_DETECTION_RADIUS
	float PlayerTickRate = 0.2
	int teamNum = owner.GetTeam()

	while( IsValid( tower ) && IsValid( owner ) )
	{
		wait PlayerTickRate // do a wait first, defensive fix
		array<entity> nearbyPlayers = GetPlayerArrayEx( "any", TEAM_ANY, teamNum, tower.GetOrigin() + < 0,0,30 >, triggerRadius )
		foreach( ent in nearbyPlayers )
		{
			if ( ShouldSetOffGasTrap( tower, ent ) )
			{
				tower.Signal( "GasTrapTriggered" )
				break
			}
		}
	}
}

bool function ShouldSetOffGasTrap( entity tower, entity ent )
{
	if ( !IsAlive( ent ) )
		return false

	if ( ent.IsPhaseShifted() )
		return false

	TraceResults results = TraceLine( tower.GetOrigin(), ent.EyePosition(), tower, (TRACE_MASK_SHOT | CONTENTS_BLOCKLOS), TRACE_COLLISION_GROUP_NONE )
	if ( results.fraction >= 1 || results.hitEnt == ent )
		return true

	return false
}

void function OnGasTrapTriggerEnter( entity trigger, entity ent )
{
	if( !ent.IsPlayer() )
		return

	//if ( !IsEnemyTeam( trigger.GetTeam(), ent.GetTeam() ) )
	//	return

	ScreenFade( ent, 100, 155, 0, 15, 0.1, GAS_TRAP_TOXIC_DURATION + GAS_SLOWMOVE_DURATION, FFADE_OUT | FFADE_PURGE )
	//if( !inGasPlayers.contains( ent ) )
	//	inGasPlayers.append( ent )
}

void function OnGasTrapTriggerLeave( entity trigger, entity ent )
{
	if( !ent.IsPlayer() )
		return

	ScreenFadeFromColor( ent, 100, 155, 0, 15, 0.1, GAS_SLOWMOVE_DURATION )

	//if ( !IsEnemyTeam( trigger.GetTeam(), ent.GetTeam() ) )
	//	return

	//if( IsValid( trigger ) )
	//	GiveGasStatusEffects_Leaving( ent, trigger.GetOwner() )
	//ScreenFadeFromColor( ent, 100, 155, 0, 15, 0.1, GAS_TRAP_SLOW_DURATION_LEAVING-0.1 )
	//if( inGasPlayers.contains( ent ) )
	//	inGasPlayers.fastremovebyvalue( ent )
}

/*
void function GiveGasStatusEffects( entity ent, entity trapOwner, float duration = GAS_TRAP_SLOW_DURATION_PER_TICK, float fadeoutDuration = 0.5, float slowMove = GAS_SEVERITY_SLOWMOVE )
{
	if( !IsValid(ent) )
		return
	if( !ent.IsTitan() )
	{
		Highlight_SetEnemyHighlight( ent, "health_pickup" )
		StatusEffect_AddTimed( ent, eStatusEffect.move_slow, slowMove, duration, fadeoutDuration )
		ent.TakeDamage( ent.GetMaxHealth() * GAS_TRAP_DAMAGE_PERCENTAGE, trapOwner, trapOwner, { damageSourceId = eDamageSourceId.toxic_sludge } )
	}
}
  
void function GiveGasStatusEffects_Leaving( entity ent, entity trapOwner, float duration = GAS_TRAP_SLOW_DURATION_LEAVING, float fadeoutDuration = 0.5, float slowMove = GAS_SEVERITY_SLOWMOVE )
{
	if( !IsValid(ent) )
		return
	if( !ent.IsTitan() )
	{
		SetDefaultMPEnemyHighlight( ent )
		StatusEffect_AddTimed( ent, eStatusEffect.move_slow, slowMove, duration, fadeoutDuration )
		ent.TakeDamage( ent.GetHealth() * GAS_TRAP_DAMAGE_PERCENTAGE, trapOwner, trapOwner, { damageSourceId = eDamageSourceId.toxic_sludge } )
	}
}
*/

void function GasTrap_DamagedPlayer( entity victim, var damageInfo )
{
	if( !victim.IsPlayer() || victim.IsTitan() )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if( IsValid( attacker ) )
	{
		if( victim.GetTeam() == attacker.GetTeam() )
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			return
		}
	}
	if( victim.s.lastGasDamagedTime + GAS_DAMAGE_INTERVAL > Time() )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
	vector damageOrigin = DamageInfo_GetDamagePosition( damageInfo )
	if( fabs( damageOrigin.z - victim.GetOrigin().z ) > GAS_TRAP_HEIGHT ) // prevent damage players above
	{
		//print( "player's z is far away from trap!" )
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	victim.s.lastGasDamagedTime = Time()
	victim.Signal( "GasDamaged" )
	thread PlayerGasStackThink( victim )

	// deal damage and apply effect
	StatusEffect_AddTimed( victim, eStatusEffect.move_slow, GAS_SEVERITY_SLOWMOVE, GAS_SLOWMOVE_DURATION, GAS_SLOWMOVE_FADEOUT_DURATION )
	DamageInfo_SetDamage( damageInfo, GAS_BASE_DAMAGE + expect int( victim.s.gasStack ) * GAS_ADDITIONAL_DAMAGE_PER_STACK )
	EmitSoundOnEntityOnlyToPlayer( victim, victim, ELECTRIC_SMOKE_GRENADE_SFX_DAMAGE_PILOT_1P )
	EmitSoundOnEntityExceptToPlayer( victim, victim, ELECTRIC_SMOKE_GRENADE_SFX_DAMAGE_PILOT_3P )
	//print( victim.s.gasStack )
}

void function InitPlayerGasStat( entity player )
{
	player.s.gasStack <- 0 // int
	player.s.lastGasDamagedTime <- 0 // float
}

void function PlayerGasStackThink( entity player )
{
	player.EndSignal( "GasDamaged" ) // end last thread
	player.EndSignal( "OnDestroy" )
	if( expect int( player.s.gasStack ) < GAS_MAX_STACKS )
		player.s.gasStack += 1
	else
		player.s.gasStack = GAS_MAX_STACKS

	wait GAS_STACK_CLEAR_DELAY
	player.s.gasStack = 0
}

void function OnGasTrapDamaged( entity tower, var damageInfo )
{
	if( !IsValid( tower ) )
		return
	int damageSourceId = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	if( damageSourceId == eDamageSourceId.toxic_sludge )
		return
	//entity owner = expect entity( tower.s.trapOwner )
	entity owner = tower.GetBossPlayer()
	int ownerTeam = TEAM_UNASSIGNED
	if( IsValid( owner ) )
		ownerTeam = owner.GetTeam()
	entity attacker = DamageInfo_GetAttacker( damageInfo )
    if ( attacker.IsPlayer() )
	{
		if( attacker.GetTeam() == ownerTeam )
			DamageInfo_SetDamage( damageInfo, 0 )
		else
        	attacker.NotifyDidDamage( tower, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamagePosition( damageInfo ), DamageInfo_GetCustomDamageType( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageFlags( damageInfo ), DamageInfo_GetHitGroup( damageInfo ), DamageInfo_GetWeapon( damageInfo ), DamageInfo_GetDistFromAttackOrigin( damageInfo ) )
		if( !( expect bool( tower.s.gasTrapTriggered ) ) )
			tower.Signal( "GasTrapTriggered" )
	}
}   
#endif
