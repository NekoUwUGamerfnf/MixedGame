global function OnWeaponPrimaryAttack_ability_heal
global function OnProjectileCollision_ability_heal

global const STIM_EFFECT_SEVERITY_OCTANE = 0.25
const OCTANE_STIM_DAMAGE = 20

const JUMP_PAD_LIFETIME = 15
const REPAIR_DRONE_LIFETIME = 20

// not letting too much jump pads causes crash
const int MAX_JUMP_PAD_CONT = 64
struct JumpPadStruct
{
	entity tower
	entity projectile
}
array<JumpPadStruct> placedJumpPads
// not letting too much jump pads play sounds
global table< string, bool > playerJumpPadSoundTable

var function OnWeaponPrimaryAttack_ability_heal( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	Assert( IsValid( ownerPlayer) && ownerPlayer.IsPlayer() )
	if ( IsValid( ownerPlayer ) && ownerPlayer.IsPlayer() )
	{
		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_CLASSIC_MP_SPAWNING )
			return false

		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_INTRO )
			return false
	}

	if( weapon.HasMod( "wrecking_ball" ) )
	{
		#if SERVER
		SendHudMessage(ownerPlayer, "投出破坏球", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
		#endif
		return OnWeaponPrimaryAttack_weapon_wrecking_ball( weapon, attackParams )
	}

	bool isDeployableThrow = weapon.HasMod("jump_pad") || weapon.HasMod("repair_drone")

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	if( isDeployableThrow )
	{
		entity deployable
		if( weapon.HasMod( "jump_pad" ) )
		{
			deployable = ThrowDeployable( weapon, attackParams, DEPLOYABLE_THROW_POWER, OnJumpPadPlanted )
			#if SERVER
			SendHudMessage(ownerPlayer, "扔出跳板", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			#endif
		}
		else if( weapon.HasMod( "repair_drone" ) )
		{
			deployable = ThrowDeployable( weapon, attackParams, 100, OnRepairDroneReleased )
			#if SERVER
			SendHudMessage(ownerPlayer, "扔出维修无人机", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			#endif
		}
		
		if ( deployable )
		{
			entity player = weapon.GetWeaponOwner()

			#if SERVER
			string projectileSound = GetGrenadeProjectileSound( weapon )
			if ( projectileSound != "" )
				EmitSoundOnEntity( deployable, projectileSound )

			weapon.w.lastProjectileFired = deployable
			#endif
		}
	}
	else if( weapon.HasMod("octane_stim") )
	{
		StimPlayer( ownerPlayer, duration, STIM_EFFECT_SEVERITY_OCTANE )
		#if SERVER
		thread OctaneStimThink( ownerPlayer, duration )
		#endif
	}
	else if( weapon.HasMod( "bc_super_stim" ) && weapon.HasMod( "dev_mod_low_recharge" ) )
		StimPlayer( ownerPlayer, duration, 0.15 )
	else
		StimPlayer( ownerPlayer, duration )

	PlayerUsedOffhand( ownerPlayer, weapon )

#if SERVER
#if BATTLECHATTER_ENABLED
	TryPlayWeaponBattleChatterLine( ownerPlayer, weapon )
#endif //
#else //
	Rumble_Play( "rumble_stim_activate", {} )
#endif //

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

void function OnProjectileCollision_ability_heal( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()
	if( mods.contains( "wrecking_ball" ) )
		return OnProjectileCollision_weapon_wrecking_ball( projectile, pos, normal, hitEnt, hitbox, isCritical )
	else
		return OnProjectileCollision_weapon_deployable( projectile, pos, normal, hitEnt, hitbox, isCritical )
}

void function OnJumpPadPlanted( entity projectile )
{
	#if SERVER
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

	DeployJumpPad( projectile, origin, surfaceAngles )
	#endif
}

void function OnRepairDroneReleased( entity projectile )
{
	#if SERVER
	entity drone = SpawnRepairDrone( projectile.GetTeam(), projectile.GetOrigin(), < 0,0,0 >, projectile.GetOwner() )
	thread AfterTimeDestroyDrone( drone, projectile.GetOwner(), REPAIR_DRONE_LIFETIME )
	projectile.GrenadeExplode( < 0,0,20 > )
	#endif
}

#if SERVER
void function DeployJumpPad( entity projectile, vector origin, vector angles )
{
	#if SERVER
	int team = projectile.GetTeam()
	entity tower = CreateEntity( "prop_dynamic" )
	tower.SetModel( $"models/weapons/sentry_shield/sentry_shield_proj.mdl" )
	tower.SetOrigin( origin )
	tower.SetAngles( angles )
	tower.kv.modelscale = 4

	array<string> mods = projectile.ProjectileGetMods()
	if( mods.contains( "infinite_jump_pad" ) )
	{
		JumpPadStruct placedJumpPad
		placedJumpPad.tower = tower
		placedJumpPad.projectile = projectile
		placedJumpPads.append( placedJumpPad )
		JumpPadLimitThink()
	}

	thread JumpPadThink( tower )

	if( !mods.contains( "infinite_jump_pad" ) )
		thread CleanupJumpPad( tower, projectile, JUMP_PAD_LIFETIME )
	#endif
}

void function JumpPadThink( entity tower )
{
	tower.EndSignal( "OnDestroy" )
	entity trigger = CreateTriggerRadiusMultiple( tower.GetOrigin(), 64, [], TRIG_FLAG_PLAYERONLY | TRIG_FLAG_NO_PHASE_SHIFT, 24, 0 )
	SetTeam( trigger, tower.GetTeam() )

	AddCallback_ScriptTriggerEnter( trigger, OnJumpPadTriggerEnter )

	ScriptTriggerSetEnabled( trigger, true )

	OnThreadEnd(
		function(): ( trigger )
		{
			if( IsValid( trigger ) )
				trigger.Destroy()
		}
	)

	WaitForever()
}

void function OnJumpPadTriggerEnter( entity trigger, entity ent )
{
	thread GiveJumpPadEffect( ent )
}

void function GiveJumpPadEffect( entity player )
{
	if( player.GetParent() != null )
		return
	if( player.IsTitan() )
		return
	float zVelocity = player.GetVelocity().z
	if( zVelocity < 0 )
		zVelocity = 0
	player.SetVelocity( < player.GetVelocity().x * 1.5, player.GetVelocity().y * 1.5, zVelocity + 750 >  )
	if( !playerJumpPadSoundTable[ player.GetUID() ] )
	{
		for( int i = 0; i < 5; i++ )
			EmitSoundOnEntity( player, "Boost_Card_SentryTurret_Deployed_3P" )
	}
	thread JumpPadSoundLimit( player )
	Remote_CallFunction_Replay( player, "ServerCallback_ScreenShake", 5, 10, 0.5 )

	int attachmentIndex = player.LookupAttachment( "CHESTFOCUS" )

	if( !playerJumpPadSoundTable[ player.GetUID() ] )
	{
		entity fx = StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_titan_sniper1" ), FX_PATTACH_POINT_FOLLOW, attachmentIndex )
		fx.SetOwner( player )
		fx.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY)

		OnThreadEnd(
			function(): ( fx ){
				if( IsValid(fx) )
					EffectStop(fx)
			}
		)

		wait 1
	}
}

void function JumpPadSoundLimit( entity player )
{
	string uid = player.GetUID()
	playerJumpPadSoundTable[uid] <- true
	wait 0.1
	playerJumpPadSoundTable[uid] <- false
}

void function CleanupJumpPad( entity tower, entity projectile, float delay )
{
	wait delay
	if( IsValid(tower) )
		tower.Destroy()
	if( IsValid(projectile) )
		projectile.GrenadeExplode(< 0,0,10 >)
}

void function AfterTimeDestroyDrone( entity drone, entity owner, float delay )
{
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function() : ( drone )
		{
			if( IsValid( drone ) )
				drone.SetHealth( 0 )
		}
	)
	
	wait delay
}

void function JumpPadLimitThink()
{
	if( placedJumpPads.len() >= MAX_JUMP_PAD_CONT )
	{
		JumpPadStruct curJumpPad = placedJumpPads[0]
		if( IsValid( curJumpPad.tower ) )
			curJumpPad.tower.Destroy()
		if( IsValid( curJumpPad.projectile ) )
			curJumpPad.projectile.GrenadeExplode(< 0,0,10 >)
		placedJumpPads.remove(0)
	}
}

void function OctaneStimThink( entity player, float duration )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function(): ( player )
		{
			if( IsValid( player ) )
			{
				player.SetOneHandedWeaponUsageOff()
			}
		}
	)
	float startTime = Time()
	player.TakeDamage( player.GetHealth() - OCTANE_STIM_DAMAGE < 1 ? 1 : OCTANE_STIM_DAMAGE, player, player, { damageSourceId = eDamageSourceId.bleedout } )
	while( true )
	{
		wait 0.1
		if( IsValid( player ) )
		{
			player.p.lastDamageTime = Time()
			player.SetOneHandedWeaponUsageOn()
		}
		if( Time() >= startTime + duration )
		{
			if( IsValid( player ) )
				player.p.lastDamageTime = Time() - 5
			return
		}
	}
}
#endif
