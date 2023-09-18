untyped

global function MpWeaponProximityMine_Init
global function OnWeaponTossReleaseAnimEvent_weapon_proximity_mine
global function OnProjectileCollision_weapon_proximity_mine

#if SERVER
global function ShowProxMineTriggeredIcon
#endif

const MAX_PROXIMITY_MINES_IN_WORLD = 4  // if more than this are thrown, the oldest one gets cleaned up
const PROXIMITY_MINE_THROW_POWER = 620
const ATTACH_SFX = "Weapon_ProximityMine_Land"
const WARNING_SFX = "Weapon_ProximityMine_ArmedBeep"

// modded proximity mine
const PROXIMITY_MINE_EXPLOSION_DELAY_BALANCED = 0.8
const PROXIMITY_MINE_ARMING_DELAY_BALANCED = 1.2
const ANTI_TITAN_MINE_EXPLOSION_DELAY = 1.2

struct {
	int iconCount = 0
	int totalIcons = 10
	var[10] icons
} file
function MpWeaponProximityMine_Init()
{
	#if SERVER
		RegisterSignal( "ProxMineTriggered" )
		PrecacheModel( $"models/weapons/caber_shot/caber_shot_thrown.mdl" )
		// using projectile.ProjectileSetDamageSourceID() to handle this
		//AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_satchel, OnDamagedTarget_Proximity_Mine )
	#endif
}

#if SERVER
// nessie note: should use PingMiniMap() in titanfall 2
function ShowProxMineTriggeredIcon( entity triggeredEnt )
{
	triggeredEnt.Signal( "ProxMineTriggered")
	triggeredEnt.EndSignal( "OnDeath" )
	triggeredEnt.EndSignal( "ProxMineTriggered" )

	wait PROX_MINE_MARKER_TIME
}
#endif

var function OnWeaponTossReleaseAnimEvent_weapon_proximity_mine( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return
	#endif

	entity player = weapon.GetWeaponOwner()

	vector attackPos
	if ( IsValid( player ) )
		attackPos = GetProximityMineThrowStartPos( player, attackParams.pos )
	else
		attackPos = attackParams.pos

	vector attackVec = attackParams.dir
	vector angularVelocity = Vector( 600, RandomFloatRange( -300, 300 ), 0 )

	float fuseTime = 0.0	// infinite

	int damageFlags = weapon.GetWeaponDamageFlags()
	entity proximityMine = weapon.FireWeaponGrenade( attackPos, attackVec, angularVelocity, fuseTime, damageFlags, damageFlags, PROJECTILE_PREDICTED, true, true )
	if ( proximityMine == null )
		return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )

	// modified, or it won't have proper behavior
	proximityMine.SetModel( $"models/weapons/caber_shot/caber_shot_thrown.mdl" ) //caber_shot_thrown_xl

	Grenade_Init( proximityMine, weapon )
	PlayerUsedOffhand( player, weapon )
	#if SERVER
		EmitSoundOnEntityExceptToPlayer( player, player, "weapon_proximitymine_throw" )
		ProximityCharge_PostFired_Init( proximityMine, player )
		// vanilla behavior
		//thread ProximityMineThink( proximityMine, player )

		// modded weapon
		int damageSourceIdOverride = eDamageSourceId.mp_weapon_proximity_mine // triggers EMP_DamagedPlayerOrNPC() in _weapon_utility.nut

		bool overrideEnemySearchFunc = false
		float armingDelay = PROXIMITY_MINE_ARMING_DELAY_BALANCED
		float explosionDelay = PROXIMITY_MINE_EXPLOSION_DELAY_BALANCED
		array<entity> functionref( entity proximityMine, int teamNum, float triggerRadius ) npcSearchFunc
		array<entity> functionref( entity proximityMine, int teamNum, float triggerRadius ) playerSearchFunc
		// proximity mine modifiers
		array<string> mods = Vortex_GetRefiredProjectileMods( proximityMine )
		if( mods.contains( "anti_titan_mine" ) )
		{
			damageSourceIdOverride = eDamageSourceId.mp_weapon_satchel

			overrideEnemySearchFunc = true
			explosionDelay = ANTI_TITAN_MINE_EXPLOSION_DELAY
			npcSearchFunc = AntiTitanMine_NPCSearch
			playerSearchFunc = AntiTitanMine_PlayerSearch
		}
		// start think
		if ( overrideEnemySearchFunc )
			thread ProximityMineThink( proximityMine, player, armingDelay, explosionDelay, npcSearchFunc, playerSearchFunc )
		else
			thread ProximityMineThink( proximityMine, player, armingDelay, explosionDelay )

		thread TrapDestroyOwnerDeath( proximityMine, player )
		thread TrapDestroyOnRoundEnd( player, proximityMine )
		thread EnableTrapWarningSound( proximityMine, PROXIMITY_MINE_ARMING_DELAY, WARNING_SFX )
		PROTO_PlayTrapLightEffect( proximityMine, "BLINKER", player.GetTeam() )

		// modified
		proximityMine.ProjectileSetDamageSourceID( damageSourceIdOverride ) 
	#endif
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function TrapDestroyOwnerDeath( entity trap, entity player )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "OnDestroy" )
	trap.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function(): ( trap )
		{
			if( IsValid( trap ) )
				trap.Destroy()
		}
	)

	WaitForever()
}

vector function GetProximityMineThrowStartPos( entity player, vector baseStartPos )
{
	vector attackPos = player.OffsetPositionFromView( baseStartPos, Vector( 15.0, 0.0, 0.0 ) )	// forward, right, up
	return attackPos
}

vector function GetProximityMineThrowVelocity( vector baseAngles )
{
	baseAngles += Vector( -10, 0, 0 )
	vector forward = AnglesToForward( baseAngles )
	vector velocity = forward * PROXIMITY_MINE_THROW_POWER

	return velocity
}

