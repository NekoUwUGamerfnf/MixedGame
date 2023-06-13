// vanilla missing MpWeaponEPG_Init()
global function MpWeaponEPG_Init

global function OnProjectileCollision_weapon_epg

void function MpWeaponEPG_Init()
{

}

void function OnProjectileCollision_weapon_epg( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
    // modded weapon
    OnProjectileCollision_Tediore( projectile, pos, normal, hitEnt, hitbox, isCritical ) // always call this, for tediore_reload to work

    array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
    if ( mods.contains( "direct_hit" ) )
        OnProjectileCollision_DirectHit( projectile, pos, normal, hitEnt, hitbox, isCritical )
}