
global function Shield_Core_Init

global function OnCoreCharge_Shield_Core
global function OnCoreChargeEnd_Shield_Core

global function OnAbilityStart_Shield_Core

const FX_AMPED_XO16_3P = $"P_wpn_lasercannon_aim"
const FX_AMPED_XO16 = $"P_wpn_lasercannon_aim"

void function Shield_Core_Init()
{

}

bool function OnCoreCharge_Shield_Core( entity weapon )
{
	if( !weapon.HasMod( "shield_core" ) )
		return false
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

	return true
}

void function OnCoreChargeEnd_Shield_Core( entity weapon )
{
	if( !weapon.HasMod( "shield_core" ) )
		return
#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )
#endif
}

var function OnAbilityStart_Shield_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( !owner.IsTitan() )
		return 0
	entity soul = owner.GetTitanSoul()
	#if SERVER
	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	thread ShieldCoreThink( weapon, duration )

	OnAbilityStart_TitanCore( weapon )
	#endif

	return 1
}

void function ShieldCoreThink( entity weapon, float coreDuration )
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
	int storedShield = soul.GetShieldHealth()

	if ( owner.IsPlayer() )
	{
		ScreenFade( owner, 100, 100, 0, 10, 0.1, coreDuration, FFADE_OUT | FFADE_PURGE )
	}

	OnThreadEnd(
	function() : ( weapon, soul, owner, storedShield )
		{
			if ( IsValid( owner ) )
			{
				StopSoundOnEntity( owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
				EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Deactivated_1P" )
				if ( owner.IsPlayer() )
				{
					ScreenFade( owner, 0, 0, 0, 0, 0.1, 0.1, FFADE_OUT | FFADE_PURGE )
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
				soul.SetShieldHealth( storedShield )
			}
		}
	)

	float startTime = Time()
	while( true )
	{
		if( IsValid( soul ) )
		{
			wait 0.1
			if( Time() >= startTime + coreDuration )
				break
			if( soul.GetShieldHealth() >= soul.GetShieldHealthMax() )
			{
				soul.SetShieldHealth( soul.GetShieldHealthMax() )
				continue
			}
			soul.SetShieldHealth( soul.GetShieldHealth() + 250 )
		}
	}
	#endif
}