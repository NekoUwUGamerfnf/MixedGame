untyped // almost everything is hardcoded in this file!

global function TitanPick_Init

global function DropPlayerTitanWeapon
global function GiveDroppedTitanWeapon

global struct TitanWeaponStruct
{
    string weaponClassname
    string weaponName
    entity weaponModel
    array<string> weaponMods
    int weaponAmmo
    int weaponSkin
    int weaponCamo
}

global array<TitanWeaponStruct> droppedWeapons = []

void function TitanPick_Init() 
{
    #if SERVER
    AddCallback_OnPlayerKilled( OnTitanKilled )
    AddCallback_OnNPCKilled( OnTitanKilled )
    #endif
}

#if SERVER
void function OnTitanKilled( entity victim, entity attacker,var damageInfo )
{
    if( !victim.IsTitan() )
        return
    if( victim.GetModelName() == $"models/titans/buddy/titan_buddy.mdl" )
        return
    DropPlayerTitanWeapon( victim )
}

void function DropPlayerTitanWeapon( entity player, vector droppoint = < 9999,9999,9999 >, vector dropangle = < 9999,9999,9999 > ) 
{
    thread DropPlayerTitanWeapon_Threaded( player, droppoint, dropangle )
}

void function DropPlayerTitanWeapon_Threaded( entity player, vector droppoint, vector dropangle )
{
    array < entity > weapons = player.GetMainWeapons()
    if( droppoint == < 9999,9999,9999 > )
    {
        droppoint = player.GetOrigin() + < 0,0,10 > //< -70,-20,20 >
    }
    if( dropangle == < 9999,9999,9999 > )
    {
        dropangle = player.GetAngles() + < 0,0,10 >
        dropangle.x = 0
        dropangle.z = 90
    }
    
    if ( IsValid(player) && weapons.len() != 0 ) 
    {
        if ( IsValid(weapons[0]) )
        {
            asset modelname = weapons[0].GetModelName()
            string name = GetWeaponName_ReturnString( weapons[0] )
            if( player.IsPlayer() )
                modelname = GetWorldModelName( weapons[0] )
            if( modelname == $"" )
                return
            if( name == "未知武器" )
                return
            int skin = weapons[0].GetSkin()
            int camo = weapons[0].GetCamo()
            entity weaponmodel = CreatePropDynamic( modelname, droppoint, dropangle , SOLID_VPHYSICS )
            
            weaponmodel.EndSignal( "OnDestroy" )
            weaponmodel.SetUsable()
            weaponmodel.SetUsableByGroup("titan")
            weaponmodel.SetUsePrompts("按住 %use% 以撿起" + name, "按下 %use% 以撿起" + name)
            AddCallback_OnUseEntity( weaponmodel, GiveDroppedTitanWeapon )

            TitanWeaponStruct tempweapon
            tempweapon.weaponName = name
            tempweapon.weaponClassname = weapons[0].GetWeaponClassName()
            tempweapon.weaponModel = weaponmodel
            tempweapon.weaponMods = RemoveTacticalWeaponMods( weapons[0].GetMods() )
            tempweapon.weaponAmmo = weapons[0].IsChargeWeapon() ? 0 : weapons[0].GetWeaponPrimaryClipCount()
            tempweapon.weaponSkin = skin
            tempweapon.weaponCamo = camo
            droppedWeapons.append( tempweapon )
            
            wait 30
            droppedWeapons.fastremovebyvalue( tempweapon )
            if (IsValid(weaponmodel))
            {
                weaponmodel.Destroy()
            }
        }
    }
}

void function ReplaceTitanWeapon( entity player, entity weaponmodel ) 
{
    TitanWeaponStruct replacementWeapon
    foreach( TitanWeaponStruct tempweapon in droppedWeapons )
    {
        if( tempweapon.weaponModel == weaponmodel )
        {
            replacementWeapon = tempweapon
            droppedWeapons.fastremovebyvalue( tempweapon )
        }
    }
    if( replacementWeapon.weaponModel == null )
        return

    player.TakeWeaponNow( player.GetMainWeapons()[0].GetWeaponClassName() )
    player.GiveWeapon( replacementWeapon.weaponClassname, replacementWeapon.weaponMods )
    player.SetActiveWeaponByName( replacementWeapon.weaponClassname )
    array < entity > weapons = player.GetMainWeapons()
    if ( IsValid(player) && weapons.len() != 0 ) 
    {
        if( weapons[0].IsChargeWeapon() )
            weapons[0].SetWeaponChargeFraction( 0.0 )
        else
            weapons[0].SetWeaponPrimaryClipCount( replacementWeapon.weaponAmmo )
        weapons[0].SetSkin( replacementWeapon.weaponSkin )
        weapons[0].SetCamo( replacementWeapon.weaponCamo )
        GiveOffhandsForWeaponReplace( player )
    }
    replacementWeapon.weaponModel.Destroy()
}

