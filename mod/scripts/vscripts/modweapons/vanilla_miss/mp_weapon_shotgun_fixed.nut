// vanilla missing MpWeaponShotgun_Init

global function MpWeaponShotgun_Init

void function MpWeaponShotgun_Init()
{
    // calculate damage manually to get rid of "damage_falloff_type" "inverse"
    #if SERVER
        AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_shotgun, OnShotgunDamageTarget )
    #endif
}

#if SERVER
void function OnShotgunDamageTarget( entity ent, var damageInfo )
{
    // calculate damage manually to get rid of "damage_falloff_type" "inverse"
    entity weapon = DamageInfo_GetWeapon( damageInfo )
    if ( !IsValid( weapon ) )
        return

    if ( weapon.HasMod( "twin_slug" ) )
    {
        // modifydamage using force calculated value
        ModifyDamageInfoWithCalculatedDamage( weapon, ent, damageInfo )
    }
}
#endif