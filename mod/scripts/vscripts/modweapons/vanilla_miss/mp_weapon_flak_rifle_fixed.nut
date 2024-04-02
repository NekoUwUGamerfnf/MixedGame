untyped
global function MpWeaponFlakRifle_Init

void function MpWeaponFlakRifle_Init()
{
#if SERVER
	// now using missile.ProjectileSetDamageSourceID( eDamageSourceId.mp_weapon_flak_rifle ), no need to hack this
	//AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_vinson, OnDamagedTarget_FlakRifle )
	// vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_vinson", // weapon name
		"flak_rifle", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_smr", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_smr", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"rocket" // refire behavior
	)
	// flak_cannon
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_vinson", // weapon name
		"flak_cannon", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"rocket" // refire behavior
	)

	// burnmod blacklist
    ModdedBurnMods_AddDisabledMod( "flak_rifle" )
	ModdedBurnMods_AddDisabledMod( "flak_cannon" )

	// retain damage mod on refired by vortex
	Vortex_AddWeaponModRetainedOnRefire( "mp_weapon_vinson", "flak_rifle" )
	Vortex_AddWeaponModRetainedOnRefire( "mp_weapon_vinson", "flak_cannon" )

	// keep mod data on refired by vortex
	Vortex_AddProjectileModToKeepDataOnRefire( "flak_rifle" )
	Vortex_AddProjectileModToKeepDataOnRefire( "flak_cannon" )
#endif
}

#if SERVER
void function OnDamagedTarget_FlakRifle( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( !IsValid( attacker ) )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if( !IsValid( inflictor ) )
		return
	if( !inflictor.IsProjectile() )
		return

	if( !inflictor.IsProjectile() )
		return
	
	array<string> mods = Vortex_GetRefiredProjectileMods( inflictor ) // modded weapon refire behavior

	if( mods.contains( "flak_rifle" ) )
	{
		PROTO_Flak_Rifle_DamagedPlayerOrNPC( ent, damageInfo )
	}
}
#endif