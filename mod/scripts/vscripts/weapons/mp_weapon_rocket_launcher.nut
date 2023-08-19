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

// modded rocket
const array<string> NO_LOCK_REQUIRED_MODS = // we should fix visual for these mods
[
	"no_lock_required",
	"guided_missile",
]
const float GUIDED_MISSILE_LIFETIME = 20 // guided missile lifetiime
// visual fix
struct
{
	table<entity, entity> rocketLaserTable // save existing laser effect
} file

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
		// modded weapon
		if( weapon.HasMod("no_lock_required") )
			SmartAmmo_SetAllowUnlockedFiring( weapon, true )
		else // vanilla behavior
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

	// modified to add rocket lasers
#if SERVER
	//if ( weaponOwner.IsNPC() )
	//	thread DelayedRocketLaserStart( weapon, weaponOwner )
#endif
}

void function OnWeaponDeactivate_weapon_rocket_launcher( entity weapon )
{
	if ( weapon.HasMod( "guided_missile" ) )
	{
		weapon.Signal( "StopGuidedLaser" )
	}

	// modified to add rocket lasers
	entity weaponOwner = weapon.GetWeaponOwner()
#if SERVER
	if ( weaponOwner.IsNPC() )
		weapon.StopWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim" )
	
	// defensive fix
	ADSLaserEnd( weapon )
#endif
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
	#endif

	if ( !weapon.HasMod( "guided_missile" ) )
	{
		int fired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.projectileImpact, damageTypes.explosive )

		if ( fired )
		{
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

			// no lock required version
			#if SERVER
				if ( weapon.HasMod( "no_lock_required" ) )
					RocketEffectFix( weapon )
			#endif
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
			// modified here
			#if SERVER
				RocketEffectFix( weapon ) // fix effect
				thread GuidedMissileReloadThink( weapon, weaponOwner, missile ) // for better missile controling?
			#endif
		}
	}
}

void function OnProjectileCollision_weapon_rocket_launcher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> refiredMods = Vortex_GetRefiredProjectileMods( projectile )
	// direct hit
	if ( refiredMods.contains( "direct_hit" ) )
        OnProjectileCollision_DirectHit( projectile, pos, normal, hitEnt, hitbox, isCritical )

#if SERVER
	// visual fix think
	array<string> mods = projectile.ProjectileGetMods() // only contains explosion stuffs, no need to use Vortex_GetRefiredProjectileMods()
	bool shouldFixVisual = false
	foreach ( string mod in NO_LOCK_REQUIRED_MODS )
	{
		if ( mods.contains( mod ) )
		{
			shouldFixVisual = true
			break
		}
	}
	//print( "shouldFixVisual: " + string( shouldFixVisual ) )
	if ( shouldFixVisual )
	{
		// do a fake explosion effect for better client visual, hardcoded!
		float creationTime = projectile.GetProjectileCreationTime()
		float maxFixTime = creationTime + 0.3 // hope this will pretty much fix client visual
		if ( Time() < maxFixTime )
			PlayImpactFXTable( pos, projectile, "exp_rocket_archer", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
	}
#endif
}

#if SERVER
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
	// NPC can shoot the weapon at non-players, but when shooting at players it must be a titan
	// nessie: add back this if we need
	if ( weapon.HasMod( "npc_disable_fire_at_pilot" ) ) // now specified for this mod
	{
		entity owner = weapon.GetWeaponOwner()
		if ( IsValid( owner ) )
		{
			entity enemy = owner.GetEnemy()
			if ( IsValid( enemy ) )
			{
				if ( enemy.IsPlayer() && !enemy.IsTitan() )
					return 0
			}
		}
	}

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
#endif // SERVER


void function OnWeaponOwnerChanged_weapon_rocket_launcher( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if SERVER
		weapon.w.missileFiredCallback = null
	#endif
}


// modded callbacks
void function OnWeaponStartZoomIn_weapon_rocket_launcher( entity weapon )
{
	if( !weapon.HasMod( "guided_missile" ) )
		return
#if SERVER
	ADSLaserStart( weapon )
#endif
}

void function OnWeaponStartZoomOut_weapon_rocket_launcher( entity weapon )
{
	if( !weapon.HasMod( "guided_missile" ) )
		return
	entity weaponOwner = weapon.GetWeaponOwner()
#if SERVER
	ADSLaserEnd( weapon )
#endif
}

// modded functions
#if SERVER
void function ADSLaserStart( entity weapon )
{
	thread ADSLaserStart_Threaded( weapon )
}

void function ADSLaserStart_Threaded( entity weapon )
{
	ADSLaserEnd( weapon ) // defensive fix: stop existing laser
	
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return
	if ( !owner.IsPlayer() )
		return

	WaitFrame()
	if( !IsAlive( owner ) || !IsValid( weapon ) )
		return
	if( owner.GetActiveWeapon() != weapon )
		return

	entity viewModelEnt = owner.GetViewModelEntity()
	if ( IsValid( viewModelEnt ) && EntHasModelSet( viewModelEnt ) )
	{
		if ( !( viewModelEnt in file.rocketLaserTable ) )
			file.rocketLaserTable[ viewModelEnt ] <- null
		if ( IsValid( file.rocketLaserTable[ viewModelEnt ] ) ) // already has a laser valid
			return
		// get attachment validation
		int attachID = viewModelEnt.LookupAttachment( "flashlight" )
		if ( attachID <= 0 )
			return
		// make non_predicted client have proper fx
		entity fx = PlayLoopFXOnEntity( $"P_wpn_lasercannon_aim", viewModelEnt, "flashlight" )
		fx.SetStopType( "DestroyImmediately" ) // ensure this fx gets destroyed immediately
		file.rocketLaserTable[ viewModelEnt ] = fx
	}
	// thirdperson fx
	weapon.PlayWeaponEffect( $"", $"P_wpn_lasercannon_aim", "flashlight" )
}

