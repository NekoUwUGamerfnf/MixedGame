// vanilla missing MpWeaponLMG_Init
global function MpWeaponLMG_Init

void function MpWeaponLMG_Init()
{
#if SERVER
    // burnmod replace
	ModdedBurnMods_AddReplacementBurnMod( "apex_rampage", "burn_mod_apex_rampage" )
#endif
}