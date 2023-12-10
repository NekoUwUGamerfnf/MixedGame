global function UpgradeCore_Init
global function OnWeaponPrimaryAttack_UpgradeCore
// modified callbacks
global function OnCoreCharge_UpgradeCore
global function OnCoreChargeEnd_UpgradeCore
//

#if SERVER
global function OnWeaponNpcPrimaryAttack_UpgradeCore

// modified settings
// allow modifying upgrading method for titan
global function UpgradeCore_SetWeaponUpgradePassive

// vanilla hardcode turns to default value
const int UPGRADE_CORE_DEFAULT_MAX_LEVEL = 2 // lv0-lv1-lv2( stage1-stage2-stage3 )
//
#endif
#if CLIENT
global function ServerCallback_VanguardUpgradeMessage
#endif

const LASER_CHAGE_FX_1P = $"P_handlaser_charge"
const LASER_CHAGE_FX_3P = $"P_handlaser_charge"
const FX_SHIELD_GAIN_SCREEN		= $"P_xo_shield_up"

// modified settings
struct
{
	// allow modifying upgrading method for titan
	table< entity, table<int, int> > upgradeCorePassivesTable
	table<entity, int> soulUpgradeCount
} file

void function UpgradeCore_Init()
{
	RegisterSignal( "OnSustainedDischargeEnd" )

	PrecacheParticleSystem( FX_SHIELD_GAIN_SCREEN )
	PrecacheParticleSystem( LASER_CHAGE_FX_1P )
	PrecacheParticleSystem( LASER_CHAGE_FX_3P )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_UpgradeCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_UpgradeCore( weapon, attackParams )
	return 1
}
#endif

var function OnWeaponPrimaryAttack_UpgradeCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "shield_core" ) )
		return OnAbilityStart_Shield_Core( weapon, attackParams )
	//

	// vanilla behavior
	if ( !CheckCoreAvailable( weapon ) )
		return false

	entity owner = weapon.GetWeaponOwner()
	entity soul = owner.GetTitanSoul()
	#if SERVER
		float coreDuration = weapon.GetCoreDuration()
		thread UpgradeCoreThink( weapon, coreDuration )

		// below are heavily modified
		if ( !( soul in file.soulUpgradeCount ) )
			file.soulUpgradeCount[ soul ] <- 0

		void functionref( entity ) upgradeFunc = null
		if ( !( weapon in file.upgradeCorePassivesTable ) ) // don't have modified settings?
			upgradeFunc = GetUpgradeFunctionFromTitan( owner ) // get upgrade from titan
		else // has modified upgrade order
		{
			if ( file.soulUpgradeCount[ soul ] in file.upgradeCorePassivesTable[ weapon ] )
			{
				int passive = file.upgradeCorePassivesTable[ weapon ][ file.soulUpgradeCount[ soul ] ]
				upgradeFunc = GetUpgradeFunctionFromPassive( passive )
			}
		}

		// modified: this variable only stores "effective" upgrades
		// if we don't have any upgrade function calling, this variable isn't gonna increase
		int currentUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		if ( upgradeFunc != null )
		{
			upgradeFunc( owner )
			// play dialogue before we update upgrade counter
			PlayUpgradeDialogue( owner )

			soul.SetTitanSoulNetInt( "upgradeCount", currentUpgradeCount + 1 )
		}
		else
		{
			// do shield replenish dialogue if there're no valid upgrade
			if ( owner.IsPlayer() )
				Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", GetConversationIndex( "upgradeShieldReplenish" ) )
		}

		// this is the variable that stores any upgrade we tried to do, not only effective ones
		file.soulUpgradeCount[ soul ] = file.soulUpgradeCount[ soul ] + 1
		
		// upgrade bodygroup
		int newUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		if ( newUpgradeCount > 0 )
		{
			int statesIndex = owner.FindBodyGroup( "states" )
			if ( statesIndex > -1 ) // anti-crash
				owner.SetBodygroup( statesIndex, 1 )
		}
	#endif

	#if CLIENT
		if ( owner.IsPlayer() )
		{
			entity cockpit = owner.GetCockpit()
			if ( IsValid( cockpit ) )
				StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( FX_SHIELD_GAIN_SCREEN	), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		}
	#endif
	OnAbilityCharge_TitanCore( weapon )
	OnAbilityStart_TitanCore( weapon )

	return 1
}

