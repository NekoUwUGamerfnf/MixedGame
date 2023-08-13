untyped

global function OnWeaponPrimaryAttack_titanweapon_barrage_core_launcher
global function OnProjectileCollision_titanweapon_barrage_core_launcher

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_barrage_core_launcher
#endif // #if SERVER

const FUSE_TIME = 0.25 //Applies once the grenade has stuck to a surface.
const FUSE_TIME_EXT = 1.5

var function OnWeaponPrimaryAttack_titanweapon_barrage_core_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		return FireGrenade( weapon, attackParams )
	return 1
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_barrage_core_launcher( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	return FireGrenade( weapon, attackParams, true )
}
#endif // #if SERVER

var function FireGrenade( entity weapon, WeaponPrimaryAttackParams attackParams, bool isNPCFiring = false )
{
	entity owner = weapon.GetWeaponOwner()
	owner.Signal("KillBruteShield")

	vector angularVelocity = Vector( 0, 0, 0 )

	int damageType = DF_RAGDOLL | DF_EXPLOSION

	entity nade = weapon.FireWeaponGrenade( attackParams.pos, attackParams.dir, angularVelocity, 0.0 , damageType, damageType, !isNPCFiring, true, false )

	if ( nade )
	{
		nade.SetModel( $"models/weapons/grenades/m20_f_grenade_projectile.mdl" )
		#if SERVER
			nade.ProjectileSetDamageSourceID( eDamageSourceId.mp_titancore_barrage_core_launcher ) // change damageSourceID
			EmitSoundOnEntity( nade, "Weapon_softball_Grenade_Emitter" )
			Grenade_Init( nade, weapon )

			// fix for trail effect, so clients without scripts installed can see the trail
			// start from server-side, so clients that already installed scripts won't see multiple trail effect stacking together
			StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"Rocket_Smoke_SMALL_Titan_mod" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
			StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"wpn_grenade_sonar_titan_AMP" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
			StartParticleEffectOnEntity( nade, GetParticleSystemIndex( $"wpn_grenade_frag_softball_elec_burn" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		#else
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( nade, weaponOwner.GetTeam() )
		#endif
	}
	return 1
}

void function OnProjectileCollision_titanweapon_barrage_core_launcher( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		if ( IsAlive( hitEnt ) && hitEnt.IsPlayer() )
		{
			PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
			EmitSoundOnEntityOnlyToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_1P" )
			EmitSoundOnEntityExceptToPlayer( projectile, hitEnt, "weapon_softball_grenade_attached_3P" )
		}
		else
		{
			PlantSuperStickyGrenade( projectile, pos, normal, hitEnt, hitbox )
			EmitSoundOnEntity( projectile, "weapon_softball_grenade_attached_3P" )
		}
		// HACK - call cluster creation on impact, otherwise projectile will be null; use projectile_explosion_delay in .txt to account for FUSE_TIME. Must match!
		StartClusterAfterDelay( projectile, normal )
		thread DetonateStickyAfterTime( projectile, FUSE_TIME, normal )
	#endif
}

#if SERVER
void function StartClusterAfterDelay( entity projectile, vector normal) {
	entity owner = projectile.GetOwner()
	if ( IsValid( owner ) )
	{
		PopcornInfo popcornInfo
		// Clusters share explosion radius/damage with the base weapon
		// Clusters spawn '((int) (count/groupSize) + 1) * groupSize' total subexplosions (thanks to a '<=')
		// The ""base delay"" between each group's subexplosion on average is ((float) duration / (int) (count / groupSize))
		// The actual delay is (""base delay"" - delay). Thus 'delay' REDUCES delay. Make sure delay + offset < ""base delay"".

		// Current:
		// 5 count, 0.15 delay, 2 duration, 1 groupSize
		// Total: 6 subexplosions
		// ""Base delay"": 0.4s, avg delay between (each group): 0.25s, total duration: 1.5s
		array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
		array untypedArray // construct to untyped array
		foreach ( string mod in mods )
			untypedArray.append( mod )
		popcornInfo.weaponName = "mp_titanweapon_flightcore_launcher"
		popcornInfo.weaponMods = untypedArray
		popcornInfo.damageSourceId = eDamageSourceId.mp_titancore_barrage_core_launcher
		popcornInfo.count = 5
		popcornInfo.delay = mods.contains( "rapid_detonator" ) ? 0.225 : 0.15 // avg delay and duration -30%
		popcornInfo.offset = 0.1
		popcornInfo.range = 150
		popcornInfo.normal = normal
		popcornInfo.duration = 2.0
		popcornInfo.groupSize = 1
		popcornInfo.hasBase = false

		thread StartClusterExplosions( projectile, owner, popcornInfo, CLUSTER_ROCKET_FX_TABLE )
	}
}
#endif //SERVER

#if SERVER
// need this so grenade can use the normal to explode
void function DetonateStickyAfterTime( entity projectile, float delay, vector normal )
{
	wait delay
	if ( IsValid( projectile ) )
		projectile.GrenadeExplode( normal )
}
#endif

