untyped
#if SERVER
global function ThermiteBurn
global const float THERMITE_GRENADE_BURN_TIME = 6.0
global const float THERMITE_TRAIL_SOUND_TIME = 2.0

// bleedout balance
const float BLEEDOUT_BURN_TIME = 3.0 // halfed normal duration
const float BLEEDOUT_STICK_BURN_TIME = 1.0 // sticked firestar will have less duration.
#endif

global function OnWeaponTossReleaseAnimEvent_weapon_thermite_grenade

global function OnProjectileCollision_weapon_thermite_grenade
global function OnProjectileIgnite_weapon_thermite_grenade

var function OnWeaponTossReleaseAnimEvent_weapon_thermite_grenade( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( weapon.HasMod( "flamewall_grenade" ) )
		return OnWeaponTossReleaseAnimEvent_weapon_flamewall_grenade( weapon, attackParams )

	entity grenade = Grenade_OnWeaponToss_ReturnEntity( weapon, attackParams )
	if( !IsValid( grenade ) )
		return
	if( weapon.HasMod( "meteor_grenade" ) )
	{
		grenade.SetModel( $"models/weapons/bullets/triple_threat_projectile.mdl" )
		#if SERVER
			grenade.ProjectileSetDamageSourceID( eDamageSourceId.mp_titanweapon_meteor ) // better damageSource
		#endif
	}

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function OnProjectileCollision_weapon_thermite_grenade( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded weapon
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if ( mods.contains( "flamewall_grenade" ) )
		return OnProjectileCollision_weapon_flamewall_grenade( projectile, pos, normal, hitEnt, hitbox, isCritical )
	if( mods.contains( "ninja_projectile" ) )
		return OnProjectileCollision_ninja_projectile( projectile, pos, normal, hitEnt, hitbox, isCritical )
	
	// vanilla behavior
	entity player = projectile.GetOwner()

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


	bool result = PlantStickyEntity( projectile, collisionParams )
	if( hitEnt.IsPlayer() )
	{
		#if SERVER
		if( mods.contains( "bleedout_balance" ) && !mods.contains( "thermite_grenade_dot" ) ) // only apply to normal firestars
			thread EarlyExtinguishFireStar( projectile, BLEEDOUT_STICK_BURN_TIME )
		#endif
	}

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
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if ( mods.contains( "flamewall_grenade" ) )
		return OnProjectileIgnite_weapon_flamewall_grenade( projectile )
	if( mods.contains( "ninja_projectile" ) )
		return // ninja projectile shouldn't have any ignition effect

	projectile.SetDoesExplode( false )

	#if SERVER
		projectile.proj.onlyAllowSmartPistolDamage = false

		entity player = projectile.GetOwner()

		if ( !IsValid( player ) )
		{
			projectile.Destroy()
			return
		}

		// modified to add bleedout balance
		//thread ThermiteBurn( THERMITE_GRENADE_BURN_TIME, player, projectile )
		float burnTime = THERMITE_GRENADE_BURN_TIME
		if ( mods.contains( "bleedout_balance" ) )
			burnTime = BLEEDOUT_BURN_TIME
		thread ThermiteBurn( burnTime, player, projectile )

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

void function EarlyExtinguishFireStar( entity projectile, float duration )
{
	wait duration
	if( IsValid( projectile ) )
		projectile.Destroy()
}
#endif