void function ADSLaserEnd( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return
	if ( !owner.IsPlayer() )
		return

	entity viewModelEnt = owner.GetViewModelEntity()
	if ( IsValid( viewModelEnt ) )
	{
		entity laserFX
		if ( viewModelEnt in file.rocketLaserTable )
			laserFX = file.rocketLaserTable[ viewModelEnt ]
		if ( IsValid( laserFX ) )
		{
			EntFireByHandle( laserFX, "Stop", "", 0, null, null )
			laserFX.Destroy()
		}
	}
	// thirdperson fx
	weapon.StopWeaponEffect( $"", $"P_wpn_lasercannon_aim" )
}

// modified function
void function GuidedMissileReloadThink( entity weapon, entity weaponOwner, entity missile )
{
	if( !weaponOwner.IsPlayer() )
		return
	weapon.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDeath" )
	weaponOwner.EndSignal( "OnDestroy" )
	missile.EndSignal( "OnDestroy" ) // wait for missile explode

	table fireInterval = {}
	fireInterval.timeLeft <- 0.0

	OnThreadEnd
	(
		function():( weapon, weaponOwner, fireInterval )
		{
			//print( "guiding end!" )
			if( IsValid( weapon ) )
			{
				thread DelayedEnableRocketAttack( weapon, expect float ( fireInterval.timeLeft ) )
				//weapon.RemoveMod( "disable_reload" ) // client can't predict this
			}
		}
	)
	
	// try to prevent SetNextAttackAllowedTime() during a firing interval( which will make it not work )
	float minReloadDelay = 1 / weapon.GetWeaponSettingFloat( eWeaponVar.fire_rate )
	fireInterval.timeLeft = minReloadDelay
	float minReloadTime = Time() + minReloadDelay
	weapon.AddMod( "disable_reload" ) // client can't predict this and it's not necessary, just to prevent softlock
	while( true )
	{
		if ( Time() >= minReloadTime ) // must in valid reload time to trigger manually reloading
		{
			fireInterval.timeLeft = 0.0
			if( weaponOwner.IsInputCommandHeld( IN_RELOAD ) || weaponOwner.IsInputCommandHeld( IN_USE_AND_RELOAD ) )
				break
			if( weaponOwner.GetActiveWeapon() != weapon )
				break
			if( !weapon.IsWeaponAdsButtonPressed() )
				break
		}
		else // still in interval
			fireInterval.timeLeft = minReloadTime - Time()
		WaitFrame()
	}
	//print( "guiding interrupted!" )
}

const float GUIDED_MISSILE_RELOAD_INTERVAL = 0.3
void function DelayedEnableRocketAttack( entity weapon, float delay )
{
	weapon.EndSignal( "OnDestroy" )
	wait delay + GUIDED_MISSILE_RELOAD_INTERVAL
	// refresh next attack time, so the weapon will start reloading. add 0.3s more for defensive fix
	weapon.SetNextAttackAllowedTime( Time() + GUIDED_MISSILE_RELOAD_INTERVAL )
	//weapon.SetWeaponPrimaryClipCount( 0 )
	// try to prevent SetNextAttackAllowedTime() while reloading, which will break ammo system
	wait GUIDED_MISSILE_RELOAD_INTERVAL + 0.2
	weapon.RemoveMod( "disable_reload" )
}

void function RocketEffectFix( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return
	if ( !owner.IsPlayer() )
		return

	if( IsAlive( owner ) && IsValid( weapon ) )
	{
		// play a sound
		EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_Archer_Fire_1P" )

		entity viewModelEnt = owner.GetViewModelEntity()
		// firstperson fx, force play it on vm
		if ( IsValid( viewModelEnt ) )
			thread RocketMuzzleThink( weapon, owner )
	}
}

const float MUZZLE_MAX_DURATION = 2.0 // assume this is the fx's duration
void function RocketMuzzleThink( entity weapon, entity owner )
{
	entity viewModelEnt = owner.GetViewModelEntity()
	if ( !IsValid( viewModelEnt ) || !EntHasModelSet( viewModelEnt ) )
		return
	// get attachment validation
	int attachID = viewModelEnt.LookupAttachment( "muzzle_flash" )
	if ( attachID <= 0 )
		return

	// firstperson fx, force play it on vm
	entity fx = PlayFXOnEntity( $"P_wpn_muzzleflash_law_fp", viewModelEnt, "muzzle_flash" )
	fx.SetStopType( "DestroyImmediately" ) // ensure this fx gets destroyed immediately
	viewModelEnt.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDestroy" )
	fx.EndSignal( "OnDestroy" )

	OnThreadEnd
	(
		function(): ( fx )
		{
			if ( IsValid( fx ) )
			{
				//print( "try to stop muzzle fx" )
				EffectStop( fx )
			}
			//else
			//	print( "fx destroyed" )
		}
	)

	float endTime = Time() + MUZZLE_MAX_DURATION
	while ( Time() < endTime )
	{
		entity activeWeapon = owner.GetActiveWeapon()
		if ( !IsValid( activeWeapon ) )
			break
		if ( activeWeapon != weapon ) // player switched weapon...
		{
			//print( "player switched weapon!" )
			break // try to stop fx
		}
		WaitFrame()
	}
}

void function DelayedRocketLaserStart( entity weapon, entity weaponOwner )
{
	if ( IsValid( weapon ) && IsValid( weaponOwner ) && weapon == weaponOwner.GetActiveWeapon() )
	{
		weapon.PlayWeaponEffect( $"P_wpn_lasercannon_aim", $"P_wpn_lasercannon_aim", "flashlight" )
	}
}
#endif