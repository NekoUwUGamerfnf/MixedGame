// based on _sp_loadouts.gnut, really should rework this to callbacks
/*
	example: 
		TitanLoadoutSwitch_RegisterBurstFireWeapon( string weapon )
		TitanLoadoutSwitch_RegisterChargeWeapon( string weapon )
		TitanLoadoutSwitch_RegisterAmmoClipWeapon( string weapon )
		TitanLoadoutSwitch_RegisterSharedEnergyWeapon( string weapon )
		// don't register ignored weapon to any type

		// EDIT: using a enum could be better for registering listed stuffs
		// EDIT2: could just use cooldown_type and add ignore weapon names
				  why respawn keep hardcoding everything?
*/
global function TitanLoadoutSwitch_Init

global function TitanLoadoutSwitch_GetWeaponCooldowns
global function TitanLoadoutSwitch_SetWeaponCooldownsFromTable

// registering ignored weapons
global function TitanLoadoutSwitch_AddCooldownIgnoredWeaponName

// always reduced from cooldown if you try to switch
const float LOADOUT_SWITCH_COOLDOWN_PENALTY = 0.1

const array<int> LOADOUT_SWITCH_RECORD_OFFHAND_SLOTS =
[
	OFFHAND_SPECIAL,
	OFFHAND_ANTIRODEO,
	OFFHAND_ORDNANCE,
	// no melee and no core
]

struct WeaponCooldownData
{
	// never use weaponName in case we have same weapons for different titans
	// why not use slot?
	//string weaponName
	int slot
	float timeStored
	float severity
}

struct
{
	// store cooldown data per player
	table< entity, array<WeaponCooldownData> > playerCooldownData
	// adding ignored weapons
	array<string> loadoutSwitchIgnoredWeapons
} file

void function TitanLoadoutSwitch_Init()
{
	AddCallback_OnClientConnected( OnClientConnected )
}

void function OnClientConnected( entity player )
{
	file.playerCooldownData[ player ] <- []
}

void function TitanLoadoutSwitch_AddCooldownIgnoredWeaponName( string weapon )
{
	if ( !file.loadoutSwitchIgnoredWeapons.contains( weapon ) )
		file.loadoutSwitchIgnoredWeapons.append( weapon )
}

