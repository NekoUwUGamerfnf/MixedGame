untyped // ent.Fire() requires this

global function MpWeaponDefender_Init

global function OnWeaponPrimaryAttack_weapon_defender

global function OnWeaponSustainedDischargeBegin_Defender

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_defender
#endif // #if SERVER

const float CHARGE_RIFLE_DAMAGE_COUNT = 10

void function MpWeaponDefender_Init()
{
	DefenderPrecache()
#if SERVER
	//AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_defender, OnApexChargeRifleDamagedTarget )
#endif
}

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
	if( weapon.HasMod( "apex_charge_rifle" ) && weapon.HasMod( "quick_charge" ) )
	{
		#if SERVER
		FireChargeRifle( weapon, attackParams )
		#endif
		return 1
	}

	if ( weapon.GetWeaponChargeFraction() < 1.0 )
		return 0

	return FireDefender( weapon, attackParams )
}

bool function OnWeaponSustainedDischargeBegin_Defender( entity weapon )
{
	#if SERVER
	if( weapon.HasMod( "apex_charge_rifle" ) )
	{

		//weapon.e.onlyDamageEntitiesOncePerTick = true

		entity player = weapon.GetWeaponOwner()
		EmitSoundOnEntity( weapon, "Weapon_ChargeRifle_Fire_3P" )

		WeaponPrimaryAttackParams attackParams
		attackParams.dir = weapon.GetAttackDirection()
		attackParams.pos = weapon.GetAttackPosition()
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	}

	#endif

	return true
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
		if( IsValid( result.hitEnt ) )
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