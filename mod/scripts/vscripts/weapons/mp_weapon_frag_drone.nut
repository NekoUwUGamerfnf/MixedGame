untyped // so we can use entity.s
global function OnProjectileCollision_weapon_frag_drone
global function OnProjectileExplode_weapon_frag_drone
global function OnWeaponAttemptOffhandSwitch_weapon_frag_drone

global function OnWeaponTossReleaseAnimEvent_weapon_frag_drone
global function MpWeaponFragDrone_Init

// modified callbacks
global function OnWeaponTossPrep_weapon_frag_drone
global function OnWeaponPrimaryAttack_weapon_frag_drone
#if SERVER
global function OnWeaponNPCTossGrenade_weapon_frag_drone
#endif

// modified: drone_spawner_anm
const array<string> VALID_DRONE_TYPES = 
[ 
	"npc_drone_beam", 
	"npc_drone_rocket", 
	"npc_drone_plasma" 
]

void function MpWeaponFragDrone_Init()
{
	RegisterSignal( "OnFragDroneCollision" )

	#if SERVER
		PrecacheModel( $"models/robots/drone_frag/frag_drone_proj.mdl" )
		AddDamageCallbackSourceID( damagedef_frag_drone_throwable_PLAYER, FragDrone_OnDamagePlayerOrNPC )
	#endif
}

// modified callbacks
void function OnWeaponTossPrep_weapon_frag_drone( entity weapon, WeaponTossPrepParams prepParams )
{
	// vanilla behavior
	Grenade_OnWeaponTossPrep( weapon, prepParams )
}

var function OnWeaponPrimaryAttack_weapon_frag_drone( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "drone_spawner_anim" ) )
    {
#if SERVER
		entity owner = weapon.GetWeaponOwner()
		entity drone = SpawnDroneFromPlayer( owner, VALID_DRONE_TYPES[ RandomInt( VALID_DRONE_TYPES.len() ) ] )
		
		if( !IsValid( drone ) ) // drone spawn failed!
			return 0

		return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
#endif
	}

	// vanilla has no behavior about this
}
//

void function OnProjectileCollision_weapon_frag_drone( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		if ( hitEnt.GetClassName() != "func_brush" )
		{
			if ( projectile.proj.projectileBounceCount > 0 )
				return

			float dot = normal.Dot( Vector( 0, 0, 1 ) )

			if ( dot < 0.7 )
				return

			projectile.proj.projectileBounceCount += 1

 			thread DelayedExplode( projectile, 0.75 )
		}
	#endif
}


