untyped

global function OnWeaponActivate_weapon_softball // unused
global function OnWeaponOwnerChanged_weapon_softball // for stickybomb signal

global function OnWeaponPrimaryAttack_weapon_softball
global function OnProjectileCollision_weapon_softball

global function OnWeaponReload_weapon_softball
#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_softball

global table < string, array<entity> > playerStickyTable = {}
#endif // #if SERVER

const FUSE_TIME = 0.5 //Applies once the grenade has stuck to a surface.
const STICKY_ARM_DELAY = 0.7
const STICKY_EXPLOSION_DELAY = 0.13

// moved to mp_weapon_modded_softball for sometimes we use ".AddMod()"
void function OnWeaponActivate_weapon_softball( entity weapon )
{
#if SERVER
	if( !weapon.HasMod( "stickybomb_launcher" ) )
		return
	entity owner = weapon.GetWeaponOwner()
	if( !owner.IsPlayer() )
		return
	if( !( owner.GetUID() in playerStickyTable ) ) // we should initialize
		playerStickyTable[owner.GetUID()] <- []
#endif
}

void function OnWeaponOwnerChanged_weapon_softball( entity weapon, WeaponOwnerChangedParams changeParams )
{
#if SERVER
	if( weapon.HasMod( "stickybomb_launcher" ) )
	{
		if( IsValid( changeParams.oldOwner ) )
		{
			if( changeParams.oldOwner.IsPlayer() )
			{
				RemoveButtonPressedPlayerInputCallback( changeParams.oldOwner, IN_ZOOM, SignalDetonateSticky )
				RemoveButtonPressedPlayerInputCallback( changeParams.oldOwner, IN_ZOOM_TOGGLE, SignalDetonateSticky )
			}
		}
	}
	thread DelayedCheckStickyBombMod( weapon, changeParams ) // in case we're using AddMod()
#endif
}

#if SERVER
void function DelayedCheckStickyBombMod( entity weapon, WeaponOwnerChangedParams changeParams )
{
	WaitFrame()
	if( !IsValid( weapon ) )
		return
	if( weapon.HasMod( "stickybomb_launcher" ) )
	{
		if ( IsValid( changeParams.newOwner ) )
		{
			entity player
			if( changeParams.newOwner.IsPlayer() )
				player = changeParams.newOwner
			if( !IsValid( player ) )
				return
			AddButtonPressedPlayerInputCallback( player, IN_ZOOM, SignalDetonateSticky )
			AddButtonPressedPlayerInputCallback( player, IN_ZOOM_TOGGLE, SignalDetonateSticky )
		}
	}
}
#endif

