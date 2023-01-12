
global function MpWeaponDefender_Init

global function OnWeaponPrimaryAttack_weapon_defender

global function OnWeaponSustainedDischargeBegin_Defender

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_defender
#endif // #if SERVER

const float CHARGE_RIFLE_DAMAGE_TICK = 0.1
const float CHARGE_RIFLE_DAMAGE_COUNT = 10

void function MpWeaponDefender_Init()
{
	DefenderPrecache()
}

void function DefenderPrecache()
{
	PrecacheParticleSystem( $"P_wpn_defender_charge_FP" )
	PrecacheParticleSystem( $"P_wpn_defender_charge" )
	PrecacheParticleSystem( $"defender_charge_CH_dlight" )

	PrecacheParticleSystem( $"wpn_muzzleflash_arc_cannon_fp" )
	PrecacheParticleSystem( $"wpn_muzzleflash_arc_cannon" )
}

var function OnWeaponPrimaryAttack_weapon_defender( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	/*
	if( weapon.HasMod( "apex_charge_rifle" ) && weapon.HasMod( "quick_charge" ) )
	{
		#if SERVER
		thread FireChargeRifle( weapon, attackParams )
		#endif
		return 1
	}
	*/

	if ( weapon.GetWeaponChargeFraction() < 1.0 )
		return 0

	return FireDefender( weapon, attackParams )
}

bool function OnWeaponSustainedDischargeBegin_Defender( entity weapon )
{
	#if SERVER
	if( weapon.HasMod( "apex_charge_rifle" ) )
	{

		//weapon.e.onlyDamageEntitiesOncePerTick = true

		entity player = weapon.GetWeaponOwner()
		EmitSoundOnEntity( weapon, "Weapon_ChargeRifle_Fire_3P" )

		WeaponPrimaryAttackParams attackParams
		attackParams.dir = weapon.GetAttackDirection()
		attackParams.pos = weapon.GetAttackPosition()
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	}

	#endif

	return true
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_defender( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireDefender( weapon, attackParams )
}
#endif // #if SERVER


int function FireDefender( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )

	return 1
}

#if SERVER
void function FireChargeRifle( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	for( int i = 0; i < CHARGE_RIFLE_DAMAGE_COUNT; i ++ )
	{
		if( !IsValid( weaponOwner ) || !IsValid( weapon ) )
			return
		attackParams.dir = weapon.GetAttackDirection()
		attackParams.pos = weapon.GetAttackPosition()
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
		wait CHARGE_RIFLE_DAMAGE_TICK
	}
}
#endif