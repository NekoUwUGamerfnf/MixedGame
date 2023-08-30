// vanilla missing file, exsiting for better modding
global function MpWeaponFragGrenade_Init

global function OnWeaponTossReleaseAnimEvent_weapon_frag_grenade
global function OnProjectileExplode_weapon_frag_grenade

void function MpWeaponFragGrenade_Init()
{
    Grenade_AddChargeDisabledMod( "frag_no_charge" )
    Grenade_AddDropOnCancelDisabledMod( "frag_no_charge" )
    
    Grenade_AddDropOnCancelDisabledMod( "nessie_grenade" )
}

var function OnWeaponTossReleaseAnimEvent_weapon_frag_grenade( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    // base grenade modifiers
    entity grenade = Grenade_OnWeaponToss_ReturnEntity( weapon, attackParams )
    if ( grenade )
    {
        if ( weapon.HasMod( "nessie_grenade" ) )
            grenade.SetModel( $"models/domestic/nessy_doll.mdl" )
    }
	//

    return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnProjectileExplode_weapon_frag_grenade( entity frag )
{
#if SERVER
    PlayFX( $"P_impact_exp_FRAG_air" ,frag.GetOrigin(), < 0,0,0 > )
	EmitSoundAtPosition( TEAM_UNASSIGNED, frag.GetOrigin(), "explo_fraggrenade_impact_3p_int" )
	//"explo_fraggrenade_impact_3p_int"
	//"explo_fraggrenade_impact_1p_OLD" //ttf1 sound! but volume so low...
	//"corporate_spectre_death_explode"
	
    //EmitSoundAtPosition( TEAM_UNASSIGNED, frag.GetOrigin(), "Titan.ARLRocket_Explosion_1P_vs_3P" )
    //EmitSoundAtPosition( TEAM_UNASSIGNED, frag.GetOrigin(), "Default.ClusterRocket_Primary_Explosion_1P_vs_3P" )
    //EmitSoundAtPosition( TEAM_UNASSIGNED, frag.GetOrigin(), "Default.ClusterRocket_Primary_Explosion_3P_vs_3P" )
    //EmitSoundAtPosition( TEAM_UNASSIGNED, frag.GetOrigin(), "Explo_TripleThreat_Impact_1P" )
    //EmitSoundAtPosition(  TEAM_UNASSIGNED, frag.GetOrigin(), "Explo_40mm_Impact_3P" )
    //"Explo_TripleThreat_Impact_3P"
    //"Explo_FragGrenade_Impact_1P"
    //"Default.ClusterRocket_Explosion_3P_vs_3P"
    //"Wpn_TetherTrap_Explode"
    //"explo_40mm_splashed_impact_3p"
    //"explo_softball_impact_3p"
    //"Default.Rocket_Explosion_3P_vs_3P"
    //"s2s_goblin_explode"
    //"explo_spectremortar_impact_3p"
    //"Default.ClusterRocket_Primary_Explosion_3P_vs_3P"
#endif
}