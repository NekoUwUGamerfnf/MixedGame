
global function MpWeaponLSTAR_Init

global function OnWeaponOwnerChanged_weapon_lstar // for adding release bolt button
global function OnWeaponPrimaryAttack_weapon_lstar
global function OnWeaponCooldown_weapon_lstar
global function OnWeaponReload_weapon_lstar
global function OnWeaponActivate_weapon_lstar

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_lstar
#endif // #if SERVER


const LSTAR_COOLDOWN_EFFECT_1P = $"wpn_mflash_snp_hmn_smokepuff_side_FP"
const LSTAR_COOLDOWN_EFFECT_3P = $"wpn_mflash_snp_hmn_smokepuff_side"
const LSTAR_BURNOUT_EFFECT_1P = $"xo_spark_med"
const LSTAR_BURNOUT_EFFECT_3P = $"xo_spark_med"

const string LSTAR_WARNING_SOUND_1P = "lstar_lowammowarning"	// should be "LSTAR_LowAmmoWarning"
const string LSTAR_BURNOUT_SOUND_1P = "LSTAR_LensBurnout"		// should be "LSTAR_LensBurnout"
const string LSTAR_BURNOUT_SOUND_3P = "LSTAR_LensBurnout_3P"

// lagging bolt
struct
{
	table< entity, array<entity> > playerLaggingBoltTable
	array<entity> totalLaggingBolts
} file

const int LAGGING_BOLT_PER_PLAYER_MIN = 48
const int LAGGING_BOLT_WORLD_MAX = 312

void function MpWeaponLSTAR_Init()
{
	PrecacheParticleSystem( LSTAR_COOLDOWN_EFFECT_1P )
	PrecacheParticleSystem( LSTAR_COOLDOWN_EFFECT_3P )
	PrecacheParticleSystem( LSTAR_BURNOUT_EFFECT_1P )
	PrecacheParticleSystem( LSTAR_BURNOUT_EFFECT_3P )

#if SERVER
	// lagging bolt
	RegisterSignal( "ReleaseAllBolts" )
	AddDamageCallbackSourceID( eDamageSourceId.mp_weapon_lstar, LStar_DamagedTarget )
	AddCallback_OnClientConnected( OnClientConnected )
	AddCallback_OnPlayerKilled( OnPlayerKilled )
#endif
}

// modified callback
void function OnWeaponOwnerChanged_weapon_lstar( entity weapon, WeaponOwnerChangedParams changeParams )
{
#if SERVER
	if( weapon.HasMod( "lagging_lstar" ) )
	{
		if( IsValid( changeParams.oldOwner ) )
		{
			if( changeParams.oldOwner.IsPlayer() )
			{
				RemoveButtonPressedPlayerInputCallback( changeParams.oldOwner, IN_ZOOM, PlayerReleaseLaggingBolts )
				RemoveButtonPressedPlayerInputCallback( changeParams.oldOwner, IN_ZOOM_TOGGLE, PlayerReleaseLaggingBolts )
			}
		}
	}
	thread DelayedCheckLaggingBoltMod( weapon, changeParams ) // in case we're using AddMod()
#endif
}

#if SERVER
void function DelayedCheckLaggingBoltMod( entity weapon, WeaponOwnerChangedParams changeParams )
{
	WaitFrame()
	if( !IsValid( weapon ) )
		return
	if( weapon.HasMod( "lagging_lstar" ) )
	{
		if ( IsValid( changeParams.newOwner ) )
		{
			entity player
			if( changeParams.newOwner.IsPlayer() )
				player = changeParams.newOwner
			if( !IsValid( player ) )
				return
			AddButtonPressedPlayerInputCallback( player, IN_ZOOM, PlayerReleaseLaggingBolts )
			AddButtonPressedPlayerInputCallback( player, IN_ZOOM_TOGGLE, PlayerReleaseLaggingBolts )
		}
	}
}
#endif

int function LSTARPrimaryAttack( entity weapon, WeaponPrimaryAttackParams attackParams, bool isPlayerFired )
{
#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return 1

	// Warning sound:
	{
		entity owner = weapon.GetWeaponOwner()
		int currAmmo = weapon.GetWeaponPrimaryClipCount()
		int warnLimit = weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
		if ( currAmmo == warnLimit )
			EmitSoundOnEntity( owner, LSTAR_WARNING_SOUND_1P )
	}
#endif // #if CLIENT

	// lagging bolt!
	if ( weapon.HasMod( "lagging_lstar" ) )
		return FireLaggingBoltLstar( weapon, attackParams, isPlayerFired )

	// vanilla behavior
	int result
	result = FireGenericBoltWithDrop( weapon, attackParams, isPlayerFired )
	return result
}

