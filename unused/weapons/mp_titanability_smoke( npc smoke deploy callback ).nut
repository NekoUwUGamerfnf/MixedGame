
global function OnWeaponPrimaryAttack_titanability_smoke
global function MpTitanAbilitySmoke_Init
#if SERVER
	global function OnWeaponNpcPrimaryAttack_titanability_smoke
	global function AddSmokeHealCallback

	// modified callback for monitor npc smoke usage
	global function AddCallback_OnNPCDeployElectricSmoke
#endif

const SHIELD_BODY_FX			= $"P_xo_armor_body_CP"

void function MpTitanAbilitySmoke_Init()
{
	PrecacheParticleSystem( SHIELD_BODY_FX )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanability_smoke, ElectricSmoke_DamagedTarget )
	#endif
}

var function OnWeaponPrimaryAttack_titanability_smoke( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//PlayWeaponSound( "fire" )

#if SERVER
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
#endif

	entity player = weapon.GetWeaponOwner()
	if ( IsAlive( player ) )
	{
#if SERVER
		TitanSmokescreen( player, weapon )
#else
		Rumble_Play( "rumble_titan_electric_smoke", {} )
#endif
		if ( player.IsPlayer() )
			PlayerUsedOffhand( player, weapon )

#if MP && SERVER && ANTI_RODEO_SMOKE_ENABLED // JFS
		if ( player.GetOffhandWeapon( OFFHAND_INVENTORY ) == weapon && player.GetWeaponAmmoStockpile( weapon ) == 0 )
			player.TakeOffhandWeapon( OFFHAND_INVENTORY )
#endif

		return weapon.GetAmmoPerShot()
	}
	return 0
}

#if SERVER
struct
{
	void functionref(entity,entity,int) smokeHealCallback

	// modified callback for monitor npc smoke usage
	// added via AddCallback_OnNPCDeployElectricSmoke()
	array<void functionref( entity npc, entity weapon )> onNPCDeployElectricSmokeCallbacks
} file

var function OnWeaponNpcPrimaryAttack_titanability_smoke( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	entity npc = weapon.GetWeaponOwner()
	if ( IsAlive( npc ) )
	{
		TitanSmokescreen( npc, weapon )

		// modified callback for monitor npc smoke usage
		// added via AddCallback_OnNPCDeployElectricSmoke()
		foreach ( callbackFunc in file.onNPCDeployElectricSmokeCallbacks )
			callbackFunc( npc, weapon )
	}
}

void function TitanSmokescreen( entity ent, entity weapon )
{
	SmokescreenStruct smokescreen
	// modified: smoke dangerous area team
	// breaks vanilla behavior, but surly makes npcs behave better
	#if MP
	// HACK: only ability smoke do specific dangerous area team
	// burnmeter reward smoke can't be used by npcs so no need add team for them, which can also help keeping vanilla behavior
	if ( weapon.GetWeaponClassName() == "mp_titanability_smoke" ) 
		smokescreen.dangerousAreaTeam = FriendlyFire_IsEnabled() ? TEAM_INVALID : ent.GetTeam()
	#endif // MP
	//
	if ( weapon.HasMod( "burn_mod_titan_smoke" ) )
	{
		smokescreen.lifetime = 12.0
		smokescreen.smokescreenFX = FX_ELECTRIC_SMOKESCREEN_BURN
		smokescreen.deploySound1p = SFX_SMOKE_DEPLOY_BURN_1P
		smokescreen.deploySound3p = SFX_SMOKE_DEPLOY_BURN_3P
	}
	#if MP
	if ( HasHealingSmoke( ent ) )
	{
		smokescreen.smokescreenFX = FX_ELECTRIC_SMOKESCREEN_HEAL
		// modified: smoke dangerous area team
		// healing smoke is always safe against friendly targets
		// HACK: only ability smoke do specific dangerous area team
		// burnmeter reward smoke can't be used by npcs so no need add team for them, which can also help keeping vanilla behavior
		if ( weapon.GetWeaponClassName() == "mp_titanability_smoke" ) 
			smokescreen.dangerousAreaTeam = ent.GetTeam()
		//
	}
	#endif
	smokescreen.isElectric = true
	smokescreen.ownerTeam = ent.GetTeam()
	smokescreen.attacker = ent
	smokescreen.inflictor = ent
	smokescreen.weaponOrProjectile = weapon
	smokescreen.damageInnerRadius = 320.0
	smokescreen.damageOuterRadius = 375.0
	if ( weapon.HasMod( "maelstrom" ) )
	{
		smokescreen.dpsPilot = 90
		smokescreen.dpsTitan = 1350
		smokescreen.deploySound1p = SFX_SMOKE_DEPLOY_BURN_1P
		smokescreen.deploySound3p = SFX_SMOKE_DEPLOY_BURN_3P
	}
	else
	{
		smokescreen.dpsPilot = 45
		smokescreen.dpsTitan = 450
	}
	smokescreen.damageDelay = 1.0

	vector eyeAngles = <0.0, ent.EyeAngles().y, 0.0>
	smokescreen.angles = eyeAngles

	vector forward = AnglesToForward( eyeAngles )
	vector testPos = ent.GetOrigin() + forward * 240.0
	vector basePos = testPos

	float trace = TraceLineSimple( ent.EyePosition(), testPos, ent )
	if ( trace != 1.0 )
		basePos = ent.GetOrigin()

	float fxOffset = 200.0
	float fxHeightOffset = 148.0

	smokescreen.origin = basePos

	smokescreen.fxOffsets = [ < -fxOffset, 0.0, 20.0>,
							  <0.0, fxOffset, 20.0>,
							  <0.0, -fxOffset, 20.0>,
							  <0.0, 0.0, fxHeightOffset>,
							  < -fxOffset, 0.0, fxHeightOffset> ]

	Smokescreen( smokescreen )
}

