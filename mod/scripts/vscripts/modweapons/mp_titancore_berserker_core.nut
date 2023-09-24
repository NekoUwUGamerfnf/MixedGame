global function Berserker_Core_Init

global function OnCoreCharge_Berserker_Core
global function OnCoreChargeEnd_Berserker_Core
global function OnAbilityStart_Berserker_Core

#if SERVER
struct BerserkerCoreSavedMelee
{
	string meleeName
	array<string> meleeMods
}

struct
{
	table<entity, BerserkerCoreSavedMelee> soulBerserkerCoreSavedMelee
	table<entity, string> npcBerserkerCoreSavedAiSet
} file
#endif

const string BERSERKER_CORE_MELEE_MOD_NAME = "berserker_core_punch"

void function Berserker_Core_Init()
{
	#if SERVER
		// adding a new damageSourceId. it's gonna transfer to client automatically
		RegisterWeaponDamageSource( "mp_titancore_berserker_core", "Berserker Core" )
		// modified function in sh_melee_titan, other players can't counter berserker core's melee
		TitanMelee_AddCounterImmuneMod( BERSERKER_CORE_MELEE_MOD_NAME )
		TitanMelee_AddDamageSourceIdMod( BERSERKER_CORE_MELEE_MOD_NAME, eDamageSourceId.mp_titancore_berserker_core )
	#endif
}

bool function OnCoreCharge_Berserker_Core( entity weapon )
{
	if ( !OnAbilityCharge_TitanCore( weapon ) )
		return false

#if SERVER
	entity owner = weapon.GetWeaponOwner()

	if ( owner.IsPlayer() )
	{
		owner.HolsterWeapon() //TODO: Look into rewriting this so it works with HolsterAndDisableWeapons()
		thread RestoreWeapon( owner, weapon )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_1P" )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
		EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Legion_Smart_Core_Activated_3P" )
	}
	else
	{
		EmitSoundOnEntity( owner, "Titan_Legion_Smart_Core_Activated_3P" )
	}
#endif

	return true
}

void function OnCoreChargeEnd_Berserker_Core( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "dash_core" ) )
		return OnCoreChargeEnd_Dash_Core( weapon )
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