var function OnWeaponTossReleaseAnimEvent_weapon_frag_drone( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapons
	if( weapon.HasMod( "emp_drone" ) )
		return OnAbilityStart_EMPDrone( weapon, attackParams )

	entity grenade = Grenade_OnWeaponToss_ReturnEntity( weapon, attackParams )
	if( grenade )
	{
		if( weapon.HasMod( "sp_tick_model" ) )
		{
			grenade.SetModel( $"models/robots/drone_frag/frag_drone_proj.mdl" ) // can't make it behave like disc after resetting model
			//grenade.SetAngles( grenade.GetAngles() + < RandomFloatRange( 7,11 ), 0, 0 > )
		}
	}
	//
	
	// vanilla behavior
	//Grenade_OnWeaponTossReleaseAnimEvent( weapon, attackParams )

	#if SERVER && MP // TODO: should be BURNCARDS
		if ( weapon.HasMod( "burn_card_weapon_mod" ) )
			TryUsingBurnCardWeapon( weapon, weapon.GetWeaponOwner() )
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

// modified callback
#if SERVER
void function OnWeaponNPCTossGrenade_weapon_frag_drone( entity weapon, entity nade )
{
	// generic setup
	Grenade_OnPlayerNPCTossGrenade_Common( weapon, nade )

	// here goes some vanilla missing behavior: we save squad here and apply it on tick spawn
	entity owner = nade.GetThrower()
	//print( "RUNNING OnWeaponNPCTossGrenade_weapon_frag_drone()" )
	//print( "weapon: " + string( weapon ) )
	//print( "nade: " + string( nade ) )
	//print( "owner: " + string( owner ) )
	//print( "squadname: " + string( owner.kv.squadname ) )
	if ( IsValid( owner ) && owner.IsNPC() )
		nade.s.savedSquadName <- owner.kv.squadname
}
#endif

void function OnProjectileExplode_weapon_frag_drone( entity projectile )
{
	#if SERVER
		vector origin = projectile.GetOrigin()
		entity owner = projectile.GetThrower()

		if ( !IsValid( owner ) )
			return

		array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior

		// modded weapons
		if( mods.contains( "prowler_spawner" ) )
			return DeployableToProwler( projectile )
		else if( mods.contains( "drone_spawner" ) )
			return TicksToDrones( projectile )
		//

		// vanilla behavior
		int team = owner.GetTeam()

		entity drone = CreateFragDroneCan( team, origin, < 0, projectile.GetAngles().y, 0 > )
		if( mods.contains( "sp_tick_model" ) ) // modded condition
			SetSpawnOption_AISettings( drone, "npc_frag_drone" )
		else
			SetSpawnOption_AISettings( drone, "npc_frag_drone_throwable" )
		
		// here goes modified behavior: we add squad if it's spawned by npc
		// welp there's actually delayed very much, may needs to setup on throw
		// maybe no need? thinks below never gets hit if projectile's thrower became invalid
		if ( owner.IsNPC() )
		{
			string squad = ""
			// setup squad on throw version
			if ( "savedSquadName" in projectile.s )
			{
				squad = expect string( projectile.s.savedSquadName )
				//print( "we got saved squad name for nade " + string( projectile ) + " : " + squad )
			}
			else // failsafe, or we're not setting up squad but called this OnProjectileCollision calllback
			{
				squad = expect string( owner.kv.squadname )
				//print( "we can't find saved squad name!! owner " + string( owner ) + " squad is: " + squad )
			}

			if ( squad != "" )
				SetSpawnOption_SquadName( drone, squad )
		}

		DispatchSpawn( drone )

		vector ornull clampedPos = NavMesh_ClampPointForAIWithExtents( origin, drone, < 20, 20, 36 > )
		if ( clampedPos != null )
		{
			expect vector( clampedPos )
			drone.SetOrigin( clampedPos )
		}
		else
		{
			// fix for northstar: if we can't find better pos, at least set a owner before tick explodes
			//projectile.GrenadeExplode( Vector( 0, 0, 0 ) )
			//drone.Signal( "SuicideSpectreExploding" )
			thread DroneDeployFailedExplode( drone, owner )
			return
		}

		int followBehavior = GetDefaultNPCFollowBehavior( drone )
		if ( owner.IsPlayer() )
		{
			drone.SetBossPlayer( owner )
			UpdateEnemyMemoryWithinRadius( drone, 1000 )
		}
		else if ( owner.IsNPC() )
		{
			entity enemy = owner.GetEnemy()
			if ( IsAlive( enemy ) )
				drone.SetEnemy( enemy )
		}

		if ( IsSingleplayer() && IsAlive( owner ) )
		{
			drone.InitFollowBehavior( owner, followBehavior )
			drone.EnableBehavior( "Follow" )
		}
		else
		{
			drone.EnableNPCFlag( NPC_ALLOW_PATROL | NPC_ALLOW_INVESTIGATE | NPC_NEW_ENEMY_FROM_SOUND )
		}

		thread FragDroneDeplyAnimation( drone, 0.0, 0.1 )
		thread WaitForEnemyNotification( drone )
		thread FragDroneLifetime( drone )
	#endif
}

#if SERVER
void function FragDroneLifetime( entity drone )
{
	drone.EndSignal( "OnDestroy" )
	drone.EndSignal( "OnDeath" )

	EmitSoundOnEntity( drone, "weapon_sentryfragdrone_emit_loop" )
	wait 15.0
	drone.Signal( "SuicideSpectreExploding" )
}

void function DelayedExplode( entity projectile, float delay )
{
	projectile.Signal( "OnFragDroneCollision" )
	projectile.EndSignal( "OnFragDroneCollision" )
	projectile.EndSignal( "OnDestroy" )

	wait delay
	while( TraceLineSimple( projectile.GetOrigin(), projectile.GetOrigin() - <0,0,15>, projectile ) == 1.0 )
		wait 0.25

	projectile.GrenadeExplode( Vector( 0, 0, 0 ) )
}

// fix for northstar: if we can't find better pos, at least set a owner before tick explodes
void function DroneDeployFailedExplode( entity drone, entity owner )
{
	if ( owner.IsPlayer() )
	{
		drone.SetBossPlayer( owner )
	}
	thread FragDroneDeplyAnimation( drone, 0.0, 0.1 )
	//drone.Signal( "SuicideSpectreExploding" )
	drone.Signal( "SuicideSpectreForceExplode" ) // signal "SuicideSpectreExploding" will cause ticks already ignited to explode instantly, which makes player unable to react...
}

void function WaitForEnemyNotification( entity drone )
{
	drone.EndSignal( "OnDeath" )

	entity owner
	entity currentTarget

	while ( true )
	{
		//----------------------------------
		// Get owner and current enemy
		//----------------------------------
		currentTarget = drone.GetEnemy()
		owner = drone.GetFollowTarget()

		//----------------------------------
		// Free roam if owner is dead or HasEnemy
		//----------------------------------
		if ( !IsAlive( owner ) || currentTarget != null )
		{
			drone.DisableBehavior( "Follow" )
		}
		else
		{
			drone.ClearEnemy()
			drone.EnableBehavior( "Follow" )
		}

		wait 0.25
	}

}

void function FragDrone_OnDamagePlayerOrNPC( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	if ( ent != attacker )
		return

	DamageInfo_SetDamage( damageInfo, 0.0 )
}

#endif

bool function OnWeaponAttemptOffhandSwitch_weapon_frag_drone( entity weapon )
{
	entity weaponOwner = weapon.GetOwner()
	if ( weaponOwner.IsPhaseShifted() )
		return false

	return true
}


// modded weapon stuffs
#if SERVER
void function DeployableToProwler( entity grenade )
{
	entity owner = grenade.GetThrower()
	vector pos = grenade.GetOrigin()
	vector ang = grenade.GetAngles()
	int team = grenade.GetTeam()

	entity prowler = CreateNPC( "npc_prowler", team , pos, ang )
	SetSpawnOption_AISettings( prowler, "npc_prowler" )
	DispatchSpawn( prowler )

	prowler.SetOwner( owner )
	prowler.SetBossPlayer( owner )
	NPCFollowsPlayer( prowler, owner )
}

void function TicksToDrones( entity tick )
{
	thread TicksToDronesThreaded( tick )
}

void function TicksToDronesThreaded( entity tick )
{
	entity tickowner = tick.GetThrower()
	vector tickpos = tick.GetOrigin() + Vector(0,0,50)
	vector tickang = tick.GetAngles()
	int tickteam = tick.GetTeam()

	string dronename = VALID_DRONE_TYPES[ RandomInt( VALID_DRONE_TYPES.len() ) ]

	entity drone = CreateNPC("npc_drone" , tickteam , tickpos, tickang )
	SetSpawnOption_AISettings( drone, dronename )
	DispatchSpawn( drone )

	drone.SetOwner( tickowner )
	drone.SetBossPlayer( tickowner )
	drone.SetMaxHealth( 170 )
	drone.SetHealth( 170 )
	entity weapon = drone.GetActiveWeapon()
	string classname = weapon.GetWeaponClassName()
	//print( "Drone's Active Weapon is " + classname )
	drone.TakeWeaponNow( classname )
	drone.GiveWeapon( classname, ["npc_elite_weapon"] ) // weapon has been nerfed
	drone.SetActiveWeaponByName( classname )
	NPCFollowsPlayer( drone, tickowner )
	thread DisableDroneSound( drone ) // disable their annoying sound!

	/*
	int followBehavior = GetDefaultNPCFollowBehavior( drone )
    drone.InitFollowBehavior( tickowner, followBehavior )
    drone.EnableBehavior( "Follow" )
    */
}

void function DisableDroneSound( entity drone )
{
	drone.EndSignal( "OnDestroy" )
	
	WaitFrame()
	StopSoundOnEntity( drone, "Drone_Mvmt_Hover_Hero" )
	StopSoundOnEntity( drone, "Drone_Mvmt_Hover" )
	/* // this might cause entities firing too many signals
	while( true )
	{
		StopSoundOnEntity( drone, "Drone_Mvmt_Hover_Hero" )
		StopSoundOnEntity( drone, "Drone_Mvmt_Hover" )
		StopSoundOnEntity( drone, "Drone_Mvmt_Turn" )
		
		WaitFrame()
	}
	*/
}
#endif