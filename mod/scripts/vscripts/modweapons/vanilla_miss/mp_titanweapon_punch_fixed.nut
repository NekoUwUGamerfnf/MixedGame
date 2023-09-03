global function MpTitanWeaponPunch_Init

global function OnWeaponActivate_titanweapon_punch

// less than this we'll consider re-deploy melee, so it can have proper anim time
const float TITAN_EMPTYHAND_ATTACK_ANIMTIME = 0.7 // actually 0.8
const float TITAN_DASH_PUNCH_ATTACK_ANIMTIME = 1.6 // actually 1.7
const float TITAN_ELECTRIC_FIST_ATTACK_ANIMTIME = 1.1 // actually 1.23

void function MpTitanWeaponPunch_Init()
{

}

void function OnWeaponActivate_titanweapon_punch( entity weapon )
{
    #if SERVER
        float attackAnimTime = weapon.GetWeaponSettingFloat( eWeaponVar.melee_attack_animtime )
        if ( attackAnimTime > 0 ) // defensive fix!!!
        {
            float minAnimTime = TITAN_EMPTYHAND_ATTACK_ANIMTIME
            switch ( weapon.GetWeaponSettingInt( eWeaponVar.melee_anim_1p_number ) )
            {
                case 1: // normal punch
                    minAnimTime = TITAN_EMPTYHAND_ATTACK_ANIMTIME
                    break
                case 2:
                    minAnimTime = TITAN_DASH_PUNCH_ATTACK_ANIMTIME
                    break
                case 3:
                    minAnimTime = TITAN_ELECTRIC_FIST_ATTACK_ANIMTIME
                    break
            }
            if ( attackAnimTime < minAnimTime )
                ModifiedMelee_ReDeployAfterTime( weapon ) // forced melee attack animtime
        }
    #endif
}