var function OnWeaponPrimaryAttack_weapon_softball( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
	{
		vector offset = Vector( 30.0, 6.0, -4.0 )
		if ( weapon.IsWeaponInAds() )
			offset = Vector( 30.0, 0.0, -3.0 )
		vector attackPos = player.OffsetPositionFromView( attackParams[ "pos" ], offset )	// forward, right, up
		
		//Triple Threat ammo
		if( weapon.HasMod( "triplethreat_softball" ) )
		{
			#if SERVER
			return FireTripleThreat_Softball( weapon, attackParams, true )
			#endif
		}
		else
			FireGrenade( weapon, attackParams )
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_softball( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	if( weapon.HasMod( "triplethreat_softball" ) )
		return FireTripleThreat_Softball( weapon, attackParams, false )
	else
		FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION // | DF_GIB

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )
	entity owner = weapon.GetWeaponOwner()

	asset fxAsset = weapon.GetWeaponSettingAsset( eWeaponVar.projectile_trail_effect_0 )
	float explosionDelay = weapon.GetWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
	asset impactEffect = weapon.GetWeaponSettingAsset( eWeaponVar.impact_effect_table )
    string tempString = string( impactEffect )
    string impactFXName = tempString.slice( 2, tempString.len() - 1 )

	if ( nade )
	{
		InitSoftballGrenade( nade, weapon, owner, fxAsset, explosionDelay, impactFXName )
	}
}

void function InitSoftballGrenade( entity nade, entity weapon, entity owner, asset fxAsset, float explosionDelay, string impactFXName )
{
	#if SERVER
		Grenade_Init( nade, weapon )
		thread DelayedStartParticleSystem( nade, fxAsset )
	#else
		entity weaponOwner = weapon.GetWeaponOwner()
		SetTeam( nade, weaponOwner.GetTeam() )
	#endif
	if( weapon.HasMod( "sonar_softball" ) )
		nade.SetModel( $"models/weapons/kunai/w_kunai_projectile.mdl" )
	else if( weapon.HasMod( "thermite_softball" ) )
		nade.SetModel( $"models/weapons/shuriken/w_shuriken.mdl" )
	else if( weapon.HasMod( "northstar_softball" ) )
		nade.SetModel( $"models/titans/light/titan_light_raptor.mdl" )
	else if( weapon.HasMod( "cluster_softball" ) )
		nade.SetModel( $"models/weapons/bullets/projectile_rocket_largest.mdl" )
	else if( weapon.HasMod( "arcball_softball" ) )
	{
		nade.SetModel( $"models/dev/empty_model.mdl" )
	#if SERVER
		AttachBallLightning( weapon, nade ) // this will make grenade a arcball
	#endif // SERVER
	}
	else if( weapon.HasMod( "smoke_softball" ) )
		nade.SetModel( $"models/weapons/grenades/smoke_grenade_projectile.mdl" )
	else if( weapon.HasMod( "gravity_softball" ) )
		nade.SetModel( $"models/weapons/shuriken/w_shuriken.mdl" )
	else if( weapon.HasMod( "emp_softball" ) )
		nade.SetModel( $"models/weapons/grenades/arc_grenade_projectile.mdl" )
	else if( weapon.HasMod( "error_softball" ) )
		nade.SetModel( $"models/error.mdl" )
	else if( weapon.HasMod( "grenade_launcher" ) )
	{
	#if SERVER
		thread DetonateGrenadeAfterTime( nade, explosionDelay, impactFXName )
	#endif
	}
	else if( weapon.HasMod( "stickybomb_launcher" ) )
	{
	#if SERVER
		nade.proj.onlyAllowSmartPistolDamage = false
		thread DelayedAddStickyForPlayer( owner, nade )
		thread PlayerStickyManagement( owner )
	#endif
	}
	else
	{
		EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
	}
	
}

void function OnProjectileCollision_weapon_softball( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()

#if SERVER
	//Prevent triplethreat from being sticky and triggers it's unique impact
	if( mods.contains( "triplethreat_softball" ) )
		return OnProjectileCollision_titanweapon_triple_threat( projectile, pos, normal, hitEnt, hitbox, isCritical )
	//Prevent demoman grenade from being sticky
	if( mods.contains( "grenade_launcher" ) )
	{
		projectile.proj.savedOrigin = normal
		// no impact fuse after bounce
		if( projectile.proj.projectileBounceCount++ != 0 )
			return
		if( hitEnt.IsPlayer() || hitEnt.IsNPC() )
			projectile.Signal( "DetonateGrenade" )
		projectile.proj.projectileBounceCount++
		return
	}
	//Prevent stickybomb from sticking on players
	else if( mods.contains( "stickybomb_launcher" ) )
	{
		if( hitEnt.IsPlayer() || hitEnt.IsNPC() )
			return
	} 
#endif
		
	bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
	if ( !didStick )
		return

	#if SERVER
	entity player = projectile.GetOwner()

	if ( IsAlive( hitEnt ) && hitEnt.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
		EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
	}
	else
	{
		EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
	}

	//Thermite ammo
	if( mods.contains( "thermite_softball" ) )
	{
		thread ThermiteBurn_Softball( 2.0, player, projectile )
	}
	//Sonar ammo
	else if( mods.contains( "sonar_softball" ) )
	{
		thread SonarGrenadeThink_Softball( projectile )
		thread DestroySoftballProjectile( projectile, 1.0 )
	}
	//Northstar ammo
	else if( mods.contains( "northstar_softball" ) )
	{
		thread NuclearCoreExplosionChainReaction_Softball( projectile, 0 )
	}
	//Cluster ammo
	else if( mods.contains( "cluster_softball" ) )
	{
		ClusterRocket_Detonate_Softball( projectile, normal )
		projectile.GrenadeExplode( normal )
	}
	//Arcball ammo
	else if( mods.contains( "arcball_softball" ) )
	{
		thread DetonateStickyAfterTime( projectile, 0.0, normal )
	}
	//Smoke ammo
	else if( mods.contains( "smoke_softball" ) )
	{
		ElectricGrenadeSmokescreen_Softball( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )
		thread DestroySoftballProjectile( projectile, 4.0)
	}
	//Gravity ammo
	else if( mods.contains( "gravity_softball" ) )
	{
		thread GravityGrenadeThink_Softball( projectile, hitEnt, normal, pos )
	}
	//Emp Grenade ammo
	else if( mods.contains( "emp_softball" ))
	{
		thread DetonateStickyAfterTime( projectile, 0.75, normal )
	}
	//Random ammo
	else if( mods.contains( "error_softball" ) )
	{
		DetonateRandomGrenade( projectile, pos, normal, hitEnt, hitbox, isCritical )
	}
	// StickyBomb ammo
	else if( mods.contains( "stickybomb_launcher" ) )
	{
		thread TrapDestroyOnDamage( projectile )
		projectile.proj.savedOrigin = normal
	}
	//Default ammo
	else
	{
		thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
	}
	#endif
}

void function DetonateRandomGrenade( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
	entity player = projectile.GetOwner()
	switch( RandomInt(5) )
	{
		case 0:
			thread ThermiteBurn_Softball( 2.0, player, projectile )
			return
		case 1:
			thread SonarGrenadeThink_Softball( projectile )
			thread DestroySoftballProjectile( projectile, 6.0 )
			return
		case 2:
			ElectricGrenadeSmokescreen_Softball( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )
			thread DestroySoftballProjectile( projectile, 4.0 )
			return
		case 3:
			ClusterRocket_Detonate_Softball( projectile, normal )
			projectile.GrenadeExplode( normal )
			return
		case 4:
			thread NuclearCoreExplosionChainReaction_Softball( projectile, 3.0, 7, 1.4 )
			return
		//case 5:
		//	thread GravityGrenadeThink_Softball( projectile, hitEnt, normal, pos )
		//	return
		default:
			return
	}
	#endif
}

void function OnWeaponReload_weapon_softball( entity weapon, int milestoneIndex )
{
	if( !weapon.HasMod( "reload_repeat" ) )
		return
#if SERVER
	// softball only have one milestone, maybe impossible to use this to fix
	//print( "current milestoneIndex is: " + string( milestoneIndex ) )
	entity owner = weapon.GetWeaponOwner()
    vector pos = owner.EyePosition()
    vector dir = owner.GetViewVector()
    vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )
    int damageType = weapon.GetWeaponDamageFlags()

	entity nade = weapon.FireWeaponGrenade( pos, dir, angularVelocity, 0.0, damageType, damageType, false, true, true )

	asset fxAsset = weapon.GetWeaponSettingAsset( eWeaponVar.projectile_trail_effect_0 )
	float explosionDelay = weapon.GetWeaponSettingFloat( eWeaponVar.grenade_fuse_time )
	asset impactEffect = weapon.GetWeaponSettingAsset( eWeaponVar.impact_effect_table )
    string tempString = string( impactEffect )
    string impactFXName = tempString.slice( 2, tempString.len() - 1 )

	if ( nade )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Weapon_Softball_Fire_1P" )
        EmitSoundOnEntity( owner, "Weapon_Softball_Fire_3P" )
		InitSoftballGrenade( nade, weapon, owner, fxAsset, explosionDelay, impactFXName )
	}