#if SERVER
void function UpgradeCoreThink( entity weapon, float coreDuration )
{
	weapon.EndSignal( "OnDestroy" )
	entity owner = weapon.GetWeaponOwner()
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "DisembarkingTitan" )
	owner.EndSignal( "TitanEjectionStarted" )

	// modified to add npc usage
	if ( owner.IsPlayer() ) 
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_1P" )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_ActiveLoop_1P" )
		EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_3P" )
	}
	else
		EmitSoundOnEntity( owner, "Titan_Monarch_Smart_Core_Activated_3P" )
	
	entity soul = owner.GetTitanSoul()
	soul.SetShieldHealth( soul.GetShieldHealthMax() )

	OnThreadEnd(
	function() : ( weapon, owner, soul )
		{
			if ( IsValid( owner ) )
			{
				StopSoundOnEntity( owner, "Titan_Monarch_Smart_Core_ActiveLoop_1P" )
				//EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_1P" )
			}

			if ( IsValid( weapon ) )
			{
				OnAbilityChargeEnd_TitanCore( weapon )
				OnAbilityEnd_TitanCore( weapon )
			}

			if ( IsValid( soul ) )
			{
				CleanupCoreEffect( soul )
			}
		}
	)

	wait coreDuration
}


// modified rework starts here
// split everything into functions
void functionref( entity ) function GetUpgradeFunctionFromTitan( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( IsValid( soul ) )
	{
		int currentUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		if ( currentUpgradeCount == 0 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE1 ) ) // Arc Rounds
				return Upgrade_ArcRounds
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE2 ) ) //Missile Racks
				return Upgrade_MissileRacks
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE3 ) ) //Energy Transfer
				return Upgrade_EnergyTransfer
		}
		else if ( currentUpgradeCount == 1 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE4 ) )  // Rapid Rearm
				return Upgrade_RapidRearm
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE5 ) ) //Maelstrom
				return Upgrade_Maelstrom
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE6 ) ) //Energy Field
				return Upgrade_EnergyField
		}
		else if ( currentUpgradeCount == 2 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE7 ) )  // Multi-Target Missiles
				return Upgrade_MultiTargetMissiles
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE8 ) ) //Superior Chassis
				return Upgrade_SuperiorChassis
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE9 ) ) //XO-16 Battle Rifle
				return Upgrade_XO16BattleRifle
		}
	}

	return null
}

void functionref( entity ) function GetUpgradeFunctionFromPassive( int passive )
{
	switch ( passive )
	{
		case ePassives.PAS_VANGUARD_CORE1:
			return Upgrade_ArcRounds
		case ePassives.PAS_VANGUARD_CORE2:
			return Upgrade_MissileRacks
		case ePassives.PAS_VANGUARD_CORE3:
			return Upgrade_EnergyTransfer

		case ePassives.PAS_VANGUARD_CORE4:
			return Upgrade_RapidRearm
		case ePassives.PAS_VANGUARD_CORE5:
			return Upgrade_Maelstrom
		case ePassives.PAS_VANGUARD_CORE6:
			return Upgrade_EnergyField

		case ePassives.PAS_VANGUARD_CORE7:
			return Upgrade_MultiTargetMissiles
		case ePassives.PAS_VANGUARD_CORE8:
			return Upgrade_SuperiorChassis
		case ePassives.PAS_VANGUARD_CORE9:
			return Upgrade_XO16BattleRifle
	}

	return null
}

void function PlayUpgradeDialogue( entity titan )
{
	// dialogue is only for players
	if ( !titan.IsPlayer() )
		return

	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
	
	int conversationID = -1

	// this variable only stores "effective" upgrades. if an upgrade only included shield regen it won't be consider as effective
	int effectiveUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
	if ( effectiveUpgradeCount == 0 )
		conversationID = GetConversationIndex( "upgradeTo1" )
	else if ( effectiveUpgradeCount == 1 )
		conversationID = GetConversationIndex( "upgradeTo2" )
	else if ( effectiveUpgradeCount == 2 )
	{
		array<string> conversations = [ "upgradeTo3" ]
		if ( GetMaxUpgradeLevel( titan ) == 2 ) // max upgrade level is 2
			conversations.append( "upgradeToFin" ) // add chance to pick "final upgrade" dialogue
		conversationID = GetConversationIndex( conversations.getrandom() )
	}
	else // higher than level 2
	{
		conversationID = GetConversationIndex( "upgradeShieldReplenish" )

		// custom level
		if ( soul in file.soulUpgradeCount )
		{
			if ( file.soulUpgradeCount[ soul ] == GetMaxUpgradeLevel( titan ) ) // reaching max upgrade level?
				conversationID = GetConversationIndex( "upgradeToFin" ) // use final upgrade dialogue instead
		}
	}

	if ( conversationID != -1 )
		Remote_CallFunction_Replay( titan, "ServerCallback_PlayTitanConversation", conversationID )
}

