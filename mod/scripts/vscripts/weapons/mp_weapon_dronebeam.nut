
global function MpWeaponDroneBeam_Init

#if SERVER
global function OnWeaponNpcPrimaryAttack_DroneBeam
#endif // #if SERVER

void function MpWeaponDroneBeam_Init()
{
	PrecacheParticleSystem( $"P_wpn_defender_charge_FP" )
	PrecacheParticleSystem( $"P_wpn_defender_charge" )
	PrecacheParticleSystem( $"defender_charge_CH_dlight" )

	// modified
#if SERVER
    // respawn actually assigned display name for drone beam
	// but #WPN_DRONERBEAM isn't a valid localized string, should be #WPN_DRONEBEAM( remove the R )
    RegisterWeaponDamageSource( "mp_weapon_dronebeam_fixed", "#WPN_DRONEBEAM" )
    // fix method is to change damageSourceId of mp_weapon_dronebeam to mp_weapon_dronebeam_fixed
    AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_dronebeam, OnDroneBeamDealDamage )
#endif
}


#if SERVER
var function OnWeaponNpcPrimaryAttack_DroneBeam( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	return 1
}

// fix damageSourceId display name
void function OnDroneBeamDealDamage( entity victim, var damageInfo )
{
    // change to fixed damageSourceId
    DamageInfo_SetDamageSourceIdentifier( damageInfo, eDamageSourceId.mp_weapon_dronebeam_fixed )
}
#endif // #if SERVER
