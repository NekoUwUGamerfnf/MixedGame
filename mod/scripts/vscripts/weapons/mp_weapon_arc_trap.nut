untyped

global function MpWeaponArcTrap_Init

global function OnWeaponTossReleaseAnimEvent_weapon_arc_trap
global function OnWeaponAttemptOffhandSwitch_weapon_arc_trap
global function OnWeaponTossPrep_weapon_arc_trap

#if SERVER
global function AddArcTrapTriggeredCallback
#endif

const float ARC_TRAP_ANGLE_LIMIT = 0.55
const asset ARC_TRAP_FX = $"P_wpn_arcTrap"
const asset ARC_TRAP_IDLE_FX = $"P_arcTrap_light"
const asset ARC_TRAP_START_FX = $"P_wpn_arcTrap_start"
const asset ARC_TRAP_ZAP_FX = $"P_wpn_arcTrap_beam"

const float ARC_TRAP_RISE_DURATION = 0.5
const float ARC_TRAP_DROP_DURATION = 0.5
const float ARC_TRAP_DURATION = 0.6
const float ARC_TRAP_COOLDOWN = 12.0

const float ARC_TRAP_RADIUS = 500.0

#if SERVER
struct
{
	array < void functionref( entity, var ) > arcTrapTriggerCallbacks = []
	// limited arc traps
	table< entity, array<entity> > playerOwnedArcTraps
	table<entity, int> arcTrapActivateCount
} file

// limited arc traps
const int ARC_TRAP_LIMIT = 2
const int ARC_TRAP_ACTIVATE_LIMIT = 2
const float ARC_TRAP_LIFETIME = 20
#endif

function MpWeaponArcTrap_Init()
{
	PrecacheParticleSystem( ARC_TRAP_FX )
	PrecacheParticleSystem( ARC_TRAP_START_FX )
	PrecacheParticleSystem( ARC_TRAP_IDLE_FX )
	PrecacheParticleSystem( ARC_TRAP_ZAP_FX )
	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_arc_trap, ArcTrap_DamagedTarget )
	RegisterSignal( "ActivateArcTrap" )
	RegisterSignal( "DeployArcTrap" )

	// make arc traps usable in any modes
	//if( GameRules_GetGameMode() != "fd" )
	RegisterSignal( "BoostRefunded" )

	// modified arctrap mods
	AddCallback_OnClientConnected( OnClientConnected )
	#endif
}

bool function OnWeaponAttemptOffhandSwitch_weapon_arc_trap( entity weapon )
{
	int ammoReq = weapon.GetAmmoPerShot()
	int currAmmo = weapon.GetWeaponPrimaryClipCount()
	if ( currAmmo < ammoReq )
		return false

	entity player = weapon.GetWeaponOwner()
	if ( player.IsPhaseShifted() )
		return false

	return true
}

var function OnWeaponTossReleaseAnimEvent_weapon_arc_trap( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	int ammoReq = weapon.GetAmmoPerShot()
	weapon.EmitWeaponSound_1p3p( GetGrenadeThrowSound_1p( weapon ), GetGrenadeThrowSound_3p( weapon ) )

	entity deployable = ThrowDeployable( weapon, attackParams, DEPLOYABLE_THROW_POWER, OnArcTrapPlanted )
	if ( deployable )
	{
		entity player = weapon.GetWeaponOwner()
		PlayerUsedOffhand( player, weapon )

		// arc trap mods
		if ( weapon.HasMod( "multiplayer_arc_trap" ) )
		{
			Grenade_Init( deployable, weapon )
			#if SERVER
			// enable attackable by players
			deployable.proj.onlyAllowSmartPistolDamage = false
			// not working, why?
			//thread TrapExplodeOnDamage( deployable, 50 )
			//thread TrapDestroyOnRoundEnd( deployable.GetOwner(), deployable )
			thread TrapDestroyOwnerDeath( deployable, deployable.GetOwner() )
			#endif
		}
		if ( weapon.HasMod( "gm_shock_grunt" ) ) // grunt mode shock grunts
		{
			#if SERVER
			thread TrapDestroyOwnerDeath( deployable, deployable.GetOwner() )
			#endif
		}
		//

		#if SERVER
		deployable.e.fd_roundDeployed = weapon.e.fd_roundDeployed

		string projectileSound = GetGrenadeProjectileSound( weapon )
		if ( projectileSound != "" )
			EmitSoundOnEntity( deployable, projectileSound )

		weapon.w.lastProjectileFired = deployable
		deployable.e.burnReward = weapon.e.burnReward
		#endif

		#if BATTLECHATTER_ENABLED && SERVER
			TryPlayWeaponBattleChatterLine( player, weapon )
		#endif

	}

	#if SERVER && MP // TODO: should be BURNCARDS
		if ( weapon.HasMod( "burn_card_weapon_mod" ) )
			TryUsingBurnCardWeapon( weapon, weapon.GetWeaponOwner() )
	#endif

	return ammoReq
}

