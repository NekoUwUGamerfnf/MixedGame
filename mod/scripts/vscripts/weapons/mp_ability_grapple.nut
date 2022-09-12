untyped
global function OnWeaponActivate_ability_grapple
global function OnWeaponPrimaryAttack_ability_grapple
global function OnWeaponAttemptOffhandSwitch_ability_grapple
global function CodeCallback_OnGrapple
global function GrappleWeaponInit

global function OnProjectileCollision_weapon_zipline_gun
#if SERVER
global function OnWeaponNpcPrimaryAttack_ability_grapple

global function ToolZipline_DestroyZipline
#endif

struct
{
	int grappleExplodeImpactTable
} file

const int GRAPPLEFLAG_CHARGED	= (1<<0)

global struct PlacedZipline
{
	entity start,
	entity mid,
	entity end,

	entity AnchorStart,
	entity AnchorEnd,
	vector StartLocation,
	vector EndLocation
}

global array< PlacedZipline > PlacedZiplines;

const vector ZIPLINE_ANCHOR_OFFSET = Vector( 0.0, 0.0, 60.0 ); //Fit archor model, z = 80 is better
const vector ZIPLINE_ANCHOR_ANGLES = Vector( 0.0, 0.0, 0.0 );
//const asset ZIPLINE_ANCHOR_MODEL = $"models/weapons/titan_trip_wire/titan_trip_wire_projectile.mdl"
const asset ZIPLINE_ANCHOR_MODEL = $"models/signs/flag_base_pole_ctf.mdl"

const int ZIPLINE_autoDetachDistance = 150;
const float ZIPLINE_MAX_LENGTH = 5500
const float ZIPLINE_MoveSpeedScale = 1.0;
const float ZIPLINE_LIFETIME = 30
const int ZIPLINE_LAUNCH_SPEED_SCALE = 1
const float ZIPLINE_GRAVITY_SCALE = 0.001
const float ZIPLINE_MAX_COUNT = 64

// bison titan
const float BISON_GRAPPLE_DURATION = 1.0

void function GrappleWeaponInit()
{
	//file.grappleExplodeImpactTable = PrecacheImpactEffectTable( "exp_rocket_archer" )
	file.grappleExplodeImpactTable = PrecacheImpactEffectTable( "40mm_mortar_shots" )
	#if SERVER
	//AddClientCommandCallback( "ToolZipline_AddZipline", ClientCommand_ToolZipline_AddZipline );
	PrecacheModel( ZIPLINE_ANCHOR_MODEL )
	thread ToolZipline_UpdateZiplines();
	#endif
}

void function OnWeaponActivate_ability_grapple( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	int pmLevel = GetPVEAbilityLevel( weapon )
	if ( (pmLevel >= 2) && IsValid( weaponOwner ) )
		weapon.SetScriptTime0( Time() )
	else
		weapon.SetScriptTime0( 0.0 )

	// clear "charged-up" flag:
	{
		int oldFlags = weapon.GetScriptFlags0()
		weapon.SetScriptFlags0( oldFlags & ~GRAPPLEFLAG_CHARGED )
	}
}

int function GetPVEAbilityLevel( entity weapon )
{
	if ( weapon.HasMod( "pm2" ) )
		return 2
	if ( weapon.HasMod( "pm1" ) )
		return 1
	if ( weapon.HasMod( "pm0" ) )
		return 0

	return -1
}

