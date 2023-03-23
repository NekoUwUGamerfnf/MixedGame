// based on _sp_loadouts.gnut, really should rework this to tables
global function TitanLoadoutSwitch_Init

global function GetWeaponCooldownsForTitanLoadoutSwitch
global function SetWeaponCooldownsForTitanLoadoutSwitch

const float LOADOUT_SWITCH_COOLDOWN_PENALTY = 0.1

struct WeaponCooldownData
{
	string weaponName
	float timeStored
	float severity
}

struct
{
	table< entity, array<WeaponCooldownData> > playerCooldownData
} file

void function TitanLoadoutSwitch_Init()
{
	AddCallback_OnClientConnected( OnClientConnected )
}

void function OnClientConnected( entity player )
{
	file.playerCooldownData[ player ] <- []
}

table<int,float> function GetWeaponCooldownsForTitanLoadoutSwitch( entity player )
{
	if ( !player.IsPlayer() ) // used on npcs?
		return {}
	if ( !player.IsTitan() )
		return {}

	entity coreWeapon = player.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	entity meleeWeapon = player.GetMeleeWeapon()
	array<entity> offhandWeapons = player.GetOffhandWeapons()

	table<int,float> cooldowns = {}
	cooldowns[ OFFHAND_ORDNANCE ] <- 0.0
	cooldowns[ OFFHAND_SPECIAL ] <- 0.0
	cooldowns[ OFFHAND_ANTIRODEO ] <- 0.0

	foreach ( slot,severity in cooldowns )
	{
		entity offhand = player.GetOffhandWeapon( slot )

		if ( !IsValid( offhand ) )
			continue
		if ( offhand == meleeWeapon )
			continue
		if ( offhand == coreWeapon )
			continue

		switch( offhand.GetWeaponClassName() )
		{
			// Next attack time (burst fire):
			case "mp_titanweapon_homing_rockets":
			{
				float cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
				float nextAttackTime = offhand.GetNextAttackAllowedTime()
				if ( nextAttackTime < Time() ) // already be allowed to attack
					nextAttackTime = Time()
				float NAT = nextAttackTime - Time()

				if ( NAT >= 0 )
					cooldowns[slot] = 1.0 - NAT/cooldownTime
			}
			break


			// Set charge to 100%:
			case "mp_titanweapon_vortex_shield":
			case "mp_titanweapon_heat_shield":
			case "mp_titanweapon_shoulder_rockets":
			{
				cooldowns[slot] = 1.0 - offhand.GetWeaponChargeFraction()
			}
			break

			// Set clip ammo to 0:
			case "mp_titanability_smoke":
			case "mp_titanability_tether_trap":
			case "mp_titanability_phase_dash":
			case "mp_titanability_hover":
			case "mp_titanability_sonar_pulse":
			case "mp_titanability_particle_wall":
			case "mp_titanability_gun_shield":
			case "mp_titanweapon_flame_wall":
			case "mp_titanability_slow_trap":
			case "mp_titanweapon_arc_wave":
			case "mp_titanweapon_dumbfire_rockets":
			case "mp_titanability_power_shot":
			case "mp_titanability_rearm":
			case "mp_titanweapon_stun_laser":
			case "mp_titanability_rocketeer_ammo_swap":
			case "mp_titanweapon_salvo_rockets":
			case "mp_titanability_laser_trip":
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

			// Do nothing:
			case "mp_titanweapon_laser_lite":		// shared energy
			case "mp_titanability_laser_trip":		// shared energy
			case "mp_titanweapon_vortex_shield_ion":// shared energy
			{
				cooldowns[slot] = float( player.GetSharedEnergyCount() ) / float( player.GetSharedEnergyTotal() )
			}
			break

			case "mp_titanability_basic_block":
			case "mp_titanweapon_tracker_rockets":
			case "mp_titanability_ammo_swap":
			{
				cooldowns[slot] = 1.0
			}
			break

			default:
			{
				//CodeWarning( offhand.GetWeaponClassName() + " - not handled in GetWeaponCooldownsForTitanLoadoutSwitch()." )
			}
		}

		string weaponName = offhand.GetWeaponClassName()
		array<WeaponCooldownData> playerDatas = file.playerCooldownData[ player ]
		bool foundData = false
		foreach ( WeaponCooldownData data in playerDatas )
		{
			if ( data.weaponName == weaponName ) // found one valid data?
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
			data.weaponName = weaponName
			data.timeStored = Time()
			data.severity = cooldowns[slot]

			file.playerCooldownData[ player ].append( data )
		}

		//printt( "GET: " + slot + " " + offhand.GetWeaponClassName() + " - " + cooldowns[slot] )
	}

	return cooldowns
}

