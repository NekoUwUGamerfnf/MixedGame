untyped

global function MpTitanweaponRocketeetRocketStream_Init

global function OnWeaponPrimaryAttack_TitanWeapon_Rocketeer_RocketStream
global function OnWeaponOwnerChanged_TitanWeapon_Rocketeer_RocketStream
global function OnWeaponDeactivate_TitanWeapon_Rocketeer_RocketStream

global function OnWeaponStartZoomIn_TitanWeapon_Rocketeer_RocketStream
global function OnWeaponStartZoomOut_TitanWeapon_Rocketeer_RocketStream

#if SERVER
global function OnWeaponNpcPrimaryAttack_TitanWeapon_Rocketeer_RocketStream
#endif // #if SERVER

#if CLIENT
global function OnClientAnimEvent_TitanWeapon_Rocketeer_RocketStream
#endif // #if CLIENT

const DRAW_DEBUG = 0
const DEBUG_FAIL = 0
const MERGEDEBUG = 0
const DEBUG_TIME = 5
const MIN_HEIGHT = 70
const POINT_FROM = 0
const POINT_TO = 1
const POINT_NEXT = 2
const POINT_FUTURE = 3
const TRACE_DIST_PER_SECTION = 800
const WALL_BUFFER = 74
const STEEPNESS_DOT = 0.6
const MISSILE_LOOKAHEAD = 150 // 150
const MATCHSLOPERISE = 40 // 32
const MISSILE_LIFETIME = 8.0
const FUDGEPOINT_RIGHT = 100
const FUDGEPOINT_UP = 150
const PROX_MISSILE_RANGE = 160
const BURN_CLUSTER_EXPLOSION_INNER_RADIUS = 150
const BURN_CLUSTER_EXPLOSION_RADIUS = 220
const BURN_CLUSTER_EXPLOSION_DAMAGE = 66
const BURN_CLUSTER_EXPLOSION_DAMAGE_HEAVY_ARMOR = 100
const BURN_CLUSTER_NPC_EXPLOSION_DAMAGE = 66
const BURN_CLUSTER_NPC_EXPLOSION_DAMAGE_HEAVY_ARMOR = 100

const STRAIGHT_CONDENSE_DELAY = 0.3
const STRAIGHT_CONDENSE_TIME = 1.0
const STRAIGHT_EXPAND_DIST = 30.0
const STRAIGHT_CONDENSE_DIST = 20.0

const asset AMPED_SHOT_PROJECTILE = $"models/weapons/bullets/temp_triple_threat_projectile_large.mdl"

function MpTitanweaponRocketeetRocketStream_Init()
{
	RegisterSignal( "FiredWeapon" )
	RegisterSignal( "KillBruteShield" )

	PrecacheParticleSystem( $"wpn_muzzleflash_xo_rocket_FP" )
	PrecacheParticleSystem( $"wpn_muzzleflash_xo_rocket" )
	PrecacheParticleSystem( $"wpn_muzzleflash_xo_fp" )
	PrecacheParticleSystem( $"P_muzzleflash_xo_mortar" )

#if SERVER
	PrecacheModel( AMPED_SHOT_PROJECTILE )
#endif // #if SERVER
}

void function OnWeaponStartZoomIn_TitanWeapon_Rocketeer_RocketStream( entity weapon )
{
#if SERVER
	// cluster missiles and fast shots
	if ( weapon.HasMod( "burn_mod_titan_rocket_launcher" ) || 
		 weapon.HasMod( "rocketeer_ammo_swap" ) ||
		 weapon.HasMod( "brute4_fast_shot" ) ||
		 weapon.HasMod( "rocketstream_fast" ) )
		return

	if( weapon.HasMod( "brute4_rocket_launcher" ) ) // brute4
		weapon.AddMod( "brute4_fast_shot" )
	else // vanilla
		weapon.AddMod( "rocketstream_fast" )
	
	if ( weapon.HasMod( "brute_rocket" ) ) // brute additional mod
		weapon.AddMod( "brute_rocket_fast_shot" )
#endif
	//weapon.PlayWeaponEffectNoCull( $"wpn_arc_cannon_electricity_fp", $"wpn_arc_cannon_electricity", "muzzle_flash" )
	//weapon.PlayWeaponEffectNoCull( $"wpn_arc_cannon_charge_fp", $"wpn_arc_cannon_charge", "muzzle_flash" )
	//weapon.EmitWeaponSound( "arc_cannon_charged_loop" )
}