var function OnWeaponPrimaryAttack_ability_grapple( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()

#if SERVER
	if ( owner.MayGrapple() )
	{
		#if BATTLECHATTER_ENABLED
			TryPlayWeaponBattleChatterLine( owner, weapon ) //Note that this is fired whenever you fire the grapple, not when you've successfully grappled something. No callback for that unfortunately...
		#endif
	}
#endif

	if ( owner.IsPlayer() )
	{
		int pmLevel = GetPVEAbilityLevel( weapon )
		float scriptTime = weapon.GetScriptTime0()
		if ( (pmLevel >= 2) && (scriptTime != 0.0) )
		{
			float chargeMaxTime = weapon.GetWeaponSettingFloat( eWeaponVar.custom_float_0 )
			float chargeTime = (Time() - scriptTime)
			if ( chargeTime >= chargeMaxTime )
			{
				int oldFlags = weapon.GetScriptFlags0()
				weapon.SetScriptFlags0( oldFlags | GRAPPLEFLAG_CHARGED )
			}
		}
	}

	PlayerUsedOffhand( owner, weapon )

	if( weapon.HasMod( "zipline_grapple" ) )
	{
		#if SERVER
		if( owner.IsPlayer() )
		{
			if( owner.GetSuitGrapplePower() >= 100 )
			{
				owner.SetSuitGrapplePower( owner.GetSuitGrapplePower() - 100 )
				FireZipline( weapon, attackParams, true )
			}
			else
			{
				SendHudMessage(owner, "需要完全充满以使用滑索枪", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
				return 1
			}
		}
		#endif
	}
	else
	{
		owner.Grapple( attackParams.dir )
		// for bison: not allowed to control players or npcs by grapple
		if( weapon.HasMod( "bison_grapple" ) )
		{
			thread DelayedAutoDetach( owner )
		}
	}

	return 1
}

void function DelayedAutoDetach( entity player )
{
	wait BISON_GRAPPLE_DURATION
	if( IsAlive( player ) )
		player.Grapple( < 0,0,0 > )
}

bool function OnWeaponAttemptOffhandSwitch_ability_grapple( entity weapon )
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	bool allowSwitch = (ownerPlayer.GetSuitGrapplePower() >= 100.0)

	if ( !allowSwitch )
	{
		entity ownerPlayer = weapon.GetWeaponOwner()
		ownerPlayer.Grapple( <0,0,1> )
	}
	if( weapon.HasMod( "pm2" ) && !allowSwitch )
	{
		entity ownerPlayer = weapon.GetWeaponOwner()
		#if SERVER
		SendHudMessage(ownerPlayer, "需要完全充满以使用加长钩爪", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
		#endif
	}

	return allowSwitch
}

void function DoGrappleImpactExplosion( entity player, entity grappleWeapon, entity hitent, vector hitpos, vector hitNormal )
{
#if CLIENT
	if ( !grappleWeapon.ShouldPredictProjectiles() )
		return
#endif //

	vector origin = hitpos + hitNormal * 16.0
	int damageType = (DF_RAGDOLL | DF_EXPLOSION | DF_ELECTRICAL)
	entity nade = grappleWeapon.FireWeaponGrenade( origin, hitNormal, <0,0,0>, 0.01, damageType, damageType, true, true, true )
	if ( !nade )
		return

	nade.SetImpactEffectTable( file.grappleExplodeImpactTable )
	nade.GrenadeExplode( hitNormal )
}

void function CodeCallback_OnGrapple( entity player, entity hitent, vector hitpos, vector hitNormal )
{
#if SERVER
#if MP
	PIN_PlayerAbility( player, "grapple", "mp_ability_grapple", {pos = hitpos}, 0 )
#endif //
#endif //

	// assault impact:
	{
		if ( !IsValid( player ) )
			return

		entity grappleWeapon = null
		foreach( entity offhand in player.GetOffhandWeapons() )
		{
			if( offhand.GetWeaponClassName() == "mp_ability_grapple" )
				grappleWeapon = offhand
		}

		if ( !IsValid( grappleWeapon ) )
			return
		if ( !grappleWeapon.GetWeaponSettingBool( eWeaponVar.grapple_weapon ) )
			return

		int flags = grappleWeapon.GetScriptFlags0()
		if ( ! (flags & GRAPPLEFLAG_CHARGED) )
			return

		int expDamage = grappleWeapon.GetWeaponSettingInt( eWeaponVar.explosion_damage )
		if ( expDamage <= 0 )
			return

		DoGrappleImpactExplosion( player, grappleWeapon, hitent, hitpos, hitNormal )
	}
}

int function FireZipline( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true

	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	if ( shouldCreateProjectile )
	{
		int damageFlags = weapon.GetWeaponDamageFlags()
		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, ZIPLINE_LAUNCH_SPEED_SCALE, damageFlags, damageFlags, playerFired, 0 )

		if ( bolt != null )
		{
			bolt.kv.gravity = ZIPLINE_GRAVITY_SCALE

			thread DelayedStartParticleSystem( bolt )
		}
	}

	return 1
}

