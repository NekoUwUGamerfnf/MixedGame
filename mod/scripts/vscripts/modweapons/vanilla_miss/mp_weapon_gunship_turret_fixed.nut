// vanilla missing mp_weapon_gunship_turret.nut
global function MpWeaponGunshipTurret_Init

#if SERVER
global function OnWeaponNpcPrimaryAttack_gunship_turret
#endif

void function MpWeaponGunshipTurret_Init()
{
    // respawn assigned damage source display name twice for mp_weapon_gunship_turret
    // the one that should be assigned for mp_weapon_gunship_missile has been assigned to this weapon...
    // for clients that have installed the mod, this is a fix for gunship turret damageSource display name
    RegisterWeaponDamageSourceName( "mp_weapon_gunship_turret", "#WPN_GUNSHIP_TURRET" )
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
#endif