untyped
#if SERVER
global function ThermiteBurn
global const float THERMITE_GRENADE_BURN_TIME = 6.0
global const float THERMITE_TRAIL_SOUND_TIME = 2.0
#endif

global function OnWeaponTossReleaseAnimEvent_weapon_thermite_grenade

global function OnProjectileCollision_weapon_thermite_grenade
global function OnProjectileIgnite_weapon_thermite_grenade

var function OnWeaponTossReleaseAnimEvent_weapon_thermite_grenade( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity grenade = Grenade_OnWeaponToss_ReturnEntity( weapon, attackParams, 1.0 )
	if( !IsValid( grenade ) )
		return
#if SERVER
	vector attackAngle = VectorToAngles( attackParams.dir )
	grenade.proj.savedAngles = < 0,attackAngle.y,0 >
#endif
	if( weapon.HasMod( "meteor_grenade" ) )
		grenade.SetModel( $"models/weapons/bullets/triple_threat_projectile.mdl" )
	else if( weapon.HasMod( "flamewall_grenade" ) )
		grenade.SetModel( $"models/weapons/grenades/smoke_grenade_projectile.mdl" )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
	
}

void function OnProjectileCollision_weapon_thermite_grenade( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	entity player = projectile.GetOwner()
	array<string> mods = projectile.ProjectileGetMods()

	if ( hitEnt == player )
		return

	table collisionParams =
	{
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	if ( IsSingleplayer() && ( player && !player.IsPlayer() ) )
		collisionParams.hitEnt = GetEntByIndex( 0 )

	if( mods.contains( "flamewall_grenade" ) )
	{
		bool result = PlantStickyEntityOnWorldThatBouncesOffWalls( projectile, collisionParams, 0.7 )
#if SERVER
		projectile.proj.savedOrigin = normal
#endif
		if( !result )
			return
	}
	else
	{
		bool result = PlantStickyEntity( projectile, collisionParams )

		if( mods.contains( "meteor_grenade" ) )
		{
			EmitSoundOnEntity( projectile, "explo_firestar_impact" )
			OnProjectileCollision_Meteor( projectile, pos, normal, hitEnt, hitbox, isCritical )
			projectile.GrenadeExplode( normal )
			#if SERVER
			//thread DelayedGrenadeExplode( projectile, THERMITE_TRAIL_SOUND_TIME )
			#endif
			return
		}
	}

	if ( projectile.GrenadeHasIgnited() )
		return

	projectile.GrenadeIgnite()
}

void function DelayedGrenadeExplode( entity projectile, float delay )
{
	wait delay
	if( IsValid( projectile ) )
		projectile.GrenadeExplode( < 0,0,0 > )
}

void function OnProjectileIgnite_weapon_thermite_grenade( entity projectile )
{
	projectile.SetDoesExplode( false )

	#if SERVER
		projectile.proj.onlyAllowSmartPistolDamage = false

		entity player = projectile.GetOwner()

		array<string> mods = projectile.ProjectileGetMods()

		if ( !IsValid( player ) )
		{
			projectile.Destroy()
			return
		}

		if( mods.contains( "flamewall_grenade" ) && player.IsPlayer() )
		{
			entity thermiteWeapon
			foreach( entity offhand in player.GetOffhandWeapons() )
			{
				if( offhand.GetWeaponClassName() == "mp_weapon_thermite_grenade" )
				{
					if( offhand.HasMod( "flamewall_grenade" ) )
						thermiteWeapon = offhand
				}
			}
			if( !IsValid( thermiteWeapon ) )
			{
				projectile.Destroy()
				//print( "Thermite Weapon Invalid!" )
				return
			}
			// it's hard!
			//vector fireAng = projectile.proj.savedAngles
			/*
			WeaponPrimaryAttackParams fakeParams
			fakeParams.pos = projectile.GetOrigin() + projectile.proj.savedOrigin
			vector fireAng = projectile.proj.savedAngles
			fakeParams.dir = AnglesToForward( < 0,fireAng.y + 90,0 > )
			OnWeaponPrimaryAttack_FlameWall( thermiteWeapon, fakeParams )
			fakeParams.dir = AnglesToForward( < 0,fireAng.y - 90,0 > )
			OnWeaponPrimaryAttack_FlameWall( thermiteWeapon, fakeParams )
			*/
			StartFlameWall( thermiteWeapon, projectile )

			//thread FlameWallGrenadeThink( projectile, thermiteWeapon )

			//print( "Tried to spawn FlameWall!" )
			//projectile.Destroy()
			return
		}

		thread ThermiteBurn( THERMITE_GRENADE_BURN_TIME, player, projectile )

		entity entAttachedTo = projectile.GetParent()
		if ( !IsValid( entAttachedTo ) )
			return

		if ( !player.IsPlayer() ) //If an NPC Titan has vortexed a satchel and fires it back out, then it won't be a player that is the owner of this satchel
			return

		entity titanSoulRodeoed = player.GetTitanSoulBeingRodeoed()
		if ( !IsValid( titanSoulRodeoed ) )
			return

		entity titan = titanSoulRodeoed.GetTitan()

		if ( !IsAlive( titan ) )
			return

		if ( titan == entAttachedTo )
			titanSoulRodeoed.SetLastRodeoHitTime( Time() )
	#endif
}

#if SERVER
void function FlameWallGrenadeThink( entity projectile, entity thermiteWeapon )
{
	entity inflictor = CreateOncePerTickDamageInflictorHelper( 6 )
	projectile.EndSignal( "OnDestroy" )
	projectile.SetTakeDamageType( DAMAGE_NO )
	WeaponPrimaryAttackParams fakeParams
	fakeParams.pos = projectile.GetOrigin() + projectile.proj.savedOrigin
	vector fireAng = projectile.proj.savedAngles
	fakeParams.dir = AnglesToForward( < 0,fireAng.y - 90,0 > )
	thread WeaponAttackWave( projectile, 0, inflictor, fakeParams.pos + fakeParams.dir * 25.0, fakeParams.dir, CreateThermiteWallSegment )
	fakeParams.dir = AnglesToForward( < 0,fireAng.y + 90,0 > )
	waitthread WeaponAttackWave( projectile, 0, inflictor, fakeParams.pos + fakeParams.dir * 25.0, fakeParams.dir, CreateThermiteWallSegment )
	print( projectile.GetOrigin() )
	//projectile.Destroy()
}

void function StartFlameWall( entity weapon, entity projectile )
{
	entity inflictor = CreateOncePerTickDamageInflictorHelper( 6 )
	inflictor.SetScriptName( "thermite_dot_inflictor" )

	WeaponPrimaryAttackParams attackParams
	vector startPos = projectile.GetOrigin() + < 0,0,30 >
	vector fireAng = projectile.proj.savedAngles
	// hardcoded!!!!
	array<entity> fakeProjectiles
	array<vector> vectorGroup = [AnglesToForward( < 0,fireAng.y - 90,0 > ), AnglesToForward( < 0,fireAng.y + 90,0 > )]
	attackParams.pos = startPos
	attackParams.dir = vectorGroup[0]
	fakeProjectiles.append( weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, 99, damageTypes.projectileImpact, damageTypes.explosive, false, true, true ) )
	attackParams.pos = startPos
	attackParams.dir = vectorGroup[1]
	fakeProjectiles.append( weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, 99, damageTypes.projectileImpact, damageTypes.explosive, false, true, true ) )
	
	foreach( int index, entity projectile in fakeProjectiles )
	{
		if ( projectile )
		{
			attackParams.pos = startPos - vectorGroup[index] * 150 // should do this or flame walls will have a period
			attackParams.dir = vectorGroup[index]
			projectile.SetModel( $"models/dev/empty_model.mdl" )
			EmitSoundOnEntity( projectile, "flamewall_flame_start" )
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )
			thread BeginFlameWave( projectile, 0, inflictor, attackParams, attackParams.dir, false )
		}
	}

	/* // don't know why code below will never stop creating new thermite trails
	entity inflictor = CreateOncePerTickDamageInflictorHelper( 6 )

	WeaponPrimaryAttackParams attackParams
	attackParams.pos = projectile.GetOrigin() + projectile.proj.savedOrigin
	vector fireAng = projectile.proj.savedAngles
	array<vector> vectorGroup = [AnglesToForward( < 0,fireAng.y - 90,0 > ), AnglesToForward( < 0,fireAng.y + 90,0 > )]
	foreach( int index, vector direction in vectorGroup )
	{
		attackParams.dir = vectorGroup[index]
		entity fakeProjectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, 99, damageTypes.projectileImpact, damageTypes.explosive, false, true, true )
		if ( projectile )
		{
			projectile.SetModel( $"models/dev/empty_model.mdl" )
			EmitSoundOnEntity( projectile, "flamewall_flame_start" )
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )
			thread BeginFlameWave( projectile, 0, inflictor, attackParams, true )
		}
	}

	entity inflictor = CreateOncePerTickDamageInflictorHelper( 6 )

	vector fireAng = projectile.proj.savedAngles
	array<vector> vectorGroup = [AnglesToForward( < 0,fireAng.y - 90,0 > ), AnglesToForward( < 0,fireAng.y + 90,0 > )]

	for( int i = 0; i < 2; i++ )
	{
		WeaponPrimaryAttackParams attackParams
		attackParams.pos = projectile.GetOrigin() + projectile.proj.savedOrigin
		attackParams.dir = vectorGroup[i]
		entity fakeProjectile = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, < 0,0,0 >, 99, damageTypes.projectileImpact, damageTypes.explosive, false, true, true )

		if ( fakeProjectile )
		{
			projectile.SetModel( $"models/dev/empty_model.mdl" )
			EmitSoundOnEntity( projectile, "flamewall_flame_start" )
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.5 )
			thread BeginFlameWave( projectile, 0, inflictor, attackParams, true )
		}
		
	}
	*/
}

