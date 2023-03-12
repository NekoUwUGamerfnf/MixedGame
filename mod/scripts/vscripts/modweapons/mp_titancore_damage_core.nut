global function Damage_Core_Init

global function OnCoreCharge_Damage_Core
global function OnCoreChargeEnd_Damage_Core

global function OnAbilityStart_Damage_Core

void function Damage_Core_Init()
{

}

bool function OnCoreCharge_Damage_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

	return true
}

void function OnCoreChargeEnd_Damage_Core( entity weapon )
{
#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )
#endif
}

var function OnAbilityStart_Damage_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( !owner.IsTitan() )
		return 0
	entity soul = owner.GetTitanSoul()
	#if SERVER
	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	thread DamageCoreThink( weapon, duration )

	OnAbilityStart_TitanCore( weapon )
	#endif

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
	owner.EndSignal( "OnSyncedMeleeVictim" )

	if( !owner.IsTitan() )
		return

	if ( owner.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_1P" )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
		EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_3P" )
	}
	else // npc
		EmitSoundOnEntity( owner, "Titan_Legion_Smart_Core_Activated_3P" )

	entity soul = owner.GetTitanSoul()
	int statusEffect = StatusEffect_AddEndless( soul, eStatusEffect.titan_damage_amp, 0.5 )
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
				
				if ( owner.IsPlayer() )
				{
					EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Deactivated_1P" )
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