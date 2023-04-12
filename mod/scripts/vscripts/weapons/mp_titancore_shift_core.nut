global function OnWeaponPrimaryAttack_DoNothing

global function Shift_Core_Init
#if SERVER
global function Shift_Core_UseMeter
#endif

global function OnCoreCharge_Shift_Core
global function OnCoreChargeEnd_Shift_Core
global function OnAbilityStart_Shift_Core

// modified: weapon store system, so we can use sword core with no melee_titan_sword
#if SERVER
struct ShiftCoreSavedMelee
{
	string meleeName
	array<string> meleeMods
}

struct
{
	table<entity, ShiftCoreSavedMelee> soulShiftCoreSavedMelee
	table<entity, string> npcShiftCoreSavedAiSet
} file
#endif
//

void function Shift_Core_Init()
{
	RegisterSignal( "RestoreWeapon" )
	#if SERVER
	AddCallback_OnPlayerKilled( SwordCore_OnPlayedOrNPCKilled )
	AddCallback_OnNPCKilled( SwordCore_OnPlayedOrNPCKilled )
	#endif
}

#if SERVER
void function SwordCore_OnPlayedOrNPCKilled( entity victim, entity attacker, var damageInfo )
{
	if ( !victim.IsTitan() )
		return

	if ( !attacker.IsPlayer() || !PlayerHasPassive( attacker, ePassives.PAS_SHIFT_CORE ) )
		return

	entity soul = attacker.GetTitanSoul()
	//if ( !IsValid( soul ) || !SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
	if ( !IsValid( soul ) )
		return

	bool hasPasSwordCore = false
	foreach( entity offhand in attacker.GetOffhandWeapons() )
	{
		if( offhand.GetWeaponClassName() == "mp_titancore_shift_core" )
		{
			if( offhand.HasMod( "pas_ronin_sword_core" ) )
				hasPasSwordCore = true
		}
	}
	if( SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
		hasPasSwordCore = true
	
	if( !hasPasSwordCore )
		return

	float curTime = Time()
	float highlanderBonus = 8.0
	float remainingTime = highlanderBonus + soul.GetCoreChargeExpireTime() - curTime
	float duration = soul.GetCoreUseDuration()
	float coreFrac = min( 1.0, remainingTime / duration )
	//Defensive fix for this sometimes resulting in a negative value.
	if ( coreFrac > 0.0 )
	{
		soul.SetTitanSoulNetFloat( "coreExpireFrac", coreFrac )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
	}
}
#endif

var function OnWeaponPrimaryAttack_DoNothing( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}

bool function OnCoreCharge_Shift_Core( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "dash_core" ) )
		return OnCoreCharge_Dash_Core( weapon )
	if ( weapon.HasMod( "berserker_core" ) )
		return OnCoreCharge_Berserker_Core( weapon )
	//

	// vanilla behavior
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

#if SERVER
	entity owner = weapon.GetWeaponOwner()
	string swordCoreSound_1p
	string swordCoreSound_3p
	if ( weapon.HasMod( "fd_duration" ) )
	{
		swordCoreSound_1p = "Titan_Ronin_Sword_Core_Activated_Upgraded_1P"
		swordCoreSound_3p = "Titan_Ronin_Sword_Core_Activated_Upgraded_3P"
	}
	else
	{
		swordCoreSound_1p = "Titan_Ronin_Sword_Core_Activated_1P"
		swordCoreSound_3p = "Titan_Ronin_Sword_Core_Activated_3P"
	}
	if ( owner.IsPlayer() )
	{
		owner.HolsterWeapon() //TODO: Look into rewriting this so it works with HolsterAndDisableWeapons()
		thread RestoreWeapon( owner, weapon )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, swordCoreSound_1p )
		EmitSoundOnEntityExceptToPlayer( owner, owner, swordCoreSound_3p )
	}
	else
	{
		EmitSoundOnEntity( weapon, swordCoreSound_3p )
	}
#endif

	return true
}

void function OnCoreChargeEnd_Shift_Core( entity weapon )
{
	// modded weapon
	if ( weapon.HasMod( "dash_core" ) )
		return OnCoreChargeEnd_Dash_Core( weapon )
	if ( weapon.HasMod( "berserker_core" ) )
		return OnCoreChargeEnd_Berserker_Core( weapon )
	//

	// vanilla behavior	
	#if SERVER
	entity owner = weapon.GetWeaponOwner()
	OnAbilityChargeEnd_TitanCore( weapon )
	if ( IsValid( owner ) && owner.IsPlayer() )
		owner.DeployWeapon() //TODO: Look into rewriting this so it works with HolsterAndDisableWeapons()
	else if ( !IsValid( owner ) )
		Signal( weapon, "RestoreWeapon" )
	#endif
}