void function ThermiteBurn( float burnTime, entity owner, entity projectile, entity vortexSphere = null )
{
	if ( !IsValid( projectile ) ) //MarkedForDeletion check
		return

	projectile.SetTakeDamageType( DAMAGE_NO )

	const vector ROTATE_FX = <90.0, 0.0, 0.0>
	entity fx = PlayFXOnEntity( THERMITE_GRENADE_FX, projectile, "", null, ROTATE_FX )
	fx.SetOwner( owner )
	fx.EndSignal( "OnDestroy" )

	if ( IsValid( vortexSphere ) )
		vortexSphere.EndSignal( "OnDestroy" )

	projectile.EndSignal( "OnDestroy" )

	int statusEffectHandle = -1
	entity attachedToEnt = projectile.GetParent()
	if ( ShouldAddThermiteStatusEffect( attachedToEnt, owner ) )
		statusEffectHandle = StatusEffect_AddEndless( attachedToEnt, eStatusEffect.thermite, 1.0 )

	OnThreadEnd(
		function() : ( projectile, fx, attachedToEnt, statusEffectHandle )
		{
			if ( IsValid( projectile ) )
				projectile.Destroy()

			if ( IsValid( fx ) )
				fx.Destroy()

			if ( IsValid( attachedToEnt) && statusEffectHandle != -1 )
				StatusEffect_Stop( attachedToEnt, statusEffectHandle )
		}
	)

	AddActiveThermiteBurn( fx )

	RadiusDamageData radiusDamage 	= GetRadiusDamageDataFromProjectile( projectile, owner )
	int damage 						= radiusDamage.explosionDamage
	int titanDamage					= radiusDamage.explosionDamageHeavyArmor
	float explosionRadius 			= radiusDamage.explosionRadius
	float explosionInnerRadius 		= radiusDamage.explosionInnerRadius
	int damageSourceId 				= projectile.ProjectileGetDamageSourceID()

	CreateNoSpawnArea( TEAM_INVALID, owner.GetTeam(), projectile.GetOrigin(), burnTime, explosionRadius )
	AI_CreateDangerousArea( fx, projectile, explosionRadius * 1.5, TEAM_INVALID, true, false )
	EmitSoundOnEntity( projectile, "explo_firestar_impact" )

	bool firstBurst = true

	float endTime = Time() + burnTime
	while ( Time() < endTime )
	{
		vector origin = projectile.GetOrigin()
		RadiusDamage(
			origin,															// origin
			owner,															// owner
			projectile,		 													// inflictor
			firstBurst ? float( damage ) * 1.2 : float( damage ),			// normal damage
			firstBurst ? float( titanDamage ) * 2.5 : float( titanDamage ),	// heavy armor damage
			explosionInnerRadius,											// inner radius
			explosionRadius,												// outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,								// explosion flags
			0, 																// distanceFromAttacker
			0, 																// explosionForce
			0,																// damage flags
			damageSourceId													// damage source id
		)
		firstBurst = false

		wait 0.2

		if ( statusEffectHandle != -1 && IsValid( attachedToEnt ) && !attachedToEnt.IsTitan() ) //Stop if thermited player Titan becomes a Pilot
		{
			StatusEffect_Stop( attachedToEnt, statusEffectHandle )
			statusEffectHandle = -1
		}
	}
}

bool function ShouldAddThermiteStatusEffect( entity attachedEnt, entity thermiteOwner )
{
	if ( !IsValid( attachedEnt ) )
		return false

	if ( !attachedEnt.IsPlayer() )
		return false

	if ( !attachedEnt.IsTitan() )
		return false

	if ( IsValid( thermiteOwner ) &&  attachedEnt.GetTeam() == thermiteOwner.GetTeam() )
		return false

	return true
}
#endif