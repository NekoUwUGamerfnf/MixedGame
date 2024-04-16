untyped // ent.Fire() requires this

global function MpWeaponDefender_Init

global function OnWeaponPrimaryAttack_weapon_defender

global function OnWeaponChargeBegin_Defender
global function OnWeaponSustainedDischargeBegin_Defender
global function OnWeaponSustainedDischargeEnd_Defender

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_defender
#endif // #if SERVER

const float CHARGE_RIFLE_DAMAGE_COUNT = 10

// temp for us store client-side that have charge rifle mod installed
struct
{
	array<entity> chargeRifleSafePlayers
} file
//

void function MpWeaponDefender_Init()
{
	DefenderPrecache()

#if SERVER
	// temp for us get client-side that have charge rifle mod installed
	AddCallback_OnClientSideWithMixedGameInstalledConnected( OnModdedPlayerConnected )

	//AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_defender, OnApexChargeRifleDamagedTarget )
	// burnmod blacklist
	ModdedBurnMods_AddDisabledMod( "apex_charge_rifle" )
	ModdedBurnMods_AddDisabledMod( "apex_charge_rifle_burst" )
#endif
}

// temp for us get client-side that have charge rifle mod installed
#if SERVER
void function OnModdedPlayerConnected( entity player )
{
	if ( !file.chargeRifleSafePlayers.contains( player ) )
		file.chargeRifleSafePlayers.append( player )
}
#endif

void function DefenderPrecache()
{
	PrecacheParticleSystem( $"P_wpn_defender_charge_FP" )
	PrecacheParticleSystem( $"P_wpn_defender_charge" )
	PrecacheParticleSystem( $"defender_charge_CH_dlight" )

	PrecacheParticleSystem( $"wpn_muzzleflash_arc_cannon_fp" )
	PrecacheParticleSystem( $"wpn_muzzleflash_arc_cannon" )
}

var function OnWeaponPrimaryAttack_weapon_defender( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//if( weapon.HasMod( "apex_charge_rifle" ) && weapon.HasMod( "quick_charge" ) )
	//{
	//	#if SERVER
	//	FireChargeRifle( weapon, attackParams )
	//	#endif
	//	return 1
	//}
	entity owner = weapon.GetWeaponOwner()
	if( weapon.HasMod( "apex_charge_rifle" ) && owner.IsPlayer() )
		return 0

	if ( weapon.GetWeaponChargeFraction() < 1.0 )
		return 0

	return FireDefender( weapon, attackParams )
}

bool function OnWeaponChargeBegin_Defender( entity weapon )
{
	//if( weapon.HasMod( "apex_charge_rifle" ) )
	//{
	//	WeaponPrimaryAttackParams attackParams
	//	attackParams.dir = weapon.GetAttackDirection()
	//	attackParams.pos = weapon.GetAttackPosition()
	//	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	//}
	return true
}

bool function OnWeaponSustainedDischargeBegin_Defender( entity weapon )
{
	#if SERVER
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return false
	if( weapon.HasMod( "apex_charge_rifle" ) && owner.IsPlayer() )
	{

		//weapon.e.onlyDamageEntitiesOncePerTick = true

		float duration = weapon.GetWeaponSettingFloat( eWeaponVar.sustained_discharge_duration )
		//float fireDelay = 1.0 / weapon.GetWeaponSettingFloat( eWeaponVar.fire_rate ) // no need to do a long delay after fire

		thread ChargeRifleWingUpSound( weapon, duration + 0.1 ) // play charge sound 0.1s more and it will be smoother
		thread DisableOtherWeaponsForChargeRifle( weapon, owner, duration + 0.1 ) // well respawn didn't done sustained charges well
		thread ChargeRifleBeam_ServerSide( weapon, duration ) // visual fix
		//entity player = weapon.GetWeaponOwner()
		//EmitSoundOnEntityOnlyToPlayer( weapon, player, "Weapon_ChargeRifle_Fire_1P" )
		//EmitSoundOnEntityExceptToPlayer( weapon, player, "Weapon_ChargeRifle_Fire_3P" )

		//WeaponPrimaryAttackParams attackParams
		//attackParams.dir = weapon.GetAttackDirection()
		//attackParams.pos = weapon.GetAttackPosition()
		//weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	}

	#endif

	return true
}

void function OnWeaponSustainedDischargeEnd_Defender( entity weapon )
{
	weapon.Signal( "OnSustainedDischargeEnd" )
	entity owner = weapon.GetWeaponOwner()
	if( !IsValid( owner ) )
		return
	if( weapon.HasMod( "apex_charge_rifle" ) && owner.IsPlayer() )
	{
		if( !IsAlive( owner ) ) // some function below will cause crash client if owner dead( which means they're player.SetPredictionEnabled( false ) )
			return

		#if SERVER
		EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_ChargeRifle_Fire_1P" )
		EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_ChargeRifle_Fire_3P" )
		#endif
		
		if( IsAlive( owner ) ) // defensive fix
		{
			#if SERVER
				if ( owner.IsWatchingSpecReplay() || !owner.IsWatchingKillReplay() )
					return
			#elseif CLIENT
				if ( owner != GetLocalViewPlayer()  )
					return
			#endif
			// client should predict these
			WeaponPrimaryAttackParams attackParams
			attackParams.dir = weapon.GetAttackDirection()
			attackParams.pos = weapon.GetAttackPosition()

			#if SERVER // defensive fix, don't run on client
				weapon.RemoveMod( "apex_charge_rifle" )
				weapon.AddMod( "apex_charge_rifle_burst" )
			#elseif CLIENT
				if ( InPrediction() && IsFirstTimePredicted() )
				{
					weapon.RemoveMod( "apex_charge_rifle" )
					weapon.AddMod( "apex_charge_rifle_burst" )
				}
			#endif
			//owner.Weapon_StartCustomActivity( "ACT_VM_DRAW", false )
			weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
			
			#if SERVER // defensive fix, don't run on client
			weapon.RemoveMod( "apex_charge_rifle_burst" )
			weapon.AddMod( "apex_charge_rifle" )
			#endif
		}
	}

}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_defender( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireDefender( weapon, attackParams )
}
#endif // #if SERVER


int function FireDefender( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )

	return 1
}

