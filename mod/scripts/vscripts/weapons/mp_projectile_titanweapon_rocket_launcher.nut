untyped


global function OnProjectileCollision_SpiralMissile

void function OnProjectileCollision_SpiralMissile( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// move outta here to add modded weapon think
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // I don't care, let's break vanilla behavior
	
	// modded weapon
	if ( mods.contains( "brute4_quad_rocket" ) )
		return OnProjectileCollision_Brute4_QuadRocket( projectile, pos, normal, hitEnt, hitbox, isCritical )
	
	#if SERVER
		//array<string> mods = projectile.ProjectileGetMods() // using Vortex_GetRefiredProjectileMods()
		
		// have to convert it to untyped array
		// why respawn never work around these?
		array untypedMods
		foreach ( mod in mods )
			untypedMods.append( mod )
		
		// "mini_clusters" is not implemented in vanilla, guess it's used for rocketeer_ammo_swap
		// I've added support for it
		if ( mods.contains( "burn_mod_titan_rocket_launcher" ) || mods.contains( "mini_clusters" ) )
		{
			entity owner = projectile.GetOwner()
			if ( IsValid( owner ) )
			{
				PopcornInfo popcornInfo

				popcornInfo.weaponName = "mp_titanweapon_rocketeer_rocketstream"
				//popcornInfo.weaponMods = projectile.ProjectileGetMods() // vanilla behavior, not changing to Vortex_GetRefiredProjectileMods()
				popcornInfo.weaponMods = untypedMods // I don't care, let's break vanilla behavior
				popcornInfo.damageSourceId = eDamageSourceId.mp_titanweapon_rocketeer_rocketstream
				popcornInfo.count = 2 //(groupSize is the minimum number of explosions )
				popcornInfo.delay = 0.5
				popcornInfo.offset = 0.3
				popcornInfo.range = 250
				popcornInfo.normal = normal
				popcornInfo.duration = 1.0
				popcornInfo.groupSize = 2 //Total explosions = groupSize * count
				popcornInfo.hasBase = false

				thread StartClusterExplosions( projectile, owner, popcornInfo, CLUSTER_ROCKET_FX_TABLE )
			}
		}

		// brute rocket specific
		// it has higher rocket speed, don't want to make landing shots too difficult
		// but we need to fix visual for it can work best
		if ( projectile.ProjectileGetMods().contains( "brute_rocket" ) ) // visual fix checks, no need to handle refiring cause refired projectile already unpredicted
			FixImpactEffectForProjectileAtPosition( projectile, pos )
	#endif

	if ( "spiralMissiles" in projectile.s )
	{
		if ( !IsAlive( hitEnt ) )
			return

		if ( !hitEnt.IsTitan() )
			return

		if ( Time() - projectile.s.launchTime < 0.02 )
			return

		foreach ( missile in projectile.s.spiralMissiles )
		{
			if ( !IsValid( missile ) )
				continue

			if ( missile == projectile )
				continue

			missile.s.spiralMissiles = []
			missile.MissileExplode()
		}
	}
}