void function OnWeaponTossPrep_weapon_arc_trap( entity weapon, WeaponTossPrepParams prepParams )
{
	weapon.EmitWeaponSound_1p3p( GetGrenadeDeploySound_1p( weapon ), GetGrenadeDeploySound_3p( weapon ) )
}

void function OnArcTrapPlanted( entity projectile )
{
	#if SERVER
		Assert( IsValid( projectile ) )
		vector origin = projectile.GetOrigin()

		vector endOrigin = origin - < 0.0, 0.0, 32.0 >
		vector surfaceAngles = projectile.proj.savedAngles
		vector oldUpDir = AnglesToUp( surfaceAngles )

		TraceResults traceResult = TraceLine( origin, endOrigin, [], TRACE_MASK_SOLID, TRACE_COLLISION_GROUP_NONE )
		if ( traceResult.fraction < 1.0 )
		{
			vector forward = AnglesToForward( projectile.proj.savedAngles )
			surfaceAngles = AnglesOnSurface( traceResult.surfaceNormal, forward )

			vector newUpDir = AnglesToUp( surfaceAngles )
			if ( DotProduct( newUpDir, oldUpDir ) < ARC_TRAP_ANGLE_LIMIT )
				surfaceAngles = projectile.proj.savedAngles
		}

		projectile.SetAngles( surfaceAngles )
		//thread TrapDestroyOnRoundEnd( projectile.GetOwner(), projectile )
		thread DeployArcTrap( projectile )
	#endif
}

#if SERVER

void function AddArcTrapTriggeredCallback( void functionref( entity, var ) callback )
{
	file.arcTrapTriggerCallbacks.append( callback )
}

