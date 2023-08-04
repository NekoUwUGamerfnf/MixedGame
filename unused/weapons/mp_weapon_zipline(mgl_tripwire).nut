untyped


global function MpWeaponZipline_Init
global function OnWeaponActivate_weapon_zipline
global function OnWeaponDeactivate_weapon_zipline
global function OnWeaponAttemptOffhandSwitch_weapon_zipline
global function OnWeaponPrimaryAttack_weapon_zipline
global function OnProjectileCollision_weapon_zipline

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_zipline
global function UpdateZiplineCrosshair
#endif // #if SERVER

const ZIPLINE_END_MODEL = $"models/industrial/grappling_hook_end.mdl"

const ZIPLINE_DIST_MIN = 350
const ZIPLINE_DIST_MAX = 6000

const ZIPLINE_LIFE_TIME = 30

struct
{
	table<int, entity> activeWeaponBolts
} file

function MpWeaponZipline_Init()
{
	PrecacheModel( ZIPLINE_END_MODEL )
	PrecacheMaterial( $"cable/cable" )
	PrecacheMaterial( $"cable/zipline" )
	PrecacheModel( $"cable/zipline.vmt" )

	#if SERVER
	#endif
}

void function OnWeaponActivate_weapon_zipline( entity weapon )
{
	if( !weapon.HasMod( "tripwire_launcher" ) )
		return
	entity owner = weapon.GetWeaponOwner()
	if ( !("activeZiplineBolt" in owner.s) ) // TODO: initialize this elsewhere...
		owner.s.activeZiplineBolt <- null
}

void function OnWeaponDeactivate_weapon_zipline( entity weapon )
{
	if( !weapon.HasMod( "tripwire_launcher" ) )
		return
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) )
		owner.s.activeZiplineBolt <- null
}

bool function OnWeaponAttemptOffhandSwitch_weapon_zipline( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()

	if ( owner.IsPhaseShifted() )
		return false

	return true
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_zipline( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}
#endif // #if SERVER

var function OnWeaponPrimaryAttack_weapon_zipline( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	entity owner = weapon.GetWeaponOwner()

	EmitSoundOnEntity( owner, "Wpn_TetherTrap_Deploy_3P" )
	if ( !("activeZiplineBolt" in owner.s) ) // TODO: initialize this elsewhere...
		owner.s.activeZiplineBolt <- null

	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true

	if ( shouldCreateProjectile )
	{
		entity projectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir * 3000, < 0, 0, 0 >, 0.0, 0, 0, false, true, false )
		#if SERVER
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( projectile, weaponOwner.GetTeam() )
		#endif

		// #if CLIENT
		// 	StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"Rocket_Smoke_SMR_Glow" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		// #endif

		// #if SERVER
		// 	entity owner = weapon.GetWeaponOwner()

		// #endif
	}

	return 1
}

#if SERVER

void function DeleteAfterDelay( array<entity> ents, delay )
{
	wait delay

	// // TEMP
	// bool playerZiplining = false
	// do
	// {
	// 	WaitFrame()

	// 	array<entity> players = GetPlayerArray()
	// 	foreach ( player in players )
	// 	{
	// 		if ( !player.IsZiplining() )
	// 			continue

	// 		playerZiplining = false
	// 		break
	// 	}
	// }
	// while ( playerZiplining )

	foreach ( ent in ents )
	{
		if ( IsValid( ent ) )
			ent.Destroy()
	}
}

void function ExplodeAfterDelay( array<entity> ents, delay )
{
	wait delay

	foreach ( ent in ents )
	{
		if ( IsValid( ent ) )
			ent.GrenadeExplode( <0,0,0> )
	}
}

