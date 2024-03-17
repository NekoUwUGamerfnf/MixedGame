//TODO: FIX REARM WHILE FIRING SALVO ROCKETS

// modified callbacks
global function OnWeaponChargeBegin_titanability_rearm

global function OnWeaponPrimaryAttack_titanability_rearm
global function OnWeaponAttemptOffhandSwitch_titanability_rearm

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanability_rearm
#endif

// modified callbacks
bool function OnWeaponChargeBegin_titanability_rearm( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	if ( !weaponOwner.IsPlayer() )
		return true
	// basic checks handled by OnWeaponAttemptOffhandSwitch_titanability_rearm()
	// respawn hardcode... these runs on client so have to check OFFHAND_LEFT on charge begin, or it will crash if weapon not using clip
#if SERVER
	entity ordnance = weaponOwner.GetOffhandWeapon( OFFHAND_RIGHT )
	if ( IsValid( ordnance ) )
	{
		try { ordnance.SetWeaponPrimaryClipCount( ordnance.GetWeaponPrimaryClipCount() ) }
		catch ( ex ) // once reaches here means defensive is not a clip weapon
		{ 
			//print( "ordnance can't use ammo clip!" )
			thread DelayedFakeRearmPlayer( weaponOwner, weapon )
			return true
		}
	}
	entity defensive = weaponOwner.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( defensive ) )
	{
		try { defensive.SetWeaponPrimaryClipCount( defensive.GetWeaponPrimaryClipCount() ) }
		catch ( ex ) // once reaches here means defensive is not a clip weapon
		{ 
			//print( "defensive can't use ammo clip!" )
			thread DelayedFakeRearmPlayer( weaponOwner, weapon )
			return true
		} 
	}
#endif
	return true
}

#if SERVER
void function DelayedFakeRearmPlayer( entity player, entity rearmWeapon )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	rearmWeapon.EndSignal( "OnDestroy" )

	OnThreadEnd
	(
		function(): ( player )
		{
			if ( IsValid( player ) )
			{
				//player.EnableWeaponViewModel()
				//player.Server_TurnOffhandWeaponsDisabledOff()
				DeployViewModelAndEnableWeapons( player ) 
			}
		}
	)

	float rearmDuration = rearmWeapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	// function HolsterAndDisableWeapons() now has stack system for HolsterWeapon() method... no need to loop anymore I think
	/*
	float endTime = Time() + rearmDuration
	// holster weapon until we can do rearm
	while ( Time() < endTime )
	{
		player.DisableWeaponViewModel()
		player.Server_TurnOffhandWeaponsDisabledOn()
		WaitFrame() // may get a bit longer rearm since script is 10fps
	}
	*/
	HolsterViewModelAndDisableWeapons( player )
	wait rearmDuration

	PlayerUsedOffhand( player, rearmWeapon )
	RearmOwner( player )
	rearmWeapon.SetWeaponPrimaryClipCountAbsolute( 0 )
}
#endif
// end

var function OnWeaponPrimaryAttack_titanability_rearm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	/* // respawn hardcode... these runs on client so have to check OFFHAND_LEFT on charge begin, or it will crash if weapon not using clip
	entity ordnance = weaponOwner.GetOffhandWeapon( OFFHAND_RIGHT )
	if ( IsValid( ordnance ) )
	{
		ordnance.SetWeaponPrimaryClipCount( ordnance.GetWeaponPrimaryClipCountMax() )
		#if SERVER
		if ( ordnance.IsChargeWeapon() )
			ordnance.SetWeaponChargeFractionForced( 0 )
		#endif
	}
	entity defensive = weaponOwner.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( defensive ) )
		defensive.SetWeaponPrimaryClipCount( defensive.GetWeaponPrimaryClipCountMax() )

#if SERVER
	if ( weaponOwner.IsPlayer() && weaponOwner.IsTitan() )//weapon.HasMod( "rapid_rearm" ) &&  )
		weaponOwner.Server_SetDodgePower( 100.0 )
#endif
	*/

	RearmOwner( weaponOwner )
	
	weapon.SetWeaponPrimaryClipCount( 0 )//used to skip the fire animation
	return 0
}

