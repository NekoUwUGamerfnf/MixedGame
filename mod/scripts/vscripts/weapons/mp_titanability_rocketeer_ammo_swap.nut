// Vanilla not implement this
// requires client-side installation
// most stuffs compied from brute4 mp_titanability_cluster_payload

global function OnWeaponPrimaryAttack_rocketeer_ammo_swap
global function MpTitanAbilityRocketeerAmmoSwap_Init

#if SERVER
global function OnWeaponNpcPrimaryAttack_rocketeer_ammo_swap
#endif

void function MpTitanAbilityRocketeerAmmoSwap_Init()
{
}

var function OnWeaponPrimaryAttack_rocketeer_ammo_swap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if ( weapon.HasMod( "brute4_cluster_payload" ) )
		return OnWeaponPrimaryAttack_cluster_payload( weapon, attackParams )
	//

	// vanilla( actually modified ) behavior
	entity weaponOwner = weapon.GetWeaponOwner()
	array<entity> weapons = weaponOwner.GetMainWeapons()
	if ( weapons.len() < 1 )
		return false
	
	entity primaryWeapon = weapons[0]
	/* // this is bad, no need to handle
	entity primaryWeapon = null
	foreach( entity weapon in weapons )
	{
		if( weapon.GetWeaponClassName() == "mp_titanweapon_rocketeer_rocketstream" )
			primaryWeapon = weapon
	}
	*/

	if ( !IsValid( primaryWeapon ) )
		return false
	else if ( weaponOwner.ContextAction_IsActive() )
		return false
	else if ( primaryWeapon.GetWeaponClassName() != "mp_titanweapon_rocketeer_rocketstream" )
		return false
	else if ( primaryWeapon.HasMod( "burn_mod_titan_rocket_launcher" ) )
		return false
	// re-implement vanilla mini_clusters
	else if ( primaryWeapon.HasMod( "mini_clusters" ) )
		return false
	// remove ads check, it can make weapon handling feels bad
	// we will remove fast shot in SwapRocketAmmo()
	//else if( primaryWeapon.IsWeaponInAds() )
	//	return false

	// brute4 defensive fix( hardcoded )
	if ( primaryWeapon.HasMod( "brute4_quad_rocket" ) )
		return false

	#if SERVER
		thread SwapRocketAmmo( weaponOwner, weapon, primaryWeapon )
	#endif

	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	return weapon.GetAmmoPerShot()
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_rocketeer_ammo_swap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if ( weapon.HasMod( "brute4_cluster_payload" ) )
		return OnWeaponPrimaryAttack_cluster_payload( weapon, attackParams )
	//

	// vanilla( actually modified ) behavior
	OnWeaponPrimaryAttack_rocketeer_ammo_swap( weapon, attackParams )
}

void function SwapRocketAmmo( entity weaponOwner, entity offhand, entity weapon )
{
	weapon.EndSignal( "OnDestroy" )
	offhand.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "DisembarkingTitan" )

	EmitSoundOnEntity( weaponOwner, "Coop_AmmoBox_AmmoRefill" )

	if ( weaponOwner.IsNPC() && HasAnim( weaponOwner, "at_reload_quick" ) )
	{
		weaponOwner.Anim_ScriptedPlay( "at_reload_quick" )
	}

	array<string> mods = weapon.GetMods()
	mods.append( "fast_reload" )

	// re-implement vanilla mini_clusters
	mods.append( "mini_clusters" )
	mods.fastremovebyvalue( "rocketstream_fast" )

	weapon.SetMods( mods )

	offhand.AddMod( "no_regen" )

	weapon.SetWeaponPrimaryClipCount( 0 )
	// no matter weapon reloading or not, we always re-deploy current weapon to make player reload
	// that should only happen on player, npcs don't have such method...
	if ( weaponOwner.IsPlayer() )
	{
		weapon.AddMod( "fast_deploy" )
		weaponOwner.HolsterWeapon()
		weaponOwner.DeployWeapon()
		weapon.RemoveMod( "fast_deploy" )
	}

	OnThreadEnd(
	function() : ( weaponOwner, weapon, offhand )
		{
			if ( IsValid( weapon ) )
			{
				array<string> mods = weapon.GetMods()
				// clean up
				mods.fastremovebyvalue( "fast_reload" )
				mods.fastremovebyvalue( "mini_clusters" )

				weapon.SetMods( mods )
			}
			
			if ( IsValid( offhand ) )
				offhand.RemoveMod( "no_regen" )
		}
	)

	// We want the reload speed buff to stay until the reload is finished.
	// The weapon will not be reloading if something lowers it, so this more reliably waits until the weapon is reloaded than checking the IsReloading function.
	while ( weapon.GetWeaponPrimaryClipCount() == 0 )
		WaitFrame()

	mods = weapon.GetMods()
	mods.fastremovebyvalue( "fast_reload" )
	weapon.SetMods( mods )

	if ( weaponOwner.IsPlayer() )
	{
		// Check reload index to avoid stopping thread on canceled reloads, but catch non-empty reloads
		while ( weapon.GetReloadMilestoneIndex() == 0 && weapon.GetWeaponPrimaryClipCount() > 0 )
			WaitFrame()
	}
	else
	{
		while ( weapon.GetWeaponPrimaryClipCount() > 0 )
		WaitFrame()
	}
}
#endif