#if SERVER
void function RestoreWeapon( entity owner, entity weapon )
{
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "CoreBegin" )

	WaitSignal( weapon, "RestoreWeapon", "OnDestroy" )

	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		owner.DeployWeapon() //TODO: Look into rewriting this so it works with DeployAndEnableWeapons()
	}
}
#endif

var function OnAbilityStart_Shift_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if ( weapon.HasMod( "dash_core" ) )
		return OnAbilityStart_Dash_Core( weapon, attackParams )
	if ( weapon.HasMod( "berserker_core" ) )
		return OnAbilityStart_Berserker_Core( weapon, attackParams )
	//

	// vanilla behavior
	OnAbilityStart_TitanCore( weapon )

	entity owner = weapon.GetWeaponOwner()

	if ( !owner.IsTitan() )
		return 0

	if ( !IsValid( owner ) )
		return

	/* // modified: weapon store system, so we can use sword core with no melee_titan_sword
	entity offhandWeapon = owner.GetOffhandWeapon( OFFHAND_MELEE )

	if ( !IsValid( offhandWeapon ) )
		return 0

	if ( offhandWeapon.GetWeaponClassName() != "melee_titan_sword" )
		return 0
	*/

#if SERVER
	if ( owner.IsPlayer() )
	{
		owner.Server_SetDodgePower( 100.0 )
		owner.SetPowerRegenRateScale( 6.5 )
		GivePassive( owner, ePassives.PAS_FUSION_CORE )
		GivePassive( owner, ePassives.PAS_SHIFT_CORE )
	}

	entity soul = owner.GetTitanSoul() // moved up

	// modified: weapon store system, so we can use sword core with no melee_titan_sword
	entity meleeWeapon = owner.GetOffhandWeapon( OFFHAND_MELEE )
	if ( IsValid( meleeWeapon ) )
	{
		// if we're not having sword, save current melee weapon and give melee_titan_sword
		if ( meleeWeapon.GetWeaponClassName() != "melee_titan_sword" )
		{
			ShiftCoreSavedMelee meleeStruct
			meleeStruct.meleeName = meleeWeapon.GetWeaponClassName()
			meleeStruct.meleeMods = meleeWeapon.GetMods()
			file.soulShiftCoreSavedMelee[ soul ] <- meleeStruct
			owner.TakeOffhandWeapon( OFFHAND_MELEE )

			// prime sword check
			TitanLoadoutDef loadout = soul.soul.titanLoadout
			array<string> mods = []
			if ( loadout.isPrime == "titan_is_prime" )
				mods.append( "modelset_prime" )
			owner.GiveOffhandWeapon( "melee_titan_sword", OFFHAND_MELEE, mods )
		}
	}
	//

	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		if ( titan.IsNPC() )
		{
			file.npcShiftCoreSavedAiSet[ titan ] <- titan.GetAISettingsName() // save aiset
			titan.SetAISettings( "npc_titan_stryder_leadwall_shift_core" )
			titan.EnableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
			AddAnimEvent( titan, "shift_core_use_meter", Shift_Core_UseMeter_NPC )
		}

		titan.GetOffhandWeapon( OFFHAND_MELEE ).AddMod( "super_charged" )

		if ( IsSingleplayer() )
		{
			titan.GetOffhandWeapon( OFFHAND_MELEE ).AddMod( "super_charged_SP" )
		}
		
		// pullout animation, respawn messed this up, but makes sword core has less startup
		if ( weapon.HasMod( "deploy_animation_fix" ) )
		{
			if ( owner.IsPlayer() )
				owner.HolsterWeapon() // to have deploy animation
		}

		titan.SetActiveWeaponByName( "melee_titan_sword" )
		
		// pullout animation
		if ( weapon.HasMod( "deploy_animation_fix" ) )
		{
			if ( owner.IsPlayer() )
				owner.DeployWeapon() // to have deploy animation
		}
		
		// reworked here: supporting multiple main weapon titans
		foreach( entity mainWeapon in titan.GetMainWeapons() )
			mainWeapon.AllowUse( false )
		//entity mainWeapon = titan.GetMainWeapons()[0]
		//mainWeapon.AllowUse( false )
	}

	float delay = weapon.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
	thread Shift_Core_End( weapon, owner, delay )
#endif

	return 1
}