#endif
}

#if SERVER
// need this so grenade can use the normal to explode
void function DetonateStickyAfterTime( entity projectile, float delay, vector normal )
{
	wait delay
	if ( IsValid( projectile ) )
		projectile.GrenadeExplode( normal )
}

void function DestroySoftballProjectile( entity projectile, float duration )
{
	wait duration
	if ( IsValid( projectile ) )
		projectile.Destroy()
}

void function DetonateGrenadeAfterTime( entity projectile, float delay, string impactFXName )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.EndSignal( "DetonateGrenade" )
	// for better client visual
	float startTime = Time()
	OnThreadEnd(
		function() : ( projectile, impactFXName, startTime )
		{
			if( IsValid( projectile ) )
			{
				projectile.GrenadeExplode( projectile.proj.savedOrigin )
				if( Time() - startTime <= 0.3 ) // not making it too loud, just server-forced prediction
					PlayImpactFXTable( projectile.GetOrigin() + projectile.proj.savedOrigin, projectile, impactFXName, SF_ENVEXPLOSION_INCLUDE_ENTITIES )
			}
		}
	)
	wait delay
}

void function DelayedAddStickyForPlayer( entity player, entity projectile )
{
	string uid = player.GetUID()
	wait STICKY_ARM_DELAY
	if( !IsAlive( player ) )
	{
		if( IsValid( projectile ) )
			projectile.Destroy()
		return
	}
	if( IsValid( projectile ) )
		playerStickyTable[uid].append( projectile )
}

