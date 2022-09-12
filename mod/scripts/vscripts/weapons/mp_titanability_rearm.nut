//TODO: FIX REARM WHILE FIRING SALVO ROCKETS

global function OnWeaponPrimaryAttack_titanability_rearm
global function OnWeaponAttemptOffhandSwitch_titanability_rearm

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanability_rearm
#endif

var function OnWeaponPrimaryAttack_titanability_rearm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	foreach( entity offhandweapon in weaponOwner.GetOffhandWeapons() )
	{
		if( offhandweapon.GetWeaponClassName() != "mp_titanability_rearm" )
		{
			if ( IsValid( offhandweapon ) )
			{
				#if SERVER
				if( offhandweapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield" && offhandweapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
					continue
				switch ( GetWeaponInfoFileKeyField_Global( offhandweapon.GetWeaponClassName(), "cooldown_type" ) )
				{
					case "grapple":
						weaponOwner.SetSuitGrapplePower( 100.0 )
					continue;

					case "ammo":
					case "ammo_instant":
					case "ammo_deployed":
					case "ammo_timed":
					case "ammo_per_shot":
						int maxAmmo = offhandweapon.GetWeaponPrimaryClipCountMax()

						offhandweapon.SetWeaponPrimaryClipCount( maxAmmo )
					continue;

					case "chargeFrac":
					case "charged_shot":
						offhandweapon.SetWeaponChargeFractionForced( 0 )
					continue;

					default:
						printt( offhandweapon.GetWeaponClassName() + " needs to be updated to support cooldown_type setting" )
					continue;
				}
				#endif
			}
		}
	}

	#if SERVER
	if ( weaponOwner.IsPlayer() && weaponOwner.IsTitan() )//weapon.HasMod( "rapid_rearm" ) &&  )
		weaponOwner.Server_SetDodgePower( 100.0 )
	#endif
	weapon.SetWeaponPrimaryClipCount( 0 )//used to skip the fire animation
	return 0
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanability_rearm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanability_rearm( weapon, attackParams )
}
#endif

bool function OnWeaponAttemptOffhandSwitch_titanability_rearm( entity weapon )
{

	bool allowSwitch = true
	entity weaponOwner = weapon.GetWeaponOwner()

	if( IsPilot( weaponOwner ) )
	{
		allowSwitch = true
	}

	else
	{
		entity ordnance = weaponOwner.GetOffhandWeapon( OFFHAND_RIGHT )
		entity defensive = weaponOwner.GetOffhandWeapon( OFFHAND_LEFT )

		if ( ordnance.GetWeaponPrimaryClipCount() == ordnance.GetWeaponPrimaryClipCountMax() && defensive.GetWeaponPrimaryClipCount() == defensive.GetWeaponPrimaryClipCountMax() )
			allowSwitch = false

		if ( ordnance.IsBurstFireInProgress() )
			allowSwitch = false

		if ( ordnance.IsChargeWeapon() && ordnance.GetWeaponChargeFraction() > 0.0 )
			allowSwitch = true

		//if ( weapon.HasMod( "rapid_rearm" ) )
		//{
			if ( weaponOwner.GetDodgePower() < 100 )
				allowSwitch = true
		//}
	}

	if( !allowSwitch && !IsPilot( weaponOwner ) && IsFirstTimePredicted() )
	{
		// Play SFX and show some HUD feedback here...
		#if CLIENT
			AddPlayerHint( 1.0, 0.25, $"rui/titan_loadout/tactical/titan_tactical_rearm", "#WPN_TITANABILITY_REARM_ERROR_HINT" )
			if ( weaponOwner == GetLocalViewPlayer() )
				EmitSoundOnEntity( weapon, "titan_dryfire" )
		#endif
	}

	return allowSwitch
}

//UPDATE TO RESTORE CHARGE FOR THE MTMS