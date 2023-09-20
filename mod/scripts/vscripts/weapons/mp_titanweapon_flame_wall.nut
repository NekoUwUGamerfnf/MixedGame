global function MpTitanweaponFlameWall_Init

global function OnWeaponPrimaryAttack_FlameWall
global function OnProjectileCollision_FlameWall
global function OnWeaponActivate_titancore_flame_wall

#if SERVER
global function OnWeaponNpcPrimaryAttack_FlameWall
global function BeginFlameWave // modified to globalize it
global function CreateThermiteWallSegment
#endif

const asset FLAME_WALL_FX = $"P_wpn_meteor_wall"
const asset FLAME_WALL_FX_S2S = $"P_wpn_meteor_wall_s2s"
const asset FLAME_WALL_CHARGED_ADD_FX = $"impact_exp_burst_FRAG_2"

const string FLAME_WALL_PROJECTILE_SFX = "flamewall_flame_start"
const string FLAME_WALL_GROUND_SFX = "Explo_ThermiteGrenade_Impact_3P"
const string FLAME_WALL_GROUND_BEGINNING_SFX = "flamewall_flame_burn_front"
const string FLAME_WALL_GROUND_MIDDLE_SFX = "flamewall_flame_burn_middle"
const string FLAME_WALL_GROUND_END_SFX = "flamewall_flame_burn_end"

global const float FLAME_WALL_THERMITE_DURATION = 5.2
global const float PAS_SCORCH_FIREWALL_DURATION = 5.2
global const float SP_FLAME_WALL_DURATION_SCALE = 1.75

void function MpTitanweaponFlameWall_Init()
{
	PrecacheParticleSystem( FLAME_WALL_FX )
	PrecacheParticleSystem( FLAME_WALL_CHARGED_ADD_FX )

	if ( GetMapName() == "sp_s2s" )
	{
		PrecacheParticleSystem( FLAME_WALL_FX_S2S )
	}

	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_flame_wall, FlameWall_DamagedTarget )
	#endif
}

void function OnWeaponActivate_titancore_flame_wall( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "stryder_fire_wave" ) )
		return OnWeaponActivate_titanweapon_fire_wave( weapon )
	
	// vanilla behavior
	weapon.EmitWeaponSound_1p3p( "flamewall_start_1p", "flamewall_start_3p" )

	// fix for atlas npc titan usage
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if ( owner.IsNPC() )
		{
			// shared from special_3p_attack_anim_fix.gnut
			// fix atlas chassis animation
			HandleSpecial3pAttackAnim( owner, weapon, 0.5, OnWeaponPrimaryAttack_FlameWall )
		}
	#endif
}

var function OnWeaponPrimaryAttack_FlameWall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "wrecking_ball" ) )
		return OnWeaponPrimaryAttack_weapon_wrecking_ball( weapon, attackParams )
	if ( weapon.HasMod( "stryder_fire_wave" ) )
		return OnWeaponPrimaryAttack_titanweapon_fire_wave( weapon, attackParams )

	// vanilla behavior
	entity weaponOwner = weapon.GetOwner()
		
	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	// float missileSpeed = 1200.0
	// bool doPopup = false
	// entity grenade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir * missileSpeed, < 200,0,0 >, 99, damageTypes.projectileImpact, damageTypes.explosive, shouldPredict, true, true )
	// vector angles = VectorToAngles( attackParams.dir )
	// #if SERVER
	// 	float chargeTime = weapon.GetWeaponChargeTime()
	// 	if ( chargeTime > ChargeBall_GetChargeTime() )
	// 		grenade.proj.isChargedShot = true
	// 	grenade.proj.trackedEnt = weapon
	// #endif
	// return weapon.GetWeaponInfoFileKeyField( "ammo_min_to_fire" )

	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	vector[ 3 ] anglesToRotate = [ <0,0,0>, < 0, 15, 0 >, < 0, -15, 0 > ]

	#if SERVER
	float duration = weapon.HasMod( "pas_scorch_firewall" ) ? PAS_SCORCH_FIREWALL_DURATION : FLAME_WALL_THERMITE_DURATION
	entity inflictor = CreateOncePerTickDamageInflictorHelper( duration )
	#endif

	const float FUSE_TIME = 99.0
	entity projectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, shouldPredict, true, true )
	if ( projectile )
	{
		projectile.SetModel( $"models/dev/empty_model.mdl" )
		EmitSoundOnEntity( projectile, FLAME_WALL_PROJECTILE_SFX )
		#if SERVER
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )
			thread BeginFlameWave( projectile, 0, inflictor, attackParams, attackParams.dir )
		#endif
	}

	#if CLIENT
		ClientScreenShake( 8.0, 10.0, 1.0, Vector( 0.0, 0.0, 0.0 ) )
	#endif

	#if SERVER
		// anim fix for titanpick
		if ( weaponOwner.IsPlayer() )
		{
			// shared from special_3p_attack_anim_fix.gnut
			// fix atlas chassis animation
			// flamewall's npc fix already handled in OnWeaponActivate_titancore_flame_wall()
			HandleSpecial3pAttackAnim( weaponOwner, weapon, 0.5 )
		}
	#endif

	return weapon.GetWeaponInfoFileKeyField( "ammo_min_to_fire" )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_FlameWall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if ( weapon.HasMod( "stryder_fire_wave" ) )
		return OnWeaponNpcPrimaryAttack_titanweapon_fire_wave( weapon, attackParams )

	return OnWeaponPrimaryAttack_FlameWall( weapon, attackParams )
}
#endif

