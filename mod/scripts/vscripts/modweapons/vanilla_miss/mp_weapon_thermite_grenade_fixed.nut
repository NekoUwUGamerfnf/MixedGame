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
    RegisterWeaponDamageSource( "mp_weapon_thermite_grenade_dot", "#SP_TITAN_LOADOUT_SUBTITLE_SCORCH" ) // "Thermite"

    ThermiteDot_AddProjectileMod( 
        "thermite_grenade_dot",                         // weapon mod name
        eDamageSourceId.mp_weapon_thermite_grenade,     // damageSourceId( for checking )
        THERMITE_GRENADE_DOT_DURATION,                  // dot duration
        THERMITE_GRENADE_DOT_DAMAGE,                    // dot damage
        THERMITE_GRENADE_DOT_DAMAGE_HEAVY_ARMOR,        // dot damage heavyarmor
        THERMITE_GRENADE_DOT_DAMAGE_FINAL,              // dot damage on ent
        THERMITE_GRENADE_DOT_TICK,                      // dot damage tickrate
        THERMITE_GRENADE_DOT_STACK_INTERVAL,            // dot stack inverval
        THERMITE_GRENADE_DOT_STACK_MAX,                 // dot max stacks
        eDamageSourceId.mp_weapon_thermite_grenade_dot  // dot damage source override
    )

    // retain damage mod on refired by vortex
	Vortex_AddWeaponModRetainedOnRefire( "mp_weapon_thermite_grenade", "thermite_grenade_dot" )

    // keep mod data on refired by vortex
	Vortex_AddProjectileModToKeepDataOnRefire( "thermite_grenade_dot" )
#endif
}