void function OnWeaponStartZoomOut_TitanWeapon_Rocketeer_RocketStream( entity weapon )
{
#if SERVER
	// cluster missiles
	if ( weapon.HasMod( "burn_mod_titan_rocket_launcher" ) || 
		 weapon.HasMod( "rocketeer_ammo_swap" ) )
		return

	if( weapon.HasMod( "brute4_rocket_launcher" ) ) // brute4
		weapon.RemoveMod( "brute4_fast_shot" )
	else // vanilla
		weapon.RemoveMod( "rocketstream_fast" )

	if ( weapon.HasMod( "brute_rocket" ) ) // brute additional mod
		weapon.RemoveMod( "brute_rocket_fast_shot" )
#endif
	//weapon.StopWeaponEffect( $"wpn_arc_cannon_charge_fp", $"wpn_arc_cannon_charge" )
	//weapon.StopWeaponEffect( $"wpn_arc_cannon_electricity_fp", $"wpn_arc_cannon_electricity" )
	//weapon.StopWeaponSound( "arc_cannon_charged_loop" )
}


#if CLIENT
void function OnClientAnimEvent_TitanWeapon_Rocketeer_RocketStream( entity weapon, string name )
{
	if ( name == "muzzle_flash" )
	{
		weapon.PlayWeaponEffect( $"wpn_muzzleflash_xo_fp", $"wpn_muzzleflash_xo_rocket", "muzzle_flash" )
	}
}
#endif // #if CLIENT

var function OnWeaponPrimaryAttack_TitanWeapon_Rocketeer_RocketStream( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()
	float zoomFrac = player.GetZoomFrac()
	if ( zoomFrac < 1 && zoomFrac > 0)
		return 0

	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return 1
	#endif

	return FireMissileStream( weapon, attackParams, PROJECTILE_PREDICTED )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_TitanWeapon_Rocketeer_RocketStream( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireMissileStream( weapon, attackParams, PROJECTILE_NOT_PREDICTED )
}
#endif // #if SERVER

int function FireMissileStream( entity weapon, WeaponPrimaryAttackParams attackParams, bool predicted )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	bool adsPressed = weapon.IsWeaponInAds()
	bool hasBurnMod = weapon.HasMod( "burn_mod_titan_rocket_launcher" )
	bool isBrute4 = weapon.HasMod( "brute4_rocket_launcher" )
	bool hasAmmoSwap = weapon.HasMod( "rocketeer_ammo_swap" )
	bool has_s2s_npcMod = weapon.HasMod( "sp_s2s_settings_npc" )
	bool has_mortar_mod = weapon.HasMod( "coop_mortar_titan" )

	if ( adsPressed || hasBurnMod || hasAmmoSwap )
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Rocket_Launcher_Amped_Fire_1P", "Weapon_Titan_Rocket_Launcher_Amped_Fire_3P" )
	else
		weapon.EmitWeaponSound_1p3p( "Weapon_Titan_Rocket_Launcher.RapidFire_1P", "Weapon_Titan_Rocket_Launcher.RapidFire_3P" )

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( !IsValid( weaponOwner ) )
		return 0
	weaponOwner.Signal( "KillBruteShield" )

	if ( !adsPressed && !hasBurnMod && !hasAmmoSwap && !has_s2s_npcMod && !has_mortar_mod )
	{
		int shots = minint( weapon.GetProjectilesPerShot(), weapon.GetWeaponPrimaryClipCount() )
		FireMissileStream_Spiral( weapon, attackParams, predicted, shots )
		return shots
	}
	else
	{
		//attackParams.pos = attackParams.pos + Vector( 0, 0, -20 )
		// float missileSpeed = 2800
		float missileSpeed = 6000
		if( isBrute4 )
			missileSpeed = 8000
		if ( has_s2s_npcMod || has_mortar_mod )
			missileSpeed = 2500

		int impactFlags = (DF_IMPACT | DF_GIB | DF_KNOCK_BACK)

		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, missileSpeed, impactFlags, damageTypes.explosive | DF_KNOCK_BACK, predicted, 0 )
		if ( bolt != null )
		{
			//bolt.kv.gravity = -0.1
			SetTeam( bolt, weaponOwner.GetTeam() )
		#if SERVER
			string whizBySound = "Weapon_Sidwinder_Projectile"
			EmitSoundOnEntity( bolt, whizBySound )
		#endif
			bolt.kv.rendercolor = "0 0 0"
			bolt.kv.renderamt = 0
			bolt.kv.fadedist = 1
			bolt.kv.gravity = 0.001
		}
		//entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, missileSpeed, impactFlags, damageTypes.explosive | DF_KNOCK_BACK, false, predicted )

// 		if ( missile )
// 		{
// 			SetTeam( missile, weaponOwner.GetTeam() )
// #if SERVER
// 			string whizBySound = "Weapon_Sidwinder_Projectile"
// 			EmitSoundOnEntity( missile, whizBySound )
// 			if ( weapon.w.missileFiredCallback != null )
// 			{
// 				weapon.w.missileFiredCallback( missile, weaponOwner )
// 			}
// #endif // #if SERVER
// 		}

		int cost = weapon.GetWeaponSettingInt(eWeaponVar.ammo_per_shot)

		return cost
	}

	unreachable
}


