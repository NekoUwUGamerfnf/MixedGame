untyped

global function Archon_Init

#if SERVER
global function DamageShieldsInRadiusOnEntity
#endif

void function Archon_Init()
{
	ArchonCannon_Init()
	MpTitanweaponArchonCannon_Init()
	MpTitanweaponShockShield_Init()
	MpTitanweaponChargeBall_Init()
	MpTitanAbilityArcPylon_Init()
	MpTitanWeaponStormWave_Init()
	MpTitanweaponStormBall_Init()
}

vector function ApplyVectorSpread_Archon( vector vecShotDirection, float spreadDegrees, float bias = 1.0 )
{
	vector angles = VectorToAngles( vecShotDirection )
	vector vecUp = AnglesToUp( angles )
	vector vecRight = AnglesToRight( angles )

	float sinDeg = deg_sin( spreadDegrees / 2.0 )

	// get circular gaussian spread
	float x
	float y
	float z

	if ( bias > 1.0 )
		bias = 1.0
	else if ( bias < 0.0 )
		bias = 0.0

	// code gets these values from cvars ai_shot_bias_min & ai_shot_bias_max
	float shotBiasMin = -1.0
	float shotBiasMax = 1.0

	// 1.0 gaussian, 0.0 is flat, -1.0 is inverse gaussian
	float shotBias = ( ( shotBiasMax - shotBiasMin ) * bias ) + shotBiasMin
	float flatness = ( fabs(shotBias) * 0.5 )

	while ( true )
	{
		x = RandomFloatRange( -1.0, 1.0 ) * flatness + RandomFloatRange( -1.0, 1.0 ) * (1 - flatness)
		y = RandomFloatRange( -1.0, 1.0 ) * flatness + RandomFloatRange( -1.0, 1.0 ) * (1 - flatness)
		if ( shotBias < 0 )
		{
			x = ( x >= 0 ) ? 1.0 - x : -1.0 - x
			y = ( y >= 0 ) ? 1.0 - y : -1.0 - y
		}
		z = x * x + y * y

		if ( z <= 1 )
			break
	}

	vector addX = vecRight * ( x * sinDeg )
	vector addY = vecUp * ( y * sinDeg )
	vector m_vecResult = vecShotDirection + addX + addY

	return m_vecResult
}


float function DegreesToTarget_Archon( vector origin, vector forward, vector targetPos )
{
	vector dirToTarget = targetPos - origin
	dirToTarget = Normalize( dirToTarget )
	float dot = DotProduct( forward, dirToTarget )
	float degToTarget = (acos( dot ) * 180 / PI)

	return degToTarget
}

#if SERVER
array<entity> function DamageShieldsInRadiusOnEntity( entity weapon, entity inflictor, float radius, float damage )
{
	array<entity> damagedEnts = [] // used so that we only damage a shield once per function call
	array<string> shieldClasses = [ "mp_titanweapon_vortex_shield", "mp_titanweapon_shock_shield", "mp_titanweapon_heat_shield" ] // add shields that are like vortex shield/heat shield to this, they seem to be exceptions?

	// not ideal
	foreach ( entity shield in GetEntArrayByClass_Expensive( "vortex_sphere" ) )
	{
		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( weapon.GetWeaponOwner(), inflictor.GetOrigin(), shield.GetCenter() )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )

			if ( damagedEnts.contains( vortexHit.vortex ) )
				continue
			if ( Distance( inflictor.GetCenter(), vortexHit.vortex.GetCenter() ) > radius )
				continue

			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && shieldClasses.contains( vortexWeapon.GetWeaponClassName() ) )
				VortexDrainedByImpact( vortexWeapon, weapon, inflictor, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damage )

			damagedEnts.append( vortexHit.vortex )

		}
	}

	foreach ( entity npc in GetNPCArrayOfEnemies( weapon.GetWeaponOwner().GetTeam() ) )
	{
		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( weapon.GetWeaponOwner(), inflictor.GetOrigin(), npc.GetCenter() )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )

			if ( damagedEnts.contains( vortexHit.vortex ) )
				continue
			if ( Distance( inflictor.GetCenter(), vortexHit.vortex.GetCenter() ) > radius )
				continue

			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && shieldClasses.contains( vortexWeapon.GetWeaponClassName() ) )
				VortexDrainedByImpact( vortexWeapon, weapon, inflictor, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damage )

			damagedEnts.append( vortexHit.vortex )

		}
	}

	foreach ( entity player in GetPlayerArray() )
	{
		if (player.GetTeam() == weapon.GetWeaponOwner().GetTeam())
			continue

		VortexBulletHit ornull vortexHit = VortexBulletHitCheck( weapon.GetWeaponOwner(), inflictor.GetOrigin(), player.GetCenter() )
		if ( vortexHit )
		{
			expect VortexBulletHit( vortexHit )

			if ( damagedEnts.contains( vortexHit.vortex ) )
				continue
			if ( Distance( inflictor.GetCenter(), vortexHit.vortex.GetCenter() ) > radius )
				continue

			entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

			if ( vortexWeapon && shieldClasses.contains( vortexWeapon.GetWeaponClassName() ) )
				VortexDrainedByImpact( vortexWeapon, weapon, inflictor, null ) // drain the vortex shield
			else if ( IsVortexSphere( vortexHit.vortex ) )
				VortexSphereDrainHealthForDamage( vortexHit.vortex, damage )

			damagedEnts.append( vortexHit.vortex )

		}
	}

	return damagedEnts // returning an array of the things you damaged with a RadiusDamage-esque function?? crazy
}
#endif
