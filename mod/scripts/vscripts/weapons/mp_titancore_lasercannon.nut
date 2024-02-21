global function LaserCannon_Init

// modified callbacks
global function OnWeaponActivate_LaserCannon
global function OnWeaponDeactivate_LaserCannon
global function OnWeaponPrimaryAttack_LaserCannon
global function OnProjectileCollision_LaserCannon
//

global function OnAbilityStart_LaserCannon
global function OnAbilityEnd_LaserCannon
global function OnAbilityCharge_LaserCannon
global function OnAbilityChargeEnd_LaserCannon

#if SERVER
global function LaserCore_OnPlayedOrNPCKilled
#endif

const SEVERITY_SLOWTURN_LASERCORE = 0.25
const SEVERITY_SLOWMOVE_LASERCORE = 0.25

const FX_LASERCANNON_AIM = $"P_wpn_lasercannon_aim"
const FX_LASERCANNON_CORE = $"P_lasercannon_core"
const FX_LASERCANNON_MUZZLEFLASH = $"P_handlaser_charge"

const LASER_MODEL = $"models/weapons/empty_handed/w_laser_cannon.mdl"

#if SP
const LASER_FIRE_SOUND_1P = "Titan_Core_Laser_FireBeam_1P_extended"
#else
const LASER_FIRE_SOUND_1P = "Titan_Core_Laser_FireBeam_1P"
#endif

// modified struct for handling npc execution
struct
{
	table<entity, bool> entUsingFakeLaserCore
} file

void function LaserCannon_Init()
{
	PrecacheParticleSystem( FX_LASERCANNON_AIM )
	PrecacheParticleSystem( FX_LASERCANNON_CORE )
	PrecacheParticleSystem( FX_LASERCANNON_MUZZLEFLASH )

	PrecacheModel( LASER_MODEL )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_laser_cannon, Laser_DamagedTarget )
		AddCallback_OnPlayerKilled( LaserCore_OnPlayedOrNPCKilled )//Move to FD game mode script
		AddCallback_OnNPCKilled( LaserCore_OnPlayedOrNPCKilled )//Move to FD game mode script
	#endif
}

#if SERVER
void function LaserCore_OnPlayedOrNPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !attacker.IsPlayer() || !attacker.IsTitan() )//|| !PlayerHasPassive( attacker, ePassives.PAS_SHIFT_CORE ) )
		return

	int damageSource = DamageInfo_GetDamageSourceIdentifier( damageInfo )
	if ( damageSource != eDamageSourceId.mp_titancore_laser_cannon )
		return

	entity soul = attacker.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	entity weapon = attacker.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	// anti-crash
	if ( !IsValid( weapon ) )
		return
	if ( !weapon.HasMod( "fd_laser_cannon" ) )
		return

	float curTime = Time()
	float laserCoreBonus
	if ( victim.IsTitan() )
		laserCoreBonus = 2.5
	else if ( IsSuperSpectre( victim ) )
		laserCoreBonus = 1.5
	else
		laserCoreBonus = 0.5

	float remainingTime = laserCoreBonus + soul.GetCoreChargeExpireTime() - curTime
	// I feel like this shouldn't be hardcoded here...
	// change to get weapon settings. may make normal laser core's core regen less powerful, but that's respawn's fault, not mine
	// now uses setting to toggle it
	bool doCoreFix = bool( GetCurrentPlaylistVarInt( "laser_core_fix", 0 ) ) || weapon.HasMod( "laser_core_fix" )
	float duration
	// modified version
	if ( doCoreFix )
		duration = weapon.GetWeaponSettingFloat( eWeaponVar.sustained_discharge_duration )
	else // vanilla behavior
	{
		if ( weapon.HasMod( "pas_ion_lasercannon") )
			duration = 5.0
		else
			duration = 3.0
	}

	float coreFrac = min( 1.0, remainingTime / duration )
	//Defensive fix for this sometimes resulting in a negative value.
	if ( coreFrac > 0.0 )
	{
		soul.SetTitanSoulNetFloat( "coreExpireFrac", coreFrac )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
		// modified here: this causes core meter to have bad display effect, don't use it
		// now updating it with TrackLaserCoreDuration()
		if ( !doCoreFix ) // vanilla behavior toggle
			weapon.SetSustainedDischargeFractionForced( coreFrac ) 
	}
}

