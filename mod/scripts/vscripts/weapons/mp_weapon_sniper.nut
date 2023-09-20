untyped
global function MpWeaponSniper_Init

global function OnWeaponActivate_weapon_sniper
global function OnWeaponPrimaryAttack_weapon_sniper
global function OnProjectileCollision_weapon_sniper

#if CLIENT
global function OnClientAnimEvent_weapon_sniper
#endif // #if CLIENT

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_sniper
#endif // #if SERVER

const int MAX_FLOATING_BOLT_COUNT = 64
array<entity> floatingBolts

void function MpWeaponSniper_Init()
{
	SniperPrecache()

	// modified. really should separent these to mp_weapon_modded_kraber.gnut
#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_sniper, OnHit_WeaponSniper )
	PrecacheModel( $"models/domestic/nessy_doll.mdl" )

	// burnmod blacklist
	ModdedBurnMods_AddDisabledMod( "ricochet_only_sniper" )
	ModdedBurnMods_AddDisabledMod( "floating_bolt_sniper" )
	ModdedBurnMods_AddDisabledMod( "ricochet_infinite_sniper" )
	ModdedBurnMods_AddDisabledMod( "explosive_sniper" )
	ModdedBurnMods_AddDisabledMod( "phase_sniper" )
	ModdedBurnMods_AddDisabledMod( "heal_sniper" )
	ModdedBurnMods_AddDisabledMod( "stim_sniper" )
#endif
}

void function SniperPrecache()
{
	PrecacheParticleSystem( $"wpn_mflash_snp_hmn_smoke_side_FP" )
	PrecacheParticleSystem( $"wpn_mflash_snp_hmn_smoke_side" )
	PrecacheParticleSystem( $"Rocket_Smoke_SMR_Glow" )
}

void function OnWeaponActivate_weapon_sniper( entity weapon )
{
#if CLIENT
	UpdateViewmodelAmmo( false, weapon )
#endif // #if CLIENT
}

#if CLIENT
void function OnClientAnimEvent_weapon_sniper( entity weapon, string name )
{
	GlobalClientEventHandler( weapon, name )

	if ( name == "muzzle_flash" )
	{

		if ( IsOwnerViewPlayerFullyADSed( weapon ) )
			return

		weapon.PlayWeaponEffect( $"wpn_mflash_snp_hmn_smoke_side_FP", $"wpn_mflash_snp_hmn_smoke_side", "muzzle_flash_L" )
		weapon.PlayWeaponEffect( $"wpn_mflash_snp_hmn_smoke_side_FP", $"wpn_mflash_snp_hmn_smoke_side", "muzzle_flash_R" )
	}
}

#endif // #if CLIENT

