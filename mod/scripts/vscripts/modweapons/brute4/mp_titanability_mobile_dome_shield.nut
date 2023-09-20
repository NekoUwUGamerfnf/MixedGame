untyped

global function MpTitanAbilityMobileDomeShield_Init

global function OnWeaponPrimaryAttack_mobile_dome_shield

#if SERVER
global function OnWeaponNpcPrimaryAttack_mobile_dome_shield
#endif // #if SERVER

const float MOLTING_SHELL_MAX_REFUND = 2.0 // seconds

// we're now setup stuffs in mod.json, return type should be void
void function MpTitanAbilityMobileDomeShield_Init()
{

}

var function OnWeaponPrimaryAttack_mobile_dome_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	#if SERVER
	entity soul = weaponOwner.GetTitanSoul()

	if( weaponOwner.IsPlayer() && IsValid( soul )  && IsValid( soul.soul.bubbleShield ))
		return 0
	#endif //SERVER

	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	thread GiveMobileDomeShield( weapon, weaponOwner, duration )

	return 1
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_mobile_dome_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	entity soul = weaponOwner.GetTitanSoul()
	if ( IsValid( soul ) && IsValid( soul.soul.bubbleShield ))
		return 0

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	thread GiveMobileDomeShield( weapon, weaponOwner, duration )

	return 1
}
#endif // #if SERVER

void function GiveMobileDomeShield( entity weapon, entity owner, float duration = 6.0 )
{
	#if SERVER
	owner.EndSignal( "OnDeath" )

	entity soul = owner.GetTitanSoul()
	if ( soul == null )
		return

	soul.EndSignal( "OnTitanDeath" )
	soul.EndSignal( "OnDestroy" )

	// Prevents the owner from sprinting
	int slowID = StatusEffect_AddTimed( owner, eStatusEffect.move_slow, 0.5, duration, 0 )
	int speedID = StatusEffect_AddTimed( owner, eStatusEffect.speed_boost, 0.5, duration, 0 )
	MobileDomeShield_AllowNPCWeapons( owner, false )

	MobileDomeShield_CreateDome( owner, owner.GetOrigin(), owner.GetAngles(), duration )

	soul.EndSignal( "TitanBrokeBubbleShield" )
	entity bubbleShield = soul.soul.bubbleShield
	bubbleShield.EndSignal( "OnDestroy" )

	bool rechargeDash = weapon.HasMod( "molting_dome" )
	if ( rechargeDash )
	{
		owner.s.bubbleShieldHealthFrac <- 1.0
		bubbleShield.s.ownerForDisembark <- owner
		AddEntityDestroyedCallback( bubbleShield, MobileDomeShield_TrackHealth )
	}

	OnThreadEnd(
	function() : ( owner, weapon, rechargeDash, slowID, speedID )
		{
			if ( rechargeDash && IsValid( weapon ) && IsValid( owner ) )
			{
				float fireDuration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
				float remainingUseTime = float( weapon.GetWeaponPrimaryClipCount() ) / float( weapon.GetWeaponPrimaryClipCountMax() ) * fireDuration
				float remainingShieldTime = expect float( owner.s.bubbleShieldHealthFrac ) * fireDuration
				int refundAmmo = int( min( MOLTING_SHELL_MAX_REFUND, remainingShieldTime ) * weapon.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate ) )
				thread MobileDomeShield_RefundDuration( weapon, owner, refundAmmo, remainingUseTime )
			}

			if ( IsValid( owner ) )
			{
				StatusEffect_Stop( owner, slowID )
				StatusEffect_Stop( owner, speedID )
				MobileDomeShield_AllowNPCWeapons( owner, true )

				if ( owner.IsPlayer() && owner.IsTitan() && rechargeDash )
				{
					float amount = expect float( GetSettingsForPlayer_DodgeTable( owner )["dodgePowerDrain"] )
					owner.Server_SetDodgePower( min( 100.0, owner.GetDodgePower() + amount ) )
				}
			}
		}
	)
	
	MobileDomeShield_AllowShootThrough( owner, weapon )

	wait duration
	#endif
}

#if SERVER
function MobileDomeShield_TrackHealth( bubbleShield )
{
	// Bubble Shield can use GetParent() to get the titan, but this callback runs after soul transfer on disembark.
	// Alternatively, could track the health in the titan soul.
	expect entity( bubbleShield )
	entity owner = expect entity( bubbleShield.s.ownerForDisembark )
	if ( IsValid( owner ) )
		owner.s.bubbleShieldHealthFrac = max( 0, GetHealthFrac( bubbleShield ) )
}

void function MobileDomeShield_RefundDuration( entity weapon, entity owner, int amount, float delay )
{
	wait delay
	if ( !IsValid( weapon ) || !IsValid( owner ) || weapon.GetWeaponOwner() != owner )
		return
	
	if ( weapon.GetWeaponPrimaryClipCount() + amount <= weapon.GetWeaponPrimaryClipCountMax() )
		weapon.SetWeaponPrimaryClipCountNoRegenReset( weapon.GetWeaponPrimaryClipCount() + amount )
}

void function MobileDomeShield_AllowNPCWeapons( entity npc, bool unlock = false )
{
	// Prevent NPCs from breaking their bubble shield early
	// Not working properly rn and dunno how to fix
	if ( npc.IsNPC() )
	{
		if ( npc.GetMainWeapons().len() > 0 )
			npc.GetMainWeapons()[0].AllowUse( unlock )
			
		entity ordnance = npc.GetOffhandWeapon( OFFHAND_RIGHT )
		if ( IsValid( ordnance ) )
			ordnance.AllowUse( unlock )

		entity utility = npc.GetOffhandWeapon( OFFHAND_TITAN_CENTER )
		if ( IsValid( utility ) )
			utility.AllowUse( unlock )
	}
}
#endif