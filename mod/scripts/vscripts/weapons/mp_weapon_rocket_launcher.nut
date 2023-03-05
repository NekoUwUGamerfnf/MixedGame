untyped

global function MpWeaponRocketLauncher_Init

global function OnWeaponActivate_weapon_rocket_launcher
global function OnWeaponDeactivate_weapon_rocket_launcher
global function OnWeaponPrimaryAttack_weapon_rocket_launcher
global function OnWeaponOwnerChanged_weapon_rocket_launcher

// modified callbacks
global function OnProjectileCollision_weapon_rocket_launcher

global function OnWeaponStartZoomIn_weapon_rocket_launcher
global function OnWeaponStartZoomOut_weapon_rocket_launcher

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_rocket_launcher
global function OnWeaponNpcPrimaryAttack_S2S_weapon_rocket_launcher
#endif // #if SERVER


//14 //RUMBLE_FLAT_BOTH
const LOCKON_RUMBLE_INDEX 	= 1 //RUMBLE_PISTOL
const LOCKON_RUMBLE_AMOUNT	= 45
const S2S_MISSILE_SPEED = 2500
const S2S_MISSILE_HOMING = 5000

const float GUIDED_MISSILE_LIFETIME = 20

function MpWeaponRocketLauncher_Init()
{
	RegisterSignal( "StopLockonRumble" )
	RegisterSignal( "StopGuidedLaser" )
	RegisterSignal( "ADSLaserStop" )
}

function MissileThink( weapon, missile )
{
	expect entity( missile )

	#if SERVER
		missile.EndSignal( "OnDestroy" )

		bool playedWarning = false

		while ( IsValid( missile ) )
		{
			entity target = missile.GetMissileTarget()

			if ( IsValid( target ) && target.IsPlayer() )
			{
				float distance = Distance( missile.GetOrigin(), target.GetOrigin() )

				if ( distance < 1536 && !playedWarning )
				{
					EmitSoundOnEntityOnlyToPlayer( target, target, "titan_cockpit_missile_close_warning" )
					playedWarning = true
				}
			}

			WaitFrame()
		}
	#endif
}

void function OnWeaponActivate_weapon_rocket_launcher( entity weapon )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.missileThinkThread <- MissileThink
		weapon.s.initialized <- true
	}

	bool hasGuidedMissiles = weapon.HasMod( "guided_missile" )

	if ( !hasGuidedMissiles )
	{
		if( weapon.HasMod("no_lock_required") )
			SmartAmmo_SetAllowUnlockedFiring( weapon, true )
		else
			SmartAmmo_SetAllowUnlockedFiring( weapon, !IsMultiplayer() )
		if ( IsSingleplayer() )
		{
			SmartAmmo_SetMissileSpeed( weapon, 1750 )
			SmartAmmo_SetMissileHomingSpeed( weapon, 70 )

			if ( weapon.HasMod( "burn_mod_rocket_launcher" ) )
				SmartAmmo_SetMissileSpeedLimit( weapon, 1250 )
			else if ( weapon.HasMod( "sp_s2s_settings" ) )
			{
				SmartAmmo_SetMissileSpeedLimit( weapon, 9000 )
				SmartAmmo_SetMissileSpeed( weapon, S2S_MISSILE_SPEED )
				SmartAmmo_SetMissileHomingSpeed( weapon, S2S_MISSILE_HOMING )
			}
			else
				SmartAmmo_SetMissileSpeedLimit( weapon, 900 )
		}
		else
		{
			SmartAmmo_SetMissileSpeed( weapon, 1200 )
			SmartAmmo_SetMissileHomingSpeed( weapon, 125 )

			if ( weapon.HasMod( "burn_mod_rocket_launcher" ) )
				SmartAmmo_SetMissileSpeedLimit( weapon, 1300 )
			else
				SmartAmmo_SetMissileSpeedLimit( weapon, 1400 )
		}

		SmartAmmo_SetMissileShouldDropKick( weapon, false )  // TODO set to true to see drop kick behavior issues
		SmartAmmo_SetUnlockAfterBurst( weapon, true )
	}

	entity weaponOwner = weapon.GetWeaponOwner()

	if ( hasGuidedMissiles )
	{
		if ( !("guidedLaserPoint" in weaponOwner.s) )
			weaponOwner.s.guidedLaserPoint <- null

		
		thread CalculateGuidancePoint( weapon, weaponOwner )
	}
}