var function OnAbilityStart_Berserker_Core( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()

	if ( !owner.IsTitan() )
		return 0

	if ( !IsValid( owner ) )
		return

	OnAbilityStart_TitanCore( weapon )
	
	entity soul = owner.GetTitanSoul()
#if SERVER
	// since this core is a mod of mp_titancore_shift_core, we take off PAS_SHIFT_CORE given by OnAbilityStart_TitanCore()
	if ( IsValid( soul ) )
	{
		TakePassive( soul, ePassives.PAS_SHIFT_CORE )
		GivePassive( soul, ePassives.PAS_BERSERKER ) // soul can't be given passive through CoreBegin(), so give manually
	}
	if ( owner.IsPlayer() )
	{
		//TakePassive( owner, ePassives.PAS_FUSION_CORE ) // player also get a PAS_FUSION_CORE from script
		TakePassive( owner, ePassives.PAS_SHIFT_CORE )
	}

	SetCoreEffect( owner, CreateCoreEffect, $"P_lasercannon_core" ) // laser core effect

	// save current melee weapon
	entity meleeWeapon = owner.GetOffhandWeapon( OFFHAND_MELEE )
	if ( IsValid( meleeWeapon ) )
	{
		BerserkerCoreSavedMelee meleeStruct
		meleeStruct.meleeName = meleeWeapon.GetWeaponClassName()
		meleeStruct.meleeMods = meleeWeapon.GetMods()
		file.soulBerserkerCoreSavedMelee[ soul ] <- meleeStruct
	}

	if ( owner.IsPlayer() )
	{
		owner.Server_SetDodgePower( 100.0 )
		owner.SetPowerRegenRateScale( 7.0 )
		owner.SetDodgePowerDelayScale( 0.5 )
		GivePassive( owner, ePassives.PAS_FUSION_CORE )
		GivePassive( owner, ePassives.PAS_BERSERKER )
	}

	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		if ( titan.IsNPC() )
		{
			file.npcBerserkerCoreSavedAiSet[ titan ] <- titan.GetAISettingsName() // save aiset
			titan.SetAISettings( "npc_titan_ogre_fighter_berserker_core" )
			titan.EnableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, false )
		}

		// core melee, only "melee_titan_punch_fighter" has deployed animations
		titan.TakeOffhandWeapon( OFFHAND_MELEE )
		titan.GiveOffhandWeapon( "melee_titan_punch_fighter", OFFHAND_MELEE, ["allow_as_primary", "dash_punch", "berserker", "berserker_core_punch"] )
		entity meleeWeapon = titan.GetOffhandWeapon( OFFHAND_MELEE )

		// pullout animation, respawn messed this up, but makes core has less startup
		// removed doAnimationFix check, since we gave player a new meleeWeapon
		// if player is sprinting while activating the core, they will have to wait the weapon pull out before first attack
		if ( owner.IsPlayer() )
			owner.HolsterWeapon() // to have deploy animation

		titan.SetActiveWeaponByName( "melee_titan_punch_fighter" )
		
		// pullout animation
		if ( owner.IsPlayer() )
			owner.DeployWeapon() // to have deploy animation
		// removing animation makes titan blanking melee
		//meleeWeapon.AddMod( "berserker_instant_deploy" ) // add instant deploy for we switch back to fist when player try to switch weapon
		meleeWeapon.AddMod( "berserker_fast_deploy" ) // using this now

		// HACK fix: looping to limit player's weapon
		thread BerserkerCoreLimitedWeapon( owner )

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

	StopSoundOnEntity( player, "Titan_Legion_Smart_Core_ActiveLoop_1P" )
	if ( player.IsPlayer() )
	{
		player.SetPowerRegenRateScale( 1.0 )
		player.SetDodgePowerDelayScale( 1.0 )
		EmitSoundOnEntityOnlyToPlayer( player, player, "Titan_Legion_Smart_Core_Deactivated_1P" )
		int conversationID = GetConversationIndex( "swordCoreOffline" )
		Remote_CallFunction_Replay( player, "ServerCallback_PlayTitanConversation", conversationID )
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
		TakePassive( player, ePassives.PAS_BERSERKER )

		soul = GetSoulFromPlayer( player )
	}

	if ( soul != null )
	{
		entity titan = soul.GetTitan()

		// restore passive
		TakePassive( soul, ePassives.PAS_BERSERKER )

		// restore melee
		titan.TakeOffhandWeapon( OFFHAND_MELEE )
		if ( soul in file.soulBerserkerCoreSavedMelee )
		{
			BerserkerCoreSavedMelee savedMelee = file.soulBerserkerCoreSavedMelee[ soul ]
			titan.GiveOffhandWeapon( savedMelee.meleeName, OFFHAND_MELEE, savedMelee.meleeMods )
			delete file.soulBerserkerCoreSavedMelee[ soul ]
		}
		
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
			if ( titan in file.npcBerserkerCoreSavedAiSet )
			{
				settings = file.npcBerserkerCoreSavedAiSet[ titan ]
				delete file.npcBerserkerCoreSavedAiSet[ titan ]
			}
			if ( settings != "" )
				titan.SetAISettings( settings )

			titan.DisableNPCMoveFlag( NPCMF_PREFER_SPRINT )
			titan.SetCapabilityFlag( bits_CAP_MOVE_SHOOT, true )
		}
	}
}

// HACK fix: looping to limit player's weapon
void function BerserkerCoreLimitedWeapon( entity owner, string limitedWeapon = "melee_titan_punch_fighter" )
{
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )

	bool activeWeaponLostLastTick
	while ( IsValid( owner.GetTitanSoul() ) && TitanCoreInUse( owner ) )
	{
		WaitFrame()
		
		array<entity> mainWeapons = owner.GetMainWeapons()
		entity activeWeapon = owner.GetActiveWeapon()

		// player may have weapon lost forever if they used the bug...
		// if this happend more than 1tick, switch back to fist
		// the 1 tick grace period is used for offhand switch!
		if ( !IsValid( activeWeapon ) )
		{
			if ( activeWeaponLostLastTick )
			{
				ReDeployWeapon( owner, limitedWeapon )
				activeWeaponLostLastTick = false
			}
			else
				activeWeaponLostLastTick = true
			
			continue
		}
		// also never allow switching to main weapon
		if ( mainWeapons.contains( activeWeapon ) )
		{
			ReDeployWeapon( owner, limitedWeapon )
		}

		activeWeaponLostLastTick = false
	}
}

void function ReDeployWeapon( entity owner, string weaponName )
{
	if ( owner.IsPlayer() )
		owner.HolsterWeapon() // show deploy animation, avoid blanking melee
	
	owner.SetActiveWeaponByName( weaponName )
	
	if ( owner.IsPlayer() )
		owner.DeployWeapon()
}
#endif