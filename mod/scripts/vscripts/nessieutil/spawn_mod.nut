untyped
global function SpawnCommand
global function OnPrematchStar2t

struct
{
    array<entity> successfulnames
} admin

void function SpawnCommand()
{
	#if SERVER
	AddClientCommandCallback("spawn", SpawnCMD);
    AddClientCommandCallback("fastball", FastBall1)
    //Precache models to spawn units :)

    // drones
    PrecacheModel($"models/robots/drone_air_attack/drone_air_attack_plasma.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_air_attack_rockets.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_air_attack_static.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_attack_pc_1.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_attack_pc_2.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_attack_pc_3.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_attack_pc_4.mdl")
    PrecacheModel($"models/robots/drone_air_attack/drone_attack_pc_5.mdl")
    //gunship
    PrecacheModel($"models/vehicle/straton/straton_imc_gunship_01.mdl")
    PrecacheModel($"models/vehicle/straton/straton_imc_gunship_01_1000x.mdl")
    PrecacheModel($"models/vehicle/straton/straton_imc_gunship_afterburner.mdl")
    PrecacheModel($"models/robots/aerial_unmanned_worker/aerial_unmanned_worker.mdl")
    //worker drone
    PrecacheModel($"models/robots/aerial_unmanned_worker/worker_drone_pc1.mdl")
    PrecacheModel($"models/robots/aerial_unmanned_worker/worker_drone_pc2.mdl")
    PrecacheModel($"models/robots/aerial_unmanned_worker/worker_drone_pc3.mdl")
    PrecacheModel($"models/robots/aerial_unmanned_worker/worker_drone_pc4.mdl")
    //plsma turret
    PrecacheModel($"models/robotics_r2/heavy_turret/mega_turret.mdl")
    PrecacheModel($"models/robotics_r2/turret_plasma/plasma_turret_pc_1.mdl")
    PrecacheModel($"models/robotics_r2/turret_plasma/plasma_turret_pc_2.mdl")
    PrecacheModel($"models/robotics_r2/turret_plasma/plasma_turret_pc_3.mdl")
    PrecacheModel($"models/robotics_r2/turret_rocket/rocket_turret_posed.mdl")
    //prowler
    /* // should never precache their corpses!
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_01.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_02.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_05.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_06.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_07.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_08.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_09.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_10.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_corpse_static_12.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_dead_static_07.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_dead_static_08.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_dead_static_09.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_dead_static_10.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_dead_static_11.mdl")
    PrecacheModel($"models/creatures/prowler/prowler_death1_static.mdl")
    */
    PrecacheModel($"models/creatures/prowler/r2_prowler.mdl")
    PrecacheModel( $"models/titans/stryder/stryder_titan.mdl")
    PrecacheModel( $"models/titans/ogre/ogre_titan.mdl")
    PrecacheModel( $"models/titans/atlas/atlas_titan.mdl")
    PrecacheModel( $"models/weapons/arms/atlaspov_cockpit2.mdl")
    PrecacheModel( $"models/weapons/arms/atlaspov.mdl")
    PrecacheModel( $"models/weapons/arms/stryderpov.mdl")
    PrecacheModel($"models/titans/buddy/titan_buddy.mdl")
    PrecacheModel($"models/titans/buddy/ar_battery.mdl")
    PrecacheModel($"models/titans/buddy/bt_battery_idle_2_static.mdl")
    PrecacheModel($"models/titans/buddy/bt_battery_idle_3_static.mdl")
    PrecacheModel($"models/titans/buddy/bt_posed.mdl")
    PrecacheModel($"models/weapons/arms/buddypov.mdl")
    PrecacheModel($"models/titans/buddy/titan_buddy_skyway.mdl")
    PrecacheModel($"models/weapons/arms/buddypov_skyway.mdl")
    PrecacheModel($"models/creatures/flyer/r2_flyer.mdl")
    PrecacheParticleSystem( $"P_BT_eye_SM" )

	#endif
}

void function CheckSpawnModPlayerName(string name)
{
    array<entity> players = GetPlayerArray()
    admin.successfulnames = [];
    foreach (entity player in players)
    {
        if (player != null)
        {
            string playername = player.GetPlayerName()
            if (playername.tolower().find(name.tolower()) != null)
            {
                print("Detected " + playername + "!")
                admin.successfulnames.append(player)
            }
        }
    }
    return;
}

