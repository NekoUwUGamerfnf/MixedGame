// vanilla missing file, exsiting for better modding
global function MpWeaponFragGrenade_Init

void function MpWeaponFragGrenade_Init()
{
    Grenade_AddChargeDisabledMod( "frag_no_charge" )
    Grenade_AddDropOnCancelDisabledMod( "frag_no_charge" )
}