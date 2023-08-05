
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
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 2, weapon.GetWeaponDamageFlags() )
		return 1
		//return 2 // fire 2 bullets already costs 2 ammo!
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
