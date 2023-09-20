untyped

global function MpTitanWeaponStormCore_Init

global function FireStormBall
// originally in sh_archon_util, move here
#if SERVER
global function DamageShieldsInRadiusOnEntity
#endif

global function OnWeaponActivate_StormCore
global function OnAbilityCharge_StormCore
global function OnAbilityChargeEnd_StormCore
global function OnWeaponPrimaryAttack_StormCore
global function OnProjectileCollision_StormCore

const FX_EMP_FIELD				= $"P_xo_emp_field"
const FX_EMP_GLOW             	= $"P_titan_core_atlas_charge"

struct {
	table<entity, float> sonarExpiryTimes
} file

void function MpTitanWeaponStormCore_Init()
{
	PrecacheParticleSystem( FX_EMP_FIELD )
	PrecacheParticleSystem( FX_EMP_GLOW )

	#if SERVER
		// adding a new damageSourceId. it's gonna transfer to client automatically
	    RegisterWeaponDamageSource( "mp_titancore_storm_core", "Storm Core" )

		AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_storm_core, StormCore_DamagedTarget )
		//prevent player earning coremeter by storm core 
		GameModeRulesRegisterTimerCreditException( eDamageSourceId.mp_titancore_storm_core )
	#endif
}

void function OnWeaponActivate_StormCore( entity weapon )
{
	// could be better to use flamewave stuffs
	//weapon.EmitWeaponSound_1p3p( "bt_hotdrop_turbo", "bt_hotdrop_turbo_upgraded" )
	weapon.EmitWeaponSound_1p3p( "flamewave_start_1p", "flamewave_start_3p" )
	OnAbilityCharge_TitanCore( weapon )
}

bool function OnAbilityCharge_StormCore( entity weapon )
{
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		float chargeTime = weapon.GetWeaponSettingFloat( eWeaponVar.charge_time )
		entity soul = owner.GetTitanSoul()
		if ( soul == null )
			soul = owner
		StatusEffect_AddTimed( owner, eStatusEffect.move_slow, 0.6, chargeTime, 0 )
		StatusEffect_AddTimed( owner, eStatusEffect.dodge_speed_slow, 0.6, chargeTime, 0 )
		StatusEffect_AddTimed( owner, eStatusEffect.emp, 0.05, chargeTime*1.5, 0.35 )
		StatusEffect_AddTimed( soul, eStatusEffect.damageAmpFXOnly, 1.0, chargeTime, 0 )

		if ( owner.IsPlayer() )
			owner.SetTitanDisembarkEnabled( false )
		else
			owner.Anim_ScriptedPlay( "at_antirodeo_anim_fast" )
	#endif

	return true
}

void function OnAbilityChargeEnd_StormCore( entity weapon )
{
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		OnAbilityChargeEnd_TitanCore( weapon )

		if ( !IsValid( owner ) )
			return

		if ( owner.IsPlayer() )
			owner.SetTitanDisembarkEnabled( true )

		if ( owner.IsPlayer() )
			owner.Server_TurnOffhandWeaponsDisabledOff()

		if ( owner.IsNPC() && IsAlive( owner ) )
		{
			owner.Anim_Stop()
		}

		// shared from special_3p_attack_anim_fix.gnut
		// fix atlas chassis animation
		HandleSpecial3pAttackAnim( owner, weapon, 1.0, OnWeaponPrimaryAttack_StormCore, true )

	#endif // #if SERVER
}

var function OnWeaponPrimaryAttack_StormCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnAbilityStart_TitanCore( weapon )

	/* // we've modified firing duration, no need to do shake
	#if CLIENT
    	ClientScreenShake( 4.0, 5.0, 5.0, Vector( 0.0, 0.0, 0.0 ) )
  	#endif
	*/

	#if SERVER
		OnAbilityEnd_TitanCore( weapon )
	#endif
	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	#if SERVER
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )

		entity owner = weapon.GetWeaponOwner()
		if ( owner.IsNPC() )
		{
			vector attackAngles = VectorToAngles( attackParams.dir )
			attackAngles.x = -20 // move up attack angle a little bit for npcs
			attackAngles.z = 0
			attackParams.dir = AnglesToForward( attackAngles )
		}

      	FireStormBall( weapon, attackParams.pos, attackParams.dir, shouldPredict)
	#elseif CLIENT
		ClientScreenShake( 8.0, 10.0, 1.0, Vector( 0.0, 0.0, 0.0 ) )
	#endif

	return 1
}