void function DeployArcTrap( entity projectile )
{
	if ( projectile.GetOwner() == null )
	{
		projectile.Destroy()
		return
	}

	entity owner = projectile.GetOwner()
	entity mover = CreateScriptMover( projectile.GetOrigin() )

	// modified traps
	array<string> projectileMods = Vortex_GetRefiredProjectileMods( projectile )
	// limited arc trap
	if ( projectileMods.contains( "limited_arc_trap" ) )
	{
		if ( owner in file.playerOwnedArcTraps )
		{
			ArrayRemoveInvalid( file.playerOwnedArcTraps[ owner ] )
			file.playerOwnedArcTraps[ owner ].append( projectile )
			file.arcTrapActivateCount[ projectile ] <- 0

			// max limit check
			if ( file.playerOwnedArcTraps[ owner ].len() > ARC_TRAP_LIMIT )
			{
				// try to dissolve latest trap
				entity latestTrap = file.playerOwnedArcTraps[ owner ][0]
				if ( IsValid( latestTrap ) )
				{
					//latestTrap.Destroy() // just destroy it like any other deployables. dissolving will failsafe sometimes, as they can still damage targets
					latestTrap.GrenadeExplode( <0,0,1> ) // make them explode is better
				}
				file.playerOwnedArcTraps[ owner ].remove( 0 )
			}
		}
	}
	// one-use arc trap
	if ( projectileMods.contains( "one_time_arc_trap" ) )
		thread AfterTimeDestroyTrap( projectile, ARC_TRAP_LIFETIME )
	//

	entity fx
	entity idleLightFX

	int fxId = GetParticleSystemIndex( ARC_TRAP_FX )
	int startAttachID = projectile.LookupAttachment( "fx_center" )
	int StartFxId = GetParticleSystemIndex( ARC_TRAP_START_FX )
	int idleFxId = GetParticleSystemIndex( ARC_TRAP_IDLE_FX )

	entity minimapObj = CreatePropScript( $"models/dev/empty_model.mdl", projectile.GetOrigin() )
	SetTeam( minimapObj, projectile.GetTeam() )
	minimapObj.Minimap_SetCustomState( eMinimapObject_prop_script.ARC_TRAP )
	minimapObj.Minimap_AlwaysShow( minimapObj.GetTeam(), null )
	minimapObj.Minimap_SetObjectScale( 0.02 )
	minimapObj.DisableHibernation()

	//respawn why lol
	entity eyeButton = CreatePropDynamic( RODEO_BATTERY_MODEL, projectile.GetOrigin() - <0,0,10>, <0,0,0>, 2, -1 )
	eyeButton.Hide()
	eyeButton.e.burnReward = projectile.e.burnReward
	eyeButton.SetBossPlayer( owner )
	if ( BoostStoreEnabled() )
		thread BurnRewardRefundThink( eyeButton, projectile )

	// arc trap mods
	if ( projectileMods.contains( "multiplayer_arc_trap" ) )
		eyeButton.NotSolid() // so player can destroy the trap, or can't. idk why
	//

	owner.Signal( "DeployArcTrap", { projectile = projectile } )

	owner.EndSignal( "OnDestroy" )
	projectile.EndSignal( "OnDestroy" )
	mover.EndSignal( "OnDestroy" )

	EmitSoundOnEntity( projectile, "Wpn_ArcTrap_Land" )

	OnThreadEnd(
		function() : ( mover, projectile, eyeButton, minimapObj )
		{
			if ( IsValid( mover ) )
				mover.Destroy()
			if ( IsValid( eyeButton ) )
				eyeButton.Destroy()
			if ( IsValid( minimapObj ) )
				minimapObj.Destroy()
			if ( IsValid( projectile ) )
				projectile.GrenadeExplode( <0,0,1> )
		}
	)


	if ( BoostStoreEnabled() )
		eyeButton.UnsetUsable()

	// some ceremony
	StartParticleEffectOnEntity( projectile, StartFxId, FX_PATTACH_POINT_FOLLOW, startAttachID )
	idleLightFX = StartParticleEffectOnEntity_ReturnEntity( projectile, idleFxId, FX_PATTACH_POINT_FOLLOW, startAttachID )
	thread BeepSound( projectile )

	entity trig = CreateEntity( "trigger_cylinder" )
	trig.SetRadius( ARC_TRAP_RADIUS * 0.5 )
	trig.SetAboveHeight( 100 )
	trig.SetBelowHeight( 20 )
	trig.SetOrigin( projectile.GetOrigin() )
	trig.kv.triggerFilterNpc = "all"
	trig.kv.triggerFilterPlayer = "all"
	trig.kv.triggerFilterNonCharacter = "0"
	if ( projectile.GetTeam() == TEAM_IMC )
		trig.kv.triggerFilterTeamIMC = "0"
	else if ( projectile.GetTeam() == TEAM_MILITIA )
		trig.kv.triggerFilterTeamMilitia = "0"
	DispatchSpawn( trig )

	trig.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( trig )
		{

			if ( IsValid( trig ) )
				trig.Destroy()
		}
	)

	thread KillFxOnRefund( projectile, fx )

	trig.SetEnterCallback( TriggerSignal )

	while ( 1 )
	{
		if ( BoostStoreEnabled() )
		{
			if( IsValid( eyeButton ) )
			{
				eyeButton.SetUsable()
				eyeButton.SetUsableByGroup( "owner pilot" )
			}
		}

		array<entity> other

		if ( trig.GetTouchingEntities().len() == 0 )
		{
			table results = trig.WaitSignal( "OnTrigger" )

			entity activator
			if ( activator in results )
			{
				activator = expect entity( results.activator )
			}

			if ( activator != null )
			{

				other.append( activator )
			}
		}
		else
			other = trig.GetTouchingEntities()

		bool shouldTrigger = false
		foreach ( guy in other )
		{
			if ( IsAlive( guy ) && guy.GetTeam() != projectile.GetTeam() )
			{
				shouldTrigger = true
				break
			}
		}

		if ( !shouldTrigger )
		{
			WaitFrame()
			continue
		}

		StartParticleEffectOnEntity( projectile, StartFxId, FX_PATTACH_POINT_FOLLOW, startAttachID )
		fx = StartParticleEffectOnEntity_ReturnEntity( mover, fxId, FX_PATTACH_ABSORIGIN_FOLLOW, -1 )

		waitthread ActivateArcTrap( owner, mover, projectile, eyeButton, ARC_TRAP_DURATION )
		EffectStop( fx )

		if ( BoostStoreEnabled() )
			eyeButton.UnsetUsable()

		bool restartFx = true

		if ( IsValid( idleLightFX ) )
		{
			EffectStop( idleLightFX )
		}
		else
		{
			restartFx = false
		}

		wait ARC_TRAP_COOLDOWN

		if ( restartFx )
		{
			idleLightFX = StartParticleEffectOnEntity_ReturnEntity( projectile, idleFxId, FX_PATTACH_POINT_FOLLOW, startAttachID )
			thread BeepSound( projectile )
		}
	}
}