void function OnWeaponDeactivate_weapon_rocket_launcher( entity weapon )
{
	if ( weapon.HasMod( "guided_missile" ) )
	{
		weapon.Signal( "StopGuidedLaser" )
	}
}

var function OnWeaponPrimaryAttack_weapon_rocket_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	float zoomFrac = weaponOwner.GetZoomFrac()
	if ( zoomFrac < 1 )
		return 0

	vector angles = VectorToAngles( weaponOwner.GetViewVector() )
	vector right = AnglesToRight( angles )
	vector up = AnglesToUp( angles )
	#if SERVER
		if ( weaponOwner.GetTitanSoulBeingRodeoed() != null )
			attackParams.pos = attackParams.pos + up * 20
		if( weapon.HasMod( "no_lock_required" ) || weapon.HasMod( "guided_missile" ) )
			RocketEffectFix( weaponOwner, weapon )
	#endif

	if ( !weapon.HasMod( "guided_missile" ) )
	{
		int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.projectileImpact, damageTypes.explosive )

		if ( fired )
		{
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		}

		return fired
	}
	else
	{
		if( !weapon.IsWeaponAdsButtonPressed() )
			return 0

		bool shouldPredict = weapon.ShouldPredictProjectiles()
		#if CLIENT
			if ( !shouldPredict )
				return 1
		#endif

		float speed = 1200.0
		if ( weapon.HasMod("titanhammer") )
			speed = 800.0

		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, speed, damageTypes.projectileImpact | DF_IMPACT, damageTypes.explosive, false, shouldPredict )

		if ( missile )
		{
			if( "guidedMissileTarget" in weapon.s && IsValid( weapon.s.guidedMissileTarget ) )
			{
				missile.SetMissileTarget( weapon.s.guidedMissileTarget, Vector( 0, 0, 0 ) )
				missile.SetHomingSpeeds( 300, 0 )
			}

			InitializeGuidedMissile( weaponOwner, missile )
			#if SERVER // for better missile controling?
			thread GuidedMissileReloadThink( weapon, weaponOwner, missile )
			#endif
		}
	}
}

void function OnProjectileCollision_weapon_rocket_launcher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
#if SERVER
	array<string> mods = projectile.ProjectileGetMods()
	if( mods.contains( "no_lock_required" ) || mods.contains( "guided_missile" ) )
	{
		// do a fake explosion effect for better client visual, hardcoded!..
		float creationTime = projectile.GetProjectileCreationTime()
		float maxFixTime = creationTime + 0.3 // hope this will pretty much fix client visual
		if ( Time() < maxFixTime )
			PlayImpactFXTable( pos, projectile, "exp_rocket_archer", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
		//PlayFX( $"P_impact_exp_lrg_metal", pos ) // a single FX won't work on some condition... consider a better ImpactEffectTable
		//EmitSoundAtPosition( TEAM_UNASSIGNED, pos, "Explo_Archer_Impact_3P" )
	}
#endif
}

void function OnWeaponStartZoomIn_weapon_rocket_launcher( entity weapon )
{
	if( !weapon.HasMod( "guided_missile" ) )
		return
	entity weaponOwner = weapon.GetWeaponOwner()
	thread ADSLaserStart( weaponOwner, weapon )
}

void function OnWeaponStartZoomOut_weapon_rocket_launcher( entity weapon )
{
	if( !weapon.HasMod( "guided_missile" ) )
		return
	entity weaponOwner = weapon.GetWeaponOwner()
	ADSLaserEnd( weapon )
}

void function ADSLaserStart( entity player, entity weapon )
{
	WaitFrame()
	if( !IsAlive( player ) || !IsValid( weapon ) )
		return
	
	if( player.GetActiveWeapon() != weapon )
		return

	weapon.PlayWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim", "flashlight" )
}

void function ADSLaserEnd( entity weapon )
{
	weapon.StopWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim" )
}

