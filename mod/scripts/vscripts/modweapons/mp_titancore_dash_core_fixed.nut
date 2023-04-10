global function Dash_Core_Fixed_Init

global function OnCoreCharge_Dash_Core
global function OnCoreChargeEnd_Dash_Core

global function OnAbilityStart_Dash_Core

void function Dash_Core_Fixed_Init()
{

}

bool function OnCoreCharge_Dash_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

	#if SERVER
	entity owner = weapon.GetWeaponOwner()
	#endif

	return true
}

void function OnCoreChargeEnd_Dash_Core( entity weapon )
{
#if SERVER
	OnAbilityChargeEnd_TitanCore( weapon )

	entity owner = weapon.GetWeaponOwner()
#endif
}

var function OnAbilityStart_Dash_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    entity owner = weapon.GetWeaponOwner()
    if ( !owner.IsTitan() )
        return 0
    entity soul = owner.GetTitanSoul()
    #if SERVER
		float duration = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
		thread DashCoreThink( weapon, duration )

		OnAbilityStart_TitanCore( weapon )
		// since this dash core is a mod of mp_titancore_shift_core, we take off PAS_SHIFT_CORE given by OnAbilityStart_TitanCore()
		if ( IsValid( soul ) )
			TakePassive( soul, ePassives.PAS_SHIFT_CORE )
		if ( owner.IsPlayer() )
		{
			//TakePassive( owner, ePassives.PAS_FUSION_CORE ) // player also get a PAS_FUSION_CORE from script
			TakePassive( owner, ePassives.PAS_SHIFT_CORE )
		}
    #endif

	return 1
}

void function DashCoreThink( entity weapon, float coreDuration )
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

	table savedData = {}
	savedData.aiSettings <- ""

	if ( owner.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_1P" )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
		EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_3P" )
	}
	else // npc
	{
		EmitSoundOnEntity( owner, "Titan_Legion_Smart_Core_Activated_3P" )
		savedData.aiSettings = owner.GetAISettingsName()
		owner.SetAISettings( "npc_titan_stryder_rocketeer_dash_core" )
		owner.EnableNPCMoveFlag( NPCMF_PREFER_SPRINT )
		owner.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
	}

	entity soul = owner.GetTitanSoul()
	if ( owner.IsPlayer() )
	{
		owner.Server_SetDodgePower( 100.0 )
		owner.SetPowerRegenRateScale( 8.0 ) // sword core is 6.5
		owner.SetDodgePowerDelayScale( 0.8 )

		if ( weapon.HasMod( "ttf1_dash_core" ) ) // specific
		{
			owner.SetPowerRegenRateScale( 16.0 )
			owner.SetDodgePowerDelayScale( 0.1 )
		}
	}
	if ( owner.IsPlayer() )
	{
		ScreenFade( owner, 0, 0, 100, 10, 0.1, coreDuration, FFADE_OUT | FFADE_PURGE )
	}

	OnThreadEnd(
	function() : ( weapon, soul, owner, savedData )
		{
			if ( IsValid( owner ) )
			{
				StopSoundOnEntity( owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )

				if ( owner.IsPlayer() )
				{
					EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Deactivated_1P" )
					// clearn up
					ScreenFade( owner, 0, 0, 0, 0, 0.1, 0.1, FFADE_OUT | FFADE_PURGE )
					owner.SetPowerRegenRateScale( 1.0 )
		            owner.SetDodgePowerDelayScale( 1.0 )
				}
				else // npc
				{
					if ( savedData.aiSettings != "" )
						owner.SetAISettings( expect string( savedData.aiSettings ) )
					owner.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
					owner.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, true )
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
			}
		}
	)

	wait coreDuration
	#endif
}