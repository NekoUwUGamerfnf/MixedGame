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
	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_sniper, OnHit_WeaponSniper )
	PrecacheModel( $"models/domestic/nessy_doll.mdl" )
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
		entity bolt
		if( weapon.HasMod( "smart_sniper" ) )
		{
			if( weapon.HasMod( "homing_nessie" ) )
			{
				SmartAmmo_SetMissileSpeed( weapon, 100 )
				SmartAmmo_SetMissileHomingSpeed( weapon, 10000 )
				SmartAmmo_SetMissileSpeedLimit( weapon, 10000 )
				int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.bullet, damageTypes.bullet )
				if( !fired )
					return 0
			}
			else
			{
				// better not adjust itself
				//entity weaponOwner = weapon.GetWeaponOwner()
				//vector bulletVec = ApplyVectorSpread( attackParams.dir, weaponOwner.GetAttackSpreadAngle() )
				//attackParams.dir = bulletVec
				SmartAmmo_SetMissileSpeed( weapon, 10000 )
				SmartAmmo_SetMissileHomingSpeed( weapon, 10000 )
				SmartAmmo_SetMissileSpeedLimit( weapon, 10000 )
				int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.bullet, damageTypes.bullet )
				if( !fired )
					return 0
			}
		}
		else
		{
			bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, boltSpeed, damageFlags, damageFlags, playerFired, 0 )
			//bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, 1.0, damageFlags, damageFlags, playerFired, 0 )

			if ( bolt != null )
			{
				if( weapon.HasMod( "nessie_sniper" ) )
					bolt.SetModel( $"models/domestic/nessy_doll.mdl" )
				if( weapon.HasMod( "nessie_balance" ) )
				{
					bolt.kv.gravity = 0.0
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
				if( !weapon.HasMod( "homing_nessie" ) && !weapon.HasMod( "nessie_sniper" ) )
					StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"Rocket_Smoke_SMR_Glow" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
#endif // #if CLIENT
			}
		}
	}

	return 1
}

void function OnProjectileCollision_weapon_sniper( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()
	if( mods.contains( "tediore_effect" ) )
		return OnProjectileCollision_Tediore( projectile, pos, normal, hitEnt, hitbox, isCritical )
#if SERVER
	if( mods.contains( "explosive_sniper" ) )
	{
		// do a fake explosion effect for better client visual, hardcoded!
		// this won't work due "projectile_do_predict_impact_effects"
		//PlayFX( $"P_impact_exp_lrg_metal", pos )
		//EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "explo_40mm_splashed_impact_3p" )
	}

	int bounceCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectile_ricochet_max_count )
	if ( projectile.proj.projectileBounceCount >= bounceCount )
		return

	if ( hitEnt == svGlobal.worldspawn )
		EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Bullets.DefaultNearmiss" )

	projectile.proj.projectileBounceCount++
#endif
}

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

	array<string> mods = inflictor.ProjectileGetMods()
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