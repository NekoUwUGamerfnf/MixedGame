// vanilla "mp_weapon_thermite_grenade.nut" missing
global function MpWeaponThermiteGrenade_Init

// thermite_grenade_dot, total of 25 damage
const float THERMITE_GRENADE_DOT_DURATION = 3.0 // better be a multipiler of THERMITE_DOT_TICK
const int THERMITE_GRENADE_DOT_DAMAGE = 4
const int THERMITE_GRENADE_DOT_DAMAGE_HEAVY_ARMOR = 40
const int THERMITE_GRENADE_DOT_DAMAGE_FINAL = 1
const float THERMITE_GRENADE_DOT_TICK = 0.5
const float THERMITE_GRENADE_DOT_STACK_INTERVAL = 0.4
const int THERMITE_GRENADE_DOT_STACK_MAX = 4

void function MpWeaponThermiteGrenade_Init()
{
#if SERVER
    // for "thermite_grenade_dot"
    ThermiteDot_AddProjectileMod( 
        "thermite_grenade_dot", 
        eDamageSourceId.mp_weapon_thermite_grenade,
        THERMITE_GRENADE_DOT_DURATION, 
        THERMITE_GRENADE_DOT_DAMAGE, 
        THERMITE_GRENADE_DOT_DAMAGE_HEAVY_ARMOR, 
        THERMITE_GRENADE_DOT_DAMAGE_FINAL, 
        THERMITE_GRENADE_DOT_TICK, 
        THERMITE_GRENADE_DOT_STACK_INTERVAL, 
        THERMITE_GRENADE_DOT_STACK_MAX
    )
#endif
}