void function OnProjectileCollision_weapon_proximity_mine( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// Old version, but that rotation/position offset stuff is bunk and if this weapon comes back, we fix the asset.
	//bool result = PlantStickyEntity( projectile, collisionParams, Vector( 90, 0, 0 ), false, Vector( 0, 0, -3.9 ) )
	table collisionParams =
	{
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}
	bool result = PlantStickyEntity( projectile, collisionParams )

	#if SERVER
		entity player = projectile.GetOwner()

		if ( !IsValid( player ) )
		{
			projectile.Kill_Deprecated_UseDestroyInstead()
			return
		}

		EmitSoundOnEntity( projectile, ATTACH_SFX )

		// should enable sound right after deployed
		//thread EnableTrapWarningSound( projectile, PROXIMITY_MINE_ARMING_DELAY, WARNING_SFX )

		// if player is rodeoing a Titan and we stickied the mine onto the Titan, set lastAttackTime accordingly
		if ( result )
		{
			entity entAttachedTo = projectile.GetParent()
			if ( !IsValid( entAttachedTo ) )
				return

			if ( !player.IsPlayer() ) //If an NPC Titan has vortexed a prox mine  and fires it back out, then it won't be a player that is the owner of this satchel
				return

			entity titanSoulRodeoed = player.GetTitanSoulBeingRodeoed()
			if ( !IsValid( titanSoulRodeoed ) )
				return

			entity titan = titanSoulRodeoed.GetTitan()

			if ( !IsAlive( titan ) )
				return

			if ( titan == entAttachedTo )
				titanSoulRodeoed.SetLastRodeoHitTime( Time() )
		}
	#endif
}

#if SERVER
// using projectile.ProjectileSetDamageSourceID() to handle this
/*
void function OnDamagedTarget_Proximity_Mine( entity ent, var damageInfo )
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

	if( mods.contains( "proximity_mine" ) )
	{
		EMP_DamagedPlayerOrNPC( ent, damageInfo )
	}
}
*/

// unfinished, should use PingMiniMap()
/*
void function ProxMine_Triggered_SatchelMod( entity ent, var damageInfo )
{
	if ( !IsValid( ent ) )
		return

	if ( DamageInfo_GetCustomDamageType( damageInfo ) & DF_DOOMED_HEALTH_LOSS )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( !IsValid( attacker ) )
		return

	if ( attacker == ent )
		return

	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if( !IsValid( inflictor ) )
		return

	array<string> mods = Vortex_GetRefiredProjectileMods( inflictor ) // modded weapon refire behavior

	if( mods.contains( "proximity_mine" ) )
	{
		if ( ent.IsPlayer() || ent.IsNPC() )
			thread ShowProxMineTriggeredIcon( ent )

		//If this feature is good, we should add this to NPCs as well. Currently script errors if applied to an NPC.
		if ( ent.IsPlayer() )
			thread ProxMine_ShowOnMinimapTimed( ent, GetOtherTeam( ent.GetTeam() ), PROX_MINE_MARKER_TIME )
	}
}

// copied from _grenade.nut
function ProxMine_ShowOnMinimapTimed( ent, teamToDisplayEntTo, duration )
{
	expect entity( ent )
	if( !IsValid( ent ) )
		return

	ent.Minimap_AlwaysShow( int( teamToDisplayEntTo ), null )
	Minimap_PingForTeam( int( teamToDisplayEntTo ), ent.GetOrigin(), 64.0, float( duration ), TEAM_COLOR_FRIENDLY / 255.0, 4, false )

	wait duration

	if ( IsValid( ent ) && ent.IsPlayer() )
		ent.Minimap_DisplayDefault( teamToDisplayEntTo, ent )
}
*/

// proximity mine modifiers
array<entity> function AntiTitanMine_NPCSearch( entity proximityMine, int teamNum, float triggerRadius )
{
	// friendly fire condition
	if ( FriendlyFire_ShouldMineWeaponSearchForFriendly() )
	{
		entity owner = proximityMine.GetOwner()
		array<entity> validTargets = GetNPCArrayEx( "npc_titan", TEAM_ANY, TEAM_ANY, proximityMine.GetOrigin(), triggerRadius )
		foreach ( entity target in validTargets )
		{
			// don't damage player owned titan, otherwise we damage all titans including friendly ones
			if ( IsValid( owner ) )
			{
				if ( owner.GetTeam() != target.GetTeam() )
					continue
				if ( owner.GetPetTitan() == target )
					validTargets.removebyvalue( target )
			}
		}

		return validTargets
	}

	// default case
	return GetNPCArrayEx( "npc_titan", TEAM_ANY, teamNum, proximityMine.GetOrigin(), triggerRadius )
}

array<entity> function AntiTitanMine_PlayerSearch( entity proximityMine, int teamNum, float triggerRadius )
{
	array<entity> nearbyPlayers = GetPlayerArrayEx( "any", TEAM_ANY, teamNum, proximityMine.GetOrigin(), triggerRadius )
	
	// friendly fire condition
	entity owner = proximityMine.GetOwner()
	if ( FriendlyFire_ShouldMineWeaponSearchForFriendly() )
		nearbyPlayers = GetPlayerArrayEx( "any", TEAM_ANY, TEAM_ANY, proximityMine.GetOrigin(), triggerRadius )
	
	array<entity> tempTitanArray
	foreach( entity player in nearbyPlayers )
	{
		// don't damage player themselves, otherwise we damage all titans including friendly ones
		if ( IsValid( owner ) && player == owner )
			continue
		
		if( player.IsTitan() )
			tempTitanArray.append( player )
	}
	return tempTitanArray
}
#endif