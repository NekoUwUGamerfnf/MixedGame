untyped

global function MpWeaponGreandeElectricSmoke_Init
global function OnProjectileCollision_weapon_grenade_electric_smoke

global function OnProjectileIgnite_weapon_grenade_electirc_smoke
#if SERVER
global function ElectricGrenadeSmokescreen
#endif

global const FX_ELECTRIC_SMOKESCREEN_PILOT = $"P_wpn_smk_electric_pilot"
global const FX_ELECTRIC_SMOKESCREEN_PILOT_AIR = $"P_wpn_smk_electric_pilot_air"

const float FLASH_DURATION_MAX = 3
const float FLASH_FADEOUT_DURATION = 1
const float FLASHBANG_FUSE_TIME = 1.75

const SMOKE_MINE_LIFETIME = 15
const SMOKE_MINE_ARMING_DELAY = 0.5

void function MpWeaponGreandeElectricSmoke_Init()
{
	PrecacheParticleSystem( FX_ELECTRIC_SMOKESCREEN_PILOT )
	PrecacheParticleSystem( FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )

	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_grenade_electric_smoke, FlashBang_DamagedTarget )
	RegisterSignal( "MineTriggered" )
	#endif
}

void function OnProjectileCollision_weapon_grenade_electric_smoke( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded weapons
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if( mods.contains( "creeping_bombardment" ) )
	{
		if( projectile.GetClassName() == "rpg_missile" )
			return OnProjectileCollision_WeaponCreepingBombardmentWeapon( projectile, pos, normal, hitEnt, hitbox, isCritical )
		if( projectile.GetClassName() == "grenade" )
			return OnProjectileCollision_WeaponCreepingBombardment( projectile, pos, normal, hitEnt, hitbox, isCritical )
	}
	
	entity player = projectile.GetOwner()
	if ( hitEnt == player )
		return

	if ( projectile.GrenadeHasIgnited() )
		return

#if SERVER
	if( mods.contains( "flashbang" ) )
	{
		if( projectile.proj.projectileBounceCount == 0 ) // first bounce
			projectile.SetGrenadeTimer( FLASHBANG_FUSE_TIME ) // start timer
		projectile.proj.projectileBounceCount++
		return
		/* // no need to check these
		projectile.proj.projectileBounceCount++
		int maxBounceCount = projectile.GetProjectileWeaponSettingInt( eWeaponVar.projectile_ricochet_max_count )

		bool forceExplode = false
		if ( projectile.proj.projectileBounceCount > maxBounceCount )
		{
			forceExplode = true
		}
		bool projectileIsOnGround = normal.Dot( <0,0,1> ) > 0.75
		if( projectileIsOnGround && forceExplode )
		{
			projectile.proj.savedOrigin = normal
			projectile.GrenadeExplode( normal )
		}
		*/
	}
	else
	{
#endif
		table collisionParams =
		{
			pos = pos,
			normal = normal,
			hitEnt = hitEnt,
			hitbox = hitbox
		}

		if( !mods.contains( "smoke_mine" ) )
			projectile.SetModel( $"models/dev/empty_model.mdl" ) // model change should be done before PlantStickyEntity(), otherwise projectile will detach
		bool result = PlantStickyEntity( projectile, collisionParams, <90.0, 0.0, 0.0> )
		
#if SERVER
		if( mods.contains( "smoke_mine" ) )
		{
			thread SmokeMineThink( projectile )
		}
		else
		{
#endif

#if SERVER
			if ( !result )
			{
				projectile.SetVelocity( <0.0, 0.0, 0.0> )
				projectile.StopPhysics()
				ElectricGrenadeSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )
			}
			else if ( IsValid( hitEnt ) && ( hitEnt.IsPlayer() || hitEnt.IsTitan() || hitEnt.IsNPC() ) )
			{
				// this is vanilla missing behavior:
				// should never let electric smoke grenade stick on entities
				// their smokescreen never moves
				projectile.ClearParent()
				projectile.SetVelocity( <0.0, 0.0, 0.0> )
				projectile.StopPhysics()
				//

				ElectricGrenadeSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT_AIR )
			}
			else
			{
				ElectricGrenadeSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT )
			}

			projectile.GrenadeIgnite()
			projectile.SetDoesExplode( false )
		}
	}
#endif
}

void function OnProjectileIgnite_weapon_grenade_electirc_smoke( entity projectile )
{
	#if SERVER
	//FlashBangExplosion( projectile )
	#endif
}

#if SERVER
void function ElectricGrenadeSmokescreen( entity projectile, asset fx, float delay = 1.0 )
{
	entity owner = projectile.GetThrower()

	if ( !IsValid( owner ) )
		return

	RadiusDamageData radiusDamageData = GetRadiusDamageDataFromProjectile( projectile, owner )

	SmokescreenStruct smokescreen
	smokescreen.smokescreenFX = fx
	smokescreen.ownerTeam = owner.GetTeam()
	smokescreen.damageSource = eDamageSourceId.mp_weapon_grenade_electric_smoke
	smokescreen.deploySound1p = "explo_electric_smoke_impact"
	smokescreen.deploySound3p = "explo_electric_smoke_impact"
	smokescreen.attacker = owner
	// this is stupid. we do have a projectile to behave as inflictor, why use owner?
	//smokescreen.inflictor = owner
	smokescreen.inflictor = projectile
	smokescreen.weaponOrProjectile = projectile
	smokescreen.damageInnerRadius = radiusDamageData.explosionInnerRadius
	smokescreen.damageOuterRadius = radiusDamageData.explosionRadius
	smokescreen.dangerousAreaRadius = smokescreen.damageOuterRadius * 1.5
	smokescreen.damageDelay = delay
	smokescreen.dpsPilot = radiusDamageData.explosionDamage
	smokescreen.dpsTitan = radiusDamageData.explosionDamageHeavyArmor

	smokescreen.origin = projectile.GetOrigin()
	smokescreen.angles = projectile.GetAngles()
	smokescreen.fxUseWeaponOrProjectileAngles = true
	smokescreen.fxOffsets = [ <0.0, 0.0, 2.0> ]

	// modified to add: lifetime should match projectile's ignition time
	smokescreen.lifetime = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.grenade_ignition_time )

	Smokescreen( smokescreen )
}
#endif

