global function OnWeaponActivate_titanweapon_sword
global function OnWeaponDeactivate_titanweapon_sword
global function MpTitanWeaponSword_Init

global const asset SWORD_GLOW_FP = $"P_xo_sword_core_hld_FP"
global const asset SWORD_GLOW = $"P_xo_sword_core_hld"

global const asset SWORD_GLOW_PRIME_FP = $"P_xo_sword_core_PRM_FP"
global const asset SWORD_GLOW_PRIME = $"P_xo_sword_core_PRM"

// modified!!!
// less than this we'll consider re-deploy melee, so it can have proper anim time
const float TITAN_SWORD_ATTACK_ANIMTIME = 0.8 // actually 0.9
const float TITAN_SWORD_ATTACK_ANIMTIME_SP = 1.1 // actually 1.2
//

void function MpTitanWeaponSword_Init()
{
	PrecacheParticleSystem( SWORD_GLOW_FP )
	PrecacheParticleSystem( SWORD_GLOW )

	PrecacheParticleSystem( SWORD_GLOW_PRIME_FP )
	PrecacheParticleSystem( SWORD_GLOW_PRIME )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_shift_core, Sword_DamagedTarget )
	#endif
}

void function OnWeaponActivate_titanweapon_sword( entity weapon )
{
	if ( weapon.HasMod( "super_charged" ) )
	{
		if ( weapon.HasMod( "modelset_prime" ) )
			weapon.PlayWeaponEffectNoCull( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME, "sword_edge" )
		else
			weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
	}

	//thread DelayedSwordCoreFX( weapon )

	// modified!!
	#if SERVER
        float attackAnimTime = weapon.GetWeaponSettingFloat( eWeaponVar.melee_attack_animtime )
        if ( attackAnimTime > 0 ) // defensive fix!!!
		{
			float minAnimTime = TITAN_SWORD_ATTACK_ANIMTIME
			if ( IsSingleplayer() )
				minAnimTime = TITAN_SWORD_ATTACK_ANIMTIME_SP
			
			if ( attackAnimTime < minAnimTime )
				ModifiedMelee_ReDeployAfterTime( weapon ) // forced melee attack animtime
		}
	#endif
	//
}

/*void function DelayedSwordCoreFX( entity weapon )
{
	weapon.EndSignal( "WeaponDeactivateEvent" )
	weapon.EndSignal( "OnDestroy" )

	WaitFrame()

	weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
}*/

void function OnWeaponDeactivate_titanweapon_sword( entity weapon )
{
	if ( weapon.HasMod( "modelset_prime" ) )
		weapon.StopWeaponEffect( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME )
	else
		weapon.StopWeaponEffect( SWORD_GLOW_FP, SWORD_GLOW )
}

#if SERVER
void function Sword_DamagedTarget( entity target, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity soul = attacker.GetTitanSoul()
	entity coreWeapon = attacker.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	if ( !IsValid( coreWeapon ) )
		return

	if ( coreWeapon.HasMod( "fd_duration" ) && IsValid( soul ) )
	{
		int shieldRestoreAmount = target.GetArmorType() == ARMOR_TYPE_HEAVY ? 500 : 250
		soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )
	}
}
#endif