untyped

global function MpTitanWeaponBarrageCoreLauncher_Init

global function OnWeaponPrimaryAttack_titanweapon_barrage_core_launcher
global function OnProjectileCollision_titanweapon_barrage_core_launcher

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_barrage_core_launcher

global function Brute4_StartClusterExplosions
#endif // #if SERVER

const FUSE_TIME = 0.25 //Applies once the grenade has stuck to a surface.
const FUSE_TIME_EXT = 1.5

void function MpTitanWeaponBarrageCoreLauncher_Init()
{
	PrecacheParticleSystem( $"Rocket_Smoke_SMALL_Titan_mod" )
	PrecacheParticleSystem( $"wpn_grenade_sonar_titan_AMP" )
	PrecacheParticleSystem( $"wpn_grenade_frag_softball_burn" )

#if SERVER
	// adding a new damageSourceId. it's gonna transfer to client automatically
	RegisterWeaponDamageSource( "mp_titanweapon_barrage_core_launcher", "Barrage Core" ) // "Barrage Core Cluster", limited to 1 space-bar usage...

	// don't gain core meter from core weapon
	GameModeRulesRegisterTimerCreditException( eDamageSourceId.mp_titanweapon_barrage_core_launcher )

	// vortex refire override
	Vortex_AddImpactDataOverride_WeaponMod( 
		"mp_titanweapon_flightcore_rockets", // weapon name
		"brute4_barrage_core_launcher", // mod name
		$"wpn_vortex_projectile_frag_FP", // absorb effect
		$"wpn_vortex_projectile_frag", // absorb effect 3p
		"grenade" // refire behavior
	)
#endif
}

var function OnWeaponPrimaryAttack_titanweapon_barrage_core_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		return FireGrenade( weapon, attackParams )
	return 1
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_barrage_core_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	return FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

var function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, bool isNPCFiring = false )
{
	entity owner = weapon.GetWeaponOwner()

	vector angularVelocity = Vector( 0, 0, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		nade.SetModel( $"models/weapons/grenades/m20_f_grenade_projectile.mdl" )
		#if SERVER
			nade.ProjectileSetDamageSourceID( eDamageSourceId.mp_titanweapon_barrage_core_launcher ) // change damageSourceID
			EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
			Grenade_Init( nade, weapon )

			// hide default trail, so clients without scripts installed won't show flight core rocket launcher's trails
			nade.SetReducedEffects()
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif

		// fix for trail effect, so clients without scripts installed can see the trail
		StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"Rocket_Smoke_SMALL_Titan_mod" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"wpn_grenade_sonar_titan_AMP" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"wpn_grenade_frag_softball_burn" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	}
	return 1
}

void function OnProjectileCollision_titanweapon_barrage_core_launcher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		if ( IsAlive( hitEnt ) && hitEnt.IsPlayer() )
		{
			PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
			EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
			EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
		}
		else
		{
			PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
			EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
		}

		if ( projectile.proj.projectileBounceCount == 0 ) // ensure we only detonate once
		{
			// HACK - call cluster creation on impact, otherwise projectile will be null; use projectile_explosion_delay in .txt to account for FUSE_TIME. Must match!
			StartClusterAfterDelay( projectile, normal )
			thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
			projectile.proj.projectileBounceCount++
		}
	#endif
}

#if SERVER
void function StartClusterAfterDelay( entity projectile, vector normal) {
	entity owner = projectile.GetOwner()
	if ( IsValid( owner ) )
	{
		PopcornInfo popcornInfo
		// Clusters share explosion radius/damage with the base weapon
		// Clusters spawn '((int) (count/groupSize) + 1) * groupSize' total subexplosions (thanks to a '<=')
		// The ""base delay"" between each group's subexplosion on average is ((float) duration / (int) (count / groupSize))
		// The actual delay is (""base delay"" - delay). Thus 'delay' REDUCES delay. Make sure delay + offset < ""base delay"".

		// Current:
		// 4 count, 0.15 delay, 2 duration, 1 groupSize
		// Total: 5 subexplosions
		// ""Base delay"": 0.4s, avg delay between (each group): 0.25s, total duration: 1.25s
		popcornInfo.weaponName = "mp_titanweapon_barrage_core_launcher"
		popcornInfo.weaponMods = projectile.ProjectileGetMods()
		popcornInfo.damageSourceId = eDamageSourceId.mp_titanweapon_barrage_core_launcher
		popcornInfo.count = 4
		popcornInfo.delay = projectile.ProjectileGetMods().contains( "rapid_detonator" ) ? 0.2 : 0.15 // avg delay and duration -20%
		popcornInfo.offset = 0.1
		popcornInfo.range = 150
		popcornInfo.normal = normal
		popcornInfo.duration = 1.6
		popcornInfo.groupSize = 1
		popcornInfo.hasBase = false

		thread Brute4_StartClusterExplosions( projectile, owner, popcornInfo, CLUSTER_ROCKET_FX_TABLE )
	}
}


