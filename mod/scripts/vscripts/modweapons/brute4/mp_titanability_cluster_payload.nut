global function MpTitanAbilityClusterPayload_Init

global function OnWeaponPrimaryAttack_cluster_payload

#if SERVER
global function OnWeaponNpcPrimaryAttack_cluster_payload
#endif

void function MpTitanAbilityClusterPayload_Init()
{
}

var function OnWeaponPrimaryAttack_cluster_payload( entity weapon, WeaponPrimaryAttackParams attackParams )
{
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
    else if ( !primaryWeapon.HasMod( "brute4_quad_rocket" ) )
        return false
	else if ( primaryWeapon.HasMod( "brute4_cluster_payload_ammo" ) )
		return false

	#if SERVER
		thread SwapRocketAmmo( weaponOwner, weapon, primaryWeapon )
	#else
		//primaryWeapon.SetWeaponPrimaryClipCount( 0 ) // force client to start reload. unstable, fixed by re-deploy weapon
	#endif

	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	return weapon.GetAmmoPerShot()
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_cluster_payload( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_cluster_payload( weapon, attackParams )
}

void function SwapRocketAmmo( entity weaponOwner, entity offhand, entity weapon )
{
	weapon.EndSignal( "OnDestroy" )
	offhand.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "DisembarkingTitan" )

	EmitSoundOnEntity( weaponOwner, "Coop_AmmoBox_AmmoRefill" )
	#if SERVER
		//SendHudMessage(weaponOwner, "将弹药切换为小型集束炸弹", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
	#endif

	if ( weaponOwner.IsNPC() && HasAnim( weaponOwner, "at_reload_quick" ) )
	{
		weaponOwner.Anim_ScriptedPlay( "at_reload_quick" )
	}

	array<string> mods = weapon.GetMods()
	mods.append( "fast_reload" )

	// brute4 cases
    mods.append( "brute4_cluster_payload_ammo" )
    if ( mods.contains( "rapid_detonator" ) )
        mods.append( "rapid_detonator_active" )
    mods.fastremovebyvalue( "brute4_single_shot" )

	weapon.SetMods( mods )

	offhand.AddMod( "no_regen" )
	weapon.SetWeaponPrimaryClipCount( 0 )
	// no matter weapon reloading or not, we always re-deploy current weapon to make player reload
	//if ( weapon.IsReloading() )
	//{
		weapon.AddMod( "fast_deploy" )
		weaponOwner.HolsterWeapon()
		weaponOwner.DeployWeapon()
		weapon.RemoveMod( "fast_deploy" )
	//}

	OnThreadEnd(
	function() : ( weaponOwner, weapon, offhand )
		{
			if ( IsValid( weapon ) )
			{
				array<string> mods = weapon.GetMods()
				// brute4
				mods.fastremovebyvalue( "brute4_cluster_payload_ammo" )
				mods.fastremovebyvalue( "rapid_detonator_active" )
				mods.fastremovebyvalue( "fast_reload" )

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