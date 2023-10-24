
#if SERVER
global function OnWeaponNpcPrimaryAttack_gunship_missile
#endif // SERVER


#if SERVER
var function OnWeaponNpcPrimaryAttack_gunship_missile( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//self.EmitWeaponSound( "Weapon_ARL.Single" )
	// removing scripted firing sound now, try to use settings file
	//weapon.EmitWeaponSound( "ShoulderRocket_Salvo_Fire_3P" )

	// manually play another muzzle flash fx
    weapon.PlayWeaponEffect( $"", $"wpn_muzzleflash_40mm", "muzzle_flash" )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	#if SERVER
		entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, 1, damageTypes.largeCaliberExp, damageTypes.largeCaliberExp, false, PROJECTILE_NOT_PREDICTED )
		if ( missile )
		{
			EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )
			missile.InitMissileForRandomDriftFromWeaponSettings( attackParams.pos, attackParams.dir )
		
			// modified damageSourceId in mp_weapon_gunship_missile_fixed.nut, fixes display name
			missile.ProjectileSetDamageSourceID( eDamageSourceId.mp_weapon_gunship_missile_fixed )
		}
	#endif
}
#endif // #if SERVER