void function GiveOffhandsForWeaponReplace( entity player )
{
    if( !IsAlive( player ) )
        return
    entity weapon = player.GetMainWeapons()[0]
    if( !IsValid( weapon ) )
        return

    string classname = weapon.GetWeaponClassName()
    array<string> mods = weapon.GetMods()

    table<int,float> cooldowns = GetWeaponCooldownsForTitanLoadoutSwitch( player )

    if( classname == "mp_titanweapon_particle_accelerator" )
        BecomeIon( player, true )
    if( classname == "mp_titanweapon_sticky_40mm" )
    {
        if( mods.contains( "atlas_40mm" ) )
            BecomeAtlas( player, true )
        else
            BecomeTone( player, true )
    }

    if( classname == "mp_titanweapon_leadwall" )
        BecomeRonin( player, true )
    if( classname == "mp_titanweapon_sniper" )
    {
        if( mods.contains( "arc_cannon" ) )
            BecomeArchon( player, true )
        else
            BecomeNorthstar( player, true )
    }
    if( classname == "mp_titanweapon_rocketeer_rocketstream" )
    {
        if( mods.contains( "brute4_rocket_launcher" ) )
            BecomeBrute4( player, true )
        else
            BecomeStryder( player, true )
    }

    if( classname == "mp_titanweapon_meteor" )
        BecomeScorch( player, true )
    if( classname == "mp_titanweapon_predator_cannon" )
        BecomeLegion( player, true )
    if( classname == "mp_titanweapon_triplethreat" )
        BecomeOgre( player, true )
    if( classname == "mp_titanweapon_xo16_vanguard" )
        BecomeMonarch( player, true )

    SetWeaponCooldownsForTitanLoadoutSwitch( player, cooldowns )
}

function GiveDroppedTitanWeapon( weaponmodel, player ) 
{
    expect entity(player)
    expect entity(weaponmodel)
	
	bool canPickUp = true
	if( "disableTitanPick" in player.s )
	{
		canPickUp = expect bool( player.s.disableTitanPick )
	}
	if( !canPickUp )
	{
		string title = player.GetTitle()
		SendHudMessage(player, title + " 不可更换装备", -1, 0.3, 255, 255, 0, 255, 0.15, 3, 1)
		return
	}
	if( IsTitanCoreFiring( player ) )
	{
		SendHudMessage( player, "核心启动期间不可更换装备", -1, 0.3, 255, 255, 0, 0, 0, 3, 0 )
		return
	}
        
	DropPlayerTitanWeapon( player, weaponmodel.GetOrigin(), weaponmodel.GetAngles() )
	ReplaceTitanWeapon( player, weaponmodel )
}

array<string> function RemoveTacticalWeaponMods( array<string> mods )
{
    array<string> replaceArray
    foreach( string mod in mods )
    {
        if( mod == "Smart_Core" ||
            mod == "rocketeer_ammo_swap" ||
            mod == "LongRangeAmmo" )
            continue

        replaceArray.append( mod )
    }

    return replaceArray
}

