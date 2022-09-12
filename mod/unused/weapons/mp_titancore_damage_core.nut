global function Damage_Core_Init

global function OnCoreCharge_Damage_Core
global function OnCoreChargeEnd_Damage_Core

global function OnAbilityStart_Damage_Core

const FX_AMPED_XO16_3P = $"P_wpn_lasercannon_aim"
const FX_AMPED_XO16 = $"P_wpn_lasercannon_aim"

void function Damage_Core_Init()
{
	#if SERVER
	//AddCallback_OnClientDisconnected( GiveAttackBack )
	#endif
}

/*
#if SERVER
void function GiveAttackBack( entity player )
{
	ClientCommand( player, "-attack" )
}
#endif
*/

bool function OnCoreCharge_Damage_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

	#if SERVER
	entity owner = weapon.GetWeaponOwner()

	/*
	if ( owner.IsPlayer() )
	{
		owner.Signal( "KillBruteShield" )
		owner.HolsterWeapon()
	}
	*/
	#endif

	return true
}

void function OnCoreChargeEnd_Damage_Core( entity weapon )
{
#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )

	entity owner = weapon.GetWeaponOwner()

	/*
	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		owner.Signal( "KillBruteShield" )
		owner.DeployWeapon()
	}
	*/
#endif
}

var function OnAbilityStart_Damage_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	/* //we don't need a burst core anymore
	if( weapon.HasMod( "burst_core" ) )
	{
		entity owner = weapon.GetWeaponOwner()

		if( owner.GetMainWeapons().len() > 0 )
		{
			entity storedweapon = owner.GetMainWeapons()[0]
			thread BurstCoreThink( weapon, storedweapon )
		}
		OnAbilityStart_TitanCore( weapon )
	}
	else
	{
	*/
		entity owner = weapon.GetWeaponOwner()
		if ( !owner.IsTitan() )
			return 0
	    entity soul = owner.GetTitanSoul()
		#if SERVER
		float duration = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
		thread DamageCoreThink( weapon, duration )

		OnAbilityStart_TitanCore( weapon )
		#endif
	//}

	return 1
}

void function DamageCoreThink( entity weapon, float coreDuration )
{
	#if SERVER
	weapon.EndSignal( "OnDestroy" )
	entity owner = weapon.GetWeaponOwner()
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "DisembarkingTitan" )
	owner.EndSignal( "TitanEjectionStarted" )

	if( !owner.IsTitan() )
		return

	EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_1P" )
	EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
	EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_3P" )

	entity soul = owner.GetTitanSoul()
	int statusEffect = StatusEffect_AddEndless( soul, eStatusEffect.titan_damage_amp, 0.35 )
	if ( owner.IsPlayer() )
	{
		ScreenFade( owner, 100, 0, 0, 10, 0.1, coreDuration, FFADE_OUT | FFADE_PURGE )
	}

	OnThreadEnd(
	function() : ( weapon, soul, owner, statusEffect )
		{
			if ( IsValid( owner ) )
			{
				StopSoundOnEntity( owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
				EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Deactivated_1P" )
				if ( owner.IsPlayer() )
				{
					ScreenFade( owner, 0, 0, 0, 0, 0.1, 0.1, FFADE_OUT | FFADE_PURGE )
					StatusEffect_Stop( owner, statusEffect )
				}
			}

			if ( IsValid( weapon ) )
			{
				if ( IsValid( owner ) )
					CoreDeactivate( owner, weapon )
				OnAbilityEnd_TitanCore( weapon )
			}

			if ( IsValid( soul ) )
			{
				CleanupCoreEffect( soul )
				StatusEffect_Stop( soul, statusEffect )
			}
		}
	)

	wait coreDuration
	#endif
}

