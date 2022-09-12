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

struct {
	int iconCount = 0
	int totalIcons = 10
	var[10] icons
} file
function MpWeaponProximityMine_Init()
{
	#if SERVER
		RegisterSignal( "ProxMineTriggered" )
		AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_satchel, OnDamagedTarget_Proximity_Mine )
	#endif
}

#if SERVER
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

	proximityMine.SetModel( $"models/weapons/caber_shot/caber_shot_thrown_xl.mdl" )

	Grenade_Init( proximityMine, weapon )
	PlayerUsedOffhand( player, weapon )
	#if SERVER
		EmitSoundOnEntityExceptToPlayer( player, player, "weapon_proximitymine_throw" )
		ProximityCharge_PostFired_Init( proximityMine, player )
		thread ProximityMineThink( proximityMine, player )
		thread TrapDestroyOwnerDeath( proximityMine, player )
		thread TrapDestroyOnRoundEnd( player, proximityMine )
		thread EnableTrapWarningSound( proximityMine, PROXIMITY_MINE_ARMING_DELAY, WARNING_SFX )
		PROTO_PlayTrapLightEffect( proximityMine, "BLINKER", player.GetTeam() )
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

	array<string> mods = inflictor.ProjectileGetMods()

	if( mods.contains( "proximity_mine" ) )
	{
		EMP_DamagedPlayerOrNPC( ent, damageInfo )
	}
}

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

	local inflictor = DamageInfo_GetInflictor( damageInfo )
	if( !IsValid( inflictor ) )
		return

	local mods = inflictor.ProjectileGetMods()

	if( mods.contains( "proximity_mine" ) )
	{
		if ( ent.IsPlayer() || ent.IsNPC() )
			thread ShowProxMineTriggeredIcon( ent )

		//If this feature is good, we should add this to NPCs as well. Currently script errors if applied to an NPC.
		if ( ent.IsPlayer() )
			thread ProxMine_ShowOnMinimapTimed( ent, GetOtherTeam( ent.GetTeam() ), PROX_MINE_MARKER_TIME )
	}
}

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
#endif