// modified here: we needs to update laser core's charged frac so it won't have issue displaying on HUD
void function TrackLaserCoreDuration( entity titan, entity weapon )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
	
	soul.EndSignal( "OnDestroy" )
	weapon.EndSignal( "OnDestroy" )

	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "CoreEnd" )
	
	// initial wait
	//wait weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	WaitFrame()
	
	while( IsTitanCoreFiring( titan ) ) // player specific core firing check
	{
		float coreFrac = soul.GetTitanSoulNetFloat( "coreExpireFrac" )
		weapon.SetSustainedDischargeFractionForced( coreFrac )
		WaitFrame()
	}
}
#endif

// modified callbacks
void function OnWeaponActivate_LaserCannon( entity weapon )
{
	if ( weapon.HasMod( "archon_storm_core" ) )
		return OnWeaponActivate_StormCore( weapon )
}

void function OnWeaponDeactivate_LaserCannon( entity weapon )
{
	if ( weapon.HasMod( "archon_storm_core" ) )
		return OnWeaponDeactivate_StormCore( weapon )
}

var function OnWeaponPrimaryAttack_LaserCannon( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( weapon.HasMod( "archon_storm_core" ) )
		return OnWeaponPrimaryAttack_StormCore( weapon, attackParams )
	if ( weapon.HasMod( "tesla_core" ) )
		return OnAbilityStart_Tesla_Core( weapon, attackParams )
}

void function OnProjectileCollision_LaserCannon( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile )
	if ( mods.contains( "archon_storm_core" ) )
		return OnProjectileCollision_StormCore( projectile, pos, normal, hitEnt, hitbox, isCritical )
}
//

bool function OnAbilityCharge_LaserCannon( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "archon_storm_core" ) )
		return OnAbilityCharge_StormCore( weapon )
	if ( weapon.HasMod( "tesla_core" ) )
		return OnCoreCharge_Tesla_Core( weapon )
	//

	// vanilla behavior
	OnAbilityCharge_TitanCore( weapon )

#if CLIENT
	if ( !InPrediction() || IsFirstTimePredicted() )
	{
		weapon.PlayWeaponEffectNoCull( FX_LASERCANNON_AIM, FX_LASERCANNON_AIM, "muzzle_flash" )
		weapon.PlayWeaponEffectNoCull( FX_LASERCANNON_AIM, FX_LASERCANNON_AIM, "laser_canon_1" )
		weapon.PlayWeaponEffectNoCull( FX_LASERCANNON_AIM, FX_LASERCANNON_AIM, "laser_canon_2" )
		weapon.PlayWeaponEffectNoCull( FX_LASERCANNON_AIM, FX_LASERCANNON_AIM, "laser_canon_3" )
		weapon.PlayWeaponEffectNoCull( FX_LASERCANNON_AIM, FX_LASERCANNON_AIM, "laser_canon_4" )
		weapon.PlayWeaponEffect( FX_LASERCANNON_MUZZLEFLASH, FX_LASERCANNON_MUZZLEFLASH, "muzzle_flash" )
	}
#endif // #if CLIENT

