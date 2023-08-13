untyped
global function MpTitanweaponGrenadeLauncher_Init
global function OnWeaponPrimaryAttack_titanweapon_grenade_launcher
global function OnProjectileCollision_titanweapon_grenade_launcher
global function OnWeaponAttemptOffhandSwitch_titanweapon_grenade_launcher

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_grenade_launcher
#endif // #if SERVER

const FUSE_TIME = 0.5

void function MpTitanweaponGrenadeLauncher_Init()
{
#if SERVER
	// adding a new damageSourceId. it's gonna transfer to client automatically
	RegisterWeaponDamageSource( "mp_titanweapon_grenade_launcher", "Grenade Salvo" )

	// vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_titanweapon_salvo_rockets", // weapon name
		"brute4_grenade_launcher", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_softball", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_softball", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"grenade" // refire behavior
	)
#endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_grenade_launcher( entity weapon )
{
	int minAmmo = weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if ( currAmmo < minAmmo )
		return false

	return true
}

var function OnWeaponPrimaryAttack_titanweapon_grenade_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsPlayer() )
		PlayerUsedOffhand( owner, weapon )

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		FireGrenade( weapon, attackParams )

	return weapon.GetAmmoPerShot()
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_grenade_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	// all clients can hear the firing sound from script
	weapon.EmitWeaponSound_1p3p( "Weapon_Softball_Fire_1P", "Weapon_Softball_Fire_3P" )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.Signal( "KillBruteShield" )

	vector bulletVec = ApplyVectorSpread( attackParams.dir, (weaponOwner.GetAttackSpreadAngle() - 1.0) * 2 )

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, bulletVec, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		nade.SetModel( $"models/weapons/grenades/m20_f_grenade_projectile.mdl" )
		#if SERVER
			nade.ProjectileSetDamageSourceID( eDamageSourceId.mp_titanweapon_grenade_launcher ) // change damageSourceID
			EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
			Grenade_Init( nade, weapon )

			// fix for trail effect, so clients without scripts installed can see the trail
			// start from server-side, so clients that already installed scripts won't see multiple trail effect stacking together
			StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"weapon_40mm_projectile" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		#else
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
	}
}

void function OnProjectileCollision_titanweapon_grenade_launcher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
	if ( projectile.proj.projectileBounceCount > 0 )
	{
		if ( "isMagnetic" in projectile.s && IsMagneticTarget( hitEnt ) )
			projectile.GrenadeExplode( <0,0,0> )

		return
	}

	projectile.proj.projectileBounceCount++

	EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
	if ( Vortex_GetRefiredProjectileMods( projectile ).contains( "magnetic_rollers" ) ) // modded weapon refire behavior
		projectile.InitMagnetic( 1000.0, "Explo_MGL_MagneticAttract" )

	thread DetonateAfterTime( projectile, FUSE_TIME )
	#endif
}

#if SERVER
void function DetonateAfterTime( entity projectile, float delay )
{
	wait delay
	if ( IsValid( projectile ) )
		projectile.GrenadeExplode( <0,0,0> )
}
#endif