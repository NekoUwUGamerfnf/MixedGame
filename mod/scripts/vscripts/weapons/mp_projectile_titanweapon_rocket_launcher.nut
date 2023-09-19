untyped


global function OnProjectileCollision_SpiralMissile

void function OnProjectileCollision_SpiralMissile( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	#if SERVER
		//array<string> mods = projectile.ProjectileGetMods() // vanilla behavior, not changing to Vortex_GetRefiredProjectileMods()
		array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // I don't care, let's break vanilla behavior
		// have to convert it to untyped array
		// why respawn never work around these?
		array untypedMods
		foreach ( mod in mods )
			untypedMods.append( mod )
		
		// adding brute4 cases
		// "mini_clusters" is not implemented in vanilla, guess it's used for rocketeer_ammo_swap
		//if ( mods.contains( "burn_mod_titan_rocket_launcher" ) || mods.contains( "mini_clusters" ) )
		if ( mods.contains( "brute4_cluster_payload_ammo" ) )
		{
			entity owner = projectile.GetOwner()
			if ( IsValid( owner ) )
			{
				PopcornInfo popcornInfo
				// Clusters share explosion radius/damage with the base weapon
				// Clusters spawn '((int) (count/groupSize) + 1) * groupSize' total subexplosions (thanks to a '<=')
				// The ""base delay"" between each group's subexplosion on average is ((float) duration / (int) (count / groupSize))
				// The actual delay is (""base delay"" - delay). Thus 'delay' REDUCES delay. Make sure delay + offset < ""base delay"".

				// Current:
				// 9 count, 0.3 delay, 2.4 duration, 3 groupSize
				// Total: 12 subexplosions
				// ""Base delay"": 0.8s, avg delay between (each group): 0.5s, total duration: 2.0s
				popcornInfo.weaponName = "mp_titanweapon_rocketeer_rocketstream"
				//popcornInfo.weaponMods = projectile.ProjectileGetMods() // vanilla behavior, not changing to Vortex_GetRefiredProjectileMods()
				popcornInfo.weaponMods = untypedMods // I don't care, let's break vanilla behavior
				popcornInfo.damageSourceId = eDamageSourceId.mp_titanweapon_rocketeer_rocketstream
				popcornInfo.count = 9
				popcornInfo.delay = mods.contains( "rapid_detonator" ) ? 0.4 : 0.3 // Avg delay and duration -20%
				popcornInfo.offset = 0.15
				popcornInfo.range = 200
				popcornInfo.normal = normal
				popcornInfo.duration = 2.4
				popcornInfo.groupSize = 3
				popcornInfo.hasBase = false

				thread Brute4_StartClusterExplosions( projectile, owner, popcornInfo, CLUSTER_ROCKET_FX_TABLE )
			}
		}
		else if ( mods.contains( "burn_mod_titan_rocket_launcher" ) || mods.contains( "mini_clusters" ) )
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