int function FindIdealMissileConfiguration( int numMissiles, int i )
{
	//We're locked into 4 missiles from passing in 0-3, and in the case of 2 we want to fire the horizontal missiles for aesthetic reasons.
	int idealMissile
	if ( numMissiles == 2 )
	{
		if ( i == 0 )
			idealMissile = 1
		else
			idealMissile = 3
	}
	else
	{
		idealMissile = i
	}

	return idealMissile
}

vector function FindStraightMissileDir( vector dir, int i )
{
	vector angles = VectorToAngles( dir )
	switch ( i )
	{
		case 0:
			return AnglesToUp( angles )
			break
		case 1:
			return -AnglesToRight( angles )
			break
		case 2:
			return -AnglesToUp( angles )
			break
		case 3:
			return AnglesToRight( angles )
	}
	return < 0,0,0 >
}

void function FireMissileStream_Spiral( entity weapon, WeaponPrimaryAttackParams attackParams, bool predicted, int numMissiles = 4 )
{
	//attackParams.pos = attackParams.pos + Vector( 0, 0, -20 )
	array<entity> missiles
	array<vector> straightDir
	float missileSpeed = 3000
	bool straight = weapon.HasMod( "straight_shot" )

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( IsSingleplayer() && weaponOwner.IsPlayer() )
		missileSpeed = 2000

	for ( int i = 0; i < numMissiles; i++ )
	{
		int impactFlags = (DF_IMPACT | DF_GIB | DF_KNOCK_BACK)
		vector pos = attackParams.pos
		int missileNumber = FindIdealMissileConfiguration( numMissiles, i )
		if ( straight )
		{
			straightDir.append( FindStraightMissileDir( attackParams.dir, missileNumber ) )
			pos += straightDir[i] * STRAIGHT_EXPAND_DIST
		}

		entity missile = weapon.FireWeaponMissile( pos, attackParams.dir, missileSpeed, impactFlags, damageTypes.explosive | DF_KNOCK_BACK, false, predicted )
		if ( missile )
		{
			//Spreading out the missiles
			if ( !straight )
				missile.InitMissileSpiral( attackParams.pos, attackParams.dir, missileNumber, false, false )

			//missile.s.launchTime <- Time()
			// each missile knows about the other missiles, so they can all blow up together
			//missile.e.projectileGroup = missiles
			missile.kv.lifetime = MISSILE_LIFETIME
			missile.SetSpeed( missileSpeed );
			SetTeam( missile, weapon.GetWeaponOwner().GetTeam() )

			missiles.append( missile )

#if SERVER
			EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )
#endif // #if SERVER
		}
	}

	if ( straight && missiles.len() > 0 )
		thread MissileStream_CondenseSpiral( missiles, straightDir, missileSpeed )
}

void function MissileStream_CondenseSpiral( array<entity> missiles, array<vector> straightDir, float missileSpeed )
{
	wait STRAIGHT_CONDENSE_DELAY

	ArrayRemoveInvalid( missiles )
	if ( missiles.len() == 0 )
		return

	array<vector> targetPos, velocities
	foreach ( i, missile in missiles )
	{
		vector target = -straightDir[i] * STRAIGHT_CONDENSE_DIST
		velocities.append( missile.GetVelocity() )
		targetPos.append( missile.GetOrigin() + velocities[i] * STRAIGHT_CONDENSE_TIME + target )
		missile.SetVelocity( velocities[i] + target / STRAIGHT_CONDENSE_TIME )
	}

	wait STRAIGHT_CONDENSE_TIME

	foreach ( i, missile in missiles )
	{
		if ( IsValid( missile ) )
		{
			missile.SetOrigin( targetPos[i] )
			missile.SetVelocity( velocities[i] )
		}
	}
}

void function OnWeaponOwnerChanged_TitanWeapon_Rocketeer_RocketStream( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
	weapon.w.missileFiredCallback = null
	#endif
}

void function OnWeaponDeactivate_TitanWeapon_Rocketeer_RocketStream( entity weapon )
{
}