untyped
global function MpTitanweaponChargeBall_Init
global function OnWeaponPrimaryAttack_weapon_MpTitanWeaponChargeBall
global function OnWeaponChargeBegin_MpTitanWeaponChargeBall
global function OnWeaponChargeEnd_MpTitanWeaponChargeBall

const CHARGEBALL_CHARGE_FX_1P = $"wpn_arc_cannon_charge_fp"
const CHARGEBALL_CHARGE_FX_3P = $"wpn_arc_cannon_charge"

const int CHARGEBALL_LIGHTNING_DAMAGE = 250 // uncharged, only fires 1 ball
const int CHARGEBALL_LIGHTNING_DAMAGE_CHARGED = 125
const int CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD = 85

void function MpTitanweaponChargeBall_Init()
{
	PrecacheParticleSystem( $"Weapon_ArcLauncher_Fire_1P" )
	PrecacheParticleSystem( $"Weapon_ArcLauncher_Fire_3P" )
	PrecacheParticleSystem( CHARGEBALL_CHARGE_FX_1P )
	PrecacheParticleSystem( CHARGEBALL_CHARGE_FX_3P )

	PrecacheParticleSystem( $"P_impact_exp_emp_med_air" )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_stun_laser, ChargeBallOnDamage )
		RegisterBallLightningDamage( eDamageSourceId.mp_titanweapon_stun_laser ) // doing check in stun laser damagesourceID
	#endif
}

var function OnWeaponPrimaryAttack_weapon_MpTitanWeaponChargeBall( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	#if SERVER
		if ( weaponOwner.IsPlayer() )
		{
			vector angles = VectorToAngles( weaponOwner.GetViewVector() )
			vector up = AnglesToUp( angles )
			PlayerUsedOffhand( weaponOwner, weapon )

			if ( weaponOwner.GetTitanSoulBeingRodeoed() != null )
				attackParams.pos = attackParams.pos + up * 20
		}
	#endif

	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return
	#endif

	float speed = 200.0

	var fireMode = weapon.GetWeaponInfoFileKeyField( "fire_mode" )

	vector attackPos = attackParams.pos
	vector attackDir = attackParams.dir

	if ( fireMode == "offhand_instant" )
	{
		// Get missile firing information
		entity owner = weapon.GetWeaponOwner()
		if ( owner.IsPlayer() )
			attackDir = GetVectorFromPositionToCrosshair( owner, attackParams.pos )
	}

	float charge = weapon.GetWeaponChargeFraction()
	float angleoffset = 0.05

	vector rightVec = AnglesToRight(VectorToAngles(attackDir))

  if (charge == 1.0)
	{
		if ( weapon.HasMod( "thylord_module" ) )
		{
			FireArcBall( weapon, attackPos, attackDir, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false, true )
			FireArcBall( weapon, attackPos, attackDir + rightVec * angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false, true )
			FireArcBall( weapon, attackPos, attackDir + rightVec * -angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false, true )
			FireArcBall( weapon, attackPos, attackDir + rightVec * angleoffset*3.2, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false, true )
			FireArcBall( weapon, attackPos, attackDir + rightVec * -angleoffset*3.2, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false, true )
			weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
			//weapon.StopWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P )
		}
		else
		{
			FireArcBall( weapon, attackPos, attackDir, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED, false, true )
			FireArcBall( weapon, attackPos, attackDir + rightVec * angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED, false, true )
			FireArcBall( weapon, attackPos, attackDir + rightVec * -angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED, false, true )
			weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
			//weapon.StopWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P )
		}
	}

	if (charge != 1.0)
	{
		FireArcBall( weapon, attackPos, attackDir, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE )
		weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		//weapon.StopWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P )
	}
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

bool function OnWeaponChargeBegin_MpTitanWeaponChargeBall( entity weapon )
{
	local stub = "this is here to suppress the untyped message.  This can go away when the .s. usage is removed from this file."
	weapon.EmitWeaponSound("Weapon_EnergySyphon_Charge_3P")

	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return true
	#endif


	//entity weaponOwner = weapon.GetWeaponOwner()
	//weapon.PlayWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P, "muzzle_flash" )

	return true
}

void function OnWeaponChargeEnd_MpTitanWeaponChargeBall( entity weapon )
{
	weapon.StopWeaponSound("Weapon_EnergySyphon_Charge_3P")
	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return
	#endif


	//weapon.StopWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P )
}

void function ChargeBallOnDamage( entity ent, var damageInfo )
{
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	if( !IsValid( weapon ) )
		return
	if( !weapon.HasMod( "charge_ball" ) )
		return

	const ARC_TITAN_EMP_DURATION			= 0.35
	const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35

	StatusEffect_AddTimed( ent, eStatusEffect.emp, 0.1, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )
}
