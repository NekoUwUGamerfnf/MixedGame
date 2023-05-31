// vanilla missing MpWeaponAutoPistol_Init
global function MpWeaponAutoPistol_Init

const float AUTOPISTOL_IMPULSE_FORCE = 500 // unused
const float AUTOPISTOL_IMPULSE_FORCE_LIMIT_HORIZONTAL = 170 // so player won't receive too much force on horizontal

void function MpWeaponAutoPistol_Init()
{
#if SERVER
    // pistol_mode
    AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_autopistol, OnDamagedTarget_AutoPistol )
#endif
}

#if SERVER
void function OnDamagedTarget_AutoPistol( entity ent, var damageInfo )
{
    if ( !IsValid( ent ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsValid( attacker ) )
		return

    entity weapon = DamageInfo_GetWeapon( damageInfo )
    //print( "weapon: " + string( weapon ) )
    if ( !IsValid( weapon ) )
        return
    if ( !weapon.HasMod( "pistol_mode" ) )
        return

    vector forceVec = ClampHorizontalVelocity( DamageInfo_GetDamageForce( damageInfo ), AUTOPISTOL_IMPULSE_FORCE_LIMIT_HORIZONTAL )
    //print( "forceVec: " + string( forceVec ) )
    ent.SetVelocity( ent.GetVelocity() + forceVec )
    DamageInfo_SetDamageForce( damageInfo, < 0,0,0 > ) // only receive velocity from this script
    /*
    vector damagePos = DamageInfo_GetDamagePosition( damageInfo )
    //print( "damagePos: " + string( damagePos ) )
    vector victimPos = ent.GetOrigin()
    //print( "victimPos: " + string( victimPos ) )
    vector forceDirection = Normalize( victimPos - damagePos )
    vector forceVec = forceDirection * AUTOPISTOL_IMPULSE_FORCE
    ent.SetVelocity( ent.GetVelocity() + forceVec )
    */
    DamageInfo_SetDamage( damageInfo, 1 )
}

vector function ClampHorizontalVelocity( vector vel, float maxSpeed )
{
    vector horizontalVel = < vel.x, vel.y, 0 >
    float speed = Length( horizontalVel )
    horizontalVel = Normalize( horizontalVel )
    horizontalVel = horizontalVel * min( speed, maxSpeed )
    vel.x = horizontalVel.x
    vel.y = horizontalVel.y
    return vel
}
#endif