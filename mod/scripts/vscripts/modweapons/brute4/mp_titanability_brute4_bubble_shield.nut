untyped

global function MpTitanAbilityBrute4DomeShield_Init

global function OnWeaponPrimaryAttack_dome_shield

#if SERVER
global function OnWeaponNpcPrimaryAttack_dome_shield
#endif // #if SERVER

global const BRUTE4_DOME_SHIELD_HEALTH = 2500
global const PAS_DOME_SHIELD_HEALTH = 3000
global const BRUTE4_DOME_SHIELD_MELEE_MOD = 2.5
const float BRUTE4_MOLTING_SHELL_MAX_REFUND = 2.0 // seconds

function MpTitanAbilityBrute4DomeShield_Init()
{
	RegisterSignal( "KillBruteShield" )
}

var function OnWeaponPrimaryAttack_dome_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
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
	thread Brute4GiveShortDomeShield( weapon, weaponOwner, duration )

	return 1
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_dome_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	entity soul = weaponOwner.GetTitanSoul()
	if ( IsValid( soul ) && IsValid( soul.soul.bubbleShield ))
		return 0

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	thread Brute4GiveShortDomeShield( weapon, weaponOwner, duration )

	return 1
}
#endif // #if SERVER

void function Brute4GiveShortDomeShield( entity weapon, entity owner, float duration = 6.0 )
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
	Brute4DomeShield_AllowNPCWeapons( owner, false )

	CreateParentedBrute4BubbleShield( owner, owner.GetOrigin(), owner.GetAngles(), duration )

	soul.EndSignal( "TitanBrokeBubbleShield" )
	entity bubbleShield = soul.soul.bubbleShield
	bubbleShield.EndSignal( "OnDestroy" )

	bool rechargeDash = weapon.HasMod( "molting_dome" )
	if ( rechargeDash )
	{
		owner.s.bubbleShieldHealthFrac <- 1.0
		bubbleShield.s.ownerForDisembark <- owner
		AddEntityDestroyedCallback( bubbleShield, Brute4DomeShield_TrackHealth )
	}

	OnThreadEnd(
	function() : ( owner, weapon, rechargeDash, slowID, speedID )
		{
			if ( rechargeDash && IsValid( weapon ) && IsValid( owner ) )
			{
				float fireDuration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
				float remainingUseTime = float( weapon.GetWeaponPrimaryClipCount() ) / float( weapon.GetWeaponPrimaryClipCountMax() ) * fireDuration
				float remainingShieldTime = expect float( owner.s.bubbleShieldHealthFrac ) * fireDuration
				int refundAmmo = int( min( BRUTE4_MOLTING_SHELL_MAX_REFUND, remainingShieldTime ) * weapon.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate ) )
				thread Brute4DomeShield_RefundDuration( weapon, owner, refundAmmo, remainingUseTime )
			}

			if ( IsValid( owner ) )
			{
				StatusEffect_Stop( owner, slowID )
				StatusEffect_Stop( owner, speedID )
				Brute4DomeShield_AllowNPCWeapons( owner, true )

				if ( owner.IsPlayer() && owner.IsTitan() && rechargeDash )
				{
					float amount = expect float( GetSettingsForPlayer_DodgeTable( owner )["dodgePowerDrain"] )
					owner.Server_SetDodgePower( min( 100.0, owner.GetDodgePower() + amount ) )
				}
			}
		}
	)
	
	Brute4LetTitanPlayerShootThroughBubbleShield( owner, weapon )

	wait duration
	#endif
}

#if SERVER
function Brute4DomeShield_TrackHealth( bubbleShield )
{
	// Bubble Shield can use GetParent() to get the titan, but this callback runs after soul transfer on disembark.
	// Alternatively, could track the health in the titan soul.
	expect entity( bubbleShield )
	entity owner = expect entity( bubbleShield.s.ownerForDisembark )
	if ( IsValid( owner ) )
		owner.s.bubbleShieldHealthFrac = max( 0, GetHealthFrac( bubbleShield ) )
}

void function Brute4DomeShield_RefundDuration( entity weapon, entity owner, int amount, float delay )
{
	wait delay
	if ( IsValid( weapon ) && IsValid( owner ) && weapon.GetWeaponOwner() == owner )
		weapon.SetWeaponPrimaryClipCountNoRegenReset( min( weapon.GetWeaponPrimaryClipCountMax(), weapon.GetWeaponPrimaryClipCount() + amount ) )
}

void function Brute4DomeShield_AllowNPCWeapons( entity npc, bool unlock = false )
{
	// Prevent NPCs from breaking their bubble shield early
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