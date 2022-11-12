untyped

global function OnWeaponPrimaryAttack_weapon_shotgun_pistol

global function OnProjectileCollision_weapon_nessie_gun
global function OnProjectileIgnite_weapon_nessie_gun

const float NESSIE_DRONE_TIME = 12
const asset NESSIE_DRONE_MODEL = $"models/domestic/nessy_doll.mdl"
const asset NESSIE_DRONE_FX = $"P_xo_battery"

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_shotgun_pistol

global function CreateArcNetBeam // so doubletake can also use
#endif // #if SERVER

const SHOTGUN_PISTOL_MAX_BOLTS = 3 // this is the code limit for bolts per frame... do not increase.

struct {
	float[2][SHOTGUN_PISTOL_MAX_BOLTS] boltOffsets = [
		[-0.2, -0.4], //
		[-0.2, 0.4], //
		[0.0, 0.0], //

	]

} file

struct
{
	float[2][SHOTGUN_PISTOL_MAX_BOLTS] boltOffsets = [
		[-0.1, -0.4], //
		[-0.1, 0.4], //
		[1.0, 0.0], //
	]
}nessie

var function OnWeaponPrimaryAttack_weapon_shotgun_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, true, weapon )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_shotgun_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, false, weapon )
}
#endif // #if SERVER

function FireWeaponPlayerAndNPC( WeaponPrimaryAttackParams attackParams, bool playerFired, entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	bool hasArcNet = weapon.HasMod( "arc_net" )
	bool isNessieWeapon = weapon.HasMod( "nessie_balance" )

	float zoomFrac
	if ( playerFired )
		zoomFrac = owner.GetZoomFrac()
	else
		zoomFrac = 0.75

	float spreadFrac = Graph( zoomFrac, 0, 1, 0.05, 0.025 ) * (hasArcNet ? 1.5 : 1.0)

	array<entity> projectiles

	if ( shouldCreateProjectile )
	{
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		if( weapon.HasMod( "apex_nessie" ) )
			return FireNessieGrenade( weapon, attackParams, false )

		for ( int index = 0; index < SHOTGUN_PISTOL_MAX_BOLTS; index++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[index][0] * spreadFrac
			vector rightVec = baseRightVec * file.boltOffsets[index][1] * spreadFrac

			vector attackDir = attackParams.dir + upVec + rightVec
			int damageFlags = weapon.GetWeaponDamageFlags()
			entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackDir, 3000, damageFlags, damageFlags, playerFired, index )
			if ( bolt != null )
			{
				bolt.kv.gravity = 0.09
				if( isNessieWeapon )
					bolt.kv.gravity = 0.5

				#if SERVER
					if ( !hasArcNet && !isNessieWeapon )
					{
						if ( !(playerFired && zoomFrac > 0.8) )
							EntFireByHandle( bolt, "Kill", "", RandomFloatRange( 0.5, 0.75 ), null, null )
						else
							EntFireByHandle( bolt, "Kill", "", RandomFloatRange( 0.5, 0.75 ) * 1.25, null, null )
					}
				#endif

				projectiles.append( bolt )
				EmitSoundOnEntity( bolt, "wpn_mozambique_projectile_crackle" )
			}
		}
	}

	if ( hasArcNet )
	{
		entity firstProjectile = null
		entity lastProjectile = null
		foreach ( int index, projectile in projectiles )
		{
			if( index == 0 )
				firstProjectile = projectile
			if( index == 2 )
			{
				if ( firstProjectile != null )
				{
					#if SERVER
					thread CreateArcNetBeam( projectile, firstProjectile )
					#endif
				}
			}
			if ( lastProjectile != null )
			{
				//printt( "Linking" )
				//#if CLIENT
				//	thread CreateClientMastiffBeam( lastProjectile, projectile )
				//#elseif SERVER
				//	thread CreateServerMastiffBeam( lastProjectile, projectile )
				//#endif
				#if SERVER	
					thread CreateArcNetBeam( lastProjectile, projectile )
				#endif
			}

			lastProjectile = projectile;
		}
	}

	return 1
}

function FireNessieGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		#if SERVER
			Grenade_Init( nade, weapon )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
		if( weapon.HasMod( "apex_nessie" ) )
		{
			nade.SetModel( NESSIE_DRONE_MODEL )
			return 1
		}
	}
}

void function OnProjectileCollision_weapon_nessie_gun( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()

	if( mods.contains( "apex_nessie" ) )
	{
		entity player = projectile.GetOwner()
		if ( hitEnt == player )
			return

		if ( projectile.GrenadeHasIgnited() )
			return

		projectile.GrenadeIgnite()
		projectile.SetDoesExplode( true )
	}
}

void function OnProjectileIgnite_weapon_nessie_gun( entity projectile )
{
	#if SERVER
	thread GrenadesToDrones( projectile )
	#endif
}

#if SERVER
void function GrenadesToDrones( entity tick )
{
	thread GrenadesToDronesThreaded( tick )
}

