untyped

global function OnWeaponPrimaryAttack_weapon_arc_launcher
global function OnProjectileCollision_weapon_grenade_bangalore
global function OnProjectileIgnite_weapon_grenade_bangalore
const ARC_LAUNCHER_ZAP_DAMAGE = 350
const int ARC_LAUNCHER_ZAP_DAMAGE_PILOT_AMPED = 15

const int SMOKE_GRENADE_COUNT = 3
const float SMOKE_LAUNCHER_DELAY = 0.7
const float SMOKE_LAUNCHER_TIME = 15
const float SMOKE_LAUNCHER_TIME_UNLIMITED_AMMO = 1
const float SMOKE_LAUNCHER_RADIUS = 150
const float SMOKE_GRENADE_VERTICAL_SPEED = 250
const float SMOKE_GRENADE_HORIZAL_SPEED = 400

global vector Velocity
var function OnWeaponPrimaryAttack_weapon_arc_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	if ( weaponOwner.IsPlayer() )
	{
		float zoomFrac = weaponOwner.GetZoomFrac()
		if ( zoomFrac < 1 )
			return 0
	}

	#if SERVER
		if ( weaponOwner.IsPlayer() )
		{
			vector angles = VectorToAngles( weaponOwner.GetViewVector() )
			vector up = AnglesToUp( angles )

			if ( weaponOwner.GetTitanSoulBeingRodeoed() != null )
				attackParams.pos = attackParams.pos + up * 20
		}
	#endif

	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	if( weapon.HasMod( "smoke_launcher" ) )
	{
		FireSmokeGrenade( weapon, attackParams )
		weapon.EmitWeaponSound_1p3p( "Weapon_MGL_Fire_1P", "Weapon_MGL_Fire_3P" )
	}
	
	else
	{
		float speed = 450.0

		vector attackPos = attackParams.pos
		vector attackDir = attackParams.dir

		entity arcBall = FireArcBall( weapon, attackPos, attackDir, shouldPredict, ARC_LAUNCHER_ZAP_DAMAGE )
		if( arcBall )
		{
#if SERVER
			entity ballLightning = expect entity( arcBall.s.ballLightning )
			if( weapon.HasMod( "antipilot_arc_launcher" ) )
			{
				ballLightning.e.ballLightningData.damageToPilots = ARC_LAUNCHER_ZAP_DAMAGE_PILOT_AMPED
				ballLightning.e.ballLightningData.damage = ARC_LAUNCHER_ZAP_DAMAGE * 0.2
			}
#endif
		}

		weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		return 1
	}
}

function FireSmokeGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		#if SERVER
			Grenade_Init( nade, weapon )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
		if( weapon.HasMod( "smoke_launcher" ) )
		{
			nade.SetModel( $"models/weapons/bullets/triple_threat_projectile.mdl" )
			#if SERVER
			nade.proj.savedAngles = VectorToAngles( attackParams.dir )
			thread DelayedStartSmokeParticle( nade )
			#endif
			return
		}
	}
}

void function OnProjectileCollision_weapon_grenade_bangalore( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()

	if( mods.contains("smoke_launcher") )
	{
		entity player = projectile.GetOwner()
		if ( hitEnt == player )
			return

		if ( projectile.GrenadeHasIgnited() )
			return

		#if SERVER
			                                                                        
		#endif         

		if ( LengthSqr( normal ) < 0.01 )                                                                                     
			normal = AnglesToForward( VectorToAngles( projectile.GetVelocity() ) )

		#if SERVER
			                                           
		#endif         

		table collisionParams =
		{
			pos = pos,
			normal = normal,
			hitEnt = hitEnt,
			hitbox = hitbox
		}
		
		//projectile.SetModel( $"models/dev/empty_model.mdl" )
		
		//PlantStickyEntity( projectile, collisionParams, normal )
		
		Velocity = projectile.GetVelocity()

		projectile.GrenadeIgnite()
		projectile.SetDoesExplode( true )
	}
}