string function GetWeaponName_ReturnString( entity weapon )
{
    string classname = weapon.GetWeaponClassName()
    array<string> mods = weapon.GetMods()
    
    if( classname == "mp_titanweapon_particle_accelerator" )
    {
        if( mods.contains( "pas_ion_weapon" ) )
            return "分裂槍 [纏結能量]"
        if( mods.contains( "pas_ion_weapon_ads" ) )
            return "分裂槍 [折射鏡片]"
        return "分裂槍"
    }
    if( classname == "mp_titanweapon_sticky_40mm" )
    {
        if( mods.contains( "atlas_40mm" ) )
            return "40mm機炮"
        if( mods.contains( "pas_tone_weapon" ) )
            return "40mm追蹤機炮 [強化追蹤彈藥]"
        if( mods.contains( "pas_tone_burst" ) )
            return "40mm追蹤機炮 [連發填充器]"
        return "40mm追蹤機炮"
    }
    if( classname == "mp_titanweapon_predator_cannon" )
    {
        if( mods.contains( "pas_legion_weapon" ) )
            return "獵殺者機炮 [強化彈藥容量]"
        if( mods.contains( "pas_legion_spinup" ) )
            return "獵殺者機炮 [輕合金]"
        return "獵殺者機炮"
    }
    if( classname == "mp_titanweapon_meteor" )
    {
        if( mods.contains( "pas_scorch_weapon" ) )
            return "T-203鋁熱劑發射器 [野火投射器]"
        return "T-203鋁熱劑發射器"
    }
    if( classname == "mp_titanweapon_xo16_vanguard" )
    {
        if( mods.contains( "battle_rifle" ) )
        {
            if( mods.contains( "rapid_reload" ) )
                return "XO-16 [快速武裝，加速器]"
            return "XO-16 [加速器]"
        }
        if( mods.contains( "arc_rounds" ) )
        {
            if( mods.contains( "rapid_reload" ) )
                return "XO-16 [電弧彈藥，快速武裝]"
            return "XO-16 [電弧彈藥]"
        }
        if( mods.contains( "arc_rounds_with_battle_rifle" ) )
        {
            if( mods.contains( "rapid_reload" ) )
                return "XO-16 [電弧彈藥，快速武裝，加速器]"
            return "XO-16 [電弧彈藥，加速器]"
        }
        return "XO-16"
    }
    if( classname == "mp_titanweapon_leadwall" )
    {
        if( mods.contains( "pas_ronin_weapon" ) )
            return "天女散花 [彈跳彈藥]"
        return "天女散花"
    }
    if( classname == "mp_titanweapon_sniper" )
    {
        if( mods.contains( "arc_cannon" ) )
        {
            //temp fix
            return "未知武器"
            if( mods.contains( "capacitor" ) )
                return "電弧機炮 [電容器]"
            if( mods.contains( "chain_reaction" ) )
                return "電弧機炮 [連鎖反應]"
            if( mods.contains( "generator_mod" ) )
                return "電弧機炮 [發電裝置]"
            return "電弧機炮"
        }
        if( mods.contains( "pas_northstar_optics" ) )
            return "電漿磁軌炮 [威脅光鏡]"
        if( mods.contains( "pas_northstar_weapon" ) )
            return "電漿磁軌炮 [穿刺射擊]"
        return "電漿磁軌炮"
    }
    if( classname == "mp_titanweapon_rocketeer_rocketstream" )
    {
        //temp fix
        if( mods.contains( "brute4_rocket_launcher" ) )
            return "未知武器"
        if( mods.contains( "straight_shot" ) )
            return "四段火箭 [直射系統]"
        if( mods.contains( "rapid_detonator" ) )
            return "四段火箭 [快速引爆]"
        return "四段火箭"
    }
    if( classname == "mp_titanweapon_triplethreat" )
    {
        if( mods.contains( "rolling_rounds" ) )
            return "三連環榴彈 [滾動彈藥]"
        if( mods.contains( "hydraulic_launcher" ) )
            return "三連環榴彈 [液壓驅動]"
        if( mods.contains( "mine_field" ) )
            return "三連環榴彈 [地雷區]"
        return "三連環榴彈"
    }
    return "未知武器"
}

asset function GetWorldModelName( entity weapon )
{
    string modelname = weapon.GetWeaponClassName()
    switch( modelname )
    {
        case "mp_titanweapon_particle_accelerator":
            return $"models/weapons/titan_particle_accelerator/w_titan_particle_accelerator.mdl"
        case "mp_titanweapon_sticky_40mm":
            return $"models/weapons/thr_40mm/w_thr_40mm.mdl"
        case "mp_titanweapon_predator_cannon":
        case "mp_titanweapon_predator_cannon_siege":
            return $"models/weapons/titan_predator/w_titan_predator.mdl"
        case "mp_titanweapon_meteor":
            return $"models/weapons/titan_thermite_launcher/w_titan_thermite_launcher.mdl"
        case "mp_titanweapon_xo16_vanguard":
        case "mp_titanweapon_xo16_shorty":
            return $"models/weapons/titan_xo16_shorty/w_xo16shorty.mdl"
        case "mp_titanweapon_leadwall":
            return $"models/weapons/titan_triple_threat/w_titan_triple_threat.mdl"
        case "mp_titanweapon_sniper":
            return $"models/weapons/titan_sniper_rifle/w_titan_sniper_rifle.mdl"
        case "mp_titanweapon_rocketeer_rocketstream":
            return $"models/weapons/titan_rocket_launcher/titan_rocket_launcher.mdl"
        case "mp_titanweapon_triplethreat":
            return $"models/weapons/titan_triple_threat_og/w_titan_triple_threat_og.mdl"
    }
    return $""
}

#endif