int function GetMaxUpgradeLevel( entity titan )
{
	entity upgradeCore = GetUpgradeCoreWeapon( titan )
	if ( !IsValid( upgradeCore ) ) // don't have upgrade core for some reason...
		return 0

	// core with no modified settings, just return default value
	if ( !( upgradeCore in file.upgradeCorePassivesTable ) )
		return UPGRADE_CORE_DEFAULT_MAX_LEVEL
	
	int highestLevel = 0
	foreach ( int level, int passive in file.upgradeCorePassivesTable[ upgradeCore ] )
	{
		if ( highestLevel < level )
			highestLevel = level
	}
	return highestLevel
}

// this is hardcoded!
entity function GetUpgradeCoreWeapon( entity titan )
{
	entity coreWeapon = titan.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	if ( IsValid( coreWeapon ) && coreWeapon.GetWeaponClassName() == "mp_titancore_upgrade" )
		return coreWeapon
	
	return null
}

void function Upgrade_ArcRounds( entity titan )
{
	array<entity> weapons = GetPrimaryWeapons( titan )
	if ( weapons.len() > 0 )
	{
		entity primaryWeapon = weapons[0]
		if ( IsValid( primaryWeapon ) )
		{
			array<string> mods = primaryWeapon.GetMods()
			mods.append( "arc_rounds" )
			primaryWeapon.SetMods( mods )
			primaryWeapon.SetWeaponPrimaryClipCount( primaryWeapon.GetWeaponPrimaryClipCount() + 10 )
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 1 )
}

void function Upgrade_MissileRacks( entity titan )
{
	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_RIGHT )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "missile_racks" )
		offhandWeapon.SetMods( mods )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 2 )
}

void function Upgrade_EnergyTransfer( entity titan )
{
	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "energy_transfer" )
		offhandWeapon.SetMods( mods )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 3 )
}

void function Upgrade_RapidRearm( entity titan )
{
	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_ANTIRODEO )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "rapid_rearm" )
		offhandWeapon.SetMods( mods )
	}
	array<entity> weapons = GetPrimaryWeapons( titan )
	if ( weapons.len() > 0 )
	{
		entity primaryWeapon = weapons[0]
		if ( IsValid( primaryWeapon ) )
		{
			array<string> mods = primaryWeapon.GetMods()
			mods.append( "rapid_reload" )
			primaryWeapon.SetMods( mods )
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 4 )
}

void function Upgrade_Maelstrom( entity titan )
{
	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_INVENTORY )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "maelstrom" )
		offhandWeapon.SetMods( mods )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 5 )
}

void function Upgrade_EnergyField( entity titan )
{
	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		if ( mods.contains( "energy_transfer" ) )
		{
			array<string> mods = offhandWeapon.GetMods()
			mods.fastremovebyvalue( "energy_transfer" )
			mods.append( "energy_field_energy_transfer" )
			offhandWeapon.SetMods( mods )
		}
		else
		{
			array<string> mods = offhandWeapon.GetMods()
			mods.append( "energy_field" )
			offhandWeapon.SetMods( mods )
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 6 )
}

void function Upgrade_MultiTargetMissiles( entity titan )
{
	entity ordnance = titan.GetOffhandWeapon( OFFHAND_RIGHT )
	array<string> mods
	if ( ordnance.HasMod( "missile_racks") )
		mods = [ "upgradeCore_MissileRack_Vanguard" ]
	else
		mods = [ "upgradeCore_Vanguard" ]

	if ( ordnance.HasMod( "fd_balance" ) )
		mods.append( "fd_balance" )

	float ammoFrac = float( ordnance.GetWeaponPrimaryClipCount() ) / float( ordnance.GetWeaponPrimaryClipCountMax() )
	titan.TakeWeaponNow( ordnance.GetWeaponClassName() )
	titan.GiveOffhandWeapon( "mp_titanweapon_shoulder_rockets", OFFHAND_RIGHT, mods )
	ordnance = titan.GetOffhandWeapon( OFFHAND_RIGHT )
	ordnance.SetWeaponChargeFractionForced( 1 - ammoFrac )

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 7 )
}

