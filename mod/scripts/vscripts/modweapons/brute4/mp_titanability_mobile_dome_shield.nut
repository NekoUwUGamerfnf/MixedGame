untyped

global function MpTitanAbilityMobileDomeShield_Init

global function OnWeaponPrimaryAttack_mobile_dome_shield

#if SERVER
global function OnWeaponNpcPrimaryAttack_mobile_dome_shield
#endif // #if SERVER

const float MOLTING_SHELL_MAX_REFUND = 2.0 // seconds
// welp, maybe just make them don't fire during full duration of ability...
// npc's primary attack signal isn't implemented yet
//const float NPC_DISABLE_ATTACK_DURATION_FRAC = 0.5 // npc stops attacking and dodging at the start of this duration frac

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
	{
		// some validation checks:
		// we shouldn't let player use dome shield during a weapon burst -- that'll make themselves break dome shield instantly
		array<entity> weapons
		weapons.extend( weaponOwner.GetMainWeapons() )
		weapons.extend( weaponOwner.GetOffhandWeapons() )
		foreach ( weapon in weapons )
		{
			if ( weapon.IsBurstFireInProgress() )
				return 0
		}

		PlayerUsedOffhand( weaponOwner, weapon )
	}

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
	//MobileDomeShield_AllowNPCWeapons( owner, false )

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

	// modified here: handle npc usage to make them try not to break bubble shield too early
	array<int> npcDisabledCapabilityFlags
	array<int> npcEnabledMoveFlags
	if ( owner.IsNPC() )
	{
		// melee
		// maybe no need to disable melee...? I'm not sure about that... npcs ain't smart enough when activating ability
		/*
		if ( owner.GetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK1 ) ) // uncharged
		{
			owner.SetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK1, false )
			npcDisabledCapabilityFlags.append( bits_CAP_INNATE_MELEE_ATTACK1 )
		}
		if ( owner.GetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK2 ) ) // charged
		{
			owner.SetCapabilityFlag( bits_CAP_INNATE_MELEE_ATTACK2, false )
			npcDisabledCapabilityFlags.append( bits_CAP_INNATE_MELEE_ATTACK2 )
		}
		*/

		// gun fire
		/* 
		if ( owner.GetCapabilityFlag( bits_CAP_MOVE_SHOOT ) )
		{
			owner.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
			npcDisabledCapabilityFlags.append( bits_CAP_MOVE_SHOOT )
		}
		if ( owner.GetCapabilityFlag( bits_CAP_AIM_GUN ) )
		{
			owner.SetCapabilityFlag( bits_CAP_AIM_GUN, false )
			npcDisabledCapabilityFlags.append( bits_CAP_AIM_GUN )
		}
		*/
		if ( owner.GetCapabilityFlag( bits_CAP_WEAPON_RANGE_ATTACK1 ) )
		{
			owner.SetCapabilityFlag( bits_CAP_WEAPON_RANGE_ATTACK1, false )
			npcDisabledCapabilityFlags.append( bits_CAP_WEAPON_RANGE_ATTACK1 )
		}

		// movements
		if ( !owner.GetNPCMoveFlag( NPCMF_DISABLE_DANGEROUS_AREA_DISPLACEMENT ) )
		{
			owner.EnableNPCMoveFlag( NPCMF_DISABLE_DANGEROUS_AREA_DISPLACEMENT )
			npcEnabledMoveFlags.append( NPCMF_DISABLE_DANGEROUS_AREA_DISPLACEMENT )
		}
		if ( !owner.GetNPCMoveFlag( NPCMF_IGNORE_CLUSTER_DANGER_TIME ) )
		{
			owner.EnableNPCMoveFlag( NPCMF_IGNORE_CLUSTER_DANGER_TIME )
			npcEnabledMoveFlags.append( NPCMF_IGNORE_CLUSTER_DANGER_TIME )
		}
	}

	OnThreadEnd(
	function() : ( owner, weapon, rechargeDash, slowID, speedID, npcDisabledCapabilityFlags, npcEnabledMoveFlags )
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
				//MobileDomeShield_AllowNPCWeapons( owner, true )

				if ( owner.IsPlayer() && owner.IsTitan() && rechargeDash )
				{
					float amount = expect float( GetSettingsForPlayer_DodgeTable( owner )["dodgePowerDrain"] )
					owner.Server_SetDodgePower( min( 100.0, owner.GetDodgePower() + amount ) )
				}

				// modified for npc usage: restore disabled capability flags
				if ( owner.IsNPC() )
				{
					foreach ( int flag in npcDisabledCapabilityFlags )
						owner.SetCapabilityFlag( flag, true )
					foreach ( int flag in npcEnabledMoveFlags )
						owner.DisableNPCMoveFlag( flag )
				}
			}
		}
	)
	
	// NOTE here: this function only handled npc's melee attack, can't handle ranged attacks RN
	MobileDomeShield_AllowShootThrough( owner, weapon )

	// modified here: npc can start shooting after certain delay
	// welp, maybe just make them don't fire during full duration of ability...
	// npc's primary attack signal isn't implemented yet
	wait duration

	/*
	float npcDisableAttackTime = duration * NPC_DISABLE_ATTACK_DURATION_FRAC
	wait npcDisableAttackTime
	if ( owner.IsNPC() )
	{
		foreach ( int flag in npcDisabledCapabilityFlags )
			owner.SetCapabilityFlag( flag, true )
		foreach ( int flag in npcEnabledMoveFlags )
			owner.DisableNPCMoveFlag( flag )
		npcDisabledCapabilityFlags.clear() // so we don't clean up again in OnThreadEnd()
		npcEnabledMoveFlags.clear()
	}

	wait duration - npcDisableAttackTime
	*/

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
	// has been reworked with capability flags
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