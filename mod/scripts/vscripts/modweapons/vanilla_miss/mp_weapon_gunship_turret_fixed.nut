// vanilla missing mp_weapon_gunship_turret.nut
global function MpWeaponGunshipTurret_Init

#if SERVER
global function OnWeaponNpcPrimaryAttack_gunship_turret
#endif

void function MpWeaponGunshipTurret_Init()
{
#if SERVER
    // respawn assigned damage source display name twice for mp_weapon_gunship_turret
    // the one that should be assigned for mp_weapon_gunship_missile has been assigned to this weapon...
    RegisterWeaponDamageSource( "mp_weapon_gunship_turret_fixed", "#WPN_GUNSHIP_TURRET" )
    // fix method is to change damageSourceId of mp_weapon_gunship_turret to mp_weapon_gunship_turret_fixed
    AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_gunship_turret, OnGunshipTurretDealDamage )
#endif

    // there're also another way to fix it
    // for clients that have installed the mod, this is a fix for gunship turret damageSource display name
    //RegisterWeaponDamageSourceName( "mp_weapon_gunship_turret", "#WPN_GUNSHIP_TURRET" )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_gunship_turret( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    // manually play a muzzle flash fx
    weapon.PlayWeaponEffect( $"", $"wpn_muzzleflash_sentry", "muzzle_flash" )

    int damageFlags = weapon.GetWeaponDamageFlags()
    weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, damageFlags )
    return 1
}

// fix damageSourceId display name
void function OnGunshipTurretDealDamage( entity victim, var damageInfo )
{
    // change to fixed damageSourceId
    DamageInfo_SetDamageSourceIdentifier( damageInfo, eDamageSourceId.mp_weapon_gunship_turret_fixed )
}
#endif