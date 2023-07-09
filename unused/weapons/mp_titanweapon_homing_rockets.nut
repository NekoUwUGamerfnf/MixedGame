untyped

global function OnWeaponOwnerChanged_titanweapon_homing_rockets
global function OnWeaponPrimaryAttack_titanweapon_homing_rockets

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_homing_rockets
#endif

const HOMINGROCKETS_NUM_ROCKETS_PER_SHOT	= 3
const HOMINGROCKETS_MISSILE_SPEED			= 1250
const HOMINGROCKETS_APPLY_RANDOM_SPREAD		= true
const HOMINGROCKETS_LAUNCH_OUT_ANG 			= 17
const HOMINGROCKETS_LAUNCH_OUT_TIME 		= 0.15
const HOMINGROCKETS_LAUNCH_IN_LERP_TIME 	= 0.2
const HOMINGROCKETS_LAUNCH_IN_ANG 			= -12
const HOMINGROCKETS_LAUNCH_IN_TIME 			= 0.10
const HOMINGROCKETS_LAUNCH_STRAIGHT_LERP_TIME = 0.1

int burstCount = 0

void function OnWeaponOwnerChanged_titanweapon_homing_rockets( entity weapon, WeaponOwnerChangedParams changeParams )
{
	burstCount = 0
	Init_titanweapon_homing_rockets( weapon )
}

function Init_titanweapon_homing_rockets( entity weapon )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.initialized <- true
		SmartAmmo_SetMissileSpeed( weapon, HOMINGROCKETS_MISSILE_SPEED )
		SmartAmmo_SetMissileHomingSpeed( weapon, 250 )
		SmartAmmo_SetUnlockAfterBurst( weapon, true )
		SmartAmmo_SetDisplayKeybinding( weapon, false )
		SmartAmmo_SetExpandContract( weapon, HOMINGROCKETS_NUM_ROCKETS_PER_SHOT, HOMINGROCKETS_APPLY_RANDOM_SPREAD, HOMINGROCKETS_LAUNCH_OUT_ANG, HOMINGROCKETS_LAUNCH_OUT_TIME, HOMINGROCKETS_LAUNCH_IN_LERP_TIME, HOMINGROCKETS_LAUNCH_IN_ANG, HOMINGROCKETS_LAUNCH_IN_TIME, HOMINGROCKETS_LAUNCH_STRAIGHT_LERP_TIME )
	}
}

var function OnWeaponPrimaryAttack_titanweapon_homing_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity ownerPlayer = weapon.GetWeaponOwner()

	if( weapon.HasMod( "fakebt_balance" ) )
	{
		if( weapon.GetWeaponPrimaryClipCount() == weapon.GetWeaponPrimaryClipCountMax() )
		{
			burstCount = 1
			//weapon.SetNextAttackAllowedTime( Time() + 14 )
			int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.projectileImpact, damageTypes.explosive )
			if( fired )
			{
				#if SERVER
				if( weapon.HasMod( "burn_mod_titan_homing_rockets" ) )
					DiscardAmmo( weapon, 80 )
				else
					DiscardAmmo( weapon, 100 )
				#endif
				return fired
			}
			else
				return false
		}
		else if( burstCount >= 1 )
		{
			burstCount += 1
			int maxBurst = 4
			if( weapon.HasMod( "burn_mod_titan_homing_rockets" ) )
				maxBurst = 5
			if( burstCount == maxBurst )
				burstCount = 0
			int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.projectileImpact, damageTypes.explosive )
			if( fired )
			{
				#if SERVER
				if( weapon.HasMod( "burn_mod_titan_homing_rockets" ) )
					DiscardAmmo( weapon, 80 )
				else
					DiscardAmmo( weapon, 100 )
				#endif
				return fired
			}
			else
				return false
		}
		else
		{
			#if SERVER
			SendHudMessage(ownerPlayer, "需要完全充满以使用同步弹头", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			#endif
			return false
		}
	}
	else
		return SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.projectileImpact, damageTypes.explosive )

}


#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_homing_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_homing_rockets( weapon, attackParams )
}
#endif

#if SERVER
void function DiscardAmmo( entity weapon, int consume )
{
	weapon.SetWeaponPrimaryClipCountAbsolute( max( 20, weapon.GetWeaponPrimaryClipCount() - consume ) )
}
#endif