// vanilla missing MpWeaponGrenadeEMP_Init()
untyped
global function MpWeaponGrenadeEMP_Init

void function MpWeaponGrenadeEMP_Init()
{
	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_grenade_emp, OnDamagedTarget_GrenadeEMP )
	#endif
}

#if SERVER
void function OnDamagedTarget_GrenadeEMP( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( !IsValid( attacker ) )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if( !IsValid( inflictor ) )
		return
	if( !inflictor.IsProjectile() )
		return

	array<string> mods = Vortex_GetRefiredProjectileMods( inflictor ) // modded weapon refire behavior
	// emp grenade modifier
	if( mods.contains( "impulse_grenade" ) )
	{
		if ( ent.IsPlayer() )
			ImpulseGrenade_EffectsPlayer( ent, damageInfo )
		return
	}

	// vanilla behavior
	EMP_DamagedPlayerOrNPC( ent, damageInfo )
}

function ImpulseGrenade_EffectsPlayer( entity player, damageInfo )
{
	if ( player.IsPhaseShifted() )
		return

    /** Factors */
    int scalePush = 1

    /** Dropoff */
    entity inflictor = DamageInfo_GetInflictor( damageInfo )
    local origin = inflictor.GetOrigin()
    float radius = inflictor.GetDamageRadius()
    vector force = ( player.GetOrigin() + /** Approx. player waist height */ <0,0,40> - expect vector(origin) )
    float len = vmag(force) // Vector size
    vector normForce = force * (1/len) // Normalized vector
    float pushF = -1/radius * pow(len, 2) + radius // Quadratic force dropoff from origin
    vector effectiveForce = normForce * pushF // Resize normalized vector with added force
    if(player.IsTitan())
        effectiveForce = effectiveForce * 0.3

    player.SetVelocity( player.GetVelocity() + effectiveForce * scalePush )
}

float function vmag( vector v ){
    return sqrt(v.x*v.x + v.y*v.y + v.z*v.z)
}
#endif