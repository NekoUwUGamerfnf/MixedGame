untyped
global function MpTitanweaponChargeBall_Init
global function OnWeaponPrimaryAttack_titanweapon_charge_ball
global function OnWeaponChargeBegin_titanweapon_charge_ball
global function OnWeaponChargeEnd_titanweapon_charge_ball

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
			FireArchonChargeBall( weapon, attackPos, attackDir, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false )
			FireArchonChargeBall( weapon, attackPos, attackDir + rightVec * angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false )
			FireArchonChargeBall( weapon, attackPos, attackDir + rightVec * -angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false )
			FireArchonChargeBall( weapon, attackPos, attackDir + rightVec * angleoffset*3.2, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false )
			FireArchonChargeBall( weapon, attackPos, attackDir + rightVec * -angleoffset*3.2, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED_MOD, false )
			weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
			weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
			//weapon.StopWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P )
		}
		else
		{
			FireArchonChargeBall( weapon, attackPos, attackDir, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED, false )
			FireArchonChargeBall( weapon, attackPos, attackDir + rightVec * angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED, false )
			FireArchonChargeBall( weapon, attackPos, attackDir + rightVec * -angleoffset*1.6, shouldPredict, CHARGEBALL_LIGHTNING_DAMAGE_CHARGED, false )
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

bool function OnWeaponChargeBegin_titanweapon_charge_ball( entity weapon )
{
	local stub = "this is here to suppress the untyped message.  This can go away when the .s. usage is removed from this file."
	// sound already handled by mp_titanweapon_stun_laser
	//weapon.EmitWeaponSound("Weapon_EnergySyphon_Charge_3P")

	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return true
	#endif

	// effect already handled by mp_titanweapon_stun_laser
	//entity weaponOwner = weapon.GetWeaponOwner()
	//weapon.PlayWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P, "muzzle_flash" )

	return true
}

void function OnWeaponChargeEnd_titanweapon_charge_ball( entity weapon )
{
	// sound already handled by mp_titanweapon_stun_laser
	//weapon.StopWeaponSound("Weapon_EnergySyphon_Charge_3P")
	#if CLIENT
		if ( !IsFirstTimePredicted() )
			return
	#endif

	// effect already handled by mp_titanweapon_stun_laser
	//weapon.StopWeaponEffect( CHARGEBALL_CHARGE_FX_1P, CHARGEBALL_CHARGE_FX_3P )
}

void function ChargeBallOnDamage( entity ent, var damageInfo )
{
	const ARC_TITAN_EMP_DURATION			= 0.35
	const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35

	StatusEffect_AddTimed( ent, eStatusEffect.emp, 0.1, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )
}

// taken from mp_titanweapon_arc_ball.nut, archon requires a independed arcball launch
entity function FireArchonChargeBall( entity weapon, vector pos, vector dir, bool shouldPredict, float damage = BALL_LIGHTNING_DAMAGE, bool isCharged = false )
{
	entity owner = weapon.GetWeaponOwner()

	float speed = 500.0

	if ( isCharged )
		speed = 350.0

	if ( owner.IsPlayer() )
	{
		vector myVelocity = owner.GetVelocity()

		float mySpeed = Length( myVelocity )

		myVelocity = Normalize( myVelocity )

		float dotProduct = DotProduct( myVelocity, dir )

		dotProduct = max( 0, dotProduct )

		speed = speed + ( mySpeed*dotProduct )
	}

	int team = TEAM_UNASSIGNED
	if ( IsValid( owner ) )
		team = owner.GetTeam()

	entity bolt = weapon.FireWeaponBolt( pos, dir, speed, damageTypes.arcCannon | DF_IMPACT, damageTypes.arcCannon | DF_EXPLOSION, shouldPredict, 0 )
	if ( bolt != null )
	{
		bolt.kv.rendercolor = "0 0 0"
		bolt.kv.renderamt = 0
		bolt.kv.fadedist = 1
		bolt.kv.gravity = 5
		SetTeam( bolt, team )

		float lifetime = 8.0

		if ( isCharged )
		{
			bolt.SetProjectilTrailEffectIndex( 1 )
			lifetime = 20.0
		}

		bolt.SetProjectileLifetime( lifetime )

		#if SERVER
			bolt.ProjectileSetDamageSourceID( eDamageSourceId.mp_titanweapon_charge_ball )

			AttachBallLightning( bolt, bolt ) // not using( weapon, bolt ) since we want to make the lightning use projectile's damageSourceID

			entity ballLightning = expect entity( bolt.s.ballLightning )

			ballLightning.e.ballLightningData.damage = damage
		#endif

		// fix for trail effect, so clients without scripts installed can see the trail
		StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"P_wpn_arcball_trail" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )

		return bolt
	}
}