/* fake ads laser version
void function ADSLaserStart( entity player, entity weapon )
{
	#if SERVER
	entity fx = PlayLoopFXOnEntity( $"P_wpn_lasercannon_aim_short", weapon, "muzzle_flash", null, null, ENTITY_VISIBLE_TO_ENEMY | ENTITY_VISIBLE_TO_FRIENDLY )
	fx.SetOwner( player )

	OnThreadEnd(
		function(): ( fx )
		{
			if( IsValid( fx ) )
				fx.Destroy()
		}
	)

	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.WaitSignal( "ADSLaserStop" )
	#endif
}

void function ADSLaserEnd( entity player, entity weapon )
{
	#if SERVER
	if( IsAlive( player ) && IsValid( weapon ) )
	{
		player.Signal( "ADSLaserStop" )
	}
	#endif
}
*/

#if SERVER
void function RocketEffectFix( entity player, entity weapon )
{
	//WaitFrame()
	if( IsAlive( player ) && IsValid( weapon ) )
	{
		EmitSoundOnEntityOnlyToPlayer( weapon, player, "Weapon_Archer_Fire_1P" )
		weapon.PlayWeaponEffect( $"P_wpn_muzzleflash_law_fp", $"P_wpn_muzzleflash_law", "muzzle_flash" )
	}
}

var function OnWeaponNpcPrimaryAttack_S2S_weapon_rocket_launcher( entity weapon, WeaponPrimaryAttackParams attackParams, entity target )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	bool shouldPredict = false
	entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, S2S_MISSILE_SPEED, damageTypes.projectileImpact | DF_IMPACT, damageTypes.explosive, false, shouldPredict )

	if ( missile )
	{
		missile.kv.lifetime = 20
		missile.SetMissileTarget( target, < 0, 0, 0 > )
		missile.SetHomingSpeeds( S2S_MISSILE_HOMING, 0 )
	}
}

var function OnWeaponNpcPrimaryAttack_weapon_rocket_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	/*
	// NPC can shoot the weapon at non-players, but when shooting at players it must be a titan
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) )
	{
		entity enemy = owner.GetEnemy()
		if ( IsValid( enemy ) )
		{
			if ( enemy.IsPlayer() && !enemy.IsTitan() )
				return
		}
	}
	*/

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, 1800.0, damageTypes.projectileImpact, damageTypes.explosive, false, PROJECTILE_NOT_PREDICTED )
	if ( missile )
	{
		missile.InitMissileForRandomDriftFromWeaponSettings( attackParams.pos, attackParams.dir )
		if ( weapon.w.missileFiredCallback != null )
		{
			weapon.w.missileFiredCallback( missile, weapon.GetWeaponOwner() )
		}
	}
}
#endif // #if SERVER

//GUIDED MISSILE FUNCTIONS
function CalculateGuidancePoint( entity weapon, entity weaponOwner )
{
	weaponOwner.EndSignal( "OnDestroy" )
	weapon.EndSignal( "OnDestroy" )
	weapon.EndSignal( "StopGuidedLaser" )

	entity info_target
	#if SERVER
		info_target = CreateEntity( "info_target" )
		info_target.SetOrigin( weapon.GetOrigin() )
		info_target.SetInvulnerable()
		DispatchSpawn( info_target )
		weapon.s.guidedMissileTarget <- info_target
	#endif

	OnThreadEnd(
		function() : ( weapon, info_target )
		{
			if ( IsValid( info_target ) )
			{
				info_target.Kill_Deprecated_UseDestroyInstead()
				delete weapon.s.guidedMissileTarget
			}
		}
	)

	while ( true )
	{
		if ( !IsValid_ThisFrame( weaponOwner ) || !IsValid_ThisFrame( weapon ) )
			return

		weaponOwner.s.guidedLaserPoint = null
		if ( weapon.IsWeaponInAds())
		{
			TraceResults result = GetViewTrace( weaponOwner )
			weaponOwner.s.guidedLaserPoint = result.endPos
			#if SERVER
				info_target.SetOrigin( result.endPos )
			#endif
		}

		WaitFrame()
	}
}

function InitializeGuidedMissile( entity weaponOwner, entity missile )
{
		missile.s.guidedMissile <- true
		if ( "missileInFlight" in weaponOwner.s )
			weaponOwner.s.missileInFlight = true
		else
			weaponOwner.s.missileInFlight <- true

		missile.kv.lifetime = GUIDED_MISSILE_LIFETIME

		#if SERVER
			missile.SetOwner( weaponOwner )
			thread playerHasMissileInFlight( weaponOwner, missile )
		#endif
}