// Copy and pasted this cluster code from utility so I can disable self damage
function Brute4_StartClusterExplosions( entity projectile, entity owner, PopcornInfo popcornInfo, customFxTable = null )
{
	Assert( IsValid( owner ) )
	owner.EndSignal( "OnDestroy" )

	string weaponName = popcornInfo.weaponName
	float innerRadius
	float outerRadius
	int explosionDamage
	int explosionDamageHeavyArmor

	innerRadius = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.explosion_inner_radius )
	outerRadius = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.explosionradius )
	if ( owner.IsPlayer() )
	{
		explosionDamage = projectile.GetProjectileWeaponSettingInt( eWeaponVar.explosion_damage )
		explosionDamageHeavyArmor = projectile.GetProjectileWeaponSettingInt( eWeaponVar.explosion_damage_heavy_armor )
	}
	else
	{
		explosionDamage = projectile.GetProjectileWeaponSettingInt( eWeaponVar.npc_explosion_damage )
		explosionDamageHeavyArmor = projectile.GetProjectileWeaponSettingInt( eWeaponVar.npc_explosion_damage_heavy_armor )
	}

	local explosionDelay = projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_explosion_delay" )

	if ( owner.IsPlayer() )
		owner.EndSignal( "OnDestroy" )

	vector origin = projectile.GetOrigin()

	vector rotateFX = Vector( 90,0,0 )
	entity placementHelper = CreateScriptMover()
	placementHelper.SetOrigin( origin )
	placementHelper.SetAngles( VectorToAngles( popcornInfo.normal ) )
	SetTeam( placementHelper, owner.GetTeam() )

	array<entity> players = GetPlayerArray()
	foreach ( player in players )
	{
		Remote_CallFunction_NonReplay( player, "SCB_AddGrenadeIndicatorForEntity", owner.GetTeam(), owner.GetEncodedEHandle(), placementHelper.GetEncodedEHandle(), outerRadius )
	}

	int particleSystemIndex = GetParticleSystemIndex( CLUSTER_BASE_FX )
	int attachId = placementHelper.LookupAttachment( "REF" )
	entity fx

	if ( popcornInfo.hasBase )
	{
		fx = StartParticleEffectOnEntity_ReturnEntity( placementHelper, particleSystemIndex, FX_PATTACH_POINT_FOLLOW, attachId )
		EmitSoundOnEntity( placementHelper, "Explo_ThermiteGrenade_Impact_3P" ) // TODO: wants a custom sound
	}

	OnThreadEnd(
		function() : ( fx, placementHelper )
		{
			if ( IsValid( fx ) )
				EffectStop( fx )
			placementHelper.Destroy()
		}
	)

	if ( explosionDelay )
		wait explosionDelay

	waitthread Brute4_ClusterRocketBursts( origin, explosionDamage, explosionDamageHeavyArmor, innerRadius, outerRadius, owner, popcornInfo, customFxTable )

	if ( IsValid( projectile ) )
		projectile.Destroy()
}


//------------------------------------------------------------
// ClusterRocketBurst() - does a "popcorn airburst" explosion effect over time around the origin. Total distance is based on popRangeBase
// - returns the entity in case you want to parent it
//------------------------------------------------------------
function Brute4_ClusterRocketBursts( vector origin, int damage, int damageHeavyArmor, float innerRadius, float outerRadius, entity owner, PopcornInfo popcornInfo, customFxTable = null )
{
	owner.EndSignal( "OnDestroy" )

	// this ent remembers the weapon mods
	entity clusterExplosionEnt = CreateEntity( "info_target" )
	DispatchSpawn( clusterExplosionEnt )

	if ( popcornInfo.weaponMods.len() > 0 )
		clusterExplosionEnt.s.weaponMods <- popcornInfo.weaponMods

	clusterExplosionEnt.SetOwner( owner )
	clusterExplosionEnt.SetOrigin( origin )

	// AI_CreateDangerousArea_Static( clusterExplosionEnt, null, outerRadius, owner.GetTeam(), true, true, origin )

	OnThreadEnd(
		function() : ( clusterExplosionEnt )
		{
			clusterExplosionEnt.Destroy()
		}
	)

	// No Damage - Only Force
	// Push players
	// Test LOS before pushing
	int flags = 11
	// create a blast that knocks pilots out of the way
	CreatePhysExplosion( origin, outerRadius, PHYS_EXPLOSION_LARGE, flags )

	int count = popcornInfo.groupSize
	for ( int index = 0; index < count; index++ )
	{
		thread Brute4_ClusterRocketBurst( clusterExplosionEnt, origin, damage, damageHeavyArmor, innerRadius, outerRadius, owner, popcornInfo, customFxTable )
		WaitFrame()
	}

	wait 2.5 // Should be greater than the max possible time for subexplosions to spawn
}

