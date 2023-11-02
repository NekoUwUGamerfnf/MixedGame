// vanilla missing MpWeaponMGL_Init
global function MpWeaponMGL_Init

void function MpWeaponMGL_Init()
{
#if SERVER
    // burnmod blacklist
    ModdedBurnMods_AddDisabledMod( "tripwire_launcher" )
	//ModdedBurnMods_AddDisabledMod( "flesh_magnetic" )
    //ModdedBurnMods_AddDisabledMod( "magnetic_rollers" )

    // vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_weapon_mgl", // weapon name
		"tripwire_launcher", // mod name
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect" ), // absorb effect
		GetWeaponInfoFileKeyFieldAsset_Global( "mp_weapon_mgl", "vortex_absorb_effect_third_person" ), // absorb effect 3p
		"absorb" // refire behavior
	)

	// modded weapon mod: grenade_arc_on_ads
	// gives ar_trajectory on weapon ads, similar to softball ads arc
	RegisterSignal( "AwaitingWeaponOwnerADSEnd" )
	RegisterSignal( "MGLZoomOut" )
#endif
}