void function BeepSound( entity projectile )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.EndSignal( "BoostRefunded" )
	projectile.EndSignal( "ActivateArcTrap" )

	while( 1 )
	{
		EmitSoundOnEntity( projectile, "Wpn_ArcTrap_Beep" )
		wait 1.0
	}
}

void function KillFxOnRefund( entity projectile, entity fx )
{
	projectile.EndSignal( "OnDestroy" )
	projectile.WaitSignal( "BoostRefunded" )
	if ( IsValid( fx ) )
		EffectStop( fx )
}

void function TriggerSignal( entity trig, entity other )
{
	trig.Signal( "OnTrigger" )
}

void function ActivateArcTrap( entity owner, entity mover, entity projectile, entity eyeButton, float duration )
{
	vector up = <0,0,1>
	owner.EndSignal( "OnDestroy" )
	projectile.EndSignal( "OnDestroy" )
	mover.EndSignal( "OnDestroy" )
	projectile.Signal( "ActivateArcTrap" )

	OnThreadEnd(
		function() : ( mover )
		{
			if ( IsValid( mover ) )
				DestroyBallLightningOnEnt( mover )
		}
	)

	EmitSoundOnEntity( projectile, "Wpn_ArcTrap_Activate" )
	mover.NonPhysicsMoveTo( projectile.GetOrigin() + up*40, ARC_TRAP_RISE_DURATION, ARC_TRAP_RISE_DURATION*0.5, ARC_TRAP_RISE_DURATION*0.5 )
	wait ARC_TRAP_RISE_DURATION

	if ( IsValid( projectile.GetOwner() ) )
		Minimap_PingForPlayer( projectile.GetOwner(), projectile.GetOrigin(), ARC_TRAP_RADIUS, duration + ARC_TRAP_RISE_DURATION, TEAM_COLOR_FRIENDLY/255.0 )

	AttachBallLightning( projectile, mover )

	entity ball = GetBallLightningFromEnt( mover )
	ball.e.ballLightningData.humanRadius = ARC_TRAP_RADIUS
	ball.e.ballLightningData.radius = ARC_TRAP_RADIUS
	ball.e.ballLightningData.damageToPilots = 1;
	ball.e.ballLightningData.damage = 10;
	// ball.e.ballLightningData.zapFx = ARC_TRAP_ZAP_FX;
	wait duration // hang

	mover.NonPhysicsMoveTo( projectile.GetOrigin(), ARC_TRAP_DROP_DURATION, ARC_TRAP_DROP_DURATION*0.5, ARC_TRAP_DROP_DURATION*0.5 )
	//wait ARC_TRAP_DROP_DURATION*0.5

	// modified arc trap mods
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile )
	// limited arc trap
	if ( mods.contains( "limited_arc_trap" ) )
	{
		if ( projectile in file.arcTrapActivateCount )
		{
			file.arcTrapActivateCount[ projectile ] += 1
			// max activate count check
			if ( file.arcTrapActivateCount[ projectile ] >= ARC_TRAP_ACTIVATE_LIMIT )
				projectile.Dissolve( ENTITY_DISSOLVE_CORE, Vector( 0, 0, 0 ), 100 )
		}
	}
	// one-time arc trap
	if( mods.contains( "one_time_arc_trap" ) )
	{
		if ( IsValid( projectile ) )
			projectile.GrenadeExplode( < 0, 0, 1 > ) // explode after use
	}
}

