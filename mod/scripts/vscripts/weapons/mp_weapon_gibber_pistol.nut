untyped

global function OnWeaponPrimaryAttack_weapon_gibber_pistol
global function OnProjectileCollision_weapon_gibber_pistol
#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_gibber_pistol
#endif // #if SERVER

const FUSE_TIME 			= 0.5 //Applies once the grenade has stuck to a surface.
const MAX_BONUS_VELOCITY	= 1250

var function OnWeaponPrimaryAttack_weapon_gibber_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// gibber pistol
	if ( weapon.HasMod( "gibber_pistol" ) || weapon.HasMod( "grenade_pistol" ) )
	{
		entity player = weapon.GetWeaponOwner()

		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		vector bulletVec = ApplyVectorSpread( attackParams.dir, player.GetAttackSpreadAngle() )
		attackParams.dir = bulletVec

		if ( IsServer() || weapon.ShouldPredictProjectiles() )
		{
			FireGrenade( weapon, attackParams )
		}
	}
	else // p2016
	{
		//entity weaponOwner = weapon.GetWeaponOwner()
		// don't calculate again! client will desync
		//vector bulletVec = ApplyVectorSpread( attackParams.dir, weaponOwner.GetAttackSpreadAngle() )
		//attackParams.dir = bulletVec
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )
	}
}

#if SERVER
// nowhere called this
var function OnWeaponNpcPrimaryAttack_weapon_gibber_pistol( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, isNPCFiring = false )
{
	//vector attackAngles = VectorToAngles( attackParams.dir )
	//attackAngles.x -= 2
	//attackParams.dir = AnglesToForward( attackAngles )

	entity owner = weapon.GetWeaponOwner()
	vector attackVec = attackParams.dir
	vector angularVelocity = Vector( RandomFloatRange( -1200, 1200 ), 100, 0 )
	float fuseTime = 0.0
	entity nade = FireWeaponGrenade_RecordData( weapon, attackParams.pos, attackVec, angularVelocity, fuseTime, damageTypes.pinkMist, damageTypes.pinkMist, !isNPCFiring, true, false )

	if ( nade )
	{
		#if SERVER
			// forced sound fix!!!
			string tpFiringSound = weapon.GetWeaponSettingString( eWeaponVar.fire_sound_2_player_3p )
			EmitSoundOnEntityExceptToPlayer( owner, owner, tpFiringSound )

			thread DelayedStartParticleSystem( nade )
			EmitSoundOnEntity( nade, "Weapon_GibberPistol_Grenade_Emitter" )
			nade.ProjectileSetDamageSourceID( eDamageSourceId.mp_weapon_gibber_pistol )
			Grenade_Init( nade, weapon )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
	}
}

// trail fix
void function DelayedStartParticleSystem( entity nade )
{
    WaitFrame()
    if( IsValid( nade ) )
        StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"wpn_grenade_frag_mag" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
}

void function OnProjectileCollision_weapon_gibber_pistol( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if( mods.contains( "gibber_pistol" ) )
	{
		bool didStick = PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
		if ( !didStick )
			return
		#if SERVER
		projectile.SetGrenadeTimer( FUSE_TIME )
		#endif
	}
	else if( mods.contains( "grenade_pistol" ) )
		return
}