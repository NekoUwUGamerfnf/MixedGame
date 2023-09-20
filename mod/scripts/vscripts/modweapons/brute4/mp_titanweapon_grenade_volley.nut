untyped
global function MpTitanweaponGrenadeVolley_Init
global function OnWeaponPrimaryAttack_titanweapon_grenade_volley
global function OnProjectileCollision_titanweapon_grenade_volley
global function OnWeaponAttemptOffhandSwitch_titanweapon_grenade_volley

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_grenade_volley
#endif // #if SERVER

const FUSE_TIME = 0.5

void function MpTitanweaponGrenadeVolley_Init()
{
#if SERVER
	// adding a new damageSourceId. it's gonna transfer to client automatically
	RegisterWeaponDamageSource( "mp_titanweapon_grenade_volley", "Grenade Volley" )

	// vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_titanweapon_salvo_rockets", // weapon name
		"brute4_grenade_volley", // mod name
		$"wpn_vortex_projectile_frag_FP", // absorb effect
		$"wpn_vortex_projectile_frag", // absorb effect 3p
		"grenade" // refire behavior
	)
#endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_grenade_volley( entity weapon )
{
	int minAmmo = weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if ( currAmmo < minAmmo )
		return false

	return true
}

var function OnWeaponPrimaryAttack_titanweapon_grenade_volley( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( owner.IsPlayer() )
		PlayerUsedOffhand( owner, weapon )

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		FireGrenade( weapon, attackParams )

	return weapon.GetAmmoPerShot()
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_grenade_volley( entity weapon, WeaponPrimaryAttackParams attackParams )
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

	vector bulletVec = attackParams.dir
	// due we changed viewmodel to cluster missile launcher
	// needs to adjust attack pos
	// note: attackParams.dir is only for visual effect on client
	// if we don't change attackParams.pos the projectile still never collide with wall even when weapon barrel being blocked
	if ( weaponOwner.IsPlayer() )
		bulletVec = GetVectorFromPositionToCrosshair( weaponOwner, attackParams.pos )
	
	// apply spread
	bulletVec = ApplyVectorSpread( bulletVec, (weaponOwner.GetAttackSpreadAngle() - 1.0) * 2 )

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, bulletVec, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		nade.SetModel( $"models/weapons/grenades/m20_f_grenade_projectile.mdl" )
		#if SERVER
			nade.ProjectileSetDamageSourceID( eDamageSourceId.mp_titanweapon_grenade_volley ) // change damageSourceID
			EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
			Grenade_Init( nade, weapon )
		#else
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif

		// fix for trail effect, so clients without scripts installed can see the trail
		StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"weapon_40mm_projectile" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	}
}

void function OnProjectileCollision_titanweapon_grenade_volley( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
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