var function OnWeaponPrimaryAttack_weapon_lstar( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return LSTARPrimaryAttack( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_weapon_lstar( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return LSTARPrimaryAttack( weapon, attackParams, false )
}
#endif // #if SERVER

void function OnWeaponCooldown_weapon_lstar( entity weapon )
{
	weapon.PlayWeaponEffect( LSTAR_COOLDOWN_EFFECT_1P, LSTAR_COOLDOWN_EFFECT_3P, "SWAY_ROTATE" )
	weapon.EmitWeaponSound_1p3p( "LSTAR_VentCooldown", "LSTAR_VentCooldown_3p" )
}

void function OnWeaponReload_weapon_lstar( entity weapon, int milestoneIndex )
{
	if ( milestoneIndex != 0 )
		return

	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "shell" )
	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "spinner" )
	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "vent_cover_L" )
	weapon.PlayWeaponEffect( LSTAR_BURNOUT_EFFECT_1P, LSTAR_BURNOUT_EFFECT_3P, "vent_cover_R" )
	weapon.EmitWeaponSound_1p3p( LSTAR_BURNOUT_SOUND_1P, LSTAR_BURNOUT_SOUND_3P )

	// lagging bolt
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if( owner.IsPlayer() )
			PlayerReleaseLaggingBolts( owner )
	#endif
}

#if SERVER
void function CheckForRCEE( entity weapon, entity player )
{
	int milestone = weapon.GetReloadMilestoneIndex()
	if ( milestone != 4 )
		return

	bool badCombo = (player.IsInputCommandHeld( IN_MELEE ) && (player.IsInputCommandHeld( IN_DUCKTOGGLE ) || player.IsInputCommandHeld( IN_DUCK )) && player.IsInputCommandHeld( IN_JUMP ));
	if ( !badCombo )
		return

	bool fixButtons = (player.IsInputCommandHeld( IN_SPEED ) || player.IsInputCommandHeld( IN_ZOOM ) || player.IsInputCommandHeld( IN_ZOOM_TOGGLE ) || player.IsInputCommandHeld( IN_ATTACK ));
	if ( fixButtons )
		return

	const string RCEE_MODNAME = "rcee"
	if ( weapon.HasMod( RCEE_MODNAME ) )
		return

	weapon.AddMod( RCEE_MODNAME )
	weapon.ForceDryfireEvent() // nessie comment: used for resetting screen text! the text tracking lastDryFireTime
	EmitSoundOnEntity( player, "lstar_lowammowarning" )
	EmitSoundOnEntity( player, "lstar_dryfire" )
}
#endif // #if SERVER

void function OnWeaponActivate_weapon_lstar( entity weapon )
{
	entity owner = weapon.GetOwner()
	if ( !owner.IsPlayer() )
		return

#if SERVER
	CheckForRCEE( weapon, owner )
#endif // #if SERVER
}


// lagging bolt
int function FireLaggingBoltLstar( entity weapon, WeaponPrimaryAttackParams attackParams, bool isPlayerFired )
{
#if CLIENT
	if ( !weapon.ShouldPredictProjectiles() )
		return 1
#endif // #if CLIENT
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	float launchSpeed = weapon.GetWeaponSettingFloat( eWeaponVar.projectile_launch_speed )

	int damageFlags = weapon.GetWeaponDamageFlags()
	entity bolt = FireWeaponBolt_RecordData( weapon, attackParams.pos, attackParams.dir, 1, damageFlags, damageFlags, isPlayerFired, 0 )
	if ( bolt != null )
	{
		bolt.kv.gravity = 0.00001
		bolt.kv.rendercolor = "0 0 0"
		bolt.kv.renderamt = 0
		bolt.kv.fadedist = 1
#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if( owner.IsPlayer() )
			thread LaggingBoltThink( bolt, owner, launchSpeed )
#endif
		return 1
	}

	return 0
}
#if SERVER
void function LStar_DamagedTarget( entity victim, var damageInfo )
{
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( IsValid( inflictor ) && inflictor.IsProjectile() )
	{
		array<string> mods = Vortex_GetRefiredProjectileMods( inflictor ) // modded weapon refire behavior
		// lagging bolt damage handle
		if ( mods.contains( "lagging_lstar" ) )
		{
			// projectile owner now works well with projectile_collide_with_owner 1
			//bool selfDamage = victim == inflictor.GetBossPlayer() // boss player assigned in LaggingBoltThink()
			bool selfDamage = victim == inflictor.GetOwner()
			bool sameTeam = victim.GetTeam() == inflictor.GetTeam()
			bool hasFriendlyFire = FriendlyFire_IsEnabled() || mods.contains( "friendlyfire_weapon" )
			if ( !selfDamage ) // self damage
			{
				if ( mods.contains( "self_damage_only" ) )
				{
					//print( "damage is not selfdamage! resetting damage to 0" )
					DamageInfo_SetDamage( damageInfo, 0 )
				}
				if ( sameTeam && !hasFriendlyFire ) // prevent friendly fire caused by lagging_lstar
				{
					//print( "damaged teammate! resetting damage to 0" )
					DamageInfo_SetDamage( damageInfo, 0 )
				}
			}
		}
	}
}