#if SERVER
	entity player = weapon.GetWeaponOwner()
	float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
	entity soul = player.GetTitanSoul()
	if ( soul == null )
		soul = player

	StatusEffect_AddTimed( soul, eStatusEffect.move_slow, SEVERITY_SLOWMOVE_LASERCORE, chargeTime, 0 )

	weapon.w.laserWorldModel = CreatePropDynamic( LASER_MODEL )

	int index = player.LookupAttachment( "PROPGUN" )
	vector origin = player.GetAttachmentOrigin( index )
	vector angles = player.GetAttachmentAngles( index )

	if ( player.IsPlayer() )
		player.Server_TurnOffhandWeaponsDisabledOn()

	weapon.w.laserWorldModel.SetOrigin( origin )
	weapon.w.laserWorldModel.SetAngles( angles - Vector(90,0,0)  )

	// modified checks for non-atlas chassis using laser core
	if ( !TitanShouldPlayAnimationForLaserCore( player ) )
		weapon.w.laserWorldModel.SetParent( player, "CHESTFOCUS", true, 0.0 )
	else // vanilla behavior
		weapon.w.laserWorldModel.SetParent( player, "PROPGUN", true, 0.0 )
	PlayFXOnEntity( FX_LASERCANNON_AIM, weapon.w.laserWorldModel, "muzzle_flash", null, null, 6, player )
	PlayFXOnEntity( FX_LASERCANNON_AIM, weapon.w.laserWorldModel, "laser_canon_1", null, null, 6, player )
	PlayFXOnEntity( FX_LASERCANNON_AIM, weapon.w.laserWorldModel, "laser_canon_2", null, null, 6, player )
	PlayFXOnEntity( FX_LASERCANNON_AIM, weapon.w.laserWorldModel, "laser_canon_3", null, null, 6, player )
	PlayFXOnEntity( FX_LASERCANNON_AIM, weapon.w.laserWorldModel, "laser_canon_4", null, null, 6, player )

	weapon.w.laserWorldModel.Anim_Play( "charge_seq" )

	// check for npc executions to work!
	// don't want it intterupt execution animations
	//PrintFunc()
	//print( "player.Anim_IsActive(): " + string( player.Anim_IsActive() ) )
	//if ( player.IsNPC() )
	if ( player.IsNPC() && !player.Anim_IsActive() )
	{
		player.SetVelocity( <0,0,0> )
		
		// modified checks for animations, anti-crash
		if ( TitanShouldPlayAnimationForLaserCore( player ) )
		{
			player.Anim_ScriptedPlayActivityByName( "ACT_SPECIAL_ATTACK_START", true, 0.0 )
			// vanilla missing: needs these to make them unable to be set into other scripted animations( eg. being executed )
			// alright... shouldn't mark context action state for them, will make them stop finding new enemies
			// just handle in extra_ai_spawner.gnut
			//if ( !player.ContextAction_IsBusy() )
			//	player.ContextAction_SetBusy()
		}
		else // other titans using it, could be bad... try to stop their movement for the duration of core
		{
			//print( "non-atlas chassis titan using laser core..." )
			float coreChargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
			float coreDuration = weapon.GetWeaponSettingFloat( eWeaponVar.sustained_discharge_duration )
			// welp it's kinda funny but... 1.0 move_slow severity for npc will crash the game
			// they'll move like weirdly some animation, and the game just boom
			//StatusEffect_AddTimed( soul, eStatusEffect.move_slow, 1.0, coreDuration + coreChargeTime, coreChargeTime )
			StatusEffect_AddTimed( soul, eStatusEffect.move_slow, 0.6, coreDuration + coreChargeTime, coreChargeTime )
			StatusEffect_AddTimed( soul, eStatusEffect.dodge_speed_slow, 0.6, coreDuration + coreChargeTime, coreChargeTime )
		}
	}
#endif // #if SERVER

	weapon.EmitWeaponSound_1p3p( "Titan_Core_Laser_ChargeUp_1P", "Titan_Core_Laser_ChargeUp_3P" )

	return true
}

void function OnAbilityChargeEnd_LaserCannon( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "archon_storm_core" ) )
		return OnAbilityChargeEnd_StormCore( weapon )
	if ( weapon.HasMod( "tesla_core" ) )
		return OnCoreChargeEnd_Tesla_Core( weapon )
	//

	// vanilla behavior
	#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )
	#endif

	#if CLIENT
	if ( IsFirstTimePredicted() )
	{
		weapon.StopWeaponEffect( FX_LASERCANNON_AIM, FX_LASERCANNON_AIM )
	}
	#endif

	#if SERVER
	if ( IsValid( weapon.w.laserWorldModel ) )
		weapon.w.laserWorldModel.Destroy()

	entity player = weapon.GetWeaponOwner()

	if ( player == null )
		return

	if ( player.IsPlayer() )
		player.Server_TurnOffhandWeaponsDisabledOff()

	// check for npc executions to work!
	// don't want it intterupt execution animations
	//PrintFunc()
	//print( "IsTitanCoreFiring( player ): " + string( IsTitanCoreFiring( player ) ) )
	//print( "player.Anim_IsActive(): " + string( player.Anim_IsActive() ) )
	if ( player.IsNPC() && IsAlive( player ) && ( IsTitanCoreFiring( player ) || !player.Anim_IsActive() ) )
		player.Anim_Stop()
	#endif
}