array<entity> function CreateRopeWithEnts( entity startParent, entity endParent )
{
	vector startPos = startParent.GetOrigin()
	vector endPos = endParent.GetOrigin()

	string startpointName = UniqueString( "rope_startpoint" )
	string endpointName = UniqueString( "rope_endpoint" )

	entity rope_start = CreateEntity( "move_rope" )
	SetTargetName( rope_start, startpointName )
	rope_start.kv.NextKey = endpointName
	rope_start.kv.MoveSpeed = 64
	rope_start.kv.Slack = 0
	rope_start.kv.Subdiv = "2"
	rope_start.kv.Width = "2"
	rope_start.kv.TextureScale = "1"
	rope_start.kv.RopeMaterial = "cable/cable.vmt"
	rope_start.kv.PositionInterpolator = 2
	rope_start.SetOrigin( startPos )
	rope_start.SetParent( startParent )

	entity rope_end = CreateEntity( "keyframe_rope" )
	SetTargetName( rope_end, endpointName )
	rope_end.kv.MoveSpeed = 64
	rope_end.kv.Slack = 0
	rope_end.kv.Subdiv = "2"
	rope_end.kv.Width = "2"
	rope_end.kv.TextureScale = "1"
	rope_end.kv.RopeMaterial = "cable/cable.vmt"
	rope_end.kv.PositionInterpolator = 2
	rope_end.SetOrigin( endPos )
//	rope_end.SetParent( endParent )

	DispatchSpawn( rope_start )
	DispatchSpawn( rope_end )

	array<entity> ropeEnts = [ rope_start, rope_end ]
	return ropeEnts
}


array<entity> function CreateGunZipline( vector startPos, vector endPos )
{
	string startpointName = UniqueString( "rope_startpoint" )
	string endpointName = UniqueString( "rope_endpoint" )

	entity rope_start = CreateEntity( "move_rope" )
	SetTargetName( rope_start, startpointName )
	rope_start.kv.NextKey = endpointName
	rope_start.kv.MoveSpeed = 64
	rope_start.kv.Slack = 25
	rope_start.kv.Subdiv = "0"
	rope_start.kv.Width = "2"
	rope_start.kv.Type = "0"
	rope_start.kv.TextureScale = "1"
	rope_start.kv.RopeMaterial = "cable/zipline.vmt"
	rope_start.kv.PositionInterpolator = 2
	rope_start.kv.Zipline = "1"
	rope_start.kv.ZiplineAutoDetachDistance = "150"
	rope_start.kv.ZiplineSagEnable = "0"
	rope_start.kv.ZiplineSagHeight = "50"
	rope_start.SetOrigin( startPos )

	entity rope_end = CreateEntity( "keyframe_rope" )
	SetTargetName( rope_end, endpointName )
	rope_end.kv.MoveSpeed = 64
	rope_end.kv.Slack = 25
	rope_end.kv.Subdiv = "0"
	rope_end.kv.Width = "2"
	rope_end.kv.Type = "0"
	rope_end.kv.TextureScale = "1"
	rope_end.kv.RopeMaterial = "cable/zipline.vmt"
	rope_end.kv.PositionInterpolator = 2
	rope_end.kv.Zipline = "1"
	rope_end.kv.ZiplineAutoDetachDistance = "150"
	rope_end.kv.ZiplineSagEnable = "0"
	rope_end.kv.ZiplineSagHeight = "50"
	rope_end.SetOrigin( endPos )

	DispatchSpawn( rope_start )
	DispatchSpawn( rope_end )

	array<entity> ropeEnts = [ rope_start, rope_end ]
	return ropeEnts
}

array<entity> function CreateZipLine( vector start, vector end, int autoDetachDistance = 150, float ziplineMoveSpeedScale = 1.0 )
{
	string midpointName = UniqueString( "rope_midpoint" )
	string endpointName = UniqueString( "rope_endpoint" )

	entity rope_start = CreateEntity( "move_rope" )
	rope_start.kv.NextKey = midpointName
	rope_start.kv.MoveSpeed = 0
	rope_start.kv.ZiplineMoveSpeedScale = ziplineMoveSpeedScale
	rope_start.kv.Slack = 0
	rope_start.kv.Subdiv = 0
	rope_start.kv.Width = "2"
	rope_start.kv.TextureScale = "1"
	rope_start.kv.RopeMaterial = "cable/zipline.vmt"
	rope_start.kv.PositionInterpolator = 2
	rope_start.kv.Zipline = "1"
	rope_start.kv.ZiplineAutoDetachDistance = string( autoDetachDistance )
	rope_start.kv.ZiplineSagEnable = "0"
	rope_start.kv.ZiplineSagHeight = "0"
	rope_start.SetOrigin( start )

	entity rope_mid = CreateEntity( "keyframe_rope" )
	SetTargetName( rope_mid, midpointName )
	rope_start.kv.NextKey = endpointName
	rope_mid.SetOrigin( ( start + end ) * 0.5 )
	//rope_mid.SetOrigin( start )

	entity rope_end = CreateEntity( "keyframe_rope" )
	SetTargetName( rope_end, endpointName )
	rope_end.SetOrigin( end )

	// Dispatch spawn entities
	DispatchSpawn( rope_start )
	DispatchSpawn( rope_mid )
	DispatchSpawn( rope_end )

	array<entity> ropeEnts = [ rope_start, rope_mid, rope_end ]

	return ropeEnts
}

