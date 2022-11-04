global function SpawnTitanWeaponCommand

void function SpawnTitanWeaponCommand()
{
	#if SERVER
	AddClientCommandCallback("spawntw", SpawnTW)
	#endif
}

bool function SpawnTW(entity player, array<string> args)
{
	#if SERVER
	entity weapon = null;
	string weaponId = ("");
	array<entity> players = GetPlayerArray();
	hadGift_Admin = false;
	CheckAdmin(player);
	if (hadGift_Admin != true)
	{
		Kprint( player, "Admin permission not detected.");
		return true;
	}

	// if player only typed "gift"
	if (args.len() == 0)
	{
		Kprint( player, "Give a valid argument.");
		Kprint( player, "Example: spawntw <weaponId> <playerName> <camoid> <weaponmods> ");
		Kprint( player, "You can check weaponId by typing give and pressing tab to scroll through the IDs.");
		// print every single player's name and their id
		int i = 0;
		foreach (entity p in GetPlayerArray())
		{
			string playername = p.GetPlayerName();
			Kprint( player, "[" + i.tostring() + "] " + playername);
			i++
		}
		return true;
	}
	CheckWeaponName(args[0])
	if (successfulweapons.len() > 1)
	{
		print ("Multiple weapons found!")
		int i = 1;
		foreach (string weaponnames in successfulweapons)
		{
			print ("[" + i.tostring() + "] " + weaponnames)
			i++
		}
		return true;
	} else if (successfulweapons.len() == 1)
	{
			Kprint( player, "Weapon ID is " + successfulweapons[0])
			weaponId = successfulweapons[0]
	} else if (successfulweapons.len() == 0)
	{
		Kprint( player, "Unable to detect weapon")
		return true;
	}
	// if player typed "gift correctId" with no further arguments
	if (args.len() == 1)
	{
		Kprint( player, "Example: spawntw <weaponId> <playerName> <mod>");
		Kprint( player, "If you want to spawn yourself A weapon, put your own name as the playerName.");
		return true;
	}
	array<entity> playerstogift
	// if player typed "gift correctId somethinghere"
	switch (args[1])
	{
		case ("all"):
			foreach (entity p in GetPlayerArray())
			{
				if (p != null)
					playerstogift.append(p)
			}
		break;

		case ("imc"):
			foreach (entity p in GetPlayerArrayOfTeam( TEAM_IMC ))
			{
				if (p != null)
					playerstogift.append(p)
			}
		break;

		case ("militia"):
			foreach (entity p in GetPlayerArrayOfTeam( TEAM_MILITIA ))
			{
				if (p != null)
					playerstogift.append(p)
			}
		break;

		default:
            CheckPlayerName(args[1])
			 	foreach (entity p in successfulnames)
                	playerstogift.append(p)
		break;
	}
	array<string> mods
	if (args.len() > 3)
	{
		mods = args.slice(3);
	}
	CMDsender = player
	foreach(entity p in playerstogift)
		SpawnTitanWeapon(p, weaponId, args[2].tointeger() , mods )
	#endif
	return true;
}

#if SERVER
void function SpawnTitanWeapon(entity player , string weaponname , int weaponCamo = 0 , array<string> weaponMods = [] , int weaponAmmo = 0)
{
    bool isTitanWeapon = weaponname.find( "mp_titanweapon_" ) != null
    if ( isTitanWeapon )
    {
        thread SpawnTitanWeapon_threaded( player , weaponname , weaponMods , weaponCamo , weaponAmmo )
    }
    else
        Kprint( player , weaponname + " is not A valid titanweapon" )
}

void function SpawnTitanWeapon_threaded(entity player , string weaponname , array<string> weaponMods , int weaponCamo , int weaponAmmo , vector dropangle = <0,0,0>)
{
    //asset modelname = weaponname.GetModelName()
    asset modelname = GetWorldModelFromClassName( weaponname )
    entity weaponmodel = CreatePropDynamic( modelname, GetPlayerCrosshairOrigin( player ), dropangle , SOLID_VPHYSICS )

    weaponmodel.EndSignal( "OnDestroy" )
    weaponmodel.SetUsable()
    weaponmodel.SetUsableByGroup("titan")
    weaponmodel.SetUsePrompts("按住 %use% 以撿起" + GetWeaponNameFromClassName( weaponname ), "按下 %use% 以撿起" + GetWeaponNameFromClassName( weaponname ))
    //weaponmodel.SetSkin( weaponCamo  )
    //weaponmodel.SetCamo( weaponCamo )
    AddCallback_OnUseEntity( weaponmodel, GiveDroppedTitanWeapon )

    TitanWeaponStruct tempweapon
    tempweapon.weaponName = GetWeaponNameFromClassName( weaponname )
    tempweapon.weaponClassname = weaponname
    tempweapon.weaponModel = weaponmodel
    tempweapon.weaponMods = weaponMods
    tempweapon.weaponAmmo = weaponAmmo
    tempweapon.weaponCamo = weaponCamo
    droppedWeapons.append( tempweapon )

    WaitForever()
    droppedWeapons.fastremovebyvalue( tempweapon )
    if (IsValid(weaponmodel))
    {
        weaponmodel.Destroy()
    }
}

string function GetWeaponNameFromClassName( string classname )
{
    switch( classname )
    {
        case "mp_titanweapon_particle_accelerator":
            return "分裂槍"
        case "mp_titanweapon_sticky_40mm":
            return "40mm追蹤機炮"
        case "mp_titanweapon_predator_cannon":
            return "獵殺者機炮"
        case "mp_titanweapon_meteor":
            return "T-203鋁熱劑發射器"
        case "mp_titanweapon_xo16_vanguard":
            return "XO-16"
        case "mp_titanweapon_leadwall":
            return "天女散花"
        case "mp_titanweapon_sniper":
            return "電漿磁軌炮"
        case "mp_titanweapon_rocketeer_rocketstream":
            return "四段火箭"
        case "mp_titanweapon_triplethreat":
            return "三聯裝榴彈"
    }
    return "未知武器"
}

asset function GetWorldModelFromClassName( string weaponname )
{
    switch( weaponname )
    {
        case "mp_titanweapon_particle_accelerator":
            return $"models/weapons/titan_particle_accelerator/w_titan_particle_accelerator.mdl"
        case "mp_titanweapon_sticky_40mm":
            return $"models/weapons/thr_40mm/w_thr_40mm.mdl"
        case "mp_titanweapon_predator_cannon":
            return $"models/weapons/titan_predator/w_titan_predator.mdl"
        case "mp_titanweapon_meteor":
            return $"models/weapons/titan_thermite_launcher/w_titan_thermite_launcher.mdl"
        case "mp_titanweapon_xo16_vanguard":
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