bool function FastBall1(entity player, array<string> args)
{
	#if SERVER
	if ( !BATTERY_SPAWNERS.contains( player.GetUID() ) )
	{
		print("Admin permission not detected.");
		return true;
	}

	// if player only typed "gift"
	if (args.len() == 0) {
        print("Give a valid argument.");
        // print every single player's name and their id
        int i = 0;
        foreach(entity p in GetPlayerArray()) {
            string playername = p.GetPlayerName();
            print("[" + i.tostring() + "] " + playername);
            i++
        }
        return true;
    }
	string playername = player.GetPlayerName()
    array < entity > sheep1 = [];
    // if player typed "health somethinghere"
    switch (args[0]) {
        default:
            CheckSpawnModPlayerName(args[0])
                foreach (entity p in admin.successfulnames)
                    sheep1.append(p)
            break;
    }


    // if player typed "gift correctId" with no further arguments
    // if (args.len() == 2 || args.len() == 3) {
    //     return true;
    // }

    // if (args.len() > 4 )
	// {
	// 	print("Only 4 arguments required.")
	// 	return true;
	// }

    table<string,string> parm
    int a = 1

    while(a<3){
        if (args.len() == a+3){
        parm["null"] <- "0"
        }
        if (args.len() == a+4) {
            parm[args[a+3]] <- "0"
        }
        if (args.len() == a+5) {
            parm[args[a+3]] <- args[a+4]
        }
        a += 1
    }



    foreach (entity p in sheep1 ) {
        thread OnPrematchStar2t( p )
    }
	#endif
	return true;
}

bool function SpawnCMD(entity player, array<string> args)
{
	#if SERVER
	if ( !BATTERY_SPAWNERS.contains( player.GetUID() ) )
	{
		print("Admin permission not detected.");
		return true;
	}

	// if player only typed "gift"
	if (args.len() == 0) {
        print("Give a valid argument.");
        print("Example: spawn <playerId> <teamNum> <amount> <npc> , playerId = imc / militia / all, npc = grunt");
        // print every single player's name and their id
        int i = 0;
        foreach(entity p in GetPlayerArray()) {
            string playername = p.GetPlayerName();
            print("[" + i.tostring() + "] " + playername);
            i++
        }
        return true;
    }
	string playername = player.GetPlayerName()
    array < entity > sheep1 = [];
    // if player typed "health somethinghere"
    switch (args[0]) {
        case ("all"):
            foreach(entity p in GetPlayerArray()) {
                if (p != null)
                    sheep1.append(p)
            }
            break;

        case ("imc"):
            foreach(entity p in GetPlayerArrayOfTeam(TEAM_IMC)) {
                if (p != null)
                    sheep1.append(p)
            }
            break;

        case ("militia"):
            foreach(entity p in GetPlayerArrayOfTeam(TEAM_MILITIA)) {
                if (p != null)
                    sheep1.append(p)
            }
            break;

        default:
            CheckSpawnModPlayerName(args[0])
                foreach (entity p in admin.successfulnames)
                    sheep1.append(p)
            break;
    }

    // if player typed "gift correctId" with no further arguments
    // if (args.len() == 2 || args.len() == 3) {
    //     return true;
    // }

    // if (args.len() > 4 )
	// {
	// 	print("Only 4 arguments required.")
	// 	return true;
	// }

    table<string,string> parm
    int a = 1

    while(a<3){
        if (args.len() == a+3){
        parm["null"] <- "0"
        }
        if (args.len() == a+4) {
            parm[args[a+3]] <- "0"
        }
        if (args.len() == a+5) {
            parm[args[a+3]] <- args[a+4]
        }
        a += 1
    }



    foreach (entity p in sheep1) {
        thread Spawn(p, args[1].tointeger(), args[2].tointeger(),args[3],parm)
    }
	#endif
	return true;
}