table<int,float> function TitanLoadoutSwitch_GetWeaponCooldowns( entity player )
{
	if ( !player.IsPlayer() ) // used on npcs?
		return {}
	if ( !player.IsTitan() )
		return {}

	table<int,float> cooldowns = {}
	foreach ( int slot in LOADOUT_SWITCH_RECORD_OFFHAND_SLOTS )
		cooldowns[ slot ] <- 0.0

	// you know what? we should use for() instead of foreach to get sloted weapons
	for ( int slot = 0; slot < OFFHAND_COUNT - 1; slot ++ )
	{
		if ( !LOADOUT_SWITCH_RECORD_OFFHAND_SLOTS.contains( slot ) )
			continue
		
		entity offhand = player.GetOffhandWeapon( slot )
		if ( !IsValid( offhand ) )
			continue

		string weaponName = offhand.GetWeaponClassName()
		
		// Do nothing:
		if ( file.loadoutSwitchIgnoredWeapons.contains( weaponName ) )
			cooldowns[slot] = 1.0
		else
		{
			// I think it's genericly stupid when you try to... ughh, hardcoding weapon name
			switch( GetWeaponInfoFileKeyField_Global( weaponName, "cooldown_type" ) )
			{
				// Do nothing:
				case "ammo_swordblock":
				{
					cooldowns[slot] = 1.0
				}
				break

				// Using charge frac( reversed cooldown ):
				case "charged_shot":
				case "vortex_drain":
				{
					cooldowns[slot] = 1.0 - offhand.GetWeaponChargeFraction()
				}
				break

				// Using ammo clip:
				case "ammo":
				case "ammo_instant":
				case "ammo_per_shot":
				case "ammo_deployed":
				case "ammo_timed":
				{
					if ( offhand.IsWeaponRegenDraining() )
					{
						cooldowns[slot] = 0.0
					}
					else
					{
						int maxClipAmmo = offhand.GetWeaponPrimaryClipCountMax()
						int currentAmmo = offhand.GetWeaponPrimaryClipCount()
						cooldowns[slot] = (float( currentAmmo ) / float( maxClipAmmo ))
					}
				}
				break

				// Shared energy
				case "shared_energy":
				case "shared_energy_drain":
				{
					cooldowns[slot] = float( player.GetSharedEnergyCount() ) / float( player.GetSharedEnergyTotal() )
				}
				break

				default:
				{
					// Next attack time (burst fire):
					float cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
					float nextAttackTime = offhand.GetNextAttackAllowedTime()
					if ( nextAttackTime < Time() ) // already be allowed to attack
						nextAttackTime = Time()
					float NAT = nextAttackTime - Time()

					if ( NAT >= 0 )
						cooldowns[slot] = 1.0 - NAT/cooldownTime

					// THIS IS BECAUSE YOU'RE HARDCODING EVERYTHING
					//CodeWarning( offhand.GetWeaponClassName() + " - not handled in TitanLoadoutSwitch_GetWeaponCooldowns()." )
				}
				break
			}
		}

		array<WeaponCooldownData> playerDatas = file.playerCooldownData[ player ]
		bool foundData = false
		foreach ( WeaponCooldownData data in playerDatas )
		{
			if ( data.slot == slot ) // found one valid data?
			{
				// update it
				data.timeStored = Time()
				data.severity = cooldowns[slot]
				foundData = true
			}
		}

		if ( !foundData ) // can't found any data
		{
			// append a new one
			WeaponCooldownData data
			data.slot = slot
			data.timeStored = Time()
			data.severity = cooldowns[slot]

			file.playerCooldownData[ player ].append( data )
		}

		// debug
		printt( "GET: " + slot + " " + offhand.GetWeaponClassName() + " - " + cooldowns[slot] )
	}

	return cooldowns
}

void function TitanLoadoutSwitch_SetWeaponCooldownsFromTable( entity player, table<int,float> cooldowns )
{
	if ( !player.IsPlayer() ) // used on npcs?
		return
	if ( !player.IsTitan() )
		return

	// 1 is fully available, 0 is used up
	float highestSeverity = 1.0

	foreach ( slot, severity in cooldowns )
	{
		if ( !LOADOUT_SWITCH_RECORD_OFFHAND_SLOTS.contains( slot ) )
			continue
		
		entity offhand = player.GetOffhandWeapon( slot )
		if ( !IsValid( offhand ) )
			continue

		string weaponName = offhand.GetWeaponClassName()
		// Do nothing:
		if ( file.loadoutSwitchIgnoredWeapons.contains( weaponName ) )
			continue

		float severity = 1.0
		array<WeaponCooldownData> playerDatas = file.playerCooldownData[ player ]
		foreach ( WeaponCooldownData data in playerDatas )
		{
			if ( data.slot == slot ) // found saved severity in data
			{
				float savedSeverity = CalculateCurrentWeaponCooldownFromStoredTime( player, offhand, data )
				severity = min( savedSeverity, severity )
			}
		}

		highestSeverity = min( severity, highestSeverity )

		// debug
		printt( "SET: " + slot + " " + offhand.GetWeaponClassName() + " - " + severity )

		// I think it's genericly stupid when you try to... ughh, hardcoding weapon name
		switch( GetWeaponInfoFileKeyField_Global( weaponName, "cooldown_type" ) )
		{
			// Do nothing:
			case "ammo_swordblock":
			case "shared_energy":
			case "shared_energy_drain":
			{

			}
			break

			// Using charge frac( reversed cooldown ):
			case "charged_shot":
			case "vortex_drain":
			{
				offhand.SetWeaponChargeFractionForced( 1.0 - severity )
			}
			break

			// Using ammo clip:
			case "ammo":
			case "ammo_instant":
			case "ammo_per_shot":
			case "ammo_deployed":
			case "ammo_timed":
			{
				int maxClipAmmo = offhand.GetWeaponPrimaryClipCountMax()
				offhand.SetWeaponPrimaryClipCountAbsolute( maxClipAmmo * severity )
			}
			break

			default:
			{
				// Next attack time (burst fire):
				float cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
				offhand.SetNextAttackAllowedTime( Time() + ( cooldownTime * (1.0 - severity) ) )

				// THIS IS BECAUSE YOU'RE HARDCODING EVERYTHING
				//CodeWarning( offhand.GetWeaponClassName() + " - not handled in TitanLoadoutSwitch_SetWeaponCooldownsFromTable()." )
			}
			break
		}
	}

	// debug
	printt( "highestSeverity: " + highestSeverity )
	int energy = player.GetSharedEnergyCount()
	int totalEnergy = player.GetSharedEnergyTotal()
	int idealEnergy = int( player.GetSharedEnergyTotal() * highestSeverity )
	if ( energy < idealEnergy )
		player.AddSharedEnergy( idealEnergy - energy )
	else
		player.TakeSharedEnergy( energy - idealEnergy )
}

