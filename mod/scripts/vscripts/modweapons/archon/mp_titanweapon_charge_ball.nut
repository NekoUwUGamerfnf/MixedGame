untyped
global function MpTitanWeaponChargeBall_Init
global function OnWeaponPrimaryAttack_titanweapon_charge_ball
global function OnWeaponChargeBegin_titanweapon_charge_ball
global function OnWeaponChargeEnd_titanweapon_charge_ball

const CHARGEBALL_CHARGE_FX_1P = $"wpn_arc_cannon_charge_fp"
const CHARGEBALL_CHARGE_FX_3P = $"wpn_arc_cannon_charge"

const int CHARGEBALL_LIGHTNING_DAMAGE = 250 // uncharged, only fires 1 ball
const int CHARGEBALL_LIGHTNING_DAMAGE_CHARGED = 125
const int CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD = 85

void function MpTitanWeaponChargeBall_Init()
{
	PrecacheParticleSystem( $"Weapon_ArcLauncher_Fire_1P" )
	PrecacheParticleSystem( $"Weapon_ArcLauncher_Fire_3P" )
	PrecacheParticleSystem( CHARGEBALL_CHARGE_FX_1P )
	PrecacheParticleSystem( CHARGEBALL_CHARGE_FX_3P )

	PrecacheParticleSystem( $"P_impact_exp_emp_med_air" )

	#if SERVER
		// adding a new damageSourceId. it's gonna transfer to client automatically
	    RegisterWeaponDamageSource( "mp_titanweapon_charge_ball", "Charge Ball" )

		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_charge_ball, ChargeBallOnDamage )
		RegisterBallLightningDamage( eDamageSourceId.mp_titanweapon_charge_ball )
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_charge_ball( entity weapon, WeaponPrimaryAttackParams attackParams )
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

	var fireMode = weapon.GetWeaponInfoFileKeyField( "fire_mode" )

	vector attackPos = attackParams.pos
	vector attackDir = attackParams.dir

	float charge = weapon.GetWeaponChargeFraction()
	float angleoffset = 0.05
	float angleMultiplier = 1.6
	int extraBallAmount = 0

	vector rightVec = AnglesToRight(VectorToAngles(attackDir))

  	if (charge == 1.0)
	{extraBallAmount++
  	if (weapon.HasMod("thylord_module") ) { extraBallAmount++ }
	}

	for (int i = -extraBallAmount ; i < extraBallAmount+1 ; i++)
	{
		float finalMultiplier = angleMultiplier*i
		int damageSplitter = extraBallAmount+1
		float zapDamage = 300.0 / damageSplitter

		// function FireArcBall() has been modified, it now returns arcball entity
		entity arcball = FireArcBall( weapon, attackPos, attackDir + rightVec * angleoffset*finalMultiplier, shouldPredict, zapDamage )
		//Single = 300 per, Triple = 150 per, Thylord = 100 per

		if ( IsValid( arcball ) )
		{
			#if SERVER
				// note: this can't affect ball lightning's damageSourceId...
				// fixed it in _ball_lightning.gnut
				arcball.ProjectileSetDamageSourceID( eDamageSourceId.mp_titanweapon_charge_ball )
			#endif
			// fix for trail effect, so clients without scripts installed can see the trail
			StartParticleEffectOnEntity( arcball, GetParticleSystemIndex( $"P_wpn_arcball_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		}
	}
	
	weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

bool function OnWeaponChargeBegin_titanweapon_charge_ball( entity weapon )
{
	// sound already handled by weapon mod
	//weapon.EmitWeaponSound("Weapon_EnergySyphon_Charge_3P")

	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return true
	#endif
	
	return true
}

void function OnWeaponChargeEnd_titanweapon_charge_ball( entity weapon )
{
	// sound already handled by weapon mod
	//weapon.StopWeaponSound("Weapon_EnergySyphon_Charge_3P")
	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return
	#endif
}

void function ChargeBallOnDamage( entity ent, var damageInfo )
{
	//print( "chargeball damaged target!!!" )
	const ARC_TITAN_EMP_DURATION			= 0.35
	const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35

	StatusEffect_AddTimed( ent, eStatusEffect.emp, 0.1, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )
}