bool function OnAbilityStart_LaserCannon( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "archon_storm_core" ) ) // storm core don't have a sustained laser
		return true
	if ( weapon.HasMod( "tesla_core" ) ) // tesla core don't have a sustained laser
		return true
	//

	// modded check
	entity player = weapon.GetWeaponOwner()
	// if owner npc is playing animation, we only run function if npc can use fake laser core
#if SERVER
	if ( player.IsNPC() && player.Anim_IsActive() )
	{
		if ( !NPCInValidFakeLaserCoreState( player ) )
			return true
	}
#endif

	// vanilla behavior
	OnAbilityStart_TitanCore( weapon )

#if SERVER
	weapon.e.onlyDamageEntitiesOncePerTick = true

	// moved up
	//entity player = weapon.GetWeaponOwner()
	float stunDuration = weapon.GetSustainedDischargeDuration()
	float fadetime = 2.0
	entity soul = player.GetTitanSoul()
	if ( soul == null )
		soul = player

	if ( !player.ContextAction_IsMeleeExecution() ) //don't do this during executions
	{
		StatusEffect_AddTimed( soul, eStatusEffect.turn_slow, SEVERITY_SLOWTURN_LASERCORE, stunDuration + fadetime, fadetime )
		StatusEffect_AddTimed( soul, eStatusEffect.move_slow, SEVERITY_SLOWMOVE_LASERCORE, stunDuration + fadetime, fadetime )
	}

	if ( player.IsPlayer() )
	{
		player.Server_TurnDodgeDisabledOn()
		player.Server_TurnOffhandWeaponsDisabledOn()
		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Core_Laser_FireStart_1P" )
		EmitSoundOnEntityOnlyToPlayer( player, player, LASER_FIRE_SOUND_1P )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Core_Laser_FireStart_3P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Core_Laser_FireBeam_3P" )
		// modified here: we needs to update laser core's charged frac so it won't have issue displaying on HUD
		bool doCoreFix = bool( GetCurrentPlaylistVarInt( "laser_core_fix", 0 ) ) || weapon.HasMod( "laser_core_fix" )
		if ( doCoreFix )
			thread TrackLaserCoreDuration( player, weapon )
	}
	else
	{
		EmitSoundOnEntity( player, "Titan_Core_Laser_FireStart_3P" )
		EmitSoundOnEntity( player, "Titan_Core_Laser_FireBeam_3P" )
	}
	
	if ( player.IsNPC() )
	{
		// check for npc executions to work!
		// don't want it intterupt execution animations
		//PrintFunc()
		//print( "player.ContextAction_IsMeleeExecution(): " + string( player.ContextAction_IsMeleeExecution() ) )
		//print( "player.Anim_IsActive(): " + string( player.Anim_IsActive() ) )
		//print( "IsValid( player.GetParent() ): " + string( IsValid( player.GetParent() ) ) )
		// player.ContextAction_IsMeleeExecution() can't get a npc's state
		// modded behavior
		if ( player.Anim_IsActive() )
		{
			// they can't aim laser core if use during execution, do some fake effect
			thread FakeExecutionLaserCannonThink( player, weapon )
		}
		else // vanilla behavior
		{
			player.SetVelocity( <0,0,0> )
			// modified checks for animations, anti-crash
			if ( TitanShouldPlayAnimationForLaserCore( player ) )
				player.Anim_ScriptedPlayActivityByName( "ACT_SPECIAL_ATTACK", true, 0.1 )
		}
	}

	// thread LaserEndingWarningSound( weapon, player )

	SetCoreEffect( player, CreateCoreEffect, FX_LASERCANNON_CORE )
#endif

	#if CLIENT
	thread PROTO_SustainedDischargeShake( weapon )
	#endif

	return true
}

