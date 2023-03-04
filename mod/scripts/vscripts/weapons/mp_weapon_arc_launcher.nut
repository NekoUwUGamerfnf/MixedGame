untyped

global function OnWeaponPrimaryAttack_weapon_arc_launcher

const ARC_LAUNCHER_ZAP_DAMAGE = 350

// modified callbacks
global function OnProjectileCollision_weapon_arc_launcher
global function OnProjectileIgnite_weapon_arc_launcher

// respawn missing npc_primary_attack
#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_arc_launcher
#endif

// anti-pilot arclauncher
const int ARC_LAUNCHER_ZAP_DAMAGE_PILOT_AMPED = 20

var function OnWeaponPrimaryAttack_weapon_arc_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( weapon.HasMod( "smoke_launcher" ) )
		return OnWeaponPrimaryAttack_weapon_smoke_launcher( weapon, attackParams )

	entity weaponOwner = weapon.GetWeaponOwner()

	if ( weaponOwner.IsPlayer() )
	{
		float zoomFrac = weaponOwner.GetZoomFrac()
		if ( zoomFrac < 1 )
			return 0
	}

	#if SERVER
		if ( weaponOwner.IsPlayer() )
		{
			vector angles = VectorToAngles( weaponOwner.GetViewVector() )
			vector up = AnglesToUp( angles )

			if ( weaponOwner.GetTitanSoulBeingRodeoed() != null )
				attackParams.pos = attackParams.pos + up * 20
		}
	#endif

	bool shouldPredict = weapon.ShouldPredictProjectiles()
	#if CLIENT
		if ( !shouldPredict )
			return 1
	#endif

	float speed = 450.0

	vector attackPos = attackParams.pos
	vector attackDir = attackParams.dir

	// reworked here: FireArcBall() won't return a entity in vanilla, I changed it in mp_titanweapon_arc_ball
	entity arcBall = FireArcBall( weapon, attackPos, attackDir, shouldPredict, ARC_LAUNCHER_ZAP_DAMAGE )
	if( arcBall )
	{
#if SERVER
		entity ballLightning = expect entity( arcBall.s.ballLightning )

		// anti-pilot arc launcher
		if( weapon.HasMod( "antipilot_arc_launcher" ) )
		{
			ballLightning.e.ballLightningData.damageToPilots = ARC_LAUNCHER_ZAP_DAMAGE_PILOT_AMPED
			ballLightning.e.ballLightningData.damage = ARC_LAUNCHER_ZAP_DAMAGE * 0.2
		}
#endif
	}

	weapon.EmitWeaponSound_1p3p( "Weapon_ArcLauncher_Fire_1P", "Weapon_ArcLauncher_Fire_3P" )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return 1
}

// modded callbacks
#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_arc_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( weapon.HasMod( "smoke_launcher" ) )
		return OnWeaponNpcPrimaryAttack_weapon_smoke_launcher( weapon, attackParams )

	return OnWeaponPrimaryAttack_weapon_arc_launcher( weapon, attackParams )	
}
#endif

void function OnProjectileCollision_weapon_arc_launcher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = projectile.ProjectileGetMods()

	if ( mods.contains( "smoke_launcher" ) )
		return OnProjectileCollision_weapon_smoke_launcher( projectile, pos, normal, hitEnt, hitbox, isCritical )
}

void function OnProjectileIgnite_weapon_arc_launcher( entity projectile )
{
	array<string> mods = projectile.ProjectileGetMods()

	if ( mods.contains( "smoke_launcher" ) )
		return OnProjectileIgnite_weapon_smoke_launcher( projectile )
}