void function GrenadesToDronesThreaded( entity tick )
{
	entity tickowner = tick.GetThrower()
	vector tickpos = tick.GetOrigin() + Vector(0,0,10)
	vector tickang = tick.GetAngles()
	int tickteam = tick.GetTeam()

	int randomdrone = RandomInt(3)
	string dronename = "npc_drone_worker"
	switch( randomdrone )
	{
		case 0:
			dronename = "npc_drone_beam"
			break
		case 1:
			dronename = "npc_drone_rocket"
			break
		case 2:
			dronename = "npc_drone_plasma"
			break
		default:
			break
	}

	entity drone = CreateNPC("npc_drone" , tickteam , tickpos, tickang )
	SetSpawnOption_AISettings( drone, dronename )
	drone.kv.modelscale = 0.01
	//drone.kv.modelscale = 0.5
	//drone.Hide() // this one can't show a title!
	DispatchSpawn( drone )

	entity nessie = CreateEntity( "script_mover" )
	nessie.SetModel( NESSIE_DRONE_MODEL )
	nessie.SetParent( drone, "CHESTFOCUS" )
	nessie.SetAngles( < 0, -90, 0 > )

	drone.SetTitle( "小尼斯水怪" )
	drone.SetHealth( 1 )
	drone.SetOwner( tickowner )
	drone.SetBossPlayer( tickowner )

	NPCFollowsPlayer( drone, tickowner )
	
	thread DisableNessieDroneSound( drone )
	thread NessieDroneLifetime( drone, nessie, NESSIE_DRONE_TIME )
	//thread AfterTimeDissolveNessieDrone( drone, nessie, fx, NESSIE_DRONE_TIME )
}

void function DisableNessieDroneSound( entity drone ) // annoying sound!
{
	drone.EndSignal( "OnDestroy" )
	
	while( true )
	{
		StopSoundOnEntity( drone, "Drone_Mvmt_Hover_Hero" )
		StopSoundOnEntity( drone, "Drone_Mvmt_Hover" )
		StopSoundOnEntity( drone, "Drone_Mvmt_Turn" )
		
		WaitFrame()
	}
}

void function NessieDroneLifetime( entity drone, entity nessie, float delay )
{
	drone.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function(): ( drone, nessie )
		{
			if( IsValid( nessie ) )
			{
				nessie.Dissolve( ENTITY_DISSOLVE_CORE, Vector( 0, 0, 0 ), 500 )
			}
			if( IsValid( drone ) )
			{
				PlayFX( $"P_plasma_exp_SM", drone.GetOrigin(), drone.GetAngles() )
				EmitSoundAtPosition( TEAM_UNASSIGNED, drone.GetOrigin(), "explo_plasma_small" )
				drone.Destroy()
			}
		}
	)
	
	wait delay
}

void function AfterTimeDissolveNessieDrone( entity drone, entity nessie, entity fx, float delay )
{
	wait delay
	if( IsValid(drone) )
		drone.Dissolve( ENTITY_DISSOLVE_CORE, Vector( 0, 0, 0 ), 500 )
	if( IsValid(nessie) )
		nessie.Dissolve( ENTITY_DISSOLVE_CORE, Vector( 0, 0, 0 ), 500 )
	if( IsValid(fx) )
		EffectStop( fx )

}
#endif

#if CLIENT
function CreateClientMastiffBeam( entity sourceEnt, entity destEnt )
{
	local beamEffectName = $"P_wpn_charge_tool_beam"

	local effectHandle = StartParticleEffectOnEntity( sourceEnt, GetParticleSystemIndex( beamEffectName ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	//EffectSetControlPointEntity( effectHandle, 1, destEnt )
	EffectSetControlPointVector( effectHandle, 1, destEnt.GetOrigin() )

	while ( EffectDoesExist( effectHandle ) && IsValid( destEnt ) /*&& IsValid( sourceEnt )*/ )
	{
		EffectSetControlPointVector( effectHandle, 1, destEnt.GetOrigin() )
		wait 0
	}

	if ( EffectDoesExist( effectHandle ) )
		EffectStop( effectHandle, true, false )
}
#endif

#if SERVER
function CreateServerMastiffBeam( entity sourceEnt, entity destEnt )
{
	local beamEffectName = $"P_wpn_charge_tool_beam"

	entity serverEffect = CreateEntity( "info_particle_system" )
	serverEffect.SetParent( sourceEnt )
	serverEffect.SetValueForEffectNameKey( beamEffectName )
	serverEffect.kv.start_active = 1
	serverEffect.SetControlPointEnt( 1, destEnt )

	DispatchSpawn( serverEffect )
}

void function CreateArcNetBeam( entity sourceEnt, entity destEnt, float lifeTime = 5.0, asset beamEffectName = $"P_wpn_charge_tool_beam" )
{
	entity cpEnd = CreateEntity( "info_placement_helper" )
	cpEnd.SetParent( sourceEnt, "REF", false, 0.0 )
	SetTargetName( cpEnd, UniqueString( "arc_cannon_beam_cpEnd" ) )
	DispatchSpawn( cpEnd )

	entity tracer = CreateEntity( "info_particle_system" )
	tracer.kv.cpoint1 = cpEnd.GetTargetName()

	tracer.SetValueForEffectNameKey( beamEffectName )

	tracer.kv.start_active = 1
	tracer.SetParent( destEnt, "REF", false, 0.0 )

	DispatchSpawn( tracer )

	sourceEnt.EndSignal( "OnDestroy" )
	destEnt.EndSignal( "OnDestroy" )

	OnThreadEnd( 
		function(): ( cpEnd, tracer )
		{
			if( IsValid( cpEnd ) )
				cpEnd.Destroy()
			if( IsValid( tracer ) )
				tracer.Destroy()
		}
	)

	tracer.Fire( "Start" )
	tracer.Fire( "StopPlayEndCap", "", lifeTime )
	tracer.Kill_Deprecated_UseDestroyInstead( lifeTime )
	cpEnd.Kill_Deprecated_UseDestroyInstead( lifeTime )

	wait lifeTime
}
#endif