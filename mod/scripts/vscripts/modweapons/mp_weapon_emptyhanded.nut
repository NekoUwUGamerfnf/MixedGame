global function MpWeaponEmptyHanded_Init

global function OnWeaponActivate_weapon_emptyhanded

// less than this we'll consider re-deploy melee, so it can have proper anim time
const float PILOT_EMPTYHAND_ATTACK_ANIMTIME = 0.7 // actually 0.8

void function MpWeaponEmptyHanded_Init()
{

}

void function OnWeaponActivate_weapon_emptyhanded( entity weapon )
{
    #if SERVER
        float attackAnimTime = weapon.GetWeaponSettingFloat( eWeaponVar.melee_attack_animtime )
        if ( attackAnimTime <= 0 ) // defensive fix!!!
            return

        if ( attackAnimTime < PILOT_EMPTYHAND_ATTACK_ANIMTIME )
            ModifiedMelee_ReDeployAfterTime( weapon ) // forced melee attack animtime
    #endif
}