void function ArcTrap_DamagedTarget( entity victim, var damageInfo )
{

	//Arc traps do not effect arc titans while their ability is active.
	if ( victim.GetTargetName() == "empTitan" && victim.IsTitan() )
	{
		entity soul = victim.GetTitanSoul()
		if ( IsValid( soul ) )
		{
			if ( !soul.IsDoomed() )
			{
				DamageInfo_SetDamage( damageInfo, 0 )
				return
			}
		}
	}

	//Mortar titans should be intruputed by arc traps.
	if ( victim.GetScriptName() == "mortar_titan" && victim.IsTitan() )
	{
		MortarTitanStopAttack( victim )
	}

	foreach ( callback in file.arcTrapTriggerCallbacks )
	{
		callback( victim, damageInfo )
	}

	StatusEffect_AddTimed( victim, eStatusEffect.move_slow, 0.75, 0.2, 0.1 )
	EMP_DamagedPlayerOrNPC( victim, damageInfo )

	//Force npc titans to take a knee
	if ( !victim.IsPlayer() )
	{
		if ( victim.IsTitan() && !victim.ContextAction_IsActive() && victim.IsInterruptable() )
		{
			thread ArcTrap_StaggerTitan( victim )
		}
	}
}

void function ArcTrap_StaggerTitan( entity titan )
{
	Assert ( IsNewThread(), "Must be threaded off." )
	titan.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( titan )
		{

			if ( IsValid( titan ) )
			{
				if ( titan.ContextAction_IsBusy() )
					titan.ContextAction_ClearBusy()
			}
		}
	)

	titan.ContextAction_SetBusy()
	titan.Anim_ScriptedPlayActivityByName( "ACT_FLINCH_KNOCKBACK_BACK", true, 0.1 )

	wait 2.0
}

// arc trap mods
void function OnClientConnected( entity player )
{
	file.playerOwnedArcTraps[ player ] <- []
}

void function AfterTimeDestroyTrap( entity projectile, float delay )
{
	wait delay
	if( IsValid(projectile) )
		projectile.GrenadeExplode( < 0,0,1 > )
}

void function TrapDestroyOwnerDeath( entity trap, entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	trap.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function(): ( trap )
		{
			if( IsValid( trap ) )
				trap.GrenadeExplode( < 0,0,1 > )
		}
	)

	WaitForever()
}

#endif