#if SERVER
function playerHasMissileInFlight( entity weaponOwner, entity missile )
{
	weaponOwner.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( weaponOwner )
		{
			if ( IsValid( weaponOwner ) )
			{
				weaponOwner.s.missileInFlight = false
				//Using a remote call because if this thread is on the client it gets triggered prematurely due to prediction.
				Remote_CallFunction_NonReplay( weaponOwner, "ServerCallback_GuidedMissileDestroyed" )
			}
		}
	)

	WaitSignal( missile, "OnDestroy" )
}

// modified function
void function GuidedMissileReloadThink( entity weapon, entity weaponOwner, entity missile )
{
	if( !weaponOwner.IsPlayer() )
		return
	weapon.EndSignal( "OnDestroy" )
	//weapon.AddMod( "disable_reload" ) // client will desync!
	//weapon.AddMod( "guided_missile_aiming" )
	weaponOwner.EndSignal( "OnDeath" )
	weaponOwner.EndSignal( "OnDestroy" )
	missile.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function():( weapon, weaponOwner )
		{
			if( IsValid( weapon ) )
			{
				if( !IsAlive( weaponOwner ) ) // i don't care! destroy it!
				{
					weapon.Destroy()
					return
				}
				thread HACK_ForceReloadLauncher( weapon, weaponOwner )
			}
			//if( IsValid( weapon ) )
			//{
			//	ADSLaserEnd( weapon )
			//	weaponOwner.HolsterWeapon()
			//	weapon.RemoveMod( "guided_missile_aiming" )
				//weapon.RemoveMod( "disable_reload" ) // client will desync!
			//	weaponOwner.DeployWeapon()
			//}
		}
	)
	
	while( true )
	{
		if( weaponOwner.IsInputCommandHeld( IN_RELOAD ) || weaponOwner.IsInputCommandHeld( IN_USE_AND_RELOAD ) )
			break
		if( weaponOwner.GetActiveWeapon() != weapon )
			break
		if( !weapon.IsWeaponAdsButtonPressed() )
			break
		WaitFrame()
	}
	//print( "guiding interrupted!" )
}

void function HACK_ForceReloadLauncher( entity weapon, entity weaponOwner )
{
	weapon.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDeath" )
	weaponOwner.EndSignal( "OnDestroy" )
	
	OnThreadEnd(
		function():( weapon, weaponOwner )
		{
			if( IsValid( weapon ) )
			{
				if( !IsAlive( weaponOwner ) ) // i don't care! destroy it!
				{
					weapon.Destroy()
					return
				}
				weapon.RemoveMod( "guided_missile_refresh" )
			}
		}
	)

	weaponOwner.HolsterWeapon()
	weapon.AddMod( "guided_missile_refresh" )
	weaponOwner.DeployWeapon()
	wait 1 // defensive fix, wait for player deploy weapon
	ADSLaserEnd( weapon )
	
	// wait for next time weapon begin ads, then remove mod, likely it must have been completely reloaded
	while( true ) 
	{
		WaitFrame()
		if( weaponOwner.GetActiveWeapon() != weapon )
			continue
		float zoomFrac = weaponOwner.GetZoomFrac()
		if ( zoomFrac >= 0.5 )
			break
	}
	//print( "adsing after reload!" )
	
	/*
	while( true )
	{
		WaitFrame()
		if( weaponOwner.GetActiveWeapon() != weapon )
			continue
		if( weapon.GetWeaponPrimaryClipCount() > 0 ) // done reloading!
		{
			if( !weapon.IsReloading() && !weaponOwner.IsWallRunning() )
			{
				weaponOwner.HolsterWeapon()
				weaponOwner.DeployWeapon()
				break
			}
		}
		//if( !weapon.IsReloading() )
		//	break
	}
	print( "done reloading!" )
	*/
	
}
#endif // SERVER


void function OnWeaponOwnerChanged_weapon_rocket_launcher( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
		weapon.w.missileFiredCallback = null

	// modified! for npc swiching to it
	/* // this will make all npcs carrying a red line, don't know why
	entity weaponOwner = weapon.GetWeaponOwner()
	if ( IsValid( weaponOwner ) )
	{
		if ( weaponOwner.IsNPC() )
			weapon.PlayWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim", "flashlight" )
		else
			weapon.StopWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim" )
	}
	else
		weapon.StopWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim" )
	*/
	#endif
}