#endif

bool function CanTetherEntities( entity startEnt, entity endEnt )
{
	if ( Distance( startEnt.GetOrigin(), endEnt.GetOrigin() ) > 1024 )
		return false

	TraceResults traceResult = TraceLine( startEnt.GetOrigin(), endEnt.GetOrigin(), [], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
	if ( traceResult.fraction < 1 )
		return false

	entity startEntParent = startEnt.GetParent()
	entity endEntParent = endEnt.GetParent()

	// sadly, this is broken right now.
	if ( startEntParent.IsTitan() && endEntParent.IsTitan() )
		return false

	return true
}

void function OnProjectileCollision_weapon_zipline( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		entity owner = projectile.GetOwner()
		if ( !IsValid( owner ) )
			return

		if ( !owner.IsPlayer() )
			return

		//for mgl tripwire
		if( !hitEnt.IsWorld() )
			return

		bool didStick = PlantStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
		if ( !didStick )
		{
			projectile.Destroy()
			UpdateZiplineCrosshair( owner )
			return
		}

		//projectile.SetAbsAngles( AnglesCompose( projectile.GetAngles(), Vector(-90,0,0) ) )

		Assert( IsValid( projectile ) )
		vector origin = projectile.GetOrigin()

		vector endOrigin = origin - Vector( 0.0, 0.0, 32.0 )
		vector surfaceAngles = projectile.proj.savedAngles
		vector oldUpDir = AnglesToUp( surfaceAngles )

		TraceResults traceResult = TraceLine( origin, endOrigin, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
		if ( traceResult.fraction < 1.0 )
		{
			vector forward = AnglesToForward( projectile.proj.savedAngles )
			surfaceAngles = AnglesOnSurface( traceResult.surfaceNormal, forward )

			vector newUpDir = AnglesToUp( surfaceAngles )
			if ( DotProduct( newUpDir, oldUpDir ) < 0.55 )
				surfaceAngles = projectile.proj.savedAngles
		}

		projectile.SetAngles( surfaceAngles )

		EmitSoundOnEntity( projectile, "Wpn_LaserTripMine_Land" )

		// TODO first person representation
		// - duplicate entities, not parented to the hitbox
		// - draw only for player that IsTitan()
		// - disable draw completely when outside of Titan

		SetForceDrawWhileParented( projectile, true )

		entity activeZiplineBolt = expect entity( owner.s.activeZiplineBolt )

		if ( IsValid( activeZiplineBolt ) )
		{
			if ( CanTetherEntities( activeZiplineBolt, projectile ) )
			{
				array<entity> ziplineEnts = [activeZiplineBolt, projectile]

				entity startEnt = activeZiplineBolt.GetParent().IsWorld() ? activeZiplineBolt : activeZiplineBolt.GetParent()
				entity endEnt = projectile.GetParent().IsWorld() ? projectile : projectile.GetParent()

				SetTargetName( activeZiplineBolt, UniqueString( "rope_startpoint" ) )
				SetTargetName( projectile, UniqueString( "rope_endpoint" ) )

				if ( startEnt.IsTitan() || endEnt.IsTitan() )
				{
					if ( startEnt.IsTitan() )
					{
						ziplineEnts.extend( CreateRopeWithEnts( activeZiplineBolt, projectile ) )
					}
					else
					{
						ziplineEnts.extend( CreateRopeWithEnts( projectile, activeZiplineBolt ) )
					}
				}
				else
				{
					PROTO_EnvBeam( owner, startEnt, endEnt )
				}

				EmitSoundOnEntityOnlyToPlayer( owner, owner, "Explo_TripleThreat_MagneticAttract")

				if( Vortex_GetRefiredProjectileMods( projectile ).contains( "tripwire_launcher" ) ) // modded refire behavior
				{
					foreach( entity attatch in ziplineEnts )
					{
						thread TrapDestroyOnDamage( attatch )
						thread TrapDestroyOnRoundEnd( owner, attatch )
					}
					thread ExplodeAfterDelay( ziplineEnts, ZIPLINE_LIFE_TIME )
				}
				else
					thread DeleteAfterDelay( ziplineEnts, 60.0 )
				owner.s.activeZiplineBolt = null
			}
			else
			{
				activeZiplineBolt.Destroy()
				owner.s.activeZiplineBolt = projectile
			}
		}
		else
		{
			owner.s.activeZiplineBolt = projectile
		}
		UpdateZiplineCrosshair( owner )
	#endif
}

#if SERVER
//fix so it can be destroyed now
void function TrapDestroyOnDamage( entity trapEnt )
{
	EndSignal( trapEnt, "OnDestroy" )

	trapEnt.SetDamageNotifications( true )

	var results
	entity attacker
	entity inflictor

	while ( true )
	{
		if ( !IsValid( trapEnt ) )
			return

		results = WaitSignal( trapEnt, "OnDamaged" )
		attacker = expect entity( results.activator )
		inflictor = expect entity( results.inflictor )

		if ( IsValid( inflictor ) && inflictor == trapEnt )
			continue

		bool shouldDamageTrap = false
		if ( IsValid( attacker ) )
		{
			if ( trapEnt.GetTeam() == attacker.GetTeam() )
			{
				shouldDamageTrap = false
			}
			else
			{
				shouldDamageTrap = true
			}
		}

		if ( shouldDamageTrap )
			break
	}

	if ( !IsValid( trapEnt ) )
		return

	trapEnt.Destroy()
}

entity function PROTO_EnvBeam( entity owner, entity startEnt, entity endEnt )
{
	entity env_laser = CreateEntity( "env_laser" )
	env_laser.kv.LaserTarget = endEnt.GetTargetName()
	env_laser.kv.rendercolor = "150 100 15"
	env_laser.kv.rendercolorFriendly = "15 100 150"
	env_laser.kv.renderamt = 255
	env_laser.kv.width = 2
	env_laser.SetValueForTextureKey( $"sprites/laserbeam.spr" )
	env_laser.kv.TextureScroll = 35
	env_laser.kv.damage = "0"
	env_laser.kv.dissolvetype = -1//-1 to 2 - none, energy, heavy elec, light elec
	env_laser.kv.spawnflags = 1// 32 end sparks
	env_laser.SetOrigin( startEnt.GetOrigin() )
	env_laser.SetAngles( startEnt.GetAngles() )
	env_laser.ConnectOutput( "OnTouchedByEntity", OnTouchedByEntity )
	env_laser.SetParent( startEnt )
	env_laser.s.parents <- [startEnt, endEnt]

	SetTeam( env_laser, owner.GetTeam() )

	DispatchSpawn( env_laser )

	return env_laser
}

void function OnTouchedByEntity( entity self, entity activator, entity caller, var value )
{
	if ( self.GetTeam() == activator.GetTeam() )
		return

	foreach ( ent in self.s.parents )
	{
		if( IsValid(ent) )
			ent.GrenadeExplode( <0,0,0> )
	}

	printt( "touch", self, activator, caller, value )
}

void function UpdateZiplineCrosshair( entity player )
{
	entity atWeapon = GetPilotAntiTitanWeapon( player )

	if ( !IsValid( atWeapon ) )
		return

	if ( atWeapon.GetWeaponClassName() != "mp_weapon_zipline" )
		return

	int activeTethers = PROTO_GetActiveTethers( player )

	if ( IsValid( player.s.activeZiplineBolt ) )
	{
		if ( activeTethers )
			atWeapon.SetMods( ["tether_single_one"] )
		else
			atWeapon.SetMods( ["tether_single"] )
	}
	else
	{
		if ( activeTethers )
			atWeapon.SetMods( ["tether_base_one"] )
		else
			atWeapon.SetMods( [] )
	}
}
#endif