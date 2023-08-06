untyped

global function MpWeaponSatchel_Init

global function OnWeaponActivate_weapon_satchel
global function OnWeaponDeactivate_weapon_satchel
global function OnWeaponPrimaryAttackAnimEvent_weapon_satchel
global function OnWeaponTossReleaseAnimEvent_weapon_satchel
global function OnProjectileCollision_weapon_satchel
global function AddCallback_OnSatchelPlanted

const MAX_SATCHELS_IN_WORLD = 3  // if more than this are thrown, the oldest one gets cleaned up
const SATCHEL_THROW_POWER = 620

// rework callbacks to make it typed!!
struct
{
	array< void functionref( entity player, entity satchel, table collisionParams ) > onSatchelPlantedCallbacks
} file

function MpWeaponSatchel_Init()
{
	SatchelPrecache()

	RegisterSignal( "DetonateSatchels" )
}

function SatchelPrecache()
{
	PrecacheParticleSystem( $"wpn_laser_blink" )
	PrecacheParticleSystem( $"wpn_satchel_clacker_glow_LG_1" )
	PrecacheParticleSystem( $"wpn_satchel_clacker_glow_SM_1" )
}

void function OnWeaponActivate_weapon_satchel( entity weapon )
{
	#if CLIENT
		if ( weapon.GetWeaponOwner() == GetLocalViewPlayer() )
		{
			weapon.PlayWeaponEffect( $"wpn_satchel_clacker_glow_LG_1", $"", "light_large" )
			weapon.PlayWeaponEffect( $"wpn_satchel_clacker_glow_SM_1", $"", "light_small" )
		}
	#endif
}

void function OnWeaponDeactivate_weapon_satchel( entity weapon )
{
	#if CLIENT
		if ( weapon.GetWeaponOwner() == GetLocalViewPlayer() )
		{
			weapon.StopWeaponEffect( $"wpn_satchel_clacker_glow_LG_1", $"" )
			weapon.StopWeaponEffect( $"wpn_satchel_clacker_glow_SM_1", $"" )
		}
	#endif
}

var function OnWeaponPrimaryAttackAnimEvent_weapon_satchel( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity player = weapon.GetWeaponOwner()
	if ( !IsValid( player ) )
		return

	#if SERVER
	if( !weapon.HasMod( "proximity_mine" ) || !weapon.HasMod( "anti_titan_mine" ) )
		Player_DetonateSatchels( player )
	#endif
}

var function OnWeaponTossReleaseAnimEvent_weapon_satchel( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "proximity_mine" ) || weapon.HasMod( "anti_titan_mine" ) )
		return OnWeaponTossReleaseAnimEvent_weapon_proximity_mine( weapon, attackParams )

	// vanilla behavior
	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return
	#endif

	entity player = weapon.GetWeaponOwner()

	vector attackPos
	if ( IsValid( player ) )
		attackPos = GetSatchelThrowStartPos( player, attackParams.pos )
	else
		attackPos = attackParams.pos


	vector attackVec = attackParams.dir
	vector angularVelocity = Vector( 600, RandomFloatRange( -300, 300 ), 0 )

	float fuseTime = 0.0	// infinite

	int damageFlags = weapon.GetWeaponDamageFlags()
	entity satchel = weapon.FireWeaponGrenade( attackPos, attackVec, angularVelocity, fuseTime, damageFlags, damageFlags, PROJECTILE_PREDICTED, true, true )
	if ( satchel == null )
		return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )

	Grenade_Init( satchel, weapon )
	PlayerUsedOffhand( player, weapon )

	#if SERVER
		SetVisibleEntitiesInConeQueriableEnabled( satchel, true )
		Satchel_PostFired_Init( satchel, player )
		thread EnableTrapWarningSound( satchel, 0, DEFAULT_WARNING_SFX )
		EmitSoundOnEntityExceptToPlayer( player, player, "weapon_r1_satchel.throw" )
		PROTO_PlayTrapLightEffect( satchel, "LIGHT", player.GetTeam() )
		#if BATTLECHATTER_ENABLED
			TryPlayWeaponBattleChatterLine( player, weapon )
		#endif
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

vector function GetSatchelThrowStartPos( entity player, vector baseStartPos )
{
	vector attackPos = player.OffsetPositionFromView( baseStartPos, Vector( 15.0, 0.0, 0.0 ) )	// forward, right, up
	return attackPos
}

vector function GetSatchelThrowVelocity( entity player, vector baseAngles )
{
	baseAngles += Vector( -8, 0, 0 )
	vector forward = AnglesToForward( baseAngles )
	vector velocity = forward * SATCHEL_THROW_POWER

	return velocity
}

void function OnProjectileCollision_weapon_satchel( entity weapon, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded weapons
	array<string> mods = Vortex_GetRefiredProjectileMods( weapon ) // modded weapon refire behavior
	if( mods.contains( "proximity_mine" ) || mods.contains( "anti_titan_mine" ) )
		return OnProjectileCollision_weapon_proximity_mine( weapon, pos, normal, hitEnt, hitbox, isCritical )
	//

	// vanilla behavior
	table collisionParams =
	{
		pos = pos,
		normal = normal,
		hitEnt = hitEnt,
		hitbox = hitbox
	}

	bool result = PlantStickyEntity( weapon, collisionParams )

	#if SERVER
		entity player = weapon.GetOwner()

		if ( !IsValid( player ) )
		{
			weapon.Kill_Deprecated_UseDestroyInstead()
			return
		}

		EmitSoundOnEntity( weapon, "Weapon_R1_Satchel.Attach" )
		EmitAISoundWithOwner( player, SOUND_PLAYER, 0, player.GetOrigin(), 1000, 0.2 )

		// Added via AddCallback_OnSatchelPlanted
		// rework to make it typed！！
		#if MP
			foreach ( callbackFunc in file.onSatchelPlantedCallbacks )
				callbackFunc( player, weapon, collisionParams )
		#else // vanilla behavior(save for SP)
			if ( "onSatchelPlanted" in level )
			{
				foreach ( callbackFunc in level.onSatchelPlanted )
					callbackFunc( player, collisionParams )
			}
		#endif // MP

		//if player is rodeoing a Titan and we stickied the satchel onto the Titan, set lastAttackTime accordingly
		if ( result )
		{
			entity entAttachedTo = weapon.GetParent()
			if ( !IsValid( entAttachedTo ) )
				return

			if ( !player.IsPlayer() ) //If an NPC Titan has vortexed a satchel and fires it back out, then it won't be a player that is the owner of this satchel
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

// rework to make it typed！！
#if MP
void function AddCallback_OnSatchelPlanted( void functionref( entity player, entity satchel, table collisionParams ) callbackFunc )
{
	file.onSatchelPlantedCallbacks.append( callbackFunc )
}
#else // vanilla behavior(save for SP)
function AddCallback_OnSatchelPlanted( callbackFunc )
{
	if ( !( "onSatchelPlanted" in level ) )
		level.onSatchelPlanted <- []

	AssertParameters( callbackFunc, 2, "entity player, table collisionParams" )

	Assert( !level.onSatchelPlanted.contains( callbackFunc ), "Already added " + FunctionToString( callbackFunc ) + " with AddCallback_OnSatchelPlanted" )

	level.onSatchelPlanted.append( callbackFunc )
}
#endif // MP