function Brute4_ClusterRocketBurst( entity clusterExplosionEnt, vector origin, damage, damageHeavyArmor, innerRadius, outerRadius, entity owner, PopcornInfo popcornInfo, customFxTable = null )
{
	clusterExplosionEnt.EndSignal( "OnDestroy" )
	Assert( IsValid( owner ), "ClusterRocketBurst had invalid owner" )

	// first explosion always happens where you fired
	//int eDamageSource = popcornInfo.damageSourceId
	int numBursts = popcornInfo.count
	float popRangeBase = popcornInfo.range
	float popDelayBase = popcornInfo.delay
	float popDelayRandRange = popcornInfo.offset
	float duration = popcornInfo.duration
	int groupSize = popcornInfo.groupSize

	int counter = 0
	vector randVec
	float randRangeMod
	float popRange
	vector popVec
	vector popOri = origin
	float popDelay
	float colTrace

	float burstDelay = duration / ( numBursts / groupSize )

	vector clusterBurstOrigin = origin + (popcornInfo.normal * 8.0)
	entity clusterBurstEnt = CreateClusterBurst( clusterBurstOrigin )

	int explosionFlags = SF_ENVEXPLOSION_NOSOUND_FOR_ALLIES
	if ( popcornInfo.weaponName == "mp_titanweapon_barrage_core_launcher" )
		explosionFlags = explosionFlags | SF_ENVEXPLOSION_NO_DAMAGEOWNER

	OnThreadEnd(
		function() : ( clusterBurstEnt )
		{
			if ( IsValid( clusterBurstEnt ) )
			{
				foreach ( fx in clusterBurstEnt.e.fxArray )
				{
					if ( IsValid( fx ) )
						fx.Destroy()
				}
				clusterBurstEnt.Destroy()
			}
		}
	)

	while ( IsValid( clusterBurstEnt ) && counter <= numBursts / popcornInfo.groupSize )
	{
		randVec = RandomVecInDome( popcornInfo.normal )
		randRangeMod = RandomFloat( 1.0 )
		popRange = popRangeBase * randRangeMod
		popVec = randVec * popRange
		popOri = origin + popVec
		popDelay = popDelayBase + RandomFloatRange( -popDelayRandRange, popDelayRandRange )

		colTrace = TraceLineSimple( origin, popOri, null )
		if ( colTrace < 1 )
		{
			popVec = popVec * colTrace
			popOri = origin + popVec
		}

		clusterBurstEnt.SetOrigin( clusterBurstOrigin )

		vector velocity = GetVelocityForDestOverTime( clusterBurstEnt.GetOrigin(), popOri, burstDelay - popDelay )
		clusterBurstEnt.SetVelocity( velocity )

		clusterBurstOrigin = popOri

		counter++

		wait burstDelay - popDelay

		Explosion(
			clusterBurstOrigin,
			owner,
			clusterExplosionEnt,
			damage,
			damageHeavyArmor,
			innerRadius,
			outerRadius,
			explosionFlags,
			clusterBurstOrigin,
			damage,
			damageTypes.explosive,
			popcornInfo.damageSourceId,
			customFxTable )
	}
}

entity function CreateClusterBurst( vector origin )
{
	entity prop_physics = CreateEntity( "prop_physics" )
	prop_physics.SetValueForModelKey( $"models/weapons/bullets/projectile_rocket.mdl" )
	prop_physics.kv.spawnflags = 4 // 4 = SF_PHYSPROP_DEBRIS
	prop_physics.kv.fadedist = 2000
	prop_physics.kv.renderamt = 255
	prop_physics.kv.rendercolor = "255 255 255"
	prop_physics.kv.CollisionGroup = TRACE_COLLISION_GROUP_DEBRIS

	prop_physics.kv.minhealthdmg = 9999
	prop_physics.kv.nodamageforces = 1
	prop_physics.kv.inertiaScale = 1.0

	prop_physics.SetOrigin( origin )
	DispatchSpawn( prop_physics )
	prop_physics.SetModel( $"models/weapons/grenades/m20_f_grenade.mdl" )

	entity fx = PlayFXOnEntity( $"P_wpn_dumbfire_burst_trail", prop_physics )
	prop_physics.e.fxArray.append( fx )

	return prop_physics
}
#endif //SERVER

#if SERVER
// need this so grenade can use the normal to explode
void function DetonateStickyAfterTime( entity projectile, float delay, vector normal )
{
	wait delay
	if ( IsValid( projectile ) )
	{
		projectile.GrenadeExplode( normal )
		// due we've hide projectile effect, do a impact effect manually
		// this is actually better cause "exp_rocket_dumbfire" have bad airburst effect, but grenades exploding with offset sometimes triggering them
		// PlayImpactFXTable() with SF_ENVEXPLOSION_INCLUDE_ENTITIES flag can prevent that from happening
		PlayImpactFXTable( projectile.GetOrigin(), projectile, "exp_rocket_dumbfire", SF_ENVEXPLOSION_INCLUDE_ENTITIES )
	}
}
#endif