#if SERVER
void function FlashBangExplosion( entity projectile )
{
	entity owner = projectile.GetThrower()

	if ( !IsValid( owner ) )
		return

	RadiusDamageData radiusDamageData = GetRadiusDamageDataFromProjectile( projectile, owner )

	RadiusDamage(
		projectile.GetOrigin(),								// origin
		owner,												// owner
		projectile,		 									// inflictor
		radiusDamageData.explosionDamage,					// pilot damage
		radiusDamageData.explosionDamageHeavyArmor,			// heavy armor damage
		radiusDamageData.explosionInnerRadius,				// inner radius
		radiusDamageData.explosionRadius,					// outer radius
		SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
		0, 													// distanceFromAttacker
		5000, 												// explosionForce
		0,													// damage flags
		eDamageSourceId.mp_weapon_grenade_electric_smoke 	// damage source id
	)
}

void function FlashBang_DamagedTarget( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )

	if( !IsValid( inflictor ) )
		return
	if( !inflictor.IsProjectile() )
		return

	array<string> mods = Vortex_GetRefiredProjectileMods( inflictor ) // modded weapon refire behavior

	if( mods.contains( "flashbang" ) )
	{
		entity attacker = DamageInfo_GetAttacker( damageInfo )
		DamageInfo_SetDamage( damageInfo, 0 )
		if( !IsValid( attacker ) )
			return
		thread FlashEffect( ent, inflictor, damageInfo )
	}
}

void function FlashEffect( entity victim, entity projectile, var damageInfo )
{
	if( !IsValid( victim ) )
		return
	if( !victim.IsPlayer() )
		return
	if( !IsValid( projectile ) )
		return

	victim.EndSignal( "OnDeath" )
	victim.EndSignal( "OnDestroy" )
	victim.EndSignal( "OnChangedPlayerClass" )

	entity owner = projectile.GetThrower()

	if ( !IsValid( owner ) )
		return

	RadiusDamageData radiusDamageData = GetRadiusDamageDataFromProjectile( projectile, owner )
	vector damagePos = DamageInfo_GetDamagePosition( damageInfo )

	if( !PlayerCanSeePos( victim, damagePos, true, 135 ) )
	{
		print( "Victim didn't see flash point!" )
		return
	}

	float distance = fabs( Distance( victim.GetOrigin(), projectile.GetOrigin() ) )

	float severity = 1 - distance / radiusDamageData.explosionRadius
	if( distance <= radiusDamageData.explosionInnerRadius )
		severity = 1

	ScreenFade( victim, 255, 255, 255, 255 * severity, 0.1, FLASH_DURATION_MAX + 0.2, FFADE_OUT | FFADE_PURGE )

	OnThreadEnd(
		function() : ( victim, severity )
		{
			if( IsAlive( victim ) )
				ScreenFadeFromColor( victim, 255, 255, 255, 255 * severity, FLASH_FADEOUT_DURATION, 0.0 )
		}
	)

	wait FLASH_DURATION_MAX + 0.1

}

void function SmokeMineThink( entity projectile )
{
	if( !IsValid( projectile ) )
		return

	projectile.EndSignal( "OnDestroy" )
	entity owner = projectile.GetOwner()
	owner.EndSignal( "OnDestroy" )
	OnThreadEnd(
		function() : ( projectile )
		{
			if ( IsValid( projectile ) )
				projectile.Destroy()
		}
	)

	wait SMOKE_MINE_ARMING_DELAY

	EmitSoundOnEntity( projectile, "Weapon_R1_Satchel.Attach" )
	thread EnableTrapWarningSound( projectile, 0, DEFAULT_WARNING_SFX )
	int teamNum = projectile.GetTeam()
	float triggerRadius = projectile.GetDamageRadius()
	local PlayerTickRate = 0.2

	float startTime = Time()
	while( IsValid( projectile ) && IsValid( owner ) )
	{
		array<entity> nearbyPlayers = GetPlayerArrayEx( "any", TEAM_ANY, teamNum, projectile.GetOrigin(), triggerRadius )
		foreach( ent in nearbyPlayers )
		{
			if ( ShouldSetOffProximityMine( projectile, ent ) )
			{
				SmokeMineIgnite( projectile )
				return
			}
		}

		wait PlayerTickRate

		if( Time() >= startTime + SMOKE_MINE_LIFETIME )
			break
	}
}

void function SmokeMineIgnite( entity projectile )
{
	if( IsValid( projectile ) )
	{
		ElectricGrenadeSmokescreen( projectile, FX_ELECTRIC_SMOKESCREEN_PILOT, 0.5 )
		projectile.Destroy()
	}
}
#endif