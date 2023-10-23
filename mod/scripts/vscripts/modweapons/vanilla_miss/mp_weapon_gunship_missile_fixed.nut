// vanilla missing MpWeaponGunshipMissile_Init
global function MpWeaponGunshipMissile_Init

void function MpWeaponGunshipMissile_Init()
{
#if SERVER
    // respawn assigned incorrect damage source display name for mp_weapon_gunship_missile
    // instead, mp_weapon_gunship_turret will display as #WPN_GUNSHIP_MISSILE
    // quite funny, isn't it?
    RegisterWeaponDamageSource( "mp_weapon_gunship_missile_fixed", "#WPN_GUNSHIP_MISSILE" )
#endif
}