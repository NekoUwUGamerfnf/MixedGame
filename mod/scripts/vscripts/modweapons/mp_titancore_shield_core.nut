
global function Shield_Core_Init

global function OnCoreCharge_Shield_Core
global function OnCoreChargeEnd_Shield_Core

global function OnAbilityStart_Shield_Core

const float SHIELD_CORE_REGEN_DELAY = 2.0
const int SHILED_CORE_REGEN_RATE = 150
const float SHIELD_CORE_REGEN_TICKRATE = 0.1 // 1500 shields per second
const int SHIELD_CORE_MAX_SHIELD = 4000

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

	if ( owner.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_1P" )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
		EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_3P" )
	}
	else // npc
		EmitSoundOnEntity( owner, "Titan_Legion_Smart_Core_Activated_3P" )

	entity soul = owner.GetTitanSoul()
	table storedShield = {}
	storedShield.starterShield <- soul.GetShieldHealth()
	storedShield.starterMaxShield <- soul.GetShieldHealthMax()
	soul.SetShieldHealthMax( SHIELD_CORE_MAX_SHIELD )
	soul.SetShieldHealth( SHIELD_CORE_MAX_SHIELD )
	AddEntityCallback_OnDamaged( owner, TrackShieldCoreBeingDamaged )

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
				
				RemoveEntityCallback_OnDamaged( owner, TrackShieldCoreBeingDamaged )
				if ( owner.IsPlayer() )
				{
					EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Deactivated_1P" )
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
				int orgMaxShield = expect int ( storedShield.starterMaxShield )
				soul.SetShieldHealth( min( orgMaxShield, soul.GetShieldHealth() ) )
				soul.SetShieldHealthMax( orgMaxShield )
			}
		}
	)

	float startTime = Time()
	owner.p.lastDamageTime = Time() - SHIELD_CORE_REGEN_DELAY // reset lastDamageTime, start player regen
	while( true )
	{
		if( IsValid( soul ) )
		{
			if( Time() >= startTime + coreDuration )
				break
			if ( Time() - owner.p.lastDamageTime >= SHIELD_CORE_REGEN_DELAY && !owner.ContextAction_IsActive() )
				soul.SetShieldHealth( min( soul.GetShieldHealthMax(), soul.GetShieldHealth() + SHILED_CORE_REGEN_RATE ) )
			
			wait SHIELD_CORE_REGEN_TICKRATE
		}
	}
	#endif
}

#if SERVER
void function TrackShieldCoreBeingDamaged( entity player, var damageInfo )
{
	player.p.lastDamageTime = Time()
}
#endif