void function SetWeaponCooldownsForTitanLoadoutSwitch( entity player, table<int,float> cooldowns )
{
	if ( !player.IsPlayer() ) // used on npcs?
		return
	if ( !player.IsTitan() )
		return

	entity coreWeapon = player.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	entity meleeWeapon = player.GetMeleeWeapon()
	array<entity> offhandWeapons = player.GetOffhandWeapons()

	// 1 is fully available, 0 is used up
	float highestSeverity = 1.0

	foreach ( slot,severity in cooldowns )
	{
		entity offhand = player.GetOffhandWeapon( slot )

		if ( !IsValid( offhand ) )
			continue

		string offhandName = offhand.GetWeaponClassName()

		array<WeaponCooldownData> playerDatas = file.playerCooldownData[ player ]
		foreach ( WeaponCooldownData data in playerDatas )
		{
			if ( data.weaponName == offhandName ) // found saved severity in data
			{
				float savedSeverity = CalculateCurrentWeaponCooldownFromStoredTime( player, offhand, data )
				severity = min( savedSeverity, severity )
			}
		}

		highestSeverity = min( severity, highestSeverity )

		if ( offhand == meleeWeapon )
			continue
		if ( offhand == coreWeapon )
			continue

		//printt( "SET: " + slot + " " + offhand.GetWeaponClassName() + " - " + severity )

		switch( offhandName )
		{
			// Next attack time (burst fire):
			case "mp_titanweapon_homing_rockets":
			{
				float cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
				offhand.SetNextAttackAllowedTime( Time() + ( cooldownTime * (1.0 - severity) ) )
			}
			break

			// Set charge to 100%:
			case "mp_titanweapon_vortex_shield":
			case "mp_titanweapon_heat_shield":
			case "mp_titanweapon_shoulder_rockets":
			{
				offhand.SetWeaponChargeFractionForced( 1.0 - severity )
			}
			break

			// Set clip ammo to 0:
			case "mp_titanability_smoke":
			case "mp_titanability_tether_trap":
			case "mp_titanability_phase_dash":
			case "mp_titanability_hover":
			case "mp_titanability_sonar_pulse":
			case "mp_titanability_gun_shield":
			case "mp_titanability_particle_wall":
			case "mp_titanweapon_flame_wall":
			case "mp_titanability_slow_trap":
			case "mp_titanweapon_arc_wave":
			case "mp_titanweapon_dumbfire_rockets":
			case "mp_titanability_power_shot":
			case "mp_titanability_rearm":
			case "mp_titanweapon_stun_laser":
			case "mp_titanability_rocketeer_ammo_swap":
			case "mp_titanweapon_salvo_rockets":
			case "mp_titanability_laser_trip":
			{
				int maxClipAmmo = offhand.GetWeaponPrimaryClipCountMax()
				offhand.SetWeaponPrimaryClipCountAbsolute( maxClipAmmo * severity )
			}
			break

			// Do nothing:
			case "mp_titanability_basic_block":
			case "mp_titanweapon_tracker_rockets":
			case "mp_titanability_ammo_swap":
			case "mp_titanweapon_laser_lite":		// shared energy
			case "mp_titanability_laser_trip":		// shared energy
			case "mp_titanweapon_vortex_shield_ion":// shared energy
			{
			}
			break

			default:
			{
				//CodeWarning( offhand.GetWeaponClassName() + " - not handled in SetWeaponCooldownsForTitanLoadoutSwitch()." )
			}
		}
	}

	//printt( "highestSeverity: " + highestSeverity )
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
	switch( offhand.GetWeaponClassName() )
	{
		// Next attack time (burst fire):
		case "mp_titanweapon_homing_rockets":
		{
			cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
		}
		break

		// Set charge to 100%:
		case "mp_titanweapon_vortex_shield":
		case "mp_titanweapon_heat_shield":
		case "mp_titanweapon_shoulder_rockets":
		{
			cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_time ) + offhand.GetWeaponSettingFloat( eWeaponVar.charge_cooldown_delay )
		}
		break

		// Set clip ammo to 0:
		case "mp_titanability_smoke":
		case "mp_titanability_tether_trap":
		case "mp_titanability_phase_dash":
		case "mp_titanability_hover":
		case "mp_titanability_sonar_pulse":
		case "mp_titanability_particle_wall":
		case "mp_titanability_gun_shield":
		case "mp_titanweapon_flame_wall":
		case "mp_titanability_slow_trap":
		case "mp_titanweapon_arc_wave":
		case "mp_titanweapon_dumbfire_rockets":
		case "mp_titanability_power_shot":
		case "mp_titanability_rearm":
		case "mp_titanweapon_stun_laser":
		case "mp_titanability_rocketeer_ammo_swap":
		case "mp_titanweapon_salvo_rockets":
		case "mp_titanability_laser_trip":
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

		// Do nothing:
		case "mp_titanweapon_laser_lite":		// shared energy
		case "mp_titanability_laser_trip":		// shared energy
		case "mp_titanweapon_vortex_shield_ion":// shared energy
		{
			float maxEnergy = float( player.GetSharedEnergyTotal() )
			float refillRate = player.GetSharedEnergyRegenRate()

			cooldownTime = (maxEnergy / refillRate) + player.GetSharedEnergyRegenDelay()
		}
		break

		case "mp_titanability_basic_block":
		case "mp_titanweapon_tracker_rockets":
		case "mp_titanability_ammo_swap":
		{
			cooldownTime = 0.1
		}
		break

		default:
		{
			//CodeWarning( offhand.GetWeaponClassName() + " - not handled in GetWeaponCooldownsForTitanLoadoutSwitch()." )
		}
	}

	float startTime = min( data.timeStored + LOADOUT_SWITCH_COOLDOWN_PENALTY, Time() )
	float elapsedTime = Time() - startTime

	float severity = elapsedTime / cooldownTime

	return clamp( severity + data.severity, 0, 1 )
}