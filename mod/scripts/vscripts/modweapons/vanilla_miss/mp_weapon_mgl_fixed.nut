// vanilla missing MpWeaponMGL_Init
global function MpWeaponMGL_Init

void function MpWeaponMGL_Init()
{
#if SERVER
	// modded weapon mod: grenade_arc_on_ads
	// gives ar_trajectory on weapon ads, similar to softball ads arc
	RegisterSignal( "AwaitingWeaponOwnerADSEnd" )
	RegisterSignal( "MGLZoomOut" )
#endif
}