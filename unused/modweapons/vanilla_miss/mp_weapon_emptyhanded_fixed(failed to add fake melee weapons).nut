global function MpWeaponEmptyHanded_Init

global function OnWeaponActivate_weapon_emptyhanded
global function OnWeaponDeactivate_weapon_emptyhanded

// less than this we'll consider re-deploy melee, so it can have proper anim time
const float PILOT_EMPTYHAND_ATTACK_ANIMTIME = 0.7 // actually 0.8

#if SERVER
const array<string> FAKE_MELEE_VALID_SOUNDS =
[
    "Pilot_Mvmt_Melee_RightHook_1P",
    "Pilot_Mvmt_Melee_LeftHook_1P",
    "Pilot_Mvmt_Melee_SlideKick_1P",
    "Pilot_Mvmt_Melee_WallKick_1P",
    "Pilot_Mvmt_Melee_Elbow_1P",
    "Pilot_Mvmt_Melee_AirKick_1P",
    "Pilot_Mvmt_Melee_Knee_1P",
    "Pilot_Mvmt_Melee_LeftHook_1P",
    "Pilot_Mvmt_Melee_UpperCut_1P",
]
#endif

void function MpWeaponEmptyHanded_Init()
{
    #if SERVER
        RegisterSignal( "MeleeDeactivate" )
        RegisterSignal( "TrackFakeMeleeEnd" )
    #endif
}

void function OnWeaponActivate_weapon_emptyhanded( entity weapon )
{
    #if SERVER
        float attackAnimTime = weapon.GetWeaponSettingFloat( eWeaponVar.melee_attack_animtime )
        if ( attackAnimTime > 0 ) // defensive fix!!!
        {
            if ( attackAnimTime < PILOT_EMPTYHAND_ATTACK_ANIMTIME )
                ModifiedMelee_ReDeployAfterTime( weapon ) // forced melee attack animtime
        }
    #endif

    // fake melee weapons
    array<string> mods = weapon.GetMods()
    foreach ( string mod in mods )
    {
        if ( mod.find( "fake_melee_" ) != null )
        {
            TryFakeMeleeWeaponAttack( weapon, mod )
            break
        }
    }
}

void function OnWeaponDeactivate_weapon_emptyhanded( entity weapon )
{
    #if SERVER
        weapon.Signal( "MeleeDeactivate" )
    #endif
}

bool function TryFakeMeleeWeaponAttack( entity weapon, string modName )
{
    print( "RUNNING TryFakeMeleeWeaponAttack()" )
    entity owner = weapon.GetWeaponOwner()
    if ( !owner.IsOnGround() )
        return false
    string modToApply = modName + "_model"
    if ( weapon.HasMod( modToApply ) )
        return false
    
    weapon.AddMod( modToApply )
    #if SERVER
        EmitSoundOnEntityOnlyToPlayer( weapon, owner, FAKE_MELEE_VALID_SOUNDS.getrandom() )
        thread TrackFakeMeleeEnd( weapon, modToApply )
    #endif
    return true
}

#if SERVER
void function TrackFakeMeleeEnd( entity weapon, string appliedMod )
{
    weapon.EndSignal( "OnDestroy" )
    weapon.Signal( "TrackFakeMeleeEnd" )
    weapon.EndSignal( "TrackFakeMeleeEnd" )

    weapon.WaitSignal( "MeleeDeactivate" )
    weapon.RemoveMod( appliedMod )
}
#endif