void function OnProjectileCollision_FlameWall( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// vanilla has no specific behavior, this is modded only
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile )
	if( mods.contains( "wrecking_ball" ) )
		return OnProjectileCollision_weapon_wrecking_ball( projectile, pos, normal, hitEnt, hitbox, isCritical )
}

#if SERVER
void function BeginFlameWave( entity projectile, int projectileCount, entity inflictor, WeaponPrimaryAttackParams attackParams, vector direction )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.SetAbsOrigin( projectile.GetOrigin() )
	projectile.SetAbsAngles( projectile.GetAngles() )
	projectile.SetVelocity( Vector( 0, 0, 0 ) )
	projectile.StopPhysics()
	projectile.SetTakeDamageType( DAMAGE_NO )
	projectile.Hide()
	projectile.NotSolid()
	projectile.proj.savedOrigin = < -999999.0, -999999.0, -999999.0 >
	waitthread WeaponAttackWave( projectile, projectileCount, inflictor, attackParams.pos + direction * 25.0, direction, CreateThermiteWallSegment )
	projectile.Destroy()
}

bool function CreateThermiteWallSegment( entity projectile, int projectileCount, entity inflictor, entity movingGeo, vector pos, vector angles, int waveCount )
{
	projectile.SetOrigin( pos )
	entity owner = projectile.GetOwner()

	if ( projectile.proj.savedOrigin != < -999999.0, -999999.0, -999999.0 > )
	{
		//array<string> mods = projectile.ProjectileGetMods() // behavior is "absorb", no need to change to Vortex_GetRefiredProjectileMods()
		array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // all good, refired mods not that bad to use
		float duration
		int damageSource
		if ( mods.contains( "pas_scorch_flamecore" ) )
		{
			damageSource = eDamageSourceId.mp_titancore_flame_wave_secondary
			duration = 1.5
		}
		else
		{
			damageSource = eDamageSourceId.mp_titanweapon_flame_wall
			duration = mods.contains( "pas_scorch_firewall" ) ? PAS_SCORCH_FIREWALL_DURATION : FLAME_WALL_THERMITE_DURATION
			
			// modified: flamewall_grenade
			if( mods.contains( "flamewall_grenade" ) )
				duration = THERMITE_GRENADE_BURN_TIME
		}
		

		if ( IsSingleplayer() )
		{
			if ( owner.IsPlayer() || Flag( "SP_MeteorIncreasedDuration" ) )
			{
				duration *= SP_FLAME_WALL_DURATION_SCALE
			}
		}

		entity thermiteParticle
		//regular script path
		if ( !movingGeo )
		{
			thermiteParticle = CreateThermiteTrail( pos, angles, owner, inflictor, duration, FLAME_WALL_FX, damageSource )
			EffectSetControlPointVector( thermiteParticle, 1, projectile.proj.savedOrigin )
			AI_CreateDangerousArea_Static( thermiteParticle, projectile, METEOR_THERMITE_DAMAGE_RADIUS_DEF, TEAM_INVALID, true, true, pos )
		}
		else
		{
			if ( GetMapName() == "sp_s2s" )
			{
				angles = <0,90,0>//wind dir
				thermiteParticle = CreateThermiteTrailOnMovingGeo( movingGeo, pos, angles, owner, inflictor, duration, FLAME_WALL_FX_S2S, damageSource )
			}
			else
			{
				thermiteParticle = CreateThermiteTrailOnMovingGeo( movingGeo, pos, angles, owner, inflictor, duration, FLAME_WALL_FX, damageSource )
			}

			if ( movingGeo == projectile.proj.savedMovingGeo )
			{
				thread EffectUpdateControlPointVectorOnMovingGeo( thermiteParticle, 1, projectile.proj.savedRelativeDelta, projectile.proj.savedMovingGeo )
			}
			else
			{
				thread EffectUpdateControlPointVectorOnMovingGeo( thermiteParticle, 1, GetRelativeDelta( pos, movingGeo ), movingGeo )
			}
			AI_CreateDangerousArea( thermiteParticle, projectile, METEOR_THERMITE_DAMAGE_RADIUS_DEF, TEAM_INVALID, true, true )
		}

		//EmitSoundOnEntity( thermiteParticle, FLAME_WALL_GROUND_SFX )
		int maxSegments = expect int( projectile.ProjectileGetWeaponInfoFileKeyField( "wave_max_count" ) )
		//figure out why it's starting at 1 but ending at 14.
		if ( waveCount == 1 )
			EmitSoundOnEntity( thermiteParticle, FLAME_WALL_GROUND_BEGINNING_SFX )
		else if ( waveCount == ( maxSegments - 1 ) )
			EmitSoundOnEntity( thermiteParticle, FLAME_WALL_GROUND_END_SFX )
		else if ( waveCount == maxSegments / 2  )
			EmitSoundOnEntity( thermiteParticle, FLAME_WALL_GROUND_MIDDLE_SFX )
	}

	projectile.proj.savedOrigin = pos
	if ( IsValid( movingGeo ) )
	{
		projectile.proj.savedRelativeDelta = GetRelativeDelta( pos, movingGeo )
		projectile.proj.savedMovingGeo = movingGeo
	}

	return true
}

void function EffectUpdateControlPointVectorOnMovingGeo( entity thermiteParticle, int cpIndex, vector relativeDelta, entity movingGeo )
{
	thermiteParticle.EndSignal( "OnDestroy" )

	while ( 1 )
	{
		vector origin = GetWorldOriginFromRelativeDelta( relativeDelta, movingGeo )

		EffectSetControlPointVector( thermiteParticle, cpIndex, origin )
		WaitFrame()
	}
}

void function FlameWall_DamagedTarget( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	Thermite_DamagePlayerOrNPCSounds( ent )
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