#if SERVER
void function ChargeRifleWingUpSound( entity weapon, float duration )
{
	weapon.EndSignal( "OnDestroy" )
	entity player = weapon.GetWeaponOwner()
	if( !IsValid( player ) )
		return
	EmitSoundOnEntityOnlyToPlayer( weapon, player, "Weapon_ChargeRifle_WindUp_1P" )
	EmitSoundOnEntityExceptToPlayer( weapon, player, "Weapon_ChargeRifle_WindUp_3P" )

	wait duration
	StopSoundOnEntity( weapon, "Weapon_ChargeRifle_WindUp_1P" )
	StopSoundOnEntity( weapon, "Weapon_ChargeRifle_WindUp_3P" )
}

void function DisableOtherWeaponsForChargeRifle( entity allowedWeapon, entity owner, float duration )
{
	allowedWeapon.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )
	array<entity> disabledWeapons
	foreach( entity mainWeapon in owner.GetMainWeapons() )
	{
		if( mainWeapon != allowedWeapon )
		{
			mainWeapon.AllowUse( false )
			disabledWeapons.append( mainWeapon )
		}
	}
	owner.Server_TurnOffhandWeaponsDisabledOn()

	OnThreadEnd(
		function(): ( owner, disabledWeapons )
		{
			foreach( entity weapon in disabledWeapons )
			{
				if( IsValid( weapon ) )
					weapon.AllowUse( true )
			}
			if( IsValid( owner ) )
				owner.Server_TurnOffhandWeaponsDisabledOff()
		}
	)

	wait duration
}

void function ChargeRifleBeam_ServerSide( entity weapon, float duration )
{
	weapon.EndSignal( "OnDestroy" )
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.EndSignal( "OnDestroy" ) 
	entity destEntMover = CreateEntity( "script_mover_lightweight" )
	destEntMover.kv.SpawnAsPhysicsMover = 0
	DispatchSpawn( destEntMover )
	CreateServerSideWeaponTracer( weaponOwner, weapon, destEntMover, duration, $"P_wpn_defender_beam" )
	float startTime = Time()

	OnThreadEnd(
		function(): ( destEntMover )
		{
			if( IsValid( destEntMover ) )
				destEntMover.Destroy()
		}
	)

	while( startTime + duration >= Time() )
	{
		TraceResults result = TraceLine( weaponOwner.EyePosition(), weaponOwner.EyePosition() + weaponOwner.GetViewVector() * 3000, [weaponOwner], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		vector destPos = result.endPos
		destEntMover.SetOrigin( destPos )
		WaitFrame( true ) // bypass server framerate limit to make things more accurate
	}
}

void function CreateServerSideWeaponTracer( entity player, entity weapon, entity destEnt, float lifeTime = 5.0, asset beamEffectName = $"P_wpn_charge_tool_beam" )
{
	entity cpEnd = CreateEntity( "info_placement_helper" )
	cpEnd.SetParent( weapon, "muzzle_flash", false, 0.0 )
	SetTargetName( cpEnd, UniqueString( "arc_cannon_beam_cpEnd" ) )
	DispatchSpawn( cpEnd )

	entity tracer = CreateEntity( "info_particle_system" )
	tracer.SetOwner( player )
	tracer.kv.cpoint1 = cpEnd.GetTargetName()
	if( file.chargeRifleSafePlayers.contains( player ) ) // temp
		tracer.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY // not owner only

	tracer.SetValueForEffectNameKey( beamEffectName )

	tracer.kv.start_active = 1
	tracer.SetParent( destEnt, "REF", false, 0.0 )

	DispatchSpawn( tracer )

	player.EndSignal( "OnDeath" )
	weapon.EndSignal( "OnDestroy" )
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
}

void function FireChargeRifle( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	thread FireChargeRifle_Threaded( weapon, attackParams )
}

void function FireChargeRifle_Threaded( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	entity destEntMover = CreateEntity( "script_mover_lightweight" )
	destEntMover.kv.SpawnAsPhysicsMover = 0
	DispatchSpawn( destEntMover )
	CreateChargeRifleTracer( weaponOwner, destEntMover, 1.0, $"P_wpn_defender_beam" )
	for( int i = 0; i < CHARGE_RIFLE_DAMAGE_COUNT; i ++ )
	{
		if( !IsValid( weaponOwner ) || !IsValid( weapon ) )
			return

		TraceResults result = TraceLine( weaponOwner.EyePosition(), weaponOwner.EyePosition() + weaponOwner.GetViewVector() * 3000, [weaponOwner], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_NONE )
		vector destPos = result.endPos
		destEntMover.SetOrigin( destPos )
		//if( IsValid( result.hitEnt ) )
		WaitFrame()
	}
	destEntMover.Destroy()
	weapon.FireWeaponBullet( weaponOwner.EyePosition(), weaponOwner.EyePosition() + weaponOwner.GetViewVector() * 3000, 1, DF_GIB | DF_EXPLOSION )
}

void function CreateChargeRifleTracer( entity sourceEnt, entity destEnt, float lifeTime = 5.0, asset beamEffectName = $"P_wpn_charge_tool_beam" )
{
	entity cpEnd = CreateEntity( "info_placement_helper" )
	cpEnd.SetParent( sourceEnt, "HEADSHOT", false, 0.0 )
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
}
#endif