#if SERVER
void function Shift_Core_End( entity weapon, entity player, float delay )
{
	weapon.EndSignal( "OnDestroy" )

	if ( player.IsNPC() && !IsAlive( player ) )
		return

	player.EndSignal( "OnDestroy" )
	if ( IsAlive( player ) )
		player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )
	player.EndSignal( "OnSyncedMelee" )
	player.EndSignal( "InventoryChanged" )

	OnThreadEnd(
	function() : ( weapon, player )
		{
			OnAbilityEnd_Shift_Core( weapon, player )

			if ( IsValid( player ) )
			{
				entity soul = player.GetTitanSoul()
				if ( soul != null )
					CleanupCoreEffect( soul )
			}
		}
	)

	entity soul = player.GetTitanSoul()
	if ( soul == null )
		return

	while ( 1 )
	{
		if ( soul.GetCoreChargeExpireTime() <= Time() )
			break;
		wait 0.1
	}
}

void function OnAbilityEnd_Shift_Core( entity weapon, entity player )
{
	OnAbilityEnd_TitanCore( weapon )

	if ( player.IsPlayer() )
	{
		player.SetPowerRegenRateScale( 1.0 )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_1P" )
		EmitSoundOnEntityExceptToPlayer( player, player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
		int conversationID = GetConversationIndex( "swordCoreOffline" )
		Remote_CallFunction_Replay( player, "ServerCallback_PlayTitanConversation", conversationID )
	}
	else
	{
		DeleteAnimEvent( player, "shift_core_use_meter" )
		EmitSoundOnEntity( player, "Titan_Ronin_Sword_Core_Deactivated_3P" )
	}

	RestorePlayerWeapons( player )
}

void function RestorePlayerWeapons( entity player )
{
	if ( !IsValid( player ) )
		return

	if ( player.IsNPC() && !IsAlive( player ) )
		return // no need to fix up dead NPCs

	entity soul = player.GetTitanSoul()

	if ( player.IsPlayer() )
	{
		TakePassive( player, ePassives.PAS_FUSION_CORE )
		TakePassive( player, ePassives.PAS_SHIFT_CORE )

		soul = GetSoulFromPlayer( player )
	}

	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		entity meleeWeapon = titan.GetOffhandWeapon( OFFHAND_MELEE )
		if ( IsValid( meleeWeapon ) )
		{
			meleeWeapon.RemoveMod( "super_charged" )
			if ( IsSingleplayer() )
			{
				meleeWeapon.RemoveMod( "super_charged_SP" )
			}
		}

		// modified: weapon store system, so we can use sword core with no melee_titan_sword
		if ( soul in file.soulShiftCoreSavedMelee ) // do saved another melee?
		{
			titan.TakeOffhandWeapon( OFFHAND_MELEE ) // take of sword
			// restore melee
			ShiftCoreSavedMelee savedMelee = file.soulShiftCoreSavedMelee[ soul ]
			titan.GiveOffhandWeapon( savedMelee.meleeName, OFFHAND_MELEE, savedMelee.meleeMods )
			delete file.soulShiftCoreSavedMelee[ soul ]
		}
		
		// reworked here: supporting multiple main weapon titans
		foreach( entity mainWeapon in titan.GetMainWeapons() )
			mainWeapon.AllowUse( true )
		//array<entity> mainWeapons = titan.GetMainWeapons()
		//if ( mainWeapons.len() > 0 )
		//{
		//	entity mainWeapon = titan.GetMainWeapons()[0]
		//	mainWeapon.AllowUse( true )
		//}

		if ( titan.IsNPC() )
		{
			string settings = GetSpawnAISettings( titan )
			// modified: use saved aiset
			if ( titan in file.npcShiftCoreSavedAiSet )
			{
				settings = file.npcShiftCoreSavedAiSet[ titan ]
				delete file.npcShiftCoreSavedAiSet[ titan ]
			}
			//
			if ( settings != "" )
				titan.SetAISettings( settings )

			titan.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, true )
		}
	}
}

void function Shift_Core_UseMeter( entity player )
{
	if ( IsMultiplayer() )
		return

	entity soul = player.GetTitanSoul()
	float curTime = Time()
	float remainingTime = soul.GetCoreChargeExpireTime() - curTime

	if ( remainingTime > 0 )
	{
		const float USE_TIME = 5

		remainingTime = max( remainingTime - USE_TIME, 0 )
		float startTime = soul.GetCoreChargeStartTime()
		float duration = soul.GetCoreUseDuration()

		soul.SetTitanSoulNetFloat( "coreExpireFrac", remainingTime / duration )
		soul.SetTitanSoulNetFloatOverTime( "coreExpireFrac", 0.0, remainingTime )
		soul.SetCoreChargeExpireTime( remainingTime + curTime )
	}
}

void function Shift_Core_UseMeter_NPC( entity npc )
{
	Shift_Core_UseMeter( npc )
}
#endif