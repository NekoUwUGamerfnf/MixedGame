
global function OnWeaponPrimaryAttack_weapon_shotgun

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_shotgun
#endif // #if SERVER

var function OnWeaponPrimaryAttack_weapon_shotgun( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	bool hasTwinSlugMod = weapon.HasMod( "twin_slug" )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	// modded weapon
	if ( hasTwinSlugMod )
	{
		// in respawn's though, this mod will blast all two pellets in one time
		// my version is to turn it to an marksman weapon which fires two bullets at the same time
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )
		
		// might be respawn's though
		//ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 16, weapon.GetWeaponDamageFlags() )
		return 2
	}
	//

	// vanilla behavior
	ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 8, weapon.GetWeaponDamageFlags() )

	// remove this behavior
	//if ( hasTwinSlugMod )
	//	return 2
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_shotgun( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_weapon_shotgun( weapon, attackParams )
}
#endif // #if SERVER