// changed from archon's void return type
entity function FireStormBall( entity weapon, vector pos, vector dir, bool shouldPredict, float damage = BALL_LIGHTNING_DAMAGE )
{
	entity owner = weapon.GetWeaponOwner()

	float speed = 1000.0

	if ( owner.IsPlayer() )
	{
		vector myVelocity = owner.GetVelocity()

		float mySpeed = Length( myVelocity )

		myVelocity = Normalize( myVelocity )

		float dotProduct = DotProduct( myVelocity, dir )

		dotProduct = max( 0, dotProduct )

		mySpeed = mySpeed*0.30

		speed = speed + ( mySpeed*dotProduct )
	}

	int team = TEAM_UNASSIGNED
	if ( IsValid( owner ) )
		team = owner.GetTeam()

	int flags = DF_EXPLOSION | DF_STOPS_TITAN_REGEN | DF_DOOM_FATALITY | DF_SKIP_DAMAGE_PROT

	entity bolt = weapon.FireWeaponBolt( pos, dir, speed, damageTypes.arcCannon | DF_ELECTRICAL, damageTypes.arcCannon | DF_EXPLOSION, shouldPredict, 0 )

	if ( bolt != null )
	{
		bolt.kv.rendercolor = "0 0 0"
		bolt.kv.renderamt = 0
		bolt.kv.fadedist = 1
		bolt.kv.gravity = 0.75
		SetTeam( bolt, team )

		float lifetime = 25.0

		bolt.SetProjectileLifetime( lifetime )


		#if SERVER
			if ( IsValid( bolt ) )
			{
				PlayFXOnEntity( FX_EMP_FIELD, bolt, "", <0, 0, -21.0> )
				PlayFXOnEntity( FX_EMP_FIELD, bolt, "", <0, 0, -20.0> )
				PlayFXOnEntity( FX_EMP_FIELD, bolt, "", <0, 0, -22.0> )
				PlayFXOnEntity( FX_EMP_GLOW, bolt)
				EmitSoundOnEntity( bolt, "EMP_Titan_Electrical_Field" )
				EmitSoundOnEntity( bolt, "Wpn_LaserTripMine_LaserLoop" )


				vector origin = owner.OffsetPositionFromView( <0, 0, 0>, <25, -25, 15> )
				#if SERVER
					//AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_storm_core, StormCore_DamagedTarget )
					bolt.ProjectileSetDamageSourceID( eDamageSourceId.mp_titancore_storm_core )
				#endif

				thread UpdateStormCoreField( owner, bolt, weapon, origin, lifetime )

				if ( weapon.HasMod( "bring_the_thunder" ) )
				{
					thread UpdateStormCoreSmoke( owner, bolt, weapon, origin, lifetime )
				}
			}
		#endif

		// fix for trail effect, so clients without scripts installed can see the trail
		StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"P_wpn_arcball_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	}

	return bolt
}

void function OnProjectileCollision_StormCore( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// archon only has collision behavior for aegis upgrades
	#if SERVER
	
	#endif
}


#if SERVER
void function UpdateStormCoreField( entity owner, entity bolt, entity weapon, vector origin, float lifetime )
{
    bolt.EndSignal( "OnDestroy" )
    float endTime = Time() + lifetime

	while ( Time() < endTime )
	{
		WaitFrame()
		origin = bolt.GetOrigin()
		StormCoreFieldDamage( weapon, bolt, origin )
	}

}

void function UpdateStormCoreSmoke( entity owner, entity bolt, entity weapon, vector origin, float lifetime )
{
    bolt.EndSignal( "OnDestroy" )
    float endTime = Time() + lifetime

	while ( Time() < endTime )
	{
		wait 0.1
		origin = bolt.GetOrigin()
		StormCoreSmokescreen( bolt, FX_ELECTRIC_SMOKESCREEN, owner )
		wait 0.15
	}
}

function StormCoreFieldDamage( entity weapon, entity bolt, vector origin )
{

	int flags = DF_EXPLOSION | DF_STOPS_TITAN_REGEN | DF_DOOM_FATALITY | DF_SKIP_DAMAGE_PROT

	// sonar things
	if ( !IsValid( weapon ) ) // i guess if you die you dont get more sonar, too bad!
		return
	if ( weapon.HasMod( "bring_the_thunder" ) )
	{
		// construct array of sonar-able things
		array<entity> enemiesToSonar = GetPlayerArrayEx( "any", TEAM_ANY, weapon.GetOwner().GetTeam(), origin, ARC_TITAN_EMP_FIELD_RADIUS )
		enemiesToSonar.extend( GetNPCArrayEx( "any", TEAM_ANY, weapon.GetOwner().GetTeam(), origin, ARC_TITAN_EMP_FIELD_RADIUS ) )

		foreach ( entity enemy in enemiesToSonar )
		{
			if ( enemy.GetTeam() == weapon.GetOwner().GetTeam() )
				continue

			// nothing is blocking LOS
			if ( TraceLineSimple(origin, enemy.GetCenter(), enemy) == 1.0 )
			{
				float oldExpiryTime = 0
				if ( enemy in file.sonarExpiryTimes )
					oldExpiryTime = file.sonarExpiryTimes[enemy]
				file.sonarExpiryTimes[enemy] <- Time() + 5.0 // this 5.0 is how long the sonar should stay
				if ( Time() > oldExpiryTime )
					thread StormCoreSonar_Think( enemy, weapon.GetOwner().GetTeam(), weapon.GetOwner(), origin )

			}
		}
	}

	// damage shields first and then other things
	DamageShieldsInRadiusOnEntity( weapon, bolt, ARC_TITAN_EMP_FIELD_RADIUS, 450 * 8 ) // damageheavyArmor * 8
	RadiusDamage(
		origin,									// center
		weapon.GetWeaponOwner(),									// attacker
		bolt,									// inflictor
		90,					// damage
		700,					// damageHeavyArmor
		ARC_TITAN_EMP_FIELD_INNER_RADIUS,		// innerRadius
		ARC_TITAN_EMP_FIELD_RADIUS,				// outerRadius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER,			// flags
		0,										// distanceFromAttacker
		0,					                    // explosionForce
		flags,	// scriptDamageFlags
		eDamageSourceId.mp_titancore_storm_core )			// scriptDamageSourceIdentifier
}

void function StormCoreSonar_Think( entity ent, int sonarTeam, entity owner, vector origin )
{
	SonarStart( ent, origin, sonarTeam, owner )
	IncrementSonarPerTeam( sonarTeam )

	while ( Time() < file.sonarExpiryTimes[ent] )
	{
		wait file.sonarExpiryTimes[ent] - Time()
	}

	DecrementSonarPerTeam( sonarTeam )
	SonarEnd( ent, sonarTeam )
}

void function StormCore_DamagedTarget( entity target, var damageInfo )
{
    entity attacker = DamageInfo_GetAttacker( damageInfo )

    if ( attacker == target )
    {
        DamageInfo_SetDamage( damageInfo, 0 )
    }

		if ( DamageInfo_GetDamage( damageInfo ) <= 0 )
			return

		const ARC_TITAN_EMP_DURATION			= 0.35
		const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35

		StatusEffect_AddTimed( target, eStatusEffect.emp, 1.0, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )
}

void function StormCoreSmokescreen( entity bolt, asset fx, entity owner )
{
	if ( !IsValid( owner ) )
		return

	RadiusDamageData radiusDamageData = GetRadiusDamageDataFromProjectile( bolt, owner )

	SmokescreenStruct smokescreen
	smokescreen.smokescreenFX = fx
	smokescreen.lifetime = 5.0
	smokescreen.ownerTeam = owner.GetTeam()
	smokescreen.damageSource = eDamageSourceId.mp_titancore_storm_core
	smokescreen.deploySound1p = "Null_Remove_SoundHook"
	smokescreen.deploySound3p = "Null_Remove_SoundHook"
	smokescreen.attacker = owner
	smokescreen.inflictor = owner
	smokescreen.weaponOrProjectile = bolt
	smokescreen.damageInnerRadius = 50
	smokescreen.damageOuterRadius = 210
	smokescreen.damageDelay = 1.0
	smokescreen.dpsPilot = 150
	smokescreen.dpsTitan = 800

	smokescreen.origin = bolt.GetOrigin()
	smokescreen.angles = bolt.GetAngles()
	smokescreen.fxUseWeaponOrProjectileAngles = true
	smokescreen.fxOffsets = [ <0.0, 0.0, 0.0> ]

	Smokescreen( smokescreen )
}

// originally in sh_archon_util, move here
array<entity> function DamageShieldsInRadiusOnEntity( entity weapon, entity inflictor, float radius, float damage )
{
	array<entity> damagedEnts = [] // used so that we only damage a shield once per function call
	array<string> shieldClasses = [ "mp_titanweapon_vortex_shield", "mp_titanweapon_shock_shield", "mp_titanweapon_heat_shield", "mp_titanability_brute4_bubble_shield" ] // add shields that are like vortex shield/heat shield to this, they seem to be exceptions?

	// not ideal
	foreach ( entity shield in GetEntArrayByClass_Expensive( "vortex_sphere" ) )
	{
		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( weapon.GetWeaponOwner(), inflictor.GetOrigin(), shield.GetCenter() )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )

			if ( damagedEnts.contains( vortexHit.vortex ) )
				continue
			if ( Distance( inflictor.GetCenter(), vortexHit.vortex.GetCenter() ) > radius )
				continue

			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && shieldClasses.contains( vortexWeapon.GetWeaponClassName() ) )
				VortexDrainedByImpact( vortexWeapon, weapon, inflictor, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damage )

			damagedEnts.append( vortexHit.vortex )

		}
	}

	foreach ( entity npc in GetNPCArrayOfEnemies( weapon.GetWeaponOwner().GetTeam() ) )
	{
		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( weapon.GetWeaponOwner(), inflictor.GetOrigin(), npc.GetCenter() )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )

			if ( damagedEnts.contains( vortexHit.vortex ) )
				continue
			if ( Distance( inflictor.GetCenter(), vortexHit.vortex.GetCenter() ) > radius )
				continue

			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && shieldClasses.contains( vortexWeapon.GetWeaponClassName() ) )
				VortexDrainedByImpact( vortexWeapon, weapon, inflictor, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damage )

			damagedEnts.append( vortexHit.vortex )

		}
	}

	foreach ( entity player in GetPlayerArray() )
	{
		if (player.GetTeam() == weapon.GetWeaponOwner().GetTeam())
			continue

		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( weapon.GetWeaponOwner(), inflictor.GetOrigin(), player.GetCenter() )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )

			if ( damagedEnts.contains( vortexHit.vortex ) )
				continue
			if ( Distance( inflictor.GetCenter(), vortexHit.vortex.GetCenter() ) > radius )
				continue

			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && shieldClasses.contains( vortexWeapon.GetWeaponClassName() ) )
				VortexDrainedByImpact( vortexWeapon, weapon, inflictor, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damage )

			damagedEnts.append( vortexHit.vortex )

		}
	}

	return damagedEnts // returning an array of the things you damaged with a RadiusDamage-esque function?? crazy
}
#endif