// modified: fake lasercore think
// npcs can't aim laser core if use during execution, do some fake effect
#if SERVER
void function FakeExecutionLaserCannonThink( entity owner, entity weapon )
{
	// general check
	if ( !NPCInValidFakeLaserCoreState( owner ) )
		return

	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnSustainedDischargeEnd" )
	weapon.EndSignal( "OnDestroy" )

	// adding this mark so we don't stop animation and sound in OnAbilityEnd_LaserCannon()
	// all handle in this function
	file.entUsingFakeLaserCore[ owner ] <- true

	// scripted entity handle
	array<entity> laserCoreScriptedEffects
	array<entity> laserCoreScriptedEntities

	// tracer don't really work, but with impact effect it already looks not bad
	//entity laserSource //CreatePropDynamic( LASER_MODEL )
	//laserSource.SetParent( owner, "CHESTFOCUS", true, 0.0 )
	//laserSource.SetAngles( < 0, 180, 0 > )
	//laserCoreScriptedEntities.append( laserSource )

	//entity laserTracer //= PlayFXOnEntity( $"P_wpn_lasercannon", laserSource, "muzzle_flash", null, null, 6 )
	//laserCoreScriptedEffects.append( laserTracer )

	// fake impact sound
	entity laserImpactSoundEnt = CreatePropScript( $"models/dev/empty_model.mdl" )
	laserImpactSoundEnt.NotSolid()
	laserImpactSoundEnt.kv.fadedist = 10000 // try not to fade
	laserImpactSoundEnt.DisableHibernation()
	laserCoreScriptedEntities.append( laserImpactSoundEnt )

	table<string, entity> entCleanUpTable
	// all reworked
	//entCleanUpTable[ "executionParent" ] <- null
	//entCleanUpTable[ "laserGlowEffect" ] <- null

	OnThreadEnd
	(
		function(): ( owner, entCleanUpTable, laserCoreScriptedEffects, laserCoreScriptedEntities )
		{
			//print( "FakeExecutionLaserCannonThink() OnThreadEnd!" )
			// now handled by laserCoreScriptedEffects
			/*
			entity laserGlowEffect = entCleanUpTable[ "laserGlowEffect" ]
			if ( IsValid( laserGlowEffect ) )
				EffectStop( laserGlowEffect )
			*/

			if ( IsValid( owner ) )
			{
				// fix sound
				EmitSoundOnEntity( owner, "Titan_Core_Laser_FireStop_3P" )
				StopSoundOnEntity( owner, "Titan_Core_Laser_FireBeam_3P" )
				delete file.entUsingFakeLaserCore[ owner ]
			}
			// now handled by laserImpactSoundEnt
			/*
			entity executionParent = entCleanUpTable[ "executionParent" ]
			if ( IsValid( executionParent ) )
			{
				StopSoundOnEntity( executionParent, "Default.LaserLoop.BulletImpact_3P_VS_3P" )
			}
			*/

			foreach ( entity fx in laserCoreScriptedEffects )
			{
				if ( IsValid( fx ) )
					EffectStop( fx )
			}

			foreach ( entity ent in laserCoreScriptedEntities )
			{
				if ( IsValid( ent ) )
					ent.Destroy()
			}
		}
	)

	float lifeTime = weapon.GetSustainedDischargeDuration()
	float endTime = Time() + lifeTime
	bool emittedSound = false
	entity laserGlowEffect
	while ( Time() < endTime && owner.Anim_IsActive() )
	{
		// stop weapon firing
		ForceTitanSustainedDischargeEnd( owner )

		// fake impact sound event, play on target
		// updated: play on laserImpactSoundEnt that moves with laser trace
		/*
		entity executionParent = owner.GetParent()
		if ( IsValid( executionParent ) )
		{
			if ( !emittedSound )
			{
				EmitSoundOnEntity( executionParent, "Default.LaserLoop.BulletImpact_3P_VS_3P" )
				entCleanUpTable[ "executionParent" ] = executionParent
				emittedSound = true
			}
		}
		*/

		int index = owner.LookupAttachment( "CHESTFOCUS" )
		vector origin = owner.GetAttachmentOrigin( index )
		vector angles = owner.GetAttachmentAngles( index )

		array<entity> ignoreEnts = [ owner ]
		ignoreEnts.extend( laserCoreScriptedEntities )
		ArrayRemoveInvalid( ignoreEnts )

		TraceResults results = TraceLine( 
			owner.EyePosition(), 
			owner.EyePosition() + AnglesToForward( angles ) * 6000, // equal to "sustained_laser_range"
			ignoreEnts, 
			TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE 
		)

		// fake impact effect
		// "laser_core" impact effect isn't good, it will emit a looping impact sound...
		entity hitEnt = results.hitEnt
		if ( IsValid( hitEnt ) && !results.hitSky )
		{
			// move impact sound ent
			laserImpactSoundEnt.SetOrigin( results.endPos )
			if ( !emittedSound )
			{
				EmitSoundOnEntity( laserImpactSoundEnt, "Default.LaserLoop.BulletImpact_3P_VS_3P" )
				emittedSound = true
			}

			vector fxPos = results.endPos// - results.surfaceNormal // no need to minus normal since we're not using impactFXTable
			//PlayImpactFXTable( , owner, "laser_core", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
			// manually do effects
			PlayFX( $"P_impact_lasercannon_default", fxPos )
			// effects that only played when we hit target
			// reverted. always do effect because I can't code fake sustained laser radius check
			// and there's no need we play a new effect each time
			/*
			if ( IsValid( executionParent ) && hitEnt == executionParent )
			{
				if ( IsValid( laserGlowEffect ) )
				{
					EffectStop( laserGlowEffect )
					laserGlowEffect = null
				}
				laserGlowEffect = PlayFX( $"P_lasercannon_endglow", fxPos )
				//entCleanUpTable[ "laserGlowEffect" ] = laserGlowEffect
				ArrayRemoveInvalid( laserCoreScriptedEffects )
				laserCoreScriptedEffects.append( laserGlowEffect )
			}
			*/
			if ( !IsValid( laserGlowEffect ) )
			{
				laserGlowEffect = PlayFX( $"P_lasercannon_endglow", fxPos )
				laserGlowEffect.SetStopType( "DestroyImmediately" )
			}
			laserGlowEffect.SetOrigin( fxPos )
			ArrayRemoveInvalid( laserCoreScriptedEffects )
			laserCoreScriptedEffects.append( laserGlowEffect )
		}
		else // can't hit anything or hit sky
		{
			// stop impact sound and effect
			if ( emittedSound )
			{
				StopSoundOnEntity( laserImpactSoundEnt, "Default.LaserLoop.BulletImpact_3P_VS_3P" )
				emittedSound = false
			}
			if ( IsValid( laserGlowEffect ) )
			{
				EffectStop( laserGlowEffect )
				laserGlowEffect = null
			}
		}

		WaitFrame()
	}
}

