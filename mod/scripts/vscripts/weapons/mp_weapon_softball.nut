untyped

global function OnWeaponPrimaryAttack_weapon_softball
global function OnProjectileCollision_weapon_softball

// modified callbacks
global function OnWeaponActivate_weapon_softball
global function OnWeaponOwnerChanged_weapon_softball
global function OnWeaponReload_weapon_softball
//

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_softball
#endif // #if SERVER

const FUSE_TIME = 0.5 //Applies once the grenade has stuck to a surface.

// modified callbacks
void function OnWeaponActivate_weapon_softball( entity weapon )
{
	// modded softball in mp_weapon_modded_softball.gnut
	if ( ModdedSoftball_WeaponHasMod( weapon ) )
		return OnWeaponActivate_weapon_modded_softball( weapon )

	// vanilla has no behavior
}

void function OnWeaponOwnerChanged_weapon_softball( entity weapon, WeaponOwnerChangedParams changeParams )
{
	// modded softball in mp_weapon_modded_softball.gnut
	if ( ModdedSoftball_WeaponHasMod( weapon ) )
		return OnWeaponOwnerChanged_weapon_modded_softball( weapon, changeParams )

	// vanilla has no behavior
}
//

var function OnWeaponPrimaryAttack_weapon_softball( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded softball in mp_weapon_modded_softball.gnut
	if ( ModdedSoftball_WeaponHasMod( weapon ) )
		return OnWeaponPrimaryAttack_weapon_modded_softball( weapon, attackParams )
	//

	// vanilla behavior
	entity player = weapon.GetWeaponOwner()

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	//vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() * 2.0 )
	//attackParams.dir = bulletVec

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
	{
		vector offset = Vector( 30.0, 6.0, -4.0 )
		if ( weapon.IsWeaponInAds() )
			offset = Vector( 30.0, 0.0, -3.0 )
		vector attackPos = player.OffsetPositionFromView( attackParams[ "pos" ], offset )	// forward, right, up
		FireGrenade( weapon, attackParams )
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_softball( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// npc not influenced by modded softball

	// vanilla behavior
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION // | DF_GIB

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		#if SERVER
			EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
			Grenade_Init( nade, weapon )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
	}
}

void function OnProjectileCollision_weapon_softball( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	// modded softball in mp_weapon_modded_softball.gnut
	if ( ModdedSoftball_ProjectileHasMod( projectile ) )
		return OnProjectileCollision_weapon_modded_softball( projectile, pos, normal, hitEnt, hitbox, isCritical )
	//

	// direct hit softball
	if ( mods.contains( "direct_hit" ) )
        OnProjectileCollision_DirectHit( projectile, pos, normal, hitEnt, hitbox, isCritical )
	//

	// vanilla behavior
	bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
	if ( !didStick )
		return

	#if SERVER
		if ( IsAlive( hitEnt ) && hitEnt.IsPlayer() )
		{
			EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
			EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
		}
		else
		{
			EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
		}
		thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
	#endif
}

#if SERVER
// need this so grenade can use the normal to explode
void function DetonateStickyAfterTime( entity projectile, float delay, vector normal )
{
	wait delay
	if ( IsValid( projectile ) )
		projectile.GrenadeExplode( normal )
}
#endif

// modified callbacks
void function OnWeaponReload_weapon_softball( entity weapon, int milestoneIndex )
{
	// modded softball in mp_weapon_modded_softball.gnut
	if ( ModdedSoftball_WeaponHasMod( weapon ) )
		return OnWeaponReload_weapon_moded_softball( weapon, milestoneIndex )

	// vanilla has no behavior
}
//