void function OnProjectileIgnite_weapon_grenade_bangalore( entity projectile )
{
	#if SERVER

	vector origin = projectile.GetOrigin()
	array<vector> velocitygroup
	bool isOddNumber = SMOKE_GRENADE_COUNT % 2 != 0
	if( isOddNumber ) // spawn a center smoke if odd
	{
		vector upVector = AnglesToUp( projectile.proj.savedAngles )
		upVector.z = SMOKE_GRENADE_VERTICAL_SPEED
		velocitygroup.append( upVector )
	}
	vector baseVector = AnglesToRight( projectile.proj.savedAngles )
	vector baseAngles = < 0, VectorToAngles( baseVector ).y, 0 >
	int smokeCount = isOddNumber ? SMOKE_GRENADE_COUNT - 1 : SMOKE_GRENADE_COUNT
	float rotPerGrenade = 360 / float( smokeCount )
	for( int i = 0; i < smokeCount; i++ )
	{
		vector newAngles = < 0, baseAngles.y + i * rotPerGrenade, 0 >
		vector newVector = AnglesToForward( newAngles ) * SMOKE_GRENADE_HORIZAL_SPEED
		newVector.z = SMOKE_GRENADE_VERTICAL_SPEED
		velocitygroup.append( newVector )
	}
	/*
	vector rightVector = AnglesToRight( projectile.proj.savedAngles ) * SMOKE_GRENADE_HORIZAL_SPEED
	vector leftVector = -rightVector
	rightVector.z = SMOKE_GRENADE_VERTICAL_SPEED
	velocitygroup.append( rightVector )
	leftVector.z = SMOKE_GRENADE_VERTICAL_SPEED
	velocitygroup.append( leftVector )
	*/
	bool isLimitedSmoke = false
	if( projectile.ProjectileGetMods().contains( "unlimited_balance" ) )
		isLimitedSmoke = true

	for( int i = 0; i < velocitygroup.len(); i++ )
	{
		vector velocety = velocitygroup[i]
		entity grenade = CreatePropAsGrenade( velocety, origin )
		thread DelayedSmokeGrenadeIgnite( grenade, isLimitedSmoke )
	}

	/* // using a better one
	vector origin = projectile.GetOrigin()
	array<vector> velocitygroup = CreateVelocityGroup( Velocity )
	bool isLimitedSmoke = false
	if( projectile.ProjectileGetMods().contains( "unlimited_balance" ) )
		isLimitedSmoke = true

	for( int i = 0; i < velocitygroup.len(); i++ )
	{
		vector velocety = velocitygroup[i]
		entity grenade = CreatePropAsGrenade( velocety, origin )
		thread DelayedSmokeGrenadeIgnite( grenade, isLimitedSmoke )
	}
	*/

	#endif
}

#if SERVER
entity function CreatePropAsGrenade( vector velocety, vector origin )
{
	entity nade = CreateEntity( "prop_physics" )
	//prop_physics does not compilable with most other models
  	nade.SetModel( $"models/dev/empty_physics.mdl" )
 	nade.SetOrigin( origin )
  	
  	DispatchSpawn( nade )
  	nade.SetVelocity( velocety )
  	StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"P_wpn_grenade_smoke_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
	thread DelayedStartSmokeParticle( nade ) // for better client visual

  	return nade
}

void function DelayedStartSmokeParticle( entity nade )
{
	WaitFrame()
	if( IsValid( nade ) )
		StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"P_wpn_grenade_smoke_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
}

void function DelayedSmokeGrenadeIgnite( entity nade, bool shouldReduce = false )
{
	wait SMOKE_LAUNCHER_DELAY
	if( IsValid( nade ) )
	{
		SmokescreenStruct smokescreen
		smokescreen.smokescreenFX = $"P_smokescreen_FD"
		smokescreen.deploySound1p = SFX_SMOKE_GRENADE_DEPLOY
	   	smokescreen.deploySound3p = SFX_SMOKE_GRENADE_DEPLOY
		smokescreen.isElectric = false
		smokescreen.origin = nade.GetOrigin()
		smokescreen.angles = <0,0,0>
		smokescreen.lifetime = shouldReduce ? SMOKE_LAUNCHER_TIME_UNLIMITED_AMMO : SMOKE_LAUNCHER_TIME
		smokescreen.fxXYRadius = SMOKE_LAUNCHER_RADIUS
		smokescreen.fxZRadius = SMOKE_LAUNCHER_RADIUS * 0.8
		smokescreen.fxOffsets = [<0.0, 0.0, 0.0>]
		Smokescreen(smokescreen)

		nade.Destroy()
	}
}

array<vector> function CreateVelocityGroup( vector base )
{
	array<vector> group = []
	vector velocity = < 200, 200, base.z * -0.15 >
	group.append( velocity )
	velocity = < -200, -200, base.z * -0.15 >
	group.append( velocity )
	velocity = < -200, 200, base.z * -0.15 >
	group.append( velocity )
	velocity = < 200, -200, base.z * -0.15 >
	group.append( velocity )


	return group
}
#endif