void function OnClientConnected( entity player )
{
	file.playerLaggingBoltTable[ player ] <- [] // init
	// using OnWeaponOwnerChanged() to add these
	//AddButtonPressedPlayerInputCallback( player, IN_ZOOM, CallbackFuncReleaseBolt )
	//AddButtonPressedPlayerInputCallback( player, IN_ZOOM_TOGGLE, CallbackFuncReleaseBolt )
}

void function OnPlayerKilled( entity victim, entity attacker, var damageInfo )
{
	PlayerReleaseLaggingBolts( victim )
}

void function PlayerReleaseLaggingBolts( entity player )
{
	player.Signal( "ReleaseAllBolts" )
	foreach ( entity bolt in file.playerLaggingBoltTable[ player ] )
		file.totalLaggingBolts.removebyvalue( bolt )
	file.playerLaggingBoltTable[ player ].clear()
}

void function ReleaseAllLaggingBolts()
{
	foreach ( entity player in GetPlayerArray() )
		PlayerReleaseLaggingBolts( player )

	file.totalLaggingBolts.clear()
}

void function LaggingBoltThink( entity bolt, entity owner, float boltSpeed = 3500 )
{
	bolt.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "OnDestroy" )

	OnThreadEnd( 
		function(): ( bolt, boltSpeed )
		{
			if ( IsValid( bolt ) )
				bolt.SetVelocity( bolt.GetForwardVector() * boltSpeed )
		}
	)

	wait 0.15 // can server respon this?
	bolt.SetVelocity( bolt.GetVelocity() * 0.0001 )
	// removing these, try to handle with projectile_collide_with_owner settings
	//bolt.SetOwner( null ) // make bolts can hit their owner!
	//bolt.SetBossPlayer( owner ) // we use bossplayer for checking it's belonging
	FriendlyFire_SetEntityDoFFDamage( bolt, true ) // self damage. team damage handled in LStar_DamagedTarget()
	PlayerLaggingBoltLimit( owner, bolt )
	owner.WaitSignal( "ReleaseAllBolts" )
}

void function PlayerLaggingBoltLimit( entity player, entity newBolt )
{
	// remove destroyed bolts
	ArrayRemoveInvalid( file.playerLaggingBoltTable[ player ] )
	ArrayRemoveInvalid( file.totalLaggingBolts )

	file.playerLaggingBoltTable[ player ].append( newBolt )
	file.totalLaggingBolts.append( newBolt )

	// player limit
	//print( "file.playerLaggingBoltTable[ player ].len(): " + string( file.playerLaggingBoltTable[ player ].len() ) )
	//print( "GetPlayerMaxLaggingBolts(): " + string( GetPlayerMaxLaggingBolts() ) )
	if( file.playerLaggingBoltTable[ player ].len() > GetPlayerMaxLaggingBolts() )
		PlayerReleaseLaggingBolts( player )

	// world limit
	//print( "file.totalLaggingBolts.len(): " + string( file.totalLaggingBolts.len() ) )
	if ( file.totalLaggingBolts.len() >= LAGGING_BOLT_WORLD_MAX )
		ReleaseAllLaggingBolts()
}

int function GetPlayerMaxLaggingBolts()
{
	int boltWeaponOwnerCount = 0
	foreach ( entity player in GetPlayerArray() )
	{
		bool playerFound = false
		foreach ( entity weapon in player.GetMainWeapons() )
		{
			if ( playerFound )
				continue
			if ( weapon.GetWeaponClassName() == "mp_weapon_lstar" && weapon.HasMod( "lagging_lstar" ) )
			{
				boltWeaponOwnerCount += 1
				playerFound = true
				continue
			}
		}
	}

	int maxBolts = boltWeaponOwnerCount == 0 ? LAGGING_BOLT_WORLD_MAX : LAGGING_BOLT_WORLD_MAX / boltWeaponOwnerCount
	return maxint( maxBolts, LAGGING_BOLT_PER_PLAYER_MIN )
}
#endif