void function Spawn(entity player, int team, int amount, string model, table<string,string> parm)
{
#if SERVER
    vector origin = GetPlayerCrosshairOrigin( player );
    vector angles = player.EyeAngles();
    angles.x = 0;
    angles.z = 0;

    vector spawnPos = origin;
    vector spawnAng = angles;

    //info about the spawn
    print("=====Info=====")
    print("Pos :" + spawnPos)
    print("Angle : " + spawnAng)
    print("Team : " + team)
    print("Amount : " + amount)
    print("type")

    int a = amount

    //initilize spawnNpc
    entity spawnNpc

    //parms before spawning the entity
    setParmsBefore(player,parm)

    //this is made to abstarct the names of the npc or make it easier to spawn them
    switch (model) {

//////////////////////////////////////// ground boys ///////////////////////////////////////////////////

        case ("reaper"):
            print("reaper")

            SpawnNPC("npc_super_spectre", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("grunt"):
            print("grunt")

            SpawnNPC("npc_soldier", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("stalker"):
            print("stalker")

            SpawnNPC("npc_stalker", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("spectre"):
            print("spectre")

            SpawnNPC("npc_spectre", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("tick"):
            print("tick")

            SpawnNPC("npc_frag_drone", amount, team, spawnPos, spawnAng,parm, player)
            break;

//////////////////////////////////////// Drones ///////////////////////////////////////////////////

        case ("rocket_drone"):
            print("rocket_drone")

            SpawnNPC2("npc_drone","npc_drone_rocket", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("plasma_drone"):
            print("rocket_drone")

            SpawnNPC2("npc_drone","npc_drone_plasma", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("beam_drone"):
            print("beam_drone")

            SpawnNPC2("npc_drone","npc_drone_beam", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("shield_drone"):
            print("shield_drone")

            // SpawnNPC2("npc_drone","npc_drone_shield", amount, team, spawnPos, spawnAng,parm, player)
            // they lact have an ai
            break;

        case ("worker_drone"):
            print("worker_drone")

            SpawnNPC2("npc_drone","npc_drone_worker", amount, team, spawnPos, spawnAng,parm, player)
            // error lol
            break;
        case ("drone"):
            print("drone")

            SpawnNPC("npc_drone", amount, team, spawnPos, spawnAng,parm, player)
            break;

//////////////////////////////////////// Other Air Npcs ///////////////////////////////////////////////////

        case ("gunship"):
            print("gunship")

            SpawnNPC2("npc_gunship","npc_gunship", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("dropship"):
            print("dropship")

            SpawnNPC("npc_dropship", amount, team, spawnPos, spawnAng,parm, player)
            break;

//////////////////////////////////////// Turrets ///////////////////////////////////////////////////

        case ("turret_big"):
            print("turret_big")

            SpawnNPC2("npc_turret_mega","npc_turret_mega", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("turret"):
            print("turret")

            SpawnNPC2("npc_turret_sentry","npc_turret_sentry", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("turret_plasma"):
            print("turret_titan")

            SpawnNPC2("npc_turret_sentry","npc_turret_sentry_plasma", amount, team, spawnPos, spawnAng,parm, player)
            break;

//////////////////////////////////////// Other ///////////////////////////////////////////////////

        case ("marvin"):
            print("marvin")

            SpawnNPC("npc_marvin", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("prowler"):
            print("prowler")

            SpawnNPC("npc_prowler", amount, team, spawnPos, spawnAng,parm, player)
            break;

//////////////////////////////////////// Train ///////////////////////////////////////////////////

        case ("train1"):
            print("train")

            SpawnNPC3("npc_drone", 5, team, spawnPos, spawnAng,parm, player)
            break;

        case ("train2"):
            print("train2")

            SpawnNPC3("npc_super_spectre", 5, team, spawnPos, spawnAng,parm, player)
            break;

//////////////////////////////////////// Titans ///////////////////////////////////////////////////

        case ("ronin"):
            print("ronin")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_leadwall", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("amped_ronin"):
            print("amped_ronin")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_leadwall_shift_core", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("ronin_boss"):
            print("ronin_boss")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_leadwall_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("arc_titan"):
            print("arc_titan")

            SpawnTitanC("titan_stryder", "npc_titan_arc", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("northstar"):
            print("northstar")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_sniper", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("northstar_fd"):
            print("northstar_fd")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_sniper_boss_fd", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("northstar_boss"):
            print("northstar_boss")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_sniper_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("brute"):
            print("brute")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_rocketeer", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("amped_brute"):
            print("amped_brute")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_rocketeer_dash_core", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("brute_boss"):
            print("brute_boss")

            SpawnTitanC("titan_stryder", "npc_titan_stryder_rocketeer_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("tone"):
            print("tone")

            SpawnTitanC("npc_titan_atlas", "npc_titan_atlas_tracker", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("tone_boss"):
            print("tone_boss")

            SpawnTitanC("npc_titan_atlas", "npc_titan_atlas_tracker_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("ion"):
            print("ion")

            SpawnTitanC("npc_titan_atlas", "npc_titan_atlas_stickybomb", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("ion_boss"):
            print("ion")

            SpawnTitanC("npc_titan_atlas", "npc_titan_atlas_stickybomb_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("monarch"):
            print("monarch")

            SpawnTitanC("npc_titan_atlas", "npc_titan_atlas_vanguard", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("monarch_boss"):
            print("monarch_boss")

            SpawnTitanC("npc_titan_atlas", "npc_titan_atlas_vanguard_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("scorch"):
            print("scorch")

            SpawnTitanC("npc_titan_ogre", "npc_titan_ogre_meteor", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("scorch_boss"):
            print("scorch_boss")

            SpawnTitanC("npc_titan_ogre", "npc_titan_ogre_meteor_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("legion"):
            print("legion")

            SpawnTitanC("npc_titan_ogre", "npc_titan_ogre_minigun", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("legion_boss"):
            print("legion_boss")

            SpawnTitanC("npc_titan_ogre", "npc_titan_ogre_minigun_bounty", amount, team, spawnPos, spawnAng,parm, player)
            break;

        // case ("meele_titan"): doesn't work
        //     print("legion_boss")

        //     SpawnTitanC("npc_titan_ogre", "npc_titan_ogre_fighter_berserker_core", amount, team, spawnPos, spawnAng,parm, player)
        //     break;

        // case ("nuke_titan1"): don't work :(
        //     print("nuke_titan1")

        //     SpawnTitanC("titan_ogre", "npc_titan_nuke", amount, team, spawnPos, spawnAng,parm, player)
        //     break;

        // case ("nuke_titan2"):
        //     print("nuke_titan2")

        //     SpawnTitanC("titan_ogre", "npc_titan_nuke", amount, team, spawnPos, spawnAng,parm, player)
        //     break;

        // case ("titan_sarah"): doesn't work
        //     print("titan_sarah")

        //     SpawnTitanC("npc_titan", "npc_titan_sarah", amount, team, spawnPos, spawnAng,parm, player)
        //     break;

//////////////////////////////////////// Pilots ///////////////////////////////////////////////////

        case ("pilot"):
            print("pilot")

            SpawnNPC("npc_pilot_elite", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("sarah"): // she is not a pilot because npc_soldier but I will let it pass
            print("sarah")

            SpawnNPC2("npc_soldier", "npc_soldier_hero_sarah", amount, team, spawnPos, spawnAng,parm, player)
            break;


        case ("BT"):
            print("BT")

            SpawnNPCBT("npc_titan", "npc_titan_buddy", amount, 3, spawnPos, spawnAng,parm, player)
            break;

        case ("ATLAS"):
            print("BT")

            SpawnNPCBT("npc_titan", "npc_titan_buddy_atlas", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("BT2"):
            print("BT2")

            SpawnNPCBT("npc_titan", "npc_titan_buddy_s2s", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("BT3"):
            print("BT3")

            SpawnNPCBT("npc_titan", "npc_titan_buddy_skyway", amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("reaperfall"):
            print("reaperfall")

            SpawnNPCREAPER("npc_super_spectre","npc_super_spectre_aitdm",  amount, team, spawnPos, spawnAng,parm, player)
            break;

        case ("dropgrunt"):
            print("droppod")

            SpawnDropPodB( "npc_soldier" , spawnPos, spawnAng, team )
            break;


        case ("dropspectre"):
            print("droppodspectre")

            SpawnDropPodB( "npc_spectre" , spawnPos, spawnAng, team )
            break;

        case ("dropstalker"):
            print("droppodstalker")

            SpawnDropPodB( "npc_stalker" , spawnPos, spawnAng, team )
            break;

        case ("dropsarah"):
            print("droppod2")

            SpawnDropPodB2( "npc_soldier" , "npc_soldier_hero_sarah" , spawnPos, spawnAng, team )
            break;

        case ("dropshipgrunt"):
            print("dropshipgrunt")
            SpawnDropShipB( spawnPos, spawnAng, team, amount )
            break;

        case ("dropshipspectre"):
            print("dropshipgrunt")
            SpawnDropShipB2( spawnPos, spawnAng, team, amount )
            break;


        default:
            print("none")
            break;
    }
#endif
}


void function SpawnNPC(string name, int amount, int team, vector spawnPos, vector spawnAng, table<string,string> parm,entity player)
{
    int a = amount
    entity spawnNpc

    // try {
    while(a>0)
    {
    a-=1;

    spawnNpc = CreateNPC( name, team, spawnPos, spawnAng);
    SetSpawnOption_AISettings( spawnNpc, name);
    DispatchSpawn( spawnNpc );

    setParmsAfter(player,parm, spawnNpc)
    }

    // }
    // catch() {
    //     continue;
    // }
}

void function SpawnNPC2(string name,string aiName, int amount, int team, vector spawnPos, vector spawnAng, table<string,string> parm,entity player)
{
    int a = amount
    entity spawnNpc

    // try {
    while(a>0)
    {
    a-=1;

    spawnNpc = CreateNPC( name, team, spawnPos, spawnAng);
    SetSpawnOption_AISettings( spawnNpc, aiName);
    DispatchSpawn( spawnNpc );

    setParmsAfter(player,parm, spawnNpc)
    }

    // }
    // catch() {
    //     continue;
    // }
}

void function SpawnNPC3(string name, int amount, int team, vector spawnPos, vector spawnAng, table<string,string> parm,entity player)
{
    int a = amount
    entity spawnNpc
    entity lastEntity = player
    table<string,string> parm
    parm["pet"] <- "1"

    // try {
    while(a>0)
    {
    a-=1;

    spawnNpc = CreateNPC( name, team, spawnPos, spawnAng);
    SetSpawnOption_AISettings( spawnNpc, name);
    DispatchSpawn( spawnNpc );

    setParmsAfter(lastEntity,parm, spawnNpc)
    lastEntity = spawnNpc
    }

    // }
    // catch() {
    //     continue;
    // }
}

void function SpawnTitanC(string name, string aiName, int amount, int team, vector spawnPos, vector spawnAng, table<string,string> parm,entity player)
{
    int a = amount
    entity spawnNpc

    // try {
    while(a>0)
    {
    a-=1;

    entity spawnNpc = CreateNPCTitan( name, team, spawnPos, spawnAng, [] );
	SetSpawnOption_NPCTitan( spawnNpc, TITAN_HENCH );
    // string settings = expect string( Dev_GetPlayerSettingByKeyField_Global( name, "sp_aiSettingsFile" ) )
	SetSpawnOption_AISettings( spawnNpc, aiName );
    SetSpawnOption_Titanfall( spawnNpc )
    SetSpawnOption_NPCTitan( spawnNpc, TITAN_HENCH );
    // spawnNpc.ai.titanSpawnLoadout.setFile = name
	// OverwriteLoadoutWithDefaultsForSetFile( spawnNpc.ai.titanSpawnLoadout )
	DispatchSpawn( spawnNpc );

    setParmsAfter(player,parm, spawnNpc)
    }

    // }
    // catch() {
    //     continue;
    // }
}


/////////////////////////////////////////////////DROPSHIP////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void function SquadHandler( string name )
{
  array< entity > guys
  array< entity > points = GetEntArrayByClass_Expensive( "assault_assaultpoint" )

  try
  {
    guys = GetNPCArrayBySquad( name )
    array< entity > enemies = GetNPCArrayOfEnemies( guys[0].GetTeam() )

    vector point
    //if ( enemies.len() )
    //  point = enemies[ RandomInt( enemies.len() ) ].GetOrigin()

    point = points[ RandomInt( points.len() ) ].GetOrigin()

    foreach ( guy in guys )
    {
      guy.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
      guy.AssaultPoint( point )
      guy.AssaultSetGoalRadius( 100 )

      // show on enemy radar
      guy.Minimap_AlwaysShow( GetOtherTeam( guy.GetTeam() ), null )
    }
  }
  catch (ex)
  {
    printt("Squad doesn't exist you moron!")
    //return
  }
}



struct
{
  // Me when team based escalation

  array< array< string > > podEntities = [ [ "npc_soldier" ], [ "npc_soldier" ] ]
  array< bool > reapers = [ false, false ]

  array< string > gruntWeapons = [ "mp_weapon_rspn101", "mp_weapon_dmr", "mp_weapon_r97", "mp_weapon_lmg" ]
  array< string > spectreWeapons = [ "mp_weapon_hemlok_smg", "mp_weapon_doubletake", "mp_weapon_mastiff" ]
} file

void function SpawnDropShipB( vector spawnPos, vector spawnAng, int team, int amount )
{
	string squadName = MakeSquadName( team, UniqueString( "" ) )

	CallinData drop
	drop.origin 		= spawnPos + <0,0,500>
	drop.yaw 			  = spawnAng.y
	drop.dist 			= 768
	drop.team 			= team
	drop.squadname 	= squadName
	SetDropTableSpawnFuncs( drop, CreateSoldier, amount )
	SetCallinStyle( drop, eDropStyle.ZIPLINE_NPC )

  thread RunDropshipDropoff( drop )

  WaitSignal( drop, "OnDropoff" )

  array< entity > guys = GetNPCArrayBySquad( squadName )

  foreach ( guy in guys )
  {
    guy.ReplaceActiveWeapon( file.gruntWeapons[ RandomInt( file.gruntWeapons.len() ) ] )
  }

  SquadHandler( squadName )
}


void function SpawnDropShipB2( vector spawnPos, vector spawnAng, int team, int amount )
{
	string squadName = MakeSquadName( team, UniqueString( "" ) )

	CallinData drop
	drop.origin 		= spawnPos + <0,0,500>
	drop.yaw 			  = spawnAng.y
	drop.dist 			= 768
	drop.team 			= team
	drop.squadname 	= squadName
	SetDropTableSpawnFuncs( drop, CreateSpectre, amount )
	SetCallinStyle( drop, eDropStyle.ZIPLINE_NPC )

  thread RunDropshipDropoff( drop )

  WaitSignal( drop, "OnDropoff" )

  array< entity > guys = GetNPCArrayBySquad( squadName )

  foreach ( guy in guys )
  {
    guy.ReplaceActiveWeapon( file.gruntWeapons[ RandomInt( file.gruntWeapons.len() ) ] )
  }

  SquadHandler( squadName )
}



/////////////////////////////////////////////////DROPSHIP////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


void function SpawnNPCREAPER(string name,string aiName, int amount, int team, vector spawnPos, vector spawnAng, table<string,string> parm,entity player)
{
    int a = amount
    entity spawnNpc

    // try {
    while(a>0)
    {
    a-=1;

    spawnNpc = CreateNPC( name, team, spawnPos, spawnAng);
    SetSpawnOption_AISettings( spawnNpc, aiName);
    DispatchSpawn( spawnNpc );
    thread SuperSpectre_WarpFall( spawnNpc )

    setParmsAfter(player,parm, spawnNpc)
    }

    // }
    // catch() {
    //     continue;
    // }
}

void function SpawnDropPodB(string name, vector spawnPos, vector spawnAng, int team )
{
  entity pod = CreateDropPod( spawnPos, <0,0,0> )
  string squadName = MakeSquadName( team, UniqueString( "ZiplineTable" ) )
  array<entity> guys

  SetTeam( pod, team )

  InitFireteamDropPod( pod )

  waitthread LaunchAnimDropPod( pod, "pod_testpath", spawnPos, spawnAng )

  for (int i = 0; i < 4 ;i++ ) {
    entity soldier = CreateNPC( name, team, spawnPos,<0,0,0> )

    SetTeam( soldier, team )
    //soldier.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
    //soldier.AssaultPoint(Vector(-487.158, 646.772, 960.031))
    //soldier.AssaultSetFightRadius( 64 )
    DispatchSpawn( soldier )

    SetSquad( soldier, squadName )
    guys.append( soldier )
  }

  ActivateFireteamDropPod( pod, guys )

  foreach ( guy in guys )
  {
    guy.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
  }
}

void function SpawnDropPodB2(string name, string aiName , vector spawnPos, vector spawnAng, int team )
{
  entity pod = CreateDropPod( spawnPos, <0,0,0> )
  string squadName = MakeSquadName( team, UniqueString( "ZiplineTable" ) )
  array<entity> guys

  SetTeam( pod, team )

  InitFireteamDropPod( pod )

  waitthread LaunchAnimDropPod( pod, "pod_testpath", spawnPos, spawnAng )

  for (int i = 0; i < 4 ;i++ ) {
    entity soldier = CreateNPC( name, team, spawnPos,<0,0,0> )
    SetSpawnOption_AISettings( soldier, aiName);
    SetTeam( soldier, team )
    //soldier.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
    //soldier.AssaultPoint(Vector(-487.158, 646.772, 960.031))
    //soldier.AssaultSetFightRadius( 64 )
    DispatchSpawn( soldier )

    SetSquad( soldier, squadName )
    guys.append( soldier )
  }

  ActivateFireteamDropPod( pod, guys )

  foreach ( guy in guys )
  {
    guy.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_ALLOW_HAND_SIGNALS | NPC_ALLOW_FLEE )
  }
}


void function SpawnNPCBT(string name,string aiName, int amount, int team, vector spawnPos, vector spawnAng, table<string,string> parm,entity player)
{
    int a = amount
    entity spawnNpc

    // try {
    while(a>0)
    {
    a-=1;
    string squadName = MakeSquadName( team, UniqueString( "ZiplineTable" ) )

    spawnNpc = CreateNPC( name, team, spawnPos, spawnAng);
    SetSpawnOption_AISettings( spawnNpc, aiName);
    SetSpawnOption_Titanfall( spawnNpc );
    SetSpawnOption_NPCTitan( spawnNpc, TITAN_HENCH );
    spawnNpc.ai.titanSpawnLoadout.setFile = "titan_buddy"
    DispatchSpawn( spawnNpc );
    SetSquad( spawnNpc, squadName );

    SetPlayerPetTitan( player, spawnNpc );
    spawnNpc.SetUsePrompts( "#HOLD_TO_EMBARK", "#PRESS_TO_EMBARK" );
    spawnNpc.SetUsableByGroup( "friendlies pilot" );

    //Weapons
    spawnNpc.GiveWeapon("mp_titanweapon_xo16_vanguard")
    //spawnNpc.GiveWeapon("mp_titanweapon_xo16_shorty")
    //spawnNpc.GiveWeapon("mp_titanweapon_rocketeer_rocketstream")
    spawnNpc.SetActiveWeaponByName("mp_titanweapon_xo16_vanguard")

    //Rodeo
    //DisableTitanRodeo( spawnNpc )

    //Ordnance
    spawnNpc.TakeOffhandWeapon(OFFHAND_ORDNANCE)   
    spawnNpc.GiveOffhandWeapon("mp_titanweapon_shoulder_rockets", OFFHAND_ORDNANCE )
    
    //Defence
    spawnNpc.TakeOffhandWeapon(OFFHAND_SPECIAL)
    spawnNpc.GiveOffhandWeapon("mp_titanweapon_vortex_shield", OFFHAND_SPECIAL )
    spawnNpc.GetOffhandWeapons()[OFFHAND_SPECIAL].SetMods(["slow_recovery_vortex"])
    
    //Tactical
    spawnNpc.TakeOffhandWeapon(OFFHAND_ANTIRODEO)
    spawnNpc.GiveOffhandWeapon("mp_titanability_smoke", OFFHAND_ANTIRODEO ) 
    
    //Melee
    spawnNpc.TakeOffhandWeapon(OFFHAND_MELEE)
    spawnNpc.GiveOffhandWeapon( "melee_titan_punch_vanguard", OFFHAND_MELEE )
    
    //Titan Core
    spawnNpc.TakeOffhandWeapon(OFFHAND_EQUIPMENT)
    spawnNpc.GiveOffhandWeapon( "mp_titancore_amp_core", OFFHAND_EQUIPMENT )

    setParmsAfter(player,parm, spawnNpc)
    }

    // }
    // catch() {
    //     continue;
    // }
}



void function setParmsAfter(entity player,table<string,string> parm, entity Entity)
{
    if ("pet" in parm) {
        if (parm["pet"].tointeger() == 1)
        {
            print("npc/s is now a pet")
            int followBehavior = GetDefaultNPCFollowBehavior( Entity )
            Entity.InitFollowBehavior( player, followBehavior )
            Entity.EnableBehavior( "Follow" )
            SetTargetName( Entity, player.GetPlayerName() + "'s pet" )
        }
    }
    if ("health" in parm) {
        if (parm["health"].tointeger() > 0)
        {
            if (parm["health"].tointeger() > 524287)
                parm["health"] = "524286"

            Entity.SetMaxHealth(parm["health"].tointeger())
            Entity.SetHealth(parm["health"].tointeger())
            print("health is now at" + parm["health"])
        }
    }
    if ("weapon" in parm) {
        // int GetPersistentSpawnLoadoutIndex( Entity, string )
        TitanLoadoutDef loadout = GetActiveTitanLoadout( Entity )

        loadout.primary = parm["weapon"]
        loadout.primaryMod = ""
        loadout.primaryMods = []

        print("changed there loadout to " + parm["weapon"])
    }
    if ("name" in parm) {
        SetTargetName( Entity, parm["name"])
    }
    if ("size" in parm) {
        if (parm["size"].tointeger() > 0)
        {
            if (parm["size"].tointeger() > 1000)
                parm["size"] = "1000"

            Entity.kv.modelscale = parm["size"].tointeger()
        }
    }
    if ("rodeo" in parm) {
        if (parm["rodeo"].tointeger() == 1)
        {
            Entity.SetNumRodeoSlots( 3 )
            // Entity.SetRodeoRider( 1, player )

            print("number of rodeo spot is now 3")
        }
    }
}

void function setParmsBefore(entity player,table<string,string> parm)
{
    if ("wait" in parm) {
        if (parm["wait"].tointeger() > 0)
        {
            print("Waiting " + parm["wait"] + " before spawning")
            Wait(parm["wait"].tofloat())
            // SendHudMessage( player, "Wating is now over, time to spawn your entity!", -1, 0.4, 255, 100, 100, 0, 0.15, 4, 0.15 )

        }
    }
}

string function getWeapon(int Id)
{
    string value
    array<string> titanWeapons = [
		"mp_titanweapon_leadwall",
		"mp_titanweapon_meteor",
		"mp_titanweapon_particle_accelerator",
		"mp_titanweapon_predator_cannon",
		"mp_titanweapon_rocketeer_rocketstream",
		"mp_titanweapon_sniper",
		"mp_titanweapon_sticky_40mm",
		"mp_titanweapon_xo16_shorty",
		"mp_titanweapon_xo16_vanguard"
	]

    if (Id < 9){
        value = titanWeapons[Id];
    }
    return value;
}


//might be usuful lol
// ClientCommand( player,  command )
//ModelIsPrecached( asset )
// PrecacheModel( asset )
// bool ArrayEntityWithinDistance( array< entity >, vector, float )
// entity.SetRodeoRider( int, entity ). Sets the rodeo rider at the given slot.
// entity.SetNumRodeoSlots( int ). Sets the maximum number of rodeo slots available on this entity.
//SetTargetName( Entity,  string)
// var SetAILethality( var )
// AssistingPlayerStruct GetLatestAssistingPlayerInfo( entity )


void function OnPrematchStar2t( entity player )
{
    RegisterSignal( "fastball_start_throw" )
	RegisterSignal( "fastball_release" )
    entity buddy = player.GetPetTitan()
	thread AnimateBuddy( buddy )

	thread FastballPlayer2( player )
}


void function AnimateBuddy( entity buddy )
{
	print( "buddy spawn at " + buddy.GetOrigin() + " " + buddy.GetAngles() )

	thread PlayAnim( buddy, "bt_beacon_fastball_throw_end" )

	// play dialogue at the right time
	buddy.WaitSignal( "fastball_start_throw" )
	float diagDuration = EmitSoundOnEntity( buddy, "diag_sp_spoke1_BE117_04_01_mcor_bt" ) // trust me
	StartParticleEffectOnEntity( buddy, GetParticleSystemIndex( $"P_BT_eye_SM" ), FX_PATTACH_POINT_FOLLOW, buddy.LookupAttachment( "EYEGLOW" ) )

	wait diagDuration
	if ( GetGameState() != eGameState.Playing )
		ClassicMP_OnIntroFinished()

	buddy.WaitSignal( "fastball_release" )
	wait 5.0

	// clear any players off bt to avoid potential crash which can supposedly happen even though i've never seen it happen
	foreach ( entity player in GetPlayerArray() )
		if ( player.GetParent() == buddy )
			player.ClearParent()

}

void function FastballPlayer2( entity player )
{
	player.EndSignal( "OnDestroy" )

	if ( IsAlive( player ) )
		player.Die() // kill player if they're alive so there's no issues with that

	WaitFrame()

	player.EndSignal( "OnDeath" )

	OnThreadEnd( function() : ( player )
	{
		if ( IsValid( player ) )
		{
			RemoveCinematicFlag( player, CE_FLAG_CLASSIC_MP_SPAWNING )
			player.ClearParent()
			ClearPlayerAnimViewEntity( player )
			player.DeployWeapon()
			player.PlayerCone_Disable()
			player.ClearInvulnerable()
			player.kv.VisibilityFlags = ENTITY_VISIBLE_TO_EVERYONE // restore visibility
		}
	})

	FirstPersonSequenceStruct throwSequence
	throwSequence.attachment = "REF"
	throwSequence.useAnimatedRefAttachment = true
	throwSequence.hideProxy = true
	throwSequence.viewConeFunction = ViewConeFastball // this seemingly does not trigger for some reason
	throwSequence.firstPersonAnim = "ptpov_beacon_fastball_throw_end"
	// mp models seemingly have no 3p animation for this
	throwSequence.firstPersonBlendOutTime = 0.0
	throwSequence.teleport = true
	throwSequence.setInitialTime = Time() - Time()

	// get our buddy
	entity buddy = player.GetPetTitan()


	// respawn the player
	player.SetOrigin( buddy.GetOrigin() )
	DecideRespawnPlayer( player )
	player.kv.VisibilityFlags = 0 // better than .Hide(), hides weapons and such
	player.SetInvulnerable() // in deadly ground we die without this lol
	player.HolsterWeapon()

	// hide hud, fade screen out from black
	AddCinematicFlag( player, CE_FLAG_CLASSIC_MP_SPAWNING )
	ScreenFadeFromBlack( player, 0.5, 0.5 )

	// start fp sequence
	thread FirstPersonSequence( throwSequence, player, buddy )

	// manually do this because i can't get viewconefastball to work
	player.PlayerCone_FromAnim()
	player.PlayerCone_SetMinYaw( -50 )
	player.PlayerCone_SetMaxYaw( 25 )
	player.PlayerCone_SetMinPitch( -15 )
	player.PlayerCone_SetMaxPitch( 15 )

	buddy.WaitSignal( "fastball_start_throw" )
	// lock in their final angles at this point
	vector throwVel = AnglesToForward( player.EyeAngles() ) * 950
	throwVel.z = 675.0

	// wait for it to finish
	buddy.WaitSignal( "fastball_release" )

	if ( player.IsInputCommandHeld( IN_JUMP ) )
		throwVel.z = 850.0

	// have to correct this manually here since due to no 3p animation our position isn't set right during this sequence
	player.SetOrigin( buddy.GetAttachmentOrigin( buddy.LookupAttachment( "FASTBALL_R" ) ) )
	player.SetVelocity( throwVel )

}