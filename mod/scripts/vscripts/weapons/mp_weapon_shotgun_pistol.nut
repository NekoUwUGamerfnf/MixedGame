untyped

global function OnWeaponPrimaryAttack_weapon_shotgun_pistol

// modified callbacks!
global function OnProjectileCollision_weapon_shotgun_pistol
global function OnProjectileIgnite_weapon_shotgun_pistol

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

// unused: apex-like spread
struct
{
	float[2][SHOTGUN_PISTOL_MAX_BOLTS] boltOffsets = [
		[-0.1, -0.4], //
		[-0.1, 0.4], //
		[1.0, 0.0], //
	]
} nessie

var function OnWeaponPrimaryAttack_weapon_shotgun_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapons
	if ( weapon.HasMod( "apex_nessie" ) )
		return OnWeaponPrimaryAttack_weapon_nessie_pistol( weapon, attackParams )
	//
	
	return FireWeaponPlayerAndNPC( attackParams, true, weapon )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_shotgun_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapons
	if ( weapon.HasMod( "apex_nessie" ) )
		return OnWeaponNPCPrimaryAttack_weapon_nessie_pistol( weapon, attackParams )
	//

	// vanilla behavior
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
	// modified!!! apex-spread mozambique
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

		for ( int index = 0; index < SHOTGUN_PISTOL_MAX_BOLTS; index++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[index][0] * spreadFrac
			vector rightVec = baseRightVec * file.boltOffsets[index][1] * spreadFrac

			vector attackDir = attackParams.dir + upVec + rightVec
			int damageFlags = weapon.GetWeaponDamageFlags()
			entity bolt = FireWeaponBolt_RecordData( weapon, attackParams.pos, attackDir, 3000, damageFlags, damageFlags, playerFired, index )
			if ( bolt != null )
			{
				bolt.kv.gravity = 0.09
				if( isNessieWeapon ) // modified
					bolt.kv.gravity = 0.5

				#if SERVER
					if ( !hasArcNet && !isNessieWeapon ) // random bolt lifetime
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

	// modified: arc_net
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
	//

	return 1
}

// modified callbacks
void function OnProjectileCollision_weapon_shotgun_pistol( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded weapons, vanilla don't have specfic behavior
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior

	if ( mods.contains( "apex_nessie" ) )
		return OnProjectileCollision_weapon_nessie_pistol( projectile, pos, normal, hitEnt, hitbox, isCritical )
}

void function OnProjectileIgnite_weapon_shotgun_pistol( entity projectile )
{
	// modded weapons, vanilla don't have specfic behavior
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior

	if ( mods.contains( "apex_nessie" ) )
		return OnProjectileIgnite_weapon_nessie_pistol( projectile )
}

// respawn made for arc_net, really sucks
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
#endif
//

// modified: arc_net
#if SERVER
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