bool function NPCInValidFakeLaserCoreState( entity npc, bool skipUsageCheck = false )
{
	if ( !skipUsageCheck )
	{
		if ( npc in file.entUsingFakeLaserCore ) // don't run this instance multiple times
			return false
	}
	
	// HACK: npc sometimes call OnAbilityStart_LaserCannon() right after animation starts
	// don't want that weird behavior to happen, use timer for handling
	// { event AE_OFFHAND_BEGIN 118 "mp_titancore_laser_cannon" }( fps 30 )
	const float animEventTime = ( 118.0 / 30.0 ) - 0.5 // minus 0.5s to avoid we get bad float value

	// function from modified _melee_synced_titan.gnut
	if ( MeleeSyncedTitan_GetTitanExecutionStartTime( npc ) == -1 ) // invalid timer!
		return false
	float executionProcessTime = Time() - MeleeSyncedTitan_GetTitanExecutionStartTime( npc )
	if ( executionProcessTime < animEventTime )
		return false

	// all checks passed
	return true
}
#endif

void function OnAbilityEnd_LaserCannon( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "archon_storm_core" ) ) // storm core don't have a sustained laser
		return
	if ( weapon.HasMod( "tesla_core" ) ) // tesla core don't have a sustained laser
		return
	//

	// vanilla behavior
	weapon.Signal( "OnSustainedDischargeEnd" )
	weapon.StopWeaponEffect( FX_LASERCANNON_MUZZLEFLASH, FX_LASERCANNON_MUZZLEFLASH )

	#if SERVER
	OnAbilityEnd_TitanCore( weapon )

	entity player = weapon.GetWeaponOwner()

	if ( player == null )
		return

	if ( player.IsPlayer() )
	{
		player.Server_TurnDodgeDisabledOff()
		player.Server_TurnOffhandWeaponsDisabledOff()

		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Core_Laser_FireStop_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Core_Laser_FireStop_3P" )
	}
	else
	{
		// modified for handling npc laser core animation
		if ( !( player in file.entUsingFakeLaserCore ) )
			EmitSoundOnEntity( player, "Titan_Core_Laser_FireStop_3P" )
	}

	// modified for handling npc laser core animation
	if ( !( player in file.entUsingFakeLaserCore ) )
	{
		// vanilla check
		if ( player.IsNPC() && IsAlive( player ) )
		{
			player.SetVelocity( <0,0,0> )

			// modified checks for animations, anti-crash
			if ( TitanShouldPlayAnimationForLaserCore( player ) )
			{
				player.Anim_ScriptedPlayActivityByName( "ACT_SPECIAL_ATTACK_END", true, 0.0 )
				// vanilla missing: clean up context action state we set in OnAbilityCharge_LaserCannon()
				// alright... shouldn't mark context action state for them, will make them stop finding new enemies
				// just handle in extra_ai_spawner.gnut
				//if ( player.ContextAction_IsBusy() )
				//	thread ClearContextActionStateAfterCoreAnimation( player )
			}
		}
	}

	// modified for handling npc laser core animation
	if ( !( player in file.entUsingFakeLaserCore ) )
	{
		StopSoundOnEntity( player, "Titan_Core_Laser_FireBeam_3P" )
		StopSoundOnEntity( player, LASER_FIRE_SOUND_1P )
	}

	//print( "OnAbilityEnd_LaserCannon run to end!" )
	#endif
}