void function ElectricSmoke_DamagedTarget( entity target, var damageInfo )
{
	// rework checks. vanilla DO have good enough check functions but respawn never used them
	/*
	if ( !target.IsTitan() )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() < 1 )
		return

	entity weapon = weapons[0]
	if ( !IsValid( weapon ) )
		return

	if ( attacker.GetTeam() == target.GetTeam() )
	{
		if ( ( attacker == target && weapon.HasMod( "fd_vanguard_utility_1" ) ) || weapon.HasMod( "fd_vanguard_utility_2" ) )
		{
			entity soul = target.GetTitanSoul()
			if ( IsValid( soul ) )
			{
				int shieldRestoreAmount = 35
				int actualShieldRestoreAmount = minint( soul.GetShieldHealthMax()-soul.GetShieldHealth(), shieldRestoreAmount )
				soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )

				if ( file.smokeHealCallback != null && actualShieldRestoreAmount > 0 )
					file.smokeHealCallback( attacker, target, actualShieldRestoreAmount )

				//float shieldHealthFrac = GetShieldHealthFrac( target )
				//if ( shieldHealthFrac < 1.0 )
				//{
				//	int shieldbodyFX = GetParticleSystemIndex( SHIELD_BODY_FX )
				//	int attachID
				//	if ( target.IsTitan() )
				//		attachID = target.LookupAttachment( "exp_torso_main" )
				//	else
				//		attachID = target.LookupAttachment( "ref" )
				//
				//	entity shieldFXEnt = StartParticleEffectOnEntity_ReturnEntity( target, shieldbodyFX, FX_PATTACH_POINT_FOLLOW, attachID )
				//	EffectSetControlPointVector( shieldFXEnt, 1, < 115, 247, 255 > )
				//}
			}
		}

		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
	*/
	// reworked checks
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return
	if ( TryElectricSmokeTargetHeal( attacker, target ) )
		DamageInfo_SetDamage( damageInfo, 0 ) // always set damage to 0 if heal functioning
}

void function AddSmokeHealCallback( void functionref(entity,entity,int) func )
{
	file.smokeHealCallback = func
}

bool function HasHealingSmoke( entity attacker )
{
	array<entity> weapons = attacker.GetMainWeapons()
	if ( weapons.len() < 1 )
		return false

	entity weapon = weapons[0]
	if ( !IsValid( weapon ) )
		return false

	return ( weapon.HasMod( "fd_vanguard_utility_1" ) || weapon.HasMod( "fd_vanguard_utility_2" ))
}

// modified functions
bool function SmokeCanHealTarget( entity attacker, entity target )
{
	if ( !target.IsTitan() )
		return false
	entity soul = target.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false
	if ( !HasHealingSmoke( attacker ) )
		return false

	entity weapon = attacker.GetMainWeapons()[0] // safe to use, validation checks done in HasHealingSmoke()
	if ( !IsValid( weapon ) )
		return false

	// friendly fire support
	bool friendlyFireOn = FriendlyFire_IsEnabled()
	bool forceHeal = FriendlyFire_IsMonarchForcedHealthEnabled()
	if ( attacker.GetTeam() == target.GetTeam() || ( friendlyFireOn && forceHeal ) || attacker == target )
	{
		// monarch upgrade 1: can only heal self
		if ( weapon.HasMod( "fd_vanguard_utility_1" ) && attacker == target )
			return true
		// monarch upgrade 2: can heal all teammates
		if ( weapon.HasMod( "fd_vanguard_utility_2" ) )
			return true
	}

	return false // default is cannot heal target
}

bool function TryElectricSmokeTargetHeal( entity attacker, entity target )
{
	// healing condition
	if ( !SmokeCanHealTarget( attacker, target ) ) // main checks
		return false

	entity soul = target.GetTitanSoul() // safe to use, validation checks done in SmokeCanHealTarget()

	int shieldRestoreAmount = 35
	int actualShieldRestoreAmount = minint( soul.GetShieldHealthMax()-soul.GetShieldHealth(), shieldRestoreAmount )
	soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )

	if ( file.smokeHealCallback != null && actualShieldRestoreAmount > 0 )
		file.smokeHealCallback( attacker, target, actualShieldRestoreAmount )
	return true // healing succeeded
}
#endif // SERVER


// modified callback for monitor npc smoke usage
#if SERVER
void function AddCallback_OnNPCDeployElectricSmoke( void functionref( entity npc, entity weapon ) callbackFunc )
{
	file.onNPCDeployElectricSmokeCallbacks.append( callbackFunc )
}
#endif