void function RearmOwner( entity weaponOwner )
{
	// restore ammo
	foreach( entity offhandweapon in weaponOwner.GetOffhandWeapons() )
	{
		if( offhandweapon.GetWeaponClassName() != "mp_titanability_rearm" )
		{
			if ( IsValid( offhandweapon ) )
			{
				if( offhandweapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
					continue
				switch ( GetWeaponInfoFileKeyField_Global( offhandweapon.GetWeaponClassName(), "cooldown_type" ) )
				{
					case "grapple":
						#if SERVER
							weaponOwner.SetSuitGrapplePower( 100.0 )
						#endif
						continue

					case "ammo":
					case "ammo_instant":
					case "ammo_deployed":
					case "ammo_timed":
					case "ammo_per_shot":
						int maxAmmo = offhandweapon.GetWeaponPrimaryClipCountMax()

						offhandweapon.SetWeaponPrimaryClipCount( maxAmmo )
						continue

					case "chargeFrac":
					case "charged_shot":
					case "vortex_drain":
						#if SERVER
							offhandweapon.SetWeaponChargeFractionForced( 0 )
						#endif
						continue

					default:
						//printt( offhandweapon.GetWeaponClassName() + " needs to be updated to support cooldown_type setting" )
						continue
				}
			}
		}
	}

#if SERVER
	if ( weaponOwner.IsPlayer() && weaponOwner.IsTitan() )//weapon.HasMod( "rapid_rearm" ) &&  )
		weaponOwner.Server_SetDodgePower( 100.0 )
#endif
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

	int requiredOffhandCount 
	int fullOffhandCount
	for( int i = 0; i <= OFFHAND_ANTIRODEO; i++ ) // rechargable offhand up to OFFHAND_ANTIRODEO
	{
		entity offhandweapon = weaponOwner.GetOffhandWeapon( i )
		if( !IsValid( offhandweapon ) )
			continue
		// rearm itself is not included
		if( offhandweapon.GetWeaponClassName() == "mp_titanability_rearm" ) 
			continue

		// salvo rockets/ locking rockets is firing, this can't be able to switch!
		if ( offhandweapon.IsBurstFireInProgress() ) 
		{
			//print( offhandweapon.GetWeaponClassName() + " is in burstFire!!" )
			allowSwitch = false
			break
		}

		// never recharges ion vortex	
		if( offhandweapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield_ion" )
			continue

		requiredOffhandCount += 1 // valid offhand, requirement +1

		switch ( GetWeaponInfoFileKeyField_Global( offhandweapon.GetWeaponClassName(), "cooldown_type" ) )
		{
			case "grapple":
				if( weaponOwner.GetSuitGrapplePower() >= 100.0 )
					fullOffhandCount += 1
				continue

			case "ammo":
			case "ammo_instant":
			case "ammo_deployed":
			case "ammo_timed":
			case "ammo_per_shot":
				// fully charged ammo weapons
				if( offhandweapon.GetWeaponPrimaryClipCount() == offhandweapon.GetWeaponPrimaryClipCountMax() )
					fullOffhandCount += 1
				continue

			case "chargeFrac":
			case "charged_shot":
			case "vortex_drain":
				// fully charged charge weapons
				if( offhandweapon.GetWeaponChargeFraction() == 0 )
					fullOffhandCount += 1
				continue

			default:
				continue
		}
	}
	//print( "offhands those are full: " + string( fullOffhandCount ) )
	//print( "fully charged offhands required: " + string( requiredOffhandCount ) )
	// every offhand except rearm is full!
	if( fullOffhandCount >= requiredOffhandCount ) 
		allowSwitch = false

	// always letting players recharge dodge
	if ( weaponOwner.GetDodgePower() < 100 ) 
		allowSwitch = true

	/* // respawn hardcode...
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
	*/

	if( !allowSwitch && IsFirstTimePredicted() )
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