// modified functions
#if SERVER
// wants to limit animations to atlas-chassis only, in case we want to use it for other titans
bool function TitanShouldPlayAnimationForLaserCore( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( IsValid( soul ) )
	{
		string titanType = GetSoulTitanSubClass( soul )
		if ( titanType == "atlas" )
			return true
	}

	return false
}

void function ClearContextActionStateAfterCoreAnimation( entity npc )
{
	npc.EndSignal( "OnDestroy" )

	WaittillAnimDone( npc )
	if ( npc.ContextAction_IsBusy() )
	{
		npc.ContextAction_ClearBusy()
		//print( "Cleaning up context action state for npc firing laser core" )
	}
}
#endif

#if SERVER
void function LaserEndingWarningSound( entity weapon, entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnSyncedMelee" )
	player.EndSignal( "CoreEnd" )
	player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "TitanEjectionStarted" )

	float duration = weapon.GetSustainedDischargeDuration()

//	Assert( duration > 2.0, "Titan_Core_Laser_Fire_EndWarning_1P needs to be played 2.0 seconds before. Ask audio to adjust the sound and change the values in this function" )
//	wait duration - 2.0

//	EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Core_Laser_Fire_EndWarning_1P")
}

void function Laser_DamagedTarget( entity target, var damageInfo )
{
	if ( IsAlive( target ) )
		Laser_DamagedTargetInternal( target, damageInfo )
}

void function Laser_DamagedTargetInternal( entity target, var damageInfo )
{
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	// HACK fix here: if our npc is using fake laser core
	// they still fire from their back for about 1 tick, which shouldn't deal any damage
	if ( IsValid( attacker ) && attacker.IsNPC() && NPCInValidFakeLaserCoreState( attacker, true ) )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
	//

	if ( IsValid( weapon ) )
	{
		float damage = min( DamageInfo_GetDamage( damageInfo ), weapon.GetWeaponSettingInt( eWeaponVar.damage_near_value_titanarmor ) )
		DamageInfo_SetDamage( damageInfo, damage )
	}

	if ( target.GetTargetName() == "#NPC_EVAC_DROPSHIP" )
		DamageInfo_ScaleDamage( damageInfo, EVAC_SHIP_DAMAGE_MULTIPLIER_AGAINST_NUCLEAR_CORE )

	#if SP
	if ( target.IsNPC() && ( IsMercTitan( target ) || target.ai.bossTitanType == TITAN_BOSS ) )
	{
		DamageInfo_ScaleDamage( damageInfo, BOSS_TITAN_CORE_DAMAGE_SCALER )
	}
	#endif
}
#endif