void function Upgrade_SuperiorChassis( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( IsValid( soul ) )
	{
		if ( !GetDoomedState( titan ) )
		{
			if ( titan.IsPlayer() )
			{
				int missingHealth = titan.GetMaxHealth() - titan.GetHealth()
				array<string> settingMods = titan.GetPlayerSettingsMods()
				settingMods.append( "core_health_upgrade" )
				titan.SetPlayerSettingsWithMods( titan.GetPlayerSettings(), settingMods )
				titan.SetHealth( max( titan.GetMaxHealth() - missingHealth, VANGUARD_CORE8_HEALTH_AMOUNT ) )

				//Hacky Hack - Append core_health_upgrade to setFileMods so that we have a way to check that this upgrade is active.
				soul.soul.titanLoadout.setFileMods.append( "core_health_upgrade" )
			}
			else
			{
				titan.SetMaxHealth( titan.GetMaxHealth() + VANGUARD_CORE8_HEALTH_AMOUNT )
				titan.SetHealth( titan.GetHealth() + VANGUARD_CORE8_HEALTH_AMOUNT )
			}
		}
		else
		{
			titan.SetHealth( titan.GetMaxHealth() )
		}

		soul.SetPreventCrits( true )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 8 )
}

void function Upgrade_XO16BattleRifle( entity titan )
{
	array<entity> weapons = GetPrimaryWeapons( titan )
	if ( weapons.len() > 0 )
	{
		entity primaryWeapon = weapons[0]
		if ( IsValid( primaryWeapon ) )
		{
			if ( primaryWeapon.HasMod( "arc_rounds" ) )
			{
				primaryWeapon.RemoveMod( "arc_rounds" )
				array<string> mods = primaryWeapon.GetMods()
				mods.append( "arc_rounds_with_battle_rifle" )
				primaryWeapon.SetMods( mods )
			}
			else
			{
				array<string> mods = primaryWeapon.GetMods()
				mods.append( "battle_rifle" )
				mods.append( "battle_rifle_icon" )
				primaryWeapon.SetMods( mods )
			}
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 9 )
}
#endif

// modified callbacks
bool function OnCoreCharge_UpgradeCore( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "shield_core" ) )
		return OnCoreCharge_Shield_Core( weapon )

	return true
}

void function OnCoreChargeEnd_UpgradeCore( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "shield_core" ) )
		return OnCoreChargeEnd_Shield_Core( weapon )
}
//

#if CLIENT
void function ServerCallback_VanguardUpgradeMessage( int upgradeID )
{
	switch ( upgradeID )
	{
		case 1:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE1" ), Localize( "#GEAR_VANGUARD_CORE1_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 2:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE2" ), Localize( "#GEAR_VANGUARD_CORE2_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 3:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE3" ), Localize( "#GEAR_VANGUARD_CORE3_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 4:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE4" ), Localize( "#GEAR_VANGUARD_CORE4_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 5:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE5" ), Localize( "#GEAR_VANGUARD_CORE5_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 6:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE6" ), Localize( "#GEAR_VANGUARD_CORE6_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 7:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE7" ), Localize( "#GEAR_VANGUARD_CORE7_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 8:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE8" ), Localize( "#GEAR_VANGUARD_CORE8_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 9:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE9" ), Localize( "#GEAR_VANGUARD_CORE9_UPGRADEDESC" ), <255, 135, 10> )
			break
	}
}
#endif

// modified settings
#if SERVER
// allow modifying upgrading method for titan
void function UpgradeCore_SetWeaponUpgradePassive( entity weapon, int upgradeLevel, int passive )
{
	table<int, int> emptyTable
	if ( !( weapon in file.upgradeCorePassivesTable ) )
		file.upgradeCorePassivesTable[ weapon ] <- emptyTable
	
	if ( !( upgradeLevel in file.upgradeCorePassivesTable[ weapon ] ) )
		file.upgradeCorePassivesTable[ weapon ][ upgradeLevel ] <- passive
	else
		file.upgradeCorePassivesTable[ weapon ][ upgradeLevel ] = passive
}
#endif