/*
void function BurstCoreThink( entity coreweapon, entity storedweapon )
{
	#if SERVER
	coreweapon.EndSignal( "OnDestroy" )
	entity owner = storedweapon.GetWeaponOwner()
	entity soul = owner.GetTitanSoul()
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )
	//owner.EndSignal( "DisembarkingTitan" )
	owner.EndSignal( "TitanEjectionStarted" )
	string weaponname = storedweapon.GetWeaponClassName()
	array<string> mods = storedweapon.GetMods()

	owner.TakeWeaponNow( owner.GetMainWeapons()[0].GetWeaponClassName() )
	owner.GiveWeapon( "mp_titanweapon_xo16_vanguard", ["burst_core", "arc_rounds"] )
	owner.SetActiveWeaponByName( "mp_titanweapon_xo16_vanguard" )
	DisableOffhandWeapons( owner )
	entity activeweapon = owner.GetActiveWeapon()
	activeweapon.SetWeaponPrimaryClipCount( 0 )
	EmitSoundOnEntityOnlyToPlayer( activeweapon, owner, "Weapon_Predator_MotorLoop_1P" )
	EmitSoundOnEntityOnlyToPlayer( activeweapon, owner, "Weapon_Predator_Windup_1P" )
	EmitSoundOnEntityExceptToPlayer( activeweapon, owner, "Weapon_Predator_MotorLoop_3P")
	EmitSoundOnEntityExceptToPlayer( activeweapon, owner, "Weapon_Predator_Windup_3P")
	
	array<int> statusEffects = []
	statusEffects.append( StatusEffect_AddEndless( soul, eStatusEffect.turn_slow, 0.25 ) )
	statusEffects.append( StatusEffect_AddEndless( soul, eStatusEffect.move_slow, 0.4 ) )
	wait 1.85

	if( IsValid( owner ) && IsAlive( owner ) )
	{
		int ownerindex
		foreach( entity player in GetPlayerArray() )
		{
			if( player == owner )
				break
			else
				ownerindex++
		}
		foreach( entity player in GetPlayerArray() )
			ClientCommand( player, "script_client GetPlayerArray()[" + string(ownerindex) + "].GetActiveWeapon().PlayWeaponEffect( $\"P_wpn_lasercannon_aim\", $\"P_wpn_lasercannon_aim\", \"fx_laser\" )" )
		ClientCommand( owner, "+attack" )
	}
	wait 0.1
	if( IsValid( owner ) )
		ClientCommand( owner, "-attack" )

	OnThreadEnd(
		function(): ( owner, coreweapon, statusEffects, soul, weaponname, mods )
		{
			if( IsValid( owner ) )
			{
				if( IsValid( owner ) )
				{
					EnableOffhandWeapons( owner )
					if( IsValid( soul ) )
					{
						foreach( int effect in statusEffects )
							StatusEffect_Stop( soul, effect )
					}
					if( IsValid( coreweapon ) )
					{
						OnAbilityEnd_TitanCore( coreweapon )
						entity activeweapon = owner.GetActiveWeapon()
						if( IsValid( activeweapon ) )
						{
							int ownerindex
							foreach( entity player in GetPlayerArray() )
							{
								if( player == owner )
									break
								else
									ownerindex++
							}
							foreach( entity player in GetPlayerArray() )
								ClientCommand( player, "script_client GetPlayerArray()[" + string(ownerindex) + "].GetActiveWeapon().StopWeaponEffect( $\"P_wpn_lasercannon_aim\", $\"P_wpn_lasercannon_aim\" )" )
							StopSoundOnEntity( activeweapon, "Weapon_Predator_MotorLoop_1P" )
							StopSoundOnEntity( activeweapon, "Weapon_Predator_MotorLoop_3P" )
							StopSoundOnEntity( activeweapon, "Weapon_Predator_Windup_1P" )
							StopSoundOnEntity( activeweapon, "Weapon_Predator_Windup_3P" )
						}
					}
					if( IsPilot( owner ) )
					{
						entity titan = owner.GetPetTitan()
						titan.TakeWeaponNow( "mp_titanweapon_xo16_vanguard" )
						titan.GiveWeapon( weaponname, mods )
					}
					else
					{
						owner.TakeWeaponNow( "mp_titanweapon_xo16_vanguard" )
						owner.GiveWeapon( weaponname, mods )
					}
				}
			}
		}
	)

	wait 5.4
	#endif
}
*/