var function OnWeaponPrimaryAttack_weapon_sniper( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireWeaponPlayerAndNPC( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_sniper( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireWeaponPlayerAndNPC( weapon, attackParams, false )
}
#endif // #if SERVER

int function FireWeaponPlayerAndNPC( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true

	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	if ( shouldCreateProjectile )
	{
		int boltSpeed = expect int( weapon.GetWeaponInfoFileKeyField( "bolt_speed" ) )
		int damageFlags = weapon.GetWeaponDamageFlags()
		int explosionFlags = damageFlags
		if ( weapon.HasMod( "explosive_sniper" ) ) // explosive weapons should have a DF_EXPLOSION damage flag...
			explosionFlags = damageFlags | DF_EXPLOSION

		// modded condition
		if( weapon.HasMod( "smart_sniper" ) )
		{
			SmartAmmo_SetAllowUnlockedFiring( weapon, true ) // allow unlocked fire

			// fire a missile!
			float missileSpeed = 10000
			float missileHomingSpeed = 10000
			float missileSpeedLimit = 10000
			if ( weapon.HasMod( "homing_nessie" ) ) // homing nessie modifier
				missileSpeed = 100

			// maybe we should recalculate? SmartAmmo_FireWeapon() seems fire a bullet that ignores spread
			//entity weaponOwner = weapon.GetWeaponOwner()
			//vector bulletVec = ApplyVectorSpread( attackParams.dir, weaponOwner.GetAttackSpreadAngle() )
			//attackParams.dir = bulletVec
			SmartAmmo_SetMissileSpeed( weapon, missileSpeed )
			SmartAmmo_SetMissileHomingSpeed( weapon, missileHomingSpeed )
			SmartAmmo_SetMissileSpeedLimit( weapon, missileSpeedLimit )
			int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageFlags, explosionFlags )
			if( !fired )
				return 0

			// smart sniper projectile update
			// get rid of sh_smart_ammo.gnut hardcode, newest version not gonna transfer to client
			#if SERVER
				foreach ( entity projectile in FindSmartSniperProjectile( weapon ) )
				{
					projectile.kv.lifetime = 100 // smart sniper lasts longer
					if ( weapon.HasMod( "homing_nessie" ) ) // homing nessie modifier
					{
						projectile.kv.lifetime = 9999
						projectile.SetModel( $"models/domestic/nessy_doll.mdl" )
					}
				}
			#endif
			//
		}
		else // vanilla behavior
		{
			entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
			//bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, 1.0, damageFlags, damageFlags, playerFired, 0 )

			if ( bolt != null )
			{
				// weapon mods. hardcoded
				if( weapon.HasMod( "nessie_sniper" ) )
					bolt.SetModel( $"models/domestic/nessy_doll.mdl" )
				if( weapon.HasMod( "nessie_balance" ) )
				{
					bolt.kv.gravity = 0.0 // default gravity
				}
				else if( weapon.HasMod( "floating_bolt_sniper" ) )
				{
					#if SERVER
					floatingBolts.append( bolt )
					thread BoltArrayThink( bolt )
					FloatingBoltLimitThink()
					#endif
				}
				else if( weapon.HasMod( "ricochet_infinite_sniper" ) )
				{
					bolt.kv.gravity = 0.0001
				}
				else
					bolt.kv.gravity = expect float( weapon.GetWeaponInfoFileKeyField( "bolt_gravity_amount" ) )
					
#if CLIENT
				StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"Rocket_Smoke_SMR_Glow" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
#endif // #if CLIENT
			}
		}
	}

	return 1
}

// modified function
// if there's a projectile created at the same time the weapon firing
// we consider the projectile as current firing one
#if SERVER
array<entity> function FindSmartSniperProjectile( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return []

	array<entity> ownedProjectiles
	foreach ( entity projectile in GetProjectileArray() )
	{
		if ( projectile.GetOwner() == owner && projectile.GetProjectileCreationTime() == Time() )
		{
			// debug
			//print( "player owned kraber projectile: " + string( projectile ) )

			ownedProjectiles.append( projectile )
		}
	}

	return ownedProjectiles
}
#endif

void function OnProjectileCollision_weapon_sniper( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modified condition
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) 
	array<string> refiredMods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if( refiredMods.contains( "tediore_effect" ) )
		return OnProjectileCollision_Tediore( projectile, pos, normal, hitEnt, hitbox, isCritical )

#if SERVER
	if( mods.contains( "explosive_sniper" ) )
	{
		// hardcoded fix...
		float creationTime = projectile.GetProjectileCreationTime()
		float maxFixTime = creationTime + 0.3 // hope this will pretty much fix client visual
		if ( Time() < maxFixTime )
		{
			//PlayImpactFXTable( pos, projectile, "40mm_splasher_rounds", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
			// splasher rounds can be too loud, change to use this
			PlayImpactFXTable( pos, projectile, "exp_softball_grenade", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
		}
		// do a fake explosion effect for better client visual, hardcoded!
		// correct this: it's because we played a single FX, not a impact table // this won't work due "projectile_do_predict_impact_effects"
		//PlayImpactFXTable( pos, hitEnt, "" )
		//PlayFX( $"P_impact_exp_lrg_metal", pos ) // a single FX won't work on some condition... consider a better ImpactEffectTable
		//EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "explo_40mm_splashed_impact_3p" )
	}

	// vanilla behavior
	int bounceCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectile_ricochet_max_count )
	if ( projectile.proj.projectileBounceCount >= bounceCount )
		return

	//print( "projectile bounced!" )
	if ( hitEnt == svGlobal.worldspawn )
		EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Bullets.DefaultNearmiss" )

	projectile.proj.projectileBounceCount++

	// fix for explosive rounds bouncing
	//float traceFrac = TraceLineSimple( pos + normal, projectile.GetOrigin(), null )
	//print( "traceFrac: " + string( traceFrac ) )
	// bounced projectile, try to fix their explosion damage, will double the damage if they're not in valid bounce frac though
	entity owner = projectile.GetOwner()
	int damage 						= projectile.GetProjectileWeaponSettingInt( eWeaponVar.explosion_damage )
	int titanDamage					= projectile.GetProjectileWeaponSettingInt( eWeaponVar.explosion_damage_heavy_armor )
	float explosionRadius 			= projectile.GetProjectileWeaponSettingFloat( eWeaponVar.explosionradius )
	float explosionInnerRadius 		= projectile.GetProjectileWeaponSettingFloat( eWeaponVar.explosion_inner_radius )
	int damageFlags					= TEMP_GetDamageFlagsFromProjectile( projectile )
	float explosionForce			= projectile.GetProjectileWeaponSettingFloat( eWeaponVar.impulse_force_explosions )
	int damageSourceId 				= projectile.ProjectileGetDamageSourceID()
	if ( damage > 0 && explosionRadius > 0 )
	{
		RadiusDamage(
			pos,															// origin
			owner,															// owner
			projectile,		 												// inflictor
			damage,															// normal damage
			titanDamage,													// heavy armor damage
			explosionInnerRadius,											// inner radius
			explosionRadius,												// outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,								// explosion flags
			0, 																// distanceFromAttacker
			explosionForce, 												// explosionForce
			damageFlags,													// damage flags
			damageSourceId													// damage source id
		)
	}
#endif
}


