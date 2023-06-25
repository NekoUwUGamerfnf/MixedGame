// vanilla missing MpWeaponMGL_Init
global function MpWeaponMGL_Init

void function MpWeaponMGL_Init()
{
#if SERVER
    // burnmod blacklist
    ModdedBurnMods_AddDisabledMod( "tripwire_launcher" )
	ModdedBurnMods_AddDisabledMod( "flesh_magnetic" )
    ModdedBurnMods_AddDisabledMod( "magnetic_rollers" )
#endif
}