untyped

global function OnWeaponPrimaryAttack_titanweapon_salvo_rockets
global function OnProjectileCollision_titanweapon_salvo_rockets

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_salvo_rockets
#endif

const SALVOROCKETS_MISSILE_SFX_LOOP			= "Weapon_Sidwinder_Projectile"
const SALVOROCKETS_NUM_ROCKETS_PER_SHOT 	= 1
const SALVOROCKETS_APPLY_RANDOM_SPREAD 		= true
const SALVOROCKETS_LAUNCH_OUT_ANG 			= 5
const SALVOROCKETS_LAUNCH_OUT_TIME 			= 0.20
const SALVOROCKETS_LAUNCH_IN_LERP_TIME 		= 0.2
const SALVOROCKETS_LAUNCH_IN_ANG 			= -10
const SALVOROCKETS_LAUNCH_IN_TIME 			= 0.10
const SALVOROCKETS_LAUNCH_STRAIGHT_LERP_TIME = 0.1
const SALVOROCKETS_DEBUG_DRAW_PATH 			= false

var function OnWeaponPrimaryAttack_titanweapon_salvo_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapons
	if( weapon.HasMod( "brute4_grenade_volley" ) )
		return OnWeaponPrimaryAttack_titanweapon_grenade_volley( weapon, attackParams )
	//

	// vanilla behavior
	bool shouldPredict = weapon.ShouldPredictProjectiles()

	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	array<entity> firedMissiles = FireExpandContractMissiles( weapon, attackParams, attackParams.pos, attackParams.dir, damageTypes.projectileImpact, damageTypes.explosive, shouldPredict, SALVOROCKETS_NUM_ROCKETS_PER_SHOT, VANGUARD_SHOULDER_MISSILE_SPEED, SALVOROCKETS_LAUNCH_OUT_ANG, SALVOROCKETS_LAUNCH_OUT_TIME, SALVOROCKETS_LAUNCH_IN_ANG, SALVOROCKETS_LAUNCH_IN_TIME, SALVOROCKETS_LAUNCH_IN_LERP_TIME, SALVOROCKETS_LAUNCH_STRAIGHT_LERP_TIME, SALVOROCKETS_APPLY_RANDOM_SPREAD, -1, SALVOROCKETS_DEBUG_DRAW_PATH )
	foreach( missile in firedMissiles )
	{
		#if SERVER
			missile.SetOwner( player )
			EmitSoundOnEntity( missile, SALVOROCKETS_MISSILE_SFX_LOOP )
		#endif
		SetTeam( missile, player.GetTeam() )
	}

	if ( player.IsPlayer() )
		PlayerUsedOffhand( player, weapon )

	return firedMissiles.len() * weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnProjectileCollision_titanweapon_salvo_rockets( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if( mods.contains( "brute4_grenade_volley" ) )
		return OnProjectileCollision_titanweapon_grenade_volley( projectile, pos, normal, hitEnt, hitbox, isCritical )
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_salvo_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "brute4_grenade_volley" ) )
		return OnWeaponNpcPrimaryAttack_titanweapon_grenade_volley( weapon, attackParams )
	//

	// vanilla behavior
	return OnWeaponPrimaryAttack_titanweapon_salvo_rockets( weapon, attackParams )
}
#endif