// trail fix
void function DelayedStartParticleSystem( entity bolt )
{
    WaitFrame()
    if( IsValid( bolt ) )
        StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"weapon_kraber_projectile" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
}

void function OnProjectileCollision_weapon_zipline_gun( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
#if SERVER
	entity owner = projectile.GetOwner()
	if ( !IsValid( owner ) )
		return

	if ( !owner.IsPlayer() )
		return

	PlacedZipline playerZipline = ToolZipline_AddZipline( owner, projectile )
	EmitSoundOnEntity( projectile, "Wpn_LaserTripMine_Land" )

	array<string> mods = projectile.ProjectileGetMods()

	if ( CanTetherEntities( playerZipline.start, playerZipline.end ) )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Wpn_LaserTripMine_Land")
		SendHudMessage(owner, "成功部署滑索", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
		if( !mods.contains( "infinite_zipline" ) )
			thread ToolZipline_DestroyAfterTime( playerZipline, ZIPLINE_LIFETIME )
	}
	else
	{
		#if SERVER
		if( owner.IsPlayer() && IsValid( owner ) )
		{
			SendHudMessage(owner, "滑索部署失败，充能返还", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			owner.SetSuitGrapplePower( owner.GetSuitGrapplePower() + 100 )
		}
		#endif
		ToolZipline_DestroyZipline( playerZipline, true )
	}
#endif
}

bool function CanTetherEntities( entity startEnt, entity endEnt )
{
	if ( Distance( startEnt.GetOrigin(), endEnt.GetOrigin() ) > ZIPLINE_MAX_LENGTH )
		return false

	TraceResults traceResult = TraceLine( startEnt.GetOrigin(), endEnt.GetOrigin(), [], TRACE_MASK_NPCWORLDSTATIC, TRACE_COLLISION_GROUP_NONE )
	if ( traceResult.fraction < 1 )
		return false

	return true
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_ability_grapple( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()

	owner.GrappleNPC( attackParams.dir )

	return 1
}

PlacedZipline function ToolZipline_AddZipline( entity player, entity projectile )
{
	vector StartPos = player.GetOrigin();
	vector EndPos = projectile.GetOrigin();

	entity AnchorStart = ToolZipline_CreateAnchorEntity( StartPos, ZIPLINE_ANCHOR_ANGLES, 0.0 );
	entity AnchorEnd = ToolZipline_CreateAnchorEntity( EndPos, ZIPLINE_ANCHOR_ANGLES, 0.0 );
	ZipLine z = CreateZipLine( StartPos + ZIPLINE_ANCHOR_OFFSET, EndPos + ZIPLINE_ANCHOR_OFFSET, ZIPLINE_autoDetachDistance, ZIPLINE_MoveSpeedScale );

	PlacedZipline NewZipline;
	NewZipline.StartLocation = StartPos;
	NewZipline.EndLocation = EndPos;
	NewZipline.AnchorStart = AnchorStart;
	NewZipline.AnchorEnd = AnchorEnd;
	NewZipline.start = z.start;
	NewZipline.mid = z.mid;
	NewZipline.end = z.end;
	PlacedZiplines.append( NewZipline );

	if( PlacedZiplines.len() >= ZIPLINE_MAX_COUNT )
	{
		PlacedZipline CurrentZipline = PlacedZiplines[0]
		ToolZipline_DestroyZipline( CurrentZipline, true )
		PlacedZiplines.remove( 0 )
	}

	return NewZipline;
}

entity function ToolZipline_CreateAnchorEntity( vector Pos, vector Angles, float Offset )
{
	entity prop_dynamic = CreateEntity( "prop_dynamic" );
	prop_dynamic.SetValueForModelKey( ZIPLINE_ANCHOR_MODEL );
	prop_dynamic.kv.fadedist = -1;
	prop_dynamic.kv.renderamt = 255;
	prop_dynamic.kv.rendercolor = "255 255 255";
	prop_dynamic.kv.solid = 0; // 0 = no collision, 2 = bounding box, 6 = use vPhysics, 8 = hitboxes only
	prop_dynamic.kv.modelscale = 1
	SetTeam( prop_dynamic, TEAM_BOTH );	// need to have a team other then 0 or it won't take impact damage

	vector pos = Pos - AnglesToRight( Angles ) * Offset
	prop_dynamic.SetOrigin( pos );
	prop_dynamic.SetAngles( Angles );
	DispatchSpawn( prop_dynamic );
	return prop_dynamic;
}

void function ToolZipline_UpdateZiplines()
{
	while( true )
	{
		for( int i = PlacedZiplines.len() - 1; i >= 0; --i )
		{
			PlacedZipline CurrentZipline = PlacedZiplines[i];
			if( !IsValid( CurrentZipline.AnchorStart ) || !IsValid( CurrentZipline.AnchorEnd ) )
			{
				ToolZipline_DestroyZipline( CurrentZipline, true );
				PlacedZiplines.remove( i );
			}
			else
			{
				if( CurrentZipline.AnchorStart.GetOrigin() != CurrentZipline.StartLocation || CurrentZipline.AnchorEnd.GetOrigin() != CurrentZipline.EndLocation )
				{
					ToolZipline_DestroyZipline( CurrentZipline );

					CurrentZipline.StartLocation = CurrentZipline.AnchorStart.GetOrigin();
					CurrentZipline.EndLocation = CurrentZipline.AnchorEnd.GetOrigin();

					ZipLine z = CreateZipLine( CurrentZipline.StartLocation + ZIPLINE_ANCHOR_OFFSET, CurrentZipline.EndLocation + ZIPLINE_ANCHOR_OFFSET, ZIPLINE_autoDetachDistance, ZIPLINE_MoveSpeedScale );
					CurrentZipline.start = z.start;
					CurrentZipline.mid = z.mid;
					CurrentZipline.end = z.end;
				}
			}
		}

		WaitFrame();
	}
}

void function ToolZipline_DestroyZipline( PlacedZipline zip, bool completeDestroy = false )
{
	if( IsValid( zip.start ) )
	{
		zip.start.Destroy();
	}
	if( IsValid( zip.mid ) )
	{
		zip.mid.Destroy();
	}
	if( IsValid( zip.end ) )
	{
		zip.end.Destroy();
	}
	if( completeDestroy )
	{
		if( IsValid( zip.AnchorStart ) )
		{
			zip.AnchorStart.Destroy();
		}
		if( IsValid( zip.AnchorEnd ) )
		{
			zip.AnchorEnd.Destroy();
		}
	}
}

void function ToolZipline_DestroyAfterTime( PlacedZipline zip, float delay )
{
	wait delay
	if( IsValid( zip.start ) )
	{
		zip.start.Destroy();
	}
	if( IsValid( zip.mid ) )
	{
		zip.mid.Destroy();
	}
	if( IsValid( zip.end ) )
	{
		zip.end.Destroy();
	}
	if( IsValid( zip.AnchorStart ) )
	{
		zip.AnchorStart.Destroy();
	}
	if( IsValid( zip.AnchorEnd ) )
	{
		zip.AnchorEnd.Destroy();
	}
}
#endif