void function PlayerStickyManagement( entity player )
{
	string uid = player.GetUID()
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "PlayerClassChanged" )

	OnThreadEnd(
		function() : ( uid )
		{
			array<entity> stickyBombs = playerStickyTable[uid]
			foreach( entity stickyBomb in stickyBombs )
			{
				if( IsValid( stickyBomb ) )
					stickyBomb.Destroy()
			}
			playerStickyTable[uid].clear()
		}
	)
	
	wait STICKY_ARM_DELAY
	player.WaitSignal( "DetonateSticky" )
	waitthread EmitStickyActivateSound( player )
	array<entity> stickyBombs = playerStickyTable[uid]
	foreach( entity stickyBomb in stickyBombs )
	{
		if( IsValid( stickyBomb ) )
			stickyBomb.GrenadeExplode( stickyBomb.proj.savedOrigin )
	}
	playerStickyTable[uid].clear()
}

void function EmitStickyActivateSound( entity player )
{
	array<entity> stickyBombs = playerStickyTable[player.GetUID()]
	foreach( entity stickyBomb in stickyBombs )
	{
		if( IsValid( stickyBomb ) )
			EmitSoundOnEntity( stickyBomb, "Weapon_R1_Satchel.ArmedBeep" )
	}
	wait STICKY_EXPLOSION_DELAY
}

void function TrapDestroyOnDamage( entity trapEnt )
{
	EndSignal( trapEnt, "OnDestroy" )

	trapEnt.SetDamageNotifications( true )

	var results
	entity attacker
	entity inflictor

	while ( true )
	{
		if ( !IsValid( trapEnt ) )
			return

		results = WaitSignal( trapEnt, "OnDamaged" )
		attacker = expect entity( results.activator )
		inflictor = expect entity( results.inflictor )

		if ( IsValid( inflictor ) && inflictor == trapEnt )
			continue

		bool shouldDamageTrap = false
		if ( IsValid( attacker ) )
		{
			if ( trapEnt.GetTeam() == attacker.GetTeam() )
			{
				shouldDamageTrap = false
			}
			else
			{
				shouldDamageTrap = true
			}
		}

		if ( shouldDamageTrap )
			break
	}

	if ( !IsValid( trapEnt ) )
		return

	trapEnt.Destroy()
}

void function DelayedStartParticleSystem( entity projectile, asset fxAsset )
{
    WaitFrame()
    if( IsValid( projectile ) )
        StartParticleEffectOnEntity( projectile, GetParticleSystemIndex( fxAsset ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
}
#endif