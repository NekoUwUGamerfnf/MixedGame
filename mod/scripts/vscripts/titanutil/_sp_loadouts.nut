global function GetWeaponCooldownsForTitanLoadoutSwitch
global function SetWeaponCooldownsForTitanLoadoutSwitch

const float LOADOUT_SWITCH_COOLDOWN_PENALTY = 0.1

struct WeaponCooldownData
{
	float timeStored
	float severity
}

struct
{
	table< string, WeaponCooldownData > cooldownData
} file

table<int,float> function GetWeaponCooldownsForTitanLoadoutSwitch( entity player )
{
	Assert( player.IsTitan() )

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
			/*
			case "mp_titanweapon_salvo_rockets":
			{
				float cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
				float nextAttackTime = offhand.GetNextAttackAllowedTime()
				float NAT = nextAttackTime - Time()

				if ( NAT >= 0 )
					cooldowns[slot] = NAT/cooldownTime
			}
			break
			*/


			// Set charge to 100%:
			case "mp_titanweapon_vortex_shield":
			case "mp_titanweapon_heat_shield":
			case "mp_titanweapon_shoulder_rockets":
			//case "mp_titanweapon_homing_rockets":
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
			case "mp_titanweapon_homing_rockets":
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
				CodeWarning( offhand.GetWeaponClassName() + " - not handled in GetWeaponCooldownsForTitanLoadoutSwitch()." )
			}
		}

		string weaponName = offhand.GetWeaponClassName()
		WeaponCooldownData data
		data.timeStored = Time()
		data.severity = cooldowns[slot]

		if ( !( weaponName in file.cooldownData ) )
			file.cooldownData[ weaponName ] <- data
		else
			file.cooldownData[ weaponName ] = data

		//printt( "GET: " + slot + " " + offhand.GetWeaponClassName() + " - " + cooldowns[slot] )
	}

	return cooldowns
}

void function SetWeaponCooldownsForTitanLoadoutSwitch( entity player, table<int,float> cooldowns )
{
	Assert( player.IsTitan() )

/*
	array<entity> weapons = GetPrimaryWeapons( player )
	foreach ( weapon in weapons )
	{
		if ( weapon.GetWeaponPrimaryClipCountMax() > 0 )
			weapon.SetWeaponPrimaryClipCount( 0 )
	}
*/

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

		if ( offhandName in file.cooldownData )
		{
			float savedSeverity = CalculateCurrentWeaponCooldownFromStoredTime( player, offhand, file.cooldownData[ offhandName ] )
			severity = min( savedSeverity, severity )
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
			/*
			case "mp_titanweapon_salvo_rockets":
			{
				float cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
				offhand.SetNextAttackAllowedTime( Time() + (cooldownTime * severity) )
			}
			break
			*/

			// Set charge to 100%:
			case "mp_titanweapon_vortex_shield":
			case "mp_titanweapon_heat_shield":
			case "mp_titanweapon_shoulder_rockets":
			//case "mp_titanweapon_homing_rockets":
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
			//case "mp_titanweapon_homing_rockets":
			case "mp_titanability_laser_trip":
			{
				int maxClipAmmo = offhand.GetWeaponPrimaryClipCountMax()
				offhand.SetWeaponPrimaryClipCountAbsolute( maxClipAmmo * severity )
			}
			break

			case "mp_titanweapon_homing_rockets":
			{
				int maxClipAmmo = offhand.GetWeaponPrimaryClipCountMax()
				if( severity == 0 )
					severity += 0.1
				offhand.SetWeaponPrimaryClipCountAbsolute( maxClipAmmo * severity )
			}

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
				CodeWarning( offhand.GetWeaponClassName() + " - not handled in SetWeaponCooldownsForTitanLoadoutSwitch()." )
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
	// if ( Time() - data.timeStored < 30.0 )
	// 	return data.severity

	// return 1.0

	float cooldownTime = 10.0
	switch( offhand.GetWeaponClassName() )
	{
		// Next attack time (burst fire):
		/*
		case "mp_titanweapon_salvo_rockets":
		{
			cooldownTime = offhand.GetWeaponSettingFloat( eWeaponVar.burst_fire_delay )
		}
		break
		*/

		// Set charge to 100%:
		case "mp_titanweapon_vortex_shield":
		case "mp_titanweapon_heat_shield":
		case "mp_titanweapon_shoulder_rockets":
		//case "mp_titanweapon_homing_rockets":
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
		case "mp_titanweapon_homing_rockets":
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
			CodeWarning( offhand.GetWeaponClassName() + " - not handled in GetWeaponCooldownsForTitanLoadoutSwitch()." )
		}
	}

	float startTime = min( data.timeStored + LOADOUT_SWITCH_COOLDOWN_PENALTY, Time() )
	float elapsedTime = Time() - startTime

	float severity = elapsedTime / cooldownTime

	return clamp( severity + data.severity, 0, 1 )
}