float function CalculateCurrentWeaponCooldownFromStoredTime( entity player, entity offhand, WeaponCooldownData data )
{
	float cooldownTime = 10.0
	switch( GetWeaponInfoFileKeyField_Global( offhand.GetWeaponClassName(), "cooldown_type" ) )
	{
		// Do nothing:
		case "ammo_swordblock":
		{
			cooldownTime = LOADOUT_SWITCH_COOLDOWN_PENALTY // still adds penalty
		}
		break
			
		// Using charge frac( reversed cooldown ):
		case "charged_shot":
		case "vortex_drain":
		{
			cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_time ) + offhand.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
		}
		break

		// Using ammo clip:
		case "ammo":
		case "ammo_instant":
		case "ammo_per_shot":
		case "ammo_deployed":
		case "ammo_timed":
		{
			float maxClipAmmo = float( offhand.GetWeaponPrimaryClipCountMax() )
			float refillRate = offhand.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_rate )

			bool ammo_drains = offhand.GetWeaponSettingBool( eWeaponVar.ammo_drains_to_empty_on_fire )

			float drainTime = 0.0
			if ( ammo_drains )
				drainTime = offhand.GetWeaponSettingFloat( eWeaponVar.fire_duration )

			cooldownTime = (maxClipAmmo / refillRate) + offhand.GetWeaponSettingFloat( eWeaponVar.regen_ammo_refill_start_delay ) + drainTime
		}
		break

		// Shared energy:
		case "shared_energy":
		case "shared_energy_drain":
		{
			float maxEnergy = float( player.GetSharedEnergyTotal() )
			float refillRate = player.GetSharedEnergyRegenRate()

			cooldownTime = (maxEnergy / refillRate) + player.GetSharedEnergyRegenDelay()
		}
		break

		default:
		{
			// Next attack time (burst fire):
			cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )

			// THIS IS BECAUSE YOU'RE HARDCODING EVERYTHING
			//CodeWarning( offhand.GetWeaponClassName() + " - not handled in GetWeaponCooldownsForTitanLoadoutSwitch()." )
		}
		break
	}

	float startTime = min( data.timeStored + LOADOUT_SWITCH_COOLDOWN_PENALTY, Time() )
	float elapsedTime = Time() - startTime

	float severity = elapsedTime / cooldownTime

	print( "calculated severity: " + string( clamp( severity + data.severity, 0, 1 ) ) )
	return clamp( severity + data.severity, 0, 1 )
}