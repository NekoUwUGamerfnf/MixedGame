// vanilla missing MpWeaponGibberPistol_Init
global function MpWeaponGibberPistol_Init

void function MpWeaponGibberPistol_Init()
{
#if SERVER
    // vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_semipistol", // weapon name
		"gibber_pistol", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_softball", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_softball", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"grenade" // refire behavior
	)
    // grenade pistol
    Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_semipistol", // weapon name
		"grenade_pistol", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"grenade" // refire behavior
	)

	// burnmod blacklist
    ModdedBurnMods_AddDisabledMod( "gibber_pistol" )
	ModdedBurnMods_AddDisabledMod( "grenade_pistol" )

	// retain damage mod on refired by vortex
	Vortex_AddWeaponModRetainedOnRefire( "mp_weapon_semipistol", "gibber_pistol" )
	Vortex_AddWeaponModRetainedOnRefire( "mp_weapon_semipistol", "grenade_pistol" )

	// keep mod data on refired by vortex
	Vortex_AddProjectileModToKeepDataOnRefire( "gibber_pistol" )
	Vortex_AddProjectileModToKeepDataOnRefire( "grenade_pistol" )
#endif
}