// modified conditions! really should separent a file "mp_weapon_modded_kraber"
#if SERVER
void function BoltArrayThink( entity bolt )
{
	bolt.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function(): ( bolt )
		{
			floatingBolts.removebyvalue( bolt )
		}
	)

	WaitForever()
}

void function FloatingBoltLimitThink()
{
	if( floatingBolts.len() >= MAX_FLOATING_BOLT_COUNT )
	{
		if( IsValid( floatingBolts[0] ) )
			floatingBolts[0].Destroy()
		floatingBolts.remove(0)
	}
}

void function OnHit_WeaponSniper( entity victim, var damageInfo )
{
	EffectVictim( victim, damageInfo )
}

void function EffectVictim( entity victim, var damageInfo )
{
	if ( !IsValid( victim ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if( !IsValid( attacker ) )
		return
	entity inflictor = DamageInfo_GetInflictor( damageInfo ) // assuming this is kraber's bolt
	if( !IsValid( inflictor ) )
		return
	if( !inflictor.IsProjectile() )
		return

	array<string> mods = Vortex_GetRefiredProjectileMods( inflictor ) 
	if( victim.GetTeam() == attacker.GetTeam() )
	{
		if( mods.contains( "heal_sniper" ) )
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			EmitSoundOnEntity( victim, "pilot_stimpack_activate_3P" )
			victim.SetHealth( victim.GetMaxHealth() )
		}
		else if( mods.contains( "stim_sniper" ) )
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			// stimming requires victim be a player
			if( !victim.IsPlayer() )
				return
			StimPlayer( victim, 3 )
		}
	}

	if( mods.contains( "phase_sniper" ) ) // phase sniper works for both team
	{
		if( victim.GetTeam() == attacker.GetTeam() )
			DamageInfo_SetDamage( damageInfo, 0 )
		PhaseShift( victim, 0, 3 )
	}
}
#endif