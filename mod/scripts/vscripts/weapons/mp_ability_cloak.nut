global function OnWeaponPrimaryAttack_cloak

const float CLOAK_FIELD_COOLDOWN_TIME = 40

const float CLOAK_DRONE_LIFETIME = 20
const float CLOAK_DRONE_COOLDOWN_TIME = 40

var function OnWeaponPrimaryAttack_cloak( entity weapon, WeaponPrimaryAttackParams attackParams )
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

	PlayerUsedOffhand( ownerPlayer, weapon )

	bool isDeployableThrow = weapon.HasMod("cloak_field") || weapon.HasMod("cloak_drone")

	if( isDeployableThrow )
	{
		entity deployable
		if( weapon.HasMod( "cloak_field" ) )
		{
			deployable = ThrowDeployable( weapon, attackParams, DEPLOYABLE_THROW_POWER, OnDeployableCloakfieldPlanted )
			#if SERVER
			SendHudMessage(ownerPlayer, "扔出隐身力场\n特殊隐身技能进入冷却", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			thread CheckModdedCloak( weapon, "cloak_field", CLOAK_FIELD_COOLDOWN_TIME )
			#endif
		}
		else if( weapon.HasMod( "cloak_drone" ) )
		{
			entity deployable = ThrowDeployable( weapon, attackParams, DEPLOYABLE_THROW_POWER, OnCloakDroneReleased )
			#if SERVER
			SendHudMessage(ownerPlayer, "扔出隐身无人机\n特殊隐身技能进入冷却", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			thread CheckModdedCloak( weapon, "cloak_drone", CLOAK_DRONE_COOLDOWN_TIME )
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
	else
	{
		#if SERVER
		
		float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
		EnableCloak( ownerPlayer, duration )
		#if BATTLECHATTER_ENABLED
			TryPlayWeaponBattleChatterLine( ownerPlayer, weapon )
		#endif

		#endif
	}
		//ownerPlayer.Signal( "PlayerUsedAbility" )

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

void function OnDeployableCloakfieldPlanted( entity projectile )
{
	#if SERVER
	DeployCloakfield( projectile )
	#endif
}

void function OnCloakDroneReleased( entity projectile )
{
	#if SERVER
	entity drone = SpawnCloakDrone( projectile.GetTeam(), projectile.GetOrigin(), < 0,0,0 >, < 0,0,0 >, projectile.GetOwner() )
	thread AfterTimeDestroyDrone( drone, projectile.GetOwner(), CLOAK_DRONE_LIFETIME )
	projectile.GrenadeExplode( < 0,0,20 > )
	#endif
}

#if SERVER
void function CheckModdedCloak( entity weapon, string mod, float cooldown )
{
	int offhandslot = -1
	if( !weapon.HasMod( mod ) )
		return
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.EndSignal( "OnDeath" )
	weaponOwner.EndSignal( "OnDestroy" )
	foreach( entity offhand in weaponOwner.GetOffhandWeapons() )
	{
		offhandslot += 1
		if( offhandslot == OFFHAND_EQUIPMENT )
			offhandslot += 1
		if( offhand.GetWeaponClassName() == "mp_ability_cloak" )
		{

			weaponOwner.TakeWeaponNow( offhand.GetWeaponClassName() )
			break
		}
	}

	wait cooldown

	if( IsAlive(weaponOwner) && IsValid(weaponOwner) )
	{
		foreach( entity offhand in weaponOwner.GetOffhandWeapons() )
		{
			if( offhand.GetWeaponClassName() == "mp_ability_cloak" )
			{
				print( "Failed to refilled Cloakfield" )
				return
			}
		}
		if( !IsValid( weaponOwner.GetOffhandWeapon(offhandslot) ) )
		{
			SendHudMessage(weaponOwner, "特殊隐身技能冷却完毕", -1, -0.35, 255, 255, 100, 255, 0, 3, 0)
			weaponOwner.GiveOffhandWeapon( "mp_ability_cloak", offhandslot, [mod] )
		}
		else
			print( "Failed to refilled Cloakfield" )
	}
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
#endif